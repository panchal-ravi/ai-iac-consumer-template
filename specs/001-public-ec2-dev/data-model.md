# Data Model: Public EC2 Instance with Password Authentication

**Feature**: Public EC2 Development Instance  
**Branch**: `001-public-ec2-dev`  
**Date**: 2025-01-17

## Overview

This data model defines the infrastructure entities, their relationships, and state management for a public EC2 development instance. The model focuses on Terraform resources and their dependencies rather than application-level data structures.

## Entity Definitions

### 1. EC2 Instance

**Purpose**: Virtual machine resource providing compute capacity

**Attributes**:
- `instance_id` (string): AWS-generated unique identifier (e.g., `i-0123456789abcdef0`)
- `instance_type` (string): Instance size specification (fixed: `t3.micro`)
- `ami_id` (string): Amazon Machine Image ID (resolved from SSM parameter)
- `public_ip` (string): Automatically assigned public IPv4 address
- `private_ip` (string): VPC-assigned private IPv4 address
- `availability_zone` (string): AZ within ap-southeast-1 region
- `state` (enum): Instance lifecycle state (`pending`, `running`, `stopping`, `stopped`, `terminated`)
- `monitoring_enabled` (boolean): Detailed monitoring flag (fixed: `false`)
- `termination_protection` (boolean): Deletion protection flag (fixed: `false`)

**State Transitions**:
```
[Pending] → [Running] (normal startup)
[Running] → [Stopping] → [Stopped] (manual stop)
[Stopped] → [Running] (restart)
[Running/Stopped] → [Terminated] (destroy)
```

**Validation Rules**:
- Must belong to exactly one subnet
- Must have at least one security group attached
- Public IP assignment requires subnet with internet gateway route
- AMI must be compatible with instance type architecture (x86_64)

**Relationships**:
- Belongs to: 1 Subnet
- Attached to: 1 Security Group
- Has: 1 Root Volume
- Uses: 1 IAM Instance Profile
- Sends logs to: 1 CloudWatch Log Group

### 2. Security Group

**Purpose**: Stateful firewall rules controlling network traffic

**Attributes**:
- `group_id` (string): AWS-generated unique identifier (e.g., `sg-0123456789abcdef0`)
- `name` (string): Human-readable identifier (derived from instance name)
- `vpc_id` (string): Parent VPC identifier
- `ingress_rules` (list): Inbound traffic rules
- `egress_rules` (list): Outbound traffic rules (default: allow all)

**Ingress Rule Structure**:
```hcl
{
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow SSH from anywhere"
}
```

**Validation Rules**:
- Must belong to exactly one VPC
- Port ranges must be valid (0-65535)
- CIDR blocks must be valid IPv4 notation
- SSH rule (port 22) is mandatory for this feature

**Relationships**:
- Belongs to: 1 VPC
- Attached to: 1+ EC2 Instances

### 3. IAM Instance Profile

**Purpose**: Container for IAM role allowing EC2 to assume AWS service permissions

**Attributes**:
- `profile_name` (string): Unique identifier for the instance profile
- `profile_arn` (string): AWS ARN for the profile
- `role_name` (string): Associated IAM role name
- `role_arn` (string): AWS ARN for the role
- `policies` (map): Attached managed policies

**Attached Policies**:
```hcl
{
  CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```

**Validation Rules**:
- Role must have EC2 service principal in trust policy
- At least one policy must be attached
- CloudWatchAgentServerPolicy is mandatory for this feature

**Relationships**:
- Has: 1 IAM Role
- Assumed by: 1 EC2 Instance
- Grants access to: CloudWatch Logs Service

### 4. EBS Root Volume

**Purpose**: Block storage device for instance operating system and data

**Attributes**:
- `volume_id` (string): AWS-generated unique identifier (e.g., `vol-0123456789abcdef0`)
- `volume_type` (string): Storage class (fixed: `gp3`)
- `size` (number): Storage capacity in GB (fixed: `8`)
- `iops` (number): Provisioned IOPS (gp3 default: 3000)
- `throughput` (number): Throughput in MB/s (gp3 default: 125)
- `encrypted` (boolean): Encryption status (fixed: `true`)
- `kms_key_id` (string): KMS key ARN (default: AWS-managed `aws/ebs`)
- `delete_on_termination` (boolean): Automatic deletion flag (fixed: `true`)

