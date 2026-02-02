# Data Model: EC2 Instance with ALB and Nginx

**Feature Branch**: `003-ec2-alb-nginx`  
**Created**: 2025-01-21  
**Status**: Complete

---

## Overview

This document defines the logical data model and entity relationships for the EC2 ALB Nginx infrastructure. The model follows AWS resource hierarchy and incorporates Terraform module abstractions from the private registry.

---

## Entity Relationship Diagram

```
┌─────────────────┐
│   VPC (Data)    │
│  Default VPC    │
└────────┬────────┘
         │ contains
         │
    ┌────┴──────────────┐
    │                   │
┌───▼────────┐    ┌────▼─────────┐
│  Subnet 1  │    │  Subnet 2    │
│    AZ-1    │    │    AZ-2      │
└───┬────────┘    └────┬─────────┘
    │                  │
    │  ┌───────────────┴──────┐
    │  │                      │
┌───▼──▼─────────┐    ┌───────▼──────────┐
│  ALB           │    │  EC2 Instances   │
│  (Public)      │────│  (Private)       │
│  HTTPS:443     │    │  HTTP:80         │
└───┬────────────┘    └───┬──────────────┘
    │                     │
    │ uses                │ runs
    │                     │
┌───▼─────────┐      ┌───▼──────────┐
│ ACM Cert    │      │   Nginx      │
│ (Imported)  │      │   Web Server │
└───┬─────────┘      └──────────────┘
    │ from
┌───▼─────────┐
│ TLS Cert    │
│ (Generated) │
└─────────────┘

Security Groups:
┌─────────────┐         ┌──────────────┐
│  ALB SG     │────────▶│   EC2 SG     │
│  Ingress:   │  refs   │   Ingress:   │
│  443/0.0.0.0│         │   80/ALB-SG  │
└─────────────┘         └──────────────┘
```

---

## Core Entities

### 1. VPC (Virtual Private Cloud)

**Type**: Data Source (Existing Resource)  
**AWS Resource**: `aws_vpc`  
**Terraform Resource**: `data.aws_vpc.default`

**Attributes**:
- `id` (string, required): VPC identifier
- `cidr_block` (string, computed): VPC CIDR block (e.g., 172.31.0.0/16)
- `default` (boolean, required): Must be `true` (using default VPC)
- `enable_dns_hostnames` (boolean, computed): DNS hostname support
- `enable_dns_support` (boolean, computed): DNS resolution support

**Relationships**:
- Contains: `Subnet` (1:N)
- Associated with: `Security Group` (1:N)

**Validation Rules**:
- VPC must exist in ap-southeast-1 region
- VPC must have Internet Gateway attached (implied by default VPC)
- VPC must have public subnets in at least 2 availability zones

---

### 2. Subnet

**Type**: Data Source (Existing Resource)  
**AWS Resource**: `aws_subnet`  
**Terraform Resource**: `data.aws_subnet.default`

**Attributes**:
- `id` (string, required): Subnet identifier
- `vpc_id` (string, required): Parent VPC ID
- `cidr_block` (string, computed): Subnet CIDR block
- `availability_zone` (string, required): Availability zone name (e.g., ap-southeast-1a)
- `availability_zone_id` (string, computed): AZ identifier
- `map_public_ip_on_launch` (boolean, computed): Auto-assign public IP
- `default_for_az` (boolean, filter): Default subnet for the AZ

**Relationships**:
- Belongs to: `VPC` (N:1)
- Contains: `EC2 Instance` (1:N)
- Used by: `ALB` (N:M)

**Validation Rules**:
- Minimum 2 subnets required
- Subnets must be in different availability zones
- Subnets must be public (route to Internet Gateway)

**Selection Logic**:
```
1. Query all subnets in default VPC
2. Filter for default subnets (one per AZ)
3. Group by availability zone
4. Select first subnet from each of first 2 AZs
```

---

### 3. EC2 Instance

**Type**: Managed Resource  
**AWS Resource**: `aws_instance`  
**Terraform Module**: `app.terraform.io/ravi-panchal-org/ec2-instance/aws`  
**Module Version**: `6.1.4`

