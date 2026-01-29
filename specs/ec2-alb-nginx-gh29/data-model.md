# Data Model: EC2 Instance with ALB and Nginx Infrastructure

**Feature Branch**: `001-ec2-alb-nginx`  
**Created**: 2025-01-17  
**Status**: Draft

## Overview

This data model defines the Terraform infrastructure components, their relationships, and configuration parameters required to provision a highly available web infrastructure with EC2 instances, Application Load Balancer, and Nginx web server across 2 availability zones in ap-southeast-1.

## Architecture Components

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet Gateway                        │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ HTTPS (443)
                             ▼
┌─────────────────────────────────────────────────────────────┐
│            Application Load Balancer (ALB)                   │
│  - HTTPS Listener (port 443)                                 │
│  - SSL/TLS Certificate (ACM)                                 │
│  - Security Group: ALB-SG                                    │
└─────────────┬──────────────────────────┬────────────────────┘
              │                          │
              │ Target Group             │
              │ Health Checks (HTTP:80)  │
              │                          │
    ┌─────────▼─────────┐      ┌────────▼──────────┐
    │   Availability     │      │   Availability    │
    │   Zone 1           │      │   Zone 2          │
    │                    │      │                   │
    │  ┌──────────────┐  │      │  ┌──────────────┐ │
    │  │ EC2 Instance │  │      │  │ EC2 Instance │ │
    │  │ - Nginx      │  │      │  │ - Nginx      │ │
    │  │ - IAM Role   │  │      │  │ - IAM Role   │ │
    │  │ - SG: EC2-SG │  │      │  │ - SG: EC2-SG │ │
    │  └──────────────┘  │      │  └──────────────┘ │
    └────────────────────┘      └───────────────────┘
             │                           │
             │    Default VPC             │
             └───────────────────────────┘
```

---

## Terraform Variable Definitions

### Input Variables

#### Global Configuration

```hcl
variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "ap-southeast-1"
  
  validation {
    condition     = var.aws_region == "ap-southeast-1"
    error_message = "Region must be ap-southeast-1 per requirements"
  }
}

variable "environment" {
  description = "Environment name for resource tagging and identification"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "dev"], var.environment)
    error_message = "This configuration is for development environments only"
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "ec2-alb-nginx"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "tags" {
  description = "Common tags to apply to all resources for cost tracking and identification"
  type        = map(string)
  default = {
    Project     = "ec2-alb-nginx"
    Environment = "development"
    ManagedBy   = "terraform"
    CostCenter  = "development"
  }
}
```

#### Networking Configuration

```hcl
variable "use_default_vpc" {
  description = "Whether to use the default VPC (must be true per requirements)"
  type        = bool
  default     = true
  
  validation {
    condition     = var.use_default_vpc == true
    error_message = "Must use default VPC per requirements FR-002"
  }
}

variable "availability_zones" {
  description = "List of availability zones to deploy resources (must be exactly 2 AZs)"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
  
  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones required per FR-001"
  }
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing for ALB"
  type        = bool
  default     = true
}
```

#### EC2 Instance Configuration

```hcl
variable "instance_type" {
  description = "EC2 instance type optimized for cost in development environment"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = can(regex("^t[2-3]\\.(nano|micro|small)$", var.instance_type))
    error_message = "Instance type must be cost-optimized (t2/t3 nano/micro/small) per NFR-007"
  }
}

variable "instance_count_per_az" {
  description = "Number of EC2 instances to launch per availability zone"
  type        = number
  default     = 1
  
  validation {
    condition     = var.instance_count_per_az >= 1 && var.instance_count_per_az <= 2
    error_message = "Must deploy 1-2 instances per AZ for cost optimization"
  }
}

variable "root_volume_size" {
  description = "Root volume size in GB for EC2 instances"
  type        = number
  default     = 8
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 20
    error_message = "Root volume must be between 8-20 GB for cost optimization"
  }
}

variable "root_volume_type" {
  description = "Root volume type for EC2 instances"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp3", "gp2"], var.root_volume_type)
    error_message = "Use gp3 or gp2 for cost-optimized storage"
  }
}

variable "ami_filter" {
  description = "AMI filter to select Amazon Linux 2 or Amazon Linux 2023 AMI"
  type        = map(string)
  default = {
    name  = "amzn2-ami-hvm-*-x86_64-gp2"
    owner = "amazon"
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (incurs additional cost)"
  type        = bool
  default     = false
}
```

#### Application Load Balancer Configuration

```hcl
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
  default     = "ec2-alb-nginx-alb"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.alb_name)) && length(var.alb_name) <= 32
    error_message = "ALB name must be alphanumeric with hyphens and max 32 characters"
  }
}

variable "alb_internal" {
  description = "Whether ALB is internal (must be false for internet-facing)"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB (should be false for dev)"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Idle timeout in seconds for ALB connections"
  type        = number
  default     = 60
  
  validation {
    condition     = var.idle_timeout >= 30 && var.idle_timeout <= 300
    error_message = "Idle timeout must be between 30-300 seconds"
  }
}

variable "enable_http2" {
  description = "Enable HTTP/2 support on ALB"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Enable AWS WAF integration (out of scope, should be false)"
  type        = bool
  default     = false
}
```

#### SSL/TLS Certificate Configuration

```hcl
variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS listener (leave empty to create self-signed)"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
  
  validation {
    condition     = can(regex("^ELBSecurityPolicy-", var.ssl_policy))
    error_message = "Must use valid ELB SSL policy"
  }
}

