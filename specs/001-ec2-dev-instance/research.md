# Research: EC2 Development Instance with Password-Based SSH

**Feature**: Public EC2 Development Instance  
**Branch**: `001-ec2-dev-instance`  
**Date**: 2025-01-12  
**Status**: Complete

---

## Overview

This document captures technical research and decision rationale for implementing a public EC2 development instance with password-based SSH authentication, CloudWatch monitoring, and security hardening.

---

## 1. Terraform Module Strategy

### Decision: Direct Resource Implementation (No Custom Modules)

**Rationale**:
- Single EC2 instance deployment with straightforward requirements
- No complex reusability patterns needed for this development instance
- Inline resources provide clarity and simplicity for maintenance
- Constitution allows inline approach for simple use cases (OOS-019 in spec)

**Alternatives Considered**:
1. **Terraform AWS EC2 Module** (terraform-aws-modules/ec2-instance/aws)
   - Rejected: Constitution mandates private registry modules only (Section 1.1)
   - Not available in private registry based on current project setup
   
2. **Custom Private Module**
   - Rejected: Over-engineering for single-instance development use case
   - Future consideration if multi-instance patterns emerge

**Implementation Approach**:
- Direct AWS provider resources in `main.tf`
- Organized by logical grouping: networking, compute, monitoring, IAM
- Clear variable definitions with validation blocks
- Comprehensive outputs for downstream consumption

---

## 2. AMI Selection & Management

### Decision: Dynamic Amazon Linux 2023 AMI Lookup

**Rationale**:
- Automatic security updates through AWS-managed AMI releases
- No custom AMI maintenance overhead
- AWS pre-installs SSM agent for Session Manager support
- Constitution preference for standard AWS resources (A-005 in spec)

**Implementation Pattern**:
```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

**Alternatives Considered**:
1. **Hardcoded AMI ID**
   - Rejected: Requires manual updates for security patches
   - Becomes stale and introduces security vulnerabilities
   
2. **Custom Hardened AMI**
   - Rejected: Maintenance burden (OOS-008 in spec)
   - User-data script provides equivalent security at lower complexity

---

## 3. Password-Based SSH Configuration

### Decision: User-Data Script for SSH Hardening

**Rationale**:
- Centralized configuration in single user-data script
- Idempotent operations suitable for cloud-init
- No manual post-deployment configuration required
- Password set via Session Manager (not in code/state)

**Key Configuration Elements**:

#### 3.1 User Account Creation
```bash
# Create devuser with sudo privileges
useradd -m -s /bin/bash devuser
usermod -aG wheel devuser

# Password policy enforcement
chage -M 90 -m 1 -W 7 devuser  # 90-day expiry, 7-day warning
```

#### 3.2 SSH Daemon Configuration
```bash
# /etc/ssh/sshd_config modifications
PasswordAuthentication yes
PubkeyAuthentication no
PermitRootLogin no
ClientAliveInterval 900  # 15-minute keepalive (30-min timeout via 2 intervals)
ClientAliveCountMax 2
MaxAuthTries 5
```

#### 3.3 PAM Password Complexity
```bash
# /etc/security/pwquality.conf
minlen = 14
minclass = 4  # Upper, lower, digit, special
maxrepeat = 2
dcredit = -1  # At least 1 digit
ucredit = -1  # At least 1 uppercase
lcredit = -1  # At least 1 lowercase
ocredit = -1  # At least 1 special character
```

**Alternatives Considered**:
1. **AWS Secrets Manager for Password Storage**
   - Rejected: Password should be operator-controlled via Session Manager
   - Avoids storing credentials in any AWS service or Terraform state
   
2. **SSH Key Pairs with Enforced Passwords**
   - Rejected: Requirement explicitly specifies password-only (FR-008, FR-009)

---

## 4. Security Hardening with fail2ban

### Decision: fail2ban Installation via User-Data

**Rationale**:
- Industry-standard SSH brute-force protection
- Automatic IP blocking after threshold violations
- Minimal performance overhead on t3.micro instance
- Well-documented for Amazon Linux

**Implementation Configuration**:
```bash
# Install fail2ban
yum install -y fail2ban fail2ban-systemd

# Configure SSH jail
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
maxretry = 5
findtime = 600   # 10 minutes
bantime = 3600   # 1 hour
EOF

