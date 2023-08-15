variable "sql_instance_type" {
  description = "EC2 Instance Type for SQL Server"
  type        = string
  default     = "t3.2xlarge"
}

variable "ec2_iam_role" {
  description = "EC2 IAM Role with access to SSM Parameters"
  type        = string
}

variable "fsxn_admin_user" {
  description = "FSxN Admin User"
  type        = string
  default     = "fsxadmin"
}

variable "fsxn_password" {
  description = "FSxN Admin Passowrd"
  type        = string
  sensitive   = true
}

variable "fsxn_svm" {
  description = "FSxN SVM"
  type        = string
  default     = "svm01"
}

variable "fsxn_volume_name" {
  description = "FSxN Volume Name"
  type        = string
}

variable "fsxn_management_ip" {
  description = "FSxN Management IP"
  type        = list(string)
}

variable "instance_keypair" {
  description = "Value of the instance key pair"
  type        = string
}

variable "sql_subnet_id" {
  description = "Subnet Id for EC2 Instances"
  type        = string
}

variable "security_groups_ids" {
  description = "Security Groups for EC2 Instances"
  type        = list(string)
}

variable "creator_tag" {
  description = "Tag with the Key as Creator"
  type        = string
}

variable "fsxn_iscsi_ips" {
  description = "IP Address of the FSxN SVM iSCSI Protocol"
  type        = list(string)
}
