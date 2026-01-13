# ============================================================================
# Terraform Outputs: Public EC2 Development Instance
# Feature: 001-public-ec2-dev
# FR-022, FR-023: Required outputs for instance access and management
# ============================================================================

# EC2 Instance Outputs
output "instance_id" {
  description = "EC2 instance ID for reference and management"
  value       = aws_instance.dev_ec2.id
}

output "instance_public_ip" {
  description = "Public IP address for SSH connection (FR-022)"
  value       = aws_instance.dev_ec2.public_ip
}

output "instance_private_ip" {
  description = "Private IP address within VPC"
  value       = aws_instance.dev_ec2.private_ip
}

output "instance_state" {
  description = "Current state of the EC2 instance"
  value       = aws_instance.dev_ec2.instance_state
}

output "availability_zone" {
  description = "Availability zone where the instance is deployed"
  value       = aws_instance.dev_ec2.availability_zone
}

# Security Group Outputs
output "security_group_id" {
  description = "Security group ID attached to the EC2 instance"
  value       = aws_security_group.ssh.id
}

output "security_group_name" {
  description = "Security group name"
  value       = aws_security_group.ssh.name
}

# Secrets Manager Outputs
output "ssh_secret_arn" {
  description = "AWS Secrets Manager secret ARN containing SSH password (FR-023)"
  value       = aws_secretsmanager_secret.ssh_password.arn
}

output "ssh_secret_name" {
  description = "AWS Secrets Manager secret name"
  value       = aws_secretsmanager_secret.ssh_password.name
}

# Note: The actual password is NOT exposed in outputs for security
# To retrieve the password, use:
# aws secretsmanager get-secret-value --secret-id <secret_arn> --query SecretString --output text

# IAM Outputs
output "iam_role_arn" {
  description = "IAM role ARN attached to the EC2 instance"
  value       = aws_iam_role.instance_role.arn
}

output "iam_instance_profile_name" {
  description = "IAM instance profile name"
  value       = aws_iam_instance_profile.instance_profile.name
}

# VPC Outputs
output "vpc_id" {
  description = "VPC ID where the instance is deployed"
  value       = data.aws_vpc.default.id
}

output "subnet_id" {
  description = "Subnet ID where the instance is deployed"
  value       = aws_instance.dev_ec2.subnet_id
}

# AMI Information
output "ami_id" {
  description = "AMI ID used for the EC2 instance"
  value       = aws_instance.dev_ec2.ami
}

output "ami_name" {
  description = "Name of the Amazon Linux 2023 AMI used"
  value       = data.aws_ami.amazon_linux_2023.name
}

# SSH Connection Instructions
output "ssh_connection_command" {
  description = "SSH connection command (password will be prompted)"
  value       = "ssh ec2-user@${aws_instance.dev_ec2.public_ip}"
}

output "password_retrieval_command" {
  description = "AWS CLI command to retrieve SSH password"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.ssh_password.arn} --region ${var.region} --query SecretString --output text"
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost in USD (SC-006)"
  value       = "~$12.32 (EC2: $7.59 + EBS: $0.64 + IPv4: $3.60 + Secrets: $0.40 + Transfer: $0.09)"
}