**Attributes**:
- `id` (string, computed): Instance identifier (i-xxxxx)
- `name` (string, required): Instance name (e.g., "web-demo-dev-ec2-az1")
- `instance_type` (string, required): Instance size (t3.micro or t2.micro)
- `ami` (string, computed): Amazon Machine Image ID (Amazon Linux 2023)
- `ami_ssm_parameter` (string, required): SSM parameter for AMI lookup
- `subnet_id` (string, required): Placement subnet ID
- `vpc_security_group_ids` (list(string), required): Security group IDs
- `user_data` (string, required): Bootstrap script for Nginx installation
- `availability_zone` (string, computed): AZ where instance is placed
- `private_ip` (string, computed): Private IPv4 address
- `public_ip` (string, computed): Public IPv4 address (if assigned)
- `tags` (map(string), required): Resource tags

**Relationships**:
- Placed in: `Subnet` (N:1)
- Protected by: `Security Group` (N:M)
- Registered with: `Target Group` (N:1)
- Runs: `Nginx` (1:1)

**State Transitions**:
```
Pending → Running → Healthy (in target group)
Running → Unhealthy (health check fails)
Unhealthy → Healthy (health check passes)
Running → Stopped → Terminated
```

**Validation Rules**:
- Instance type must be t3.micro or t2.micro
- User data must install and configure Nginx
- Instance must be placed in one of the selected subnets
- Instance must have exactly one security group (EC2 security group)
- Instance must pass health checks within 120 seconds of launch

**Bootstrap Requirements**:
- Install Nginx via package manager
- Configure Nginx to listen on port 80
- Create custom index page with instance metadata
- Create /health endpoint for health checks
- Start and enable Nginx service

---

### 4. Application Load Balancer (ALB)

**Type**: Managed Resource  
**AWS Resource**: `aws_lb`  
**Terraform Module**: `app.terraform.io/ravi-panchal-org/alb/aws`  
**Module Version**: `10.2.0`

**Attributes**:
- `id` (string, computed): ALB identifier
- `arn` (string, computed): Amazon Resource Name
- `name` (string, required): Load balancer name (e.g., "web-demo-dev-alb")
- `load_balancer_type` (string, required): Must be "application"
- `internal` (boolean, required): Must be `false` (internet-facing)
- `subnets` (list(string), required): Subnet IDs (minimum 2 AZs)
- `security_groups` (list(string), required): Security group IDs
- `dns_name` (string, computed): ALB DNS name (for CNAME records)
- `zone_id` (string, computed): Route 53 hosted zone ID
- `vpc_id` (string, required): VPC ID
- `tags` (map(string), required): Resource tags

**Relationships**:
- Deployed in: `VPC` (N:1)
- Spans: `Subnet` (N:M, minimum 2)
- Protected by: `Security Group` (1:1)
- Forwards to: `Target Group` (1:N)
- Uses: `ACM Certificate` (1:1)

**Validation Rules**:
- Must span at least 2 availability zones
- Must have internet-facing scheme
- Must have HTTPS listener on port 443
- Must NOT have HTTP listener on port 80
- Must reference valid ACM certificate ARN
- Security group must allow HTTPS from 0.0.0.0/0

---

### 5. Target Group

**Type**: Managed Resource (via ALB module)  
**AWS Resource**: `aws_lb_target_group`  
**Terraform Module**: Embedded in ALB module

**Attributes**:
- `id` (string, computed): Target group identifier
- `arn` (string, computed): Amazon Resource Name
- `name` (string, required): Target group name (e.g., "web-demo-dev-tg")
- `port` (number, required): Backend port (80)
- `protocol` (string, required): Backend protocol (HTTP)
- `vpc_id` (string, required): VPC ID
- `target_type` (string, required): Must be "instance"
- `deregistration_delay` (number, optional): Delay before deregistering targets (default 300s)

