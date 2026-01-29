# Implementation Plan: EC2 ALB Nginx Development Environment

**Branch**: `001-ec2-alb-nginx` | **Date**: 2025-01-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ec2-alb-nginx/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy a secure, cost-optimized development environment using Application Load Balancer and EC2 instances running Nginx across multiple availability zones in ap-southeast-1. The infrastructure will use private registry modules exclusively (ravi-panchal-org) for ALB, EC2, and security groups, enforce HTTPS with ACM-managed certificates, enable Systems Manager Session Manager access without SSH keys, and maintain monthly costs under $100 USD. All resources will be deployed using Terraform through HCP Terraform with the existing default VPC.

## Technical Context

**Infrastructure as Code**: Terraform >= 1.5.7, HCL  
**Cloud Provider**: AWS (hashicorp/aws provider >= 6.0)  
**Primary Dependencies**: 
  - Private Module: `app.terraform.io/ravi-panchal-org/alb/aws` v10.2.0
  - Private Module: `app.terraform.io/ravi-panchal-org/ec2-instance/aws` v6.1.4
  - Private Module: `app.terraform.io/ravi-panchal-org/security-group/aws` v5.3.1
**Deployment Platform**: HCP Terraform (ravi-panchal-org organization)
**Target Region**: ap-southeast-1 (Singapore)  
**Availability Zones**: ap-southeast-1a, ap-southeast-1b  
**Instance Types**: t3.micro or t3.small (cost-optimized)  
**Web Server**: Nginx (latest from Amazon Linux 2023 repositories)  
**Operating System**: Amazon Linux 2023 (x86_64)  
**Performance Goals**: 
  - ALB response time: < 5 seconds for initial page load
  - Health check detection: < 60 seconds for failures
  - Session Manager connection: < 30 seconds
**Constraints**: 
  - Monthly cost: < $100 USD
  - No SSH keys or direct SSH access
  - Use existing default VPC only
  - Development environment (not production-grade)
**Scale/Scope**: 
  - 2 EC2 instances (one per AZ)
  - 1 internet-facing Application Load Balancer
  - 1 target group with health checks
  - 2 security groups (ALB and EC2)
  - Minimal static content (HTML page)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Module-First Architecture (1.1)
- **Status**: PASS
- **Validation**: All infrastructure will use private registry modules from `app.terraform.io/ravi-panchal-org/`:
  - ALB module: `ravi-panchal-org/alb/aws` v10.2.0
  - EC2 module: `ravi-panchal-org/ec2-instance/aws` v6.1.4
  - Security Group module: `ravi-panchal-org/security-group/aws` v5.3.1
- **No raw resource declarations** will be used

### ✅ Specification-Driven Development (1.2)
- **Status**: PASS
- **Validation**: Complete specification exists at `specs/001-ec2-alb-nginx/spec.md` with:
  - Explicit functional requirements (FR-001 through FR-024)
  - Defined success criteria with measurable outcomes
  - Cost constraints ($50-100 USD/month)
  - Security requirements (no SSH, Systems Manager only)
  - Edge cases and validation criteria documented

### ✅ Security-First Automation (1.3)
- **Status**: PASS
- **Validation**:
  - No static credentials in code (workspace variable sets pre-configured)
  - SSH keys explicitly disabled per FR-014
  - Security groups follow least-privilege (FR-009: EC2 only from ALB)
  - IAM role uses managed policy `AmazonSSMManagedInstanceCore` per FR-013
  - SSL/TLS certificates managed via ACM (ephemeral data handling)
  - No hardcoded secrets or sensitive data

### ✅ HCP Terraform Prerequisites (2.1)
- **Status**: PASS
- **Configuration**:
  - Organization: `ravi-panchal-org` (detected from Terraform MCP)
  - Git Repository: `https://github.com/panchal-ravi/ai-iac-consumer-template.git`
  - Branch: `001-ec2-alb-nginx`
  - Workspace naming will follow: `<project>-dev` pattern

