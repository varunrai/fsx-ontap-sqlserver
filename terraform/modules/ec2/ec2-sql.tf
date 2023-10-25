module "sqlserver" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.2.1"

  for_each = toset(["Demo"])

  name = "${var.creator_tag}-SQL-${each.key}"

  instance_type          = var.sql_instance_type
  key_name               = var.instance_keypair
  monitoring             = true
  vpc_security_group_ids = var.security_groups_ids
  subnet_id              = var.sql_subnet_id
  ami                    = data.aws_ami.windows-sql-server.id
  iam_instance_profile   = var.ec2_iam_role

  root_block_device = {
    volume_type = "gp2"
    volume_size = 150
  }

  user_data = <<EOT
    <powershell>
      Function CreateDisk([string]$Drive, [string]$DriveLabel) {
          Set-Disk -UniqueId $disk.UniqueId -IsOffline $false 
          Set-Disk -UniqueId $disk.UniqueId -IsReadOnly $false 
                            
          if($disk.PartitionStyle -ne "MBR") {
              Initialize-Disk -PartitionStyle MBR -UniqueId $disk.UniqueId
              New-Partition -DiskId $disk.UniqueId -UseMaximumSize -DriveLetter $Drive 
              $NewVol = Format-Volume -DriveLetter $Drive -FileSystem NTFS -NewFileSystemLabel $DriveLabel -AllocationUnitSize 655336 -Confirm:$false 
                              
              if($NewVol.HealthStatus -eq "Healthy" -and $NewVol.OperationalStatus -eq "OK") {
                  Write-Host "New $DriveLabel Volume is created successfully and operational"
              }
          }
      } 

      Function InstallSampleDatabase([string]$DataDrive,[string]$LogDrive) {
        $sampleDatabaseName = "StackOverflow"
        Write-Host "Installing Sample Database"
        if(!(Get-DbaDatabase -SqlInstance localhost -Database $sampleDatabaseName))
        {
            try
            {
                if(!(Test-Path -Path "${DataDrive}:\SO.7z")) {
                    Write-Host "Downloading Sample Database"
                    Start-BitsTransfer -Source "https://downloads.brentozar.com/StackOverflow2013_201809117.7z" -Destination "${DataDrive}:\SO.7z" -Confirm:$false -ErrorAction SilentlyContinue
                    try {
                        if(!(Test-Path -Path "C:\Program Files\7-zip\7z.exe")) {
                            Write-Host "Downloading 7zip"
                            $dlurl = 'https://7-zip.org/' + (Invoke-WebRequest -UseBasicParsing -Uri 'https://7-zip.org/' | Select-Object -ExpandProperty Links | Where-Object {($_.outerHTML -match 'Download')-and ($_.href -like "a/*") -and ($_.href -like "*-x64.exe")} | Select-Object -First 1 | Select-Object -ExpandProperty href)
                            $installerPath = Join-Path "${DataDrive}:\" (Split-Path $dlurl -Leaf)
                            Invoke-WebRequest $dlurl -OutFile $installerPath
                            Start-Process -FilePath $installerPath -Args "/S" -Verb RunAs -Wait
                        }
                    } 
                    catch {
                        Write-Host "An error occured during download or installation of 7zip"
                        Write-Host $_
                    }
                }

                try {
                    Write-Host "Downloading Database from Archive"
                    & 'C:\Program Files\7-Zip\7z.exe' x "${DataDrive}:\SO.7z" -o"${DataDrive}:\" -y
                    & mv "${DataDrive}:\StackOverflow2013_log.ldf" "${LogDrive}:\"
                } catch {
                    Write-Host "An error occured during extraction of sample database or move"
                    Write-Host $_
                }

                try {
                    $fileStructure = New-Object System.Collections.Specialized.StringCollection
                    $filestructure.Add("${DataDrive}:\StackOverflow2013_1.mdf")
                    $filestructure.Add("${DataDrive}:\StackOverflow2013_2.ndf")
                    $filestructure.Add("${DataDrive}:\StackOverflow2013_3.ndf")
                    $filestructure.Add("${DataDrive}:\StackOverflow2013_4.ndf")
                    $filestructure.Add("${LogDrive}:\StackOverflow2013_log.ldf")
                    Mount-DbaDatabase -SqlInstance localhost -Database StackOverflow -FileStructure $fileStructure -WarningAction Continue
                    Write-Host "Installing Sample Database Completed"
                } catch {
                    Write-Host "Failed to mount sample database!"
                    Write-Host $_
                }
            }
            catch {
                Write-Host "Failed to download sample database!"
                Write-Host $_
            }
        } 
      } 


      Write-Host "Starting EC2 Configuration for SQL Server and FSxN"
      Start-Service MSiSCSI
      Set-Service -Name msiscsi -StartupType Automatic 
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      
      $ManagementIP = "${var.fsxn_management_ip[0]}"
      $OntapArray = @($ManagementIP)
      $User = "${var.fsxn_admin_user}"
      $ssmPass = (Get-SSMParameterValue -Name /fsxn/password/fsxnadmin -WithDecryption 1).Parameters.Value 
      $Pass = ConvertTo-SecureString "$($ssmPass)" -AsPlainText -Force 

      $SvmName = "${var.fsxn_svm}"
      $DataLunPath = "/vol/${var.fsxn_volume_name}/sqldata"
      $LogLunPath = "/vol/${var.fsxn_volume_name}/sqllog"
      $InitiatorGroup = "SQLServer"
      $DataLunSize = "500GB"
      $LogLunSize = "500GB"

      $iSCSIAddress1 ="${var.fsxn_iscsi_ips[0]}"
      $iSCSIAddress2 = "${var.fsxn_iscsi_ips[1]}"
      $DataDirDrive = "D"
      $LogDirDrive = "E"
      $iSCSISessionsPerTarget = 5
      
      Write-Host "Installing Nuget Provider"
      if((Get-PackageProvider -Name NuGet -Force).Version -lt "2.8.5.208") {
          Install-PackageProvider -Name NuGet -Confirm:$false -Force
      } 
      Write-Host "Nuget Provider is installed"
      
      Write-Host "Checking if DBA Tools are installed"
      $DBATools = Get-Module dbatools -ListAvailable -Refresh
      if($DBATools -eq $null) {
          Write-Host "Installing DBA Tools"
          (Install-Module dbatools -Force)
      }
      Write-Host "DBA Tools Installed"

      Write-Host "Checking if NetApp.ONTAP Powershell is installed"
      $ONTAPModule = Get-Module NetApp.ONTAP -ListAvailable -Refresh
      if($ONTAPModule -eq $null) {
        Write-Host "Installing NetApp.ONTAP Powershell Module"
        Install-Module -Name NetApp.ONTAP -RequiredVersion 9.12.1.2302 -SkipPublisherCheck -Confirm:$false  -Repository PSGallery -Force
      } 
      Write-Host "NetApp.ONTAP Powershell Module Installed"

      Write-Host "Installing MPIO"
      $MPIOFeature = (Install-WindowsFeature Multipath-IO -Restart)
      Write-Host "MPIO Installed"

      if($MPIOFeature.Success -eq $true -and $MPIOFeature.RestartNeeded -eq "No") {       
       
        $IQN = (Get-InitiatorPort).NodeAddress
        
        # check if NetApp LUNs are already in the system
        $PreCheckDataDisks = (Get-Disk | Where-Object { $_.FriendlyName -eq "NETAPP LUN C-Mode" -and $_.OperationalStatus -eq "Online" })
        $PreCheckDataVolume = (Get-Volume | Where-Object { $_.FileSystemLabel -eq "SQL Data" })
        $PreCheckLogVolume = (Get-Volume | Where-Object { $_.FileSystemLabel -eq "SQL Log" })
        if($PreCheckDataDisks -ne $null -and $PreCheckDataVolume -ne $null -and $PreCheckLogVolume -ne $null) {
          Write-Host "SQL Data and Log Disks are already mounted"
          Write-Host "Exiting the script."
          exit
        }

        [pscredential]$Credential = New-Object System.Management.Automation.PSCredential ($User, $Pass)
        $Array = Connect-NcController -Name $OntapArray -Credential $Credential -ErrorAction Stop -ONTAPI
        $Cluster = Get-NcCluster -Controller $Array

        $SVM = Get-NcVserver -Controller $Array -Name $SvmName

        Set-NcVolOption -Name vol1 -Controller $Array -VserverContext $SVM -Key "fractional_reserve" -Value 0
        Set-NcVolOption -Name vol1 -Controller $Array -VserverContext $SVM -Key "try_first" -Value "volume_grow"
        Set-NcSnapshotAutodelete -Volume ${var.fsxn_volume_name} -Controller $Array -VserverContext $SVM -Key "state" -Value "on"
        Set-NcSnapshotReserve  -Volume ${var.fsxn_volume_name} -Controller $Array -Percentage 0
        Set-NcVolAutosize -Name ${var.fsxn_volume_name} -Controller $Array -VserverContext $SVM -Mode grow 

        $LunMap = $null
        $LocalIPAddress = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1" }

        $IGroup = (Get-NcIGroup -Name $InitiatorGroup -VserverContext $SVM)
        if($IGroup -eq $null) {
          $IGroup = New-NcIgroup -Name $InitiatorGroup -VserverContext $SVM -Protocol iscsi -Type "windows"
        }

        $IqnObj = (Get-NcIGroup -Initiator $IQN -VserverContext $SVM)
        if($IqnObj -eq $null) {
          $iqnCount = $IqnObj.Initiators | Where-Object { $_.InitiatorName -eq $IQN } | Measure-Object

          if($iqnCount.Count -eq 0) {
            $IqnObj = Add-NcIgroupInitiator -Initiator $IQN -VserverContext $SVM -Name $InitiatorGroup
          }
        } 

        # SQL Data LUN
        $dataLun = (Get-NcLun -Vserver $SVM -Volume vol1 -Path $DataLunPath -ErrorAction Stop)
        if($dataLun -eq $null) {
          $dataLun = New-NcLun -VserverContext $SVM -Path $DataLunPath -Size $DataLunSize -OsType "windows_2008"
        }

        $Lun = Get-NcLun -Path $DataLunPath -Vserver $SVM
        $LunMap = Get-NcLunMap -VserverContext $SVM -Path $DataLunPath -ErrorAction Stop 

        if($LunMap -eq $null) {
          $LunMap = Add-NcLunMap -InitiatorGroupName $InitiatorGroup -VserverContext $SVM -Path $DataLunPath
        }

        # SQL Log LUN
        $logLun = (Get-NcLun -Vserver $SVM -Volume vol1 -Path $LogLunPath -ErrorAction Stop)
        if($logLun -eq $null) {
          $logLun = New-NcLun -VserverContext $SVM -Path $LogLunPath -Size $LogLunSize -OsType "windows_2008"
        }

        $Lun = Get-NcLun -Path $LogLunPath -Vserver $SVM
        $LunMap = Get-NcLunMap -VserverContext $SVM -Path $LogLunPath -ErrorAction Stop

        if($LunMap -eq $null) {
          $LunMap = Add-NcLunMap -InitiatorGroupName $InitiatorGroup -VserverContext $SVM -Path $LogLunPath
        } 

        if($LunMap -ne $null) {
          #iSCSI IP addresses for Preferred and Standby subnets 
          $TargetPortalAddresses = @($iSCSIAddress1,$iSCSIAddress2) 
                                          
          #iSCSI Initator IP Address (Local node IP address) 
          $LocaliSCSIAddress = $LocalIPAddress.IPAddress
                                          
          #Connect to FSx for NetApp ONTAP file system 
          Foreach ($TargetPortalAddress in $TargetPortalAddresses) { 
            $targetPortal =  New-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -TargetPortalPortNumber 3260 -InitiatorPortalAddress $LocaliSCSIAddress 
            if($targetPortal -ne $null) {
              Write-Host "Created a new iSCSI Target Portal: $($TargetPortalAddress)"
            } else {
              Write-Host "Failed to create a new iSCSI Target Portal: $($TargetPortalAddress)"
            }
          } 
                                          
          #Add MPIO support for iSCSI 
          $mpioSupportedHW = New-MSDSMSupportedHW -VendorId MSFT2005 -ProductId iSCSIBusType_0x9 
          if($mpioSupportedHW -eq $null) {
            Write-Host "Failed to add MPIO support"
          }
                            
          Write-Host "Establishing 8 connections per target portal"
              
          $targetFailed = $false                            
          #Establish iSCSI connection 
          for($count=0; $count -lt $iSCSISessionsPerTarget; $count++){
            Foreach($TargetPortalAddress in $TargetPortalAddresses)
            {
              $target = Get-IscsiTarget | Connect-IscsiTarget -IsMultipathEnabled $true -TargetPortalAddress $TargetPortalAddress -InitiatorPortalAddress $LocaliSCSIAddress -IsPersistent $true 
            }

            if($target.IsConnected -ne $true) {
              $targetFailed = $true
              Write-Host "One of the connections to iSCSI Target Portal Failed. Portal - $($TargetPortalAddress)"
            }
          } 

          if($targetFailed) {
            Write-Host "One or more connections to the Target Portal Failed"
          } else {
            Write-Host "Established $iSCSISessionsPerTarget connections to the two target portals"
          }
                                          
          #Set the MPIO Policy to Round Robin 
          Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR 

          Write-Host "Getting Disks"
          $disks = Get-Disk | Where-Object { $_.FriendlyName -eq "NETAPP LUN C-Mode" -and $_.OperationalStatus -eq "Offline" } 
          Write-Host "Found NetApp Disks Offline: $(($disks | Measure-Object).Count)"

          $formatDataDisk = $true

          foreach( $disk in $disks) {
            if($formatDataDisk) {
              CreateDisk -Drive "D:" -DriveLabel "SQL Data" 
              $formatDataDisk = $false
            } 
            else 
            {
              CreateDisk -Drive "E:" -DriveLabel "SQL Log" 
            }
          }
        }
      }

      Start-Sleep -Seconds 10 
      Write-Host "Checking for SQL Volumes"
      if((Get-Volume | Where-Object { $_.FileSystemLabel -cmatch "SQL"  } | Measure-Object).Count -lt 2) {
         Write-Host "SQL Data or SQL Log volume is not found"
         Write-Host "Exiting the script."
         exit
      }
      Write-Host "SQL Volumes found"

      # Disable Encryption Warning 
      Set-DbatoolsConfig -Name Import.EncryptionMessageCheck -Value $false -PassThru | Register-DbatoolsConfig
      
      # Set the SQL Certificate to be trusted for the Powershell Module
      Set-DbaToolsConfig -fullname 'sql.connection.trustcert' -value $true -Register

      $DataVolume = Get-Volume | Where-Object { $_.FileSystemLabel -like "SQL Data"  }
      $LogVolume = Get-Volume | Where-Object { $_.FileSystemLabel -like "SQL Log"  }

      Write-Host "Data Volumes is assigned $($DataVolume.DriveLetter) drive and Log Volume is assigned $($LogVolume.DriveLetter) drive"
      $DBObject = Get-DbaDefaultPath -SqlInstance "localhost"
      if($DBObject.Data -eq "$($DataVolume.DriveLetter):" -and $DBObject.Log -eq "$($LogVolume.DriveLetter):") {
          Write-Host "DB Paths already set"
          exit
      }

      if($DataVolume -ne $null) {
        # Set the Default Path for Data Folder
        $setPathStatus = Set-DbaDefaultPath -SqlInstance "localhost"  -Type Data -Path "$($DataVolume.DriveLetter):" -ErrorAction Continue
        if($setPathStatus.Data -eq "$($DataVolume.DriveLetter):") {
            Write-Host "SQL Default Data Drive is set"
        }    
      } else {
        Write-Host "SQL Data Volume not found"
      }
      
      if($LogVolume -ne $null) {
        # Set the Default Path for Log Folder
        $setPathStatus = Set-DbaDefaultPath -SqlInstance "localhost"  -Type Log -Path "$($LogVolume.DriveLetter):" -ErrorAction Continue
        if($setPathStatus.Log -eq "$($LogVolume.DriveLetter):") {
            Write-Host "SQL Default Log Drive is set"
        }    
      } else {
        Write-Host "SQL Log Volume not found"
      }

      # Restart the SQL Service
      $ServiceStatus = Restart-DbaService -SqlInstance localhost -WarningAction SilentlyContinue
      if($ServiceStatus.Status -eq "Successful") {
          Write-Host "SQL Server Restarted Successfully"
      }

      # Validate if Paths are set correctly
      $DBObject = Get-DbaDefaultPath -SqlInstance "localhost"
      if($DBObject.Data -eq "$($DataVolume.DriveLetter):" -and $DBObject.Log -eq "$($LogVolume.DriveLetter):") {
          Write-Host "Default Database and Log Paths set correctly"
      }

      InstallSampleDatabase -DataDrive $DataVolume.DriveLetter -LogDrive $LogVolume.DriveLetter
    </powershell>
    <persist>true</persist>
  EOT 

  tags = {
    creator = var.creator_tag
  }
}


