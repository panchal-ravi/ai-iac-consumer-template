# Output Values for EC2 Development Instance
# Contract: terraform-interface.md
# FR-006: Infrastructure outputs for downstream consumption

# ==============================================================================
# COMPUTE OUTPUTS
# ==============================================================================

output "instance_id" {
  description = "EC2 instance identifier for AWS Console navigation and Session Manager"
  value       = aws_instance.dev.id
}

output "instance_public_ip" {
  description = "Public IP address (Elastic IP) for SSH access and DNS configuration"
  value       = aws_eip.dev_instance.public_ip
}

output "instance_private_ip" {
  description = "VPC private IP address for internal routing and VPC peering"
  value       = aws_instance.dev.private_ip
}

# ==============================================================================
# NETWORKING OUTPUTS
# ==============================================================================

output "security_group_id" {
  description = "Security group ID for SSH access rules and compliance auditing"
  value       = aws_security_group.ec2_dev_ssh.id
}

output "elastic_ip_id" {
  description = "Elastic IP allocation ID for cost tracking and IP allowlist management"
  value       = aws_eip.dev_instance.id
}

# ==============================================================================
# IAM OUTPUTS
# ==============================================================================

output "iam_role_arn" {
  description = "IAM role ARN for Session Manager access and permission verification"
  value       = aws_iam_role.ec2_ssm_role.arn
}

output "iam_instance_profile_name" {
  description = "IAM instance profile name for role association verification"
  value       = aws_iam_instance_profile.ec2_profile.name
}

# ==============================================================================
# MONITORING OUTPUTS
# ==============================================================================

output "log_group_name" {
  description = "CloudWatch Logs group name for SSH authentication events and log streaming"
  value       = aws_cloudwatch_log_group.ssh_auth_logs.name
}

output "log_group_arn" {
  description = "CloudWatch Logs group ARN for IAM policies and cross-account access"
  value       = aws_cloudwatch_log_group.ssh_auth_logs.arn
}

# ==============================================================================
# CONVENIENCE OUTPUTS
# ==============================================================================

output "ssh_connection_command" {
  description = "Ready-to-use SSH connection command (password must be set first via Session Manager)"
  value       = "ssh devuser@${aws_eip.dev_instance.public_ip}"
}

output "session_manager_command" {
  description = "AWS CLI command for Session Manager emergency fallback access"
  value       = "aws ssm start-session --target ${aws_instance.dev.id}"
}
