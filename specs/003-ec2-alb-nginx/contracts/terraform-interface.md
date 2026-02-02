# Terraform Module Contracts

**Feature**: EC2 Instance with ALB and Nginx  
**Purpose**: Define input variables, outputs, and module interfaces for the root Terraform configuration

---

## Root Module Interface

### Required Providers

```hcl
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  
  # HCP Terraform Cloud backend (configured automatically)
  cloud {
    organization = "ravi-panchal-org"
    workspaces {
      name = "sandbox_workspace"
    }
  }
}
```

---

## Input Variables

### Required Variables

#### aws_region
```hcl
variable "aws_region" {
  type        = string
  description = "AWS region where resources will be provisioned"
  default     = "ap-southeast-1"
  
  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af)-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Must be a valid AWS region identifier."
  }
}
```

#### project_name
```hcl
variable "project_name" {
  type        = string
  description = "Project name used in resource naming and tagging"
  default     = "web-demo"
  
  validation {
    condition     = length(var.project_name) <= 20 && can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, max 20 characters."
  }
}
```

#### environment
```hcl
variable "environment" {
  type        = string
  description = "Environment name (development, staging, production)"
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}
```

#### domain_name
```hcl
variable "domain_name" {
  type        = string
  description = "Domain name for the self-signed certificate"
  default     = "web.demo.com"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-\\.]*[a-z0-9]$", var.domain_name))
    error_message = "Must be a valid domain name format."
  }
}
```

---

### Optional Variables

#### instance_type
```hcl
variable "instance_type" {
  type        = string
  description = "EC2 instance type for web servers"
  default     = "t3.micro"
  
  validation {
    condition     = contains(["t3.micro", "t2.micro", "t3.small", "t2.small"], var.instance_type)
    error_message = "Instance type must be t3.micro, t2.micro, t3.small, or t2.small for cost optimization."
  }
}
```

#### instance_count_per_az
```hcl
variable "instance_count_per_az" {
  type        = number
  description = "Number of EC2 instances to create per availability zone"
  default     = 1
  
  validation {
    condition     = var.instance_count_per_az >= 1 && var.instance_count_per_az <= 3
    error_message = "Instance count per AZ must be between 1 and 3."
  }
}
```

#### certificate_validity_days
```hcl
variable "certificate_validity_days" {
  type        = number
  description = "Number of days the self-signed certificate should be valid"
  default     = 90
  
  validation {
    condition     = var.certificate_validity_days >= 90 && var.certificate_validity_days <= 365
    error_message = "Certificate validity must be between 90 and 365 days."
  }
}
```

#### health_check_interval
```hcl
variable "health_check_interval" {
  type        = number
  description = "Interval in seconds between ALB health checks"
  default     = 30
  
  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}
```

#### health_check_path
```hcl
variable "health_check_path" {
  type        = string
  description = "Health check endpoint path"
  default     = "/health"
  
  validation {
    condition     = can(regex("^/[a-zA-Z0-9/_-]*$", var.health_check_path))
    error_message = "Health check path must start with / and contain only alphanumeric characters, hyphens, and underscores."
  }
}
```

#### enable_detailed_monitoring
```hcl
variable "enable_detailed_monitoring" {
  type        = bool
  description = "Enable detailed CloudWatch monitoring for EC2 instances (additional cost)"
  default     = false
}
```

#### tags
```hcl
variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
```

---

## Output Values

### Network Outputs

#### vpc_id
```hcl
output "vpc_id" {
  description = "ID of the VPC used for deployment"
  value       = data.aws_vpc.default.id
}
```

#### subnet_ids
```hcl
output "subnet_ids" {
  description = "List of subnet IDs used for ALB and EC2 instances"
  value       = local.selected_subnet_ids
}
```

#### availability_zones
```hcl
output "availability_zones" {
  description = "List of availability zones where resources are deployed"
  value       = local.selected_azs
}
```

---

### Load Balancer Outputs

#### alb_id
```hcl
output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = module.alb.lb_id
}
```

#### alb_arn
```hcl
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.lb_arn
}
```

#### alb_dns_name
```hcl
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use for CNAME or A record)"
  value       = module.alb.lb_dns_name
}
```

#### alb_zone_id
```hcl
output "alb_zone_id" {
  description = "Route 53 hosted zone ID of the ALB (for alias records)"
  value       = module.alb.lb_zone_id
}
```

#### target_group_arn
```hcl
output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_group_arns[0]
}
```

#### https_listener_arn
```hcl
output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = module.alb.https_listener_arns[0]
}
```

---

### EC2 Instance Outputs

#### ec2_instance_ids
```hcl
output "ec2_instance_ids" {
  description = "List of EC2 instance IDs"
  value       = [for instance in module.ec2_instances : instance.id]
}
```

