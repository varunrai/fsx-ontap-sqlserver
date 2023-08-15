resource "aws_fsx_ontap_file_system" "fsx_ontap_fs" {
  storage_capacity    = 1024
  throughput_capacity = 128
  deployment_type     = "SINGLE_AZ_1"
  subnet_ids          = [var.fsxn_subnet_id]
  preferred_subnet_id = var.fsxn_subnet_id
  fsx_admin_password  = var.fsxn_password
  security_group_ids = var.fsxn_security_group_ids

  tags = {
    "Name" = "${var.creator_tag}-FSxN-Demo-1"
  }
}



