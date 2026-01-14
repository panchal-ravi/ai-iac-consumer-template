# ============================================================================
# Terraform Outputs
# Feature: 001-public-ec2-dev
# GitHub Issue: #15
# ============================================================================

# Phase 3: User Story 1 - Instance Identification
# FR-013: Instance ID output
output "instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2_instance.id
}

# FR-013: Instance public IP address
output "instance_public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = module.ec2_instance.public_ip
}

# Phase 4: User Story 2 - SSH Credentials
# FR-015: SSH username (non-sensitive)
output "ssh_username" {
  description = "SSH username for connecting to the instance"
  value       = "devuser"
}

# FR-014: SSH password (sensitive)
output "ssh_password" {
  description = "SSH password for devuser account (sensitive)"
  value       = random_password.devuser.result
  sensitive   = true
}

# Phase 5: User Story 3 - Security Group
output "security_group_id" {
  description = "Security group ID attached to the EC2 instance"
  value       = module.ec2_instance.security_group_id
}

# Phase 6: User Story 4 - Monitoring
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for instance logs"
  value       = module.cloudwatch_log_group.cloudwatch_log_group_name
}

output "iam_instance_profile_arn" {
  description = "IAM instance profile ARN attached to the EC2 instance"
  value       = module.ec2_instance.iam_instance_profile_arn
}