**Health Check Configuration**:
- `enabled` (boolean, required): Must be `true`
- `protocol` (string, required): HTTP
- `port` (string, required): "traffic-port" (80)
- `path` (string, required): "/health"
- `interval` (number, required): 30 seconds
- `timeout` (number, required): 5 seconds
- `healthy_threshold` (number, required): 2 consecutive successes
- `unhealthy_threshold` (number, required): 2 consecutive failures
- `matcher` (string, required): "200" (HTTP status code)

**Relationships**:
- Belongs to: `ALB` (N:1)
- Contains: `EC2 Instance` (N:M as targets)

**Target Health States**:
```
Initial → Healthy (2 consecutive successful checks)
Healthy → Unhealthy (2 consecutive failed checks)
Unhealthy → Draining (deregistration initiated)
Draining → Unused (deregistration complete)
```

**Validation Rules**:
- Must have at least 1 healthy target for ALB to serve traffic
- Health check path must return HTTP 200
- Health check timeout must be less than interval

---

### 6. Security Group (ALB)

**Type**: Managed Resource  
**AWS Resource**: `aws_security_group`  
**Terraform Module**: `app.terraform.io/ravi-panchal-org/security-group/aws`  
**Module Version**: `5.3.1`

**Attributes**:
- `id` (string, computed): Security group identifier
- `name` (string, required): Security group name (e.g., "web-demo-dev-sg-alb")
- `description` (string, required): Purpose description
- `vpc_id` (string, required): VPC ID

**Ingress Rules**:
```hcl
[
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from internet"
  }
]
```

**Egress Rules**:
```hcl
[
  {
    from_port                = 80
    to_port                  = 80
    protocol                 = "tcp"
    source_security_group_id = <EC2_SECURITY_GROUP_ID>
    description              = "Allow HTTP to EC2 instances"
  }
]
```

**Relationships**:
- Belongs to: `VPC` (N:1)
- Protects: `ALB` (1:1)
- References: `Security Group (EC2)` (1:1 in egress rules)

**Validation Rules**:
- Must allow HTTPS (443) from 0.0.0.0/0
- Must allow egress to EC2 security group on port 80
- Must NOT allow HTTP (80) from internet

---

### 7. Security Group (EC2)

**Type**: Managed Resource  
**AWS Resource**: `aws_security_group`  
**Terraform Module**: `app.terraform.io/ravi-panchal-org/security-group/aws`  
**Module Version**: `5.3.1`

**Attributes**:
- `id` (string, computed): Security group identifier
- `name` (string, required): Security group name (e.g., "web-demo-dev-sg-ec2")
- `description` (string, required): Purpose description
- `vpc_id` (string, required): VPC ID

**Ingress Rules**:
```hcl
[
  {
    from_port                = 80
    to_port                  = 80
    protocol                 = "tcp"
    source_security_group_id = <ALB_SECURITY_GROUP_ID>
    description              = "Allow HTTP from ALB only"
  }
]
```

**Egress Rules**:
```hcl
[
  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for package installation"
  }
]
```

**Relationships**:
- Belongs to: `VPC` (N:1)
- Protects: `EC2 Instance` (1:N)
- Referenced by: `Security Group (ALB)` (1:1 in egress rules)

**Validation Rules**:
- Must allow HTTP (80) from ALB security group only
- Must NOT allow HTTP from 0.0.0.0/0
- Must NOT allow SSH (22) from internet
- Must allow outbound traffic for yum/apt package installation

---

### 8. TLS Private Key

**Type**: Managed Resource  
**AWS Resource**: N/A (Terraform TLS provider)  
**Terraform Resource**: `tls_private_key`

**Attributes**:
- `algorithm` (string, required): Must be "RSA"
- `rsa_bits` (number, required): Must be 2048 or 4096
- `private_key_pem` (string, sensitive, computed): Private key in PEM format
- `public_key_pem` (string, computed): Public key in PEM format
- `public_key_openssh` (string, computed): Public key in OpenSSH format

**Relationships**:
- Used by: `TLS Certificate` (1:1)
- Used by: `ACM Certificate` (1:1)

