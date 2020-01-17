provider "aws" {
  # These account details will be provided by the user.
  region = "${var.region}"
}

variable "region" {}
variable "project_name" {}
variable "db_username" {}
variable "db_password" {}
variable "rdscluster_instance_count" {
  default = 2
}
variable "rdscluster_instance_type" {
  default = "db.t3.small"
}
variable "rdscluster_engine" {
  default = "aurora-mysql"
}
variable "rdscluster_backup_retention_period" {
  default = 7
}
variable "rdscluster_prevent_deletion" {
  default = false
}
variable "rdscluster_db_encryption" {
  default = false
}
variable "rdscluster_kms_key_id" {
  default = ""
}
variable "rdscluster_apply_chanes_immediately" {
  default = false
}
variable "rdscluster_enable_public_access" {
  default = false
}
variable "ec2_vpc_id" {}
variable "ec2_subnet_id" {}
variable "rds_subnet_group_name" {}
variable "project_tags" {
  type = "map"
  default = {
    Default = "Automated using Terraform"
  }
}

module "aws_single_dbcluster" {
  source = "../../Modules/aws_rdscluster"
  rdscluster_count = "${var.rdscluster_instance_count}"
  rdscluster_instance_type = "${var.rdscluster_instance_type}"
  rdscluster_engine = "${var.rdscluster_engine}"
  rdscluster_backup_retention = "${var.rdscluster_backup_retention_period}"
  rdscluster_prevent_delete = "${var.rdscluster_prevent_deletion}"
  rdscluster_encrypt_database = "${var.rdscluster_db_encryption}"
  rdscluster_kms_key_id = "${var.rdscluster_kms_key_id}"
  rdscluster_apply_immediately = "${var.rdscluster_apply_chanes_immediately}"
  rdscluster_password = "${var.db_password}"
  rdscluster_project_name = "${var.project_name}"
  rdscluster_tags = "${var.project_tags}"
  rdscluster_username = "${var.db_username}"
  rdscluster_enable_public_access = "${var.rdscluster_enable_public_access}"
  rdscluster_subnet_group_name = "${var.rds_subnet_group_name}"
  rdscluster_vpc_id = "${var.ec2_vpc_id}"
}
