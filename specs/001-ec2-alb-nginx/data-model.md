# Data Model: EC2 ALB Nginx Infrastructure

**Feature**: EC2 ALB Nginx Development Environment  
**Branch**: 001-ec2-alb-nginx  
**Date**: 2025-01-29

---

## Overview

This data model defines the infrastructure entities, their attributes, relationships, and state transitions for the EC2 ALB Nginx development environment. The model represents AWS infrastructure resources managed through Terraform with private registry modules.

---

## Core Entities

### 1. Application Load Balancer (ALB)

**Description**: Internet-facing load balancer distributing HTTPS traffic across EC2 instances in multiple availability zones.

**Attributes**:
```yaml
entity: application_load_balancer
properties:
  name: string                          # Format: {environment}-alb-nginx
  arn: string                           # AWS Resource Name (read-only)
  dns_name: string                      # Public DNS endpoint (read-only)
  load_balancer_type: string            # Fixed: "application"
  scheme: string                        # Fixed: "internet-facing"
  vpc_id: string                        # Reference to default VPC
  subnet_ids: list<string>              # List of subnet IDs (multi-AZ)
  security_group_id: string             # Reference to ALB security group
  
relationships:
  - target_group: one-to-many          # References target groups
  - listeners: one-to-many             # HTTP and HTTPS listeners
  - security_group: many-to-one        # Ingress/egress rules
  
validation_rules:
  - name: max_length: 32, alphanumeric and hyphens only
  - subnet_ids: minimum: 2 (multi-AZ requirement)
  - scheme: must be "internet-facing" per FR-003
```

**Module Source**: `app.terraform.io/ravi-panchal-org/alb/aws` v10.2.0

### 2. EC2 Instance

**Description**: Compute resource running Nginx web server, deployed in a specific availability zone.

**Attributes**:
```yaml
entity: ec2_instance
properties:
  instance_id: string                   # Format: i-xxxxxxxxxxxxxxxxx
  name: string                          # Format: {environment}-ec2-nginx-{az}
  ami_id: string                        # Amazon Linux 2023 (from SSM)
  instance_type: string                 # t3.micro or t3.small
  subnet_id: string                     # Reference to subnet
  availability_zone: string             # ap-southeast-1a or 1b
  private_ip_address: string            # VPC internal IP
  iam_instance_profile: string          # Reference to instance profile
  user_data: string                     # Nginx installation script
  
relationships:
  - subnet: many-to-one                # Deployed in subnet
  - security_group: many-to-one        # Network access control
  - iam_role: many-to-one              # Permissions
  - target_group: many-to-many         # Load balancer registration
  
validation_rules:
  - instance_type: must be t3.micro or t3.small per FR-002
  - availability_zone: must be ap-southeast-1a or 1b per FR-007
  - key_name: must be null (no SSH) per FR-014
```

**Module Source**: `app.terraform.io/ravi-panchal-org/ec2-instance/aws` v6.1.4

### 3. Security Group

**Description**: Stateful firewall controlling inbound and outbound network traffic.

**ALB Security Group Rules**:
```yaml
security_group: alb_sg
ingress:
  - from_port: 80
    to_port: 80
    protocol: tcp
    cidr_ipv4: 0.0.0.0/0
  - from_port: 443
    to_port: 443
    protocol: tcp
    cidr_ipv4: 0.0.0.0/0
egress:
  - protocol: -1
    cidr_ipv4: 0.0.0.0/0
```

**EC2 Security Group Rules**:
```yaml
security_group: ec2_sg
ingress:
  - from_port: 80
    to_port: 80
    protocol: tcp
    source_security_group_id: ${alb_security_group_id}
egress:
  - protocol: -1
    cidr_ipv4: 0.0.0.0/0
```

### 4. IAM Role

**Description**: Identity granting EC2 instances permissions for Systems Manager Session Manager.

**Attributes**:
```yaml
entity: iam_role
properties:
  name: string
  arn: string
  attached_policies: 
    - "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
```

### 5. ACM Certificate

**Description**: SSL/TLS certificate for HTTPS listener (self-signed for development).

**Attributes**:
```yaml
entity: acm_certificate
properties:
  arn: string
  domain_name: string                   # *.elb.amazonaws.com
  type: string                          # IMPORTED (self-signed)
  status: string                        # ISSUED
```

---

## Entity Relationship Diagram

```
┌────────────────────────────────────────────┐
│         VPC (Default)                      │
│  ┌──────────────────────────────────────┐ │
│  │  Application Load Balancer           │ │
│  │  ├─ HTTP Listener (80) → Redirect    │ │
│  │  └─ HTTPS Listener (443) → Forward   │ │
│  └──────────────┬───────────────────────┘ │
│                 │                          │
│         ┌───────▼──────────┐              │
│         │  Target Group    │              │
│         └───────┬──────────┘              │
│                 │                          │
│      ┌──────────┴──────────┐              │
│      │                     │              │
│  ┌───▼─────────┐  ┌────────▼────┐        │
│  │ EC2 (1a)    │  │ EC2 (1b)    │        │
│  │ - Nginx     │  │ - Nginx     │        │
│  │ - IAM Role  │  │ - IAM Role  │        │
│  └─────────────┘  └─────────────┘        │
└────────────────────────────────────────────┘
```

---

## Cost Model

**Monthly Cost Breakdown** (24/7, ap-southeast-1):

| Component | Quantity | Unit Cost | Monthly Cost |
|-----------|----------|-----------|--------------|
| EC2 t3.micro | 2 | $0.0104/hour | $15.18 |
| ALB | 1 | $0.0252/hour | $18.40 |
| ALB LCU | 0.25 estimated | $0.008/LCU-hour | $1.46 |
| Data Transfer | 10 GB | $0.12/GB | $1.20 |
| ACM Certificate | 1 | Free | $0.00 |
| **Total** | | | **$36.24** |

---

**End of Data Model**
