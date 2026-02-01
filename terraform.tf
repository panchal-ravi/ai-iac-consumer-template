# =============================================================================
# Terraform Configuration
# Feature: 002-ec2-alb-nginx - EC2 Infrastructure with ALB and Nginx
# Purpose: Define Terraform version and required provider constraints
# =============================================================================

terraform {
  # T003: Terraform version constraint (>= 1.5.7)
  required_version = ">= 1.5.7"

  # Provider requirements
  required_providers {
    # T004: AWS provider requirement (hashicorp/aws ~> 6.0)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # T005: TLS provider requirement (hashicorp/tls ~> 4.0)
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
