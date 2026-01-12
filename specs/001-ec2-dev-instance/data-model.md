# Data Model: EC2 Development Instance Infrastructure

**Feature**: Public EC2 Development Instance  
**Branch**: `001-ec2-dev-instance`  
**Date**: 2025-01-12  
**Status**: Complete

---

## Overview

This document defines the data model for all infrastructure entities required to provision and manage a public EC2 development instance with password-based SSH authentication, security hardening, and monitoring capabilities.

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HCP Terraform Workspace                      │
│                    (sandbox_ec2_dev_instance)                        │
│                                                                       │
│  ┌─────────────────┐         ┌──────────────────┐                  │
│  │  AWS Provider   │────────▶│  Default VPC     │                  │
│  │   (us-east-1)   │         │   (data source)  │                  │
│  └─────────────────┘         └──────────────────┘                  │
│                                       │                              │
│                                       ▼                              │
│                              ┌──────────────────┐                   │
│                              │  Public Subnet   │                   │
│                              │   (data source)  │                   │
│                              └──────────────────┘                   │
│                                       │                              │
└───────────────────────────────────────┼──────────────────────────────┘
                                        │
                    ┌───────────────────┴────────────────────┐
                    │                                         │
                    ▼                                         ▼
         ┌─────────────────────┐                  ┌──────────────────────┐
         │  Security Group     │                  │  IAM Instance Profile │
         │  (ec2-dev-ssh-sg)   │                  │  (ec2-ssm-role)      │
         └─────────────────────┘                  └──────────────────────┘
                    │                                         │
                    │                  ┌──────────────────────┘
                    │                  │
                    └────────┬─────────┘
                             │
                             ▼
                  ┌─────────────────────────┐
                  │     EC2 Instance        │
                  │   (t3.micro, AL2023)    │
                  │                         │
                  │  • devuser account      │
                  │  • fail2ban service     │
                  │  • CloudWatch agent     │
                  │  • SSM agent            │
                  └─────────────────────────┘
                             │
                  ┌──────────┴──────────┐
                  │                      │
                  ▼                      ▼
         ┌─────────────────┐   ┌──────────────────────┐
         │   Elastic IP    │   │  CloudWatch Log      │
         │   (static IPv4) │   │  Group (ssh-auth)    │
         └─────────────────┘   └──────────────────────┘
                                         │
                                         ▼
                                ┌──────────────────────┐
                                │  CloudWatch Log      │
                                │  Stream (instance-id)│
                                └──────────────────────┘
