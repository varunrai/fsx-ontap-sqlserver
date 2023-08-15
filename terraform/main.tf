
terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.66.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2.0"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region = var.aws_location
  default_tags {
    tags = {
      "creator" = var.creator_tag
    }
  }
}

module "fsxontap" {
  source                  = "./modules/fsxn"
  fsxn_password           = var.fsxn_password
  fsxn_subnet_id          = aws_subnet.private_subnet[0].id
  fsxn_security_group_ids = [aws_security_group.sg-fsx.id]
  creator_tag             = var.creator_tag
}

module "sqlserver" {
  source = "./modules/ec2"

  sql_instance_type   = var.ec2_instance_type
  instance_keypair    = var.ec2_instance_keypair
  sql_subnet_id       = aws_subnet.public_subnet[0].id
  security_groups_ids = [aws_security_group.sg-fsx.id, aws_security_group.sg-AllowRemoteToEC2.id]
  fsxn_password       = var.fsxn_password
  fsxn_iscsi_ips      = module.fsxontap.fsx_svm_iscsi_endpoints
  fsxn_svm            = module.fsxontap.fsx_svm.name
  fsxn_management_ip  = module.fsxontap.fsx_management_management_ip
  fsxn_volume_name    = module.fsxontap.fsx_volume.name
  ec2_iam_role        = var.ec2_iam_role
  creator_tag         = var.creator_tag
  depends_on          = [module.fsxontap]
}
