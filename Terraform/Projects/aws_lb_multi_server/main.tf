provider "aws" {
  # These account details will be provided by the user.
  region = "${var.region}"
}

variable "region" {}
variable "project_name" {}
variable "db_username" {}
variable "db_password" {}
variable "ec2_use_default_ami" {
  default = true
}
variable "ec2_instance_count" {
  default = 2
}
variable "ec2_instance_type" {
  default = "t3.micro"
}
variable "lb_prevent_deletion" {
  default = false
}
variable "lb_internal" {
  # Web Application might be more common for this system.
  default = false
}
variable "lb_idle_connection_timeout" {
  default = 120
}
variable "targetgroup_protocol" {
  default = "HTTP"
}
variable "targetgroup_port" {
  default = 80
}
variable "targetgroup_healthcheck_endpoint" {
  default = "/HealthCheck"
}
variable "targetgroup_healthcheck_healthycodes" {
  # Counts all 2xx HTTP codes as success cases.
  default = "200-299"
}
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
variable "ec2_subnet_id" {}
variable "vpc_id" {}
variable "rdscluster_subnet_group_name" {}
variable "associate_public_ip_address" {
  default = true
}
variable "project_tags" {
  type = "map"
  default = {
    Default = "Automated using Terraform"
  }
}

module "aws_lb_multi_ec2s" {
  source = "../../Modules/aws_ec2/lb_ec2"
  lb_default_ami = "${var.ec2_use_default_ami}"
  lb_ec2_count = "${var.ec2_instance_count}"
  lb_ec2_type = "${var.ec2_instance_type}"
  lb_prevent_delete = "${var.lb_prevent_deletion}"
  lb_internal = "${var.lb_internal}"
  lb_idle_timeout = "${var.lb_idle_connection_timeout}"
  lb_targetgroup_protocol = "${var.targetgroup_protocol}"
  lb_targetgroup_port = "${var.targetgroup_port}"
  lb_targetgroup_healthcheck_endpoint = "${var.targetgroup_healthcheck_endpoint}"
  lb_targetgroup_healthly_codes = "${var.targetgroup_healthcheck_healthycodes}"
  lb_project_name = "${var.project_name}"
  lb_tags = "${var.project_tags}"
  lb_region = "${var.region}"
  lb_associate_public_ip = "${var.associate_public_ip_address}"
  lb_ec2_subnet_id = "${var.ec2_subnet_id}"
  lb_vpc_id = "${var.vpc_id}"
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
  rdscluster_subnet_group_name = "${var.rdscluster_subnet_group_name}"
  rdscluster_vpc_id = "${var.vpc_id}"
}

# Outputs Generated Public/Private Key files needed for EC2 access to the user.
output "ec2_private_key" {
  value = "${module.aws_lb_multi_ec2s.lb_ec2_private_key}"
}

output "ec2_public_key" {
  value = "${module.aws_lb_multi_ec2s.lb_ec2_public_key}"
}

output "ec2_private_ip" {
  value = "${module.aws_lb_multi_ec2s.lb_ec2_private_ips}"
}

output "ec2_public_ip" {
  value = "${module.aws_lb_multi_ec2s.lb_ec2_public_ips}"
}