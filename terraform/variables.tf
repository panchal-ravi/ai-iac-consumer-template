# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.region == "ap-southeast-1"
    error_message = "This infrastructure is designed for ap-southeast-1 region only."
  }
}

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[2-3]\\.(nano|micro|small)$", var.instance_type))
    error_message = "Instance type must be a cost-optimized burstable instance (t2/t3 nano, micro, or small)."
  }
}

variable "instance_count" {
  description = "Number of EC2 instances to create (must be exactly 2 for this design)"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count == 2
    error_message = "Exactly 2 instances are required for this infrastructure design."
  }
}

variable "certificate_domain" {
  description = "Domain name for the self-signed TLS certificate"
  type        = string
  default     = "web.demo.com"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-\\.]*[a-z0-9]$", var.certificate_domain))
    error_message = "Certificate domain must be a valid DNS name."
  }
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, dev, staging, production."
  }
}

# ==============================================================================
# OPTIONAL VARIABLES
# ==============================================================================

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "ec2-alb-nginx"
}

variable "owner" {
  description = "Owner or team responsible for the infrastructure"
  type        = string
  default     = "devops-team"
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "List of availability zones for deployment"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones must be specified."
  }
}

variable "health_check_path" {
  description = "Target group health check path"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Target group health check interval in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Target group health check timeout in seconds"
  type        = number
  default     = 5

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 120
    error_message = "Health check timeout must be between 2 and 120 seconds."
  }
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks before marking target as healthy"
  type        = number
  default     = 2

  validation {
    condition     = var.healthy_threshold >= 2 && var.healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking target as unhealthy"
  type        = number
  default     = 2

  validation {
    condition     = var.unhealthy_threshold >= 2 && var.unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}

variable "certificate_validity_hours" {
  description = "Validity period for self-signed certificate in hours"
  type        = number
  default     = 43800 # 5 years

  validation {
    condition     = var.certificate_validity_hours >= 8760 # minimum 1 year
    error_message = "Certificate validity must be at least 1 year (8760 hours)."
  }
}