```

---

## 1. AWS Provider Configuration

### Entity: `aws_provider`

**Purpose**: Configure AWS provider for resource provisioning in us-east-1 region.

**Attributes**:

| Attribute | Type | Description | Source | Required |
|-----------|------|-------------|--------|----------|
| `region` | string | AWS region for resource deployment | Variable (`var.aws_region`) | Yes |
| `default_tags` | map(string) | Default tags applied to all resources | Local values | No |

**Relationships**:
- **Provides authentication for**: All AWS resources
- **Credentials sourced from**: HCP Terraform workspace variable sets (dynamic credentials)

**Validation Rules**:
- Region must be valid AWS region code
- Dynamic credentials automatically configured via workspace variable sets

**Terraform Resource Type**: `provider "aws"`

**Constitution Compliance**: Section 3.1 (dynamic credentials from variable sets)

---

## 2. VPC & Networking (Data Sources)

### Entity: `aws_vpc.default`

**Purpose**: Reference existing default VPC for instance placement.

**Attributes**:

| Attribute | Type | Description | Source | Required |
|-----------|------|-------------|--------|----------|
| `id` | string | VPC identifier | AWS API lookup | Yes |
| `cidr_block` | string | VPC CIDR range | AWS API lookup | No |
| `default` | bool | Must be true (default VPC) | Filter condition | Yes |

**Relationships**:
- **Contains**: Public subnets
- **Referenced by**: Security group, EC2 instance

**Assumptions**: Default VPC exists in us-east-1 (A-001 from spec)

**Terraform Resource Type**: `data "aws_vpc"`

---

### Entity: `aws_subnets.public`

**Purpose**: Identify public subnets within default VPC for instance placement.

**Attributes**:

| Attribute | Type | Description | Source | Required |
|-----------|------|-------------|--------|----------|
| `ids` | list(string) | List of public subnet IDs | AWS API lookup | Yes |
| `vpc_id` | string | Parent VPC ID | Filter condition | Yes |
| `map_public_ip_on_launch` | bool | Must be true (public subnet) | Filter condition | Yes |

**Relationships**:
- **Parent**: Default VPC
- **Referenced by**: EC2 instance subnet placement

**Selection Logic**: First available public subnet from returned list

**Terraform Resource Type**: `data "aws_subnets"`

---

## 3. Amazon Machine Image (AMI)

### Entity: `aws_ami.amazon_linux_2023`

**Purpose**: Dynamically resolve latest Amazon Linux 2023 AMI for automatic security updates.

**Attributes**:

| Attribute | Type | Description | Source | Required |
|-----------|------|-------------|--------|----------|
| `id` | string | AMI identifier | AWS API lookup | Yes |
| `name` | string | AMI name pattern | Filter (`al2023-ami-*-x86_64`) | Yes |
| `owner` | string | AMI owner account | Filter (`amazon`) | Yes |
| `virtualization_type` | string | Must be `hvm` | Filter condition | Yes |
| `most_recent` | bool | Select latest version | Lookup parameter | Yes |

**Relationships**:
- **Referenced by**: EC2 instance configuration
- **Maintained by**: AWS (automatic updates)

**Update Strategy**: Data source resolves latest AMI on each Terraform run

**Pre-Installed Components**:
- AWS Systems Manager agent (SSM agent)
- CloudWatch agent package
- Python 3.9+
- systemd init system

**Terraform Resource Type**: `data "aws_ami"`

**Constitution Compliance**: FR-001 (latest Amazon Linux 2023 via data source)

---

## 4. Security Group

### Entity: `aws_security_group.ec2_dev_ssh`

**Purpose**: Network firewall rules controlling traffic to EC2 instance.

**Attributes**:

| Attribute | Type | Description | Constraint | Required |
|-----------|------|-------------|------------|----------|
| `name` | string | Security group name | Unique within VPC | Yes |
| `description` | string | Purpose description | Max 255 chars | Yes |
| `vpc_id` | string | Parent VPC identifier | Must exist | Yes |
| `ingress` | list(object) | Inbound traffic rules | See below | Yes |
| `egress` | list(object) | Outbound traffic rules | See below | Yes |
| `tags` | map(string) | Resource tags | Standard tags | Yes |

**Ingress Rules**:

| Rule | Protocol | Port | Source CIDR | Description |
|------|----------|------|-------------|-------------|
| SSH | tcp | 22 | 0.0.0.0/0 | SSH access from anywhere (development only) |

**Egress Rules**:

| Rule | Protocol | Port | Destination | Description |
|------|----------|------|-------------|-------------|
| All | -1 | 0 | 0.0.0.0/0 | Allow all outbound traffic |

**Relationships**:
- **Parent**: Default VPC
- **Attached to**: EC2 instance network interface
- **Referenced in**: EC2 instance configuration

**Security Posture**:
- Public SSH access (0.0.0.0/0) - documented risk for development
- Tagged with `PublicAccess=true` for audit visibility
- Mitigated by fail2ban, strong passwords, CloudWatch monitoring

**Validation Rules**:
- VPC must exist before security group creation
- Ingress rules must include port 22 (FR-004)
- Source CIDR must be 0.0.0.0/0 per requirement

**Terraform Resource Type**: `resource "aws_security_group"`

**Constitution Compliance**: Section IV (Least Privilege by Default) - justified exception for development

---

## 5. IAM Resources for Session Manager

### Entity: `aws_iam_role.ec2_ssm_role`

**Purpose**: IAM role enabling EC2 instance to communicate with AWS Systems Manager for emergency access.

**Attributes**:

| Attribute | Type | Description | Constraint | Required |
|-----------|------|-------------|------------|----------|
| `name` | string | IAM role name | Globally unique in account | Yes |
| `assume_role_policy` | json | Trust policy for EC2 service | Valid JSON policy | Yes |
| `description` | string | Role purpose | Max 1000 chars | No |
| `tags` | map(string) | Resource tags | Standard tags | Yes |

**Trust Policy (Assume Role)**:
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

**Relationships**:
- **Attached policy**: `AmazonSSMManagedInstanceCore` (managed policy)
- **Used by**: IAM instance profile
- **Enables**: Session Manager, Run Command, Parameter Store read

**Terraform Resource Type**: `resource "aws_iam_role"`

**Constitution Compliance**: FR-007a (Session Manager backup access)

---

### Entity: `aws_iam_role_policy_attachment.ssm_managed_instance_core`

**Purpose**: Attach AWS-managed SSM policy to IAM role.

**Attributes**:

| Attribute | Type | Description | Constraint | Required |
|-----------|------|-------------|------------|----------|
| `role` | string | IAM role name | Must exist | Yes |
| `policy_arn` | string | AWS managed policy ARN | Valid ARN | Yes |

**Managed Policy ARN**: `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`

**Granted Permissions**:
- `ssm:UpdateInstanceInformation`
- `ssmmessages:CreateControlChannel`
- `ssmmessages:CreateDataChannel`
- `ssmmessages:OpenControlChannel`
- `ssmmessages:OpenDataChannel`
- `ec2messages:GetMessages`

**Relationships**:
- **Parent**: IAM role for EC2
- **Policy maintainer**: AWS (managed policy)

**Terraform Resource Type**: `resource "aws_iam_role_policy_attachment"`

---

### Entity: `aws_iam_instance_profile.ec2_profile`

**Purpose**: Instance profile wrapper for IAM role attachment to EC2 instance.

**Attributes**:

| Attribute | Type | Description | Constraint | Required |
|-----------|------|-------------|------------|----------|
| `name` | string | Instance profile name | Globally unique in account | Yes |
| `role` | string | IAM role name | Must exist | Yes |
| `tags` | map(string) | Resource tags | Standard tags | No |

**Relationships**:
- **Parent**: IAM role
- **Attached to**: EC2 instance
- **Enables**: Instance to assume IAM role

**Terraform Resource Type**: `resource "aws_iam_instance_profile"`

---

## 6. EC2 Instance

### Entity: `aws_instance.dev`

**Purpose**: Primary compute resource running development workloads with SSH access.

**Attributes**:

| Attribute | Type | Description | Source | Required | Validation |
|-----------|------|-------------|--------|----------|------------|
| `ami` | string | Amazon Machine Image ID | Data source lookup | Yes | Must be AL2023 AMI |
| `instance_type` | string | Instance size | Variable (`var.instance_type`) | Yes | Must be `t3.micro` |
| `subnet_id` | string | Subnet for placement | Data source (first public subnet) | Yes | Must be public subnet |
| `vpc_security_group_ids` | list(string) | Security groups | Security group resource | Yes | Must include SSH SG |
| `iam_instance_profile` | string | IAM instance profile name | IAM profile resource | Yes | Must enable SSM |
| `user_data` | string | Bootstrap script | Template file | Yes | See user-data section |
| `root_block_device` | object | Root volume configuration | See below | Yes | Encryption required |
| `monitoring` | bool | CloudWatch detailed monitoring | Variable (`var.enable_monitoring`) | Yes | Must be false (basic) |
| `tags` | map(string) | Resource tags | Merged from variables | Yes | Standard tags required |

**Root Block Device Configuration**:

| Attribute | Type | Value | Description |
|-----------|------|-------|-------------|
| `volume_type` | string | `gp3` | General Purpose SSD |
| `volume_size` | number | 30 | GB (minimum for AL2023) |
| `encrypted` | bool | `true` | Encryption at rest |
| `delete_on_termination` | bool | `true` | Cleanup on destroy |

**Relationships**:
- **Placed in**: Default VPC public subnet
- **Protected by**: Security group (SSH)
- **Authenticated via**: IAM instance profile
- **Monitored by**: CloudWatch (basic metrics + log streaming)
- **Addressed via**: Elastic IP

**State Transitions**:
1. `pending` → Instance launching
2. `running` → Instance operational, user-data executing
3. `stopping` → Instance shutting down
4. `stopped` → Instance halted (incurs EIP charges)
5. `terminating` → Instance being destroyed
6. `terminated` → Instance deleted

**Lifecycle Configuration**:
- **Create timeout**: 10 minutes
- **Update behavior**: Replace instance (triggers destroy/create)
- **Destroy behavior**: Terminate and release resources

**Terraform Resource Type**: `resource "aws_instance"`

**Constitution Compliance**: FR-001, FR-003, FR-005, FR-006

---

## 7. User Data Script

### Entity: `user_data_script`

**Purpose**: Bootstrap script executed during instance launch to configure SSH, security, and monitoring.

**Structure**: Bash script with cloud-init compatibility

**Components**:

#### 7.1 System Updates
```bash
#!/bin/bash
set -e
yum update -y
```

#### 7.2 User Account Creation
```bash
# Create devuser with sudo privileges (FR-007)
useradd -m -s /bin/bash devuser
usermod -aG wheel devuser

