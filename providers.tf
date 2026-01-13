# AWS Provider Configuration
# Region is specified via variable with validation to enforce ap-southeast-1
provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
