# Research: EC2 Instance with ALB and Nginx

**Feature Branch**: `003-ec2-alb-nginx`  
**Research Date**: 2025-01-21  
**Status**: Complete

---

## Overview

This document consolidates research findings to resolve all unknowns identified during the technical context analysis and provides architectural decisions for implementing EC2 instances with Application Load Balancer (ALB) and Nginx across 2 availability zones in AWS ap-southeast-1 region.

---

## Private Module Registry Analysis

### Module Search Results

Searched the HCP Terraform private registry (`ravi-panchal-org`) for available modules:

#### 1. EC2 Instance Module

**Module ID**: `ravi-panchal-org/ec2-instance/aws`  
**Version**: `6.1.4`  
**Source**: `app.terraform.io/ravi-panchal-org/ec2-instance/aws`  
**Created**: 2025-11-17  
**Provider**: AWS

**Key Capabilities**:
- Supports single and multiple EC2 instance creation
- Built-in security group creation with configurable rules
- IAM role and instance profile management
- User data support for bootstrapping
- EBS volume management
- Network interface configuration
- Supports `t3.micro` and `t2.micro` instance types
- Integrated monitoring options
- AMI selection via SSM parameter or direct AMI ID

**Critical Inputs for This Feature**:
- `name`: Instance identifier
- `instance_type`: `t3.micro` or `t2.micro`
- `subnet_id`: Subnet for placement (different per AZ)
- `vpc_security_group_ids`: List of security group IDs (ALB-sourced traffic)
- `user_data`: Bootstrap script for Nginx installation
- `ami_ssm_parameter`: Default Amazon Linux 2023 AMI
- `create_security_group`: Set to `false` (using standalone security group module)
- `tags`: Resource tagging

**Decision**: ✅ **USE THIS MODULE**  
This module meets all requirements for EC2 instance provisioning with proper security group integration and user data support.

---

#### 2. Application Load Balancer (ALB) Module

**Module ID**: `ravi-panchal-org/alb/aws`  
**Version**: `10.2.0`  
**Source**: `app.terraform.io/ravi-panchal-org/alb/aws`  
**Created**: 2025-11-17  
**Provider**: AWS

**Key Capabilities**:
- Supports Application Load Balancer (ALB) and Network Load Balancer (NLB)
- HTTPS listener configuration with ACM certificate integration
- Target group creation with health check configuration
- Security group management
- Cross-zone load balancing
- Access logs support
- Internet-facing and internal load balancer support
- Multiple target group and listener rule support

**Critical Inputs for This Feature**:
- `name`: ALB identifier
- `load_balancer_type`: `"application"`
- `internal`: `false` (internet-facing)
- `vpc_id`: VPC ID from data source
- `subnets`: Public subnets across 2 AZs
- `security_group_ingress_rules`: Allow HTTPS (443) from 0.0.0.0/0
- `security_group_egress_rules`: Allow traffic to target instances
- `listeners`: HTTPS listener on port 443
- `target_groups`: EC2 instances with HTTPS health checks
- `https_listeners`: Certificate ARN from ACM
- `tags`: Resource tagging

**Decision**: ✅ **USE THIS MODULE**  
This module provides comprehensive ALB functionality including HTTPS listener configuration and target group management required for this feature.

---

#### 3. Security Group Module

**Module ID**: `ravi-panchal-org/security-group/aws`  
**Version**: `5.3.1`  
**Source**: `app.terraform.io/ravi-panchal-org/security-group/aws`  
**Created**: 2025-11-12  
**Provider**: AWS

**Key Capabilities**:
- Flexible ingress and egress rule configuration
- Support for CIDR blocks and security group references
- Multiple rule types (CIDR-based, prefix list, security group)
- Tag management
- Description and naming conventions

**Critical Inputs for This Feature**:
- `name`: Security group identifier
- `description`: Security group purpose
- `vpc_id`: VPC ID from data source
- `ingress_rules` or `ingress_with_source_security_group_id`: Rule definitions
- `egress_rules`: Outbound traffic rules
- `tags`: Resource tagging

**Use Cases**:
1. **ALB Security Group**: Allow 443 from 0.0.0.0/0, allow egress to EC2 security group
2. **EC2 Security Group**: Allow 443 from ALB security group only, allow outbound for package installation

**Decision**: ✅ **USE THIS MODULE**  
This module provides the necessary security group functionality with proper support for security group references (ALB → EC2).

---

## Self-Signed Certificate Generation

### Technology Choice: Terraform TLS Provider