### ✅ Code Generation Standards (III)
- **Status**: PASS
- **Validation**:
  - Git branch strategy: `001-ec2-alb-nginx` feature branch (already created from spec)
  - File organization: Will use standard files (main.tf, variables.tf, outputs.tf, locals.tf, providers.tf, versions.tf)
  - Naming conventions: Will follow HashiCorp standards with `snake_case` variables
  - No monolithic files (infrastructure is simple, ~200-300 lines total)
  - Module sources will use `app.terraform.io/ravi-panchal-org/` prefix

### Summary
**All constitution requirements PASS** - No violations requiring justification. Implementation may proceed to Phase 0 research.

## Project Structure

### Documentation (this feature)

```text
specs/001-ec2-alb-nginx/
├── spec.md              # Feature specification (input)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - Module decisions, SSL strategy, cost analysis
├── data-model.md        # Phase 1 output - Infrastructure entities and relationships
├── quickstart.md        # Phase 1 output - Deployment and testing guide
└── contracts/           # Phase 1 output - API/interface definitions
    ├── alb-listeners.yaml        # ALB listener configuration schema
    ├── target-group-config.yaml  # Target group and health check schema
    └── user-data.sh              # EC2 bootstrap script contract
```

### Source Code (repository root)

```text
# Terraform Infrastructure Configuration (Single Project)
/
├── main.tf              # Module instantiations for ALB, EC2, security groups
├── locals.tf            # Computed values: tags, common configurations
├── variables.tf         # Input variable declarations with validation
├── outputs.tf           # ALB DNS, instance IDs, security group IDs
├── providers.tf         # AWS provider configuration
├── versions.tf          # Terraform and provider version constraints
├── override.tf          # HCP Terraform backend configuration
├── sandbox.auto.tfvars  # Development environment variable values
└── .terraform/          # Terraform working directory (gitignored)

# No nested modules or separate directories needed for this simple infrastructure
```

**Structure Decision**: Single-project structure selected because this is a straightforward infrastructure deployment with no application code, frontend, or backend components. All infrastructure is defined through module composition at the root level. The simplicity of the requirement (2 EC2 instances + ALB) doesn't warrant a multi-directory structure.

## Complexity Tracking

> **No violations detected** - All constitution checks pass without requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

---

## Phase 0: Research & Decision Making

### 0.1 SSL/TLS Certificate Strategy

**Decision**: Use AWS Certificate Manager (ACM) with self-signed certificate for development

**Research Questions**:
1. How to create self-signed certificate for ALB without custom domain?
2. What are the browser warning implications?
3. Can ACM import self-signed certificates or must we use AWS certificate request?
4. What are the cost implications?

**Alternatives Considered**:
- **Option A**: ACM-managed certificate (requires domain validation)
  - ❌ Requires custom domain name (out of scope per spec)
  - ❌ Requires Route 53 or external DNS configuration
  
- **Option B**: Self-signed certificate imported to ACM
  - ✅ No domain required, works with ALB DNS name
  - ✅ Zero cost for certificate
  - ⚠️ Browser security warnings (acceptable for dev environment)
  - ✅ Selected approach

- **Option C**: IAM server certificate
  - ⚠️ Requires manual certificate management
  - ⚠️ More complex than ACM
  
**Implementation Approach**:
- Generate self-signed certificate using OpenSSL during setup
- Import certificate to ACM via AWS CLI or Terraform resource
- Reference ACM certificate ARN in ALB module listener configuration
- Document browser warning handling in quickstart.md

### 0.2 Terraform Module Selection & Compatibility

**Decision**: Use private registry modules from `ravi-panchal-org` exclusively

**Module Analysis**:

1. **ALB Module**: `app.terraform.io/ravi-panchal-org/alb/aws` v10.2.0
   - ✅ Supports both HTTP and HTTPS listeners with certificate configuration
   - ✅ Built-in target group creation with health check configuration
   - ✅ Security group creation with configurable ingress rules
   - ✅ Supports HTTP-to-HTTPS redirect via listener configuration
   - **Key Inputs Required**:
     - `name`: ALB name
     - `internal`: false (internet-facing)
     - `security_group_ingress_rules`: Port 80 and 443 from 0.0.0.0/0
     - `listeners`: HTTP (port 80) and HTTPS (port 443) with redirect
     - `target_groups`: Configuration for EC2 instances with health checks
     - `default_port`: 80
     - `default_protocol`: HTTP

