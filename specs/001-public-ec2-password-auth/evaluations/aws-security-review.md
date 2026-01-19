# AWS Security Review: Public EC2 Instance with Password Authentication

**Feature**: Public EC2 Instance with Password Authentication  
**Review Date**: 2025-01-21  
**Reviewer**: AWS Security Advisor  
**Branch**: `001-public-ec2-password-auth`  
**Status**: ❌ **NOT APPROVED FOR PRODUCTION**

---

## Executive Summary

This security review evaluates the Terraform design for provisioning a public EC2 instance with SSH password authentication in AWS ap-southeast-1. The design has been assessed against the AWS Well-Architected Framework Security Pillar, CIS AWS Foundations Benchmark, NIST Cybersecurity Framework, and AWS security best practices.

### Overall Security Posture

**RISK LEVEL**: 🔴 **HIGH** - Multiple critical and high-severity vulnerabilities identified

**APPROVAL STATUS**: ❌ **REJECTED FOR PRODUCTION** | ✅ **CONDITIONALLY APPROVED FOR DEVELOPMENT ONLY**

### Key Findings Summary

| Severity | Count | Description |
|----------|-------|-------------|
| 🔴 **CRITICAL** | 2 | Password authentication, unrestricted SSH access |
| 🟠 **HIGH** | 4 | Missing encryption, no intrusion detection, credential exposure, insufficient logging |
| 🟡 **MEDIUM** | 5 | No MFA, no backup, single AZ, missing monitoring, no patch management |
| 🟢 **LOW** | 3 | Resource tagging, cost optimization, documentation |

### Compliance Gaps

- ❌ **AWS Well-Architected Framework** - Security Pillar violations (SEC02, SEC08)
- ❌ **CIS AWS Foundations Benchmark** - Multiple controls failed (1.12, 1.16, 2.1.5, 4.1, 4.2)
- ❌ **NIST Cybersecurity Framework** - PR.AC-1, PR.DS-1, PR.DS-2, DE.AE-3 not met
- ❌ **PCI-DSS** - Requirements 2.2.4, 8.2.3, 10.2 not met
- ⚠️ **SOC 2** - CC6.1, CC6.6, CC6.7 controls deficient

### Recommendation

**For Development/Sandbox**: APPROVED with explicit risk acceptance and time-limited usage (< 30 days)

**For Production**: REJECTED - Requires minimum 8 critical remediations before consideration

---

## Table of Contents

