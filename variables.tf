# Input Variables for EC2 Development Instance
# Constitution 3.4: Type constraints and validation required
# Contract: terraform-interface.md

# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "aws_region" {
  description = "AWS region for resource deployment (e.g., us-east-1, us-west-2)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Region must be a valid AWS region code (e.g., us-east-1)."
  }
}

variable "instance_type" {
  description = "EC2 instance type from t3 family (t3.micro ~$7.50/month, t3.small ~$15/month)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Instance type must be from t3 family for cost optimization."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB (minimum 30 for AL2023, ~$0.10/GB-month for gp3)"
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 30 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 30 and 100 GB."
  }
}

variable "environment" {
  description = "Deployment environment - development use only (production NOT supported)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["dev", "development", "sandbox"], var.environment)
    error_message = "Environment must be dev, development, or sandbox (production not supported)."
  }
}

variable "project_name" {
  description = "Project identifier for resource naming (1-32 chars, lowercase alphanumeric and hyphens)"
  type        = string
  default     = "ec2-dev-instance"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,32}$", var.project_name))
    error_message = "Project name must be 1-32 characters, lowercase alphanumeric and hyphens only."
  }
}

# ==============================================================================
# OPTIONAL VARIABLES
# ==============================================================================

variable "enable_monitoring" {
  description = "Enable CloudWatch detailed monitoring (1-minute metrics, adds $2/month cost)"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access (0.0.0.0/0 allows public access - development only)"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.ssh_allowed_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "All elements must be valid CIDR blocks."
  }
}

variable "additional_tags" {
  description = "Additional tags to merge with standard tags (Environment, Project, ManagedBy, PublicAccess)"
  type        = map(string)
  default     = {}
}