# Configure password expiry (FR-017)
chage -M 90 -m 1 -W 7 devuser
```

#### 7.3 Password Policy Configuration
```bash
# PAM password quality requirements (FR-012, FR-013)
cat > /etc/security/pwquality.conf <<EOF
minlen = 14
minclass = 4
maxrepeat = 2
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
EOF
```

#### 7.4 SSH Hardening
```bash
# Configure SSH daemon (FR-008, FR-009, FR-011)
cat >> /etc/ssh/sshd_config <<EOF
PasswordAuthentication yes
PubkeyAuthentication no
PermitRootLogin no
ClientAliveInterval 900
ClientAliveCountMax 2
MaxAuthTries 5
EOF

systemctl restart sshd
```

#### 7.5 fail2ban Installation
```bash
# Install and configure fail2ban (FR-014, FR-015)
yum install -y fail2ban fail2ban-systemd

cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
maxretry = 5
findtime = 600
bantime = 3600
EOF

systemctl enable fail2ban
systemctl start fail2ban
```

#### 7.6 CloudWatch Agent Setup
```bash
# Install and configure CloudWatch agent (FR-019)
yum install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [{
          "file_path": "/var/log/secure",
          "log_group_name": "/aws/ec2/dev-instance/ssh-auth",
          "log_stream_name": "{instance_id}",
          "timezone": "UTC"
        }]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

