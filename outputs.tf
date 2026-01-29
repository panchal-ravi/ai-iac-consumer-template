# ==============================================================================
# Output Values
# ==============================================================================
# Feature: EC2 Instance with ALB and Nginx Infrastructure

# ------------------------------------------------------------------------------
# EC2 Instance Outputs (User Story 1)
# ------------------------------------------------------------------------------

# T035: EC2 instance IDs
output "ec2_instance_ids" {
  description = "EC2 instance IDs for Nginx servers"
  value       = [module.ec2_instance_1.id, module.ec2_instance_2.id]
}

# T036: EC2 instance private IPs
output "ec2_instance_private_ips" {
  description = "Private IP addresses of EC2 instances"
  value       = [module.ec2_instance_1.private_ip, module.ec2_instance_2.private_ip]
}

# T037: EC2 availability zones
output "ec2_availability_zones" {
  description = "Availability zones where instances are deployed"
  value       = [module.ec2_instance_1.availability_zone, module.ec2_instance_2.availability_zone]
}

# ------------------------------------------------------------------------------
# ALB Outputs (User Story 2)
# ------------------------------------------------------------------------------

# T051: ALB DNS name
output "alb_dns_name" {
  description = "ALB DNS endpoint for HTTPS access"
  value       = aws_lb.main.dns_name
}

# T052: ALB ARN
output "alb_arn" {
  description = "ALB resource ARN"
  value       = aws_lb.main.arn
}

# T053: ALB zone ID
output "alb_zone_id" {
  description = "Route53 hosted zone ID for ALB"
  value       = aws_lb.main.zone_id
}

# T054: HTTPS endpoint
output "https_endpoint" {
  description = "Full HTTPS URL for accessing the application"
  value       = "https://${aws_lb.main.dns_name}"
}

# ------------------------------------------------------------------------------
# Target Group Outputs (User Story 3)
# ------------------------------------------------------------------------------

# T062: Target group ARN
output "target_group_arn" {
  description = "Target group ARN for EC2 instances"
  value       = aws_lb_target_group.nginx.arn
}

# T063: Target health check path
output "target_health_check_path" {
  description = "Health check path configured for target group"
  value       = "/"
}

# ------------------------------------------------------------------------------
# Security Group Outputs
# ------------------------------------------------------------------------------

output "ec2_security_group_id" {
  description = "Security group ID for EC2 instances"
  value       = module.ec2_security_group.security_group_id
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = module.alb_security_group.security_group_id
}

# ------------------------------------------------------------------------------
# IAM Outputs
# ------------------------------------------------------------------------------

output "iam_role_arn" {
  description = "IAM role ARN for EC2 instances"
  value       = aws_iam_role.ec2_instance.arn
}

output "iam_instance_profile_arn" {
  description = "IAM instance profile ARN for EC2 instances"
  value       = aws_iam_instance_profile.ec2_instance.arn
}

# ------------------------------------------------------------------------------
# Validation and Testing Outputs
# ------------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    region             = var.region
    environment        = var.environment
    instance_count     = local.instance_count
    instance_type      = var.instance_type
    availability_zones = [module.ec2_instance_1.availability_zone, module.ec2_instance_2.availability_zone]
    https_endpoint     = "https://${aws_lb.main.dns_name}"
    health_check_path  = "/"
  }
}
