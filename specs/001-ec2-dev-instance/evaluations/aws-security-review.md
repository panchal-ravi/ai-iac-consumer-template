# AWS Security Review: EC2 Development Instance

**Feature**: Public EC2 Development Instance with Password-Based SSH  
**Branch**: `001-ec2-dev-instance`  
**Review Date**: 2025-01-12  
**Reviewer**: AWS Security Advisor (AI Agent)  
**Scope**: Design artifacts (spec.md, plan.md, data-model.md, research.md)

---

## Executive Summary

This security review evaluates the EC2 development instance design against AWS Well-Architected Framework Security Pillar, CIS AWS Foundations Benchmark, and industry best practices.

### Risk Profile

**Environment Classification**: Development (Non-Production)  
**Data Sensitivity**: Low (No PII/PHI/PCI data expected)  
**Compliance Requirements**: None (Explicitly non-compliant with PCI-DSS, HIPAA, SOC 2)  
**Accepted Risk Posture**: Public SSH with password authentication for development use only

### Findings Summary

| Severity | Count | Primary Concerns |
|----------|-------|------------------|
| **Critical (P0)** | 1 | Unrestricted public SSH access (0.0.0.0/0) |
| **High (P1)** | 4 | Password authentication, missing MFA, no EBS encryption, missing CloudWatch KMS encryption |
| **Medium (P2)** | 3 | Overly permissive egress, missing VPC Flow Logs, no CloudWatch alerting |
| **Low (P3)** | 2 | Single-region deployment, IMDSv2 not enforced |

**Total Issues**: 10 findings

### Security Posture Assessment

✅ **Strengths**:
- Least-privilege IAM role (AmazonSSMManagedInstanceCore only)
- Emergency backup access via AWS Systems Manager Session Manager
- fail2ban brute-force protection (5 attempts/10min = 1hr block)
- Strong password policy (14+ chars, 4 character classes, 90-day rotation)
- CloudWatch authentication log streaming
- Password never stored in Terraform state/code
- Root SSH login disabled
- SSH session timeout (30 minutes)

⚠️ **Weaknesses**:
- Public SSH from entire internet (0.0.0.0/0)
- Password authentication (vs. public key cryptography)
- No multi-factor authentication
- Missing encryption-at-rest specification for EBS volumes
- No KMS encryption for CloudWatch Logs
- No network monitoring (VPC Flow Logs)
- No security event alerting (CloudWatch Alarms)

### Deployment Recommendation

**For Development Environment (Current Scope)**: ✅ **APPROVED WITH CONDITIONS**
- All Critical/High findings have documented risk acceptance in spec.md
- Environment tagged as "development" for audit visibility
- Risk acceptance valid ONLY for development workloads
- NOT suitable for production, staging, or any environment with sensitive data

**Conditions for Deployment**:
1. Tag all resources with `Environment=development` and `PublicAccess=true`
2. Document risk acceptance in change management system
3. Review security posture every 90 days
4. Implement at least Medium (P2) findings within 30 days
5. Migrate to production-ready architecture before handling sensitive data

---

## Domain 1: Identity & Access Management (IAM)

### 1.1 Password-Based SSH Authentication

**Risk Rating**: High (P1)  
**Justification**: Password authentication is fundamentally weaker than public key cryptography and vulnerable to brute-force attacks, credential stuffing, phishing, and social engineering. While fail2ban provides IP blocking after 5 attempts, distributed attacks from multiple IPs can circumvent this protection.

**Finding**: Design spec explicitly requires password-only SSH authentication with public key authentication disabled.

**Evidence**:
- `spec.md:108` - "FR-008: System MUST enable SSH password authentication on port 22"
- `spec.md:109` - "FR-009: System MUST disable SSH key-based authentication"
- `research.md:102-113` - SSH daemon config: `PasswordAuthentication yes` and `PubkeyAuthentication no`

**Impact**:
- **Credential Compromise**: Passwords susceptible to shoulder surfing, keyloggers, social engineering
- **Brute-Force**: Even with fail2ban, distributed bot networks can attempt parallel guessing
- **Credential Reuse**: Users may reuse passwords across systems, creating lateral movement risk
- **Phishing**: Passwords can be captured through fake SSH prompts
- **Compliance**: Not acceptable for PCI-DSS 8.3, HIPAA, FISMA, or SOC 2

**Recommendation**:

