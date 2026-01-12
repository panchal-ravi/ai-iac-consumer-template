# AWS Provider Configuration
# FR-001: AWS provider for EC2 instance deployment
# Constitution 3.1: Provider configuration in dedicated file

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = var.project_name
    }
  }
}
