# Sample Deployment for SQL Server on EC2 with Amazon FSx for NetApp ONTAP

The sample terraform deployment will create a Single-AZ Amazon FSx for NetApp ONTAP filesystem, create two LUN's on FSxN volume, deploy EC2 instance with SQL Server 2022 Standard and attach the FSxN LUN's as **SQL Data** and **SQL Log** volumes.

## Pre-Requisites

- Setup Terraform
- Create an IAM Role and attach the policy "AmazonSSMReadOnlyAccess"

## Configuration

- Set the parameters in terraform.tfvars
  - aws_location
  - availability_zones
  - ec2_instance_keypair
  - ec2_iam_role
  - creator
  - environment

## Sample terraform.tfvars
```ini 
creator_tag           = "<Creator Tag>"
environment           = "Demo"
aws_location          = "<AWS Region>"
availability_zones    = ["<Availability Zone 1>", "<Availability Zone 2>"]
ec2_instance_type     = "t3.2xlarge"
ec2_instance_keypair  = "<EC2 Instance Key Pair>"
ec2_iam_role          = "<IAM Role>"
fsxn_password         = "<Password for fsxadmin>"
volume_security_style = "MIXED"
vpc_cidr              = "10.0.0.0/16"
public_subnets_cidr   = ["10.0.0.0/20", "10.0.16.0/20"]
private_subnets_cidr  = ["10.0.128.0/20", "10.0.144.0/20"]
```

#### EC2 IAM Role

The role is required to fetch the password for fsxadmin from SSM Secured Parameters. Terraform creates an SSM Paramter which is retrieved via the powershell script of EC2 instance. The role allows the retrieval of the parameter and execute the necessary operations on the filesystem.

Alternatively, the password can also be entered in the user_data section found in the ec2-sql.tf file (not recommended).

#### EC2 Configuration

The EC2 Configuration can take about 10 mins and may vary depending on the instance type selected

> **Note:**
> This sample deployment is not meant for production use.
