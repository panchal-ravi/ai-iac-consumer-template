# AWS Provider Configuration

provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources created by this provider
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}
