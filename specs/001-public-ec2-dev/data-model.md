# Data Model: Public EC2 Instance Infrastructure

**Feature**: Public EC2 Instance for Development Environment  
**Branch**: `001-public-ec2-dev`  
**Date**: 2026-01-12

---

## Overview

This document defines the entities, relationships, and state model for the public EC2 instance infrastructure. While this is infrastructure-as-code rather than a traditional application, we model the key AWS resources as entities with attributes, relationships, and lifecycle states.

---

## Entity Definitions

### 1. EC2 Instance

**Description**: The primary compute resource - a virtual machine running in AWS.

**Attributes**:
| Attribute | Type | Required | Default | Validation | Description |
|-----------|------|----------|---------|------------|-------------|
| `instance_id` | String | Auto | - | AWS format: `i-*` | Unique identifier assigned by AWS |
| `instance_type` | String | Yes | `t3.micro` | Must be `t3.micro` | EC2 instance size/family |
| `ami_id` | String | Yes | (dynamic) | AWS AMI format: `ami-*` | Amazon Linux 2023 AMI identifier |
| `availability_zone` | String | Auto | (AWS selected) | Valid AZ in ap-southeast-1 | Physical location within region |
| `public_ip` | String | Auto | - | Valid IPv4 address | Internet-routable IP address |
| `private_ip` | String | Auto | - | RFC 1918 IP address | VPC-internal IP address |
| `state` | String | Auto | `pending` | See state transitions | Current instance state |
| `monitoring_enabled` | Boolean | Yes | `false` | Must be `false` | Basic monitoring only (spec requirement) |
| `root_volume_size` | Integer | Yes | `8` | Must be `8` GB | Root EBS volume size |
| `root_volume_type` | String | Yes | `gp3` | Must be `gp3` | EBS volume type |
| `delete_on_termination` | Boolean | Yes | `true` | Must be `true` | Auto-delete volume on instance termination |
| `tags` | Map | Yes | (see below) | Key-value pairs | Resource metadata |

**Tags Schema**:
```hcl
{
  Environment  = "development"
  ManagedBy    = "Terraform"
  Project      = string        # To be determined
  CostCenter   = string        # To be determined
  Feature      = "001-public-ec2-dev"
  Workspace    = "sandbox_workspace"
}
```

**State Transitions**:
```
pending → running → stopping → stopped → terminated
                  ↓
               rebooting → running
```

**Validation Rules**:
- `instance_type` MUST be `t3.micro` (cost constraint from spec FR-002)
- `ami_id` MUST be latest Amazon Linux 2023 in ap-southeast-1 (FR-005)
- `public_ip` MUST be assigned (FR-003)
- `monitoring_enabled` MUST be `false` (FR-016a - basic monitoring only)
- `root_volume_size` MUST be `8` GB (FR-006)
- `delete_on_termination` MUST be `true` (FR-006 - immediate deletion clarification)

**Relationships**:
- BELONGS TO: 1 VPC (Default VPC)
- ATTACHED TO: 1 Security Group (SSH Security Group)
- HAS: 1 Root Volume (EBS GP3)
- USES: 1 IAM Instance Profile (for Secrets Manager access)
- ACCESSES: 1 Secrets Manager Secret (SSH password)

---

### 2. Security Group

**Description**: Virtual firewall controlling inbound and outbound network traffic to the EC2 instance.

**Attributes**:
| Attribute | Type | Required | Default | Validation | Description |
|-----------|------|----------|---------|------------|-------------|
| `security_group_id` | String | Auto | - | AWS format: `sg-*` | Unique identifier assigned by AWS |
| `name` | String | Yes | `dev-ec2-ssh-sg` | Descriptive name | Human-readable security group name |
| `description` | String | Yes | - | Max 255 chars | Purpose description |
| `vpc_id` | String | Yes | (default VPC) | Valid VPC ID | VPC to which SG belongs |
| `ingress_rules` | List | Yes | (see below) | Valid CIDR blocks | Inbound traffic rules |
| `egress_rules` | List | Yes | (see below) | Valid CIDR blocks | Outbound traffic rules |
| `tags` | Map | Yes | (common tags) | Key-value pairs | Resource metadata |

**Ingress Rules Schema**:
```hcl
[
  {
    description = "SSH from anywhere (development only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
```

**Egress Rules Schema**:
```hcl
[
  {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
]
```

