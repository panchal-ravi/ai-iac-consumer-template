# Module Interface Contracts

**Feature**: 001-ec2-alb-webapp
**Date**: 2025-11-03
**Purpose**: Define module interfaces, variable schemas, and integration contracts

---

## Overview

This document defines the contracts (interfaces) for all Terraform modules used in this infrastructure deployment. Each contract specifies required inputs, optional inputs with defaults, outputs, and module version constraints.

---

## 1. VPC Module Contract

**Module Source**: `app.terraform.io/hashi-demos-apj/vpc/aws`
**Module Version**: `~> 6.5.0`
**Provider Requirement**: AWS Provider >= 6.0

### Required Inputs

```hcl
variable "name" {
  description = "Name to be used on all VPC resources as identifier"
  type        = string
}

variable "cidr" {
  description = "The IPv4 CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Must specify at least 2 availability zones for high availability."
  }
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "Must specify at least 2 public subnets across different AZs for ALB."
  }
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "Must specify at least 2 private subnets across different AZs for HA."
  }
}
```

### Recommended Inputs

```hcl
variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = true
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want only one NAT Gateway per availability zone"
  type        = bool
  default     = true  # For HA, create one NAT GW per AZ
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
```

### Module Outputs

```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}
```

### Example Usage

```hcl
module "vpc" {
  source  = "app.terraform.io/hashi-demos-apj/vpc/aws"
  version = "~> 6.5.0"

  name = "webapp-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway   = true
  one_nat_gateway_per_az = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

---

## 2. EC2 Instance Module Contract

**Module Source**: `app.terraform.io/hashi-demos-apj/ec2-instance/aws`
**Module Version**: `~> 5.0.0`
**Provider Requirement**: AWS Provider >= 4.20

**Note**: This module creates single instances. For Auto Scaling Group, we need to use Launch Template + ASG resources or public module.

### Required Inputs (when used standalone)

```hcl
variable "name" {
  description = "Name to be used on EC2 instance created"
  type        = string
}

variable "ami" {
  description = "ID of AMI to use for the instance"
  type        = string
  default     = null  # Can use ami_ssm_parameter instead
}

variable "ami_ssm_parameter" {
  description = "SSM parameter name for the AMI ID"
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "instance_type" {
  description = "The type of instance to start"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "The VPC Subnet ID to launch in"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "A list of security group IDs to associate with"
  type        = list(string)
}
```

### Recommended Inputs

```hcl
variable "user_data" {
  description = "The user data to provide when launching the instance"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile to launch the instance with"
  type        = string
  default     = null
}

variable "metadata_options" {
  description = "Customize the metadata options of the instance"
  type        = map(string)
  default = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 only
    http_put_response_hop_limit = 1
  }
}

