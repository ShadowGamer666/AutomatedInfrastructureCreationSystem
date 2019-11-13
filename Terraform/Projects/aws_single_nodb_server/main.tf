provider "aws" {
  # These account details will be provided by the user.
  region = "${var.region}"
}

variable "region" {}
variable "project_name" {}
variable "db_username" {}
variable "db_password" {}
variable "public_key_filepath" {}
variable "ec2_type" {
  default = "t3.micro"
}
variable "ec2_use_default_ami" {
  default = true
}
variable "ec2_subnet_id" {}
variable "ec2_vpc_id" {}
variable "associate_public_ip_address" {
  default = true
}
variable "project_tags" {
  type = "map"
  default = {
    Default = "Automated using Terraform"
  }
}

module "aws_single_ec2_instance" {
  source = "../../Modules/aws_ec2/standard_ec2"
  ec2_project_name = "${var.project_name}"
  ec2_public_key = "${var.public_key_filepath}"
  ec2_type = "${var.ec2_type}"
  ec2_default_ami = "${var.ec2_use_default_ami}"
  ec2_tags = "${var.project_tags}"
  ec2_associate_public_ip = "${var.associate_public_ip_address}"
  ec2_region = "${var.region}"
  ec2_subnet_id = "${var.ec2_subnet_id}"
  ec2_vpc_id = "${var.ec2_vpc_id}"
}