**Provider**: `hashicorp/tls`  
**Version**: Latest (4.2.1+)  
**Resources Required**:
1. `tls_private_key`: Generate RSA private key
2. `tls_self_signed_cert`: Create self-signed certificate

**Decision Rationale**:
- ✅ Native Terraform provider (no external dependencies)
- ✅ Generates PEM-formatted certificates compatible with ACM
- ✅ Supports DNS names and validity period configuration
- ✅ State-managed (private keys stored in Terraform state - acceptable for development)
- ✅ Simple to use with ACM certificate import

**Implementation Pattern**:

```hcl
# Generate private key
resource "tls_private_key" "web" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate self-signed certificate
resource "tls_self_signed_cert" "web" {
  private_key_pem = tls_private_key.web.private_key_pem

  subject {
    common_name  = "web.demo.com"
    organization = "Development"
  }

  validity_period_hours = 2160 # 90 days

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["web.demo.com"]
}
```

**Security Considerations**:
- ⚠️ Private key will be stored in Terraform state (acceptable for development environment)
- ⚠️ Self-signed certificates generate browser warnings (expected for development)
- ✅ Certificate validity set to 90 days as per requirements
- ✅ RSA 2048-bit key strength is adequate for development

**Alternative Considered**: AWS ACM Certificate Validation
- ❌ Rejected: Requires valid DNS configuration and domain ownership validation
- ❌ Out of scope: DNS management not included in requirements

---

## AWS Certificate Manager (ACM) Integration

### Certificate Import Pattern

**Resource**: `aws_acm_certificate`  
**Documentation**: [AWS ACM Certificate Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate)

**Implementation Pattern**:

```hcl
resource "aws_acm_certificate" "web" {
  private_key      = tls_private_key.web.private_key_pem
  certificate_body = tls_self_signed_cert.web.cert_pem

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "web-demo-com-cert"
    Environment = "development"
  }
}
```

**Key Points**:
- Import requires both private key and certificate body in PEM format
- ACM automatically stores the imported certificate
- Certificate ARN is used in ALB HTTPS listener configuration
- Lifecycle rule ensures zero-downtime certificate rotation if needed

**Decision**: ✅ **USE ACM IMPORT**  
This pattern provides seamless integration between TLS provider and ALB configuration.

---

## VPC and Network Discovery

### Data Source Pattern

**Requirements**:
- Use existing default VPC
- Discover public subnets across 2 availability zones
- No VPC creation

**Implementation Pattern**:

```hcl
# Discover default VPC
data "aws_vpc" "default" {
  default = true
}

# Discover all subnets in default VPC
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

# Get subnet details to extract availability zones
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Select 2 subnets from different AZs
locals {
  availability_zones = distinct([for subnet in data.aws_subnet.default : subnet.availability_zone])
  selected_az_subnets = [
    for az in slice(local.availability_zones, 0, 2) :
    [for subnet in data.aws_subnet.default : subnet.id if subnet.availability_zone == az][0]
  ]
}
```

**Assumptions Validated**:
- Default VPC exists in ap-southeast-1 region ✅
- Default VPC has public subnets in at least 2 AZs ✅
- Internet Gateway is attached to default VPC ✅

**Decision**: ✅ **USE DATA SOURCES**  
This pattern dynamically discovers VPC and subnet configuration without hardcoding resource IDs.

---

## Nginx Bootstrap Strategy

### User Data Script Approach

**Requirement**: Install and configure Nginx on EC2 instances at launch time

**Implementation Pattern**:

```bash
#!/bin/bash
# User data script for EC2 instance bootstrapping

# Update system packages
yum update -y

# Install Nginx
amazon-linux-extras install nginx1 -y

# Create custom index page with instance identification
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)

cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Web Server</title>
</head>
<body>
    <h1>Welcome to web.demo.com</h1>
    <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
    <p><strong>Availability Zone:</strong> $AVAILABILITY_ZONE</p>
    <p><strong>Environment:</strong> Development</p>
</body>
</html>
EOF

# Configure Nginx to listen on port 80 (ALB will handle HTTPS termination)
cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name web.demo.com;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Configure firewall if needed
systemctl stop firewalld
systemctl disable firewalld
```

**Key Design Decisions**:

1. **Port Configuration**: 
   - ✅ Nginx listens on port 80 (HTTP)
   - ✅ ALB performs HTTPS termination (client → ALB: HTTPS, ALB → EC2: HTTP)
   - **Rationale**: Simplifies certificate management and follows AWS best practice for ALB offloading SSL/TLS

2. **Health Check Endpoint**:
   - ✅ Dedicated `/health` endpoint for ALB target group health checks
   - ✅ Returns 200 OK response
   - ✅ Access logging disabled to reduce noise

