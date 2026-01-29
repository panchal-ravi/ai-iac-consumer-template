# ==============================================================================
# Terraform Version Constraints
# ==============================================================================
# Feature: EC2 Instance with ALB and Nginx Infrastructure
# Requirement: T005 - Terraform version >= 1.5.7 for latest features
# Constitution 2.1: HCP Terraform remote execution required

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
