provider "aws" {
  # These account details will be provided by the user.
  region = "${var.region}"
}

variable "region" {}
variable "project_name" {}
variable "db_username" {}
variable "db_password" {}
variable "rds_subnet_group_name" {}
variable "ec2_subnet_id" {}
variable "ec2_vpc_id" {}
variable "s3_acl" {
  default = "private"
}
variable "s3_enable_versioning" {
  default = false
}
variable "s3_enable_expiration_rule" {
  default = false
}
variable "s3_expiration_period" {
  default = 90
}
variable "project_tags" {
  type = "map"
  default = {
    Default = "Automated using Terraform"
  }
}

module "aws_s3_bucket" {
  source = "../../Modules/aws_s3"
  s3_project_name = "${var.project_name}"
  s3_acl = "${var.s3_acl}"
  s3_enable_versioning = "${var.s3_enable_versioning}"
  s3_enable_expiration_rule = "${var.s3_enable_expiration_rule}"
  s3_file_expiration_period = "${var.s3_expiration_period}"
  s3_tags = "${var.project_tags}"
}
