# ==============================================================================
# PRIMARY ACCESS POINT
# ==============================================================================

output "alb_endpoint" {
  description = "HTTPS URL for accessing the web application through the load balancer"
  value       = "https://${aws_lb.main.dns_name}"
}

# ==============================================================================
# LOAD BALANCER OUTPUTS
# ==============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = aws_security_group.alb.id
}

# ==============================================================================
# TARGET GROUP OUTPUTS
# ==============================================================================

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.main.name
}

output "target_group_targets" {
  description = "List of registered target instance IDs"
  value       = aws_lb_target_group_attachment.instances[*].target_id
}

# ==============================================================================
# EC2 INSTANCE OUTPUTS
# ==============================================================================

output "ec2_instance_ids" {
  description = "List of EC2 instance IDs"
  value       = module.ec2_instance[*].id
}

output "ec2_instance_private_ips" {
  description = "List of EC2 instance private IP addresses"
  value       = module.ec2_instance[*].private_ip
}

output "ec2_instance_public_ips" {
  description = "List of EC2 instance public IP addresses (if assigned)"
  value       = module.ec2_instance[*].public_ip
}

output "ec2_availability_zones" {
  description = "Availability zones where EC2 instances are deployed"
  value       = module.ec2_instance[*].availability_zone
}

output "ec2_security_group_id" {
  description = "Security group ID for EC2 instances"
  value       = aws_security_group.ec2.id
}

# ==============================================================================
# CERTIFICATE OUTPUTS
# ==============================================================================

output "acm_certificate_arn" {
  description = "ARN of the imported ACM certificate"
  value       = aws_acm_certificate.self_signed.arn
}

output "certificate_domain" {
  description = "Domain name on the certificate"
  value       = var.certificate_domain
}

output "certificate_expiry" {
  description = "Certificate expiration date"
  value       = aws_acm_certificate.self_signed.not_after
}

output "certificate_subject" {
  description = "Certificate subject distinguished name"
  value       = tls_self_signed_cert.main.subject[0].common_name
}

# ==============================================================================
# NETWORK OUTPUTS
# ==============================================================================

output "vpc_id" {
  description = "ID of the VPC used for deployment"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "List of subnet IDs used for deployment"
  value       = data.aws_subnets.default.ids
}

# ==============================================================================
# TESTING AND VALIDATION
# ==============================================================================

output "health_check_configuration" {
  description = "Target group health check configuration"
  value = {
    path                = aws_lb_target_group.main.health_check[0].path
    interval            = aws_lb_target_group.main.health_check[0].interval
    timeout             = aws_lb_target_group.main.health_check[0].timeout
    healthy_threshold   = aws_lb_target_group.main.health_check[0].healthy_threshold
    unhealthy_threshold = aws_lb_target_group.main.health_check[0].unhealthy_threshold
  }
}

output "verification_commands" {
  description = "Commands to verify deployment"
  value = {
    test_https_endpoint = "curl -k ${aws_lb.main.dns_name}"
    check_certificate   = "openssl s_client -connect ${aws_lb.main.dns_name}:443 -servername ${var.certificate_domain}"
    check_target_health = "aws elbv2 describe-target-health --target-group-arn ${aws_lb_target_group.main.arn} --region ${var.region}"
  }
}
