# Input Variables
# Feature: 003-ec2-alb-nginx
# Purpose: Define configurable parameters for infrastructure deployment

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., ap-southeast-1)"
  }
}

variable "project_name" {
  description = "Project identifier for resource naming"
  type        = string
  default     = "web-demo"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production"
  }
}

variable "domain_name" {
  description = "Domain name for TLS certificate and application access"
  type        = string
  default     = "web.demo.com"

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid DNS name"
  }
}

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t2.micro", "t3.small", "t2.small"], var.instance_type)
    error_message = "Instance type must be one of: t3.micro, t2.micro, t3.small, t2.small"
  }
}

variable "instance_count_per_az" {
  description = "Number of EC2 instances to create per availability zone"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count_per_az >= 1 && var.instance_count_per_az <= 5
    error_message = "Instance count per AZ must be between 1 and 5"
  }
}

variable "certificate_validity_days" {
  description = "Validity period for self-signed certificate in days"
  type        = number
  default     = 90

  validation {
    condition     = var.certificate_validity_days >= 30 && var.certificate_validity_days <= 365
    error_message = "Certificate validity must be between 30 and 365 days"
  }
}

variable "health_check_interval" {
  description = "Interval between health checks in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds"
  }
}

variable "health_check_path" {
  description = "HTTP path for ALB health checks"
  type        = string
  default     = "/health"

  validation {
    condition     = can(regex("^/[a-zA-Z0-9/_-]*$", var.health_check_path))
    error_message = "Health check path must start with / and contain only alphanumeric characters, underscores, and hyphens"
  }
}