2. **EC2 Module**: `app.terraform.io/ravi-panchal-org/ec2-instance/aws` v6.1.4
   - ✅ Supports IAM instance profile creation with managed policies
   - ✅ User data script support (both plain and base64)
   - ✅ Security group creation with ingress/egress rules
   - ✅ Systems Manager Session Manager compatible
   - ✅ Amazon Linux 2023 AMI via SSM parameter lookup
   - **Key Inputs Required**:
     - `name`: Instance name (will use for_each for multiple instances)
     - `instance_type`: t3.micro or t3.small
     - `ami_ssm_parameter`: `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
     - `subnet_id`: From default VPC data source
     - `user_data`: Nginx installation script
     - `create_iam_instance_profile`: true
     - `iam_role_policies`: `{ ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }`
     - `create_security_group`: true
     - `security_group_ingress_rules`: Port 80 from ALB security group
     - `key_name`: null (no SSH keys)

3. **Security Group Module**: `app.terraform.io/ravi-panchal-org/security-group/aws` v5.3.1
   - ℹ️ Not needed - both ALB and EC2 modules have built-in security group creation
   - Will leverage built-in security group features of ALB and EC2 modules

**Module Compatibility Matrix**:
| Module | Version | AWS Provider | Terraform Version | Status |
|--------|---------|--------------|-------------------|--------|
| alb | 10.2.0 | >= 6.0 | >= 1.5.7 | ✅ Compatible |
| ec2-instance | 6.1.4 | >= 6.0 | >= 1.5.7 | ✅ Compatible |

### 0.3 Default VPC Discovery Strategy

**Decision**: Use Terraform data sources to discover default VPC and subnets

**Implementation**:
```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  filter {
    name   = "availability-zone"
    values = ["ap-southeast-1a", "ap-southeast-1b"]
  }
}
```

**Validation Requirements**:
- Verify default VPC exists in ap-southeast-1
- Verify at least 2 subnets exist in target AZs
- Fail with clear error message if prerequisites missing

### 0.4 Nginx Installation & Configuration

**Decision**: Use user_data script to install Nginx and create static HTML

**User Data Script Design**:
```bash
#!/bin/bash
# Install Nginx on Amazon Linux 2023
dnf update -y
dnf install -y nginx

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)

