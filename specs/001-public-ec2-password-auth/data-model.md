# Data Model: Public EC2 Instance with Password Authentication

**Feature**: Public EC2 Instance with Password Authentication  
**Date**: 2025-01-21  
**Branch**: `001-public-ec2-password-auth`

---

## Overview

This document defines the data model and entity relationships for the public EC2 instance infrastructure. All entities are implemented using Terraform resources and private registry modules per the constitution requirements.

---

## Entity Relationship Diagram

```
┌─────────────────┐
│   HCP Terraform │
│    Workspace    │
└────────┬────────┘
         │ manages
         ▼
┌─────────────────────────────────────────────────────────────┐
│                     AWS Infrastructure                       │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐                    │
│  │     VPC      │◄─────┤ Default VPC  │                    │
│  │  (Fallback)  │      │   Check      │                    │
│  └──────┬───────┘      └──────────────┘                    │
│         │                                                    │
│         │ contains                                          │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │    Public    │                                           │
│  │    Subnet    │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         │ hosts                                             │
│         ▼                                                    │
│  ┌──────────────────┐          ┌─────────────────┐         │
│  │  EC2 Instance    │◄─────────┤  Security Group │         │
│  │   (t3.micro)     │ protects │   (SSH: 22)     │         │
│  └────┬─────┬───────┘          └─────────────────┘         │
│       │     │                                               │
│       │     └──────┐                                        │
│       │            │                                        │
│       │            ▼                                        │
│       │     ┌──────────────┐                               │
│       │     │  Elastic IP  │                               │
│       │     │   (Public)   │                               │
│       │     └──────────────┘                               │
│       │                                                     │
│       │ has                                                │
│       ▼                                                     │
│  ┌──────────────────┐          ┌─────────────────┐        │
│  │ IAM Instance     │◄─────────┤   IAM Role      │        │
│  │    Profile       │ contains │                 │        │
│  └──────────────────┘          └────────┬────────┘        │
│                                          │                 │
│                                          │ attached        │
│                                          ▼                 │
│                                 ┌────────────────────┐    │
│                                 │  CloudWatch Agent  │    │
│                                 │      Policy        │    │
│                                 └──────────┬─────────┘    │
│                                            │              │
│       ┌────────────────────────────────────┘              │
│       │ writes logs to                                    │
│       ▼                                                    │
│  ┌──────────────────┐                                     │
│  │  CloudWatch Logs │                                     │
│  │   /aws/ec2/ssh   │                                     │
│  │      -auth       │                                     │
│  └──────────────────┘                                     │
│                                                            │
│  ┌──────────────────┐                                     │
│  │ Random Password  │                                     │
│  │   (20 chars)     │                                     │
│  └──────────────────┘                                     │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Core Entities

### 1. EC2 Instance

**Description**: The primary compute resource running Ubuntu 22.04 LTS.

**Module Source**: `app.terraform.io/ravi-panchal-org/ec2-instance/aws`

**Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| instance_id | String (computed) | Unique AWS instance identifier | Format: `i-[a-f0-9]{17}` |
| instance_type | String | Instance size specification | Must be: `t3.micro` |
| ami | String | Ubuntu 22.04 LTS AMI ID | Dynamically looked up |
| public_ip | String (computed) | Elastic IP address | IPv4 format |
| private_ip | String (computed) | VPC private IP | RFC1918 range |
| instance_state | String (computed) | Current instance state | Enum: running, stopped, terminated |
| availability_zone | String | Placement AZ | Within ap-southeast-1 |
| subnet_id | String | Subnet placement | Must be public subnet |
| vpc_id | String | VPC identifier | Default or custom VPC |
| root_volume_id | String (computed) | EBS root volume ID | Format: `vol-[a-f0-9]{17}` |
| root_volume_size | Number | Root volume size in GB | Range: 8-20 GB |
| root_volume_type | String | EBS volume type | Must be: `gp3` |
| user_data | String | Initialization script | Base64 encoded |
| iam_instance_profile | String | IAM profile name | Links to CloudWatch permissions |
| tags | Map(String) | Resource tags | Must include: Name, Environment |

**State Transitions**:
```
[pending] → [running] → [stopping] → [stopped] → [running]
                    ↓
            [shutting-down] → [terminated]
