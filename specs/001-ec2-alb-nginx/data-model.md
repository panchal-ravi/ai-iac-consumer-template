# Data Model: AWS EC2 Infrastructure with Application Load Balancer and Nginx

**Feature**: EC2 ALB Nginx Infrastructure  
**Created**: 2025-01-10  
**Version**: 1.0  
**Status**: Draft

## Overview

This document defines the comprehensive data model for provisioning a highly available web infrastructure in AWS ap-southeast-1 region. The infrastructure consists of EC2 instances running Nginx web server behind an Application Load Balancer with HTTPS termination using a self-signed TLS certificate.

---

## 1. Terraform Resource Graph and Dependencies

### 1.1 Resource Dependency Tree

```
Root Resources (No Dependencies)
├── aws_vpc (data source - default VPC lookup)
├── aws_availability_zones (data source)
└── tls_private_key (self-signed certificate generation)
    └── tls_self_signed_cert (depends on: tls_private_key)
        └── aws_acm_certificate (depends on: tls_self_signed_cert, tls_private_key)
            └── aws_lb (depends on: aws_security_group.alb, aws_subnet.* data sources)
                ├── aws_lb_listener (depends on: aws_lb, aws_acm_certificate, aws_lb_target_group)
                └── aws_lb_target_group (depends on: aws_vpc data source)
                    └── aws_lb_target_group_attachment (depends on: aws_instance.*, aws_lb_target_group)

Independent Branches
├── aws_security_group.alb (depends on: aws_vpc data source)
└── aws_security_group.ec2 (depends on: aws_vpc data source, aws_security_group.alb)
    └── aws_instance.* (depends on: aws_security_group.ec2, aws_subnet.* data sources, aws_ami data source)
```


### 1.2 Resource Creation Order

**Phase 1: Data Sources & Certificate Generation**
1. Data: AWS default VPC
2. Data: AWS availability zones in ap-southeast-1
3. Data: AWS subnets in default VPC
4. Data: Latest Amazon Linux 2 AMI
5. Resource: TLS private key (4096-bit RSA)
6. Resource: TLS self-signed certificate (valid 365 days)
7. Resource: AWS ACM certificate import

**Phase 2: Network Security**
8. Resource: Security group for ALB (allow HTTPS:443 from internet)
9. Resource: Security group for EC2 (allow HTTP:80 from ALB SG only)

**Phase 3: Compute & Load Balancing**
10. Resource: EC2 instances (2x t3.micro) in different AZs with Nginx user data
11. Resource: ALB target group with health check configuration
12. Resource: Target group attachments (register EC2 instances)
13. Resource: Application Load Balancer (internet-facing, multi-AZ)
14. Resource: ALB HTTPS listener (port 443, forward to target group)

### 1.3 Critical Dependencies

| Resource | Depends On | Reason |
|----------|-----------|--------|
| `aws_acm_certificate` | `tls_self_signed_cert`, `tls_private_key` | Requires certificate and private key for import |
| `aws_lb_listener` | `aws_lb`, `aws_acm_certificate`, `aws_lb_target_group` | Must have ALB, certificate ARN, and target group ARN |
| `aws_security_group.ec2` | `aws_security_group.alb` | Ingress rule references ALB security group ID |
| `aws_lb_target_group_attachment` | `aws_instance.*`, `aws_lb_target_group` | Must have instance IDs and target group ARN |
| `aws_instance.*` | `aws_ami` data, `aws_subnet.*` data, `aws_security_group.ec2` | Requires AMI ID, subnet ID, and security group ID |

---

## 2. Input Variables

### 2.1 Required Variables

```hcl
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
```

### 2.2 Optional Variables

```hcl
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

variable "certificate_validity_hours" {
  description = "Validity period for self-signed certificate in hours (default: 1 year)"
  type        = number
  default     = 8760  # 365 days
}

variable "health_check_path" {
  description = "HTTP path for ALB target group health checks"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Interval between health checks in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Timeout for health check responses in seconds"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks before marking target healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking target unhealthy"
  type        = number
  default     = 2
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB (recommended false for dev)"
  type        = bool
  default     = false
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing for ALB"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

---

## 3. Data Sources

### 3.1 VPC and Network Data Sources

```hcl
# Default VPC in ap-southeast-1
data "aws_vpc" "default" {
  default = true
}

# All availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
  
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Default subnets in each availability zone
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