**Execution Environment**:
- User: `root`
- Working directory: `/root`
- Logs: `/var/log/cloud-init.log`, `/var/log/cloud-init-output.log`
- Timeout: 10 minutes (configurable)

**Dependencies**:
- Internet connectivity (yum repositories)
- CloudWatch log group pre-created via Terraform
- IAM instance profile for CloudWatch permissions

**Idempotency**: Script designed for single execution; re-runs may cause errors

**Terraform Implementation**: Base64-encoded string passed to `user_data` attribute

---

## 8. Elastic IP

### Entity: `aws_eip.dev_instance`

**Purpose**: Static public IPv4 address ensuring consistent access across instance reboots.

**Attributes**:

| Attribute | Type | Description | Constraint | Required |
|-----------|------|-------------|------------|----------|
| `domain` | string | Address allocation domain | Must be `vpc` | Yes |
| `instance` | string | Associated EC2 instance ID | Must be running instance | Yes |
| `tags` | map(string) | Resource tags | Standard tags | Yes |

**Relationships**:
- **Attached to**: EC2 instance primary network interface
- **Allocated from**: AWS public IP pool

**Lifecycle**:
- **Allocation**: When Terraform creates resource
- **Association**: Immediately after instance reaches `running` state
- **Persistence**: Survives instance reboots, remains associated
- **Cost**: $0/month while attached; $0.01/hour if unattached
- **Release**: On Terraform destroy

**Outputs**:
- Public IP address for SSH connection
- Allocation ID for reference

**Validation Rules**:
- Instance must be in `running` state before association
- Account EIP quota must have available capacity (default 5 per region)

**Terraform Resource Type**: `resource "aws_eip"`

**Constitution Compliance**: FR-002, FR-023

---

## 9. CloudWatch Resources

### Entity: `aws_cloudwatch_log_group.ssh_auth_logs`

**Purpose**: Centralized log storage for SSH authentication events.

**Attributes**:

| Attribute | Type | Description | Constraint | Required |
|-----------|------|-------------|------------|----------|
| `name` | string | Log group identifier | Must start with `/aws/` | Yes |
| `retention_in_days` | number | Log retention period | Must be 7 (FR-020) | Yes |
| `kms_key_id` | string | Encryption key ARN | Optional for encryption | No |
| `tags` | map(string) | Resource tags | Standard tags | Yes |