# Enable and start service
systemctl enable fail2ban
systemctl start fail2ban
```

**Key Parameters**:
- **maxretry**: 5 failed attempts (FR-015)
- **findtime**: 10 minutes (600 seconds) window
- **bantime**: 1 hour (3600 seconds) block duration
- **logpath**: `/var/log/secure` (Amazon Linux auth log location)

**Alternatives Considered**:
1. **AWS WAF with IP Rate Limiting**
   - Rejected: SSH operates at Layer 4; WAF is Layer 7 only
   - Doesn't protect against SSH protocol attacks
   
2. **Security Groups with Dynamic Updates**
   - Rejected: Complex automation, potential for lockout
   - fail2ban provides battle-tested host-based protection

---

## 5. AWS Systems Manager Session Manager

### Decision: IAM Instance Profile with AmazonSSMManagedInstanceCore

**Rationale**:
- Emergency fallback access if SSH is blocked by fail2ban
- No additional ports or security group rules required
- IAM-based authentication (no credentials on instance)
- AWS-managed policy simplifies permission management

**Implementation Pattern**:
```hcl
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-dev-instance-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-dev-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
```

**Key Capabilities Enabled**:
- Session Manager console/CLI access
- Run Command for emergency password reset
- Parameter Store access (if needed for future secrets)
- CloudWatch Logs integration support

**Alternatives Considered**:
1. **Custom IAM Policy**
   - Rejected: AWS-managed policy provides right-sized permissions
   - Reduces maintenance burden and misconfiguration risk
   
2. **No Session Manager (SSH-only access)**
   - Rejected: Creates single point of failure (FR-007a requirement)

---

## 6. CloudWatch Monitoring Integration

### Decision: CloudWatch Agent via User-Data with Structured Configuration

**Rationale**:
- Real-time SSH authentication log streaming
- Centralized visibility for security events
- 7-day retention balances cost and operational needs
- Basic metrics included at no additional cost

**CloudWatch Agent Configuration**:

#### 6.1 Installation
```bash
# Install CloudWatch agent (pre-packaged in AL2023)
yum install -y amazon-cloudwatch-agent

# Configure agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/secure",
            "log_group_name": "/aws/ec2/dev-instance/ssh-auth",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# Start agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

#### 6.2 Log Group Configuration
```hcl
resource "aws_cloudwatch_log_group" "ssh_auth_logs" {
  name              = "/aws/ec2/dev-instance/ssh-auth"
  retention_in_days = 7  # Cost optimization for dev (FR-020)

  tags = {
    Environment = "development"
    Purpose     = "ssh-authentication-logs"
  }
}
```

**Cost Analysis**:
- Basic monitoring: Included (5-minute metrics)
- Log ingestion: ~$0.50/GB (expected 100-200 MB/month)
- Log storage: 7-day retention minimizes accumulation
- Total estimated: $0.50-1.00/month

**Alternatives Considered**:
1. **Detailed Monitoring (1-minute metrics)**
   - Rejected: $2/month added cost not justified for development
   - 5-minute granularity sufficient per constitution (FR-024)
   
2. **Third-Party Logging (Splunk, Datadog)**
   - Rejected: Over-engineering for single development instance
   - CloudWatch provides AWS-native integration

---

## 7. Network Architecture

### Decision: Default VPC with Elastic IP

**Rationale**:
- Default VPC exists in all AWS accounts (A-001 assumption)
- Public subnet enables direct internet connectivity
- Elastic IP ensures consistent access across reboots
- Simplifies DNS and firewall rules on client side

**Network Components**:

#### 7.1 VPC & Subnet Selection
```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}
```

#### 7.2 Security Group Design
```hcl
resource "aws_security_group" "ec2_dev_ssh" {
  name_description = "Allow SSH access to development instance"
  vpc_id          = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere (development only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ec2-dev-instance-ssh-sg"
    Environment = "development"
    PublicAccess = "true"  # Explicit security posture documentation
  }
}
```

#### 7.3 Elastic IP Attachment
```hcl
resource "aws_eip" "dev_instance" {
  domain = "vpc"
  instance = aws_instance.dev.id

  tags = {
    Name        = "ec2-dev-instance-eip"
    Environment = "development"
  }
}
```

**Security Considerations**:
- 0.0.0.0/0 SSH access documented as accepted risk (RISK-001)
- Mitigations: fail2ban, strong passwords, CloudWatch monitoring
- Tagged with `PublicAccess=true` for audit visibility

