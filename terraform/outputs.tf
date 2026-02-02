# Output Values
# Feature: 003-ec2-alb-nginx
# Purpose: Export infrastructure information for external consumption

# ============================================================================
# NETWORK INFORMATION
# ============================================================================

output "vpc_id" {
  description = "ID of the default VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "List of subnet IDs used for infrastructure deployment"
  value       = local.selected_subnet_ids
}

output "availability_zones" {
  description = "List of availability zones used for infrastructure deployment"
  value       = local.selected_azs
}

# ============================================================================
# CERTIFICATE INFORMATION
# ============================================================================

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate imported from self-signed certificate"
  value       = aws_acm_certificate.web.arn
}

output "certificate_domain" {
  description = "Domain name associated with the certificate"
  value       = aws_acm_certificate.web.domain_name
}

output "certificate_validity_end" {
  description = "Certificate expiration date"
  value       = tls_self_signed_cert.web.validity_end_time
}

# ============================================================================
# SECURITY GROUP INFORMATION
# ============================================================================

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_group_alb.security_group_id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.security_group_ec2.security_group_id
}

# ============================================================================
# EC2 INSTANCE INFORMATION
# ============================================================================

output "ec2_instance_ids" {
  description = "List of EC2 instance IDs"
  value       = [for instance in module.ec2_instances : instance.id]
}

output "ec2_instance_private_ips" {
  description = "List of EC2 instance private IP addresses"
  value       = [for instance in module.ec2_instances : instance.private_ip]
}

output "ec2_instance_availability_zones" {
  description = "Map of instance names to availability zones"
  value       = { for k, instance in module.ec2_instances : k => instance.availability_zone }
}

# ============================================================================
# LOAD BALANCER INFORMATION
# ============================================================================

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = module.alb.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "Route 53 zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_groups["ec2-nginx"].arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = module.alb.listeners["https"].arn
}

# ============================================================================
# CONNECTIVITY INFORMATION
# ============================================================================

output "access_url" {
  description = "URL to access the application (using custom domain)"
  value       = "https://${var.domain_name}"
}

output "alb_direct_url" {
  description = "Direct URL to access the application via ALB DNS"
  value       = "https://${module.alb.dns_name}"
}

output "deployment_timestamp" {
  description = "Timestamp when the infrastructure was deployed"
  value       = timestamp()
}

output "terraform_workspace" {
  description = "Terraform workspace used for deployment"
  value       = "sandbox_workspace"
}

# ============================================================================
# DEPLOYMENT METADATA
# ============================================================================
# Deployment metadata will be added at the end
