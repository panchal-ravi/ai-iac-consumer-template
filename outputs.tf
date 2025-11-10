# ==============================================================================
# APPLICATION LOAD BALANCER OUTPUTS
# ==============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application via HTTPS)"
  value       = module.alb.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer (for Route53 alias records)"
  value       = module.alb.zone_id
}

output "alb_https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = module.alb.listeners["https"].arn
}

# ==============================================================================
# TARGET GROUP OUTPUTS
# ==============================================================================

output "target_group_arn" {
  description = "ARN of the target group for EC2 Nginx instances"
  value       = module.alb.target_groups["ec2_nginx"].arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = module.alb.target_groups["ec2_nginx"].name
}

# ==============================================================================
# EC2 INSTANCE OUTPUTS
# ==============================================================================

output "ec2_instance_ids" {
  description = "IDs of the EC2 instances"
  value = [
    module.ec2_instance_az1.id,
    module.ec2_instance_az2.id
  ]
}

output "ec2_private_ips" {
  description = "Private IP addresses of EC2 instances"
  value = [
    module.ec2_instance_az1.private_ip,
    module.ec2_instance_az2.private_ip
  ]
}

output "ec2_availability_zones" {
  description = "Availability zones where EC2 instances are deployed"
  value = [
    data.aws_availability_zones.available.names[0],
    data.aws_availability_zones.available.names[1]
  ]
}

# ==============================================================================
# SECURITY GROUP OUTPUTS
# ==============================================================================

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb_security_group.security_group_id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.ec2_security_group.security_group_id
}

# ==============================================================================
# NETWORK OUTPUTS
# ==============================================================================

output "vpc_id" {
  description = "ID of the VPC used for deployment"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "IDs of the subnets used for ALB and EC2 instances"
  value       = local.selected_subnet_ids
}
