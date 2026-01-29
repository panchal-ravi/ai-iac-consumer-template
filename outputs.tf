# ==============================================================================
# Outputs
# ==============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application via HTTPS)"
  value       = try(module.alb.dns_name, null)
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = try(module.alb.arn, null)
}

output "target_group_arn" {
  description = "ARN of the target group attached to the ALB"
  value       = try(module.alb.target_groups["ec2-instances"].arn, null)
}

output "instance_ids" {
  description = "Map of EC2 instance IDs by availability zone"
  value = {
    az_a = try(module.ec2_instance_az_a.id, null)
    az_b = try(module.ec2_instance_az_b.id, null)
  }
}

output "security_group_ids" {
  description = "Map of security group IDs (ALB and EC2)"
  value = {
    alb = try(module.alb.security_group_id, null)
    ec2 = try(module.ec2_instance_az_a.security_group_id, null)
  }
}

output "vpc_id" {
  description = "ID of the default VPC being used"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Map of subnet IDs by availability zone"
  value = {
    az_a = data.aws_subnet.az_a.id
    az_b = data.aws_subnet.az_b.id
  }
}

output "access_url" {
  description = "HTTPS URL to access the application (accept certificate warning for self-signed cert)"
  value       = try("https://${module.alb.dns_name}/", "ALB not yet created")
}