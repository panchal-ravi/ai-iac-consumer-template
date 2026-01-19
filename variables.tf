# Input Variables
# Feature: 001-public-ec2-password-auth
# Contract: /specs/001-public-ec2-password-auth/contracts/variables-contract.md

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.aws_region == "ap-southeast-1"
    error_message = "This configuration is designed for ap-southeast-1 region only."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = var.instance_type == "t3.micro"
    error_message = "Only t3.micro instance type is allowed."
  }
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 20
    error_message = "Root volume size must be between 8 and 20 GB."
  }
}

variable "enable_http" {
  description = "Enable HTTP access (port 80)"
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable HTTPS access (port 443)"
  type        = bool
  default     = false
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7

  validation {
    condition     = var.cloudwatch_log_retention_days >= 7
    error_message = "Log retention must be at least 7 days."
  }
}
