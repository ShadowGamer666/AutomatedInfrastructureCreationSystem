variable "ebs_default_ami"{}
variable "ebs_ec2_type" {}
variable "ebs_project_name" {}
variable "ebs_region" {}
variable "ebs_storage_size" {}
variable "ebs_encrypt" {}
variable "ebs_kms_key_id" {}
variable "ebs_ec2_public_key" {}
variable "ebs_tags"{
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

resource "aws_ebs_volume" "ebs_block_volume" {
  availability_zone = "${var.ebs_region}a"
  size = "${var.ebs_storage_size}"
  encrypted = "${var.ebs_encrypt}"
  tags = "${var.ebs_tags}"
  kms_key_id = "${var.ebs_kms_key_id}"
}

resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/sdh"
  instance_id = "${aws_instance.ebs_ec2_instance.id}"
  volume_id = "${aws_ebs_volume.ebs_block_volume.id}"
}

resource "aws_instance" "ebs_ec2_instance" {
  ami = "${var.ebs_default_ami ? data.aws_ami.linux_ami.id : data.aws_ami.windows_ami.id}"
  instance_type = "${var.ebs_ec2_type}"
  availability_zone = "${var.ebs_region}a"
  credit_specification {
    cpu_credits = "standard"
  }
  key_name = "${aws_key_pair.ebs_key_pair.key_name}"
  # Specified directly by user in the UI, to ensure compliance with company standards.
  tags = "${var.ebs_tags}"
}

# Provides the Public Key that the user will use to authenticate SSH connections with EC2.
resource "aws_key_pair" "ebs_key_pair"{
  key_name = "${var.ebs_project_name}AutoInfrastructureKey"
  public_key = "${file(var.ebs_ec2_public_key)}"
}

output "ebs_ec2_arn" {
  value = "${aws_instance.ebs_ec2_instance.arn}"
}

output "ebs_ec2_id" {
  value = "${aws_instance.ebs_ec2_instance.id}"
}

output "ebs_ec2_private_ip"{
  value = "${aws_instance.ebs_ec2_instance.private_ip}"
}

output "ebs_ec2_public_ip" {
  value = "${aws_instance.ebs_ec2_instance.public_ip}"
}

output "ebs_ebs_arn" {
  value = "${aws_ebs_volume.ebs_block_volume.arn}"
}

output "ebs_ebs_id" {
  value = "${aws_ebs_volume.ebs_block_volume.id}"
}

output "ebs_attachment_id" {
  value = "${aws_volume_attachment.ebs_attachment.id}"
}