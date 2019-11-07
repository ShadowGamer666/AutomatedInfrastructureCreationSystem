variable "ec2_default_ami"{}
variable "ec2_type" {}
variable "ec2_project_name" {}
variable "ec2_public_key" {}
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

resource "aws_instance" "ec2_instance" {
  ami = "${var.ec2_default_ami ? data.aws_ami.linux_ami.id : data.aws_ami.windows_ami.id}"
  instance_type = "${var.ec2_type}"
  credit_specification {
    cpu_credits = "standard"
  }
  key_name = "${aws_key_pair.ec2_key_pair.key_name}"
  # Specified directly by user in the UI, to ensure compliance with company standards.
  tags = "${var.ec2_tags}"
}

# Provides the Public Key that the user will use to authenticate SSH connections with EC2.
resource "aws_key_pair" "ec2_key_pair"{
  key_name = "${var.ec2_project_name}AutoInfrastructureKey"
  public_key = "${file(var.ec2_public_key)}"
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