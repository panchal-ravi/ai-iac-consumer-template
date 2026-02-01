# =============================================================================
# Provider Configuration
# Feature: 002-ec2-alb-nginx - EC2 Infrastructure with ALB and Nginx
# Purpose: Configure Terraform provider plugins for AWS and TLS
# =============================================================================

# T006: AWS Provider - Configure region from variable
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy    = "Terraform"
      Terraform    = "true"
      Feature      = "002-ec2-alb-nginx"
      Workspace    = "sandbox_workspace"
      Organization = "ravi-panchal-org"
    }
  }
}

# T007: TLS Provider - No configuration required
provider "tls" {
  # No configuration required for TLS provider
}
