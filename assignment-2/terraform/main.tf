# ---------- IAM policy JSON ----------
data "aws_iam_policy_document" "s3_read_only" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}

data "aws_iam_policy_document" "s3_create_put_no_read" {
  # Allow creating buckets and putting objects, but do NOT allow GetObject/List.
  statement {
    actions = [
      "s3:CreateBucket",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectTagging",
      "s3:PutBucketAcl",
      "s3:PutBucketTagging",
      "s3:ListAllMyBuckets" # optional to allow checking bucket list in account
    ]
    resources = ["*"]
  }
  # Explicit deny for reading
  statement {
    sid     = "DenyS3ReadOps"
    effect  = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}

resource "aws_iam_role" "role_read_only" {
  name               = "assignment2_s3_read_only"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role" "role_uploader" {
  name               = "assignment2_s3_uploader"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "policy_read_only" {
  name   = "assignment2_s3_read_only_policy"
  policy = data.aws_iam_policy_document.s3_read_only.json
}

resource "aws_iam_policy" "policy_uploader" {
  name   = "assignment2_s3_uploader_policy"
  policy = data.aws_iam_policy_document.s3_create_put_no_read.json
}

resource "aws_iam_role_policy_attachment" "attach_read" {
  role       = aws_iam_role.role_read_only.name
  policy_arn = aws_iam_policy.policy_read_only.arn
}

resource "aws_iam_role_policy_attachment" "attach_upload" {
  role       = aws_iam_role.role_uploader.name
  policy_arn = aws_iam_policy.policy_uploader.arn
}

# Instance profile for uploader role
resource "aws_iam_instance_profile" "uploader_profile" {
  name = "assignment2_uploader_profile"
  role = aws_iam_role.role_uploader.name
}

# Create S3 bucket (private)
resource "aws_s3_bucket" "logs_bucket" {
  bucket = var.bucket_name
  acl    = "private"

  versioning {
    enabled = false
  }

  lifecycle_rule {
    id      = "delete-logs-after-7-days"
    enabled = true

    prefix = "" # apply to all objects
    expiration {
      days = 7
    }
  }

  tags = {
    Name = "assignment2-logs"
  }
}

# EC2 security group (allow SSH for admin if key provided)
resource "aws_security_group" "ec2_sg" {
  name        = "assignment2_ec2_sg"
  description = "Allow SSH from anywhere (change for production)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

output "subnet_ids" {
  value = data.aws_subnets.default.ids
}


# user-data: create shutdown script that uploads logs to S3
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh.tpl")

  vars = {
    bucket_name = var.bucket_name
    DEST_PREFIX = var.DEST_PREFIX
    TS          = var.TS
  }
}

resource "aws_instance" "app" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name          # <--- important
  subnet_id     = data.aws_subnets.default.ids[0]
  security_groups = [aws_security_group.ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.uploader_profile.name
  user_data     = data.template_file.user_data.rendered
  tags = {
    Name = "assignment2-ec2-uploader"
  }
}