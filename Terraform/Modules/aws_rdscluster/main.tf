variable "rdscluster_count" {}
variable "rdscluster_instance_type" {}
variable "rdscluster_engine" {}
variable "rdscluster_backup_retention" {}
variable "rdscluster_prevent_delete" {}
variable "rdscluster_encrypt_database" {}
variable "rdscluster_kms_key_id" {
  default = ""
}
variable "rdscluster_apply_immediately" {}
variable "rdscluster_username" {}
variable "rdscluster_password" {}
variable "rdscluster_project_name" {}
variable "rdscluster_enable_public_access" {}
variable "rdscluster_subnet_group_name" {}
variable "rdscluster_security_group_id" {
  default = ""
}
variable "rdscluster_vpc_id" {}
variable "rdscluster_tags"{
  type = "map"
}

data "aws_vpc" "rds_default_sg_vpc" {
  id = "${var.rdscluster_vpc_id}"
}

resource "aws_security_group" "rdscluster_default_security_group" {
  name = "${var.rdscluster_project_name}DefaultRDSSecurityGroup"
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
  tags = "${var.rdscluster_tags}"
}

# Automatically assigns AZ zones based on the specified region.
resource "aws_rds_cluster" "rdscluster_central"{
  cluster_identifier = "${lower(var.rdscluster_project_name)}rds-cluster"
  engine = "${var.rdscluster_engine}"
  backup_retention_period = "${var.rdscluster_backup_retention}"
  deletion_protection = "${var.rdscluster_prevent_delete}"
  storage_encrypted = "${var.rdscluster_encrypt_database}"
  kms_key_id = "${var.rdscluster_kms_key_id}"
  apply_immediately = "${var.rdscluster_apply_immediately}"
  database_name = "${var.rdscluster_project_name}"
  master_username = "${var.rdscluster_username}"
  skip_final_snapshot = true
  master_password = "${var.rdscluster_password}"
  db_subnet_group_name = "${var.rdscluster_subnet_group_name}"
  vpc_security_group_ids = ["${var.rdscluster_security_group_id != "" ? var.rdscluster_security_group_id : aws_security_group.rdscluster_default_security_group.id}"]
  tags = "${var.rdscluster_tags}"
}

resource "aws_rds_cluster_instance" "rdscluster_instance" {
  count = "${var.rdscluster_count}"
  engine = "${var.rdscluster_engine}"
  cluster_identifier = "${aws_rds_cluster.rdscluster_central.id}"
  identifier = "${lower(var.rdscluster_project_name)}rds${count.index}"
  publicly_accessible = "${var.rdscluster_enable_public_access}"
  instance_class = "${var.rdscluster_instance_type}"
}

resource "aws_rds_cluster_endpoint" "rdscluster_endpoint" {
  cluster_endpoint_identifier = "${lower(var.rdscluster_project_name)}clusterendpoint"
  cluster_identifier = "${aws_rds_cluster.rdscluster_central.id}"
  custom_endpoint_type = "READER"
}

output "rdscluster_arn"{
  value = "${aws_rds_cluster.rdscluster_central.arn}"
}

output "rdscluster_id"{
  value = "${aws_rds_cluster.rdscluster_central.id}"
}

output "rdscluster_name" {
  value = "${aws_rds_cluster.rdscluster_central.database_name}"
}