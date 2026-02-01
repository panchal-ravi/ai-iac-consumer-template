# Data Model: EC2 Infrastructure with ALB and Nginx

**Feature**: 002-ec2-alb-nginx  
**Date**: 2025-02-01  
**Phase**: 1 - Design & Contracts

## Overview

This document defines the infrastructure entities, their relationships, and state management for the EC2 ALB Nginx feature. In Terraform terms, these entities map to resources, modules, and data sources.

---

## Entity Definitions

### 1. VPC Context (Data Source)

**Purpose**: Discover existing default VPC and subnets for resource placement

**Terraform Representation**: Data sources
```hcl
data "aws_vpc" "default"
data "aws_subnets" "default"
data "aws_subnet" "az"
```

**Attributes**:
| Attribute | Type | Description | Source |
|-----------|------|-------------|--------|
| vpc_id | string | Default VPC ID | `data.aws_vpc.default.id` |
| subnet_ids | list(string) | Subnet IDs in target AZs | `data.aws_subnets.default.ids` |
| cidr_block | string | VPC CIDR range | `data.aws_vpc.default.cidr_block` |
| availability_zones | list(string) | Target AZs | `["ap-southeast-1a", "ap-southeast-1b"]` |

**Relationships**:
- Provides network context for: Security Groups, ALB, EC2 Instances
- No lifecycle dependencies (data source, read-only)

**Validation Rules**:
- Default VPC must exist in ap-southeast-1 region
- At least 2 subnets must be available in specified AZs
- Subnets must be in different availability zones

**State Management**:
- No Terraform state (data source)
- Read on every plan/apply
- Changes if default VPC configuration modified externally

---

### 2. TLS Certificate (Self-Signed)

**Purpose**: Generate self-signed TLS certificate for HTTPS termination

**Terraform Representation**: Resources
```hcl
resource "tls_private_key" "self_signed"
resource "tls_self_signed_cert" "self_signed"
resource "aws_acm_certificate" "self_signed"
```

**Attributes**:
| Attribute | Type | Description | Required | Default |
|-----------|------|-------------|----------|---------|
| common_name | string | Certificate domain name | Yes | "web.demo.com" |
| organization | string | Organization name | Yes | var.organization |
| algorithm | string | Key algorithm | Yes | "RSA" |
| rsa_bits | number | Key size | Yes | 2048 |
| validity_period_hours | number | Certificate validity | Yes | 8760 (1 year) |
| private_key_pem | string (sensitive) | Private key | Generated | - |
| cert_pem | string | Certificate body | Generated | - |
| certificate_arn | string | ACM certificate ARN | Generated | - |

**Relationships**:
- **Consumed by**: ALB HTTPS Listener (certificate_arn)
- **Created before**: ALB (explicit dependency)

**Validation Rules**:
- RSA key size >= 2048 bits
- Validity period > 0 hours
- Common name matches expected domain pattern

**State Management**:
- Stored in Terraform state (encrypted in HCP Terraform)
- Private key marked as sensitive (not displayed in outputs)
- Changing any attribute forces recreation of all certificate resources
- ACM certificate persists until Terraform destroy

**Security Considerations**:
- Private key stored in encrypted remote state only
- No local state file
- Certificate not trusted by browsers (self-signed) - expected for demo
- Suitable for development only, not production

---

### 3. Security Groups

**Purpose**: Control network access to ALB and EC2 instances using least privilege

**Terraform Representation**: Modules
```hcl
module "alb_security_group"
module "ec2_security_group"
```

#### 3.1 ALB Security Group

**Attributes**:
| Attribute | Type | Description | Required | Default |
|-----------|------|-------------|----------|---------|
| name | string | Security group name | Yes | "${var.project_name}-alb-sg" |
| description | string | Purpose description | Yes | "Security group for ALB" |
| vpc_id | string | VPC ID | Yes | data.aws_vpc.default.id |
| security_group_id | string | Generated SG ID | Output | - |

**Ingress Rules**:
| Rule | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| https_from_internet | tcp | 443 | 0.0.0.0/0 | HTTPS from internet (FR-009) |

**Egress Rules**:
| Rule | Protocol | Port | Destination | Description |
|------|----------|------|-------------|-------------|
| http_to_instances | tcp | 80 | EC2 Security Group | HTTP to instances (FR-010) |

#### 3.2 EC2 Security Group

**Attributes**:
| Attribute | Type | Description | Required | Default |
|-----------|------|-------------|----------|---------|
| name | string | Security group name | Yes | "${var.project_name}-ec2-sg" |
| description | string | Purpose description | Yes | "Security group for EC2" |
| vpc_id | string | VPC ID | Yes | data.aws_vpc.default.id |
| security_group_id | string | Generated SG ID | Output | - |

