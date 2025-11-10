# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "environment" {
  description = "Deployment environment (development, staging, production)"
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "ec2-alb-nginx"

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid region code (e.g., ap-southeast-2)."
  }
}

# ==============================================================================
# OPTIONAL VARIABLES WITH DEFAULTS
# ==============================================================================

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[23]\\.(micro|small|medium|large)", var.instance_type))
    error_message = "Instance type must be a valid t2 or t3 instance type (e.g., t3.micro)."
  }
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS. If not provided, will search for most recent issued certificate."
  type        = string
  default     = null

  validation {
    condition     = var.certificate_arn == null || can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[a-f0-9-]+$", var.certificate_arn))
    error_message = "Certificate ARN must be a valid ACM certificate ARN or null."
  }
}

variable "health_check_path" {
  description = "Health check path for target group"
  type        = string
  default     = "/"

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "Health check path must start with /."
  }
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources in addition to default tags"
  type        = map(string)
  default     = {}
}
