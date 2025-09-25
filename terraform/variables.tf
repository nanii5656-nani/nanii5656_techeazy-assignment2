variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "nanistoragebucket23022002"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH (optional)"
  type        = string
  default     = "techeazy_key"
}

variable "ami" {
  description = "AMI ID to use for EC2 (Ubuntu 22.04 recommended)"
  type        = string
  default     = "ami-0360c520857e3138f"
}

locals {
  require_bucket = length(var.bucket_name) > 0
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# fail early if bucket_name not provided
resource "null_resource" "must_set_bucket" {
  count = local.require_bucket ? 0 : 1
  provisioner "local-exec" {
    command = "echo 'ERROR: bucket_name variable must be provided' && exit 1"
  }
}

variable "DEST_PREFIX" {
  description = "Destination S3 bucket prefix for uploaded files"
  type        = string
  default     = "uploads"
}

variable "TS" {
  description = "Timestamp or label for this deployment"
  type        = string
  default     = "manual-run"
}