**For Current Development Environment**:
1. ✅ Maintain password authentication with documented risk acceptance
2. ✅ Enforce strong password policy (14+ chars, 4 classes) - already in design
3. ✅ Implement fail2ban (5 attempts/10min) - already in design
4. ✅ Use Session Manager as primary access method; SSH for legacy tools only
5. ⚠️ Monitor CloudWatch Logs for anomalous patterns (recommend CloudWatch Insights queries)

**For Production Migration**:
```hcl
# Secure SSH configuration
resource "aws_instance" "prod" {
  # ... other configuration
  
  user_data = <<-EOF
    #!/bin/bash
    # Secure SSH daemon configuration
    cat >> /etc/ssh/sshd_config <<SSHEOF
    PasswordAuthentication no              # ✅ Disable passwords
    PubkeyAuthentication yes               # ✅ Enable public keys
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys  # ✅ Centralized key management
    TrustedUserCAKeys /etc/ssh/ca-user.pub # ✅ SSH CA for short-lived certs
    AuthenticationMethods publickey,keyboard-interactive   # ✅ Require MFA
    PermitRootLogin no
    MaxAuthTries 3
    ClientAliveInterval 900
    ClientAliveCountMax 2
    SSHEOF
    
    systemctl restart sshd
  EOF
}
```

**Source**: [AWS Security Best Practices for EC2 - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/data-protection.html]  
**Reference**: [CIS AWS Foundations Benchmark - §5.2]  
**Reference**: [NIST SP 800-63B - §5.1.4 (Cryptographic Keys > Memorized Secrets)]  
**Reference**: [AWS Well-Architected Security Pillar - SEC02-BP02 (Use temporary credentials)]

**Effort**: Low for current (already implemented) | Medium for production (4-8 hours to implement SSH CA)

**Risk Acceptance**: ✅ **ACCEPTED FOR DEVELOPMENT**  
Documented in spec.md RISK-001: "Public SSH with password authentication (HIGH severity) - Accepted for development environment only."

---

### 1.2 Missing Multi-Factor Authentication (MFA)

**Risk Rating**: High (P1)  
**Justification**: Single-factor authentication provides no defense-in-depth. Compromised credentials = immediate unauthorized access. MFA would require attacker to compromise both authentication factor AND second factor.

**Finding**: No MFA enforcement for SSH or Session Manager access. Design explicitly excludes MFA per spec.md OOS-002.

**Evidence**:
- `spec.md:252` - "OOS-002: Multi-factor authentication (MFA) for SSH access - not required for development"
- No MFA configuration in user-data script
- IAM policy lacks MFA condition (`aws:MultiFactorAuthPresent`)

**Impact**:
- **Stolen Credentials**: Immediate access with password alone
- **Session Hijacking**: Compromised IAM credentials allow Session Manager
- **Insider Threats**: Disgruntled employees have unrestricted access
- **Compliance**: Required by PCI-DSS 8.3, HIPAA §164.312(a)(2)(i), SOC 2 CC6.1

**Recommendation**:

**For Production**:
```hcl
# IAM policy enforcement for Session Manager
resource "aws_iam_role_policy" "ssm_mfa_required" {
  name = "session-manager-require-mfa"
  role = aws_iam_role.ec2_ssm_role.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenySessionManagerWithoutMFA"
        Effect = "Deny"
        Action = [
          "ssm:StartSession",
          "ssm:ResumeSession"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}
```

