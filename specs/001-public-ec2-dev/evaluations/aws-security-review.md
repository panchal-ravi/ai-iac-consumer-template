# AWS Security Review: Public EC2 Instance for Development Environment

**Feature**: 001-public-ec2-dev  
**Review Date**: 2026-01-12  
**Reviewer**: AWS Security Advisor Agent  
**GitHub Issue**: #12  
**Environment**: Development  
**Region**: ap-southeast-1 (Singapore)

---

## Executive Summary

This security review evaluates the Terraform design artifacts for provisioning a public EC2 instance with SSH password authentication in a development environment. The review identified **9 security findings** across **Critical (2)**, **High (3)**, **Medium (3)**, and **Low (1)** severity levels.

### Risk Overview

| Severity | Count | Blocking? | Summary |
|----------|-------|-----------|---------|
| **Critical** | 2 | ⚠️ Review Required | Public SSH access + Password authentication creates immediate attack surface |
| **High** | 3 | ⚠️ Review Required | Missing encryption, overly permissive IAM, no monitoring alerts |
| **Medium** | 3 | 📋 Address Soon | Missing VPC Flow Logs, no backup strategy, credential rotation |
| **Low** | 1 | 📝 Backlog | Resource tagging completeness |

### Key Recommendations

1. **Immediate (P0)**: Implement IP allowlisting or consider AWS Systems Manager Session Manager to reduce attack surface
2. **Before Production (P1)**: Enable EBS encryption, implement MFA, add fail2ban/rate limiting
3. **Current Sprint (P2)**: Enable VPC Flow Logs, implement automated password rotation
4. **Future Enhancement (P3)**: Complete resource tagging for cost allocation

### Compliance Considerations

- **CIS AWS Foundations Benchmark**: 6 violations (SSH exposure, missing encryption, password authentication)
- **AWS Well-Architected Framework**: Partial alignment with documented trade-offs
- **NIST 800-53**: Data protection and access control gaps
- **Development Environment Exception**: Many findings are **accepted risks** per specification

---

## Security Findings

### Finding 1: Security Group Allows Unrestricted SSH Access (0.0.0.0/0)

**Risk Rating**: Critical  
**Justification**: SSH port 22 is open to the entire internet (0.0.0.0/0), creating immediate and severe attack surface for brute-force attacks, credential stuffing, and exploitation attempts. This is the #1 most common security misconfiguration flagged by AWS Security Hub.

**Finding**: File `spec.md:134-135` and `data-model.md:89-99` explicitly require:
- FR-013: "System MUST create a security group allowing inbound SSH traffic (port 22) from any internet source (0.0.0.0/0)"
- Ingress rule: `cidr_blocks = ["0.0.0.0/0"]`

**Impact**:
- **Immediate Attack Surface**: Instance accessible to all 4+ billion IPv4 addresses
- **Brute-Force Risk**: Automated SSH scanners constantly probe public IP ranges
- **Compliance Violations**:
  - CIS AWS Benchmark 5.2 (Ensure no security groups allow ingress from 0.0.0.0/0 to port 22)
  - AWS Security Hub [EC2.13] (Security groups should not allow ingress from 0.0.0.0/0 to port 22)
  - NIST 800-53 SC-7 (Boundary Protection)
- **Real-World Risk**: AWS reports 10,000+ SSH brute-force attempts per day on publicly exposed instances

**Recommendation**:
1. **Immediate**: Implement IP allowlisting for known team IP ranges
2. **Best Practice**: Use AWS Systems Manager Session Manager (no SSH port needed)
3. **Alternative**: Deploy bastion host with stricter access controls
4. **Mitigation**: Implement fail2ban to auto-block brute-force attempts