**Validation Rules**:
- `ingress_rules` MUST include SSH (port 22) from `0.0.0.0/0` (FR-013)
- `egress_rules` MUST allow all outbound traffic (FR-014)
- `vpc_id` MUST reference default VPC (FR-004)

**Relationships**:
- BELONGS TO: 1 VPC (Default VPC)
- ATTACHED TO: 1 EC2 Instance

---

### 3. Root Volume (EBS)

**Description**: Block storage device attached to the EC2 instance as the root filesystem.

**Attributes**:
| Attribute | Type | Required | Default | Validation | Description |
|-----------|------|----------|---------|------------|-------------|
| `volume_id` | String | Auto | - | AWS format: `vol-*` | Unique identifier assigned by AWS |
| `size` | Integer | Yes | `8` | Must be `8` GB | Storage capacity in gigabytes |
| `type` | String | Yes | `gp3` | Must be `gp3` | EBS volume type (General Purpose SSD) |
| `iops` | Integer | Auto | `3000` | 3000-16000 | Input/Output operations per second |
| `throughput` | Integer | Auto | `125` | 125-1000 MB/s | Throughput in MB/s |
| `encrypted` | Boolean | No | `false` | - | Volume encryption status |
| `availability_zone` | String | Auto | (same as instance) | Valid AZ | Physical location |
| `attached_to` | String | Auto | - | Instance ID | Instance to which volume is attached |
| `device_name` | String | Auto | `/dev/xvda` | Linux device name | Root device identifier |
| `delete_on_termination` | Boolean | Yes | `true` | Must be `true` | Auto-delete on instance termination |
| `tags` | Map | Yes | (common tags) | Key-value pairs | Resource metadata |

**State Transitions**:
```
creating → available → in-use → deleting → deleted
                      ↓
                  detaching → available
```

**Validation Rules**:
- `size` MUST be `8` GB (FR-006)
- `type` MUST be `gp3` (FR-006)
- `delete_on_termination` MUST be `true` (spec clarification)

**Relationships**:
- ATTACHED TO: 1 EC2 Instance (as root device)

**Cost Calculation**:
```
Monthly Cost = $0.08/GB × 8 GB = $0.64/month
```

---

### 4. SSH Credentials

**Description**: Authentication information for SSH access to the EC2 instance.

**Attributes**:
| Attribute | Type | Required | Default | Validation | Description |
|-----------|------|----------|---------|------------|-------------|
| `username` | String | Yes | `ec2-user` | Must be `ec2-user` | SSH login username (default for Amazon Linux) |
| `password` | String | Yes | (generated) | See password policy | SSH password (stored in Secrets Manager) |
| `ssh_port` | Integer | Yes | `22` | Must be `22` | SSH service port |
| `auth_method` | String | Yes | `password` | Must be `password` | Authentication method |

**Password Policy**:
```
Length: 32 characters
Character Classes:
  - Lowercase letters: a-z
  - Uppercase letters: A-Z
  - Numbers: 0-9
  - Special characters: !@#$%^&*()_+-=[]{}|;:,.<>?
  
Requirements:
  - At least one character from each class
  - No repeating characters
  - No common patterns
  - Generated using cryptographically secure random generator
```

**Validation Rules**:
- `username` MUST be `ec2-user` (default for Amazon Linux 2023)
- `password` MUST meet password policy requirements (FR-009)
- `auth_method` MUST be `password` (FR-008)

**Relationships**:
- STORED IN: 1 Secrets Manager Secret
- USED BY: 1 EC2 Instance

---

### 5. Secrets Manager Secret

**Description**: Encrypted storage for the SSH password.

**Attributes**:
| Attribute | Type | Required | Default | Validation | Description |
|-----------|------|----------|---------|------------|-------------|
| `secret_arn` | String | Auto | - | AWS ARN format | Unique Amazon Resource Name |
| `secret_name` | String | Yes | `dev-ec2-ssh-password` | Unique within account/region | Human-readable secret identifier |
| `secret_value` | String | Yes | (password) | JSON or plain text | Encrypted password value |
| `kms_key_id` | String | No | (AWS managed) | KMS key ARN or ID | Encryption key (default: aws/secretsmanager) |
| `description` | String | Yes | - | Max 2048 chars | Purpose description |
| `rotation_enabled` | Boolean | No | `false` | - | Automatic rotation status |
| `tags` | Map | Yes | (common tags) | Key-value pairs | Resource metadata |

**Secret Value Format** (plain text):
```
<32-character-random-password>
```

