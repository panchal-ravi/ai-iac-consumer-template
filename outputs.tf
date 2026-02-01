# =============================================================================
# Output Values
# Feature: 002-ec2-alb-nginx - EC2 Infrastructure with ALB and Nginx
# Purpose: Expose key infrastructure attributes for external consumption
# =============================================================================

# T041: ALB DNS name output
output "alb_dns_name" {
  description = "ALB DNS name for HTTPS access"
  value       = module.alb.dns_name
}

# T042: ALB ARN output
output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.arn
}

# T043: Target group ARN output
output "target_group_arn" {
  description = "Target group ARN for health checks"
  value       = module.alb.target_groups["default"].arn
}

# T044: EC2 instance IDs output
output "ec2_instance_ids" {
  description = "EC2 instance IDs by availability zone"
  value = {
    for az, instance in module.ec2_instance : az => instance.id
  }
}

# T045: ACM certificate ARN output
output "acm_certificate_arn" {
  description = "ACM certificate ARN for self-signed TLS certificate"
  value       = aws_acm_certificate.self_signed.arn
  sensitive   = false
}

# T046: EC2 security group ID output
output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = module.ec2_security_group.security_group_id
}

# T047: ALB security group ID output
output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.alb_security_group.security_group_id
}

# Additional useful outputs
output "vpc_id" {
  description = "VPC ID (default VPC)"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Subnet IDs used for deployment"
  value       = data.aws_subnets.default.ids
}

output "https_url" {
  description = "HTTPS URL for accessing the application"
  value       = "https://${module.alb.dns_name}"
}
