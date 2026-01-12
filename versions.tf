# Terraform version constraints for EC2 Development Instance
# FR-001: Terraform >= 1.5.0 for HCP Terraform compatibility
# Constitution 3.1: Version constraints mandatory

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