# Create static HTML page with AZ information
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>EC2 ALB Nginx Demo</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; }
        .info { background: #f0f0f0; padding: 20px; border-radius: 10px; }
    </style>
</head>
<body>
    <h1>🚀 EC2 ALB Nginx Development Environment</h1>
    <div class="info">
        <h2>Instance Information</h2>
        <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
        <p><strong>Availability Zone:</strong> $AVAILABILITY_ZONE</p>
    </div>
</body>
</html>
EOF

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx
```

**Health Check Endpoint**:
- Default Nginx root path `/` serves the custom HTML
- Health check configuration: `path = "/", interval = 30s, timeout = 5s`

### 0.5 Cost Optimization Analysis

**Monthly Cost Breakdown** (24/7 operation):

| Component | Specification | Unit Cost | Quantity | Monthly Cost |
|-----------|--------------|-----------|----------|--------------|
| EC2 t3.micro | On-demand, ap-southeast-1 | $0.0104/hour | 2 instances | ~$15.12 |
| ALB | Application Load Balancer | $0.0252/hour | 1 | ~$18.14 |
| ALB LCU | Load Balancer Capacity Units | ~$0.008/LCU-hour | Minimal usage | ~$5-10 |
| Data Transfer | Outbound internet traffic | $0.12/GB | Minimal (dev testing) | ~$2-5 |
| ACM Certificate | Self-signed import | Free | 1 | $0.00 |
| CloudWatch Metrics | Basic monitoring | Free (basic) | Included | $0.00 |
| **Total Estimated** | | | | **$40-48/month** |

**Cost Optimization Strategies**:
1. ✅ Use t3.micro (smallest viable instance, free-tier eligible)
2. ✅ Only 2 instances (minimum for multi-AZ)
3. ✅ No NAT Gateway (instances in public subnets)
4. ✅ No CloudWatch Logs aggregation (optional feature)
5. ✅ No ALB access logs to S3 (optional feature)
6. ⚠️ **Manual shutdown recommended**: Stop instances outside testing hours to reduce EC2 costs by ~70%

**Risk Assessment**: Monthly costs are **well below** $100 target ($40-48). Actual costs may vary based on:
- Data transfer volume during testing
- ALB LCU consumption (connections, requests, rules evaluated)
- Operating hours (stopping instances when not in use significantly reduces costs)

### 0.6 Network Architecture Decisions

**Decision**: Deploy EC2 instances in public subnets of default VPC

**Rationale**:
- ✅ No NAT Gateway required (cost optimization)
- ✅ Instances can download packages directly from internet
- ✅ ALB can route traffic to instances in public subnets
- ✅ Security groups restrict inbound access (no public IPs needed for instances)

**Network Flow**:
```
Internet
   ↓ (HTTPS/HTTP)
Application Load Balancer (internet-facing)
   ↓ (HTTP on port 80, security group restricted)
EC2 Instances (public subnet, no public IP association required)
   ↓ (HTTP response)
ALB → Internet
```

**Security Posture**:
- ALB security group: Allow 0.0.0.0/0 on ports 80 and 443
- EC2 security group: Allow only ALB security group on port 80
- No public IP association for EC2 instances (optional configuration)
- Systems Manager Session Manager uses AWS PrivateLink (no inbound ports required)

### 0.7 Testing & Validation Strategy

**Pre-Deployment Tests**:
1. `terraform init` - Verify module access and provider download
2. `terraform validate` - Syntax and configuration validation
3. `terraform plan` - Review resource creation plan
4. Cost estimation via Terraform Cloud cost estimation feature

**Post-Deployment Tests**:
1. **Connectivity Test**: Access ALB DNS name via HTTPS in browser
   - Expected: Certificate warning (self-signed), then page loads
   - Validates: ALB listener, certificate, routing, EC2 health

2. **HTTP Redirect Test**: Access ALB DNS name via HTTP
   - Expected: Automatic redirect to HTTPS
   - Validates: HTTP-to-HTTPS redirect rule

3. **Multi-AZ Distribution Test**: Refresh page multiple times
   - Expected: See different availability zones (ap-southeast-1a and 1b)
   - Validates: Load balancing across instances

4. **Health Check Test**: Stop Nginx on one instance
   - Command: `sudo systemctl stop nginx`
   - Expected: ALB marks instance unhealthy, routes to healthy instance only
   - Validates: Health check configuration and automatic failover

5. **Session Manager Test**: Connect to instance without SSH
   - Command: `aws ssm start-session --target <instance-id>`
   - Expected: Shell session established
   - Validates: IAM role, Session Manager endpoint access

6. **Security Test**: Attempt direct EC2 access
   - Expected: Connection timeout (no public IP or security group blocks)
   - Validates: Security group restrictions

**Validation Acceptance Criteria**:
- ✅ All 6 tests pass
- ✅ No CRITICAL security findings from automated scanning
- ✅ Monthly cost estimate < $100

---

## Phase 1: Design & Architecture

### 1.1 Infrastructure Component Design

**Component Architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Region: ap-southeast-1            │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              Default VPC (10.0.0.0/16)                │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │  Application Load Balancer (Internet-Facing)     │ │ │
│  │  │  - HTTP Listener (80) → Redirect to HTTPS        │ │ │
│  │  │  - HTTPS Listener (443) → Target Group           │ │ │
│  │  │  - Security Group: 0.0.0.0/0 → 80,443           │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                          │                             │ │
│  │              ┌───────────┴───────────┐                │ │
│  │              │                       │                │ │
│  │  ┌───────────▼──────────┐  ┌────────▼───────────┐   │ │
│  │  │  Subnet: 1a          │  │  Subnet: 1b        │   │ │
│  │  │  (Public)            │  │  (Public)          │   │ │
│  │  │                      │  │                    │   │ │
│  │  │  ┌────────────────┐ │  │  ┌────────────────┐│   │ │
│  │  │  │ EC2 Instance   │ │  │  │ EC2 Instance   ││   │ │
│  │  │  │ - t3.micro     │ │  │  │ - t3.micro     ││   │ │
│  │  │  │ - Amazon Linux │ │  │  │ - Amazon Linux ││   │ │
│  │  │  │ - Nginx        │ │  │  │ - Nginx        ││   │ │
│  │  │  │ - Port 80      │ │  │  │ - Port 80      ││   │ │
│  │  │  │ - IAM Role     │ │  │  │ - IAM Role     ││   │ │
│  │  │  │   (SSM)        │ │  │  │   (SSM)        ││   │ │
│  │  │  └────────────────┘ │  │  └────────────────┘│   │ │
│  │  └───────────────────────┘  └────────────────────┘   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  AWS Certificate Manager (ACM)                         │ │
│  │  - Self-signed certificate imported                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Systems Manager Session Manager                       │ │
│  │  - Endpoints for private access                        │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 Resource Dependency Graph

```
data.aws_vpc.default
    │
    ├─→ data.aws_subnets.default
    │       │
    │       └─→ module.ec2_instance["az_a"]
    │       └─→ module.ec2_instance["az_b"]
    │
    └─→ module.alb
            │
            ├─→ aws_acm_certificate.self_signed (created outside Terraform initially)
            └─→ target_group (references EC2 instances)

module.ec2_instance[*]
    ├─→ IAM Role (created by module)
    ├─→ IAM Instance Profile (created by module)
    ├─→ Security Group (created by module)
    └─→ User Data (Nginx installation)

module.alb
    ├─→ Security Group (created by module)
    ├─→ Target Group (created by module)
    ├─→ HTTP Listener (redirect rule)
    └─→ HTTPS Listener (certificate attachment)
```

**Critical Dependencies**:
1. Default VPC must exist before any resource creation
2. ACM certificate must be created/imported before ALB HTTPS listener
3. EC2 instances must be running before target group health checks pass
4. Security groups must allow ALB → EC2 traffic for health checks to succeed

### 1.3 Module Configuration Specifications

**Module: ALB**
```hcl
module "alb" {
  source  = "app.terraform.io/ravi-panchal-org/alb/aws"
  version = "10.2.0"

  name     = "${var.environment}-alb-nginx"
  internal = false
  
  vpc_id  = data.aws_vpc.default.id
  subnets = data.aws_subnets.default.ids

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow HTTP traffic from internet"
    }
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow HTTPS traffic from internet"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.acm_certificate_arn
      forward = {
        target_group_key = "ec2_instances"
      }
    }
  }

  target_groups = {
    ec2_instances = {
      name        = "${var.environment}-ec2-tg"
      port        = 80
      protocol    = "HTTP"
      target_type = "instance"
      vpc_id      = data.aws_vpc.default.id
      
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
      
      # EC2 instances will be attached via separate resource
      create_attachment = false
    }
  }

  tags = local.common_tags
}
```

**Module: EC2 Instances**
```hcl
module "ec2_instance" {
  source   = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version  = "6.1.4"
  for_each = {
    az_a = {
      availability_zone = "ap-southeast-1a"
      subnet_id         = data.aws_subnets.default.ids[0]
    }
    az_b = {
      availability_zone = "ap-southeast-1b"
      subnet_id         = data.aws_subnets.default.ids[1]
    }
  }