variable "root_block_device" {
  description = "Customize details about the root block device of the instance"
  type        = list(any)
  default = [{
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }]
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
```

### Module Outputs

```hcl
output "id" {
  description = "The ID of the instance"
  value       = module.ec2_instance.id
}

output "private_ip" {
  description = "The private IP address assigned to the instance"
  value       = module.ec2_instance.private_ip
}

output "arn" {
  description = "The ARN of the instance"
  value       = module.ec2_instance.arn
}
```

---

## 3. Application Load Balancer Contract

**Module Source**: `terraform-aws-modules/alb/aws` (Public Registry - requires approval)
**Module Version**: `~> 9.0`
**Provider Requirement**: AWS Provider >= 5.0

**Status**: ⚠️ Not available in private registry. Requires user approval to use public module.

### Required Inputs

```hcl
variable "name" {
  description = "The name of the LB"
  type        = string
}

variable "load_balancer_type" {
  description = "The type of load balancer to create"
  type        = string
  default     = "application"
}

variable "vpc_id" {
  description = "VPC ID where the load balancer will be deployed"
  type        = string
}

variable "subnets" {
  description = "A list of subnet IDs to attach to the LB"
  type        = list(string)

  validation {
    condition     = length(var.subnets) >= 2
    error_message = "ALB requires at least 2 subnets in different AZs."
  }
}

variable "security_groups" {
  description = "A list of security group IDs to assign to the LB"
  type        = list(string)
}
```

### Recommended Inputs

```hcl
variable "internal" {
  description = "Whether the load balancer is internal or internet-facing"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "If true, deletion of the load balancer will be disabled via the AWS API"
  type        = bool
  default     = false
}

variable "enable_cross_zone_load_balancing" {
  description = "If true, cross-zone load balancing will be enabled"
  type        = bool
  default     = true
}

variable "listeners" {
  description = "Map of listener configurations"
  type        = any
  default     = {}
}

variable "target_groups" {
  description = "Map of target group configurations"
  type        = any
  default     = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
```

### Listener Configuration Schema

```hcl
# HTTP Listener (Port 80) - Redirect to HTTPS
listener_http = {
  port     = 80
  protocol = "HTTP"

  default_actions = [{
    type = "redirect"
    redirect = {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }]
}

# HTTPS Listener (Port 443)
listener_https = {
  port            = 443
  protocol        = "HTTPS"
  certificate_arn = "<acm-certificate-arn>"
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_actions = [{
    type             = "forward"
    target_group_key = "webapp_tg"
  }]
}
```

### Target Group Configuration Schema

```hcl
webapp_tg = {
  name_prefix = "webapp-"
  protocol    = "HTTP"
  port        = 80
  target_type = "instance"

  deregistration_delay = 30

  health_check = {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  tags = {
    Name = "webapp-target-group"
  }
}
```

### Module Outputs

```hcl
output "lb_arn" {
  description = "The ARN of the load balancer"
  value       = module.alb.lb_arn
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.alb.lb_dns_name
}

output "lb_zone_id" {
  description = "The zone_id of the load balancer"
  value       = module.alb.lb_zone_id
}

output "target_group_arns" {
  description = "ARNs of the target groups"
  value       = module.alb.target_group_arns
}
```

---

## 4. Auto Scaling Group Contract

**Module Source**: `terraform-aws-modules/autoscaling/aws` (Public Registry - requires approval)
**Module Version**: `~> 7.0`
**Provider Requirement**: AWS Provider >= 5.0

**Status**: ⚠️ Not available in private registry. Requires user approval to use public module.

### Required Inputs

```hcl
variable "name" {
  description = "Name used across the resources created"
  type        = string
}

variable "min_size" {
  description = "The minimum size of the Auto Scaling Group"
  type        = number

  validation {
    condition     = var.min_size >= 2
    error_message = "Minimum 2 instances required for high availability."
  }
}

variable "max_size" {
  description = "The maximum size of the Auto Scaling Group"
  type        = number

  validation {
    condition     = var.max_size >= var.min_size * 3
    error_message = "Max size must be at least 3x min size for 200% scaling headroom."
  }
}

variable "desired_capacity" {
  description = "The number of instances that should be running"
  type        = number
}

variable "vpc_zone_identifier" {
  description = "A list of subnet IDs to launch resources in"
  type        = list(string)
}
```

### Launch Template Configuration

```hcl
variable "image_id" {
  description = "The AMI from which to launch the instance"
  type        = string
}

variable "instance_type" {
  description = "The type of the instance"
  type        = string
  default     = "t3.micro"
}

variable "security_groups" {
  description = "A list of security group IDs to associate"
  type        = list(string)
}

variable "user_data" {
  description = "The Base64-encoded user data to provide when launching the instance"
  type        = string
  default     = ""
}

variable "iam_instance_profile_arn" {
  description = "Amazon Resource Name (ARN) of an existing IAM instance profile"
  type        = string
}

variable "block_device_mappings" {
  description = "Specify volumes to attach to the instance besides the volumes specified by the AMI"
  type        = any
  default = [{
    device_name = "/dev/xvda"
    ebs = {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }]
}

variable "metadata_options" {
  description = "Customize the metadata options for the instance"
  type        = map(string)
  default = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2
    http_put_response_hop_limit = 1
  }
}
```

### Health Check Configuration

```hcl
variable "health_check_type" {
  description = "Type of health check. Valid values are EC2 or ELB"
  type        = string
  default     = "ELB"
}

variable "health_check_grace_period" {
  description = "Time after instance comes into service before checking health"
  type        = number
  default     = 300
}
```

### Scaling Configuration

```hcl
variable "target_group_arns" {
  description = "A set of aws_alb_target_group ARNs, for use with Application Load Balancing"
  type        = list(string)
  default     = []
}

variable "default_cooldown" {
  description = "The amount of time, in seconds, after a scaling activity completes before another scaling activity can start"
  type        = number
  default     = 300
}

variable "termination_policies" {
  description = "A list of policies to decide how the instances in the Auto Scaling Group should be terminated"
  type        = list(string)
  default     = ["OldestInstance"]
}
```

### Scaling Policy Configuration

```hcl
variable "scaling_policies" {
  description = "Map of scaling policies to create"
  type        = any
  default = {
    cpu_target_tracking = {
      policy_type = "TargetTrackingScaling"
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 50.0
      }
    }
  }
}
```

### Module Outputs

```hcl
output "autoscaling_group_id" {
  description = "The Auto Scaling Group id"
  value       = module.asg.autoscaling_group_id
}

output "autoscaling_group_name" {
  description = "The Auto Scaling Group name"
  value       = module.asg.autoscaling_group_name
}

output "autoscaling_group_arn" {
  description = "The ARN for this Auto Scaling Group"
  value       = module.asg.autoscaling_group_arn
}

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = module.asg.launch_template_id
}
```

---

## 5. Security Group Contract (Raw Resources)

**Resource Type**: `aws_security_group`
**Approach**: Create raw resources (no module available in private registry)

### ALB Security Group Schema

```hcl
resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # Inbound Rules
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rules
  egress {
    description     = "HTTP to EC2 instances"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
```

### EC2 Security Group Schema

```hcl
resource "aws_security_group" "ec2" {
  name_prefix = "${var.name}-ec2-"
  description = "Security group for EC2 instances in Auto Scaling Group"
  vpc_id      = var.vpc_id

  # Inbound Rules
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound Rules
  egress {
    description = "HTTPS to Internet for S3 and package updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP to Internet for package downloads"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-ec2-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
```

---

## 6. ACM Certificate Contract (Raw Resource)

**Resource Type**: `aws_acm_certificate`

### Certificate Schema

```hcl
variable "domain_name" {
  description = "Primary domain name for the certificate"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "Must be a valid domain name."
  }
}

variable "subject_alternative_names" {
  description = "Additional domain names for the certificate"
  type        = list(string)
  default     = []
}

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name}-certificate"
  })
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
```

### DNS Validation Records (if using Route53)

```hcl
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}
```

### Outputs

```hcl
output "certificate_arn" {
  description = "The ARN of the certificate"
  value       = aws_acm_certificate.main.arn
}

