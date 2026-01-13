# Local Values for Public EC2 Development Instance
# Feature: 001-public-ec2-dev
# Defines common tags and naming conventions per FR-017

locals {
  # Common resource tags (FR-017: Required tags for all resources)
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    CostCenter  = var.cost_center
    Feature     = var.feature_branch
    Workspace   = var.workspace_name
    GitHubIssue = "12"
  }

  # Naming conventions
  name_prefix = "${var.environment}-ec2"

  # Security group names
  sg_ssh_name = "${local.name_prefix}-ssh-sg"

  # Secrets Manager secret name
  secret_name = "${local.name_prefix}-ssh-password"

  # IAM role names
  instance_role_name    = "${local.name_prefix}-instance-role"
  instance_profile_name = "${local.name_prefix}-instance-profile"
}