**Log Group Naming**: `/aws/ec2/dev-instance/ssh-auth`

**Relationships**:
- **Contains**: CloudWatch log streams (one per instance)
- **Populated by**: CloudWatch agent running on EC2 instance
- **Accessed by**: DevOps engineers for security monitoring

**Retention Policy**:
- Duration: 7 days (168 hours)
- Auto-deletion: Logs older than 7 days automatically purged
- Cost optimization: Minimizes storage charges for development

**Log Event Structure**:
```json
{
  "timestamp": "2025-01-12T10:30:45Z",
  "message": "Accepted password for devuser from 203.0.113.45 port 54321 ssh2",
  "ingestionTime": 1705060245000,
  "logStreamName": "i-0123456789abcdef0"
}
```

**Expected Volume**:
- ~50-100 log events per day (typical development usage)
- ~100-200 MB per month before retention purge

**Terraform Resource Type**: `resource "aws_cloudwatch_log_group"`

**Constitution Compliance**: FR-019, FR-020

---

### Entity: `aws_cloudwatch_log_stream` (implicit)

**Purpose**: Instance-specific stream within log group for SSH authentication events.

**Attributes**:

| Attribute | Type | Description | Source | Required |
|-----------|------|-------------|--------|----------|
| `name` | string | Stream identifier | Instance ID (`{instance_id}`) | Yes |
| `log_group_name` | string | Parent log group | Log group resource | Yes |

**Creation**: Automatically created by CloudWatch agent on first log event

**Naming Pattern**: EC2 instance ID (e.g., `i-0123456789abcdef0`)

**Lifecycle**:
- Created: On first log event from instance
- Active: While instance runs and logs events
- Deleted: When log group retention purges old events

**Terraform Management**: Not explicitly created (managed by CloudWatch agent)

---

## 10. Operating System User Account

### Entity: `devuser` (OS-level)

**Purpose**: Non-root user account with sudo privileges for SSH access.

**Attributes**:

| Attribute | Type | Description | Constraint | Managed By |
|-----------|------|-------------|------------|------------|
| `username` | string | Account login name | Must be `devuser` | user-data script |
| `password` | string | Encrypted password hash | 14+ chars, complexity rules | Operator (via Session Manager) |
| `uid` | number | User ID | Auto-assigned by OS | useradd command |
| `gid` | number | Primary group ID | Auto-assigned by OS | useradd command |
| `home_directory` | string | Home directory path | `/home/devuser` | useradd command |
| `shell` | string | Login shell | `/bin/bash` | useradd command |
| `groups` | list(string) | Supplementary groups | `[devuser, wheel]` | usermod command |
| `password_expiry` | date | Password expiration date | 90 days from set | chage command |

**Password Policy Enforcement**:

| Policy | Value | Enforcement Mechanism |
|--------|-------|----------------------|
| Minimum length | 14 characters | `/etc/security/pwquality.conf` |
| Character classes | 4 (upper, lower, digit, special) | PAM pwquality module |
| Max repeating | 2 characters | PAM pwquality module |
| Digit requirement | At least 1 | PAM pwquality module |
| Uppercase requirement | At least 1 | PAM pwquality module |
| Lowercase requirement | At least 1 | PAM pwquality module |
| Special char requirement | At least 1 | PAM pwquality module |
| Expiry period | 90 days | `chage -M 90` |
| Expiry warning | 7 days before | `chage -W 7` |

**Sudo Privileges**:
- Group membership: `wheel`
- Permissions: Full sudo access via `/etc/sudoers.d/` configuration
- Password required: Yes (NOPASSWD not configured)

**Authentication Methods**:
- SSH password authentication: Enabled (primary method)
- SSH key authentication: Disabled (PubkeyAuthentication no)
- Session Manager: Available as fallback (IAM-based)

**Lifecycle**:
- Creation: During user-data script execution
- Password set: Post-deployment via Session Manager by operator
- Deletion: On instance termination

**Terraform Management**: Not directly managed (created via user-data script)

**Constitution Compliance**: FR-007, FR-012, FR-013, FR-017

---

## 11. Security Service: fail2ban

### Entity: `fail2ban` (service)

