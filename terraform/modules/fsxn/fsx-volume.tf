resource "aws_fsx_ontap_volume" "fsxvol01" {
  name                       = "vol1"
  junction_path              = "/vol1"
  security_style             = var.fsxn_volume_security_style
  size_in_megabytes          = 1280000
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.fsxsvm01.id

  tiering_policy {
    name           = "AUTO"
    cooling_period = 2
  }
}
