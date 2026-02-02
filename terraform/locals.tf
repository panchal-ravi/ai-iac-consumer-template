# Local Values
# Feature: 003-ec2-alb-nginx
# Purpose: Computed values and common tags

locals {
  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Application = "nginx-web-server"
    ManagedBy   = "terraform"
    Feature     = "003-ec2-alb-nginx"
    GitHubIssue = "39"
    Workspace   = "sandbox_workspace"
    CostCenter  = "engineering-dev"
    CreatedDate = "2025-01-21"
    Region      = var.aws_region
  }

  # Subnet selection logic: Extract AZs and select first 2
  # Group subnets by availability zone
  subnets_by_az = {
    for subnet in data.aws_subnet.default :
    subnet.availability_zone => subnet.id...
  }

  # Get list of all availability zones (sorted for consistency)
  all_availability_zones = sort(keys(local.subnets_by_az))

  # Select first 2 availability zones
  selected_azs = slice(local.all_availability_zones, 0, 2)

  # Map selected AZs to subnet IDs (one subnet per AZ)
  selected_subnet_ids = [
    for az in local.selected_azs :
    local.subnets_by_az[az][0]
  ]

  # Additional locals will be added as needed for:
  # - Instance configuration maps
  # - User data template rendering

  # Instance configuration: Create instance configs for each AZ
  instance_configs = {
    for idx, az in local.selected_azs :
    az => {
      name      = "${var.project_name}-${var.environment}-ec2-az${idx + 1}"
      subnet_id = local.selected_subnet_ids[idx]
      az        = az
    }
  }

  # Nginx user data script with template variable substitution
  nginx_user_data = templatefile("${path.module}/user-data/nginx-bootstrap.sh", {
    domain_name = var.domain_name
    environment = var.environment
  })
}