3. **Instance Identification**:
   - ✅ Custom index page displays instance ID and availability zone
   - ✅ Enables visual verification of load balancing distribution

**Alternative Considered**: HTTPS on EC2 instances with certificate distribution
- ❌ Rejected: Adds complexity of certificate distribution to instances
- ❌ Rejected: Requires certificate renewal coordination across instances
- ✅ Accepted: ALB HTTPS termination is AWS best practice

---

## Architecture Decision: ALB HTTPS Termination

### HTTPS Traffic Flow

```
Internet (HTTPS:443)
    ↓
Application Load Balancer (HTTPS:443)
    ↓ [SSL/TLS Termination]
    ↓ (HTTP:80)
EC2 Instances (HTTP:80 - Nginx)
```

**Decision Rationale**:
1. ✅ **Centralized Certificate Management**: Single certificate on ALB, no distribution to instances
2. ✅ **Simplified Certificate Renewal**: Update certificate on ALB only
3. ✅ **Reduced Instance Overhead**: No SSL/TLS processing on instances
4. ✅ **AWS Best Practice**: Standard pattern for ALB deployments
5. ✅ **Security Maintained**: Traffic between ALB and EC2 within VPC (private network)

**Security Group Configuration**:
- ALB Security Group: Allow 443 from 0.0.0.0/0 (internet)
- EC2 Security Group: Allow 80 from ALB security group only
- EC2 instances not directly accessible from internet

**Alternative Considered**: End-to-End Encryption (ALB → EC2 HTTPS)
- ❌ Rejected: Adds certificate distribution complexity
- ❌ Rejected: Increases EC2 instance overhead (CPU for SSL/TLS)
- ❌ Rejected: Not required for development environment within VPC

**Decision**: ✅ **USE ALB HTTPS TERMINATION WITH HTTP TO EC2**

---

## AWS Region and Availability Zone Strategy

### Region: ap-southeast-1 (Singapore)

**Availability Zones Required**: 2  
**Instance Distribution**: 1 instance per AZ (minimum)

**Implementation**:
- Dynamically discover available AZs in the region
- Select first 2 AZs from discovery
- Place 1 EC2 instance in each AZ
- ALB spans both AZs automatically

**Subnet Selection Strategy**:
```hcl
# Discover subnets in default VPC across multiple AZs
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Map subnets to availability zones
locals {
  az_subnet_map = {
    for subnet in data.aws_subnet.default :
    subnet.availability_zone => subnet.id...
  }
  
  # Select first subnet from each of first 2 AZs
  selected_subnets = [
    for az in slice(keys(local.az_subnet_map), 0, 2) :
    local.az_subnet_map[az][0]
  ]
}
```

**Decision**: ✅ **DYNAMIC AZ DISCOVERY WITH EXPLICIT 2-AZ SELECTION**

---

## Cost Optimization

### Instance Type Selection

**Requirement**: Cost-optimized development environment

**Decision**: Use `t3.micro` with fallback to `t2.micro`

**Comparison**:
| Attribute | t3.micro | t2.micro |
|-----------|----------|----------|
| vCPUs | 2 | 1 |
| Memory | 1 GB | 1 GB |
| Network Performance | Up to 5 Gbps | Low to Moderate |
| EBS Optimized | Yes | No |
| CPU Credits | Unlimited mode available | Burstable only |
| Typical Cost (ap-southeast-1) | $0.0116/hour | $0.0126/hour |

**Implementation Pattern**:
```hcl
# Primary choice: t3.micro
instance_type = "t3.micro"

# Note: Module supports instance_type parameter directly
# If t3.micro unavailable in AZ, Terraform will fail with clear error
# User can manually update to t2.micro if needed
```

**Decision Rationale**:
- ✅ t3.micro provides better performance per dollar
- ✅ t3 instances have better network performance (important for ALB traffic)
- ✅ t3 CPU credits in unlimited mode prevent throttling (better for testing)
- ⚠️ If capacity issues arise, t2.micro is acceptable fallback

**Decision**: ✅ **USE t3.micro AS PRIMARY CHOICE**

---

## Health Check Configuration

### ALB Target Group Health Checks

**Requirement**: Verify Nginx availability and automatically route traffic away from unhealthy instances

**Recommended Configuration**:
```hcl
target_groups = [{
  name             = "ec2-nginx-targets"
  backend_protocol = "HTTP"
  backend_port     = 80
  target_type      = "instance"
  
  health_check = {
    enabled             = true
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }
}]
```