# Individual subnet details for each AZ
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}
```

### 3.2 AMI Data Source

```hcl
# Latest Amazon Linux 2 AMI (x86_64, EBS-backed, HVM)
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}
```

### 3.3 Data Source Attributes Used

| Data Source | Attribute | Purpose |
|-------------|-----------|---------|
| `aws_vpc.default` | `id` | VPC ID for security groups and target group |
| `aws_vpc.default` | `cidr_block` | VPC CIDR for reference |
| `aws_availability_zones.available` | `names` | List of AZ names for instance placement |
| `aws_subnets.default` | `ids` | Subnet IDs for ALB and EC2 instances |
| `aws_subnet.default` | `availability_zone` | Specific AZ for each subnet |
| `aws_ami.amazon_linux_2` | `id` | AMI ID for EC2 instance launch |
| `aws_ami.amazon_linux_2` | `name` | AMI name for documentation |


---

## 4. Output Values

### 4.1 Load Balancer Outputs

```hcl
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the ALB (for DNS alias records)"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix for use with CloudWatch metrics"
  value       = aws_lb.main.arn_suffix
}

output "alb_https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}
```

### 4.2 Target Group Outputs

```hcl
output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group for CloudWatch metrics"
  value       = aws_lb_target_group.main.arn_suffix
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.main.name
}
```

### 4.3 EC2 Instance Outputs

```hcl
output "ec2_instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.web[*].id
}

output "ec2_instance_private_ips" {
  description = "List of private IP addresses for EC2 instances"
  value       = aws_instance.web[*].private_ip
}

output "ec2_instance_availability_zones" {
  description = "Availability zones where EC2 instances are deployed"
  value       = aws_instance.web[*].availability_zone
}

output "ec2_instance_ami_id" {
  description = "AMI ID used for EC2 instances"
  value       = data.aws_ami.amazon_linux_2.id
}
```

### 4.4 Security Group Outputs

```hcl
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 instance security group"
  value       = aws_security_group.ec2.id
}

output "alb_security_group_name" {
  description = "Name of the ALB security group"
  value       = aws_security_group.alb.name
}

output "ec2_security_group_name" {
  description = "Name of the EC2 instance security group"
  value       = aws_security_group.ec2.name
}
```

### 4.5 Certificate Outputs

```hcl
output "acm_certificate_arn" {
  description = "ARN of the imported ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "certificate_domain" {
  description = "Domain name of the TLS certificate"
  value       = var.certificate_domain
}

output "certificate_expiration" {
  description = "Certificate expiration date"
  value       = aws_acm_certificate.main.not_after
}
```

### 4.6 Access and Testing Outputs

```hcl
output "application_url" {
  description = "HTTPS URL to access the application via ALB"
  value       = "https://${aws_lb.main.dns_name}"
}

output "test_commands" {
  description = "Commands to test the infrastructure"
  value = {
    https_test = "curl -k https://${aws_lb.main.dns_name}"
    health_check = "aws elbv2 describe-target-health --target-group-arn ${aws_lb_target_group.main.arn} --region ${var.region}"
  }
}
```


---

## 5. Resource Relationships and Entity Model

### 5.1 Entity Relationship Diagram

```
┌─────────────────────────┐
│   TLS Private Key       │
│   (tls_private_key)     │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│ Self-Signed Certificate │
│ (tls_self_signed_cert)  │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐         ┌─────────────────────────┐
│   ACM Certificate       │────────▶│   Application LB        │
│ (aws_acm_certificate)   │         │     (aws_lb)            │
└─────────────────────────┘         └──────────┬──────────────┘
                                               │
                                               │ has listener
                                               │
                                               ▼
                          ┌────────────────────────────────────┐
                          │      HTTPS Listener (443)          │
                          │    (aws_lb_listener)               │
                          └────────────┬───────────────────────┘
                                       │
                                       │ forwards to
                                       │
                                       ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│  ALB Security Group     │    │    Target Group         │
│ (aws_security_group)    │    │ (aws_lb_target_group)   │
│  - Ingress: 443/tcp     │    │  - Protocol: HTTP       │
│  - Source: 0.0.0.0/0    │    │  - Port: 80             │
└──────────┬──────────────┘    └──────────┬──────────────┘
           │                              │
           │ allows traffic from          │ contains
           │                              │
           ▼                              ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│  EC2 Security Group     │    │  Target Attachments     │
│ (aws_security_group)    │    │ (aws_lb_target_group_   │
│  - Ingress: 80/tcp      │    │  attachment)            │
│  - Source: ALB SG       │    └──────────┬──────────────┘
└──────────┬──────────────┘               │
           │                              │ registers
           │ attached to                  │
           │                              │
           ▼                              ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│  EC2 Instance 1         │    │  EC2 Instance 2         │
