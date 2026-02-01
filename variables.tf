# =============================================================================
# Input Variables
# Feature: 002-ec2-alb-nginx - EC2 Infrastructure with ALB and Nginx
# Purpose: Define all configurable parameters for infrastructure deployment
# =============================================================================

# T009: Region variable
variable "region" {
  description = "AWS region for infrastructure deployment"
  type        = string

  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af|il)-(north|south|east|west|central|southeast|northeast)-[1-9]$", var.region))
    error_message = "Must be a valid AWS region (e.g., ap-southeast-1, us-east-1, eu-west-1)."
  }
}

# T010: Project name variable
variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.project_name))
    error_message = "Project name must be 3-32 characters, lowercase alphanumeric and hyphens only."
  }
}

# T011: Environment variable
variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

# T012: Availability zones variable
variable "availability_zones" {
  description = "List of availability zones for instance distribution (exactly 2 required)"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones are required for high availability."
  }
}

# T013: Domain name variable
variable "domain_name" {
  description = "Domain name for TLS certificate (e.g., web.demo.com)"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "Must be a valid domain name format (e.g., web.demo.com, example.org)."
  }
}

# T014: Instance type variable
variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3a.micro"

  validation {
    condition     = can(regex("^t[2-3]a?\\.(nano|micro|small|medium|large)$", var.instance_type))
    error_message = "Instance type must be a cost-effective burstable instance (t2/t3/t3a: nano, micro, small, medium, large)."
  }
}