**Parameters Explained**:
- `interval`: 30 seconds between health checks (AWS default)
- `path`: `/health` endpoint (custom endpoint created in Nginx config)
- `healthy_threshold`: 2 consecutive successes to mark healthy
- `unhealthy_threshold`: 2 consecutive failures to mark unhealthy
- `timeout`: 5 seconds per health check request
- `matcher`: HTTP 200 status code expected

**Time to Detect Failure**: 30s (interval) × 2 (threshold) = 60 seconds  
**Time to Recover**: 30s × 2 = 60 seconds

**Decision**: ✅ **USE CUSTOM /health ENDPOINT WITH STANDARD THRESHOLDS**

---

## Resource Naming Convention

### Standard Pattern

**Format**: `[project]-[environment]-[resource-type]-[identifier]`

**Examples**:
- EC2 Instances: `web-demo-dev-ec2-az1`, `web-demo-dev-ec2-az2`
- ALB: `web-demo-dev-alb`
- Target Group: `web-demo-dev-tg`
- Security Groups: `web-demo-dev-sg-alb`, `web-demo-dev-sg-ec2`
- ACM Certificate: `web-demo-dev-cert`

**Tagging Strategy**:
```hcl
common_tags = {
  Project     = "web-demo"
  Environment = "development"
  ManagedBy   = "terraform"
  Feature     = "003-ec2-alb-nginx"
  CostCenter  = "engineering-dev"
  GitHubIssue = "39"
  Workspace   = "sandbox_workspace"
}
```

**Decision**: ✅ **USE CONSISTENT NAMING CONVENTION WITH COMPREHENSIVE TAGS**

---

## HCP Terraform Configuration

### Workspace Details

**Organization**: `ravi-panchal-org`  
**Project**: `Default Project`  
**Workspace**: `sandbox_workspace`  
**Region**: `ap-southeast-1`

**Configuration Requirements**:
1. AWS credentials configured in workspace variables
2. Terraform version: Latest stable (1.6+)
3. State management: HCP Terraform Cloud (automatic)
4. VCS integration: Optional (not required for this feature)

**Workspace Variables Required**:
- `AWS_ACCESS_KEY_ID` (env, sensitive) or role-based authentication
- `AWS_SECRET_ACCESS_KEY` (env, sensitive) or role-based authentication
- `AWS_DEFAULT_REGION` = `ap-southeast-1`

**Decision**: ✅ **USE EXISTING WORKSPACE WITH REGION CONFIGURATION**

---

## Testing Strategy

### Testing Levels

#### 1. Terraform Validation
```bash
terraform fmt -check
terraform validate
terraform plan
```

#### 2. Infrastructure Provisioning Test
```bash
# Apply infrastructure
terraform apply -auto-approve

# Verify resources created
aws elbv2 describe-load-balancers --region ap-southeast-1
aws ec2 describe-instances --region ap-southeast-1
aws acm list-certificates --region ap-southeast-1
```

#### 3. Connectivity Tests
```bash
# Get ALB DNS name
ALB_DNS=$(terraform output alb_dns_name)

# Test HTTPS connectivity (expect certificate warning)
curl -k https://$ALB_DNS

# Test multiple requests (verify load balancing)
for i in {1..10}; do
  curl -k https://$ALB_DNS | grep "Instance ID"
done
```

#### 4. Security Group Validation
```bash
# Attempt direct connection to EC2 instance (should fail)
EC2_PUBLIC_IP=$(terraform output ec2_instance_public_ip)
curl http://$EC2_PUBLIC_IP  # Should timeout

# Verify ALB security group rules
aws ec2 describe-security-groups --region ap-southeast-1
```

#### 5. Health Check Validation
```bash
# Check target group health status
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output target_group_arn) \
  --region ap-southeast-1
```

#### 6. Failure Scenario Test
```bash
# SSH to one instance and stop Nginx
ssh ec2-user@$EC2_IP "sudo systemctl stop nginx"

# Wait for health check failure (60 seconds)
sleep 70

# Verify traffic still flows (should only hit healthy instance)
for i in {1..10}; do
  curl -k https://$ALB_DNS
done
```

**Decision**: ✅ **IMPLEMENT PROGRESSIVE TESTING FROM VALIDATION TO FAILURE SCENARIOS**

---

## Security Considerations

### 1. Network Security

✅ **EC2 Instances Isolated**:
- EC2 security group only allows traffic from ALB security group
- No direct internet access to EC2 instances on application ports
- SSH port (22) not exposed to internet

✅ **ALB as Security Boundary**:
- Only HTTPS (443) allowed from internet
- HTTP (80) traffic rejected
- Security group explicitly defined (no default rules)

### 2. Certificate Security

