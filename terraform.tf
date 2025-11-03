terraform {
  required_version = ">= 1.0"

  # HCP Terraform backend configuration
  cloud {
    organization = "hashi-demos-apj"

    workspaces {
      name = "webapp-sandbox"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# AWS Provider configuration
# Credentials managed via HCP Terraform workspace variable sets
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "webapp-infrastructure"
      Workspace   = terraform.workspace
    }
  }
}
