# Terraform Version Constraints
# Terraform >= 1.5.7 per project requirements
# AWS Provider >= 6.0 for latest features and bug fixes

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
