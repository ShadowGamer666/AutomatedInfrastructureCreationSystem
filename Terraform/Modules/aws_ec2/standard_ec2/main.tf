variable "ec2_default_ami"{}
variable "ec2_type" {}
variable "ec2_region" {}
variable "ec2_subnet_id" {}
variable "ec2_security_group_id" {
  default = ""
}
variable "ec2_project_name" {}
variable "ec2_vpc_id" {}
variable "ec2_associate_public_ip" {}
variable "ec2_tags"{
  type = "map"
}

# This defines my default AMI, Amazmon Linux 2
# Chosen because of resonable costs and pre-installed AWS support.
data "aws_ami" "linux_ami" {
  most_recent = true
  owners = ["amazon"]

  filter{
    name = "owner-alias"
    values = ["amazon"]
  }

  filter{
    name = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

# This additional AWS EBS Backed Windows AMI exists to provide
# support for Windows specific pakcages e.g. .NET, uses the latest.
data "aws_ami" "windows_ami"{
  most_recent = true
  owners = ["amazon"]

  filter{
    name = "platform"
    values = ["windows"]
  }

  filter{
    name = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_vpc" "ec2_default_sg_vpc" {
  # Obtains details of the account's default VPC
  id = "${var.ec2_vpc_id}"
}

resource "aws_security_group" "ec2_default_security_group" {
  name = "${var.ec2_project_name}DefaultEC2SecurityGroup"
  vpc_id = "${data.aws_vpc.ec2_default_sg_vpc.id}"
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
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 443
    to_port = 443
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
  tags = "${var.ec2_tags}"
}

resource "aws_instance" "ec2_instance" {
  ami = "${var.ec2_default_ami ? data.aws_ami.linux_ami.id : data.aws_ami.windows_ami.id}"
  instance_type = "${var.ec2_type}"
  associate_public_ip_address = "${var.ec2_associate_public_ip}"
  credit_specification {
    cpu_credits = "standard"
  }
  key_name = "${aws_key_pair.ec2_public_key_pair.key_name}"
  security_groups = ["${var.ec2_security_group_id != "" ? var.ec2_security_group_id : aws_security_group.ec2_default_security_group.id}"]
  subnet_id = "${var.ec2_subnet_id}"
  # Specified directly by user in the UI, to ensure compliance with company standards.
  tags = "${var.ec2_tags}"
}

# Provides the Public Key that the user will use to authenticate SSH connections with EC2.
resource "tls_private_key" "ec2_private_key_pair" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "ec2_public_key_pair"{
  key_name = "${var.ec2_project_name}AutoInfrastructureKey"
  public_key = "${tls_private_key.ec2_private_key_pair.public_key_openssh}"
}

output "standard_ec2_arn" {
  value = "${aws_instance.ec2_instance.arn}"
}

output "standard_ec2_id" {
  value = "${aws_instance.ec2_instance.id}"
}

output "standard_ec2_private_ip"{
  value = "${aws_instance.ec2_instance.private_ip}"
}

output "standard_ec2_public_ip" {
  value = "${aws_instance.ec2_instance.public_ip}"
}

output "ec2_private_key" {
  value = "${tls_private_key.ec2_private_key_pair.private_key_pem}"
}

output "ec2_public_key"{
  value = "${tls_private_key.ec2_private_key_pair.public_key_pem}"
}