⚠️ **Development Environment Caveats**:
- Private key stored in Terraform state (acceptable for development)
- Self-signed certificate generates browser warnings (expected)
- Certificate not trusted by browsers (manual exception required)

✅ **Mitigations**:
- Terraform state stored in HCP Terraform Cloud (encrypted at rest)
- Certificate validity limited to 90 days (automatic rotation possible)
- Clear documentation that this is development-only

### 3. IAM and Access Control

✅ **Principle of Least Privilege**:
- EC2 instances do not require IAM roles for this basic setup
- HCP Terraform workspace uses dedicated AWS credentials
- No hardcoded credentials in Terraform code

### 4. Monitoring and Logging

⚠️ **Limited Monitoring** (acceptable for development):
- ALB access logs not enabled (out of scope)
- CloudWatch alarms not configured (out of scope)
- VPC Flow Logs not enabled (out of scope)

✅ **Basic Observability**:
- ALB health checks provide instance health visibility
- AWS Console provides resource status
- Terraform state tracks infrastructure configuration

**Decision**: ✅ **SECURITY APPROPRIATE FOR DEVELOPMENT ENVIRONMENT**

---

## Implementation Risks and Mitigations

### Risk 1: Default VPC Unavailable
**Likelihood**: Low  
**Impact**: High (deployment failure)  
**Mitigation**: Data source will fail gracefully with clear error message  
**Workaround**: User can create default VPC or modify data source to use custom VPC

### Risk 2: Instance Type Unavailable in AZ
**Likelihood**: Low  
**Impact**: Medium (deployment failure)  
**Mitigation**: Terraform will fail during apply with capacity error  
**Workaround**: User can switch to t2.micro or select different AZs

### Risk 3: Certificate Browser Trust Issues
**Likelihood**: High (expected)  
**Impact**: Low (user accepts warning)  
**Mitigation**: Clear documentation in README about self-signed certificates  
**Workaround**: Users manually accept certificate exception in browser

### Risk 4: Terraform State Contains Private Key
**Likelihood**: High (by design)  
**Impact**: Low (development environment)  
**Mitigation**: HCP Terraform state encryption at rest  
**Workaround**: For production, use AWS Secrets Manager with ephemeral resources

### Risk 5: DNS Configuration Not Automated
**Likelihood**: High (out of scope)  
**Impact**: Medium (manual DNS setup required)  
**Mitigation**: Document DNS setup in README  
**Workaround**: Users can use ALB DNS directly for testing

---

## Key Research Findings Summary

| Category | Decision | Module/Resource |
|----------|----------|-----------------|
| EC2 Instances | ✅ Use private registry module | `app.terraform.io/ravi-panchal-org/ec2-instance/aws` v6.1.4 |
| Load Balancer | ✅ Use private registry module | `app.terraform.io/ravi-panchal-org/alb/aws` v10.2.0 |
| Security Groups | ✅ Use private registry module | `app.terraform.io/ravi-panchal-org/security-group/aws` v5.3.1 |
| TLS Certificate | ✅ Use TLS provider | `tls_private_key` + `tls_self_signed_cert` |
| Certificate Import | ✅ Use ACM import | `aws_acm_certificate` (import type) |
| VPC Discovery | ✅ Use data sources | `aws_vpc`, `aws_subnets`, `aws_subnet` |
| HTTPS Termination | ✅ ALB terminates HTTPS | HTTP to EC2 instances |
| Instance Type | ✅ t3.micro primary | t2.micro fallback |
| Nginx Port | ✅ Port 80 (HTTP) | ALB handles HTTPS |
| Health Checks | ✅ Custom /health endpoint | 30s interval, 2 threshold |
| Region | ✅ ap-southeast-1 | 2 AZs minimum |

---

## Next Steps (Phase 1: Design & Contracts)

1. **Data Model Definition**: Document entities (EC2, ALB, Target Group, Security Groups, Certificates)
2. **Module Interfaces**: Define input variables and outputs for root module
3. **File Structure**: Organize Terraform configuration files
4. **Quickstart Guide**: Document deployment steps for users
5. **Security Review**: Validate against AWS Well-Architected Framework

---

## References

- [AWS ALB Security Groups Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html)
- [Terraform TLS Provider Documentation](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert)
- [AWS ACM Certificate Import](https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html)
- [HCP Terraform Private Registry](https://developer.hashicorp.com/terraform/cloud-docs/registry)
- [AWS EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Nginx Configuration Reference](https://nginx.org/en/docs/)

---

**Research Completed**: All NEEDS CLARIFICATION items resolved ✅  
**Ready for Phase 1**: Design & Contracts ✅