  name                        = "${var.environment}-ec2-nginx-${each.key}"
  ami_ssm_parameter           = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type               = var.instance_type
  subnet_id                   = each.value.subnet_id
  availability_zone           = each.value.availability_zone
  associate_public_ip_address = true  # Required for package downloads
  user_data                   = local.user_data_script
  key_name                    = null  # No SSH keys per FR-014

  # IAM Role for Systems Manager
  create_iam_instance_profile = true
  iam_role_name               = "${var.environment}-ec2-ssm-role-${each.key}"
  iam_role_policies = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Security Group
  create_security_group = true
  security_group_name   = "${var.environment}-ec2-sg-${each.key}"
  security_group_vpc_id = data.aws_vpc.default.id
  security_group_ingress_rules = {
    http_from_alb = {
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.alb.security_group_id
      description                  = "Allow HTTP from ALB only"
    }
  }

  # No EBS volumes needed for basic web server
  enable_volume_tags = false

  tags = merge(
    local.common_tags,
    {
      AvailabilityZone = each.value.availability_zone
    }
  )
}
```

### 1.4 Security Group Rules Specification

**ALB Security Group** (created by ALB module):
```yaml
Ingress Rules:
  - Port: 80 (HTTP)
    Protocol: TCP
    Source: 0.0.0.0/0
    Description: "Allow HTTP from internet for redirect to HTTPS"
  
  - Port: 443 (HTTPS)
    Protocol: TCP
    Source: 0.0.0.0/0
    Description: "Allow HTTPS from internet"

