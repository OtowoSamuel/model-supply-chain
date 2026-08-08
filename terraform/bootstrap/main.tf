/**
 * Bootstrap - Run this ONCE before main Terraform
 * Creates S3 bucket + DynamoDB table for state storage
 *
 * Usage:
 *   cd terraform/bootstrap
 *   terraform init
 *   terraform apply
 *   # Then go back to terraform/ and uncomment the S3 backend
 */

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
  # Bootstrap uses LOCAL state (no S3 yet)
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "model-supply-chain"
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 Bucket for Terraform state
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "tf-state-${var.project_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name      = "Terraform State"
    ManagedBy = "terraform-bootstrap"
  }
}

# Enable versioning (recover from bad applies)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────────────────────────────────────
# DynamoDB table for state locking
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "tf-state-lock-${var.project_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "Terraform State Lock"
    ManagedBy = "terraform-bootstrap"
  }
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────────────────────
# Outputs - copy these into terraform/main.tf backend block
# ─────────────────────────────────────────────────────────────────────────────
output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_state_lock.name
}

output "backend_config" {
  description = "Paste this into terraform/main.tf backend block"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.bucket}"
      key            = "eks/terraform.tfstate"
      region         = "${var.aws_region}"
      encrypt        = true
      dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.name}"
    }
  EOT
}
