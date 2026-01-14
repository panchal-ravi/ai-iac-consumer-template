# Input Variables
# FR-001: Region and instance type configuration with validation

variable "region" {
  description = "AWS region for resource deployment (must be ap-southeast-1)"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.region == "ap-southeast-1"
    error_message = "Region must be ap-southeast-1 for this deployment."
  }
}

variable "instance_type" {
  description = "EC2 instance type (must be t2 or t3 nano/micro/small/medium)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[2-3]\\.(nano|micro|small|medium)$", var.instance_type))
    error_message = "Instance type must match pattern t[2-3].(nano|micro|small|medium)."
  }
}

variable "password_length" {
  description = "Length of generated password for devuser (minimum 16 characters)"
  type        = number
  default     = 16

  validation {
    condition     = var.password_length >= 16
    error_message = "Password length must be at least 16 characters."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "public-ec2-dev"
    ManagedBy   = "terraform"
    Purpose     = "development-testing"
    Terraform   = "true"
    Agent       = "copilot-terraform-agent"
    Application = "public-ec2-dev"
  }
}
