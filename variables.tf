# ==============================================================================
# Input Variables
# ==============================================================================
# Feature: EC2 Instance with ALB and Nginx Infrastructure
# Variables for configuring EC2 instances, ALB, and networking

# ------------------------------------------------------------------------------
# AWS Region Configuration
# ------------------------------------------------------------------------------
# T012: Region variable with validation
variable "region" {
  description = "AWS region for infrastructure deployment. Must be in Singapore (ap-southeast-*) region for compliance."
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = can(regex("^ap-southeast-", var.region))
    error_message = "Region must be in ap-southeast-* (Singapore) region family."
  }
}

# ------------------------------------------------------------------------------
# Environment Configuration
# ------------------------------------------------------------------------------
# T013: Environment variable with validation
variable "environment" {
  description = "Environment name for resource tagging and naming. Allowed values: dev, staging, prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# ------------------------------------------------------------------------------
# EC2 Instance Configuration
# ------------------------------------------------------------------------------
# T014: Instance type variable for cost optimization
variable "instance_type" {
  description = "EC2 instance type for Nginx web servers. Default t3.micro is cost-optimized for development ($0.0104/hour, ~$15/month for 2 instances)."
  type        = string
  default     = "t3.micro"
}

# T015: Instance count variable with validation
variable "instance_count" {
  description = "Number of EC2 instances to deploy across availability zones. Minimum 2 required for high availability."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 2
    error_message = "Instance count must be at least 2 for high availability across multiple AZs."
  }
}

# ------------------------------------------------------------------------------
# SSL Certificate Configuration
# ------------------------------------------------------------------------------
# T016: ACM certificate ARN for HTTPS listener
variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for ALB HTTPS listener. Must be a valid ACM certificate in the same region."
  type        = string
}

# ------------------------------------------------------------------------------
# Resource Tagging
# ------------------------------------------------------------------------------
# T017: Common tags for all resources
variable "common_tags" {
  description = "Common tags to apply to all resources for cost tracking, ownership, and management."
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "ec2-alb-nginx"
    ManagedBy   = "terraform"
  }
}