output "certificate_domain_validation_options" {
  description = "Domain validation options for the certificate"
  value       = aws_acm_certificate.main.domain_validation_options
}
```

---

## 7. IAM Role & Instance Profile Contract (Raw Resources)

**Resource Types**: `aws_iam_role`, `aws_iam_instance_profile`, `aws_iam_role_policy_attachment`

### IAM Role Schema

```hcl
resource "aws_iam_role" "ec2" {
  name_prefix = "${var.name}-ec2-role-"
  description = "IAM role for EC2 instances to access AWS services"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-ec2-role"
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${var.name}-ec2-profile-"
  role        = aws_iam_role.ec2.name

  tags = var.tags
}
```

### Policy Attachments

```hcl
# Session Manager access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 read access (custom inline policy)
resource "aws_iam_role_policy" "s3_read" {
  name_prefix = "${var.name}-s3-read-"
  role        = aws_iam_role.ec2.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.static_content.arn,
        "${aws_s3_bucket.static_content.arn}/*"
      ]
    }]
  })
}
```

### Outputs

```hcl
output "iam_role_arn" {
  description = "ARN of IAM role for EC2 instances"
  value       = aws_iam_role.ec2.arn
}

output "iam_instance_profile_name" {
  description = "Name of IAM instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "iam_instance_profile_arn" {
  description = "ARN of IAM instance profile"
  value       = aws_iam_instance_profile.ec2.arn
}
```

---

## 8. S3 Bucket Contract (Raw Resource)

**Resource Type**: `aws_s3_bucket` + related resources

### S3 Bucket Schema

```hcl
variable "bucket_name_prefix" {
  description = "Prefix for S3 bucket name (will append random suffix for uniqueness)"
  type        = string
  default     = "webapp-static-content"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "static_content" {
  bucket = "${var.bucket_name_prefix}-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name        = "${var.name}-static-content"
    Purpose     = "Static web content storage"
  })
}