**Validation Rules**:
- `secret_name` MUST be unique within the AWS account and region (FR-010)
- `secret_value` MUST contain the generated SSH password
- Encryption at rest MUST be enabled (AWS default)

**Relationships**:
- CONTAINS: 1 SSH Credentials (password)
- ACCESSED BY: 1 EC2 Instance (via IAM role)

**Cost Calculation**:
```
Secret Storage: $0.40/month
API Calls: ~100 calls/month × $0.05/10,000 = $0.0005/month
Total: ~$0.40/month
```

---

### 6. IAM Role & Instance Profile

**Description**: Identity and permissions for the EC2 instance to access AWS services.

**Attributes**:
| Attribute | Type | Required | Default | Validation | Description |
|-----------|------|----------|---------|------------|-------------|
| `role_name` | String | Yes | `dev-ec2-instance-role` | Unique name | IAM role name |
| `role_arn` | String | Auto | - | AWS ARN format | Role Amazon Resource Name |
| `instance_profile_name` | String | Yes | `dev-ec2-instance-profile` | Unique name | Instance profile name |
| `instance_profile_arn` | String | Auto | - | AWS ARN format | Instance profile ARN |
| `assume_role_policy` | JSON | Yes | (EC2 trust policy) | Valid IAM policy | Who can assume this role |
| `policies` | List | Yes | (see below) | Valid IAM policy ARNs | Attached permission policies |
| `tags` | Map | Yes | (common tags) | Key-value pairs | Resource metadata |

**Assume Role Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    }
  }]
}
```

**Attached Policies** (inline):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "secretsmanager:GetSecretValue"
    ],
    "Resource": "arn:aws:secretsmanager:ap-southeast-1:*:secret:dev-ec2-ssh-password-*"
  }]
}
```

**Validation Rules**:
- IAM role MUST allow EC2 service to assume it
- IAM role MUST have `secretsmanager:GetSecretValue` permission for the SSH password secret
- Permissions MUST follow principle of least privilege

**Relationships**:
- ATTACHED TO: 1 EC2 Instance (via instance profile)
- GRANTS ACCESS TO: 1 Secrets Manager Secret

---

### 7. VPC (Default VPC)

**Description**: Virtual Private Cloud network where the EC2 instance is deployed.

**Attributes**:
| Attribute | Type | Required | Default | Validation | Description |
|-----------|------|----------|---------|------------|-------------|
| `vpc_id` | String | Auto | (existing) | AWS format: `vpc-*` | Unique VPC identifier |
| `cidr_block` | String | Auto | `172.31.0.0/16` | Valid CIDR | IP address range |
| `is_default` | Boolean | Yes | `true` | Must be `true` | Indicates default VPC |
| `region` | String | Yes | `ap-southeast-1` | Must be `ap-southeast-1` | AWS region |