**Ingress Rules**:
| Rule | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| http_from_alb | tcp | 80 | ALB Security Group | HTTP from ALB only (FR-011) |

**Egress Rules**:
| Rule | Protocol | Port | Destination | Description |
|------|----------|------|-------------|-------------|
| all_outbound | all | all | 0.0.0.0/0 | Outbound for updates |

**Relationships**:
- **Created before**: EC2 Instances, ALB
- **References**: VPC (data source)
- **Circular dependency**: ALB SG references EC2 SG in egress, EC2 SG references ALB SG in ingress (Terraform handles this correctly)

**Validation Rules**:
- VPC must exist
- No conflicting rules
- Port ranges valid (0-65535)

**State Management**:
- Managed by security-group module
- Changes to rules may cause brief connectivity interruption
- Deleting security group requires removing all attachments first

---

### 4. EC2 Instances

**Purpose**: Compute resources running Nginx web server

**Terraform Representation**: Modules (one per AZ using for_each)
```hcl
module "ec2_instance" {
  for_each = toset(local.availability_zones)
  ...
}
```

**Attributes**:
| Attribute | Type | Description | Required | Default |
|-----------|------|-------------|----------|---------|
| name | string | Instance name | Yes | "${var.project_name}-${az}" |
| instance_type | string | Instance size | Yes | var.instance_type ("t3a.micro") |
| availability_zone | string | AZ placement | Yes | each.key (from for_each) |
| subnet_id | string | Subnet for placement | Yes | data.aws_subnet.az[each.key].id |
| ami | string | Amazon Machine Image | No | Module default (Amazon Linux 2023) |
| user_data | string | Initialization script | Yes | Nginx installation script |
| vpc_security_group_ids | list(string) | Security groups | Yes | [ec2_sg.id] |
| iam_instance_profile | string | IAM role | Yes | Created by module |
| associate_public_ip_address | bool | Public IP assignment | Yes | true |
| instance_id | string | Generated instance ID | Output | - |
| private_ip | string | Private IP address | Output | - |
| availability_zone | string | Actual AZ | Output | - |

**User Data Script** (FR-006, FR-007):
```bash
#!/bin/bash
yum update -y
yum install -y nginx
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>EC2 ALB Demo</title></head>
<body>
  <h1>Welcome to EC2 ALB Nginx Demo</h1>
  <p>Instance: $(ec2-metadata --instance-id | cut -d' ' -f2)</p>
  <p>Availability Zone: $(ec2-metadata --availability-zone | cut -d' ' -f2)</p>
</body>
</html>
EOF
systemctl enable nginx
systemctl start nginx
```

**Relationships**:
- **Depends on**: EC2 Security Group (must exist first)
- **Referenced by**: ALB Target Group
- **Network**: Placed in VPC subnets (data source)

**Validation Rules**:
- Instance type valid for region
- AMI compatible with instance type
- Subnet in specified availability zone
- Security group in same VPC as subnet

**State Management**:
- Each instance tracked independently in Terraform state (for_each creates separate state entries)
- Terminating instance triggers recreation
- User data changes force instance replacement
- Preserve instance IDs in outputs for debugging

**High Availability**:
- 2 instances created (1 per AZ)
- Independent state: can manage/replace individually
- ALB health checks determine instance availability
- Service continues if 1 instance fails (FR-002, SC-003)

---

### 5. Application Load Balancer (ALB)

**Purpose**: Distribute HTTPS traffic across healthy EC2 instances

**Terraform Representation**: Module
```hcl
module "alb"
```

**Attributes**:
| Attribute | Type | Description | Required | Default |
|-----------|------|-------------|----------|---------|
| name | string | ALB name | Yes | "${var.project_name}-alb" |
| internal | bool | Internal vs public | Yes | false |
| load_balancer_type | string | ALB vs NLB | Yes | "application" |
| security_groups | list(string) | Security groups | Yes | [alb_sg.id] |
| subnets | list(string) | Subnet placement | Yes | All AZ subnets |
| enable_deletion_protection | bool | Deletion protection | Yes | false (dev) |
| enable_http2 | bool | HTTP/2 support | Yes | true |
| idle_timeout | number | Idle timeout seconds | Yes | 60 |
| dns_name | string | ALB DNS name | Output | - |
| arn | string | ALB ARN | Output | - |
| zone_id | string | Route53 zone ID | Output | - |

**HTTPS Listener**:
| Attribute | Type | Description | Required | Default |
|-----------|------|-------------|----------|---------|
| port | number | Listener port | Yes | 443 |
| protocol | string | Listener protocol | Yes | "HTTPS" |
| ssl_policy | string | TLS policy | Yes | "ELBSecurityPolicy-TLS13-1-2-2021-06" |
| certificate_arn | string | ACM certificate | Yes | aws_acm_certificate.self_signed.arn |
| default_action | object | Routing action | Yes | forward to target group |