**Validation Rules**:
- Size must be >= 8 GB for Amazon Linux 2023
- Encryption must be enabled
- GP3 volume supports IOPS range 3000-16000
- GP3 volume supports throughput range 125-1000 MB/s

**Lifecycle**:
- Created: During instance launch
- Deleted: When instance is terminated (delete_on_termination = true)

**Relationships**:
- Attached to: 1 EC2 Instance
- Encrypted by: 1 KMS Key (AWS-managed)

### 5. User Credentials

**Purpose**: Authentication information for SSH access

**Attributes**:
- `username` (string): Linux user account name (fixed: `devuser`)
- `password` (string, sensitive): Randomly generated authentication secret
- `password_length` (number): Character count (fixed: `16`)
- `password_policy` (object): Complexity requirements
  - `special` (boolean): true
  - `upper` (boolean): true
  - `lower` (boolean): true
  - `numeric` (boolean): true

**Validation Rules**:
- Password must be >= 16 characters
- Password must include at least one character from each enabled category
- Username must be valid Linux username (alphanumeric, underscore, dash)
- Password is marked as sensitive in Terraform state

**Lifecycle**:
- Generated: During Terraform apply (random_password resource)
- Applied: During instance user data execution
- Stored: In Terraform state (encrypted by HCP Terraform)
- Exposed: Via sensitive Terraform output

**Relationships**:
- Belongs to: 1 EC2 Instance
- Created by: User Data Script

### 6. CloudWatch Log Group

**Purpose**: Centralized storage for instance system logs

**Attributes**:
- `name` (string): Log group identifier (fixed: `/aws/ec2/sandbox_public_ec2_dev`)
- `retention_in_days` (number): Log retention period (default: never expire, 0)
- `kms_key_id` (string, optional): Encryption key ARN
- `log_streams` (computed): Individual instance log streams

**Log Stream Structure**:
```
Log Group: /aws/ec2/sandbox_public_ec2_dev
  └── Log Stream: {instance_id}  (e.g., i-0123456789abcdef0)
      └── Log Events: Timestamped entries from /var/log/messages
```

**Validation Rules**:
- Log group name must start with `/`
- Name must be 1-512 characters
- Name pattern: `[\.\-_/#A-Za-z0-9]+`

**Relationships**:
- Receives logs from: 1+ EC2 Instances
- Contains: 1+ Log Streams (one per instance)

### 7. VPC (Data Source)

**Purpose**: Existing virtual network infrastructure (not created by this feature)

**Attributes**:
- `vpc_id` (string): AWS-generated unique identifier
- `cidr_block` (string): IPv4 address range (default VPC: `172.31.0.0/16`)
- `enable_dns_hostnames` (boolean): DNS hostname assignment (default: `true`)
- `enable_dns_support` (boolean): DNS resolution (default: `true`)
- `is_default` (boolean): Default VPC flag (fixed: `true`)

**Discovery Method**:
```hcl
data "aws_vpc" "default" {
  default = true
}
```

**Relationships**:
- Contains: 1+ Subnets
- Contains: 1+ Security Groups
- Has: 1 Internet Gateway (for public IP routing)

### 8. Subnet (Data Source)

**Purpose**: Existing network segment within VPC (not created by this feature)

**Attributes**:
- `subnet_id` (string): AWS-generated unique identifier
- `cidr_block` (string): IPv4 address range (subset of VPC CIDR)
- `availability_zone` (string): Physical location within region
- `map_public_ip_on_launch` (boolean): Auto-assign public IP (default: `true`)

**Discovery Method**:
```hcl
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
```

**Relationships**:
- Belongs to: 1 VPC
- Contains: 0+ EC2 Instances

### 9. AMI (Data Source)

**Purpose**: Pre-configured operating system image (not created by this feature)

**Attributes**:
- `ami_id` (string): AWS-generated unique identifier (e.g., `ami-0123456789abcdef0`)
- `name` (string): AMI name with version/date
- `architecture` (string): CPU architecture (fixed: `x86_64`)
- `root_device_type` (string): Root volume type (fixed: `ebs`)
- `virtualization_type` (string): Virtualization (fixed: `hvm`)

**Discovery Method**:
```hcl
# Via SSM parameter (recommended)
ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
```

**Relationships**:
- Used by: 1+ EC2 Instances

## Entity Relationship Diagram

