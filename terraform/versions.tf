terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # HCP Terraform backend configuration
  cloud {
    organization = "ravi-panchal-org"

    workspaces {
      name = "sandbox_workspace"
    }
  }
}