**Security Considerations**:
- Private key stored in Terraform state (encrypted at rest in HCP Terraform)
- Not suitable for production (use AWS Secrets Manager for production)
- Development environment only

**Validation Rules**:
- Algorithm must be RSA
- Key size must be at least 2048 bits

---

### 9. TLS Self-Signed Certificate

**Type**: Managed Resource  
**AWS Resource**: N/A (Terraform TLS provider)  
**Terraform Resource**: `tls_self_signed_cert`

**Attributes**:
- `private_key_pem` (string, sensitive, required): Private key reference
- `validity_period_hours` (number, required): Must be 2160 (90 days)
- `early_renewal_hours` (number, optional): Renewal trigger (default 720 = 30 days)
- `is_ca_certificate` (boolean, required): Must be `false`
- `cert_pem` (string, computed): Certificate in PEM format
- `cert_request_pem` (string, computed): Certificate request in PEM format
- `validity_start_time` (string, computed): Certificate validity start (RFC3339)
- `validity_end_time` (string, computed): Certificate validity end (RFC3339)

**Subject Configuration**:
```hcl
subject {
  common_name  = "web.demo.com"
  organization = "Development"
}
```

**DNS Names**:
- `dns_names = ["web.demo.com"]`

**Allowed Uses**:
```hcl
allowed_uses = [
  "key_encipherment",
  "digital_signature",
  "server_auth"
]
```

**Relationships**:
- Uses: `TLS Private Key` (1:1)
- Imported into: `ACM Certificate` (1:1)

**Validation Rules**:
- Validity period must be at least 90 days (2160 hours)
- Common name must be "web.demo.com"
- Must include "server_auth" in allowed uses
- Must include DNS name "web.demo.com"

---

### 10. ACM Certificate

**Type**: Managed Resource  
**AWS Resource**: `aws_acm_certificate`  
**Terraform Resource**: `aws_acm_certificate`

**Attributes**:
- `id` (string, computed): Certificate identifier
- `arn` (string, computed): Amazon Resource Name
- `domain_name` (string, computed): Certificate domain (web.demo.com)
- `private_key` (string, sensitive, required): Private key in PEM format
- `certificate_body` (string, required): Certificate in PEM format
- `status` (string, computed): Certificate status (ISSUED)
- `not_before` (string, computed): Validity start time
- `not_after` (string, computed): Validity end time
- `tags` (map(string), required): Resource tags

**Relationships**:
- Imports from: `TLS Certificate` (1:1)
- Imports from: `TLS Private Key` (1:1)
- Used by: `ALB HTTPS Listener` (1:N)

**State Transitions**:
```
Pending → Issued (after import)
Issued → Expired (after validity period)
```

**Validation Rules**:
- Certificate must be in PEM format
- Private key must be in PEM format
- Certificate must be valid (not expired)
- Certificate domain must match ALB configuration

**Lifecycle**:
```hcl
lifecycle {
  create_before_destroy = true
}
```

---

### 11. HTTPS Listener

**Type**: Managed Resource (via ALB module)  
**AWS Resource**: `aws_lb_listener`  
**Terraform Module**: Embedded in ALB module

**Attributes**:
- `load_balancer_arn` (string, required): Parent ALB ARN
- `port` (number, required): Must be 443
- `protocol` (string, required): Must be "HTTPS"
- `certificate_arn` (string, required): ACM certificate ARN
- `ssl_policy` (string, required): TLS security policy (e.g., "ELBSecurityPolicy-TLS13-1-2-2021-06")

**Default Action**:
```hcl
default_action {
  type             = "forward"
  target_group_arn = <TARGET_GROUP_ARN>
}
```

**Relationships**:
- Belongs to: `ALB` (N:1)
- Uses: `ACM Certificate` (N:1)
- Forwards to: `Target Group` (1:1)

**Validation Rules**:
- Port must be 443
- Protocol must be HTTPS
- Must reference valid ACM certificate ARN
- Must have default forward action to target group

---

### 12. Nginx Web Server

