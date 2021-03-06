variable "rds_instance_type" {
  default = "db.t3.small"
}
# The default for RDS instances is MySQL 8.0
# Currently Terraform resource 'allocation_storage' glitch prevent Aurora implementation.
variable "rds_engine" {
  default = "mysql"
}
variable "rds_engine_version" {
  default = "8.0"
}
variable "rds_encrypt_database" {
}
variable "rds_kms_key_id" {}
variable "rds_auto_minor_upgrade" {}
variable "rds_prevent_deletion" {}
variable "rds_apply_immediately" {}
variable "rds_backup_retention" {}
variable "rds_license_model" {}
variable "rds_allocated_storage" {}
variable "rds_project_name" {}
variable "rds_admin_username" {}
variable "rds_admin_password" {}
variable "rds_enable_public_access" {}
variable "rds_security_group_id" {
  default = ""
}
variable "rds_vpc_id" {}
variable "rds_subnet_group_name" {}
variable "rds_tags"{
  type = "map"
}

data "aws_vpc" "rds_default_sg_vpc" {
  id = "${var.rds_vpc_id}"
}

resource "aws_security_group" "rds_default_security_group" {
  name = "${var.rds_project_name}DefaultRDSSecurityGroup"
  vpc_id = "${data.aws_vpc.rds_default_sg_vpc.id}"
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 0
    protocol = "-1" # -1 Any Protocol
    to_port = 0
  }
  tags = "${var.rds_tags}"
}

resource "aws_db_instance" "rds_instance" {
  instance_class = "${var.rds_instance_type}"
  identifier = "${lower(var.rds_project_name)}rds"
  name = "${var.rds_project_name}DB"
  engine = "${var.rds_engine}"
  engine_version = "${var.rds_engine_version}"
  storage_encrypted = "${var.rds_encrypt_database}"
  kms_key_id = "${var.rds_kms_key_id}"
  auto_minor_version_upgrade = "${var.rds_auto_minor_upgrade}"
  deletion_protection = "${var.rds_prevent_deletion}"
  apply_immediately = "${var.rds_apply_immediately}"
  backup_retention_period = "${var.rds_backup_retention}"
  skip_final_snapshot = true
  # Only required for Oracle DB Instances.
  license_model = "${var.rds_license_model}"
  allocated_storage = "${var.rds_allocated_storage}"
  publicly_accessible = "${var.rds_enable_public_access}"
  # Both will be provided on demand by the user.
  username = "${var.rds_admin_username}"
  password = "${var.rds_admin_password}"
  db_subnet_group_name = "${var.rds_subnet_group_name}"
  vpc_security_group_ids = ["${var.rds_security_group_id != "" ? var.rds_security_group_id : aws_security_group.rds_default_security_group.id}"]
  tags = "${var.rds_tags}"
}

output "rds_arn" {
  value = "${aws_db_instance.rds_instance.arn}"
}

output "rds_id" {
  value = "${aws_db_instance.rds_instance.id}"
}

output "rds_dbname" {
  value = "${aws_db_instance.rds_instance.name}"
}