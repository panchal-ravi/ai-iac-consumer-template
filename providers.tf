# AWS Provider Configuration
# Region: ap-southeast-1 (Singapore) per user requirements
# Provider version: >= 6.0 (specified in versions.tf)

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