**Type**: Software Component (not Terraform-managed)  
**Installation**: Via EC2 user data  
**Version**: Latest from amazon-linux-extras or apt

**Configuration**:
- `listen` (number): Port 80 (HTTP)
- `server_name` (string): "web.demo.com"
- `root` (string): "/usr/share/nginx/html"
- `index` (string): "index.html"

**Endpoints**:
1. **Root Endpoint**: `/`
   - Returns: Custom HTML page with instance metadata
   - Status: 200 OK
   - Content-Type: text/html

2. **Health Check Endpoint**: `/health`
   - Returns: "healthy\n"
   - Status: 200 OK
   - Content-Type: text/plain
   - Access logging: Disabled

**Relationships**:
- Runs on: `EC2 Instance` (1:1)
- Serves traffic from: `ALB` (N:1)

**State Management**:
```
Stopped → Started (systemctl start nginx)
Started → Enabled (systemctl enable nginx)
```

**Validation Rules**:
- Must be installed and running before health checks pass
- Must listen on port 80 (not 443)
- Must serve /health endpoint with 200 status
- Must display instance metadata on index page

---

## Cross-Entity Constraints

### Constraint 1: Security Group Circular Reference
**Problem**: ALB SG needs EC2 SG ID in egress rules, EC2 SG needs ALB SG ID in ingress rules

**Resolution**:
```hcl
# Create both security groups first (no cross-references)
resource "security_group" "alb" { ... }
resource "security_group" "ec2" { ... }

# Add rules with references after both exist
resource "security_group_rule" "alb_to_ec2" {
  security_group_id        = security_group.alb.id
  source_security_group_id = security_group.ec2.id
  ...
}

resource "security_group_rule" "ec2_from_alb" {
  security_group_id        = security_group.ec2.id
  source_security_group_id = security_group.alb.id
  ...
}
```

### Constraint 2: Certificate Must Exist Before ALB Listener
**Dependency Chain**:
```
TLS Private Key → TLS Certificate → ACM Certificate → ALB Listener
```

**Terraform Dependency**:
```hcl
resource "aws_lb_listener" "https" {
  depends_on = [aws_acm_certificate.web]
  ...
}
```

### Constraint 3: EC2 Instances Must Be Healthy Before Traffic Flows
**Timing**:
1. EC2 instance launches (30-60 seconds)
2. User data script runs (30-90 seconds)
3. Nginx starts (5-10 seconds)
4. Health checks pass (60 seconds = 2 × 30s interval)
5. **Total**: ~2-4 minutes until traffic flows

**Validation**:
```bash
# Wait for instances to be healthy
aws elbv2 wait target-in-service \
  --target-group-arn <TG_ARN>
```

### Constraint 4: Subnet Selection Must Cover 2 AZs
**Logic**:
```hcl
locals {
  # Group subnets by AZ
  subnets_by_az = {
    for subnet in data.aws_subnet.default :
    subnet.availability_zone => subnet.id...
  }
  
  # Select first 2 AZs
  selected_azs = slice(sort(keys(local.subnets_by_az)), 0, 2)
  
  # Select one subnet per AZ
  alb_subnets = [
    for az in local.selected_azs :
    local.subnets_by_az[az][0]
  ]
}

# Validation
resource "validation" "az_count" {
  condition     = length(local.selected_azs) >= 2
  error_message = "Must have at least 2 availability zones"
}
```

---

## Tag Schema

### Standard Tags (Applied to All Resources)

```hcl
locals {
  common_tags = {
    # Project identification
    Project     = "web-demo"
    Feature     = "003-ec2-alb-nginx"
    GitHubIssue = "39"
    
    # Environment
    Environment = "development"
    
    # Management
    ManagedBy   = "terraform"
    Workspace   = "sandbox_workspace"
    
    # Cost tracking
    CostCenter  = "engineering-dev"
    
    # Metadata
    CreatedDate = "2025-01-21"
    Region      = "ap-southeast-1"
  }
}
```

### Resource-Specific Tags

