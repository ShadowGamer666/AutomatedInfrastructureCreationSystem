variable "lb_default_ami" {}
variable "lb_region" {}
variable "lb_ec2_count" {}
variable "lb_ec2_type" {}
variable "lb_prevent_delete" {}
variable "lb_internal" {}
variable "lb_idle_timeout" {}
variable "lb_targetgroup_protocol" {}
variable "lb_targetgroup_healthcheck_endpoint" {}
variable "lb_targetgroup_healthly_codes" {}
variable "lb_targetgroup_port" {}
variable "lb_ec2_subnet_id" {}
variable "lb_ec2_security_group_id" {
  default = ""
}
variable "lb_vpc_id" {}
variable "lb_project_name" {}
variable "lb_associate_public_ip" {}
variable "lb_tags"{
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

data "aws_vpc" "lb_default_sg_vpc" {
  # Obtains details of the account's default VPC
  id = "${var.lb_vpc_id}"
}

resource "aws_security_group" "lb_default_security_group" {
  name = "${var.lb_project_name}DefaultEC2SecurityGroup"
  vpc_id = "${data.aws_vpc.lb_default_sg_vpc.id}"
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
  tags = "${var.lb_tags}"
}

resource "aws_instance" "lb_ec2_instance" {
  count = "${var.lb_ec2_count}"
  ami = "${var.lb_default_ami ? data.aws_ami.linux_ami.id : data.aws_ami.windows_ami.id}"
  availability_zone = "${var.lb_region}${count.index % 2 == 0 ? "a" : "b"}"
  associate_public_ip_address = "${var.lb_associate_public_ip}"
  instance_type = "${var.lb_ec2_type}"
  credit_specification {
    cpu_credits = "standard"
  }
  key_name = "${aws_key_pair.lb_public_key_pair.key_name}"
  security_groups = ["${var.lb_ec2_security_group_id != "" ? var.lb_ec2_security_group_id : aws_security_group.lb_default_security_group.id}"]
  subnet_id = "${var.lb_ec2_subnet_id}"
  # Specified directly by user in the UI, to ensure compliance with company standards.
  tags = "${var.lb_tags}"
}

# Provides the Public Key that the user will use to authenticate SSH connections with EC2.
resource "tls_private_key" "lb_private_key_pair" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "lb_public_key_pair"{
  key_name = "${var.lb_project_name}AutoInfrastructureKey"
  public_key = "${tls_private_key.lb_private_key_pair.public_key_openssh}"
}

resource "aws_default_vpc" "default_vpc" {

}

# Obtains all of the subnet ID's in the default VPC.
data "aws_subnet_ids" "availible_subnets" {
  vpc_id = "${aws_default_vpc.default_vpc.id}"
}

resource "aws_lb" "aws_load_balancer" {
  name = "${var.lb_project_name}LoadBalancer"
  load_balancer_type = "application"
  internal = "${var.lb_internal}"
  idle_timeout = "${var.lb_idle_timeout}"
  enable_deletion_protection = "${var.lb_prevent_delete}"
  subnets = "${data.aws_subnet_ids.availible_subnets.ids}"
  tags = "${var.lb_tags}"
}

resource "aws_lb_target_group" "aws_lb_http_target_group" {
  name = "${var.lb_project_name}HTTPTargetGroup"
  protocol = "${var.lb_targetgroup_protocol}"
  port = "${var.lb_targetgroup_port}"
  # Creates pre-configured HealthCheck for LB resources.
  # DISABLED BY DEFAULT!!!
  health_check {
    enabled = true
    path = "${var.lb_targetgroup_healthcheck_endpoint}"
    matcher = "${var.lb_targetgroup_healthly_codes}"
    protocol = "${var.lb_targetgroup_protocol}"
    port = "${var.lb_targetgroup_port}"
  }
  vpc_id = "${aws_default_vpc.default_vpc.id}"
  tags = "${var.lb_tags}"
}

resource "aws_lb_target_group_attachment" "aws_instance_attachment" {
  count = "${var.lb_ec2_count}"
  target_group_arn = "${aws_lb_target_group.aws_lb_http_target_group.arn}"
  target_id = "${aws_instance.lb_ec2_instance[count.index].id}"
  port = "${var.lb_targetgroup_port}"
}

output "lb_ec2_arns" {
  value = "${aws_instance.lb_ec2_instance[*].arn}"
}

output "lb_ec2_ids" {
  value = "${aws_instance.lb_ec2_instance[*].id}"
}

output "lb_ec2_private_ips"{
  value = "${aws_instance.lb_ec2_instance[*].private_ip}"
}

output "lb_ec2_public_ips" {
  value = "${aws_instance.lb_ec2_instance[*].public_ip}"
}

output "lb_arn"{
  value = "${aws_lb.aws_load_balancer.arn}"
}

output "lb_id"{
  value = "${aws_lb.aws_load_balancer.id}"
}

output "lb_targetgroup_arn" {
  value = "${aws_lb_target_group.aws_lb_http_target_group.arn}"
}

output "lb_targetgroup_id" {
  value = "${aws_lb_target_group.aws_lb_http_target_group.id}"
}

output "lb_ec2_private_key" {
  value = "${tls_private_key.lb_private_key_pair.private_key_pem}"
}

output "lb_ec2_public_key"{
  value = "${tls_private_key.lb_private_key_pair.public_key_pem}"
}