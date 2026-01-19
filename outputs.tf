# Outputs
# Feature: 001-public-ec2-password-auth
# Contract: /specs/001-public-ec2-password-auth/contracts/outputs-contract.md

# =============================================================================
# Instance Information
# =============================================================================

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2_instance.id
}

output "instance_public_ip" {
  description = "Elastic IP address of the instance"
  value       = aws_eip.instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = module.ec2_instance.private_ip
}

output "availability_zone" {
  description = "Availability zone where instance is running"
  value       = module.ec2_instance.availability_zone
}

# =============================================================================
# Network Information
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = local.use_default_vpc ? local.vpc_id : module.vpc[0].vpc_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = local.use_default_vpc ? local.subnet_id : module.vpc[0].public_subnets[0]
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.ec2_instance.id
}

# =============================================================================
# CloudWatch Logging
# =============================================================================

output "cloudwatch_log_group" {
  description = "CloudWatch log group name for SSH logs"
  value       = aws_cloudwatch_log_group.ssh_auth.name
}

output "cloudwatch_log_stream" {
  description = "CloudWatch log stream pattern"
  value       = "{instance_id}"
}

# =============================================================================
# Connection Information
# =============================================================================

output "ssh_username" {
  description = "SSH username for connecting"
  value       = "devuser"
}

output "ssh_command" {
  description = "SSH command to connect (requires password from workspace)"
  value       = "ssh devuser@${aws_eip.instance.public_ip}"
}

# =============================================================================
# Sensitive Outputs
# =============================================================================

output "instance_password" {
  description = "Generated password for SSH authentication (sensitive)"
  value       = random_password.instance_password.result
  sensitive   = true
}

# =============================================================================
# Connection Instructions
# =============================================================================

output "connection_instructions" {
  description = "Instructions for connecting to the instance"
  value       = <<-EOT
    SSH Access:
      Command: ssh devuser@${aws_eip.instance.public_ip}
      Credentials: Retrieve from HCP Terraform workspace sensitive outputs (instance_password)
    
    CloudWatch Logs:
      Log Group: ${aws_cloudwatch_log_group.ssh_auth.name}
      Console: https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${urlencode(aws_cloudwatch_log_group.ssh_auth.name)}
    
    Security Warning: This instance uses password authentication for development only.
  EOT
}