**Target Group**:
| Attribute | Type | Description | Required | Default |
|-----------|------|-------------|----------|---------|
| name | string | Target group name | Yes | "${var.project_name}-tg" |
| port | number | Target port | Yes | 80 |
| protocol | string | Target protocol | Yes | "HTTP" |
| vpc_id | string | VPC ID | Yes | data.aws_vpc.default.id |
| deregistration_delay | number | Drain time seconds | Yes | 30 |
| target_type | string | Target type | Yes | "instance" |

**Health Check** (FR-013):
| Attribute | Type | Description | Required | Default |
|-----------|------|-------------|----------|---------|
| enabled | bool | Health check enabled | Yes | true |
| path | string | Health check path | Yes | "/" |
| protocol | string | Health check protocol | Yes | "HTTP" |
| port | string | Health check port | Yes | "traffic-port" (80) |
| healthy_threshold | number | Healthy count | Yes | 2 |
| unhealthy_threshold | number | Unhealthy count | Yes | 2 |
| timeout | number | Timeout seconds | Yes | 5 |
| interval | number | Check interval seconds | Yes | 30 |
| matcher | string | Success codes | Yes | "200" |

**Target Attachments**:
```hcl
# Automatically created by module from instance IDs
targets = [
  for instance in module.ec2_instance : {
    target_id = instance.id
    port      = 80
  }
]
```

**Relationships**:
- **Depends on**: ALB Security Group, TLS Certificate, EC2 Instances
- **References**: VPC (data source), Subnets (data source)
- **Exposes**: DNS name for HTTPS access

**Validation Rules**:
- At least 2 subnets in different AZs
- Security group allows port 443 inbound
- Certificate ARN valid and in same region
- Target instances exist and are in VPC subnets

**State Management**:
- ALB persists until Terraform destroy
- DNS name changes if ALB recreated
- Target attachments update when instances change
- Listener certificate can be updated without ALB recreation

**Traffic Flow**:
```
Internet → HTTPS:443 → ALB Listener (TLS termination)
         → Target Group → HTTP:80 → EC2 Instance (Nginx)
```

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Region: ap-southeast-1             │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                      Default VPC (Data Source)             │ │
│  │                                                            │ │
│  │  ┌────────────────────────┐  ┌────────────────────────┐  │ │
│  │  │  ap-southeast-1a       │  │  ap-southeast-1b       │  │ │
│  │  │  Subnet (Data Source)  │  │  Subnet (Data Source)  │  │ │
│  │  │                        │  │                        │  │ │
│  │  │  ┌──────────────────┐  │  │  ┌──────────────────┐  │  │ │
│  │  │  │ EC2 Instance 1   │  │  │  │ EC2 Instance 2   │  │  │ │
│  │  │  │ - Nginx          │  │  │  │ - Nginx          │  │  │ │
│  │  │  │ - Private IP     │  │  │  │ - Private IP     │  │  │ │
│  │  │  │ - Port 80        │  │  │  │ - Port 80        │  │  │ │
│  │  │  └────────┬─────────┘  │  │  └────────┬─────────┘  │  │ │
│  │  │           │            │  │           │            │  │ │
│  │  └───────────┼────────────┘  └───────────┼────────────┘  │ │
│  │              │                           │                │ │
│  │              │  ┌────────────────────────┘                │ │
│  │              │  │                                         │ │
│  │              └──┼─────────────────────────────────────────┼─┤
│  │                 │        Target Group                     │ │
│  │                 │        - Port: 80                       │ │
│  │                 │        - Protocol: HTTP                 │ │
│  │                 │        - Health Check: /                │ │
│  │                 └─────────────┬───────────────────────────┘ │
│  │                               │                             │ │
│  │                 ┌─────────────┴───────────────────────────┐ │
│  │                 │  Application Load Balancer              │ │
│  │                 │  - HTTPS Listener (Port 443)            │ │
│  │                 │  - TLS Termination                      │ │
│  │                 │  - Cross-Zone Load Balancing            │ │
│  │                 │  - DNS: xxx.ap-southeast-1.elb.amazonaws│ │
│  │                 └─────────────┬───────────────────────────┘ │
│  └───────────────────────────────┼─────────────────────────────┘ │
│                                  │                               │
└──────────────────────────────────┼───────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │  HTTPS Traffic from Internet │
                    │  (0.0.0.0/0:443)            │
                    └─────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Security Architecture                      │
