# Provider Configuration
# Feature: 003-ec2-alb-nginx
# Purpose: Configure AWS and TLS providers

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "tls" {
  # TLS provider configuration
  # No additional configuration required
}