```

**Relationships**:
- BELONGS_TO: One VPC
- BELONGS_TO: One Subnet
- PROTECTED_BY: One Security Group
- HAS_ONE: IAM Instance Profile
- HAS_ONE: Elastic IP
- HAS_ONE: Root EBS Volume
- GENERATES: CloudWatch Logs

**Validation Rules**:
- Instance type MUST be `t3.micro` (cost constraint)
- AMI MUST be Ubuntu 22.04 LTS (latest)
- Subnet MUST have public IP assignment enabled
- User-data MUST configure password authentication
- Tags MUST include: `Name`, `Environment`, `ManagedBy: Terraform`

---

### 2. Security Group

**Description**: Virtual firewall controlling network traffic to the instance.

**Module Source**: `app.terraform.io/ravi-panchal-org/security-group/aws` (or integrated in EC2 module)

**Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| security_group_id | String (computed) | Unique SG identifier | Format: `sg-[a-f0-9]{17}` |
| name | String | Security group name | Must be unique in VPC |
| description | String | Purpose description | Required |
| vpc_id | String | Associated VPC | Must exist |
| ingress_rules | List(Object) | Inbound rules | See schema below |
| egress_rules | List(Object) | Outbound rules | See schema below |

**Ingress Rules Schema**:
```hcl
{
  rule_name    = string  # e.g., "allow_ssh"
  from_port    = number  # e.g., 22
  to_port      = number  # e.g., 22
  protocol     = string  # e.g., "tcp"
  cidr_blocks  = list(string)  # e.g., ["0.0.0.0/0"]
  description  = string  # e.g., "Allow SSH from anywhere"
}
```

**Required Ingress Rules**:
1. **SSH Access**:
   - Port: 22
   - Protocol: TCP
   - CIDR: `0.0.0.0/0`
   - Description: "SSH access for development"

2. **HTTP Access** (optional):
   - Port: 80
   - Protocol: TCP
   - CIDR: `0.0.0.0/0`
   - Description: "HTTP web traffic"

3. **HTTPS Access** (optional):
   - Port: 443
   - Protocol: TCP
   - CIDR: `0.0.0.0/0`
   - Description: "HTTPS web traffic"

**Required Egress Rules**:
1. **All Outbound**:
   - Port: All
   - Protocol: All
   - CIDR: `0.0.0.0/0`
   - Description: "Allow all outbound for updates and CloudWatch"

**Relationships**:
- BELONGS_TO: One VPC
- PROTECTS: One or more EC2 Instances

**Validation Rules**:
- MUST allow SSH (port 22) inbound
- MUST allow all outbound (for package updates, CloudWatch)
- MUST be in same VPC as instance

---

### 3. Elastic IP

**Description**: Static public IPv4 address associated with the instance.

**Terraform Resource**: `aws_eip` (integrated in EC2 module)

**Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| allocation_id | String (computed) | EIP allocation ID | Format: `eipalloc-[a-f0-9]{17}` |
| association_id | String (computed) | Association ID | Format: `eipassoc-[a-f0-9]{17}` |
| public_ip | String (computed) | Allocated public IP | IPv4 format |
| instance_id | String | Associated instance | Must be valid instance ID |
| domain | String | EIP domain | Must be: `vpc` |

**Lifecycle**:
- ALLOCATED on infrastructure creation
- ASSOCIATED with instance when running
- RELEASED on infrastructure destruction

**Relationships**:
- ASSOCIATED_WITH: One EC2 Instance

**Validation Rules**:
- Domain MUST be `vpc`
- MUST be associated with instance
- MUST persist across instance stop/start

---

### 4. VPC & Networking

**Description**: Virtual network environment hosting the instance.

**Module Source**: `app.terraform.io/ravi-panchal-org/vpc/aws`

**VPC Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| vpc_id | String (computed) | VPC identifier | Format: `vpc-[a-f0-9]{17}` |
| cidr_block | String | VPC CIDR range | Must be: `10.0.0.0/16` (custom VPC) |
| is_default | Boolean | Default VPC flag | True if using default VPC |
| enable_dns_hostnames | Boolean | DNS hostname support | Must be true |
| enable_dns_support | Boolean | DNS resolution | Must be true |

**Subnet Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| subnet_id | String (computed) | Subnet identifier | Format: `subnet-[a-f0-9]{17}` |
| cidr_block | String | Subnet CIDR range | Must be: `10.0.1.0/24` (custom VPC) |
| availability_zone | String | AZ placement | Within ap-southeast-1 |
| map_public_ip_on_launch | Boolean | Auto-assign public IP | Must be true |

**Internet Gateway Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| igw_id | String (computed) | IGW identifier | Format: `igw-[a-f0-9]{17}` |
| vpc_id | String | Attached VPC | Must match VPC |

**Route Table Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| route_table_id | String (computed) | Route table ID | Format: `rtb-[a-f0-9]{17}` |
| routes | List(Object) | Routing rules | Must include IGW route |

**Required Routes**:
```hcl
{
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = <internet_gateway_id>
}
```

**VPC Selection Logic**:
```
IF default_vpc EXISTS THEN
  USE default_vpc
  USE first public subnet