#### ec2_instance_private_ips
```hcl
output "ec2_instance_private_ips" {
  description = "Map of EC2 instance IDs to private IP addresses"
  value = {
    for key, instance in module.ec2_instances :
    key => instance.private_ip
  }
}
```

#### ec2_instance_availability_zones
```hcl
output "ec2_instance_availability_zones" {
  description = "Map of EC2 instance IDs to availability zones"
  value = {
    for key, instance in module.ec2_instances :
    key => instance.availability_zone
  }
}
```

---

### Security Group Outputs

#### alb_security_group_id
```hcl
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_group_alb.security_group_id
}
```

#### ec2_security_group_id
```hcl
output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.security_group_ec2.security_group_id
}
```

---

### Certificate Outputs

#### acm_certificate_arn
```hcl
output "acm_certificate_arn" {
  description = "ARN of the imported ACM certificate"
  value       = aws_acm_certificate.web.arn
}
```

#### certificate_domain
```hcl
output "certificate_domain" {
  description = "Domain name of the certificate"
  value       = var.domain_name
}
```

#### certificate_validity_end
```hcl
output "certificate_validity_end" {
  description = "Certificate expiration date (RFC3339 format)"
  value       = tls_self_signed_cert.web.validity_end_time
  sensitive   = false
}
```

---

### Connectivity Outputs

#### access_url
```hcl
output "access_url" {
  description = "URL to access the application (requires DNS configuration or hosts file entry)"
  value       = "https://${var.domain_name}"
}
```

#### alb_direct_url
```hcl
output "alb_direct_url" {
  description = "Direct URL to ALB (certificate warning expected)"
  value       = "https://${module.alb.lb_dns_name}"
}
```

---

### Deployment Metadata

#### deployment_timestamp
```hcl
output "deployment_timestamp" {
  description = "Timestamp when the infrastructure was deployed"
  value       = timestamp()
}
```

#### terraform_workspace
```hcl
output "terraform_workspace" {
  description = "HCP Terraform workspace name"
  value       = "sandbox_workspace"
}
```

---

## Module Composition

### Private Registry Modules Used

```hcl
# EC2 Instance Module (called multiple times for different AZs)
module "ec2_instances" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  
  for_each = local.instance_configs
  
  name                    = each.value.name
  instance_type           = var.instance_type
  subnet_id               = each.value.subnet_id
  vpc_security_group_ids  = [module.security_group_ec2.security_group_id]
  user_data               = local.nginx_user_data
  ami_ssm_parameter       = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  create_security_group   = false
  
  tags = merge(local.common_tags, {
    Name             = each.value.name
    AvailabilityZone = each.value.availability_zone
  })
}

# Application Load Balancer Module
module "alb" {
  source  = "app.terraform.io/ravi-panchal-org/alb/aws"
  version = "~> 10.2.0"
  
  name               = "${var.project_name}-${var.environment}-alb"
  load_balancer_type = "application"
  internal           = false
  
  vpc_id  = data.aws_vpc.default.id
  subnets = local.selected_subnet_ids
  
  security_groups = [module.security_group_alb.security_group_id]
  
  listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate.web.arn
      
      default_action = {
        type             = "forward"
        target_group_arn = module.alb.target_group_arns[0]
      }
    }
  ]
  
  target_groups = [
    {
      name             = "${var.project_name}-${var.environment}-tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      
      health_check = {
        enabled             = true
        interval            = var.health_check_interval
        path                = var.health_check_path
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }
      
      targets = {
        for key, instance in module.ec2_instances :
        key => {
          target_id = instance.id
          port      = 80
        }
      }
    }
  ]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb"
  })
}

# Security Group Module (ALB)
module "security_group_alb" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "~> 5.3.1"
  
  name        = "${var.project_name}-${var.environment}-sg-alb"
  description = "Security group for Application Load Balancer - allows HTTPS from internet"
  vpc_id      = data.aws_vpc.default.id
  
  ingress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from internet"
    }
  ]
  
  egress_rules = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.security_group_ec2.security_group_id
      description              = "Allow HTTP to EC2 instances"
    }
  ]
  
  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-sg-alb"
    Purpose = "alb"
  })
}

# Security Group Module (EC2)
module "security_group_ec2" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "~> 5.3.1"
  
  name        = "${var.project_name}-${var.environment}-sg-ec2"
  description = "Security group for EC2 instances - allows HTTP from ALB only"
  vpc_id      = data.aws_vpc.default.id
  
  ingress_rules = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.security_group_alb.security_group_id
      description              = "Allow HTTP from ALB only"
    }
  ]
  
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic for package installation"
    }
  ]
  
  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-sg-ec2"
    Purpose = "ec2"
  })
}
```

