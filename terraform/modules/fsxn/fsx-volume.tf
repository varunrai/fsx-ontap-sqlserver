resource "aws_fsx_ontap_volume" "fsxn_sql_data_volume" {
  name                       = "${local.server_name}_data"
  junction_path              = "/${local.server_name}_data"
  security_style             = "NTFS"
  size_in_megabytes          = 10240000
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.fsxsvm01.id
  skip_final_backup          = true
  tiering_policy {
    name = "SNAPSHOT_ONLY"
  }
}

resource "aws_fsx_ontap_volume" "fsxn_sql_log_volume" {
  name                       = "${local.server_name}_log"
  junction_path              = "/${local.server_name}_log"
  security_style             = "NTFS"
  size_in_megabytes          = 10240000
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.fsxsvm01.id
  skip_final_backup          = true
  tiering_policy {
    name = "SNAPSHOT_ONLY"
  }
}