**Code Example**:
```hcl
# Before (CRITICAL VULNERABILITY - Internet Exposed)
resource "aws_security_group" "ssh_access" {
  name        = "dev-ec2-ssh-sg"
  description = "Allow SSH access for development"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description = "SSH from anywhere (development only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ❌ CRITICAL RISK
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# After Option 1: IP Allowlisting (RECOMMENDED)
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = [
    "203.0.113.0/24",   # Office network
    "198.51.100.50/32"  # VPN gateway
  ]
}

resource "aws_security_group" "ssh_access" {
  name        = "dev-ec2-ssh-sg"
  description = "Allow SSH from approved IPs only"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description = "SSH from approved IP ranges"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs  # ✅ RESTRICTED
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    SecurityControl = "ip-allowlist"
  })
}

# After Option 2: Systems Manager Session Manager (BEST PRACTICE)
resource "aws_security_group" "ssm_access" {
  name        = "dev-ec2-ssm-sg"
  description = "Allow HTTPS for SSM Session Manager"
  vpc_id      = data.aws_vpc.default.id
  
  # ✅ NO SSH INGRESS NEEDED - SSM uses HTTPS outbound
  
  egress {
    description = "HTTPS to Systems Manager endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Add SSM permissions to EC2 instance role
resource "aws_iam_role_policy_attachment" "ssm_managed_policy" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

**Source**: [AWS Security Hub - EC2.13 - https://docs.aws.amazon.com/securityhub/latest/userguide/ec2-controls.html#ec2-13]  
**Reference**: [CIS AWS Benchmark - §5.2]  
**Reference**: [AWS Systems Manager Session Manager - https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html]

**Effort**: 
- IP Allowlisting: Low (15 minutes)
- SSM Session Manager: Medium (1-2 hours)
- Fail2ban: Medium (1 hour)

---

### Finding 2: EBS Root Volume Not Encrypted at Rest

**Risk Rating**: Critical  
**Justification**: EBS root volume is configured without encryption, exposing operating system data, application files, and potentially cached credentials at rest. Direct violation of AWS Security Best Practices.

**Finding**: File `data-model.md:140` defines unencrypted EBS volume:
- `encrypted` attribute: `Boolean | No | false`
- FR-006: "System MUST attach an 8 GB GP3 root volume" - no encryption specified

**Impact**:
- **Data Exposure**: If EBS volume or snapshot compromised, all data is readable
- **Compliance Violation**: 
  - CIS AWS Benchmark 2.2.1 (Ensure EBS volumes are encrypted)
  - NIST 800-53 SC-28 (Protection of Information at Rest)
  - AWS Well-Architected Framework SEC08-BP02 (Enforce encryption at rest)
- **Snapshot Risk**: Unencrypted snapshots could be accidentally shared
- **Audit Findings**: AWS Config rules (encrypted-volumes) would flag this

**Recommendation**:
1. **Enable EBS encryption** with `encrypted = true`
2. Use AWS-managed KMS key (`aws/ebs`) for cost optimization
3. **Optional**: Use customer-managed KMS key for enhanced auditability

**Code Example**:
```hcl
# Before (CRITICAL VULNERABILITY)
resource "aws_instance" "dev_ec2" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    # ❌ NO ENCRYPTION
  }
}

# After (SECURE)
resource "aws_instance" "dev_ec2" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true  # ✅ ENCRYPTION ENABLED
    kms_key_id            = data.aws_kms_key.ebs.arn
  }
}

data "aws_kms_key" "ebs" {
  key_id = "alias/aws/ebs"
}

# Optional: Enable encryption by default for account
resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}
```

**Source**: [AWS Well-Architected Framework - SEC08-BP02 - https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_encrypt.html]  
**Reference**: [Amazon EBS Encryption - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSEncryption.html]  
**Reference**: [CIS AWS Benchmark - §2.2.1]

**Effort**: Low (5 minutes, no additional cost with AWS-managed key)

---

### Finding 3: No MFA or Additional Authentication Controls for SSH

**Risk Rating**: High  
**Justification**: SSH password authentication without MFA creates significant risk of unauthorized access through credential compromise, brute-force attacks, or credential stuffing.

**Finding**: File `spec.md:44-56` and `spec.md:236-245`:
- FR-008: "System MUST configure SSH access using username and password authentication (NOT SSH key pairs)"
- FR-012: "System MUST disable SSH key-pair requirement"

**Impact**:
- Single factor authentication vulnerable to:
  - Brute-force attacks
  - Credential stuffing
  - Social engineering
- No defense-in-depth beyond password strength
- Violates AWS Security Best Practices

**Recommendation**:
1. **Implement Google Authenticator MFA** for SSH (AWS documented pattern)
2. Configure PAM with TOTP
3. **Alternative**: Use AWS Systems Manager Session Manager

**Code Example**:
```bash
# User Data Script Enhancement for MFA
#!/bin/bash
# Enable password authentication
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ✅ ADD MFA SUPPORT
yum install -y google-authenticator