```hcl
# EC2 Instance
tags = merge(local.common_tags, {
  Name             = "web-demo-dev-ec2-${availability_zone}"
  ResourceType     = "compute"
  AvailabilityZone = availability_zone
})

# ALB
tags = merge(local.common_tags, {
  Name         = "web-demo-dev-alb"
  ResourceType = "load-balancer"
  Scheme       = "internet-facing"
})

# Security Group
tags = merge(local.common_tags, {
  Name         = "web-demo-dev-sg-${purpose}"
  ResourceType = "security-group"
  Purpose      = purpose  # "alb" or "ec2"
})

# ACM Certificate
tags = merge(local.common_tags, {
  Name         = "web-demo-dev-cert"
  ResourceType = "certificate"
  Domain       = "web.demo.com"
})
```

---

## Capacity and Scaling

### Current Capacity (Development)
- EC2 Instances: 2 (1 per AZ)
- Instance Type: t3.micro (2 vCPU, 1 GB RAM)
- ALB: 1 (spanning 2 AZs)
- Target Group Capacity: 2 healthy targets minimum

### Theoretical Limits (AWS Account)
- EC2 Instances: 20 per region (default quota)
- ALBs: 50 per region (default quota)
- Target Groups: 3000 per region (default quota)
- ACM Certificates: 2500 per region (default quota)

### Performance Characteristics
- **Request Throughput**: ~100-200 req/s per t3.micro instance
- **Concurrent Connections**: ~1000 per instance (Nginx default)
- **Health Check Frequency**: Every 30 seconds per target
- **Failover Time**: 60 seconds (2 failed checks)

---

## State Management

### Terraform State Structure

```
terraform.tfstate
├── module.ec2_instance_az1
│   ├── aws_instance.this
│   └── (module-managed resources)
├── module.ec2_instance_az2
│   ├── aws_instance.this
│   └── (module-managed resources)
├── module.alb
│   ├── aws_lb.this
│   ├── aws_lb_target_group.this
│   ├── aws_lb_listener.https
│   └── (module-managed resources)
├── module.security_group_alb
│   ├── aws_security_group.this
│   └── (module-managed resources)
├── module.security_group_ec2
│   ├── aws_security_group.this
│   └── (module-managed resources)
├── tls_private_key.web
├── tls_self_signed_cert.web
├── aws_acm_certificate.web
├── data.aws_vpc.default
├── data.aws_subnets.default
└── data.aws_subnet.default[*]
```

### Sensitive Data in State
- `tls_private_key.web.private_key_pem` (encrypted at rest in HCP Terraform)
- `aws_acm_certificate.web.private_key` (encrypted at rest in HCP Terraform)

---

## Testing and Validation Data

### Sample Test Data

**Health Check Response**:
```
HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 8

healthy
```

**Index Page Response**:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Web Server</title>
</head>
<body>
    <h1>Welcome to web.demo.com</h1>
    <p><strong>Instance ID:</strong> i-0123456789abcdef0</p>
    <p><strong>Availability Zone:</strong> ap-southeast-1a</p>
    <p><strong>Environment:</strong> Development</p>
</body>
</html>
```

**Target Health Status**:
```json
{
  "TargetHealthDescriptions": [
    {
      "Target": {
        "Id": "i-0123456789abcdef0",
        "Port": 80
      },
      "HealthCheckPort": "80",
      "TargetHealth": {
        "State": "healthy"
      }
    },
    {
      "Target": {
        "Id": "i-0123456789abcdef1",
        "Port": 80
      },
      "HealthCheckPort": "80",
      "TargetHealth": {
        "State": "healthy"
      }
    }
  ]
}
```

---

## Summary

This data model defines:
- **12 core entities** (8 AWS resources, 2 TLS resources, 2 software components)
- **4 cross-entity constraints** requiring careful dependency management
- **Comprehensive attribute specifications** for each entity
- **Clear relationships** between entities
- **Validation rules** for each entity
- **State management** structure
- **Tag schema** for resource organization

**Model Status**: ✅ Complete and ready for implementation  
**Next Phase**: Contract definitions and API specifications