ELSE
  CREATE custom_vpc (10.0.0.0/16)
  CREATE public_subnet (10.0.1.0/24)
  CREATE internet_gateway
  CREATE route_table with IGW route
END IF
```

**Relationships**:
- CONTAINS: One or more Subnets
- HAS: One Internet Gateway
- HAS: One or more Route Tables
- HOSTS: EC2 Instances

**Validation Rules**:
- Subnet MUST be public (map_public_ip_on_launch = true)
- MUST have route to Internet Gateway (0.0.0.0/0)
- Region MUST be ap-southeast-1

---

### 5. EBS Root Volume

**Description**: Persistent block storage attached as root device.

**Terraform Resource**: Managed by EC2 instance

**Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| volume_id | String (computed) | Volume identifier | Format: `vol-[a-f0-9]{17}` |
| size | Number | Volume size in GB | Range: 8-20 GB |
| volume_type | String | EBS volume type | Must be: `gp3` |
| iops | Number | Provisioned IOPS | Default for gp3: 3000 |
| throughput | Number | Throughput MB/s | Default for gp3: 125 |
| encrypted | Boolean | Encryption status | Optional (false for dev) |
| kms_key_id | String | KMS key for encryption | Optional |
| device_name | String | Device mount point | `/dev/sda1` or `/dev/xvda` |
| delete_on_termination | Boolean | Delete with instance | Must be true |

**Relationships**:
- ATTACHED_TO: One EC2 Instance

**Validation Rules**:
- Type MUST be `gp3` (cost optimization)
- Size MUST be 8-20 GB
- MUST be deleted on instance termination

---

### 6. IAM Instance Profile & Role

**Description**: IAM role granting CloudWatch Logs permissions to the instance.

**Module Source**: `app.terraform.io/ravi-panchal-org/iam/aws` (or integrated in EC2 module)

**Instance Profile Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| instance_profile_id | String (computed) | Profile identifier | AWS generated |
| instance_profile_name | String | Profile name | Unique |
| role_name | String | Associated IAM role | Must exist |
| arn | String (computed) | Profile ARN | AWS ARN format |

**IAM Role Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| role_id | String (computed) | Role identifier | AWS generated |
| role_name | String | Role name | Unique |
| assume_role_policy | JSON | Trust policy | Must allow EC2 service |
| attached_policies | List(String) | Policy ARNs | Must include CloudWatch policy |
| arn | String (computed) | Role ARN | AWS ARN format |

**Required Trust Policy**:
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

**Required Attached Policies**:
1. **CloudWatchAgentServerPolicy** (AWS Managed):
   - ARN: `arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy`
   - Permissions:
     - `logs:CreateLogGroup`
     - `logs:CreateLogStream`
     - `logs:PutLogEvents`
     - `logs:DescribeLogStreams`

**Relationships**:
- ATTACHED_TO: One EC2 Instance
- HAS: One IAM Role
- GRANTS: CloudWatch Logs permissions

**Validation Rules**:
- Trust policy MUST allow ec2.amazonaws.com
- MUST attach CloudWatchAgentServerPolicy
- Role name MUST be unique in account

---

### 7. CloudWatch Logs Configuration

**Description**: Logging infrastructure for SSH authentication monitoring.

**Module Source**: `app.terraform.io/ravi-panchal-org/cloudwatch/aws`

**Log Group Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| log_group_name | String | Log group identifier | Must be: `/aws/ec2/ssh-auth` |
| retention_in_days | Number | Log retention period | Must be: 7 days (minimum) |
| kms_key_id | String | Encryption key | Optional |
| arn | String (computed) | Log group ARN | AWS ARN format |

**Log Stream Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| log_stream_name | String | Stream identifier | Format: `{instance_id}` |
| log_group_name | String | Parent log group | Must exist |

**CloudWatch Agent Configuration**:
```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "/aws/ec2/ssh-auth",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC",
            "timestamp_format": "%b %d %H:%M:%S"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {}
  }
}
```

**Log Events Schema**:

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| timestamp | Number | Event timestamp (ms) | 1705881600000 |
| message | String | Log entry | "Jan 21 12:00:00 sshd[1234]: Accepted password for devuser..." |
| ingestionTime | Number | CloudWatch ingestion time | 1705881605000 |

**Relationships**:
- RECEIVES_FROM: EC2 Instance (via CloudWatch Agent)
- CONTAINS: Log Streams (one per instance)

**Validation Rules**:
- Log group MUST be created before instance launch
- Retention MUST be at least 7 days
- Log stream MUST use instance ID

---

### 8. User Credentials

**Description**: Authentication credentials for SSH access.

**Terraform Resource**: `random_password`

**Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| result | String (sensitive, computed) | Generated password | 20 characters |
| length | Number | Password length | Must be: 20 |
| special | Boolean | Include special chars | Must be: true |
| override_special | String | Allowed special chars | `!#$%&*()-_=+[]{}<>:?` |
| min_upper | Number | Min uppercase letters | Must be: 2 |
| min_lower | Number | Min lowercase letters | Must be: 2 |
| min_numeric | Number | Min digits | Must be: 2 |
| min_special | Number | Min special chars | Must be: 2 |
| bcrypt_hash | String (computed) | Hashed password | For user-data script |