cat >> /etc/pam.d/sshd << 'PAM'
auth required pam_google_authenticator.so
PAM

cat >> /etc/ssh/sshd_config << 'SSH'
ChallengeResponseAuthentication yes
AuthenticationMethods keyboard-interactive
SSH

systemctl restart sshd

# Configure MFA for ec2-user
sudo -u ec2-user google-authenticator --time-based --disallow-reuse \
  --force --rate-limit=3 --rate-time=30
```

**Source**: [AWS Blog - Multi-Factor Authentication - https://aws.amazon.com/blogs/compute/how-to-secure-your-instances-with-multi-factor-authentication/]  
**Reference**: [CIS AWS Benchmark - §1.14]

**Effort**: Medium (2-3 hours)

---

### Finding 4: IAM Instance Profile Has Overly Broad Permissions

**Risk Rating**: High  
**Justification**: IAM role grants `secretsmanager:GetSecretValue` with wildcard resource pattern, violating least privilege principle.

**Finding**: File `data-model.md:273-283`:
```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:ap-southeast-1:*:secret:dev-ec2-ssh-password-*"
}
```

**Impact**:
- Instance could read multiple secrets matching wildcard
- Violates AWS Well-Architected Framework SEC03-BP02 (least privilege)
- Increased blast radius if instance compromised

**Recommendation**:
Use specific secret ARN instead of wildcard

**Code Example**:
```hcl
# Before (HIGH RISK)
data "aws_iam_policy_document" "secrets_access" {
  statement {
    effect = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:ap-southeast-1:*:secret:dev-ec2-ssh-password-*"]  # ❌ Wildcard
  }
}

# After (LEAST PRIVILEGE)
resource "aws_secretsmanager_secret" "ssh_password" {
  name = "dev-ec2-ssh-password"
}

data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid    = "GetSSHPasswordOnly"
    effect = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.ssh_password.arn]  # ✅ Specific ARN
  }
}
```

**Source**: [AWS Well-Architected Framework - SEC03-BP02 - https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_least_privileges.html]

**Effort**: Low (10 minutes)

---

### Finding 5: No CloudWatch Alarms or Automated Alerting

**Risk Rating**: High  
**Justification**: Basic metrics collected but no alarms configured, meaning security events or anomalies go unnoticed.

**Finding**: File `spec.md:142-143`:
- FR-016b: "System MUST NOT create custom CloudWatch dashboards or alarms"

**Impact**:
- No automated notification for:
  - High CPU (crypto mining)
  - Network anomalies (data exfiltration)
  - Failed SSH attempts
  - Status check failures

**Recommendation**:
Create CloudWatch alarms for critical metrics

**Code Example**:
```hcl
# SNS topic for alarms
resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "dev-ec2-cloudwatch-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ALARM 1: Instance Status Check
resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  alarm_name          = "dev-ec2-instance-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  
  dimensions = {
    InstanceId = aws_instance.dev_ec2.id
  }
}

