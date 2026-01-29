# ==============================================================================
# AWS Provider Configuration
# ==============================================================================
# Feature: EC2 Instance with ALB and Nginx Infrastructure
# Requirement: T006 - AWS provider with ap-southeast-1 region
# Region: Singapore (ap-southeast-1) per user requirements

provider "aws" {
  region = var.region

  default_tags {
    tags = var.common_tags
  }
}