**Purpose**: Intrusion prevention system blocking IPs after repeated SSH authentication failures.

**Configuration Attributes**:

| Attribute | Type | Value | Description |
|-----------|------|-------|-------------|
| `enabled` | bool | `true` | Service active status |
| `port` | string | `ssh` | Monitored service (port 22) |
| `logpath` | string | `/var/log/secure` | Auth log file location |
| `maxretry` | number | `5` | Failed attempts threshold |
| `findtime` | number | `600` | Time window in seconds (10 min) |
| `bantime` | number | `3600` | Block duration in seconds (1 hour) |

**Operational Behavior**:

1. **Monitoring**: Continuously tails `/var/log/secure` for authentication events
2. **Detection**: Counts failed SSH login attempts per source IP
3. **Action**: After 5 failures within 10 minutes, adds iptables DROP rule
4. **Duration**: IP remains blocked for 1 hour
5. **Unblocking**: Automatic removal after ban time expires

**Protected Scenarios**:
- Brute-force password guessing attacks
- Credential stuffing attempts
- Distributed SSH scanning

**Limitations**:
- Slow distributed attacks (below 5 attempts/10 min) not blocked
- VPN/proxy users may share IPs (false positive risk)
- Requires manual unblocking if legitimate user locked out (via Session Manager)

**Lifecycle**:
- Installation: Via user-data script during instance launch
- Startup: Automatic via systemd on boot
- Configuration: `/etc/fail2ban/jail.local`
- Logs: `/var/log/fail2ban.log`

**Terraform Management**: Not directly managed (installed via user-data script)

**Constitution Compliance**: FR-014, FR-015, FR-016

---

## 12. Variables

### Input Variables

| Variable Name | Type | Description | Default | Validation | Required |
|--------------|------|-------------|---------|------------|----------|
| `aws_region` | string | AWS region for deployment | `"us-east-1"` | Must be valid AWS region | Yes |
| `instance_type` | string | EC2 instance type | `"t3.micro"` | Must be t3.* family | Yes |
| `root_volume_size` | number | Root volume size in GB | `30` | Min 30, Max 100 | Yes |
| `environment` | string | Environment name | `"development"` | Must be dev/staging/prod | Yes |
| `project_name` | string | Project identifier | `"ec2-dev-instance"` | Max 32 chars | Yes |
| `enable_monitoring` | bool | Enable detailed monitoring | `false` | N/A | Yes |
| `ssh_allowed_cidr_blocks` | list(string) | SSH source CIDR ranges | `["0.0.0.0/0"]` | Valid CIDR notation | Yes |
| `additional_tags` | map(string) | Extra resource tags | `{}` | Valid tag format | No |

### Local Values

| Local Name | Type | Description | Source |
|-----------|------|-------------|--------|
| `common_tags` | map(string) | Standard tags for all resources | Merged from variables |
| `security_group_name` | string | Security group name | Constructed from project/environment |
| `iam_role_name` | string | IAM role name | Constructed from project/environment |
| `instance_name` | string | EC2 instance name tag | Constructed from project/environment |

**Standard Tags Structure**:
```hcl
{
  Environment   = var.environment
  Project       = var.project_name
  ManagedBy     = "terraform"
  PublicAccess  = "true"
  Owner         = "platform-team"
}
```

---

## 13. Outputs

### Output Values

| Output Name | Type | Description | Sensitive | Purpose |
|------------|------|-------------|-----------|---------|
| `instance_id` | string | EC2 instance identifier | No | AWS Console lookup, Session Manager |
| `instance_public_ip` | string | Elastic IP address | No | SSH connection string |
| `instance_private_ip` | string | VPC private IP address | No | Internal networking reference |
| `security_group_id` | string | Security group identifier | No | Rule auditing, modifications |
| `iam_role_arn` | string | IAM role ARN | No | Permission verification |
| `log_group_name` | string | CloudWatch log group name | No | Log streaming verification |
| `ssh_connection_command` | string | SSH command template | No | User documentation |

**Example Output Values**:
```hcl
instance_id              = "i-0123456789abcdef0"
instance_public_ip       = "203.0.113.45"
instance_private_ip      = "172.31.32.100"
security_group_id        = "sg-0abcdef1234567890"
iam_role_arn            = "arn:aws:iam::123456789012:role/ec2-dev-instance-ssm-role"
log_group_name          = "/aws/ec2/dev-instance/ssh-auth"
ssh_connection_command  = "ssh devuser@203.0.113.45"
```