│  (aws_instance)         │    │  (aws_instance)         │
│  - AZ: ap-southeast-1a  │    │  - AZ: ap-southeast-1b  │
│  - Type: t3.micro       │    │  - Type: t3.micro       │
│  - Nginx installed      │    │  - Nginx installed      │
└─────────────────────────┘    └─────────────────────────┘
           │                              │
           └──────────┬───────────────────┘
                      │
                      │ deployed in
                      │
                      ▼
           ┌─────────────────────────┐
           │    Default VPC          │
           │    (data source)        │
           │  - Default subnets      │
           │  - Multiple AZs         │
           └─────────────────────────┘
```

### 5.2 Key Entity Definitions

#### 5.2.1 TLS Certificate Entity

```hcl
entity "tls_certificate" {
  # Primary Key
  acm_arn = string  # ARN in ACM after import
  
  # Attributes
  domain_name         = string  # "web.demo.com"
  private_key_pem     = string  # Private key (sensitive)
  certificate_pem     = string  # Public certificate
  algorithm           = string  # "RSA"
  rsa_bits            = number  # 4096
  validity_hours      = number  # 8760 (1 year)
  
  # Relationships
  used_by_listener    = aws_lb_listener.https
  
  # Lifecycle
  create_before_destroy = true
}
```

#### 5.2.2 Application Load Balancer Entity

```hcl
entity "application_load_balancer" {
  # Primary Key
  arn = string
  
  # Attributes
  name                = string  # "ec2-alb-nginx-alb"
  load_balancer_type  = string  # "application"
  internal            = bool    # false (internet-facing)
  dns_name            = string  # Auto-generated
  zone_id             = string  # Route53 zone ID
  
  # Network Configuration
  subnets             = list(string)  # Multiple AZ subnets
  security_groups     = list(string)  # [alb_sg_id]
  
  # Features
  enable_deletion_protection          = bool  # false for dev
  enable_cross_zone_load_balancing    = bool  # true
  enable_http2                        = bool  # true (default)
  
  # Relationships
  has_listeners       = list(aws_lb_listener)
  protected_by        = aws_security_group.alb
  
  # Tags
  tags                = map(string)
}
```

#### 5.2.3 Target Group Entity

```hcl
entity "target_group" {
  # Primary Key
  arn = string
  
  # Attributes
  name                = string  # "ec2-alb-nginx-tg"
  port                = number  # 80
  protocol            = string  # "HTTP"
  vpc_id              = string
  target_type         = string  # "instance"
  
  # Health Check Configuration
  health_check {
    enabled             = bool    # true
    path                = string  # "/"
    protocol            = string  # "HTTP"
    port                = string  # "traffic-port"
    interval            = number  # 30 seconds
    timeout             = number  # 5 seconds
    healthy_threshold   = number  # 2
    unhealthy_threshold = number  # 2
    matcher             = string  # "200"
  }
  
  # Connection Settings
  deregistration_delay  = number  # 300 seconds
  
  # Stickiness
  stickiness {
    enabled         = bool    # false
    type            = string  # "lb_cookie"
    cookie_duration = number  # 86400
  }
  
  # Relationships
  contains_targets    = list(aws_lb_target_group_attachment)
  receives_from       = aws_lb_listener.https
  
  # Tags
  tags                = map(string)
}
```

#### 5.2.4 EC2 Instance Entity

```hcl
entity "ec2_instance" {
  # Primary Key
  id = string  # Instance ID
  
  # Attributes
  ami                     = string  # Amazon Linux 2 AMI ID
  instance_type           = string  # "t3.micro"
  availability_zone       = string  # Specific AZ
  subnet_id               = string
  private_ip              = string  # Auto-assigned
  
  # Security
  vpc_security_group_ids  = list(string)  # [ec2_sg_id]
  iam_instance_profile    = string        # Optional
  
  # Bootstrap Configuration
  user_data               = string  # Nginx installation script
  user_data_replace_on_change = bool  # true
  
  # Storage
  root_block_device {
    volume_type           = string  # "gp3"
    volume_size           = number  # 8 GB
    delete_on_termination = bool    # true
    encrypted             = bool    # true
  }
  
  # Monitoring
  monitoring              = bool    # false (detailed monitoring)
  
  # Metadata Service
  metadata_options {
    http_endpoint               = string  # "enabled"
    http_tokens                 = string  # "required" (IMDSv2)
    http_put_response_hop_limit = number  # 1
  }
  
  # Relationships
  member_of_target_group  = aws_lb_target_group.main
  protected_by            = aws_security_group.ec2
  
  # Tags
  tags                    = map(string)
}
```

#### 5.2.5 Security Group Entity (ALB)

```hcl
entity "security_group_alb" {
  # Primary Key
  id = string
  
  # Attributes
  name        = string  # "ec2-alb-nginx-alb-sg"
  description = string  # "Security group for Application Load Balancer"
  vpc_id      = string
  
  # Ingress Rules
  ingress {
    description      = "HTTPS from internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  # Egress Rules
  egress {
    description      = "HTTP to EC2 instances"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = [aws_security_group.ec2.id]
  }
  
  # Relationships
  protects            = aws_lb.main
  allows_traffic_to   = aws_security_group.ec2
  
  # Tags
  tags                = map(string)
}
```

#### 5.2.6 Security Group Entity (EC2)

```hcl
entity "security_group_ec2" {
  # Primary Key
  id = string
  
  # Attributes
  name        = string  # "ec2-alb-nginx-ec2-sg"
  description = string  # "Security group for EC2 instances"
  vpc_id      = string
  
  # Ingress Rules
  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  # Egress Rules
  egress {
    description      = "All outbound traffic for updates"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  # Relationships
  protects            = list(aws_instance.web)
  allows_traffic_from = aws_security_group.alb
  
  # Tags
  tags                = map(string)
}
```

### 5.3 Resource Attributes Summary

| Resource Type | Count | Key Attributes | Dependencies |
|---------------|-------|----------------|--------------|
| `tls_private_key` | 1 | algorithm=RSA, rsa_bits=4096 | None |
| `tls_self_signed_cert` | 1 | subject.CN=web.demo.com, validity_period_hours=8760 | tls_private_key |
| `aws_acm_certificate` | 1 | private_key_pem, certificate_body | tls_self_signed_cert |
| `aws_security_group` (ALB) | 1 | ingress: 443/tcp from 0.0.0.0/0 | aws_vpc data |
| `aws_security_group` (EC2) | 1 | ingress: 80/tcp from ALB SG | aws_vpc data, alb_sg |
| `aws_instance` | 2 | type=t3.micro, user_data=nginx install | ami data, subnet data, ec2_sg |
| `aws_lb_target_group` | 1 | port=80, protocol=HTTP, health_check | aws_vpc data |
| `aws_lb_target_group_attachment` | 2 | One per instance | instances, target_group |
| `aws_lb` | 1 | type=application, internal=false | subnets, alb_sg |
| `aws_lb_listener` | 1 | port=443, protocol=HTTPS | alb, acm_cert, target_group |


---

## 6. State Transitions and Lifecycle

### 6.1 Resource State Machine

#### Infrastructure Provisioning States

```
START
  │
  ├──▶ [Data Discovery]
  │     - Query default VPC
  │     - Query availability zones
  │     - Query subnets
  │     - Query latest AMI
  │
  ├──▶ [Certificate Generation]
  │     - Generate private key
  │     - Create self-signed certificate
  │     - Import to ACM
  │     State: ISSUED (ACM)
  │
  ├──▶ [Network Security Setup]
  │     - Create ALB security group
  │     - Create EC2 security group
  │     State: ACTIVE
  │
  ├──▶ [Compute Provisioning]
  │     - Launch EC2 instances (2)
  │     - Execute user data (Nginx install)
  │     State: RUNNING → HEALTHY
  │
  ├──▶ [Load Balancer Configuration]
  │     - Create target group
  │     - Register instances
  │     - Create ALB
  │     - Create HTTPS listener
  │     State: ACTIVE → PROVISIONING → ACTIVE
  │
  └──▶ [Health Check Validation]
        - Wait for healthy targets (2/2)
        - Validate HTTPS access
        State: HEALTHY
        │
        ▼
      [OPERATIONAL]
```

#### Target Health State Transitions

```
INITIAL
  │
  ▼
UNUSED
  │
  │ (register target)
  │
  ▼
INITIAL (health check pending)
  │
  ├──▶ (health check passes) ──▶ HEALTHY
  │                                 │
  │                                 ├──▶ (health check fails) ──▶ UNHEALTHY
  │                                 │                                  │
  │                                 │                                  └──▶ (recovers) ──▶ HEALTHY
  │                                 │
  │                                 └──▶ (deregister) ──▶ DRAINING ──▶ UNUSED
  │
  └──▶ (health check fails) ──▶ UNHEALTHY
                                    │
                                    ├──▶ (recovers) ──▶ HEALTHY
                                    │
                                    └──▶ (deregister) ──▶ DRAINING ──▶ UNUSED
```

### 6.2 Terraform Lifecycle Rules

```hcl
# Certificate resources - create before destroy to avoid downtime
resource "aws_acm_certificate" "main" {
  lifecycle {
    create_before_destroy = true
  }
}

# Security groups - prevent accidental deletion
resource "aws_security_group" "alb" {
  lifecycle {
    prevent_destroy = false  # Set true for production
  }
}

# EC2 instances - replace on user_data change
resource "aws_instance" "web" {
  user_data_replace_on_change = true
  
  lifecycle {
    create_before_destroy = false
    ignore_changes       = []
  }
}

# ALB - protect from accidental deletion
resource "aws_lb" "main" {
  lifecycle {
    prevent_destroy = false  # Set true for production
  }
}

# Target group - create new before destroying old
resource "aws_lb_target_group" "main" {
  lifecycle {
    create_before_destroy = true
  }
}
```

---

## 7. Data Flow Diagram

### 7.1 Request Flow (HTTPS → Backend)

```
Internet User
     │
     │ HTTPS Request (port 443)
     │ Host: <alb-dns-name>
     │
     ▼
┌─────────────────────────────────────────┐
│   Application Load Balancer             │
│   - Receives HTTPS on port 443          │
│   - Terminates TLS using ACM cert       │
│   - Security Group: Allow 443 from all  │
└────────────────┬────────────────────────┘
                 │
                 │ HTTP Request (port 80)
                 │ TLS terminated
                 │
                 ├──────────────────┐
                 │                  │
                 ▼                  ▼
     ┌───────────────────┐  ┌───────────────────┐
     │  EC2 Instance 1   │  │  EC2 Instance 2   │
     │  (AZ 1a)          │  │  (AZ 1b)          │
     │  - Nginx:80       │  │  - Nginx:80       │
     │  - SG: Allow 80   │  │  - SG: Allow 80   │
     │    from ALB SG    │  │    from ALB SG    │
     └─────────┬─────────┘  └─────────┬─────────┘
               │                      │
               │ HTTP 200 OK          │ HTTP 200 OK
               │ Content: HTML        │ Content: HTML
               │                      │
               └──────────┬───────────┘
                          │
                          ▼
          Application Load Balancer
                          │
                          │ HTTPS Response
                          │ Encrypted with TLS
                          │
                          ▼
                   Internet User
```

### 7.2 Health Check Flow

```
┌──────────────────────────────────────┐
│   Target Group                       │
│   - Health Check: HTTP:80 GET /     │
│   - Interval: 30s                    │
│   - Timeout: 5s                      │
│   - Threshold: 2 healthy / 2 unhealthy │
└──────────────┬───────────────────────┘
               │
               │ Every 30 seconds
               │
               ├────────────────────────┐
               │                        │
               ▼                        ▼
   ┌────────────────────┐    ┌────────────────────┐
   │  Instance 1        │    │  Instance 2        │
   │                    │    │                    │
   │  GET / HTTP/1.1    │    │  GET / HTTP/1.1    │
   │  Host: <private>   │    │  Host: <private>   │
   └──────────┬─────────┘    └──────────┬─────────┘
              │                         │
              │ Response:               │ Response:
              │ HTTP 200 OK             │ HTTP 200 OK
              │ (healthy)               │ (healthy)
              │                         │
              └──────────┬──────────────┘
                         │
                         ▼
              Target Group Status:
              - Instance 1: HEALTHY
              - Instance 2: HEALTHY
              - Overall: 2/2 healthy
```

---

## 8. Validation Rules and Constraints

### 8.1 Pre-Deployment Validation

```hcl
# Validate default VPC exists
data "aws_vpc" "default" {
  default = true
}

# If VPC doesn't exist, Terraform will fail with:
# Error: no matching VPC found

# Validate sufficient availability zones
locals {
  required_azs = 2
  available_azs = length(data.aws_availability_zones.available.names)
  
  validation_checks = {
    az_count = local.available_azs >= local.required_azs
  }
}

# Error if insufficient AZs
check "availability_zones" {
  assert {
    condition     = local.validation_checks.az_count
    error_message = "At least ${local.required_azs} availability zones required, found ${local.available_azs}"
  }
}

# Validate AMI exists
check "ami_available" {
  assert {
    condition     = data.aws_ami.amazon_linux_2.id != ""
    error_message = "Amazon Linux 2 AMI not found in region ${var.region}"
  }
}
```

### 8.2 Resource Constraints

| Resource | Constraint | Validation Method |
|----------|-----------|-------------------|
| VPC | Must be default VPC | Data source filter `default = true` |
| Subnets | Must have ≥2 subnets in different AZs | Check `length(data.aws_subnets.default.ids) >= 2` |
| Instances | Must be in different AZs | Use `element(distinct(...), count.index)` |
| Instance Type | Must be t3.micro | Variable validation rule |
| Certificate Domain | Must be valid DNS name | Regex validation `^[a-z0-9][a-z0-9-\\.]*[a-z0-9]$` |
| Region | Must be ap-southeast-1 | Variable validation rule |
| Instance Count | Must equal 2 | Variable validation rule |
| Security Groups | ALB SG must allow 443; EC2 SG must reference ALB SG | Resource configuration validation |

### 8.3 Post-Deployment Validation

```bash
# Validate ALB is active
aws elbv2 describe-load-balancers \
  --load-balancer-arns <alb-arn> \
  --query 'LoadBalancers[0].State.Code' \
  --output text
# Expected: active

# Validate target health
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[*].TargetHealth.State' \
  --output text
# Expected: healthy healthy

# Validate HTTPS connectivity
curl -k -I https://<alb-dns-name>
# Expected: HTTP/2 200

# Validate certificate
echo | openssl s_client -connect <alb-dns-name>:443 -servername web.demo.com 2>/dev/null | \
  openssl x509 -noout -subject
# Expected: subject=CN = web.demo.com

# Validate instances in different AZs
aws ec2 describe-instances \
  --instance-ids <id1> <id2> \
  --query 'Reservations[*].Instances[*].Placement.AvailabilityZone' \
  --output text
# Expected: ap-southeast-1a ap-southeast-1b (or similar)
```


---

## 9. Tagging Strategy

### 9.1 Common Tags (Applied to All Resources)

```hcl
locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "github.com/org/repo"
      Owner       = var.owner
      CostCenter  = var.cost_center
      CreatedDate = timestamp()
    },
    var.common_tags
  )
  
  # Resource-specific tags
  alb_tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-alb"
      Component   = "load-balancer"
      Public      = "true"
    }
  )
  
  ec2_tags = merge(
    local.common_tags,
    {
      Component   = "web-server"
      Application = "nginx"
    }
  )
  
  security_group_tags = merge(
    local.common_tags,
    {
      Component   = "network-security"
    }
  )
}
```

### 9.2 Tag Reference Table

| Tag Key | Tag Value | Applied To | Purpose |
|---------|-----------|------------|---------|
| `Name` | `<project>-<resource>-<count>` | All | Resource identification |
| `Project` | `ec2-alb-nginx` | All | Project grouping |
| `Environment` | `development` | All | Environment separation |
| `ManagedBy` | `terraform` | All | IaC tool identification |
| `Owner` | `devops-team` | All | Ownership tracking |
| `CostCenter` | `<value>` | All | Cost allocation |
| `Component` | `web-server`, `load-balancer`, etc. | Specific | Component identification |
| `Application` | `nginx` | EC2 | Application identification |
| `Public` | `true`/`false` | Network resources | Internet accessibility |

---

## 10. Error Handling and Edge Cases

### 10.1 Common Error Scenarios

| Error Scenario | Detection | Mitigation |
|----------------|-----------|------------|
| Default VPC not found | Data source fails during plan | Check VPC existence before Terraform; document VPC creation steps |
| Insufficient availability zones | Count check fails | Validation check; error message with actual count |
| AMI not found | Data source returns empty | Use multiple AMI name patterns; fallback to specific AMI ID |
| Certificate import fails | ACM resource creation error | Validate PEM format; check region support |
| Instance launch fails | AWS API error | Check service quotas; verify instance type availability |
| Health checks fail | Targets remain unhealthy | Validate security groups; check Nginx installation; review user data logs |
| Both instances unhealthy | All targets unhealthy | ALB returns 503; monitoring alert required |
| AZ becomes unavailable | Instance status checks fail | ALB routes to healthy AZ; document manual intervention |
| TLS handshake fails | Browser connection error | Verify certificate in ACM; check listener configuration |
| Port 80 blocked | Security group misconfiguration | Validate ingress rules; test connectivity |

### 10.2 Terraform Error Handling

```hcl
# Precondition checks (Terraform 1.2+)
resource "aws_instance" "web" {
  count = var.instance_count
  
  lifecycle {
    precondition {
      condition     = data.aws_vpc.default.id != ""
      error_message = "Default VPC must exist in ${var.region}"
    }
    
    precondition {
      condition     = can(data.aws_ami.amazon_linux_2.id)
      error_message = "Amazon Linux 2 AMI must be available"
    }
  }
}