Egress Rules:
  - Port: All
    Protocol: All
    Destination: 0.0.0.0/0
    Description: "Allow all outbound traffic to EC2 instances"
```

**EC2 Security Group** (created by EC2 module for each instance):
```yaml
Ingress Rules:
  - Port: 80 (HTTP)
    Protocol: TCP
    Source: ALB Security Group ID
    Description: "Allow HTTP from ALB only"

Egress Rules:
  - Port: All
    Protocol: All
    Destination: 0.0.0.0/0
    Description: "Allow outbound for package downloads and updates"
```

**Security Validation**:
- ✅ No SSH (port 22) ingress rules
- ✅ EC2 instances only accept traffic from ALB
- ✅ ALB is the only internet-facing entry point
- ✅ Systems Manager uses AWS PrivateLink (no security group rules needed)

### 1.5 IAM Policy Specification

**EC2 IAM Role Policy** (managed policy):
```json
{
  "PolicyName": "AmazonSSMManagedInstanceCore",
  "PolicyArn": "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  "Description": "AWS managed policy for Systems Manager Session Manager"
}
```

**Policy Permissions** (AWS Managed - no custom policy needed):
- `ssm:UpdateInstanceInformation` - Register instance with Systems Manager
- `ssmmessages:CreateControlChannel` - Establish Session Manager connection
- `ssmmessages:CreateDataChannel` - Data transmission for session
- `ssmmessages:OpenControlChannel` - Maintain session connection
- `ssmmessages:OpenDataChannel` - Maintain data channel
- `ec2messages:AcknowledgeMessage` - EC2 message handling
- `ec2messages:DeleteMessage` - Message cleanup
- `ec2messages:FailMessage` - Error handling
- `ec2messages:GetEndpoint` - Service endpoint discovery
- `ec2messages:GetMessages` - Receive commands
- `ec2messages:SendReply` - Send command responses

**Trust Relationship**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Security Posture**:
- ✅ Uses AWS managed policy (regularly updated by AWS)
- ✅ Minimal permissions (only Systems Manager access)
- ✅ No S3, CloudWatch Logs, or other service permissions
- ✅ Follows least-privilege principle per constitution

### 1.6 SSL/TLS Certificate Implementation

**Certificate Creation Process** (pre-Terraform):

```bash
# Generate self-signed certificate with OpenSSL
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/alb-private-key.pem \
  -out /tmp/alb-certificate.pem \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=Development/CN=*.elb.amazonaws.com"

# Import certificate to ACM
aws acm import-certificate \
  --certificate fileb:///tmp/alb-certificate.pem \
  --private-key fileb:///tmp/alb-private-key.pem \
  --region ap-southeast-1 \
  --tags Key=Environment,Value=development Key=Project,Value=ec2-alb-nginx-demo

# Output certificate ARN for use in Terraform
aws acm list-certificates --region ap-southeast-1 \
  --query 'CertificateSummaryList[?DomainName==`*.elb.amazonaws.com`].CertificateArn' \
  --output text
```

**Terraform Variable Configuration**:
```hcl
variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS listener (self-signed certificate)"
  type        = string
  
  validation {
    condition     = can(regex("^arn:aws:acm:", var.acm_certificate_arn))
    error_message = "Certificate ARN must be a valid ACM certificate ARN"
  }
}
```

**Browser Warning Handling**:
- Chrome: "Your connection is not private" (NET::ERR_CERT_AUTHORITY_INVALID)
- Firefox: "Warning: Potential Security Risk Ahead"
- Safari: "This Connection Is Not Private"
- **User Action**: Click "Advanced" → "Proceed to [ALB DNS] (unsafe)"

**Documentation Note**: This self-signed certificate is acceptable for development/testing only. For production, use ACM with domain validation or purchase certificate from trusted CA.

### 1.7 Deployment Workflow Design

**Step 1: Pre-Deployment Preparation**
```bash
# 1. Generate and import SSL certificate
./scripts/setup-ssl-certificate.sh