---

## 14. State Management

### Terraform State Schema

**Sensitive Attributes** (never stored in state):
- devuser password (set via Session Manager post-deployment)
- AWS credentials (provided via workspace variable sets)

**Stored Attributes**:
- All resource IDs and ARNs
- Public and private IP addresses
- Security group rule configurations
- IAM role trust policies
- User-data script content (no secrets)

**State Backend Configuration**:
- Backend: HCP Terraform Cloud
- Organization: `ravi-panchal-org`
- Workspace: `sandbox_ec2_dev_instance`
- Encryption: Enabled (Terraform Cloud default)
- Versioning: Enabled (Terraform Cloud default)

**State Locking**: Automatic via HCP Terraform workspace

---

## 15. Data Flow Diagram

### SSH Authentication Log Flow

```
┌─────────────────┐
│  SSH Client     │
│  (workstation)  │
└────────┬────────┘
         │ SSH connection attempt
         ▼
┌─────────────────────────┐
│  Security Group         │ ◀── Port 22 ingress rule
│  (ec2-dev-ssh-sg)       │
└────────┬────────────────┘
         │ Allowed
         ▼
┌─────────────────────────┐
│  EC2 Instance           │
│  ┌──────────────────┐   │
│  │  SSH Daemon      │   │ ◀── Password authentication
│  │  (port 22)       │   │
│  └────────┬─────────┘   │
│           │              │
│           ▼              │
│  ┌──────────────────┐   │
│  │  PAM Auth        │   │ ◀── Password policy check
│  │  (pwquality)     │   │
│  └────────┬─────────┘   │
│           │              │
│           ▼              │
│  ┌──────────────────┐   │
│  │  /var/log/secure │   │ ◀── Auth event logged
│  └────────┬─────────┘   │
│           │              │
│           ├──────────────┼─────────────┐
│           │              │             │
│           ▼              │             ▼
│  ┌──────────────────┐   │    ┌───────────────┐
│  │  fail2ban        │   │    │  CloudWatch   │
│  │  (monitoring)    │   │    │  Agent        │
│  └────────┬─────────┘   │    └───────┬───────┘
│           │              │            │
└───────────┼──────────────┘            │
            │                           │
            │ Failed attempts           │ Log streaming
            ▼                           ▼
   ┌────────────────┐        ┌──────────────────────┐
   │  iptables      │        │  CloudWatch Log      │
   │  (DROP rule)   │        │  Group (ssh-auth)    │
   └────────────────┘        └──────────────────────┘
```

---

## 16. Entity Validation Matrix

| Entity | Creation Order | Dependencies | Validation Gates | Rollback Safe |
|--------|---------------|--------------|------------------|---------------|
| AWS Provider | 1 | None | Credential validation | N/A |
| VPC (data) | 2 | Provider | Default VPC exists | N/A |
| Subnets (data) | 3 | VPC | Public subnet exists | N/A |
| AMI (data) | 2 | Provider | AL2023 AMI available | N/A |
| Security Group | 4 | VPC | VPC exists | Yes |
| IAM Role | 4 | Provider | Trust policy valid | Yes |
| IAM Policy Attachment | 5 | IAM Role | Role exists | Yes |
| IAM Instance Profile | 6 | IAM Role | Role exists | Yes |
| CloudWatch Log Group | 4 | Provider | Name unique | Yes |
| EC2 Instance | 7 | All above | User-data valid | Yes |
| Elastic IP | 8 | EC2 Instance | Instance running | Yes |

**Validation Gates**:
- Terraform validate (syntax check)
- Terraform plan (dependency resolution)
- Pre-commit hooks (linting, formatting)
- Constitution compliance check (via code-quality-judge)

---

## Conclusion

This data model defines all infrastructure entities, their attributes, relationships, validation rules, and lifecycle management for the EC2 development instance feature. The model aligns with:

- Feature specification requirements (FR-001 through FR-025)
- Constitution security standards (Section IV)
- AWS best practices for development environments
- HCP Terraform remote state management

**Next Steps**: Generate API contracts and quickstart documentation (Phase 1 continuation).
