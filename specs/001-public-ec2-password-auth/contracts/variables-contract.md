# Terraform Variable Contracts

**Feature**: Public EC2 Instance with Password Authentication  
**Purpose**: Define all input variables required for infrastructure provisioning  
**Compliance**: Constitution-compliant module consumption

---

## Required Variables

### 1. AWS Region

```hcl
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "ap-southeast-1"
  
  validation {
    condition     = var.aws_region == "ap-southeast-1"
    error_message = "This configuration is designed for ap-southeast-1 region only."
  }
}
```

### 2. Environment Name

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### 3. Instance Configuration

```hcl
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
```

### 4. Network Configuration

```hcl
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
```

### 5. CloudWatch Configuration

```hcl
variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
  
  validation {
    condition     = var.cloudwatch_log_retention_days >= 7
    error_message = "Log retention must be at least 7 days."
  }
}
```

---

## Computed Resources (Not Variables)

```hcl
# Generated password - not exposed as input
resource "random_password" "instance_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}
```

---

See `outputs-contract.md` for output specifications.
