# Master Project to create all of the Central Server and Default Infrestructure required by the system.
provider "aws" {
  # These account details will be provided by the user.
  region = "${var.availibility_zone}"
}

variable "availibility_zone" {
  default = "eu-west-1"
}
variable "central_server_tags" {
  type = "map"
  default = {
    Service = "AutomatedInfrastructureCreationService"
    Env = "CentralServer"
  }
}

module "central_server_ec2" {
  source = "../../Modules/aws_ec2/standard_ec2"
  ec2_default_ami = true
  ec2_project_name = "AutomatedInfrastructureCreationEC2"
  ec2_tags = "${var.central_server_tags}"
  ec2_type = "t3.micro"
  ec2_region = "${var.availibility_zone}"
  ec2_subnet_id = "${aws_subnet.central_default_subneta.id}"
  ec2_security_group_id = "${aws_security_group.central_default_security_group.id}"
  ec2_vpc_id = "${aws_vpc.central_default_vpc.id}"
  ec2_associate_public_ip = true
}

resource "aws_vpc" "central_default_vpc" {
  cidr_block = "10.0.0.0/24"
  enable_dns_hostnames = true
  tags = "${var.central_server_tags}"
}

resource "aws_eip" "ip-test-env" {
  instance = "${module.central_server_ec2.standard_ec2_id}"
  vpc = true
}

# This setup allows sections of the Subnet to remain private.
resource "aws_subnet" "central_default_subneta" {
  # cidrsubnet(cidrblock, new_mask, zero-based index (Difference between old/new mask))
  cidr_block = "${cidrsubnet(aws_vpc.central_default_vpc.cidr_block, 3, 1)}"
  vpc_id = "${aws_vpc.central_default_vpc.id}"
  availability_zone = "${var.availibility_zone}a"
  tags = "${var.central_server_tags}"
}

resource "aws_subnet" "central_default_subnetb" {
  # cidrsubnet(cidrblock, new_mask, zero-based index (Difference between old/new mask))
  cidr_block = "${cidrsubnet(aws_vpc.central_default_vpc.cidr_block, 3, 2)}"
  vpc_id = "${aws_vpc.central_default_vpc.id}"
  availability_zone = "${var.availibility_zone}b"
  tags = "${var.central_server_tags}"
}

resource "aws_security_group" "central_default_security_group" {
  name = "DefaultEC2SecurityGroup"
  vpc_id = "${aws_vpc.central_default_vpc.id}"
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
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
  tags = "${var.central_server_tags}"
}

# Sets up my account's default internet gateway and routing tables.
resource "aws_internet_gateway" "central_default_gateway" {
  vpc_id = "${aws_vpc.central_default_vpc.id}"
  tags = "${var.central_server_tags}"
}

//subnets.tf
resource "aws_route_table" "route-table-test-env" {
  vpc_id = "${aws_vpc.central_default_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.central_default_gateway.id}"
  }
  tags = "${var.central_server_tags}"
}
resource "aws_route_table_association" "subnet-associationa" {
  subnet_id      = "${aws_subnet.central_default_subneta.id}"
  route_table_id = "${aws_route_table.route-table-test-env.id}"
}

resource "aws_route_table_association" "subnet-associationb" {
  subnet_id      = "${aws_subnet.central_default_subnetb.id}"
  route_table_id = "${aws_route_table.route-table-test-env.id}"
}

resource "aws_db_subnet_group" "default_db_subnet_group" {
  name = "default_rds_subnet_group"
  subnet_ids = ["${aws_subnet.central_default_subneta.id}","${aws_subnet.central_default_subnetb.id}"]
  tags = "${var.central_server_tags}"
}

output "ec2_private_key" {
  value = "${module.central_server_ec2.ec2_private_key}"
}

output "ec2_public_key" {
  value = "${module.central_server_ec2.ec2_public_key}"
}

output "ec2_private_ip" {
  value = "${module.central_server_ec2.standard_ec2_private_ip}"
}

output "ec2_public_ip" {
  value = "${module.central_server_ec2.standard_ec2_public_ip}"
}