# ==============================================================================
# Input Variables
# ==============================================================================

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., ap-southeast-1)"
  }
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro or t3.small for cost optimization)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Instance type must be either t3.micro or t3.small per FR-002"
  }
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener (self-signed certificate imported to ACM)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[a-f0-9-]+$", var.acm_certificate_arn))
    error_message = "ACM certificate ARN must be a valid ARN format"
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources for cost tracking and management"
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "ec2-alb-nginx-demo"
    ManagedBy   = "terraform"
    Terraform   = "true"
    CostCenter  = "development"
    Purpose     = "testing"
  }
}