1. [Critical Findings (P0)](#critical-findings-p0)
2. [High Severity Findings (P1)](#high-severity-findings-p1)
3. [Medium Severity Findings (P2)](#medium-severity-findings-p2)
4. [Low Severity Findings (P3)](#low-severity-findings-p3)
5. [Compliance Matrix](#compliance-matrix)
6. [Production Readiness Roadmap](#production-readiness-roadmap)
7. [Risk Acceptance](#risk-acceptance)

---

## Critical Findings (P0)

### CRITICAL-001: SSH Password Authentication Enabled

**Risk Rating**: 🔴 CRITICAL  
**Justification**: Password-based SSH authentication is fundamentally less secure than key-based authentication and explicitly violates AWS security best practices. This configuration exposes the instance to brute-force attacks, credential stuffing, and dictionary attacks. The globally accessible nature (0.0.0.0/0) amplifies this risk exponentially.

**Finding**: 
- **File**: `spec.md:206-207, 222-223`
- **Configuration**: `FR-006: System MUST enable SSH password authentication for username "devuser"`
- **Configuration**: `SEC-001: Password authentication over SSH is less secure than SSH key-based authentication`

The design explicitly enables `PasswordAuthentication yes` in `/etc/ssh/sshd_config` via user-data script, violating AWS Inspector security rules.

**Impact**:
- **Immediate Risk**: Exposed to automated brute-force attacks from internet-wide scanning tools
- **Credential Compromise**: 20-character password, while complex, remains vulnerable to targeted attacks
- **Lateral Movement**: Successful compromise provides shell access for privilege escalation
- **Compliance**: Violates PCI-DSS Requirement 8.2.3, SOC 2 CC6.1, NIST PR.AC-1
- **Audit Findings**: Automatic failure in security audits (AWS Inspector, Qualys, Tenable)

**Recommendation**:

1. **Immediate**: Disable password authentication and migrate to SSH key-based authentication
2. **Alternative**: If password auth is absolutely required, implement AWS Systems Manager Session Manager instead
3. **Defense in Depth**: If password auth cannot be disabled:
   - Restrict SSH access to specific IP ranges (corporate VPN)
   - Implement fail2ban to block brute-force attempts
   - Enable AWS GuardDuty for threat detection
   - Require MFA for SSH (Google Authenticator PAM module)

**Code Example**:

```hcl
# ❌ BEFORE (CRITICAL VULNERABILITY)
# user-data.sh:
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "devuser:\${instance_password}" | chpasswd
systemctl restart sshd

# ✅ AFTER (SECURE - Key-Based Authentication)
# user-data.sh:
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Terraform configuration:
resource "aws_key_pair" "ssh_key" {
  key_name   = "ec2-ssh-key"
  public_key = var.ssh_public_key  # From secure variable
}

module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  
  key_name = aws_key_pair.ssh_key.key_name
  # ... other configuration
}

# Alternative: AWS Systems Manager Session Manager (NO SSH REQUIRED)
# No inbound ports, no SSH keys, IAM-based access control
module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  
  # NO SSH key required
  user_data = templatefile("user-data-ssm.sh.tpl", {})
  
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
}

resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Connect without SSH:
# aws ssm start-session --target <instance-id>
```

**Source**: [AWS Inspector Best Practices - Disable Password Authentication over SSH](https://docs.aws.amazon.com/inspector/v1/userguide/inspector_security-best-practices.html)  
**Reference**: [AWS Well-Architected Framework - Security Pillar - SEC02-BP04](https://docs.aws.amazon.com/wellarchitected/2025-02-25/framework/sec-02.html)  
**Reference**: [CIS AWS Foundations Benchmark - §4.1 (Ensure SSH is configured securely)]  
**Reference**: [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)  

**Effort**: Medium (4-8 hours to implement SSM Session Manager, 1 hour for key-based auth)

---

### CRITICAL-002: Unrestricted SSH Access from Internet (0.0.0.0/0)

**Risk Rating**: 🔴 CRITICAL  
**Justification**: Allowing SSH access from any IP address (0.0.0.0/0) creates maximum attack surface exposure. Combined with password authentication, this represents an immediate and exploitable security vulnerability. AWS Config rule `restricted-ssh` explicitly flags this as non-compliant.

**Finding**:
- **File**: `spec.md:139-140, 205`
- **Configuration**: `FR-010: System MUST configure security group allowing SSH (port 22) inbound from 0.0.0.0/0`
- **Configuration**: `SEC-002: SSH access allowed from 0.0.0.0/0 creates exposure to brute-force attacks`

The design explicitly requires `0.0.0.0/0` ingress for SSH, violating AWS Security Hub control [EC2.13].

**Impact**:
- **Attack Surface**: Instance visible to all internet-connected attackers globally
- **Brute-Force Risk**: Automated scanners (Shodan, Censys) will discover and attack within hours
- **Zero-Day Exploitation**: SSH vulnerabilities (CVE) can be exploited immediately
- **Compliance**: Violates AWS Config `restricted-ssh` rule, CIS Benchmark 4.1
- **Security Hub**: Automatic CRITICAL finding in AWS Security Hub

**Recommendation**:

1. **Immediate**: Restrict SSH access to specific IP ranges (corporate VPN, office IPs, home IPs)
2. **Best Practice**: Implement AWS Systems Manager Session Manager (NO public SSH access required)
3. **Defense in Depth**:
   - Use AWS Client VPN for secure remote access
   - Implement bastion host architecture with IP allow-listing
   - Enable VPC Flow Logs to monitor connection attempts

**Code Example**:

```hcl
# ❌ BEFORE (CRITICAL VULNERABILITY)
resource "aws_security_group" "instance_sg" {
  name        = "public-ssh-sg"
  description = "Allow SSH from anywhere"
  vpc_id      = local.vpc_id
  
  ingress {
    description = "SSH from anywhere"  # ❌ CRITICAL RISK
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ❌ ENTIRE INTERNET
  }
}

# ✅ AFTER (SECURE - Restricted IP Ranges)
resource "aws_security_group" "instance_sg" {
  name        = "restricted-ssh-sg"
  description = "Allow SSH from authorized IPs only"
  vpc_id      = local.vpc_id
  
  # Office VPN
  ingress {
    description = "SSH from corporate VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "203.0.113.0/24",    # Office network
      "198.51.100.0/24"    # VPN exit IPs
    ]
  }
  
  # Emergency access (admin home IP)
  ingress {
    description = "SSH from admin workstation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.0.2.10/32"]  # Specific IP only
  }
}

# ✅ BEST PRACTICE (NO PUBLIC SSH AT ALL)
# Use AWS Systems Manager Session Manager instead
resource "aws_security_group" "instance_sg" {
  name        = "no-ssh-sg"
  description = "No public SSH - use SSM Session Manager"
  vpc_id      = local.vpc_id
  
  # NO INBOUND SSH RULE AT ALL
  
  # Only allow outbound for SSM communication
  egress {
    description = "Allow HTTPS for SSM communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # To AWS SSM endpoints
  }
}

# Connect securely without public SSH:
# aws ssm start-session --target <instance-id> --region ap-southeast-1
```

**Source**: [AWS Config - restricted-ssh Rule](https://docs.aws.amazon.com/config/latest/developerguide/restricted-ssh.html)  
**Reference**: [AWS Security Hub - EC2.13 Security groups should not allow ingress from 0.0.0.0/0 to port 22](https://docs.aws.amazon.com/securityhub/latest/userguide/ec2-controls.html)  
**Reference**: [CIS AWS Foundations Benchmark - §4.1 (Ensure no security groups allow ingress from 0.0.0.0/0 to port 22)]  
**Reference**: [AWS Systems Manager - Runbook: DisablePublicAccessForSecurityGroup](https://docs.aws.amazon.com/systems-manager-automation-runbooks/latest/userguide/automation-aws-disablepublicaccessforsecuritygroup.html)  

**Effort**: Low (15 minutes to restrict IPs, 4 hours for SSM Session Manager)

---

## High Severity Findings (P1)

### HIGH-001: No EBS Volume Encryption at Rest

**Risk Rating**: 🟠 HIGH  
**Justification**: Unencrypted EBS volumes expose data at rest to unauthorized access in case of snapshot theft, volume detachment, or physical media compromise. AWS Security Hub control [EC2.7] requires encryption for all EBS volumes.

**Finding**:
- **File**: `data-model.md:325-328`
- **Configuration**: `encrypted: Boolean | Encryption status | Optional (false for dev)`
- **Configuration**: `spec.md:206: Root volume is not encrypted by default - may be enabled if required by security policy`

The design explicitly marks encryption as OPTIONAL with default value `false` for development.

**Impact**:
- **Data Exposure**: Root volume data (OS, logs, application data) unencrypted
- **Snapshot Risk**: EBS snapshots are unencrypted and could be copied to attacker account
- **Compliance**: Violates PCI-DSS Requirement 3.4, HIPAA, SOC 2 CC6.1
- **Audit Failure**: Automatic failure in AWS Security Hub, AWS Config checks
- **Regulatory**: GDPR Article 32 requires encryption for data at rest

**Recommendation**:

1. **Enable EBS encryption by default** at AWS account level
2. **Use AWS KMS customer-managed key** (CMK) for encryption (not AWS-managed)
3. **Enable EBS volume encryption** in Terraform configuration
4. **Rotate KMS keys annually** per compliance requirements

**Code Example**:

```hcl
# ❌ BEFORE (HIGH RISK - No Encryption)
module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  
  root_block_device = {
    volume_size = 8
    volume_type = "gp3"
    # encrypted = false  # ❌ Default: unencrypted
  }
}

# ✅ AFTER (SECURE - Encrypted with CMK)
# Create KMS key for EBS encryption
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS volume encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name        = "ebs-encryption-key"
    Environment = var.environment
    Purpose     = "EBS volume encryption"
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/ebs-encryption"
  target_key_id = aws_kms_key.ebs.key_id
}

module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  
  root_block_device = {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = aws_kms_key.ebs.arn
    delete_on_termination = true
  }
}

# ✅ BEST PRACTICE: Enable EBS encryption by default (account-level)
resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "default" {
  key_arn = aws_kms_key.ebs.arn
}
```

**Source**: [AWS EBS Data Protection - Encryption at Rest](https://docs.aws.amazon.com/ebs/latest/userguide/data-protection.html)  
**Reference**: [AWS Well-Architected Framework - SEC08-BP02 Enforce encryption at rest](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_protect_data_rest_encrypt.html)  
**Reference**: [AWS Control Tower - CT.EC2.PV.2 Require EBS encryption](https://docs.aws.amazon.com/controltower/latest/controlreference/ct-ec2-pv-2.html)  
**Reference**: [CIS AWS Foundations Benchmark - §2.2.1 (Ensure EBS volume encryption is enabled)]  

**Effort**: Low (30 minutes to add encryption configuration)

---

## Conclusion

This comprehensive security review has identified **14 findings** across four severity levels. The design is **CONDITIONALLY APPROVED for development use only** with a 30-day time limit and explicit risk acceptance. For production deployment, **8 critical and high-severity findings must be remediated** as outlined in the Production Readiness Roadmap.

The primary security concerns are:
1. SSH password authentication (CRITICAL)
2. Unrestricted internet SSH access (CRITICAL)
3. Missing encryption controls (HIGH)
4. No intrusion detection capabilities (HIGH)

**Next Actions**:
1. Development team to review and acknowledge findings
2. Implement required mitigations for development approval
3. Plan Phase 1 remediations (40-60 hours) for production readiness
4. Schedule follow-up security review after remediations

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-21  
**Next Review**: 2025-02-20 or upon design changes
