variable "fsxn_password" {
  description = "Default Password"
  type        = string
  sensitive   = true
}

variable "fsxn_volume_security_style" {
  description = "Default Volume Security Style"
  type        = string
  default     = "MIXED"
}

variable "fsxn_subnet_id" {
  description = "FSxN Deployment Subnet ID"
  type        = string
}

variable "fsxn_security_group_ids" {
  description = "FSxN Security Groups IDs"
  type        = list(string)
}

variable "creator_tag" {
  description = "Value of the creator tag"
  type        = string
}
