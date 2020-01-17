provider "aws" {
  # These account details will be provided by the user.
  region = "${var.region}"
}

variable "region" {}
variable "project_name" {}
variable "db_username" {}
variable "db_password" {}
# These variables will be passed as 'null' without additional user specification.
# This allow automated optional specification of parameters.
variable "ec2_type" {
  default = "t3.micro"
}
variable "ec2_use_default_ami" {
  default = true
}
variable "ec2_associate_public_ip_address" {
  default = true
}
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
variable "rds_subnet_group_name" {}
variable "ec2_subnet_id" {}
variable "ec2_vpc_id" {}
variable "project_tags" {
  type = "map"
  default = {
    Default = "Automated using Terraform"
  }
}

module "aws_single_ec2_instance" {
  source = "../../Modules/aws_ec2/standard_ec2"
  ec2_project_name = "${var.project_name}"
  ec2_type = "${var.ec2_type}"
  ec2_default_ami = "${var.ec2_use_default_ami}"
  ec2_tags = "${var.project_tags}"
  ec2_associate_public_ip = "${var.ec2_associate_public_ip_address}"
  ec2_region = "${var.region}"
  ec2_subnet_id = "${var.ec2_subnet_id}"
  ec2_vpc_id = "${var.ec2_vpc_id}"
}

module "aws_single_rds_instance" {
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
  rds_allocated_storage = "${var.rds_allocated_storage}"
  rds_enable_public_access = "${var.rds_enable_public_access}"
  rds_admin_password = "${var.db_password}"
  rds_admin_username = "${var.db_username}"
  rds_project_name = "${var.project_name}"
  rds_tags = "${var.project_tags}"
  rds_subnet_group_name = "${var.rds_subnet_group_name}"
  rds_vpc_id = "${var.ec2_vpc_id}"
}

output "ec2_private_key" {
  value = "${module.aws_single_ec2_instance.ec2_private_key}"
}

output "ec2_public_key" {
  value = "${module.aws_single_ec2_instance.ec2_public_key}"
}

output "ec2_private_ip" {
  value = "${module.aws_single_ec2_instance.standard_ec2_private_ip}"
}

output "ec2_public_ip" {
  value = "${module.aws_single_ec2_instance.standard_ec2_public_ip}"
}
