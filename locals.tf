# ==============================================================================
# Local Values
# ==============================================================================
# Feature: EC2 Instance with ALB and Nginx Infrastructure
# Maps to: FR-018 (resource tagging)
# Task: T007

locals {
  # Common resource naming prefix
  name_prefix = "ec2-alb-nginx"

  # Merged tags for all resources
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      Project     = "ec2-alb-nginx"
      ManagedBy   = "terraform"
      Feature     = "ec2-alb-nginx-gh29"
      Application = "ec2-alb-nginx"
    }
  )

  # Availability zones (first 2 zones in region for 2-AZ deployment)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  # Instance count (fixed to 2 for 2-AZ deployment per FR-001)
  instance_count = var.instance_count
}