# Versioning
resource "aws_s3_bucket_versioning" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket Policy - Allow EC2 IAM role access only
resource "aws_s3_bucket_policy" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEC2RoleAccess"
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.ec2.arn
      }
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.static_content.arn,
        "${aws_s3_bucket.static_content.arn}/*"
      ]
    }]
  })
}
```

### Lifecycle Policy (Optional)

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}
```

### Outputs

```hcl
output "s3_bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.static_content.id
}

output "s3_bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.static_content.arn
}
```

---

## Integration Contract Summary

### Module Dependency Graph

```
VPC Module (private)
  ├─> Outputs: vpc_id, public_subnets, private_subnets
  └─> Used by: ALB, ASG, Security Groups

Security Groups (raw resources)
  ├─> Requires: vpc_id from VPC
  └─> Used by: ALB, ASG

ACM Certificate (raw resource)
  ├─> Requires: domain_name (user input)
  └─> Used by: ALB HTTPS Listener

S3 Bucket (raw resource)
  └─> Used by: EC2 instances via IAM role

IAM Role + Instance Profile (raw resources)
  ├─> Requires: s3_bucket_arn
  └─> Used by: ASG Launch Template

ALB Module (public - requires approval)
  ├─> Requires: vpc_id, public_subnets, alb_security_group_id, certificate_arn
  └─> Outputs: target_group_arns, lb_dns_name

Auto Scaling Group Module (public - requires approval)
  ├─> Requires: private_subnets, ec2_security_group_id, target_group_arns, iam_instance_profile_arn
  └─> Outputs: autoscaling_group_id
```

### Variable Propagation

```hcl
# Root variables.tf defines all inputs
variable "environment" {}
variable "vpc_cidr" {}
variable "domain_name" {}

# VPC module uses root variables
module "vpc" {
  cidr = var.vpc_cidr
}

# Security groups use VPC outputs
resource "aws_security_group" "alb" {
  vpc_id = module.vpc.vpc_id
}

# ALB uses VPC outputs and security group IDs
module "alb" {
  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.alb.id]
}

# ASG uses VPC outputs, security groups, and ALB outputs
module "asg" {
  vpc_zone_identifier = module.vpc.private_subnets
  security_groups     = [aws_security_group.ec2.id]
  target_group_arns   = module.alb.target_group_arns
}
```

---

## Validation Requirements

### Pre-Deployment Validation

1. **User Approval Required**:
   - ✅ VPC module: Available in private registry
   - ⚠️ ALB module: Public registry - requires user approval
   - ⚠️ ASG module: Public registry - requires user approval

2. **User Input Required**:
   - Domain name for ACM certificate
   - HCP Terraform project and workspace names
   - Static content source/upload method

3. **AWS Prerequisites**:
   - AWS credentials configured in HCP Terraform workspace variable sets
   - Domain DNS access for ACM validation

### Post-Deployment Validation

1. **Health Checks**:
   - ALB target group shows healthy targets
   - ASG desired capacity matches actual running instances
   - ACM certificate status is "Issued"

2. **Connectivity**:
   - ALB DNS name resolves and responds to HTTPS requests
   - HTTP redirects to HTTPS (301)
   - EC2 instances can reach S3 bucket
   - NAT gateways are active

---

## Conclusion

This contract specification defines:
- **3 private modules**: VPC, EC2 Instance (though EC2 not used directly due to ASG requirement)
- **2 public modules** (require approval): ALB, Auto Scaling Group
- **5 raw resource types**: Security Groups, ACM Certificate, IAM Role/Profile, S3 Bucket

**Next Steps**: Generate quickstart.md with deployment instructions, then update agent context.