│                                                                 │
│  ┌──────────────────────────┐                                  │
│  │  ALB Security Group      │                                  │
│  │  Ingress: 0.0.0.0/0:443  │                                  │
│  │  Egress: EC2-SG:80       │                                  │
│  └────────────┬─────────────┘                                  │
│               │                                                 │
│               │ (port 80)                                       │
│               │                                                 │
│               ▼                                                 │
│  ┌──────────────────────────┐                                  │
│  │  EC2 Security Group      │                                  │
│  │  Ingress: ALB-SG:80      │                                  │
│  │  Egress: 0.0.0.0/0:all   │                                  │
│  └──────────────────────────┘                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   Certificate Management                        │
│                                                                 │
│  ┌────────────────────┐                                        │
│  │ TLS Private Key    │                                        │
│  │ (RSA 2048-bit)     │                                        │
│  └─────────┬──────────┘                                        │
│            │                                                    │
│            ▼                                                    │
│  ┌────────────────────┐                                        │
│  │ Self-Signed Cert   │                                        │
│  │ CN: web.demo.com   │                                        │
│  │ Valid: 1 year      │                                        │
│  └─────────┬──────────┘                                        │
│            │                                                    │
│            ▼                                                    │
│  ┌────────────────────┐                                        │
│  │ ACM Certificate    │                                        │
│  │ ARN: arn:aws:...   │─────────────────► Used by ALB Listener│
│  └────────────────────┘                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Resource Dependencies

**Creation Order** (Terraform manages automatically via implicit dependencies):

1. **Data Sources** (no dependencies)
   - VPC Discovery
   - Subnet Discovery

2. **TLS Resources** (no dependencies)
   - TLS Private Key
   - Self-Signed Certificate
   - ACM Certificate Import

3. **Security Groups** (depends on VPC data source)
   - ALB Security Group
   - EC2 Security Group

4. **EC2 Instances** (depends on security groups, subnets)
   - EC2 Instance in ap-southeast-1a
   - EC2 Instance in ap-southeast-1b

5. **Load Balancer** (depends on security groups, subnets, certificate, instances)
   - ALB
   - Target Group
   - HTTPS Listener
   - Target Attachments

**Destruction Order** (reverse of creation):
1. Load Balancer components
2. EC2 Instances
3. Security Groups
4. TLS/ACM Certificate resources

---

## State Transitions

### Normal Operation States

```
[Planned] → [Creating] → [Healthy] → [Destroying] → [Destroyed]
```

### EC2 Instance States
- `pending` → Initial launch
- `running` → Instance operational
- `stopping` → Shutdown initiated
- `stopped` → Instance halted
- `terminating` → Destruction in progress
- `terminated` → Instance removed

### ALB Target States
- `initial` → Target registered
- `healthy` → Passing health checks (FR-013)
- `unhealthy` → Failing health checks
- `draining` → Deregistration in progress (30s delay)
- `unused` → Not registered

### Certificate States
- `PENDING_VALIDATION` → Not applicable (self-signed, no validation)
- `ISSUED` → Certificate available in ACM (FR-004)
- `INACTIVE` → Certificate expired or revoked
- `EXPIRED` → Past validity period
- `VALIDATION_TIMED_OUT` → Not applicable

---

## Validation Rules Summary

| Entity | Validation | Error Handling |
|--------|------------|----------------|
| VPC | Default VPC exists | Fail deployment with clear message |
| Subnets | 2+ subnets in different AZs | Fail if insufficient AZs |
| Certificate | Valid for 1 year, RSA 2048+ | Terraform validation |
| Security Groups | No conflicting rules | Terraform dependency graph |
| EC2 Instances | Instance type valid for region | AWS API validation |
| ALB | Certificate in same region | AWS API validation |
| Health Checks | Instances respond HTTP 200 on / | Mark unhealthy, remove from rotation |

---

## Performance Characteristics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Initial Deployment | < 10 minutes | Terraform apply completion |
| Instance Healthy | < 5 minutes | ALB target health check (SC-008) |
| HTTPS Response | < 500ms | curl timing to ALB DNS |
| Health Check Interval | 30 seconds | ALB configuration |
| Failover Time | < 1 minute | Time to mark instance unhealthy + drain |
| Single Instance Failure | Zero downtime | ALB routes to healthy instance (SC-003) |

---

## Cost Tracking Tags

All entities tagged with:
```hcl
{
  Environment      = "development"
  Project          = "nginx-alb"
  Feature          = "002-ec2-alb-nginx"
  ManagedBy        = "terraform"
  Workspace        = "sandbox_workspace"
  CostCenter       = "development"
  CostOptimization = "minimal"
}
```

Enables AWS Cost Explorer filtering by Feature tag for cost tracking (SC-007).

---

**Data Model Complete**: All entities defined with attributes, relationships, validation rules, and state management. Ready for contract generation and implementation.