variable "create_self_signed_cert" {
  description = "Create self-signed certificate for development if ACM cert not provided"
  type        = bool
  default     = true
}
```

#### Target Group Configuration

```hcl
variable "target_group_name" {
  description = "Name of the target group"
  type        = string
  default     = "ec2-nginx-tg"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.target_group_name)) && length(var.target_group_name) <= 32
    error_message = "Target group name must be alphanumeric with hyphens and max 32 characters"
  }
}

variable "target_group_port" {
  description = "Port for target group (Nginx default port)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.target_group_port == 80
    error_message = "Nginx listens on port 80, ALB terminates SSL"
  }
}

variable "target_group_protocol" {
  description = "Protocol for target group"
  type        = string
  default     = "HTTP"
  
  validation {
    condition     = var.target_group_protocol == "HTTP"
    error_message = "Use HTTP for target group, HTTPS on ALB listener"
  }
}

variable "deregistration_delay" {
  description = "Time in seconds for ALB to wait before deregistering a target"
  type        = number
  default     = 30
  
  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 300
    error_message = "Deregistration delay must be between 0-300 seconds"
  }
}

variable "health_check" {
  description = "Health check configuration for target group"
  type = object({
    enabled             = bool
    interval            = number
    path                = string
    port                = string
    protocol            = string
    timeout             = number
    healthy_threshold   = number
    unhealthy_threshold = number
    matcher             = string
  })
  
  default = {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
  
  validation {
    condition     = var.health_check.interval >= var.health_check.timeout
    error_message = "Health check interval must be greater than or equal to timeout"
  }
  
  validation {
    condition     = var.health_check.healthy_threshold >= 2 && var.health_check.unhealthy_threshold >= 2
    error_message = "Threshold values must be at least 2 per SC-006"
  }
}

variable "stickiness" {
  description = "Session stickiness configuration"
  type = object({
    enabled         = bool
    type            = string
    cookie_duration = number
  })
  
  default = {
    enabled         = false
    type            = "lb_cookie"
    cookie_duration = 86400
  }
}
```

#### Security Group Configuration

```hcl
variable "alb_security_group_rules" {
  description = "Security group rules for Application Load Balancer"
  type = object({
    ingress_https_cidr = list(string)
    egress_to_targets  = bool
  })
  
  default = {
    ingress_https_cidr = ["0.0.0.0/0"]
    egress_to_targets  = true
  }
}

variable "ec2_security_group_rules" {
  description = "Security group rules for EC2 instances"
  type = object({
    ingress_from_alb_only = bool
    allow_ssh             = bool
    ssh_cidr_blocks       = list(string)
  })
  
  default = {
    ingress_from_alb_only = true
    allow_ssh             = false
    ssh_cidr_blocks       = []
  }
  
  validation {
    condition     = var.ec2_security_group_rules.ingress_from_alb_only == true
    error_message = "Must restrict EC2 ingress to ALB only per FR-010"
  }
}
```

#### IAM Configuration

```hcl
variable "create_iam_instance_profile" {
  description = "Create IAM instance profile for EC2 instances"
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "Name of IAM role for EC2 instances"
  type        = string
  default     = "ec2-nginx-instance-role"
}

variable "iam_policy_arns" {
  description = "List of IAM policy ARNs to attach to instance role (least privilege)"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

variable "enable_ssm_access" {
  description = "Enable AWS Systems Manager Session Manager for instance access"
  type        = bool
  default     = true
}
```

#### Nginx Configuration

```hcl
variable "nginx_config" {
  description = "Nginx configuration parameters"
  type = object({
    install_nginx     = bool
    serve_static_content = bool
    static_content_path  = string
    nginx_port           = number
  })
  
  default = {
    install_nginx        = true
    serve_static_content = true
    static_content_path  = "/usr/share/nginx/html"
    nginx_port           = 80
  }
  
  validation {
    condition     = var.nginx_config.install_nginx == true
    error_message = "Nginx installation is required per FR-006"
  }
}

variable "user_data_template" {
  description = "User data script template for EC2 instance initialization"
  type        = string
  default     = ""
}

variable "static_content_html" {
  description = "Custom HTML content for Nginx to serve"
  type        = string
  default     = <<-EOF
    <!DOCTYPE html>
    <html>
    <head>
      <title>EC2 ALB Nginx Infrastructure</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 50px; background-color: #f0f0f0; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #FF9900; }
        .info { margin: 20px 0; padding: 15px; background: #f9f9f9; border-left: 4px solid #FF9900; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>EC2 ALB Nginx Infrastructure - Development</h1>
        <div class="info">
          <p><strong>Instance ID:</strong> ${instance_id}</p>
          <p><strong>Availability Zone:</strong> ${availability_zone}</p>
          <p><strong>Region:</strong> ap-southeast-1</p>
        </div>
        <p>This infrastructure is deployed via HCP Terraform and serves content through an Application Load Balancer with HTTPS encryption.</p>
        <p><strong>Status:</strong> <span style="color: green;">✓ Online</span></p>
      </div>
    </body>
    </html>
  EOF
}
```

---

## Resource Dependencies

### Dependency Graph

```
Data Sources (First)
├── aws_vpc (default VPC)
├── aws_subnets (filter by VPC and AZs)
├── aws_ami (Amazon Linux 2/2023)
└── aws_caller_identity (account ID)
    │
    ▼
IAM Resources
├── aws_iam_role (EC2 instance role)
├── aws_iam_role_policy_attachment (managed policies)
└── aws_iam_instance_profile (attach to EC2)
    │
    ▼
Security Groups
├── aws_security_group (ALB security group)
│   ├── aws_security_group_rule (ingress HTTPS 443)
│   └── aws_security_group_rule (egress to EC2)
│
└── aws_security_group (EC2 security group)
    ├── aws_security_group_rule (ingress from ALB)
    ├── aws_security_group_rule (ingress SSH - optional)
    └── aws_security_group_rule (egress all)
    │
    ▼
Certificate (Optional)
└── aws_acm_certificate (if creating self-signed or importing)
    │
    ▼
Application Load Balancer
├── aws_lb (Application Load Balancer)
│   ├── depends_on: aws_security_group (ALB SG)
│   └── subnets: data.aws_subnets (public subnets in 2 AZs)
│
├── aws_lb_target_group
│   └── depends_on: aws_vpc (default VPC)
│
└── aws_lb_listener (HTTPS:443)
    ├── depends_on: aws_lb, aws_lb_target_group
    └── certificate_arn: aws_acm_certificate or var.certificate_arn
    │
    ▼
EC2 Instances
├── aws_instance (EC2 in AZ1)
│   ├── depends_on: aws_security_group (EC2 SG), aws_iam_instance_profile
│   ├── iam_instance_profile: aws_iam_instance_profile
│   ├── security_groups: [aws_security_group.ec2_sg.id]
│   └── user_data: Nginx installation + static content
│
└── aws_instance (EC2 in AZ2)
    ├── depends_on: aws_security_group (EC2 SG), aws_iam_instance_profile
    ├── iam_instance_profile: aws_iam_instance_profile
    ├── security_groups: [aws_security_group.ec2_sg.id]
    └── user_data: Nginx installation + static content
    │
    ▼
Target Group Attachments
├── aws_lb_target_group_attachment (EC2 AZ1 to TG)
│   ├── depends_on: aws_instance (AZ1), aws_lb_target_group
│   └── target_id: aws_instance.ec2_az1.id
│
└── aws_lb_target_group_attachment (EC2 AZ2 to TG)
    ├── depends_on: aws_instance (AZ2), aws_lb_target_group
    └── target_id: aws_instance.ec2_az2.id
```

### Critical Dependencies

1. **Data Sources → All Resources**: Must query default VPC, subnets, and AMI before any resource creation
2. **IAM Role → EC2 Instances**: IAM instance profile must exist before EC2 launch
3. **Security Groups → ALB + EC2**: Security groups must be created before attaching to resources
4. **ALB → Listener**: ALB must exist before creating listeners
5. **Target Group → Attachments**: Target group must exist before registering instances
6. **EC2 Instances → Target Attachments**: Instances must be running before target group registration
7. **Certificate → ALB Listener**: SSL certificate must be available before creating HTTPS listener

---

## Module Relationships

### Module Hierarchy

```
root module (main.tf)
│
├── module "vpc_data" (data sources only)
│   ├── Queries default VPC
│   ├── Queries subnets in specified AZs
│   └── Outputs: vpc_id, subnet_ids
│
├── module "iam" (IAM resources)
│   ├── Creates EC2 instance role
│   ├── Attaches managed policies
│   ├── Creates instance profile
│   └── Outputs: instance_profile_name, role_arn
│
├── module "security_groups"
│   ├── Creates ALB security group
│   ├── Creates EC2 security group
│   ├── Defines ingress/egress rules
│   └── Outputs: alb_sg_id, ec2_sg_id
│
├── module "alb"
│   ├── Input: security_group_ids, subnet_ids, vpc_id
│   ├── Creates Application Load Balancer
│   ├── Creates target group with health checks
│   ├── Creates HTTPS listener
│   ├── Manages SSL certificate
│   └── Outputs: alb_dns_name, alb_arn, target_group_arn
│
├── module "ec2_instances"
│   ├── Input: subnet_ids, security_group_id, iam_profile
│   ├── Creates EC2 instances (1 per AZ)
│   ├── Installs Nginx via user_data
│   ├── Deploys static content
│   └── Outputs: instance_ids, instance_private_ips
│
└── module "target_group_attachments"
    ├── Input: target_group_arn, instance_ids
    ├── Registers EC2 instances to target group
    └── Outputs: attachment_ids
```

### Module Inputs/Outputs

#### Module: vpc_data (Data Source Module)

**Inputs:**
- `aws_region` (string): AWS region
- `use_default_vpc` (bool): Flag to use default VPC
- `availability_zones` (list(string)): Target AZs

**Outputs:**
- `vpc_id` (string): Default VPC ID
- `vpc_cidr_block` (string): VPC CIDR block
- `subnet_ids` (list(string)): Public subnet IDs in specified AZs
- `subnet_cidr_blocks` (list(string)): CIDR blocks of subnets
- `internet_gateway_id` (string): Internet gateway ID

**Module Source (Priority Order):**
1. Private: `ravi-panchal-org/vpc-data/aws` (preferred)
2. Public: `terraform-aws-modules/vpc/aws` (with approval)
3. Custom: Local data source queries

---

#### Module: iam

**Inputs:**
- `project_name` (string): Project name for resource naming
- `environment` (string): Environment name
- `create_instance_profile` (bool): Whether to create profile
- `role_name` (string): IAM role name
- `policy_arns` (list(string)): Managed policy ARNs to attach
- `enable_ssm_access` (bool): Enable SSM Session Manager
- `tags` (map(string)): Resource tags

**Outputs:**
- `instance_profile_name` (string): Name of IAM instance profile
- `instance_profile_arn` (string): ARN of instance profile
- `role_name` (string): Name of IAM role
- `role_arn` (string): ARN of IAM role
- `role_id` (string): ID of IAM role

**Module Source (Priority Order):**
1. Private: `ravi-panchal-org/iam-instance-profile/aws` (preferred)
2. Public: `terraform-aws-modules/iam/aws//modules/iam-assumable-role` (with approval)
3. Custom: Local IAM resource definitions

---

#### Module: security_groups

**Inputs:**
- `vpc_id` (string): VPC ID for security groups
- `project_name` (string): Project name for resource naming
- `environment` (string): Environment name
- `alb_ingress_cidr` (list(string)): CIDR blocks for ALB HTTPS ingress
- `ec2_allow_ssh` (bool): Whether to allow SSH to EC2
- `ec2_ssh_cidr` (list(string)): CIDR blocks for SSH access
- `tags` (map(string)): Resource tags

**Outputs:**
- `alb_security_group_id` (string): ALB security group ID
- `alb_security_group_arn` (string): ALB security group ARN
- `ec2_security_group_id` (string): EC2 security group ID
- `ec2_security_group_arn` (string): EC2 security group ARN

**Module Source (Priority Order):**
1. Private: `ravi-panchal-org/security-group/aws` (preferred)
2. Public: `terraform-aws-modules/security-group/aws` (with approval)
3. Custom: Local security group resource definitions

---

#### Module: alb

**Inputs:**
- `alb_name` (string): ALB name
- `internal` (bool): Whether ALB is internal
- `security_group_ids` (list(string)): Security group IDs for ALB
- `subnet_ids` (list(string)): Subnet IDs for ALB (2 AZs required)
- `vpc_id` (string): VPC ID for target group
- `target_group_name` (string): Target group name
- `target_group_port` (number): Target port (80 for Nginx)
- `target_group_protocol` (string): Target protocol (HTTP)
- `health_check` (object): Health check configuration
- `certificate_arn` (string): ACM certificate ARN
- `ssl_policy` (string): SSL policy name
- `enable_http2` (bool): Enable HTTP/2
- `enable_deletion_protection` (bool): Deletion protection
- `idle_timeout` (number): Idle timeout in seconds
- `deregistration_delay` (number): Deregistration delay
- `stickiness` (object): Session stickiness config
- `tags` (map(string)): Resource tags

**Outputs:**
- `alb_id` (string): ALB ID
- `alb_arn` (string): ALB ARN
- `alb_dns_name` (string): ALB DNS name (primary endpoint)
- `alb_zone_id` (string): ALB Route53 zone ID
- `target_group_id` (string): Target group ID
- `target_group_arn` (string): Target group ARN
- `listener_arn` (string): HTTPS listener ARN
- `https_endpoint` (string): Full HTTPS endpoint URL

**Module Source (Priority Order):**
1. Private: `ravi-panchal-org/alb/aws` (preferred)
2. Public: `terraform-aws-modules/alb/aws` (with approval)
3. Custom: Local ALB resource definitions

---

#### Module: ec2_instances

**Inputs:**
- `instance_count` (number): Total instances to create
- `availability_zones` (list(string)): AZs for instance placement
- `subnet_ids` (list(string)): Subnet IDs (mapped to AZs)
- `instance_type` (string): EC2 instance type
- `ami_id` (string): AMI ID for instances
- `iam_instance_profile` (string): IAM instance profile name
- `security_group_ids` (list(string)): Security group IDs
- `root_volume_size` (number): Root volume size in GB
- `root_volume_type` (string): Root volume type
- `enable_detailed_monitoring` (bool): CloudWatch detailed monitoring
- `user_data` (string): User data script for initialization
- `nginx_config` (object): Nginx configuration parameters
- `static_content_html` (string): Static HTML content
- `project_name` (string): Project name for resource naming
- `environment` (string): Environment name
- `tags` (map(string)): Resource tags

**Outputs:**
- `instance_ids` (list(string)): EC2 instance IDs
- `instance_arns` (list(string)): EC2 instance ARNs
- `instance_private_ips` (list(string)): Private IP addresses
- `instance_availability_zones` (list(string)): AZs where instances are deployed
- `instance_public_ips` (list(string)): Public IPs (if assigned)

**Module Source (Priority Order):**
1. Private: `ravi-panchal-org/ec2-instance/aws` (preferred)
2. Public: `terraform-aws-modules/ec2-instance/aws` (with approval)
3. Custom: Local EC2 resource definitions

---

#### Module: target_group_attachments

**Inputs:**
- `target_group_arn` (string): Target group ARN
- `instance_ids` (list(string)): EC2 instance IDs to register
- `target_port` (number): Port for targets (default: 80)

**Outputs:**
- `attachment_ids` (list(string)): Target group attachment IDs

**Module Source (Priority Order):**
1. Private: `ravi-panchal-org/alb-target-attachment/aws` (preferred)
2. Public: Individual `aws_lb_target_group_attachment` resources
3. Custom: Local attachment resources

---

## Input/Output Specifications

### Root Module Inputs

**Required Inputs** (must be provided):
```hcl
# None - all inputs have sensible defaults for development environment
```

**Optional Inputs** (can override defaults):
```hcl
# See "Terraform Variable Definitions" section above
# Key overrideable inputs:
# - aws_region (locked to ap-southeast-1)
# - instance_type (cost optimization)
# - certificate_arn (ACM certificate)
# - alb_security_group_rules (HTTPS CIDR restrictions)
# - tags (cost tracking and environment identification)
```

### Root Module Outputs

```hcl
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (primary access endpoint)"
  value       = module.alb.alb_dns_name
}

output "alb_https_endpoint" {
  description = "Full HTTPS endpoint URL for accessing the infrastructure"
  value       = "https://${module.alb.alb_dns_name}"
}

output "alb_zone_id" {
  description = "Route53 zone ID of the ALB for DNS alias records"
  value       = module.alb.alb_zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_group_arn
}

output "ec2_instance_ids" {
  description = "List of EC2 instance IDs across all availability zones"
  value       = module.ec2_instances.instance_ids
}

output "ec2_private_ips" {
  description = "Private IP addresses of EC2 instances"
  value       = module.ec2_instances.instance_private_ips
}

output "ec2_availability_zones" {
  description = "Availability zones where EC2 instances are deployed"
  value       = module.ec2_instances.instance_availability_zones
}

output "vpc_id" {
  description = "ID of the default VPC used for deployment"
  value       = module.vpc_data.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs used for EC2 instance deployment"
  value       = module.vpc_data.subnet_ids
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = module.security_groups.alb_security_group_id
}

output "ec2_security_group_id" {
  description = "Security group ID for EC2 instances"
  value       = module.security_groups.ec2_security_group_id
}

output "iam_instance_profile_name" {
  description = "Name of IAM instance profile attached to EC2 instances"
  value       = module.iam.instance_profile_name
}

output "iam_role_arn" {
  description = "ARN of IAM role for EC2 instances"
  value       = module.iam.role_arn
}

output "deployment_region" {
  description = "AWS region where infrastructure is deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name for this deployment"
  value       = var.environment
}

output "health_check_path" {
  description = "Health check path used by ALB"
  value       = var.health_check.path
}
```

---

## Configuration Parameters

### User Data Script Template

```bash
#!/bin/bash
# EC2 Instance Initialization Script
# Purpose: Install and configure Nginx with static content
# Requirements: FR-006, FR-007

set -e

# Update system packages
yum update -y

# Install Nginx
amazon-linux-extras install nginx1 -y || yum install nginx -y

# Create static content directory
mkdir -p /usr/share/nginx/html

# Fetch instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)

# Create custom HTML page with instance information
cat > /usr/share/nginx/html/index.html <<'EOF'
${static_content_html}
EOF

# Replace placeholders with actual values
sed -i "s/\${instance_id}/$INSTANCE_ID/g" /usr/share/nginx/html/index.html
sed -i "s/\${availability_zone}/$AVAILABILITY_ZONE/g" /usr/share/nginx/html/index.html

# Configure Nginx
cat > /etc/nginx/nginx.conf <<'NGINXCONF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;
    
    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
NGINXCONF

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx

# Verify Nginx is running
systemctl status nginx

# Log completion
echo "Nginx installation and configuration completed successfully" >> /var/log/user-data.log
```

### Resource Naming Convention

```hcl
# Naming pattern: {project_name}-{resource_type}-{environment}-{identifier}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  resource_names = {
    alb                = "${local.name_prefix}-alb"
    target_group       = "${local.name_prefix}-tg"
    alb_sg             = "${local.name_prefix}-alb-sg"
    ec2_sg             = "${local.name_prefix}-ec2-sg"
    iam_role           = "${local.name_prefix}-ec2-role"
    instance_profile   = "${local.name_prefix}-ec2-profile"
    ec2_az1            = "${local.name_prefix}-ec2-az1"
    ec2_az2            = "${local.name_prefix}-ec2-az2"
  }
  
  common_tags = merge(
    var.tags,
    {
      Name        = local.name_prefix
      Terraform   = "true"
      Region      = var.aws_region
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "HCP-Terraform"
      Workspace   = "sandbox_workspace"
      GitHubIssue = "29"
    }
  )
}
```

### State Management Configuration

```hcl
# backend.tf
terraform {
  required_version = ">= 1.5.0"
  
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "ravi-panchal-org"
    
    workspaces {
      name = "sandbox_workspace"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}
```

---

## Entity Relationships

### Primary Entities

#### 1. EC2 Instance
**Attributes:**
- `id` (string): Unique instance identifier
- `availability_zone` (string): AZ placement
- `instance_type` (string): Instance size
- `ami_id` (string): Amazon Machine Image ID
- `private_ip` (string): Private IP address
- `state` (string): Instance state (running, stopped, etc.)
- `iam_instance_profile` (string): Attached IAM profile
- `security_groups` (list): Associated security groups
- `tags` (map): Resource tags

**Relationships:**
- Belongs to: 1 Availability Zone
- Belongs to: 1 Subnet (via VPC)
- Has: 1 IAM Instance Profile
- Has: 1+ Security Groups
- Member of: 1 Target Group
- Runs: 1 Nginx Server

**State Transitions:**
1. Pending → Running (initial launch)
2. Running → Stopping → Stopped (shutdown)
3. Stopped → Pending → Running (restart)
4. Running → Terminating → Terminated (destroy)

**Validation Rules:**
- Must be in specified availability zones (FR-001)
- Must have IAM role attached (FR-011)
- Must have Nginx installed (FR-006)
- Must be cost-optimized instance type (FR-012)

---

#### 2. Application Load Balancer
**Attributes:**
- `id` (string): Unique ALB identifier
- `arn` (string): Amazon Resource Name
- `dns_name` (string): Public DNS endpoint
- `scheme` (string): internet-facing or internal
- `load_balancer_type` (string): application
- `security_groups` (list): Associated security groups
- `subnets` (list): Subnet IDs (2+ AZs required)
- `tags` (map): Resource tags

**Relationships:**
- Spans: 2 Availability Zones
- Has: 1 HTTPS Listener (port 443)
- Has: 1+ Security Groups
- Routes to: 1 Target Group
- Depends on: SSL Certificate

**State Transitions:**
1. Provisioning → Active (creation)
2. Active → Active (normal operation)
3. Active → Active_impaired (subnet unavailable)
4. Active → Deleted (destruction)

**Validation Rules:**
- Must be internet-facing (FR-003)
- Must have HTTPS listener (FR-004)
- Must span 2 AZs (FR-001)
- Must have valid SSL certificate (FR-004)

---

#### 3. Target Group
**Attributes:**
- `id` (string): Unique target group identifier
- `arn` (string): Amazon Resource Name
- `name` (string): Target group name
- `port` (number): Target port (80)
- `protocol` (string): HTTP
- `vpc_id` (string): VPC identifier
- `health_check` (object): Health check configuration
- `targets` (list): Registered EC2 instances

**Relationships:**
- Belongs to: 1 VPC
- Contains: 2+ EC2 Instances (targets)
- Used by: 1 ALB Listener
- Performs: Health Checks on targets

**Health Check Configuration:**
- Path: `/` (Nginx default page)
- Protocol: HTTP
- Port: 80
- Interval: 30 seconds
- Timeout: 5 seconds
- Healthy threshold: 2 consecutive successes
- Unhealthy threshold: 2 consecutive failures
- Expected status: 200 OK

**Validation Rules:**
- Must use HTTP protocol (FR-016)
- Must have health checks enabled (FR-008)
- Must detect failures within 30 seconds (SC-006)
- Must route only to healthy instances (FR-009)

---

#### 4. Security Group
**Attributes:**
- `id` (string): Unique security group identifier
- `name` (string): Security group name
- `description` (string): Purpose description
- `vpc_id` (string): VPC identifier
- `ingress_rules` (list): Inbound rules
- `egress_rules` (list): Outbound rules

**Types:**
1. **ALB Security Group**
   - Ingress: Port 443 (HTTPS) from 0.0.0.0/0
   - Egress: Port 80 to EC2 Security Group

2. **EC2 Security Group**
   - Ingress: Port 80 from ALB Security Group
   - Ingress: Port 22 (SSH) from specific CIDR (optional)
   - Egress: All traffic (for package downloads, SSM)

**Relationships:**
- Belongs to: 1 VPC
- Attached to: ALB or EC2 instances
- References: Other security groups (for source/destination)

**Validation Rules:**
- Must follow least privilege (FR-010)
- ALB must allow HTTPS from internet (FR-004)
- EC2 must only accept traffic from ALB (FR-010)
- No unrestricted SSH access

---

#### 5. IAM Role
**Attributes:**
- `id` (string): Role ID
- `arn` (string): Role ARN
- `name` (string): Role name
- `assume_role_policy` (json): Trust policy
- `attached_policies` (list): Managed policy ARNs
- `inline_policies` (list): Inline policies

**Trust Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
```

**Managed Policies:**
- `AmazonSSMManagedInstanceCore`: Systems Manager access
- `CloudWatchAgentServerPolicy`: CloudWatch metrics/logs

**Relationships:**
- Attached to: EC2 Instances (via Instance Profile)
- Has: 0+ Managed Policies
- Has: 0+ Inline Policies
- Assumes: EC2 Service Principal

**Validation Rules:**
- Must follow least privilege (FR-011)
- Must allow EC2 service to assume role
- Must include minimum required policies for operations

---

#### 6. SSL Certificate
**Attributes:**
- `arn` (string): Certificate ARN
- `domain_name` (string): Primary domain
- `subject_alternative_names` (list): Additional domains
- `status` (string): ISSUED, PENDING_VALIDATION, etc.
- `type` (string): AMAZON_ISSUED or IMPORTED

**Relationships:**
- Used by: 1 ALB HTTPS Listener
- Validated via: DNS or Email (for ACM certs)
- Stored in: AWS Certificate Manager

**Validation Rules:**
- Must be valid (not expired) (FR-004)
- Must match ALB domain or be wildcard
- For dev: Self-signed acceptable

---

## Data Flow

### Request Flow (HTTPS → Nginx)

```
1. User Request
   ├─ HTTPS://alb-dns-name.region.elb.amazonaws.com
   └─ Port: 443

2. Internet Gateway
   ├─ Routes traffic to VPC
   └─ Public subnet

3. Application Load Balancer
   ├─ Security Group Check (ALB-SG)
   │  └─ Allow: HTTPS (443) from 0.0.0.0/0
   ├─ SSL/TLS Termination
   │  ├─ Decrypt HTTPS traffic
   │  └─ Validate certificate
   └─ Forward to Target Group (HTTP:80)

4. Target Group
   ├─ Select healthy target (Round Robin)
   ├─ Check health status
   │  └─ Last health check: Success (200 OK)
   └─ Forward to EC2 Instance

5. EC2 Instance
   ├─ Security Group Check (EC2-SG)
   │  └─ Allow: HTTP (80) from ALB-SG
   ├─ Nginx receives request
   │  ├─ Port: 80
   │  └─ Protocol: HTTP
   └─ Serve static content

6. Response Path
   ├─ Nginx → Target Group → ALB
   ├─ ALB encrypts response (HTTPS)
   └─ ALB → Internet Gateway → User

7. Metrics Collected
   ├─ ALB: Connection count, latency, status codes
   ├─ Target Group: Healthy/unhealthy count
   └─ EC2: Instance health check results
```

### Health Check Flow

```
1. ALB Initiates Health Check (every 30 seconds)
   └─ Target: EC2 Instance in Target Group

2. Health Check Request
   ├─ Protocol: HTTP
   ├─ Port: 80
   ├─ Path: /
   └─ Timeout: 5 seconds

3. EC2 Instance Response
   ├─ Nginx processes request
   └─ Returns: HTTP 200 OK + HTML content

4. ALB Evaluates Response
   ├─ Status Code: 200 (expected: 200)
   ├─ Response Time: <5 seconds
   └─ Result: Healthy

5. Health Status Update
   ├─ Healthy threshold: 2 consecutive successes
   ├─ Unhealthy threshold: 2 consecutive failures
   └─ Current Status: Healthy

6. Routing Decision
   ├─ If Healthy: Include in target rotation
   └─ If Unhealthy: Remove from target rotation (FR-009)

7. Failure Scenario (Instance Unhealthy)
   ├─ Health check timeout or 5xx error
   ├─ Mark as Unhealthy after 2 failures
   ├─ Stop sending traffic to instance
   ├─ Route all traffic to healthy instances in other AZ
   └─ Continue health checks (30s interval) until recovery
```

---

## Validation & Testing

### Infrastructure Validation

```hcl
# Validation checks in Terraform
validation {
  # FR-001: Exactly 2 AZs
  condition     = length(var.availability_zones) == 2
  error_message = "Exactly 2 availability zones required"
}

validation {
  # FR-002: Default VPC only
  condition     = var.use_default_vpc == true
  error_message = "Must use default VPC"
}

validation {
  # FR-004: HTTPS only
  condition     = var.alb_listeners["https"] != null
  error_message = "ALB must have HTTPS listener"
}

validation {
  # FR-012: Cost-optimized instances
  condition     = can(regex("^t[2-3]\\.(nano|micro|small)$", var.instance_type))
  error_message = "Must use cost-optimized instance types"
}

validation {
  # NFR-004: Minimum capacity
  condition     = var.instance_count_per_az >= 1
  error_message = "At least 1 instance per AZ required"
}
```

### Resource Verification

```bash
# Post-deployment verification script
#!/bin/bash

# 1. Verify ALB is active
ALB_STATE=$(aws elbv2 describe-load-balancers \
  --names ec2-alb-nginx-alb \
  --query 'LoadBalancers[0].State.Code' \
  --output text)
echo "ALB State: $ALB_STATE" # Expected: active

# 2. Verify target health
TARGET_HEALTH=$(aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN \
  --query 'TargetHealthDescriptions[*].TargetHealth.State' \
  --output text)
echo "Target Health: $TARGET_HEALTH" # Expected: healthy healthy

# 3. Verify HTTPS connectivity
ALB_DNS=$(terraform output -raw alb_dns_name)
curl -k https://$ALB_DNS
# Expected: HTML content with instance information

# 4. Verify HTTP rejection (should fail or redirect)
curl -k http://$ALB_DNS
# Expected: Connection refused or redirect to HTTPS

# 5. Verify instances in different AZs
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID_1 $INSTANCE_ID_2 \
  --query 'Reservations[*].Instances[*].[InstanceId,Placement.AvailabilityZone]' \
  --output table
# Expected: 2 instances in different AZs
```

---

## Cost Estimation

### Monthly Cost Breakdown (Development Environment)

| Resource | Configuration | Estimated Monthly Cost (USD) |
|----------|--------------|------------------------------|
| EC2 Instances (2x t3.micro) | 2 instances × 730 hours × $0.0104/hr | $15.18 |
| EBS Volumes (2x 8GB gp3) | 2 volumes × 8 GB × $0.08/GB-month | $1.28 |
| Application Load Balancer | 1 ALB × 730 hours × $0.0225/hr | $16.43 |
| ALB LCU Hours | ~10 LCUs × 730 hours × $0.008/hr | $58.40 |
| Data Transfer Out (estimated 10GB) | 10 GB × $0.09/GB (after 100GB free tier) | $0.00 |
| **Total Estimated Cost** | | **~$91.29/month** |

**Cost Optimization Notes:**
- Using t3.micro instances (burstable, cost-effective)
- Minimal storage (8GB gp3 volumes)
- Single ALB (no redundancy needed for dev)
- Low traffic assumption (<100 concurrent connections)
- Can reduce costs further with:
  - Auto-shutdown schedules (off-hours)
  - Reserved instances (1-year commitment)
  - Spot instances (up to 90% savings, less reliable)

---

## Security Considerations

### Security Baseline

1. **Network Security (FR-010)**
   - HTTPS-only access to ALB (FR-005)
   - Security group least-privilege rules
   - No direct internet access to EC2 instances
   - ALB terminates SSL (encrypted in transit)

2. **IAM Security (FR-011)**
   - Instance role with minimum permissions
   - No credentials stored on instances
   - SSM Session Manager for secure access
   - CloudWatch Logs for audit trail

3. **Data Security**
   - SSL/TLS 1.2+ for HTTPS
   - EBS volumes encrypted at rest (optional for dev)
   - No sensitive data in static content

4. **Operational Security**
   - HCP Terraform state encryption
   - Workspace locking prevents concurrent changes
   - Version control for infrastructure code
   - Audit logs in CloudTrail

### Compliance Checks

```hcl
# Sentinel policy example (HCP Terraform)
policy "require-https-only" {
  enforcement_level = "hard-mandatory"
}

policy "restrict-instance-types" {
  enforcement_level = "soft-mandatory"
  allowed_types = ["t2.micro", "t2.small", "t3.micro", "t3.small"]
}

policy "require-encryption" {
  enforcement_level = "advisory"
  check_ebs_encryption = true
}
```

---

## Rollback & Disaster Recovery

### Rollback Procedures

1. **Infrastructure Rollback**
   ```bash
   # Revert to previous Terraform state
   terraform state pull > current-state.backup
   terraform state push previous-state.tfstate
   terraform apply
   ```

2. **Configuration Rollback**
   ```bash
   # Revert to previous Git commit
   git revert HEAD
   git push origin feature/001-ec2-alb-nginx
   # Trigger HCP Terraform run
   ```

3. **Partial Rollback (specific resources)**
   ```bash
   # Destroy and recreate specific resource
   terraform destroy -target=module.ec2_instances
   terraform apply
   ```

### Disaster Recovery Scenarios

| Scenario | Detection | Recovery Time | Procedure |
|----------|-----------|---------------|-----------|
| Single instance failure | Health check (30s) | 0 minutes | Automatic - ALB routes to healthy instance |
| Single AZ failure | Health check (60s) | 0 minutes | Automatic - ALB routes to other AZ |
| ALB failure | External monitoring | 10-15 minutes | Recreate ALB via Terraform |
| Complete infrastructure loss | Manual detection | 15 minutes | `terraform apply` from HCP |
| State corruption | Terraform error | 5 minutes | Restore from HCP state history |

---

## Monitoring & Observability

### Key Metrics

**ALB Metrics (CloudWatch):**
- `TargetResponseTime`: Latency (target: <500ms for 95%)
- `HealthyHostCount`: Healthy instances (target: 2)
- `UnHealthyHostCount`: Unhealthy instances (target: 0)
- `RequestCount`: Total requests
- `HTTPCode_Target_2XX_Count`: Successful requests
- `HTTPCode_Target_5XX_Count`: Server errors (target: 0)

**EC2 Metrics (CloudWatch):**
- `CPUUtilization`: CPU usage
- `NetworkIn/Out`: Network traffic
- `StatusCheckFailed`: Instance health

**Target Group Metrics:**
- `HealthCheckStatus`: Per-instance health
- `TargetConnectionErrorCount`: Connection failures

### Alerting Thresholds

```yaml
alerts:
  - name: UnhealthyTargets
    condition: UnHealthyHostCount >= 1
    duration: 2 minutes
    action: SNS notification
  
  - name: HighLatency
    condition: TargetResponseTime > 500ms (p95)
    duration: 5 minutes
    action: SNS notification
  
  - name: HighErrorRate
    condition: HTTPCode_Target_5XX_Count > 10
    duration: 1 minute
    action: SNS notification
```

---

## Terraform Module Implementation Order

### Phase 1: Foundation (Data + IAM)
1. Query default VPC and subnets (`module.vpc_data`)
2. Create IAM role and instance profile (`module.iam`)

### Phase 2: Security
3. Create ALB security group (`module.security_groups`)
4. Create EC2 security group (`module.security_groups`)

### Phase 3: Load Balancing
5. Create ALB and target group (`module.alb`)
6. Create HTTPS listener with certificate (`module.alb`)

### Phase 4: Compute
7. Launch EC2 instances with Nginx (`module.ec2_instances`)
8. Wait for instance initialization (user_data execution)

### Phase 5: Registration
9. Register instances to target group (`module.target_group_attachments`)
10. Wait for health checks to pass

### Phase 6: Validation
11. Verify ALB DNS resolution
12. Test HTTPS connectivity
13. Validate traffic distribution

---

## References

### Requirement Traceability

| Requirement | Data Model Component | Notes |
|-------------|---------------------|-------|
| FR-001 | `variable.availability_zones` | Validates exactly 2 AZs |
| FR-002 | `variable.use_default_vpc`, `module.vpc_data` | Queries default VPC |
| FR-003 | `module.alb` | Creates internet-facing ALB |
| FR-004 | `variable.certificate_arn`, HTTPS listener | SSL certificate config |
| FR-005 | ALB listener rules | HTTPS-only enforcement |
| FR-006 | `variable.nginx_config`, user_data | Nginx installation |
| FR-007 | `variable.static_content_html` | Static content deployment |
| FR-008 | `variable.health_check` | Health check configuration |
| FR-009 | Target group settings | Automatic deregistration |
| FR-010 | `module.security_groups` | Least-privilege rules |
| FR-011 | `module.iam` | Minimum IAM permissions |
| FR-012 | `variable.instance_type` validation | Cost-optimized instances |

### AWS Documentation Links

- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [IAM Roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
- [ACM Certificates](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html)

---

## Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-17 | System | Initial data model creation |

---

**Document Status**: Draft  
**Last Updated**: 2025-01-17  
**Next Review**: Before Phase 1 implementation