**Alternatives Considered**:
1. **Custom VPC with Private Subnets + Bastion**
   - Rejected: Over-engineering for development (OOS-003 in spec)
   - Requirement explicitly states public accessibility
   
2. **IP Allowlist in Security Group**
   - Rejected: Requirement specifies 0.0.0.0/0 access (FR-004)
   - Future consideration flagged (FC-002)

---

## 8. Cost Optimization Strategy

### Decision: t3.micro with Basic Monitoring and 7-Day Log Retention

**Cost Breakdown**:

| Component | Configuration | Monthly Cost |
|-----------|--------------|--------------|
| EC2 Instance | t3.micro (24/7) | $7.50 |
| Elastic IP | Attached to running instance | $0.00 |
| CloudWatch Basic | 5-minute metrics | $0.00 (included) |
| CloudWatch Logs | 7-day retention, ~150 MB | $0.50 |
| Data Transfer | SSH traffic (<1 GB) | $0.10 |
| **Total** | | **~$8.10/month** |

**Budget Compliance**: Well within $50 monthly budget (SC-005)

**Optimization Decisions**:
1. **t3.micro vs. t3.small**
   - t3.micro sufficient for SSH and light development
   - 10% baseline CPU adequate for workload
   - Saves $7.50/month compared to t3.small
   
2. **7-Day Log Retention**
   - Balances operational visibility with storage costs
   - Reduces monthly log storage to ~$0.30
   
3. **Basic vs. Detailed Monitoring**
   - 5-minute metrics adequate for development
   - Saves $2/month per instance

**Cost Risks**:
- RISK-007: Data exfiltration could spike transfer costs
- RISK-008: Stopping instance triggers EIP charges ($0.01/hour)

---

## 9. HCP Terraform Integration

### Decision: Remote Execution with Cloud Backend

**Configuration**:
```hcl
# override.tf
terraform {
  cloud {
    organization = "ravi-panchal-org"
    
    workspaces {
      name = "sandbox_ec2_dev_instance"
    }
  }
}
```

**Workspace Strategy**:
- **Development**: `sandbox_ec2_dev_instance` (pre-configured)
- **Branch Mapping**: `001-ec2-dev-instance` → sandbox workspace
- **Variable Management**: AWS credentials via workspace variable sets
- **State**: Remotely stored with encryption and versioning

**Constitution Compliance**:
- Section 2.1: HCP Terraform prerequisites validated
- Section 4.1: Pre-provisioned workspace (not AI-created)
- Section 3.1: Dynamic credentials from variable sets

---

## 10. Testing & Validation Strategy

### Phase 1: Syntax & Configuration Validation
```bash
terraform init
terraform validate
terraform fmt -check
tflint
pre-commit run --all-files
```

### Phase 2: Plan Verification
```bash
terraform plan -out=plan.tfplan
# Review: EC2 instance, security group, EIP, IAM role, log group
```

### Phase 3: Deployment & SSH Testing
```bash
terraform apply plan.tfplan

# Wait for user-data completion (~3-5 minutes)
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Test 1: SSH connection with correct password
ssh devuser@$INSTANCE_IP

# Test 2: fail2ban protection (expect 5th attempt to be blocked)
for i in {1..6}; do ssh devuser@$INSTANCE_IP; done

# Test 3: Session Manager fallback
aws ssm start-session --target $(terraform output -raw instance_id)
```

### Phase 4: Monitoring Validation
```bash
# Verify CloudWatch log stream created
aws logs describe-log-streams \
  --log-group-name /aws/ec2/dev-instance/ssh-auth

# Check for SSH authentication events
aws logs tail /aws/ec2/dev-instance/ssh-auth --follow
```

### Acceptance Criteria Mapping:
- **SC-001**: Deployment completes < 5 minutes
- **SC-002**: SSH connection succeeds < 10 seconds
- **SC-003**: fail2ban blocks after 5 failed attempts
- **SC-004**: CloudWatch events appear < 2 minutes

---

## 11. Security Hardening Checklist

### Implemented Controls:
- [x] Password complexity requirements (14+ chars, 4 character classes)
- [x] Password expiry (90 days with 7-day warning)
- [x] fail2ban automatic IP blocking (5 attempts/10 min = 1 hour block)
- [x] SSH session timeout (30 minutes idle)
- [x] Disabled root login via SSH
- [x] Disabled key-based authentication
- [x] CloudWatch authentication log streaming
- [x] Session Manager emergency access
- [x] Security group scoped to port 22 only
- [x] Instance tagged with public access indicator