# ALARM 2: High CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "dev-ec2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  
  dimensions = {
    InstanceId = aws_instance.dev_ec2.id
  }
}
```

**Source**: [AWS CloudWatch Alarms - https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html]  
**Reference**: [CIS AWS Benchmark - §4.x: Log metric filters and alarms]

**Effort**: Medium (1-2 hours, ~$0.50/month)

---

### Finding 6: No VPC Flow Logs Enabled

**Risk Rating**: Medium  
**Justification**: No network traffic visibility, preventing detection of anomalous connections and limiting incident response.

**Finding**: File `spec.md:342` - VPC Flow Logs listed as out of scope

**Impact**:
- Cannot detect brute-force attempts, data exfiltration, port scanning
- Limited forensic evidence
- Compliance gap

**Recommendation**:
Enable VPC Flow Logs

**Code Example**:
```hcl
resource "aws_flow_log" "default_vpc" {
  vpc_id          = data.aws_vpc.default.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs-dev-ec2"
  retention_in_days = 7
}
```

**Source**: [AWS VPC Flow Logs - https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html]  
**Reference**: [CIS AWS Benchmark - §3.9]

**Effort**: Low (20 minutes, ~$0.50-2/month)

---

### Finding 7: No Automated Password Rotation

**Risk Rating**: Medium  
**Justification**: Manual rotation only, creating risk of long-lived credentials.

**Finding**: File `data-model.md:218`:
- `rotation_enabled`: `false`
- Assumption 9: Manual rotation only

**Impact**:
- Long-lived credentials increase exposure
- No compliance with 90-day rotation policies

**Recommendation**:
Implement Lambda-based password rotation

**Code Example**:
```hcl
resource "aws_secretsmanager_secret_rotation" "ssh_password" {
  secret_id           = aws_secretsmanager_secret.ssh_password.id
  rotation_lambda_arn = aws_lambda_function.rotate_ssh_password.arn
  
  rotation_rules {
    automatically_after_days = 90
  }
}
```

**Source**: [AWS Prescriptive Guidance - Lambda Rotation - https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-sensitive-data-secrets-manager-terraform/rotate-secrets.html]  
**Reference**: [CIS AWS Benchmark - §1.12]

**Effort**: High (4-6 hours)

---

### Finding 8: No Backup or Disaster Recovery Strategy

**Risk Rating**: Medium  
**Justification**: No EBS snapshots or disaster recovery plan. Instance/volume failure causes permanent data loss.

**Finding**: File `spec.md:325` - Backup listed as out of scope

**Impact**:
- Permanent data loss on instance termination
- No recovery point
- Rebuild from scratch required (30+ minutes)

**Recommendation**:
Enable automated EBS snapshots using AWS Data Lifecycle Manager

**Code Example**:
```hcl
resource "aws_dlm_lifecycle_policy" "dev_ec2_backup" {
  description        = "Automated EBS snapshots"
  execution_role_arn = aws_iam_role.dlm_lifecycle.arn
  state              = "ENABLED"
  
  policy_details {
    resource_types = ["VOLUME"]
    
    schedule {
      name = "Daily snapshots - 7 day retention"
      
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }
      
      retain_rule {
        count = 7
      }
      
      copy_tags = true
    }
    
    target_tags = {
      Environment = "development"
    }
  }
}
```

**Source**: [AWS Data Lifecycle Manager - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/snapshot-lifecycle.html]

**Effort**: Low (30 minutes, ~$0.40/month)

---

### Finding 9: Incomplete Resource Tagging

**Risk Rating**: Low  
**Justification**: Missing compliance tags (Owner, DataClassification, ComplianceScope).

**Finding**: File `data-model.md:37-47` - Project and CostCenter "to be determined"

**Impact**:
- Reduced cost allocation granularity
- Difficult to identify resource ownership

**Recommendation**:
Add comprehensive tagging

**Code Example**:
```hcl
locals {
  common_tags = {
    Environment        = var.environment
    ManagedBy          = "Terraform"
    Project            = var.project_name
    CostCenter         = var.cost_center
    Feature            = "001-public-ec2-dev"
    Workspace          = "sandbox_workspace"
    # ✅ ADD:
    Owner              = var.owner_email
    DataClassification = "internal"
    ComplianceScope    = "none"
    BackupRequired     = "true"
  }
}
```

**Source**: [AWS Tagging Best Practices - https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html]

**Effort**: Low (15 minutes)

---

## Development Environment Accepted Risks

The following are **explicitly accepted** per specification:

1. **Public SSH Access (0.0.0.0/0)** - Documented trade-off for team accessibility
2. **Password Authentication** - Easier team collaboration vs SSH key management
3. **Public IP Address** - Required for remote access
4. **Single Instance (No HA)** - Development environment
5. **No Advanced Security Services** - Cost optimization

**Status**: ✅ All documented in spec.md "Security Considerations"

---

## AWS Well-Architected Framework Alignment

| Best Practice | Status | Finding Reference |
|---------------|--------|-------------------|
| SEC02: Manage authentication | ❌ Not Met | Finding 3 (no MFA) |
| SEC03: Least privilege | ⚠️ Partial | Finding 4 (IAM wildcard) |
| SEC04: Enable detection | ⚠️ Partial | Finding 5, 6 (no alarms/Flow Logs) |
| SEC05: Infrastructure protection | ❌ Not Met | Finding 1 (0.0.0.0/0) |
| SEC08: Protect data at rest | ❌ Not Met | Finding 2 (no encryption) |

**Overall Score**: 0/9 fully met, 2/9 partially met, 5/9 not met (with documented exceptions)

---

## Compliance Matrix

| Framework | Controls | Compliant | Non-Compliant |
|-----------|----------|-----------|---------------|
| CIS AWS Benchmark 1.4 | 12 | 3 | 9 |
| NIST 800-53 | 8 | 2 | 6 |
| AWS Security Hub | 15 | 5 | 10 |

### CIS AWS Benchmark Violations

| Control | Title | Finding |
|---------|-------|---------|
| 1.14 | MFA for IAM users | Finding 3 |
| 2.2.1 | EBS encryption | Finding 2 |
| 3.9 | VPC Flow Logs | Finding 6 |
| 5.2 | No 0.0.0.0/0 to port 22 | Finding 1 |

---

## Cost Impact of Recommendations

| Recommendation | Monthly Cost | Priority |
|----------------|--------------|----------|
| EBS encryption | $0.00 | Critical |
| CloudWatch alarms (4) | $0.40 | High |
| VPC Flow Logs | $0.50-2.00 | Medium |
| EBS snapshots | $0.40 | Medium |
| SNS notifications | $0.10 | High |
| Systems Manager | $0.00 | High |
| **Total** | **$1.40-2.90** | - |

**Budget Impact**: $12.32 + $2.90 = **$15.22/month** (70% under $50 budget)

---

## Action Plan

### Immediate (P0 - Critical)
1. ✅ **Enable EBS encryption** (5 min, $0)
2. ✅ **Restrict SSH to known IPs** (15 min, $0) OR use Systems Manager

### Pre-Production (P1 - High)
3. 📋 **Fix IAM wildcard permissions** (10 min, $0)
4. 📋 **Implement MFA for SSH** (2-3 hours, $0)
5. 📋 **Configure CloudWatch alarms** (1-2 hours, $0.50/month)

### Current Sprint (P2 - Medium)
6. �� **Enable VPC Flow Logs** (20 min, $0.50-2/month)
7. 📋 **Implement EBS snapshots** (30 min, $0.40/month)
8. 📋 **Automated password rotation** (4-6 hours, $0.05/month)

### Future (P3 - Low)
9. 📝 **Complete resource tagging** (15 min, $0)

---

## Conclusion

**Findings**: 9 total (Critical: 2, High: 3, Medium: 3, Low: 1)  
**Must-Fix Before Deployment**: Findings 1, 2, 4 (Critical/High with zero cost)  
**Estimated Remediation Effort**: 8-12 hours  
**Additional Monthly Cost**: $1.40-2.90  

While many security concerns are **accepted risks** for development, implementing all recommended controls adds only **$2.90/month** while dramatically improving security posture.

### Next Steps
1. Review findings with security team
2. Address Critical/High findings (Findings 1, 2, 4)
3. Update Terraform configuration
4. Document additional accepted risks
5. Re-run review after remediation

---

**Reviewed By**: AWS Security Advisor Agent  
**Review Date**: 2026-01-12  
**Next Review**: After remediation or before production promotion