**Source**: [AWS IAM MFA Best Practices - https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#enable-mfa-for-privileged-users]  
**Reference**: [CIS AWS Foundations Benchmark - §1.10]  
**Reference**: [AWS Well-Architected Security Pillar - SEC02-BP03]

**Effort**: Medium (2-4 hours for Google Authenticator implementation)

**Risk Acceptance**: ✅ **ACCEPTED FOR DEVELOPMENT**

---

### 1.3 IAM Instance Profile (Least Privilege) ✅

**Risk Rating**: ✅ **COMPLIANT**  
**Justification**: IAM role uses AWS-managed policy AmazonSSMManagedInstanceCore with tightly scoped permissions.

**Finding**: Design follows least-privilege principle. No wildcard permissions, no admin access.

**Evidence**:
- `data-model.md:271-282` - IAM role with AmazonSSMManagedInstanceCore only
- `research.md:223-227` - Documented permissions: ssm:UpdateInstanceInformation, ssmmessages:*, ec2messages:GetMessages

**Validated Permissions**:
- ✅ SSM agent communication only
- ✅ No S3, DynamoDB, or other service access
- ✅ No IAM write permissions
- ✅ No resource creation capabilities

**Source**: [AWS IAM Least Privilege - https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege]  
**Reference**: [AWS Well-Architected Security Pillar - SEC03-BP02]

**Effort**: N/A - Already compliant

---

## Domain 2: Data Protection

### 2.1 Missing EBS Encryption Specification

**Risk Rating**: High (P1)  
**Justification**: Unencrypted EBS volumes expose data-at-rest to unauthorized access if physical storage compromised, snapshots made public, or volumes shared with unauthorized accounts.

**Finding**: Design does not specify EBS encryption. No `encrypted = true` attribute in Terraform configuration. Depends on account-level default (may be disabled).

**Evidence**:
- `data-model.md:338` - EC2 instance resource lacks root_block_device encryption config
- `spec.md:FR-001` - Requirements don't mandate encryption
- No KMS key resource in design artifacts

**Impact**:
- **Data Exposure**: OS files, logs, application data readable if volume detached
- **Snapshot Leakage**: Unencrypted snapshots may be accidentally shared (AWS Security Hub EC2.1)
- **Compliance**: PCI-DSS 3.4, HIPAA §164.312(a)(2)(iv), SOC 2 CC6.1 require encryption
- **Insider Risk**: AWS users with EC2 permissions can attach volumes to their instances

**Recommendation**:

```hcl
# Enable encryption by default (AWS CLI - run once)
aws ec2 enable-ebs-encryption-by-default --region us-east-1

# Terraform implementation
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS volume encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/ec2-dev-instance-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_instance" "dev" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true  # ✅ Enable encryption
    kms_key_id            = aws_kms_key.ebs.arn
    delete_on_termination = true
  }
  
  metadata_options {
    http_tokens   = "required"  # ✅ IMDSv2
    http_endpoint = "enabled"
  }
}
```

**Cost Impact**: $1/month for KMS key + $0.03/10K requests ≈ $1.50/month

**Source**: [AWS EBS Encryption Best Practices - https://docs.aws.amazon.com/prescriptive-guidance/latest/encryption-best-practices/ec2-ebs.html]  
**Reference**: [AWS Security Hub - EC2.7]  
**Reference**: [CIS AWS Foundations Benchmark - §2.2.1]

**Effort**: Low (15-30 minutes)

**Risk Acceptance**: ❌ **NOT RECOMMENDED** - Encryption should be enabled for all environments

---

### 2.2 Password Management (State Isolation) ✅

**Risk Rating**: ✅ **COMPLIANT**  
**Justification**: Password never stored in Terraform state, code, or logs. Operator sets via Session Manager post-deployment.

**Finding**: Correct secret management. Password lifecycle isolated from IaC.

**Evidence**:
- `spec.md:119` - "FR-011a: Password set via Session Manager (not in state)"
- `spec.md:188` - "A-008: Password not stored in Terraform state or logs"

**Strengths**:
- ✅ No secrets in version control
- ✅ No secrets in Terraform state
- ✅ No secrets in CloudWatch Logs or CloudTrail
- ✅ Password only in operator memory + `/etc/shadow`

**Source**: [AWS Secrets Management - https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/automate-the-aws-secrets-manager-secret-rotation-for-credentials.html]  
**Reference**: [AWS Well-Architected Security Pillar - SEC02-BP03]

**Effort**: N/A - Already compliant

---

### 2.3 CloudWatch Logs Encryption (KMS)

**Risk Rating**: High (P1)  
**Justification**: Authentication logs contain sensitive security information (usernames, IPs, timestamps). Without KMS encryption, logs encrypted with AWS-managed keys (less auditability).

**Finding**: CloudWatch Log Group lacks `kms_key_id` attribute. Defaults to AWS-managed encryption.

**Evidence**:
- `data-model.md:538-567` - Log group resource without KMS key
- `research.md:285-295` - CloudWatch configuration lacks encryption specification

**Impact**:
- **Auditability**: Cannot track who accessed log encryption keys
- **Key Management**: No control over key rotation or deletion
- **Compliance**: Some frameworks require customer-managed keys

**Recommendation**:

```hcl
resource "aws_kms_key" "cloudwatch" {
  description             = "CloudWatch Logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable Root Permissions"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = { Service = "logs.us-east-1.amazonaws.com" }
        Action = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/dev-instance/ssh-auth"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ssh_auth_logs" {
  name              = "/aws/ec2/dev-instance/ssh-auth"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch.arn  # ✅ Customer-managed encryption
}
```

**Cost Impact**: $1/month for KMS key + $0.03/10K requests ≈ $1.20/month

**Source**: [CloudWatch Logs Encryption - https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/security.html]  
**Reference**: [CIS AWS Foundations Benchmark - §3.4]

**Effort**: Low (20-30 minutes)

**Risk Acceptance**: ❌ **NOT RECOMMENDED**

---

## Domain 3: Network Security

### 3.1 Unrestricted Public SSH Access (0.0.0.0/0)

**Risk Rating**: Critical (P0)  
**Justification**: Allowing SSH from 0.0.0.0/0 exposes instance to entire internet. This is the single highest-risk configuration in the design.

**Finding**: Security group ingress rule allows TCP port 22 from 0.0.0.0/0 (all IPv4 addresses).

**Evidence**:
- `spec.md:104` - "FR-004: Security group allowing port 22 from 0.0.0.0/0"
- `research.md:351-357` - Security group with `cidr_blocks = ["0.0.0.0/0"]`
- `data-model.md:199-204` - Ingress rule SSH from anywhere

**Impact**:
- **Constant Attack Surface**: Shodan, Censys, and automated scanners immediately discover open port
- **Botnet Targeting**: Thousands of IPs attempting brute-force daily
- **Nation-State Actors**: Advanced persistent threats (APTs) scanning for vulnerabilities
- **Zero-Day Exploits**: Exposed to SSH daemon vulnerabilities (CVE-2023-XXXX)
- **Compliance**: Violates AWS Security Hub EC2.13, CIS 5.2, PCI-DSS 1.3

**Attack Statistics** (Industry Data):
- Average SSH brute-force attempts: 10,000-50,000/day for publicly exposed instances
- Time to first attack: <5 minutes after deployment
- Bot networks: 100,000+ IPs in rotation (circumvents IP-based blocking)

**Recommendation**:

**Immediate (Development)**:
1. ✅ Maintain 0.0.0.0/0 with documented risk acceptance
2. ✅ fail2ban protection (already implemented)
3. ⚠️ Add CloudWatch Alarm for excessive failed attempts:

```hcl
resource "aws_cloudwatch_log_metric_filter" "ssh_failed_auth" {
  name           = "ssh-failed-authentication"
  log_group_name = aws_cloudwatch_log_group.ssh_auth_logs.name
  pattern        = "[Mon, day, timestamp, ip, id, msg1, msg2="Failed", msg3="password", ...]"
  
  metric_transformation {
    name      = "SSHFailedAuthentication"
    namespace = "EC2/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "ssh_brute_force" {
  alarm_name          = "ssh-brute-force-detection"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SSHFailedAuthentication"
  namespace           = "EC2/Security"
  period              = "300"  # 5 minutes
  statistic           = "Sum"
  threshold           = "50"  # Alert if >50 failures in 5min
  alarm_description   = "Detect SSH brute-force attacks"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

**For Production** (Choose one):

**Option 1: IP Allowlist (Recommended for Known Offices)**
```hcl
resource "aws_security_group" "ssh_restricted" {
  name   = "ec2-dev-instance-ssh-restricted"
  vpc_id = data.aws_vpc.default.id
  
  ingress {
    description = "SSH from office network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "198.51.100.0/24",  # Office network
      "203.0.113.0/24"    # VPN network
    ]
  }
}
```

**Option 2: VPN-Only Access (Gold Standard)**
```hcl
# Remove SSH security group rule entirely
# Access via AWS Client VPN or AWS Site-to-Site VPN
# Private subnet deployment with no public IP

resource "aws_instance" "prod" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.private.id
  associate_public_ip_address = false  # ✅ No public IP
  
  vpc_security_group_ids = [aws_security_group.private_access.id]
}

