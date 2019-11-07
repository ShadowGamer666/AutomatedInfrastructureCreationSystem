variable "s3_project_name" {}
variable "s3_acl" {}
variable "s3_enable_versioning" {}
variable "s3_enable_expiration_rule" {}
variable "s3_file_expiration_period" {}
variable "s3_tags"{
  type = "map"
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${lower(var.s3_project_name)}bucket"
  # Preconfigured Priacy/Security Rules.
  acl = "${var.s3_acl}"
  # Good for setting up backup systems with these buckets.
  versioning {
    enabled = "${var.s3_enable_versioning}"
  }
  # Creates pre-configured file management rules for less experienced users.
  # DISABLED BY DEFAULT!!!
  lifecycle_rule {
    id = "${var.s3_project_name}FileExpirationRule"
    enabled = "${var.s3_enable_expiration_rule}"
    expiration {
      days = "${var.s3_file_expiration_period}"
    }
  }
  tags = "${var.s3_tags}"
}

output "s3_arn" {
  value = "${aws_s3_bucket.s3_bucket.arn}"
}

output "s3_id" {
  value = "${aws_s3_bucket.s3_bucket.id}"
}