# Postcondition checks
resource "aws_lb" "main" {
  lifecycle {
    postcondition {
      condition     = self.state == "active"
      error_message = "Load balancer failed to reach active state"
    }
  }
}
```

---

## 11. Performance and Scaling Considerations

### 11.1 Current Design Limits

| Metric | Limit | Reasoning |
|--------|-------|-----------|
| Max concurrent connections | ~500 (t3.micro) | Instance type constraint |
| Max requests/second | ~50 | Nginx + t3.micro capacity |
| Max bandwidth | ~5 Gbps | ALB baseline limit |
| Instance count | 2 (fixed) | Design requirement |
| Availability zones | 2 | Based on instance count |
| Recovery time (single instance) | ~60-90 seconds | Health check + deregistration delay |

### 11.2 Future Scaling Considerations

When scaling beyond this design:

- **Horizontal Scaling**: Implement Auto Scaling Group (ASG) with dynamic instance count
- **Instance Type**: Upgrade to t3.small or larger for higher capacity
- **Multi-AZ**: Expand to 3+ availability zones for better fault tolerance
- **Caching**: Add ElastiCache or CloudFront for static content
- **Database**: Add RDS for stateful data persistence
- **Monitoring**: CloudWatch dashboards for performance metrics
- **Auto-healing**: ASG health checks for automatic instance replacement

---

## 12. Security Model

### 12.1 Network Security Layers

```
Internet (0.0.0.0/0)
    │
    │ HTTPS:443
    ▼