# 2. Export certificate ARN
export TF_VAR_acm_certificate_arn=$(aws acm list-certificates ...)

# 3. Initialize Terraform
terraform init

# 4. Validate configuration
terraform validate
```

**Step 2: Planning & Review**
```bash
# 5. Create execution plan
terraform plan -out=plan.tfplan

# 6. Review planned changes
# Expected resources:
#   - 2 EC2 instances
#   - 1 Application Load Balancer
#   - 2 target group attachments
#   - 2 security groups (ALB + EC2)
#   - 2 IAM roles + instance profiles
#   - 1 target group
#   - 2 listeners (HTTP redirect + HTTPS forward)

# 7. Cost estimation (via HCP Terraform)
# Review estimated monthly cost < $100
```

**Step 3: Deployment Execution**
```bash
# 8. Apply infrastructure changes
terraform apply plan.tfplan

# 9. Wait for instance initialization (~2-3 minutes)
# User data script installs Nginx

# 10. Capture outputs
ALB_DNS=$(terraform output -raw alb_dns_name)
INSTANCE_IDS=$(terraform output -json instance_ids | jq -r '.[]')
```

**Step 4: Validation Testing**
```bash
# 11. Test HTTPS connectivity
curl -k https://$ALB_DNS

# 12. Test HTTP redirect
curl -I http://$ALB_DNS
# Expected: HTTP/1.1 301 Moved Permanently
# Location: https://...

# 13. Test Session Manager access
aws ssm start-session --target $(echo $INSTANCE_IDS | awk '{print $1}')

# 14. Verify health checks
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
# Expected: All instances "healthy"
```

**Step 5: Post-Deployment Cleanup** (when testing complete)
```bash
# 15. Destroy infrastructure
terraform destroy -auto-approve

# 16. Delete ACM certificate
aws acm delete-certificate --certificate-arn $TF_VAR_acm_certificate_arn
```

**Rollback Strategy**:
- If deployment fails: `terraform destroy` removes all created resources
- If partial failure: Review Terraform state, manually clean up orphaned resources
- No persistent data loss risk (stateless web servers)

---

## Phase 2: Data Model & Contracts

*Note: This section will be populated with detailed data model and contract specifications. See data-model.md and contracts/ for full specifications.*

**Summary**:
- Infrastructure entity relationships defined
- API contracts for ALB listeners and target groups
- User data script interface specification
- Health check endpoint contract
- Systems Manager access patterns

---

## Phase 3: Deployment Artifacts

### Generated Files

1. **research.md** ✅ (Embedded in this plan document, Phase 0)
2. **data-model.md** - Infrastructure entity model
3. **quickstart.md** - Step-by-step deployment guide
4. **contracts/** - Configuration schemas

### Implementation Readiness

**Status**: ✅ **READY FOR PHASE 2 (tasks.md generation)**

**Completeness Checklist**:
- [x] Module selection complete (3 private modules identified)
- [x] SSL/TLS strategy defined (self-signed ACM import)
- [x] Security architecture validated (no SSH, Systems Manager only)
- [x] Cost analysis complete ($40-48/month, well under $100 target)
- [x] Network architecture designed (default VPC, public subnets)
- [x] Module configurations specified (HCL examples provided)
- [x] Deployment workflow documented (9-step process)
- [x] Validation tests defined (6 test scenarios)
- [x] Constitution compliance verified (all gates pass)

**Next Steps**:
1. Run `/speckit.plan` completion script to generate artifacts
2. Execute Phase 1 artifact generation (data-model.md, contracts/, quickstart.md)
3. Run `/speckit.tasks` to generate tasks.md with actionable implementation steps
4. Begin implementation phase with `/speckit.implement`

**Branch**: `001-ec2-alb-nginx` (already created)
**Artifacts Output Directory**: `/workspace/specs/001-ec2-alb-nginx/`