### Documented Risks:
- **RISK-001**: Public password-based SSH (HIGH severity)
  - Accepted for development environment only
  - NOT suitable for production workloads
  
- **RISK-009**: Non-compliant with PCI-DSS, HIPAA, SOC 2
  - Documented with `Environment=development` tag
  - Architectural redesign required for compliance needs

---

## 12. Implementation Sequence

### Pre-Deployment:
1. Validate HCP Terraform workspace configuration
2. Confirm AWS provider credentials in variable sets
3. Review and commit Terraform code to feature branch
4. Run pre-commit hooks and linting

### Deployment:
1. Terraform apply creates infrastructure (~3 minutes)
2. User-data script executes (additional 2-3 minutes)
3. Operator connects via Session Manager
4. Operator sets initial devuser password securely
5. SSH access validated from remote workstation

### Post-Deployment:
1. Verify CloudWatch log streaming operational
2. Test fail2ban with intentional failed login
3. Confirm Session Manager fallback access
4. Document instance IP and access procedures

---

## 13. Key Technology Decisions Summary

| Decision Area | Selected Technology | Primary Rationale |
|--------------|---------------------|-------------------|
| Compute | t3.micro EC2 instance | Cost optimization ($7.50/month) |
| Operating System | Amazon Linux 2023 | AWS-managed updates, SSM pre-installed |
| AMI Management | Dynamic data source lookup | Automatic security patches |
| SSH Hardening | fail2ban + PAM password policy | Industry-standard protection |
| Backup Access | AWS Systems Manager Session Manager | IAM-based emergency fallback |
| Monitoring | CloudWatch Logs + Basic Metrics | AWS-native integration |
| Log Retention | 7 days | Cost-optimized for development |
| Network | Default VPC + Elastic IP | Simplicity and consistent access |
| Security | Password-only SSH authentication | Requirement specification |
| Terraform Execution | HCP Terraform remote execution | Constitution-mandated approach |

---

## 14. Constitution Compliance Matrix

| Constitution Section | Requirement | Implementation | Status |
|---------------------|-------------|----------------|--------|
| 1.1 Module-First | Prioritize private registry | Direct resources (justified for simple use case) | ✅ Compliant |
| 1.2 Specification-Driven | Explicit specifications | Comprehensive spec.md with 95+ requirements | ✅ Compliant |
| 1.3 Security-First | Zero trust, ephemeral secrets | Password via Session Manager (not in state) | ✅ Compliant |
| 2.1 HCP Prerequisites | Organization/project/workspace | Pre-configured sandbox workspace | ✅ Compliant |
| 3.1 Code Standards | File organization | main.tf, variables.tf, outputs.tf, providers.tf | ✅ Compliant |
| 3.2 File Organization | Terraform conventions | Follows standard file structure | ✅ Compliant |
| 3.3 Naming | HashiCorp standards | Resources: `<app>-<type>-<purpose>` | ✅ Compliant |
| 3.4 Variable Management | Type constraints, validation | All variables typed with validation | ✅ Compliant |
| 3.5 Module Usage | Version constraints | N/A (no modules) | ✅ Compliant |
| 4.1 Workspace Management | Pre-provisioned workspaces | Using existing sandbox workspace | ✅ Compliant |
| 4.3 Environment Promotion | feature → dev → staging → main | Feature branch from dev | ✅ Compliant |

---

## 15. Future Enhancements (Out of Scope)

Documented for potential future iterations:

- **FC-001**: Migration to SSH key-based authentication
- **FC-002**: IP allowlist restricting SSH to known office/VPN ranges
- **FC-003**: Instance type upgrade if workload demands increase
- **FC-004**: Centralized logging (ELK, Splunk) for multi-instance environments
- **FC-005**: Session Manager browser-based GUI access

---

## Conclusion

This research document provides the technical foundation for implementing a secure, monitored, and cost-optimized EC2 development instance with password-based SSH authentication. All decisions align with the feature specification, organizational constitution, and AWS best practices for development environments.

**Key Success Factors**:
1. Constitution-compliant Terraform patterns
2. Security hardening via fail2ban and strong password policies
3. Emergency access via Session Manager
4. Real-time monitoring with CloudWatch
5. Cost optimization under $10/month
6. Fully automated deployment via HCP Terraform

**Next Steps**: Proceed to Phase 1 (data-model.md, contracts generation, quickstart.md).