┌─────────────────────────────────────┐
│  Layer 1: ALB Security Group        │
│  - Ingress: 443/tcp from anywhere   │
│  - Egress: 80/tcp to EC2 SG         │
└─────────────────┬───────────────────┘
                  │
                  │ HTTP:80
                  ▼
┌─────────────────────────────────────┐
│  Layer 2: EC2 Security Group        │
│  - Ingress: 80/tcp from ALB SG only │
│  - Egress: All (for updates)        │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  Layer 3: EC2 Instance              │
│  - Nginx listening on 127.0.0.1:80  │
│  - IMDSv2 required                  │
│  - No SSH access configured         │
└─────────────────────────────────────┘
```

### 12.2 Security Requirements

| Requirement | Implementation | Validation |
|-------------|----------------|------------|
| TLS encryption in transit | ACM certificate + HTTPS listener | OpenSSL s_client test |
| Private instance access | EC2 SG allows only ALB SG | Attempt direct HTTP connection (should fail) |
| IMDSv2 enforcement | `http_tokens = "required"` | Query instance metadata with IMDSv1 (should fail) |
| Encrypted storage | `encrypted = true` on root volume | Check EBS volume encryption status |
| Least privilege | Security group rules specific to needs | AWS Config rules |
| Certificate management | Self-signed with known expiration | Monitor ACM expiration date |

---

## 13. Monitoring and Observability Data Points

### 13.1 CloudWatch Metrics (Automatic)

**ALB Metrics** (Namespace: `AWS/ApplicationELB`)
- `ActiveConnectionCount`: Current connections
- `TargetResponseTime`: Backend response latency
- `HTTPCode_Target_2XX_Count`: Successful responses
- `HTTPCode_Target_5XX_Count`: Server errors
- `HealthyHostCount`: Number of healthy targets
- `UnHealthyHostCount`: Number of unhealthy targets
- `RequestCount`: Total requests

**EC2 Metrics** (Namespace: `AWS/EC2`)
- `CPUUtilization`: CPU usage percentage
- `NetworkIn`: Incoming network traffic
- `NetworkOut`: Outgoing network traffic
- `StatusCheckFailed`: Instance health checks

**Target Group Metrics**
- `TargetResponseTime`: Average response time per target
- `HealthyStateSampleCount`: Health check results

### 13.2 Recommended Alarms

```hcl
# Example CloudWatch alarms (out of scope but documented for reference)

