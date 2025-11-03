# ============================================================================
# VPC Outputs
# ============================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# ============================================================================
# Application Load Balancer Outputs
# ============================================================================

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "The Route53 zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

output "target_group_arns" {
  description = "ARNs of the target groups"
  value       = { for k, v in module.alb.target_groups : k => v.arn }
}

# ============================================================================
# Auto Scaling Group Outputs
# ============================================================================

output "autoscaling_group_id" {
  description = "The ID of the Auto Scaling Group"
  value       = module.asg.autoscaling_group_id
}

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group"
  value       = module.asg.autoscaling_group_name
}

output "autoscaling_group_arn" {
  description = "The ARN of the Auto Scaling Group"
  value       = module.asg.autoscaling_group_arn
}

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = module.asg.launch_template_id
}

# ============================================================================
# IAM Outputs
# ============================================================================

output "iam_role_arn" {
  description = "The ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2.arn
}

output "iam_role_name" {
  description = "The name of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2.name
}

output "iam_instance_profile_name" {
  description = "The name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "iam_instance_profile_arn" {
  description = "The ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2.arn
}

# ============================================================================
# S3 Bucket Outputs
# ============================================================================

output "s3_bucket_id" {
  description = "The ID (name) of the S3 bucket for static content"
  value       = aws_s3_bucket.static_content.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket for static content"
  value       = aws_s3_bucket.static_content.arn
}

output "s3_logs_bucket_id" {
  description = "The ID (name) of the S3 bucket for access logs"
  value       = aws_s3_bucket.logs.id
}

# ============================================================================
# KMS Key Outputs
# ============================================================================

output "kms_key_id" {
  description = "The ID of the KMS key for S3 encryption"
  value       = aws_kms_key.s3.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key for S3 encryption"
  value       = aws_kms_key.s3.arn
}

# ============================================================================
# ACM Certificate Outputs
# ============================================================================

output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "acm_certificate_status" {
  description = "The status of the ACM certificate"
  value       = aws_acm_certificate.main.status
}

output "acm_certificate_domain_validation_options" {
  description = "Domain validation options for manual DNS configuration (if Route53 not used)"
  value       = aws_acm_certificate.main.domain_validation_options
  sensitive   = false
}

# ============================================================================
# Application Access Information
# ============================================================================

output "application_url_http" {
  description = "HTTP URL to access the application (will redirect to HTTPS)"
  value       = "http://${module.alb.dns_name}"
}

output "application_url_https" {
  description = "HTTPS URL to access the application"
  value       = "https://${module.alb.dns_name}"
}

output "custom_domain_url" {
  description = "Custom domain URL (if configured)"
  value       = "https://${var.domain_name}"
}

# ============================================================================
# Quick Reference
# ============================================================================

output "quick_reference" {
  description = "Quick reference guide for deployment validation"
  value       = <<-EOT

    === Web Application Infrastructure Deployment ===

    1. Application Access:
       - ALB DNS: ${module.alb.dns_name}
       - HTTP:    http://${module.alb.dns_name}
       - HTTPS:   https://${module.alb.dns_name}
       - Custom:  https://${var.domain_name}

    2. Infrastructure:
       - VPC ID:              ${module.vpc.vpc_id}
       - Public Subnets:      ${join(", ", module.vpc.public_subnets)}
       - Private Subnets:     ${join(", ", module.vpc.private_subnets)}
       - Auto Scaling Group:  ${module.asg.autoscaling_group_name}
       - S3 Bucket:           ${aws_s3_bucket.static_content.id}

    3. Validation Steps:
       - Check ALB targets: AWS Console → EC2 → Target Groups
       - Test HTTP redirect: curl -I http://${module.alb.dns_name}
       - Test HTTPS access: curl -k https://${module.alb.dns_name}
       - Upload content:    aws s3 sync ./content/ s3://${aws_s3_bucket.static_content.id}/

    4. ACM Certificate:
       - Status:  ${aws_acm_certificate.main.status}
       - ARN:     ${aws_acm_certificate.main.arn}
       ${var.route53_zone_id != "" ? "- Validation: Automatic via Route53" : "- Validation: Manual DNS CNAME records required"}

    5. Monitoring:
       - CloudWatch: EC2 → Auto Scaling Groups → ${module.asg.autoscaling_group_name}
       - ALB Metrics: EC2 → Load Balancers → ${module.alb.dns_name}

    EOT
}
