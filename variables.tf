# ============================================================================
# Core Variables
# ============================================================================

variable "environment" {
  description = "Deployment environment (dev, staging, prod, sandbox)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "sandbox"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, sandbox."
  }
}

variable "region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

# ============================================================================
# Network Variables
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones for subnet distribution"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Must specify at least 2 availability zones for high availability."
  }
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets (ALB placement)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "Must specify at least 2 public subnets for ALB across AZs."
  }
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets (EC2 instance placement)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "Must specify at least 2 private subnets for HA."
  }
}

# ============================================================================
# Domain and SSL Certificate Variables
# ============================================================================

variable "domain_name" {
  description = "Primary domain name for the web application (ACM certificate)"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "Must be a valid fully-qualified domain name."
  }
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS validation and A record creation"
  type        = string
  default     = ""
}

# ============================================================================
# Compute Variables
# ============================================================================

variable "instance_type" {
  description = "EC2 instance type for web application servers"
  type        = string
  default     = "t3.micro"
}

variable "ami_ssm_parameter" {
  description = "SSM parameter path for AMI ID (Amazon Linux 2023)"
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "asg_min_size" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 2

  validation {
    condition     = var.asg_min_size >= 2
    error_message = "Minimum 2 instances required for high availability."
  }
}

variable "asg_max_size" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 6

  validation {
    condition     = var.asg_max_size >= 6
    error_message = "Maximum size must be at least 6 for 200% scaling headroom."
  }
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in Auto Scaling Group"
  type        = number
  default     = 2

  validation {
    condition     = var.asg_desired_capacity >= 2 && var.asg_desired_capacity <= 6
    error_message = "Desired capacity must be between min_size and max_size (2-6)."
  }
}

# ============================================================================
# Auto Scaling Policy Variables
# ============================================================================

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto-scaling policy"
  type        = number
  default     = 50.0

  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 1 and 100 percent."
  }
}

variable "scale_in_cooldown" {
  description = "Cooldown period (seconds) after scale-in activity"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period (seconds) after scale-out activity"
  type        = number
  default     = 300
}

# ============================================================================
# Load Balancer Variables
# ============================================================================

variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks before marking target healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking target unhealthy"
  type        = number
  default     = 2
}

variable "deregistration_delay" {
  description = "Time (seconds) for connection draining before deregistering target"
  type        = number
  default     = 30
}

# ============================================================================
# Storage Variables
# ============================================================================

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket name (random suffix added for global uniqueness)"
  type        = string
  default     = "webapp-static-content"
}

variable "enable_s3_versioning" {
  description = "Enable versioning for S3 static content bucket"
  type        = bool
  default     = true
}

# ============================================================================
# Tags
# ============================================================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