# Unhealthy target alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.project_name}-unhealthy-targets"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 2  # Alert if < 2 healthy
  alarm_description   = "Alert when healthy target count drops below 2"
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.main.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
```

---

## 14. Cost Model

### 14.1 Estimated Monthly Costs (ap-southeast-1)

| Resource | Unit Cost | Quantity | Hours/Month | Monthly Cost (USD) |
|----------|-----------|----------|-------------|-------------------|
| EC2 t3.micro | $0.0116/hour | 2 | 730 | $16.94 |
| EBS gp3 8GB | $0.092/GB-month | 16 GB | N/A | $1.47 |
| Application LB | $0.0252/hour | 1 | 730 | $18.40 |
| LCU (Load Balancer Capacity Units) | $0.008/LCU-hour | ~5 | 730 | $29.20 |
| Data Transfer Out (est 10GB) | $0.12/GB | 10 GB | N/A | $1.20 |
| ACM Certificate | Free | 1 | N/A | $0.00 |
| **Total Estimated Cost** | | | | **~$67.21/month** |

*Note: Actual costs may vary based on data transfer, request rates, and LCU consumption*

### 14.2 Cost Optimization Notes

- **Development Environment**: Cost target is ~$50/month (currently ~$67)
- **Primary Cost Drivers**: ALB ($47.60) > EC2 ($16.94) > EBS ($1.47)
- **Optimization Options**:
  - Use Network Load Balancer (cheaper) if Layer 7 features not needed
  - Reduce instance count to 1 for non-HA development
  - Use stop/start schedule during off-hours
  - Delete ALB when not in active use (keep EC2 for testing)
- **Production Scaling**: Reserve instances or savings plans for 30-40% savings

---

## 15. Compliance and Best Practices Alignment

### 15.1 AWS Well-Architected Framework Alignment

| Pillar | Implementation | Status |
|--------|----------------|--------|
| **Operational Excellence** | Infrastructure as Code (Terraform) | ✅ Implemented |
| **Security** | Security groups, TLS encryption, IMDSv2 | ✅ Implemented |
| **Reliability** | Multi-AZ deployment, health checks | ✅ Implemented |
| **Performance Efficiency** | Right-sized instances (t3.micro for dev) | ✅ Implemented |
| **Cost Optimization** | Burstable instances, minimal redundancy | ✅ Implemented |
| **Sustainability** | Right-sizing, minimal resources | ✅ Implemented |

### 15.2 Terraform Best Practices

- ✅ Use data sources for dynamic lookups
- ✅ Parameterize with variables
- ✅ Output important values
- ✅ Use lifecycle rules for critical resources
- ✅ Tag all resources consistently
- ✅ Validate inputs with validation blocks
- ✅ Use meaningful resource names
- ✅ Document complex logic with comments

---

## 16. References and Dependencies

### 16.1 Terraform Provider Requirements

```hcl
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  
  cloud {
    organization = "ravi-panchal-org"
    
    workspaces {
      name = "sandbox_workspace"
    }
  }
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = local.common_tags
  }
}
```

### 16.2 External Documentation References

- [AWS Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS Certificate Manager User Guide](https://docs.aws.amazon.com/acm/latest/userguide/)
- [Amazon EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform TLS Provider Documentation](https://registry.terraform.io/providers/hashicorp/tls/latest/docs)
- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)

### 16.3 Related Specifications

- Feature Specification: `/workspace/specs/001-ec2-alb-nginx/spec.md`
- Implementation Plan: `/workspace/specs/001-ec2-alb-nginx/plan.md`
- Project Constitution: `/workspace/.specify/memory/constitution.md`

---

## 17. Glossary

| Term | Definition |
|------|------------|
| **ACM** | AWS Certificate Manager - service for managing SSL/TLS certificates |
| **ALB** | Application Load Balancer - Layer 7 load balancer in AWS |
| **AZ** | Availability Zone - isolated location within an AWS region |
| **CIDR** | Classless Inter-Domain Routing - IP address notation |
| **EBS** | Elastic Block Store - block storage for EC2 instances |
| **HCL** | HashiCorp Configuration Language - Terraform's syntax |
| **IMDSv2** | Instance Metadata Service Version 2 - secure metadata access |
| **LCU** | Load Balancer Capacity Unit - ALB pricing metric |
| **Security Group** | Virtual firewall controlling inbound/outbound traffic |
| **Self-Signed Certificate** | TLS certificate signed by the creator, not a CA |
| **Target Group** | Logical group of targets for load balancer routing |
| **TLS** | Transport Layer Security - cryptographic protocol for secure communication |
| **User Data** | Script executed on EC2 instance first boot |
| **VPC** | Virtual Private Cloud - isolated network in AWS |

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-10 | Copilot Agent | Initial creation |

**Approval Status**: Draft - Pending Review

**Next Steps**:
1. Review data model with architecture team
2. Validate resource relationships
3. Confirm variable defaults and constraints
4. Proceed to contracts generation (API specifications)
5. Generate quickstart.md for implementation guidance
