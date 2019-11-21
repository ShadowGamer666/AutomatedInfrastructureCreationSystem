provider "aws" {
  # These account details will be provided by the user.
  region = "${var.region}"
}

variable "region" {}
variable "project_name" {}
variable "db_username" {}
variable "db_password" {}
variable "rds_type" {
  default = "db.t3.small"
}
variable "rds_engine" {
  default = "mysql"
}
variable "rds_engine_version" {
  default = "8.0"
}
variable "rds_db_encryption" {
  default = false
}
variable "rds_kms_key_id" {
  default = ""
}
variable "rds_auto_minor_upgrade" {
  default = true
}
variable "rds_prevent_deletion" {
  default = false
}
variable "rds_apply_changes_immediately" {
  default = false
}
variable "rds_backup_retention_period" {
  default = 7
}
variable "rds_license_model" {
  default = ""
}
variable "rds_allocated_storage" {
  default = 10
}
variable "rds_enable_public_access" {
  default = false
}
variable "rds_vpc_id" {}
variable "rds_subnet_group_name" {}
variable "project_tags" {
  type = "map"
  default = {
    Default = "Automated using Terraform"
  }
}

module "aws_single_rds" {
  source = "../../Modules/aws_rds"
  rds_instance_type = "${var.rds_type}"
  rds_engine = "${var.rds_engine}"
  rds_engine_version = "${var.rds_engine_version}"
  rds_encrypt_database = "${var.rds_db_encryption}"
  rds_kms_key_id = "${var.rds_kms_key_id}"
  rds_auto_minor_upgrade = "${var.rds_auto_minor_upgrade}"
  rds_prevent_deletion = "${var.rds_prevent_deletion}"
  rds_apply_immediately = "${var.rds_apply_changes_immediately}"
  rds_backup_retention = "${var.rds_backup_retention_period}"
  rds_license_model = "${var.rds_license_model}"
  rds_admin_password = "${var.db_password}"
  rds_admin_username = "${var.db_username}"
  rds_project_name = "${var.project_name}"
  rds_tags = "${var.project_tags}"
  rds_allocated_storage = "${var.rds_allocated_storage}"
  rds_enable_public_access = "${var.rds_enable_public_access}"
  rds_subnet_group_name = "${var.rds_subnet_group_name}"
  rds_vpc_id = "${var.rds_vpc_id}"
}