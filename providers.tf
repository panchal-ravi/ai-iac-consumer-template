# AWS Provider configuration
# Feature: 001-public-ec2-password-auth
# Region: ap-southeast-1 (Singapore)

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Feature     = "001-public-ec2-password-auth"
      Workspace   = "sandbox_public_ec2_dev"
    }
  }
}