```
┌─────────────────┐
│   VPC (Data)    │ (1)
│  172.31.0.0/16  │
└────────┬────────┘
         │ contains
         │ (1:N)
         │
    ┌────▼────────────┐
    │ Subnet (Data)   │ (1)
    └────────┬────────┘
             │ hosts
             │ (1:1)
             │
    ┌────────▼────────────────┐      ┌──────────────────┐
    │    EC2 Instance         │◄─────┤  AMI (Data)      │
    │  - instance_id          │ uses │  - ami_id        │
    │  - public_ip            │ (N:1)│  - AL2023        │
    │  - state: running       │      └──────────────────┘
    └──┬──────┬──────┬────────┘
       │      │      │
       │      │      │ has (1:1)
       │      │      │
       │      │      └─────────────────┐
       │      │                        │
       │      │ attached to (1:1)      │
       │      │                        │
       │  ┌───▼───────────────┐   ┌───▼──────────────┐
       │  │  Security Group   │   │ IAM Instance     │
       │  │  - SSH: 22        │   │ Profile          │
       │  │  - CIDR: 0.0.0.0/0│   │ - CloudWatch     │
       │  └───────────────────┘   │   Policy         │
       │                          └─────────┬────────┘
       │                                    │ grants access
       │                                    │ (1:1)
       │ attached to (1:1)                  │
       │                              ┌─────▼──────────────┐
   ┌───▼────────────┐                │ CloudWatch         │
   │ EBS Volume     │                │ Log Group          │
   │ - 8GB GP3      │                │ /aws/ec2/...       │
   │ - Encrypted    │                └─────▲──────────────┘
   │ - Delete: true │                      │ streams to
   └────────────────┘                      │ (1:1)
                                           │
                               ┌───────────┴──────────┐
                               │ CloudWatch Agent     │
                               │ - /var/log/messages  │
                               └──────────────────────┘

┌──────────────────┐      ┌─────────────────────┐
│ random_password  │─────►│ User Credentials    │
│ - 16 chars       │ gen  │ - username: devuser │
│ - special: true  │ (1:1)│ - password: ******  │
└──────────────────┘      └─────────────────────┘
                                    │
                                    │ applied by (1:1)
                                    │
                          ┌─────────▼──────────┐
                          │ User Data Script   │
                          │ - Create user      │
                          │ - Enable SSH       │
                          │ - Config CW agent  │
                          └────────────────────┘
```

## State Management

### Terraform State Structure

```hcl
# State hierarchy
terraform.tfstate
├── module.ec2_instance
│   ├── aws_instance.this
│   ├── aws_iam_role.this
│   ├── aws_iam_instance_profile.this
│   ├── aws_iam_role_policy_attachment.this
│   ├── aws_security_group.this
│   └── aws_vpc_security_group_ingress_rule.this
├── module.cloudwatch_log_group
│   └── aws_cloudwatch_log_group.this
├── data.aws_vpc.default
├── data.aws_subnets.default
└── random_password.devuser
```

### Computed Attributes

Attributes that are determined at runtime and not known during plan phase:

- `instance_id`: Generated by AWS during instance creation
- `public_ip`: Assigned from subnet's public IP pool
- `private_ip`: Assigned from subnet's CIDR range
- `availability_zone`: Selected by AWS based on capacity
- `volume_id`: Generated by AWS during EBS volume creation
- `security_group_id`: Generated by AWS during security group creation
- `iam_instance_profile_arn`: Generated by AWS during profile creation

### Dependencies

Terraform manages these implicit dependencies:

1. **VPC → Subnet**: Subnet data source depends on VPC ID
2. **VPC → Security Group**: Security group requires VPC ID
3. **Security Group → EC2 Instance**: Instance requires security group ID
4. **Subnet → EC2 Instance**: Instance requires subnet ID
5. **IAM Instance Profile → EC2 Instance**: Instance requires profile
6. **CloudWatch Log Group → EC2 Instance**: Log group must exist before agent starts
7. **Random Password → User Data**: Password must be generated before user data execution

Explicit dependency declarations in Terraform:

```hcl
depends_on = [
  module.cloudwatch_log_group,  # Ensure log group exists before instance launch
]
```

## Data Flow

### Instance Provisioning Flow