**Validation Rules**:
- MUST exist in ap-southeast-1 region (spec assumption #2)
- MUST be the default VPC (FR-004, constraint #4)

**Relationships**:
- CONTAINS: 1+ Subnets
- CONTAINS: 1 Security Group
- CONTAINS: 1 EC2 Instance

---

## Entity Relationships Diagram

```
┌─────────────────────┐
│   Default VPC       │
│  (ap-southeast-1)   │
└──────────┬──────────┘
           │ contains
           ├────────────────────┐
           │                    │
           ▼                    ▼
┌──────────────────┐   ┌──────────────────┐
│  Security Group  │   │   EC2 Instance   │
│  (SSH rules)     │◄──┤   (t3.micro)     │
└──────────────────┘   └─────────┬────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
                    ▼            ▼            ▼
           ┌────────────┐  ┌───────────┐  ┌──────────────┐
           │ EBS Volume │  │ IAM Role  │  │ SSH Creds    │
           │  (8GB GP3) │  │ + Profile │  │ (password)   │
           └────────────┘  └─────┬─────┘  └──────┬───────┘
                                 │                │
                                 │ grants         │ stored in
                                 │ access         │
                                 │                │
                                 ▼                ▼
                           ┌──────────────────────────┐
                           │   Secrets Manager        │
                           │   (SSH password secret)  │
                           └──────────────────────────┘
```

**Relationship Summary**:
- VPC **contains** Security Group, EC2 Instance
- Security Group **attached to** EC2 Instance
- EC2 Instance **has** EBS Volume (root device)
- EC2 Instance **uses** IAM Instance Profile
- EC2 Instance **accesses** SSH Credentials
- IAM Role **grants access to** Secrets Manager Secret
- SSH Credentials **stored in** Secrets Manager Secret

---

## Data Flows

### 1. Infrastructure Provisioning Flow

```
Terraform Plan/Apply
        │
        ├─► Create Random Password (sensitive=true)
        │       │
        │       └─► Store in Secrets Manager
        │
        ├─► Lookup Default VPC
        │       │
        │       └─► Get Default Subnets
        │
        ├─► Lookup Latest Amazon Linux 2023 AMI
        │
        ├─► Create IAM Role + Instance Profile
        │       │
        │       └─► Attach Secrets Manager Policy
        │
        ├─► Create Security Group (SSH rules)
        │
        └─► Create EC2 Instance
                │
                ├─► Attach Security Group
                ├─► Attach IAM Instance Profile
                ├─► Attach EBS Volume (8GB GP3)
                ├─► Inject User Data Script
                │       │
                │       └─► Configure SSH password auth
                │       └─► Retrieve password from Secrets Manager
                │       └─► Set password for ec2-user
                │       └─► Restart sshd
                │
                └─► Assign Public IP
```

### 2. SSH Connection Flow

```
Developer
    │
    └─► Retrieve password from Secrets Manager
            │
            └─► AWS CLI: aws secretsmanager get-secret-value
                    │
                    ├─► Authenticate (IAM user/role)
                    ├─► Decrypt with KMS
                    └─► Return password
                            │
                            └─► SSH Client: ssh ec2-user@<public-ip>
                                    │
                                    ├─► Prompt for password
                                    ├─► Authenticate against /etc/shadow
                                    └─► Establish session
```

### 3. Monitoring Data Flow

```
EC2 Instance
    │
    └─► CloudWatch Agent (built-in)
            │
            └─► Collect metrics every 5 minutes
                    │
                    ├─► CPUUtilization
                    ├─► NetworkIn / NetworkOut
                    ├─► DiskReadBytes / DiskWriteBytes
                    └─► StatusCheckFailed
                            │
                            └─► Store in CloudWatch
                                    │
                                    └─► Query via AWS Console/CLI
```

---

## State Management

### Terraform State

**Storage**: HCP Terraform workspace `sandbox_workspace`

**Sensitive Data Handling**:
- `random_password.result` → **Marked as sensitive** in Terraform
- **NOT** stored in plain text outputs
- Secrets Manager ARN → **Safe to store** (not the secret value)

**State Schema** (simplified):
```json
{
  "resources": [
    {
      "type": "aws_instance",
      "name": "dev_ec2",
      "instances": [{
        "attributes": {
          "id": "i-0123456789abcdef",
          "public_ip": "54.255.x.x",
          "instance_type": "t3.micro",
          "ami": "ami-xyz",
          "tags": { /* common tags */ }
        }
      }]
    },
    {
      "type": "aws_secretsmanager_secret_version",
      "name": "ssh_password",
      "instances": [{
        "attributes": {
          "secret_id": "arn:aws:secretsmanager:...",
          "secret_string": "<SENSITIVE>",  // Not visible
          "version_id": "uuid"
        }
      }]
    }
  ]
}
```

---

## Idempotency & Updates

### Immutable Attributes (force replacement)
- `instance_type`: Changing from t3.micro → forces new instance
- `ami_id`: AMI update → forces new instance
- `availability_zone`: AZ change → forces new instance
- `root_volume_size`: Size change → forces new instance

### Mutable Attributes (in-place update)
- `tags`: Tag changes → in-place update
- `user_data`: User data change → requires manual restart or replace
- `security_groups`: Security group changes → in-place update
- `monitoring`: Monitoring setting → in-place update

### Password Rotation
**Current Scope**: Manual password rotation only
**Process**:
1. Generate new password in Terraform
2. Update Secrets Manager secret
3. Run user data script or manual SSH command to update password
4. Terraform apply (updates secret version)

**Future Enhancement**: Automatic rotation using Lambda (out of scope)

---

## Validation & Constraints

### Pre-Deployment Validation
- [ ] Default VPC exists in ap-southeast-1
- [ ] AWS credentials have required permissions
- [ ] HCP Terraform workspace is configured
- [ ] t3.micro instance type available in region
- [ ] Amazon Linux 2023 AMI exists

### Post-Deployment Validation
- [ ] EC2 instance state = `running`
- [ ] Public IP assigned and reachable
- [ ] Security group attached with SSH rule
- [ ] Secrets Manager secret created
- [ ] IAM role attached to instance
- [ ] SSH connection successful with password
- [ ] CloudWatch metrics appearing (5-min intervals)
- [ ] All resources tagged correctly

### Cost Validation
- [ ] Monthly cost < $50 (target: ~$12.32)
- [ ] No unexpected charges (detailed monitoring, data transfer)
- [ ] Cost tags visible in AWS Cost Explorer

---

## Error Handling

### Common Errors

| Error Condition | Detection | Response | Spec Reference |
|----------------|-----------|----------|----------------|
| Default VPC missing | Data source returns empty | Fail with error message | Assumption #2 |
| Insufficient permissions | IAM error during provisioning | Fail with IAM error details | Dependency: IAM |
| t3.micro unavailable | Instance creation error | Fail (no fallback per spec) | FR-002 |
| AMI not found | Data source returns empty | Fail with AMI error | FR-005 |
| Secrets Manager quota | Service quota error | Fail with quota error | Dependency Risk |
| SSH connection failure | Manual test fails | Troubleshoot: SG rules, user data, password | FR-012 |

---

## Performance Characteristics

### Instance Performance
- **CPU**: 2 burstable vCPUs (t3.micro)
- **Memory**: 1 GB RAM
- **Network**: Up to 5 Gbps (burst)
- **Storage IOPS**: 3,000 (GP3 baseline)
- **Storage Throughput**: 125 MB/s (GP3 baseline)

### Provisioning Time
- **Secrets Manager Secret**: ~5 seconds
- **IAM Role/Profile**: ~10 seconds
- **Security Group**: ~5 seconds
- **EC2 Instance**: ~60-90 seconds (to running state)
- **User Data Execution**: ~30-60 seconds (SSH config)
- **Total**: ~2-3 minutes (spec requirement: < 5 minutes per SC-001)

---

## Security Attributes

### Data Classification
- **SSH Password**: **Highly Sensitive** → Encrypted in Secrets Manager
- **Public IP**: **Public** → Visible in Terraform outputs
- **Instance ID**: **Internal** → Visible in Terraform state
- **Secret ARN**: **Internal** → Safe to expose in outputs

### Access Control
| Resource | Access Method | Authentication | Authorization |
|----------|---------------|----------------|---------------|
| EC2 Instance | SSH (password) | Username/password | OS-level (Linux PAM) |
| Secrets Manager | AWS API | IAM | IAM policy (GetSecretValue) |
| CloudWatch Metrics | AWS Console/API | IAM | IAM policy (CloudWatch read) |
| Terraform State | HCP Terraform | TFE token | Workspace permissions |

### Encryption
- **Secrets Manager**: Encrypted at rest (AWS KMS - aws/secretsmanager key)
- **EBS Volume**: Unencrypted (optional enhancement for future)
- **Network Traffic**: SSH (encrypted in transit)
- **Terraform State**: Encrypted in HCP Terraform

---

## Compliance & Governance

### Tagging Requirements (FR-017)
All resources MUST be tagged with:
- `Environment = "development"`
- `ManagedBy = "Terraform"`
- `Project = <project-name>` (to be determined)
- `CostCenter = <cost-center>` (to be determined)
- `Feature = "001-public-ec2-dev"`
- `Workspace = "sandbox_workspace"`

### Audit Trail
- **Terraform State**: Version history in HCP Terraform
- **CloudWatch**: Basic metrics retained (default retention)
- **CloudTrail**: AWS API calls logged (if enabled in account)
- **GitHub**: Code changes tracked via commits (linked to Issue #12)

---

## Summary

This data model defines **7 primary entities** (EC2 Instance, Security Group, EBS Volume, SSH Credentials, Secrets Manager Secret, IAM Role/Profile, VPC) with strict attribute validation, state management, and relationships. All entities are tagged for cost tracking and comply with the constitution requirement for module-first architecture.

**Key Characteristics**:
- **Strongly Typed**: All attributes have explicit types and validation rules
- **Auditable**: All state changes tracked in Terraform and AWS
- **Secure**: Sensitive data encrypted and access-controlled
- **Cost-Optimized**: $12.32/month (76% under budget)
- **Idempotent**: Safe to re-run Terraform apply

**Next Steps**: Proceed to Phase 1 contracts and quickstart documentation.

---

**Document Status**: ✅ Complete  
**Next Artifact**: `quickstart.md` (developer onboarding guide)  
**Last Updated**: 2026-01-12