**Password Complexity Requirements**:
- Total length: 20 characters
- At least 2 uppercase letters (A-Z)
- At least 2 lowercase letters (a-z)
- At least 2 digits (0-9)
- At least 2 special characters from: `!#$%&*()-_=+[]{}<>:?`

**User Account Schema**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| username | String | SSH username | Must be: `devuser` |
| password | String (sensitive) | Account password | From random_password |
| uid | Number | User ID | System assigned |
| gid | Number | Primary group ID | System assigned |
| home_directory | String | Home directory path | `/home/devuser` |
| shell | String | Login shell | `/bin/bash` |

**Storage**:
- Password stored as HCP Terraform sensitive variable
- Passed to user-data via Terraform variable
- Never logged or displayed in plain text

**Relationships**:
- USED_BY: EC2 Instance (via user-data)
- STORED_IN: HCP Terraform Workspace

**Validation Rules**:
- Password MUST meet complexity requirements
- Username MUST be `devuser`
- Password MUST be marked sensitive in Terraform
- Password MUST be stored as workspace variable

---

### 9. HCP Terraform Workspace

**Description**: Infrastructure management workspace in HCP Terraform.

**Attributes**:

| Attribute | Type | Description | Validation |
|-----------|------|-------------|------------|
| organization_name | String | HCP Terraform org | Must be: `ravi-panchal-org` |
| project_name | String | Project name | Must be: `Default Project` |
| workspace_name | String | Workspace name | Must be: `sandbox_public_ec2_dev` |
| execution_mode | String | Execution mode | Must be: `remote` |
| terraform_version | String | Terraform version | Latest stable |
| working_directory | String | Code directory | Root or specified |
| auto_apply | Boolean | Auto-apply runs | Configurable |
| variables | Map(Object) | Workspace variables | See schema below |

