# Input Variables for Public EC2 Development Instance
# Feature: 001-public-ec2-dev
# Specification: FR-001 through FR-025

# Environment Configuration
variable "environment" {
  description = "Deployment environment (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

# AWS Region (FR-001: Must be ap-southeast-1)
variable "region" {
  description = "AWS region for resource deployment (must be ap-southeast-1 per FR-001)"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.region == "ap-southeast-1"
    error_message = "Region must be ap-southeast-1 per specification requirement FR-001."
  }
}

# Instance Configuration (FR-002: Must be t3.micro)
variable "instance_type" {
  description = "EC2 instance type (must be t3.micro for cost optimization per FR-002)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = var.instance_type == "t3.micro"
    error_message = "Instance type must be t3.micro per cost requirements (FR-002)."
  }
}

# Storage Configuration (FR-006: Must be 8 GB GP3)
variable "root_volume_size" {
  description = "Root EBS volume size in GB (must be 8 GB per FR-006)"
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size == 8
    error_message = "Root volume size must be 8 GB per specification requirement (FR-006)."
  }
}

variable "root_volume_type" {
  description = "EBS volume type (must be gp3 per FR-006)"
  type        = string
  default     = "gp3"

  validation {
    condition     = var.root_volume_type == "gp3"
    error_message = "Root volume type must be gp3 per specification requirement (FR-006)."
  }
}

# Security Configuration (FR-009: Password complexity requirements)
variable "ssh_password_length" {
  description = "Length of generated SSH password (minimum 32 characters per FR-009)"
  type        = number
  default     = 32

  validation {
    condition     = var.ssh_password_length >= 32
    error_message = "Password length must be at least 32 characters for security (FR-009)."
  }
}

# Tagging Configuration (FR-017: Required tags)
variable "project_name" {
  description = "Project name for resource tagging and identification (required per FR-017)"
  type        = string
}

variable "cost_center" {
  description = "Cost center identifier for billing and cost allocation (required per FR-017)"
  type        = string
}

# Monitoring Configuration (FR-016: Basic monitoring only)
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (must be false per FR-016a)"
  type        = bool
  default     = false

  validation {
    condition     = var.enable_detailed_monitoring == false
    error_message = "Detailed monitoring must be disabled to avoid additional costs (FR-016a)."
  }
}

# Feature and Workspace Identifiers
variable "feature_branch" {
  description = "Feature branch identifier for tracking"
  type        = string
  default     = "001-public-ec2-dev"
}

variable "workspace_name" {
  description = "HCP Terraform workspace name"
  type        = string
  default     = "sandbox_workspace"
}