resource "aws_security_group" "private_access" {
  ingress {
    description = "SSH from VPN clients only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Private VPC CIDR only
  }
}
```

**Option 3: Session Manager Only (Most Secure)**
```bash
# Remove SSH access entirely
# Use AWS Systems Manager Session Manager exclusively
# Zero network ports exposed

aws ssm start-session --target i-1234567890abcdef0
```

**Source**: [AWS Security Groups Best Practices - https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html]  
**Reference**: [AWS Security Hub - EC2.13 (Security groups should not allow ingress from 0.0.0.0/0 to port 22)]  
**Reference**: [CIS AWS Foundations Benchmark - §5.2 (Ensure SSH access restricted)]  
**Reference**: [AWS Well-Architected Security Pillar - SEC05-BP01 (Create network layers)]

**Effort**: Low for IP allowlist (10 minutes) | High for VPN (4-8 hours)

**Risk Acceptance**: ✅ **ACCEPTED FOR DEVELOPMENT ONLY**  
Documented in spec.md RISK-001. Must be remediated before production use.

---

### 3.2 Overly Permissive Egress Rules

**Risk Rating**: Medium (P2)  
**Justification**: Security group allows all outbound traffic (0.0.0.0/0 on all ports/protocols). If instance compromised, attacker can exfiltrate data to any destination.

**Finding**: Egress rule permits all protocols to all destinations without restrictions.

**Evidence**:
- `research.md:359-365` - Egress rule: `protocol = "-1", cidr_blocks = ["0.0.0.0/0"]`

**Impact**:
- **Data Exfiltration**: Compromised instance can send data to attacker C2 servers
- **Malware Communication**: Can download additional malware payloads
- **Lateral Movement**: Can scan and attack other internet hosts
- **Cost Overruns**: Unlimited data transfer could spike AWS bills

**Recommendation**:

**For Production**:
```hcl
resource "aws_security_group" "restricted_egress" {
  name   = "ec2-dev-instance-restricted-egress"
  vpc_id = data.aws_vpc.default.id
  
  # Allow HTTPS for package updates
  egress {
    description = "HTTPS to package repositories"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow HTTP for package updates (consider restricting to yum repos only)
  egress {
    description = "HTTP for package updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow DNS
  egress {
    description = "DNS queries"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow NTP
  egress {
    description = "NTP time sync"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # AWS service endpoints (VPC endpoint alternative)
  egress {
    description     = "AWS APIs"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
  }
}
```

**Source**: [AWS Security Group Best Practices - https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html]  
**Reference**: [AWS Well-Architected Security Pillar - SEC05-BP02 (Control traffic at all layers)]

**Effort**: Medium (1-2 hours to identify required egress)

**Risk Acceptance**: ⚠️ **Consider Implementing** - Adds defense-in-depth

---

### 3.3 Missing VPC Flow Logs

**Risk Rating**: Medium (P2)  
**Justification**: No network-level monitoring to detect reconnaissance, data exfiltration, or anomalous traffic patterns.

**Finding**: Design does not include VPC Flow Logs for network visibility.

**Evidence**:
- No VPC Flow Logs resource in plan.md or data-model.md
- `spec.md` requirements lack network monitoring specification

**Impact**:
- **Blind Spots**: Cannot detect port scans, DDoS, or lateral movement
- **Incident Response**: No network forensics for security investigations
- **Compliance**: AWS Security Hub EC2.6, CIS 3.9 require Flow Logs

**Recommendation**:

```hcl
resource "aws_flow_log" "dev_instance" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"  # or "REJECT" for denied traffic only
  vpc_id          = data.aws_vpc.default.id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flowlogs/ec2-dev-instance"
  retention_in_days = 7
}

resource "aws_iam_role" "flow_logs" {
  name = "vpc-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}
```

**Cost Impact**: ~$0.50/month for 7-day retention (~1 GB/month for single instance)

**Source**: [VPC Flow Logs - https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html]  
**Reference**: [AWS Security Hub - EC2.6]  
**Reference**: [CIS AWS Foundations Benchmark - §3.9]

**Effort**: Low (15-20 minutes)

**Risk Acceptance**: ⚠️ **Recommend Implementing** - Improves incident response

---

## Domain 4: Logging & Monitoring

### 4.1 Missing CloudWatch Alarms for Security Events

**Risk Rating**: Medium (P2)  
**Justification**: Security logs collected but no automated alerting for critical events (brute-force, unauthorized access).

**Finding**: CloudWatch Logs configured but no metric filters or alarms for security events.

**Evidence**:
- `spec.md:258` - "OOS-011: CloudWatch alarms and SNS notifications - out of scope"
- Logs collected but no actionable alerts

**Impact**:
- **Delayed Response**: Security incidents discovered days later
- **Alert Fatigue**: Manual log review not scalable
- **Compliance**: SOC 2, ISO 27001 require security event monitoring

**Recommendation**:

```hcl
# SNS topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name = "ec2-dev-instance-security-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# Metric filter for failed SSH attempts
resource "aws_cloudwatch_log_metric_filter" "failed_ssh" {
  name           = "failed-ssh-attempts"
  log_group_name = aws_cloudwatch_log_group.ssh_auth_logs.name
  pattern        = "[timestamp, ip, id, msg1, msg2="Failed", msg3="password", ...]"
  
  metric_transformation {
    name      = "FailedSSHAttempts"
    namespace = "EC2/Security"
    value     = "1"
  }
}

# Alarm for brute-force detection
resource "aws_cloudwatch_metric_alarm" "ssh_brute_force" {
  alarm_name          = "ssh-brute-force-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedSSHAttempts"
  namespace           = "EC2/Security"
  period              = "300"  # 5 minutes
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert on excessive SSH failures"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Metric filter for successful SSH logins
resource "aws_cloudwatch_log_metric_filter" "successful_ssh" {
  name           = "successful-ssh-login"
  log_group_name = aws_cloudwatch_log_group.ssh_auth_logs.name
  pattern        = "[timestamp, ip, id, msg1, msg2="Accepted", msg3="password", ...]"
  
  metric_transformation {
    name      = "SuccessfulSSHLogins"
    namespace = "EC2/Security"
    value     = "1"
  }
}

# Alarm for off-hours access (optional)
resource "aws_cloudwatch_metric_alarm" "off_hours_login" {
  alarm_name          = "ssh-off-hours-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SuccessfulSSHLogins"
  namespace           = "EC2/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert on SSH access outside business hours"
  # Add time-based condition in alarm evaluation
}
```

**Cost Impact**: $0.10/alarm/month + SNS (free tier) ≈ $0.30/month

**Source**: [CloudWatch Logs Insights - https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/auth-and-access-control-cwl.html]  
**Reference**: [AWS Well-Architected Security Pillar - SEC04-BP01 (Configure service logging)]

**Effort**: Medium (1-2 hours for metric filters + alarms)

**Risk Acceptance**: ⚠️ **Recommend Implementing** - Improves security posture

---

## Domain 5: Resilience

### 5.1 Single-Region Deployment

**Risk Rating**: Low (P3)  
**Justification**: Development instance in single AZ has no redundancy. AWS region outage causes complete service loss.

**Finding**: Design deploys single instance in us-east-1 with no multi-region or multi-AZ failover.

**Evidence**:
- `spec.md:FR-001` - "t3.micro instance in us-east-1 region"
- `spec.md:A-026` - "Single availability zone deployment acceptable for development"

**Impact**:
- **Outage Risk**: AWS region or AZ failure = 100% downtime
- **RTO/RPO**: Recovery requires Terraform redeployment (~5 minutes)
- **Data Loss**: Recent work lost if EBS volume unavailable

**Recommendation**:

**For Development**: ✅ Accept single-region risk (cost-optimized)

**For Production**:
```hcl
# Multi-AZ deployment with Auto Scaling Group
resource "aws_launch_template" "prod" {
  name_prefix   = "prod-instance-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  # ... configuration
}

resource "aws_autoscaling_group" "prod" {
  name                = "prod-asg"
  vpc_zone_identifier = data.aws_subnets.private.ids  # Multi-AZ
  desired_capacity    = 1
  min_size            = 1
  max_size            = 2
  health_check_type   = "EC2"
  
  launch_template {
    id      = aws_launch_template.prod.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "prod-instance"
    propagate_at_launch = true
  }
}
```

**Source**: [AWS High Availability Best Practices - https://docs.aws.amazon.com/whitepapers/latest/real-time-communication-on-aws/high-availability-and-scalability-on-aws.html]  
**Reference**: [AWS Well-Architected Reliability Pillar - REL08-BP01 (Use highly available network connectivity)]

**Effort**: High (8-16 hours for multi-region setup)

**Risk Acceptance**: ✅ **ACCEPTED FOR DEVELOPMENT**

---

### 5.2 Instance Metadata Service v2 (IMDSv2) Not Enforced

**Risk Rating**: Low (P3)  
**Justification**: Design doesn't enforce IMDSv2, leaving instance vulnerable to SSRF attacks that exploit IMDSv1.

**Finding**: No `metadata_options` block in EC2 instance configuration to require IMDSv2.

**Evidence**:
- `data-model.md:338` - EC2 instance resource lacks metadata_options
- No IMDSv2 enforcement in user-data script

**Impact**:
- **SSRF Attacks**: Applications with SSRF vulnerabilities can retrieve IAM credentials via IMDSv1
- **Container Escape**: Compromised containers can access instance metadata
- **Compliance**: AWS Security Hub EC2.8 requires IMDSv2

**Recommendation**:

```hcl
resource "aws_instance" "dev" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # ✅ Enforce IMDSv2
    http_put_response_hop_limit = 1           # ✅ Limit SSRF range
    instance_metadata_tags      = "enabled"   # ✅ Enable instance tags in metadata
  }
  
  # ... rest of configuration
}
```

**Source**: [IMDSv2 Security - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html]  
**Reference**: [AWS Security Hub - EC2.8]  
**Reference**: [AWS Security Best Practices - https://docs.aws.amazon.com/securityhub/latest/userguide/exposure-ec2-instance.html]

**Effort**: Low (5 minutes)

**Risk Acceptance**: ❌ **Recommend Implementing** - Simple hardening with no cost

---

## Domain 6: Compliance

### 6.1 Non-Compliance with Major Frameworks

**Risk Rating**: Informational (Documented)  
**Justification**: Design explicitly documented as non-compliant with PCI-DSS, HIPAA, SOC 2, FISMA.

**Finding**: Architecture suitable ONLY for development environments with low-sensitivity data.

**Evidence**:
- `spec.md:RISK-009` - "Configuration violates standard security best practices and most compliance frameworks"
- `spec.md:A-007` - "Public SSH with password authentication acceptable risk posture for development environment, not production"

**Compliance Gap Summary**:

| Framework | Violated Controls | Impact |
|-----------|------------------|--------|
| **PCI-DSS v4.0** | 1.3 (Public access), 8.3 (MFA), 8.4 (Password strength) | Cannot process card data |
| **HIPAA** | §164.312(a)(2) (Access control), §164.312(e) (Transmission security) | Cannot store PHI |
| **SOC 2** | CC6.1 (Logical access), CC6.6 (Encryption) | Cannot achieve SOC 2 Type II |
| **FISMA** | AC-2 (Account management), IA-2 (Identification), SC-13 (Cryptographic protection) | Cannot handle federal data |
| **ISO 27001** | A.9.4.2 (Secure log-on), A.10.1.1 (Cryptographic controls) | Cannot achieve certification |

**Recommendation**:

**For Development**: ✅ Document limitations in security policy

**For Production/Compliance**:
1. Migrate to VPN-only or private subnet deployment
2. Implement SSH CA with short-lived certificates
3. Enforce MFA for all access
4. Enable EBS encryption with customer-managed keys
5. Implement VPC Flow Logs and CloudWatch alerting
6. Deploy WAF for application-layer protection
7. Conduct third-party security assessment

**Source**: [AWS Compliance Programs - https://aws.amazon.com/compliance/programs/]  
**Reference**: [PCI DSS on AWS - https://docs.aws.amazon.com/whitepapers/latest/pci-dss-on-aws/pci-dss-on-aws.html]  
**Reference**: [HIPAA on AWS - https://docs.aws.amazon.com/whitepapers/latest/architecting-hipaa-security-and-compliance-on-aws/architecting-hipaa-security-and-compliance-on-aws.html]

**Effort**: N/A - For awareness only

**Risk Acceptance**: ✅ **ACCEPTED** - Development environment documented

---

## Summary of Recommendations

### Critical Priority (P0) - Block Deployment if Not Accepted

| Finding | Recommendation | Status |
|---------|---------------|--------|
| 3.1 Public SSH (0.0.0.0/0) | Implement IP allowlist or VPN-only access | ✅ Accepted for Dev |

### High Priority (P1) - Fix Before Production

| Finding | Recommendation | Effort | Cost |
|---------|---------------|--------|------|
| 1.1 Password Authentication | Migrate to SSH keys + CA | Medium | $0 |
| 1.2 Missing MFA | Implement Google Authenticator | Medium | $0 |
| 2.1 Missing EBS Encryption | Enable encryption + KMS key | Low | $1.50/mo |
| 2.3 CloudWatch Logs Encryption | Add KMS key for log group | Low | $1.20/mo |

**Total P1 Cost Impact**: +$2.70/month

### Medium Priority (P2) - Implement Within 30 Days

| Finding | Recommendation | Effort | Cost |
|---------|---------------|--------|------|
| 3.2 Permissive Egress | Restrict to required ports | Medium | $0 |
| 3.3 Missing VPC Flow Logs | Enable Flow Logs (7-day) | Low | $0.50/mo |
| 4.1 Missing CloudWatch Alarms | Add metric filters + alarms | Medium | $0.30/mo |

**Total P2 Cost Impact**: +$0.80/month

### Low Priority (P3) - Backlog

| Finding | Recommendation | Effort |
|---------|---------------|--------|
| 5.1 Single-Region | Accept for dev; Multi-AZ for prod | High |
| 5.2 IMDSv2 Not Enforced | Add metadata_options block | Low |

---

## Deployment Decision Matrix

### Development Environment (Current Scope)

**Deployment Recommendation**: ✅ **APPROVED**

**Conditions**:
- Tag all resources: `Environment=development`, `PublicAccess=true`
- Document risk acceptance in change management
- Review security posture every 90 days
- Do NOT process PII, PHI, PCI, or ITAR data
- Implement P2 findings within 30 days

**Mandatory Implementations**:
- ✅ fail2ban (already in design)
- ✅ Strong password policy (already in design)
- ✅ CloudWatch logging (already in design)
- ⚠️ EBS encryption (add to design)
- ⚠️ CloudWatch KMS encryption (add to design)
- ⚠️ VPC Flow Logs (add to design)

### Production/Staging Environment

**Deployment Recommendation**: ❌ **BLOCKED**

**Required Changes for Production**:
1. ✅ Migrate to private subnet with VPN/Direct Connect access
2. ✅ Implement SSH CA with short-lived certificates (1-8 hour validity)
3. ✅ Enforce MFA for all access methods
4. ✅ Enable EBS encryption with customer-managed KMS keys
5. ✅ Enable CloudWatch Logs encryption with KMS
6. ✅ Deploy VPC Flow Logs with 90-day retention
7. ✅ Implement CloudWatch metric filters and alarms
8. ✅ Enable AWS Config for compliance monitoring
9. ✅ Deploy AWS GuardDuty for threat detection
10. ✅ Restrict security group egress to required ports
11. ✅ Enforce IMDSv2
12. ✅ Implement automated vulnerability scanning
13. ✅ Conduct security assessment (internal or third-party)

**Estimated Production Migration Effort**: 80-120 hours

---

## Risk Acceptance Sign-Off

### For Development Environment Deployment

**Risk Acceptance Statement**:
"I acknowledge that this EC2 development instance has **1 Critical and 4 High severity security findings** that violate AWS Security Hub controls, CIS benchmarks, and major compliance frameworks (PCI-DSS, HIPAA, SOC 2). This configuration is acceptable ONLY for development/sandbox environments with no sensitive data. This architecture MUST NOT be used for production, staging, or any environment containing PII, PHI, PCI, financial data, or ITAR-controlled information."

**Accepted Risks**:
- Public SSH access from 0.0.0.0/0 (Critical)
- Password-based authentication (High)
- No multi-factor authentication (High)
- Missing EBS encryption specification (High - to be added)
- Missing CloudWatch KMS encryption (High - to be added)

**Mitigation Controls**:
- fail2ban brute-force protection (5 attempts/10min)
- Strong password policy (14+ chars, 4 classes, 90-day rotation)
- CloudWatch authentication logging
- AWS Systems Manager Session Manager backup access
- Least-privilege IAM role
- Resource tagging for audit visibility

**Review Schedule**: Every 90 days or before any production migration

---

**Signature**: ___________________________  
**Name**: ___________________________  
**Title**: ___________________________  
**Date**: ___________________________

---

## Appendix A: Security Tooling Recommendations

### Static Analysis
- **TFSec**: Terraform security scanner
- **Checkov**: Infrastructure-as-code security analysis
- **Prowler**: AWS security best practices auditor

### Runtime Monitoring
- **AWS GuardDuty**: Threat detection
- **AWS Security Hub**: Centralized security posture
- **AWS Config**: Compliance monitoring
- **Falco**: Runtime security for containers (if applicable)

### Incident Response
- **AWS CloudTrail**: Audit trail
- **AWS CloudWatch Logs Insights**: Log analysis
- **AWS Systems Manager Session Manager**: Secure access

---

## Appendix B: References

### AWS Documentation
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [AWS Security Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Security Hub Controls](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-controls-reference.html)
- [EC2 Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [EBS Encryption](https://docs.aws.amazon.com/prescriptive-guidance/latest/encryption-best-practices/ec2-ebs.html)
- [CloudWatch Logs Security](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/security.html)
- [Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

### Compliance Frameworks
- [CIS AWS Foundations Benchmark v1.5.0](https://www.cisecurity.org/benchmark/amazon_web_services)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [PCI DSS v4.0](https://www.pcisecuritystandards.org/)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)

### Security Standards
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [NIST SP 800-53 Rev. 5](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf)
- [ISO/IEC 27001:2022](https://www.iso.org/standard/27001)

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-12  
**Next Review**: 2025-04-12 (90 days)