---

## Local Values

### Common Tags
```hcl
locals {
  common_tags = merge(
    var.tags,
    {
      Project      = var.project_name
      Environment  = var.environment
      ManagedBy    = "terraform"
      Feature      = "003-ec2-alb-nginx"
      GitHubIssue  = "39"
      Workspace    = "sandbox_workspace"
      CostCenter   = "engineering-dev"
      CreatedDate  = "2025-01-21"
      Region       = var.aws_region
    }
  )
}
```

### Subnet Selection
```hcl
locals {
  # Get all availability zones from discovered subnets
  all_availability_zones = distinct([
    for subnet in data.aws_subnet.default :
    subnet.availability_zone
  ])
  
  # Select first 2 AZs
  selected_azs = slice(sort(local.all_availability_zones), 0, 2)
  
  # Map AZs to subnet IDs
  az_to_subnet_map = {
    for subnet in data.aws_subnet.default :
    subnet.availability_zone => subnet.id...
  }
  
  # Select one subnet per selected AZ
  selected_subnet_ids = [
    for az in local.selected_azs :
    local.az_to_subnet_map[az][0]
  ]
}
```

### Instance Configuration
```hcl
locals {
  # Generate instance configurations for each AZ
  instance_configs = {
    for idx, az in local.selected_azs :
    "az-${idx + 1}" => {
      name              = "${var.project_name}-${var.environment}-ec2-az${idx + 1}"
      availability_zone = az
      subnet_id         = local.selected_subnet_ids[idx]
    }
  }
}
```

### Nginx User Data
```hcl
locals {
  nginx_user_data = templatefile("${path.module}/user-data/nginx-bootstrap.sh", {
    domain_name = var.domain_name
    environment = var.environment
  })
}
```

---

## Data Sources

### VPC Discovery
```hcl
data "aws_vpc" "default" {
  default = true
}
```

### Subnet Discovery
```hcl
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}
```

---

## Terraform Resources (Non-Module)

### TLS Private Key
```hcl
resource "tls_private_key" "web" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
```

### TLS Self-Signed Certificate
```hcl
resource "tls_self_signed_cert" "web" {
  private_key_pem = tls_private_key.web.private_key_pem
  
  subject {
    common_name  = var.domain_name
    organization = "Development"
  }
  
  validity_period_hours = var.certificate_validity_days * 24
  early_renewal_hours   = 720  # 30 days before expiry
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  
  dns_names = [var.domain_name]
}
```

### ACM Certificate Import
```hcl
resource "aws_acm_certificate" "web" {
  private_key      = tls_private_key.web.private_key_pem
  certificate_body = tls_self_signed_cert.web.cert_pem
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(local.common_tags, {
    Name   = "${var.project_name}-${var.environment}-cert"
    Domain = var.domain_name
  })
}
```

---

## Validation Checks

### Pre-Deployment Validations

```hcl
# Validate minimum number of subnets
resource "null_resource" "validate_subnet_count" {
  lifecycle {
    precondition {
      condition     = length(local.selected_subnet_ids) >= 2
      error_message = "At least 2 subnets in different availability zones are required for ALB deployment."
    }
  }
}

# Validate certificate validity period
resource "null_resource" "validate_certificate" {
  lifecycle {
    precondition {
      condition     = var.certificate_validity_days >= 90
      error_message = "Certificate validity must be at least 90 days per requirements."
    }
  }
}

# Validate region
resource "null_resource" "validate_region" {
  lifecycle {
    precondition {
      condition     = var.aws_region == "ap-southeast-1"
      error_message = "This configuration is designed for ap-southeast-1 region only."
    }
  }
}
```

---

## Dependency Graph

```
data.aws_vpc
  ↓
data.aws_subnets → data.aws_subnet
  ↓                     ↓
locals (subnet selection)
  ↓
module.security_group_alb ←→ module.security_group_ec2
  ↓                              ↓
module.alb                   module.ec2_instances
  ↓                              ↓
  ←────────────────────────────→
         (target attachment)

tls_private_key
  ↓
tls_self_signed_cert
  ↓
aws_acm_certificate
  ↓
module.alb (HTTPS listener)
```

---

## Contract Summary

This contract defines:
- ✅ **9 input variables** (4 required, 5 optional)
- ✅ **23 output values** organized by category
- ✅ **4 private registry modules** with specific versions
- ✅ **3 core Terraform resources** (TLS and ACM)
- ✅ **4 data sources** for VPC/subnet discovery
- ✅ **3 validation checks** for pre-deployment safety
- ✅ **Clear dependency chain** for resource creation order

**Status**: ✅ Ready for implementation  
**Next Phase**: Create quickstart documentation and update agent context