**Workspace Variables Schema**:
```hcl
{
  key         = string      # Variable name
  value       = string      # Variable value
  category    = string      # "terraform" or "env"
  sensitive   = bool        # Redact from UI
  description = string      # Variable description
}
```

**Required Workspace Variables**:

| Key | Category | Sensitive | Description |
|-----|----------|-----------|-------------|
| `instance_password` | terraform | true | Generated password from random_password |
| `aws_region` | terraform | false | AWS region (ap-southeast-1) |
| `environment` | terraform | false | Environment name (dev, staging, prod) |
| `enable_http` | terraform | false | Enable HTTP access (true/false) |
| `enable_https` | terraform | false | Enable HTTPS access (true/false) |

**Relationships**:
- MANAGES: All AWS Infrastructure
- STORES: Terraform State
- STORES: Sensitive Variables

**Validation Rules**:
- Organization MUST be `ravi-panchal-org`
- Workspace MUST be `sandbox_public_ec2_dev`
- Password variable MUST be marked sensitive

---

## Data Validation Summary

### Cross-Entity Validation

1. **Region Consistency**:
   - All resources MUST be in ap-southeast-1
   - AMI lookup MUST filter by ap-southeast-1
   - Availability zones MUST be within ap-southeast-1

2. **Networking Consistency**:
   - Security group MUST be in same VPC as instance
   - Subnet MUST be in same VPC as instance
   - Instance MUST be in subnet with public IP assignment

3. **IAM Consistency**:
   - Instance profile MUST reference valid IAM role
   - IAM role MUST have CloudWatch policy attached
   - Trust policy MUST allow EC2 service

4. **Logging Consistency**:
   - Log group MUST exist before instance launch
   - CloudWatch Agent config MUST reference correct log group
   - IAM role MUST grant logs:PutLogEvents permission

5. **Password Consistency**:
   - Password MUST meet complexity requirements
   - Password MUST be passed to user-data securely
   - Password MUST be stored as sensitive variable

---

## State Management

### Terraform State Schema

Key state attributes tracked:

```hcl
{
  ec2_instance = {
    id                  = string  # instance_id
    public_ip           = string  # elastic_ip
    private_ip          = string  # vpc_private_ip
    instance_state      = string  # running/stopped/terminated
    subnet_id           = string  # subnet placement
    security_groups     = list(string)  # attached SGs
    iam_instance_profile = string  # profile name
  }
  
  vpc = {
    id              = string  # vpc_id
    cidr_block      = string  # vpc_cidr
    is_default      = bool    # default_vpc_flag
  }
  
  security_group = {
    id          = string  # sg_id
    ingress     = list(object)  # inbound rules
    egress      = list(object)  # outbound rules
  }
  
  elastic_ip = {
    id              = string  # allocation_id
    public_ip       = string  # public_ip
    association_id  = string  # association_id
  }
  
  cloudwatch_log_group = {
    name                = string  # log_group_name
    arn                 = string  # log_group_arn
    retention_in_days   = number  # retention_period
  }
  
  random_password = {
    result  = string (sensitive)  # generated_password
    bcrypt_hash = string  # hashed_password
  }
}
```

### State Dependencies

```
random_password (no dependencies)
  ↓
vpc/subnet/igw (no dependencies, or depends on default VPC check)
  ↓
security_group (depends on VPC)
  ↓
iam_role → iam_instance_profile (depends on IAM policy)
  ↓
cloudwatch_log_group (no dependencies)
  ↓
ec2_instance (depends on: subnet, security_group, iam_instance_profile, random_password)
  ↓
elastic_ip (depends on: ec2_instance)
```

---

## Data Model Complete

This data model defines all entities, relationships, and validation rules required for the public EC2 instance with password authentication feature. All entities align with the constitution's module-first architecture using private registry modules.

**Next Phase**: Generate Terraform variable and output contracts in `/contracts/`.