```
1. Terraform Plan Phase:
   ├── Query default VPC (data source)
   ├── Query default subnets (data source)
   ├── Generate random password (random_password)
   └── Resolve AMI from SSM parameter

2. Terraform Apply Phase:
   ├── Create CloudWatch log group
   ├── Create IAM role with CloudWatch policy
   ├── Create IAM instance profile
   ├── Create security group with SSH rule
   ├── Create EC2 instance with:
   │   ├── User data script (includes password)
   │   ├── IAM instance profile
   │   ├── Security group
   │   └── Root volume (8GB GP3 encrypted)
   └── Wait for instance to reach 'running' state

3. Instance Boot Phase:
   ├── Execute user data script:
   │   ├── Create devuser with generated password
   │   ├── Enable password authentication in sshd_config
   │   ├── Restart SSH service
   │   ├── Configure CloudWatch agent
   │   └── Start CloudWatch agent
   └── Begin streaming logs to CloudWatch

4. Operational Phase:
   ├── EC2 instance accepts SSH connections (port 22)
   ├── CloudWatch agent streams /var/log/messages
   └── Basic metrics sent to CloudWatch (5-min intervals)
```

### Log Data Flow

```
EC2 Instance
  └── /var/log/messages
      └── CloudWatch Agent
          └── CloudWatch Logs API
              └── Log Group: /aws/ec2/sandbox_public_ec2_dev
                  └── Log Stream: {instance_id}
                      └── Log Events (timestamped)
```

### Authentication Flow

```
SSH Client
  └── Connect to {public_ip}:22
      └── Security Group (ingress rule check)
          └── SSH Daemon (password authentication enabled)
              └── Validate devuser credentials
                  └── Grant shell access
```

## Validation Constraints

### Cross-Entity Constraints

1. **Security Group ↔ VPC**: Security group's VPC must match instance's VPC
2. **Instance ↔ Subnet**: Instance's VPC must match subnet's parent VPC
3. **Instance ↔ AMI**: AMI architecture (x86_64) must match instance type architecture
4. **Instance ↔ IAM Profile**: IAM role must have EC2 trust relationship
5. **Instance ↔ CloudWatch**: IAM profile must include CloudWatch permissions

### Infrastructure Quotas

- EC2 instance quota: Default 5 On-Demand t3.micro instances per region
- EBS volume quota: Default 300 volumes per region
- CloudWatch Logs quota: Unlimited log groups, 1MB/s ingestion per stream

## Backup and Recovery

### State Backup

- Terraform state stored in HCP Terraform workspace
- State encryption at rest provided by HCP Terraform
- State versioning enabled for rollback capability
- Sensitive values (password) encrypted in state

### Instance Recovery

**Recovery Scenarios**:

1. **Instance termination**: Re-run `terraform apply` to recreate
   - New instance ID, public IP, private IP
   - Same AMI, configuration, user credentials
   - CloudWatch log group persists (contains old instance logs)

2. **User data failure**: Access via AWS Systems Manager Session Manager
   - Troubleshoot using `/var/log/user-data.log`
   - Manually run user data commands if needed

3. **Password lost**: Retrieve from Terraform outputs
   - `terraform output devuser_password` (sensitive)
   - Or reset via `terraform taint random_password.devuser` + `terraform apply`

## Cost Attribution

### Resource Cost Mapping

| Entity | Monthly Cost (ap-southeast-1) | Cost Driver |
|--------|-------------------------------|-------------|
| EC2 Instance (t3.micro) | ~$7.50 | 730 hours × $0.0104/hour |
| EBS Volume (8GB GP3) | ~$0.80 | 8GB × $0.10/GB |
| Data Transfer (egress) | ~$0.00 | Minimal usage |
| CloudWatch Logs | ~$2-5 | 5GB free, $0.50/GB after |
| CloudWatch Metrics | ~$0.00 | Basic monitoring free |
| IAM | $0.00 | No charge |
| Security Group | $0.00 | No charge |
| **Total** | **~$10-15/month** | Well under $50 budget |

## Glossary

- **Data Source**: Read-only Terraform resource that queries existing infrastructure
- **Module**: Reusable Terraform configuration from private registry
- **User Data**: Initialization script executed once at instance first boot
- **Instance Profile**: IAM construct allowing EC2 to assume role permissions
- **SSM Parameter**: AWS Systems Manager parameter store value
- **CIDR Block**: IP address range in CIDR notation (e.g., 172.31.0.0/16)
- **Security Group**: Stateful firewall controlling network traffic
- **Log Stream**: Sequence of log events from a single source
- **Log Group**: Collection of log streams with shared settings
