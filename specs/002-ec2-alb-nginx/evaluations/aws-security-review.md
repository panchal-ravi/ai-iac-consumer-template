# AWS Security Review: EC2 Infrastructure with ALB and Nginx

**Feature**: 002-ec2-alb-nginx  
**Reviewer**: AWS Security Advisor  
**Date**: 2025-02-01  
**Review Status**: Planning Phase (Pre-Implementation)  
**Risk Level**: **MEDIUM** - Multiple high-priority security issues identified

---

## Executive Summary

This security review evaluates the planned AWS infrastructure design for deploying EC2 instances with Application Load Balancer and Nginx. The design includes **3 HIGH priority** and **5 MEDIUM priority** security findings that must be addressed before production deployment. The infrastructure uses a self-signed TLS certificate and default VPC, which are acceptable for development but require significant hardening for production use.

**Critical Blockers for Production**: None (development environment acceptable)  
**High Priority Issues**: 3 findings requiring immediate attention  
**Medium Priority Issues**: 5 findings to address in current sprint  
**Low Priority Issues**: 2 backlog items  

**Overall Security Posture**: Acceptable for development/demo environment with documented security limitations. **NOT suitable for production** without significant security enhancements.

---

## Security Findings Summary

| # | Issue | Risk | Priority | Effort |
|---|-------|------|----------|--------|
| 1 | Private Key Exposure in Terraform State | High | P1 | Medium |
| 2 | Self-Signed TLS Certificate (Browser Warnings) | High | P1 | High |
| 3 | Public Subnet Exposure of EC2 Instances | High | P1 | Low |
| 4 | Missing VPC Flow Logs | Medium | P2 | Low |
| 5 | No CloudTrail Logging Configuration | Medium | P2 | Low |
| 6 | Overly Permissive EC2 Egress Rules | Medium | P2 | Low |
| 7 | Missing EC2 Instance Metadata Service v2 (IMDSv2) | Medium | P2 | Low |
| 8 | Default VPC Security Implications | Medium | P2 | N/A |
| 9 | Missing Resource Tagging for Security | Low | P3 | Low |
| 10 | No Session Manager Access Configuration | Low | P3 | Medium |

---

## HIGH Priority Findings (P1)

### 1. Private Key Exposure in Terraform State

**Risk Rating**: High  
**Justification**: TLS private key stored in plain text within Terraform state file creates a persistent security risk. If state file is compromised, attacker gains complete access to decrypt all HTTPS traffic.

**Finding**: 
- **Location**: `research.md:85-90` and `data-model.md:69-70`
- **Issue**: Self-signed TLS certificate private key will be stored unencrypted in Terraform state
- Code shows: `resource "tls_private_key" "self_signed"` with private key in state

**Impact**: 
- **Confidentiality**: Complete TLS traffic decryption if state file leaked
- **Integrity**: Man-in-the-middle attacks possible with stolen private key
- **Compliance**: Violates NIST 800-53 SC-12 (Cryptographic Key Management)
- **Exposure Window**: Persistent - key remains in state file indefinitely

**Evidence from Design**:
```
data-model.md:85-87:
"- Private key stored in Terraform state (encrypted in HCP Terraform)
 - Private key marked as sensitive (not displayed in outputs)
 - Changing any attribute forces recreation of all certificate resources"
```

**Recommendation**:
1. **Immediate**: Verify HCP Terraform workspace has encryption-at-rest enabled for state files
2. **Short-term**: Implement strict IAM policies limiting state file access to CI/CD pipeline only
3. **Production**: Use AWS ACM with DNS validation instead of self-signed certificates
4. **Best Practice**: Never store production private keys in Terraform state

**Code Example**:
```hcl
# Current Design (Vulnerable)
resource "tls_private_key" "self_signed" {
  algorithm = "RSA"
  rsa_bits  = 2048
  # ❌ HIGH: Private key stored in state file
}

# Recommended for Production
resource "aws_acm_certificate" "web" {
  domain_name       = "web.demo.com"
  validation_method = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
  # ✅ Private key managed by ACM, never exposed
}

# Add DNS validation records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.web.domain_validation_options : dvo.domain_name => {
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
```

**Source**: [AWS Certificate Manager Data Protection](https://docs.aws.amazon.com/acm/latest/userguide/data-protection.html)  
**Reference**: [AWS Well-Architected SEC09-BP01](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_key_cert_mgmt.html) - "Using self-signed certificates for public resources" listed as anti-pattern  
**Additional**: [Terraform State File Security](https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-sensitive-data-secrets-manager-terraform/terraform-state-file.html)  
**Effort**: Medium (3-4 hours for ACM + Route53 setup)

---

### 2. Self-Signed TLS Certificate Production Unsuitability

**Risk Rating**: High  
**Justification**: Self-signed certificates create security warnings that users will ignore, training them to accept certificate errors - a critical security anti-pattern that enables phishing and MITM attacks.

**Finding**:
- **Location**: `spec.md:92-93` (FR-003, FR-004), `research.md:39-91`
- **Issue**: Design explicitly uses self-signed certificate without browser trust chain
- Specification states: "Generate self-signed TLS certificate for domain 'web.demo.com'"

**Impact**:
- **User Security**: Trains users to click through certificate warnings (phishing enabler)
- **Trust**: No certificate transparency logging, can't verify certificate legitimacy
- **Compliance**: Fails PCI-DSS 4.1 (encryption in transit with trusted certificates)
- **Browser Warnings**: "Your connection is not private" warnings on every access

**Evidence from Design**:
```
data-model.md:481-483:
"Certificate States:
- PENDING_VALIDATION → Not applicable (self-signed, no validation)
- ISSUED → Certificate available in ACM (FR-004)"

research.md:90-92:
"- Not suitable for production (browser warnings), but acceptable 
   for development/demo per spec"
```

**Recommendation**:
1. **Development**: Document that self-signed certificate is **development only**
2. **Production Migration Path**:
   - Register domain in Route53 or external DNS
   - Use ACM with DNS validation for automated certificate management
   - Enable automatic certificate renewal (ACM handles this)
3. **Alternative**: Use AWS CloudFront with ACM certificate (even for demo)

**Code Example**:
```hcl
# Current Design (Development Only)
resource "tls_self_signed_cert" "self_signed" {
  # ❌ HIGH: Browser warnings, no trust chain
  validity_period_hours = 8760  # Manual renewal required
}

# Recommended Production Approach
resource "aws_acm_certificate" "web" {
  domain_name       = "web.demo.com"
  validation_method = "DNS"
  
  tags = {
    Environment = "production"
    AutoRenewal = "true"  # ✅ ACM handles renewal automatically
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Certificate auto-renews before expiration
resource "aws_acm_certificate_validation" "web" {
  certificate_arn         = aws_acm_certificate.web.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
```

**Source**: [AWS Well-Architected Framework SEC09-BP01](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_key_cert_mgmt.html)  
**Reference**: [OWASP Transport Layer Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html)  
**CIS Benchmark**: CIS AWS Foundations Benchmark v1.5.0 - Section 2.1.1 (Use secure connections)  
**Effort**: High (requires domain registration + DNS configuration, 4-6 hours)

---

### 3. EC2 Instances in Public Subnets with Public IP Addresses

**Risk Rating**: High  
**Justification**: EC2 instances with public IPs in public subnets expand attack surface unnecessarily. While security groups restrict access, this violates defense-in-depth and creates unnecessary internet exposure.

**Finding**:
- **Location**: `data-model.md:186` and `research.md:246-251`
- **Issue**: Design places EC2 instances in default VPC public subnets with `associate_public_ip_address = true`
- Instances directly reachable from internet (security group is only protection layer)

**Impact**:
- **Attack Surface**: Instances have public IPs, expanding internet-facing attack surface
- **Defense-in-Depth Violation**: Single security group failure exposes instances directly
- **Reconnaissance**: Public IPs enable port scanning, OS fingerprinting
- **Compliance**: Fails CIS AWS Benchmark 5.3 (EC2 instances should not have public IPs)
- **Best Practice Violation**: Web tier should be in private subnets behind load balancer

**Evidence from Design**:
```
data-model.md:186:
"associate_public_ip_address | bool | Public IP assignment | Yes | true"

research.md:246-251:
"#### ALB Placement
- Decision: Public-facing ALB in public subnets
- Rationale:
  - Requirement FR-009: Allow HTTPS traffic from internet
  - Default VPC subnets are public with internet gateway"
```

**Recommendation**:
1. **Immediate Fix**: Set `associate_public_ip_address = false` on EC2 instances
2. **Architecture**: Place EC2 instances in private subnets (create if needed)
3. **Internet Access**: Add NAT Gateway to private subnets for outbound traffic (yum updates)
4. **ALB**: Keep ALB in public subnets (correct), instances in private subnets
5. **Access**: Use AWS Systems Manager Session Manager instead of SSH

**Code Example**:
```hcl
# Current Design (Vulnerable)
module "ec2_instance" {
  # ...
  associate_public_ip_address = true  # ❌ HIGH: Public internet exposure
  subnet_id                   = data.aws_subnet.public[each.key].id
  # Instance directly accessible from internet (security group permitting)
}

# Recommended Secure Design
# 1. Create private subnets (if using default VPC, may need new VPC)
resource "aws_subnet" "private" {
  for_each = toset(["ap-southeast-1a", "ap-southeast-1b"])
  
  vpc_id                  = data.aws_vpc.default.id
  availability_zone       = each.key
  cidr_block             = cidrsubnet(data.aws_vpc.default.cidr_block, 4, index(["ap-southeast-1a", "ap-southeast-1b"], each.key) + 10)
  map_public_ip_on_launch = false  # ✅ Private subnet
  
  tags = {
    Name = "${var.project_name}-private-${each.key}"
    Tier = "private"
  }
}

# 2. Place EC2 in private subnets
module "ec2_instance" {
  # ...
  associate_public_ip_address = false  # ✅ No public IP
  subnet_id                   = aws_subnet.private[each.key].id
  # Instance NOT directly accessible from internet
}

# 3. ALB remains in public subnets (correct)
module "alb" {
  # ...
  subnets = [for s in data.aws_subnet.public : s.id]  # ✅ ALB public, instances private
}

# 4. NAT Gateway for instance outbound (yum updates)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnet.public["ap-southeast-1a"].id
  
  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

# 5. Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id  # ✅ Outbound via NAT
  }
  
  tags = {
    Name = "${var.project_name}-private-rt"
  }
}
```

**Source**: [VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)  
**Reference**: [CIS AWS Foundations Benchmark v1.5.0 - Section 5.3](https://www.cisecurity.org/benchmark/amazon_web_services)  
**Additional**: [AWS Well-Architected SEC05-BP02](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_layered.html) - Implement network segmentation  
**Effort**: Low (1-2 hours to remove public IPs, Medium 3-4 hours for full private subnet architecture)

**Note**: Using default VPC constrains architecture - consider creating dedicated VPC with proper public/private subnet separation for production.

---

## MEDIUM Priority Findings (P2)

### 4. Missing VPC Flow Logs for Network Traffic Monitoring

**Risk Rating**: Medium  
**Justification**: No network traffic logging impairs security incident investigation, threat detection, and compliance auditing. Cannot identify unusual traffic patterns, port scans, or data exfiltration attempts.

**Finding**:
- **Location**: Absence in all design documents
- **Issue**: No VPC Flow Logs configured for network traffic visibility
- Design includes no monitoring or logging infrastructure

**Impact**:
- **Incident Response**: Cannot investigate security incidents retroactively
- **Threat Detection**: No visibility into network-based attacks (port scans, DDoS)
- **Compliance**: Fails SOC 2 CC7.2 (monitoring system components)
- **Forensics**: No audit trail for network traffic during breach investigation
- **Cost**: Minimal (~$0.50-1.00/month for development traffic volumes)

**Recommendation**:
1. Enable VPC Flow Logs for the default VPC
2. Send logs to CloudWatch Logs or S3 bucket
3. Retain logs for minimum 90 days (best practice: 1 year)
4. Consider Amazon GuardDuty (analyzes Flow Logs for threats automatically)

**Code Example**:
```hcl
# Add VPC Flow Logs
resource "aws_flow_log" "main" {
  vpc_id          = data.aws_vpc.default.id
  traffic_type    = "ALL"  # ACCEPT, REJECT, or ALL
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc-flow-logs"
  })
}

# CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = 90  # ✅ 90-day retention for security analysis
  
  kms_key_id = aws_kms_key.logs.arn  # ✅ Encrypt logs at rest
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-flow-logs"
  })
}

# IAM Role for Flow Logs
resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}
```

**Source**: [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)  
**Reference**: [AWS Security Best Practices - VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)  
**Additional**: [AWS Security Incident Response Guide - Logging Trifecta](https://docs.aws.amazon.com/whitepapers/latest/aws-security-incident-response-guide/select-and-enable-log-sources.html)  
**Effort**: Low (1 hour to implement)

---

### 5. No CloudTrail Logging for API Activity Auditing

**Risk Rating**: Medium  
**Justification**: Missing CloudTrail logging eliminates audit trail for all AWS API activity, preventing detection of unauthorized configuration changes, privilege escalation, or malicious resource modifications.

**Finding**:
- **Location**: Absence in all design documents  
- **Issue**: No CloudTrail trail configured for AWS account activity
- Cannot audit who created, modified, or deleted infrastructure resources

**Impact**:
- **Audit Trail**: No record of infrastructure changes (who deployed what, when)
- **Incident Response**: Cannot determine attack timeline or affected resources
- **Compliance**: Fails PCI-DSS 10.1 (audit trail requirements), SOC 2 CC6.1
- **Insider Threats**: Cannot detect unauthorized actions by privileged users
- **Cost**: ~$2.00/month for 100,000 events (typical for small infrastructure)

**Recommendation**:
1. Create CloudTrail trail for all management events
2. Enable multi-region trail (covers all AWS regions)
3. Store logs in encrypted S3 bucket with versioning
4. Enable log file validation (integrity checking)
5. Set up CloudWatch alarms for critical events (security group changes, IAM modifications)

**Code Example**:
```hcl
# S3 Bucket for CloudTrail Logs
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.project_name}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-cloudtrail-logs"
  })
}

# Enable versioning (prevent log deletion)
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  versioning_configuration {
    status = "Enabled"  # ✅ Protect against log deletion
  }
}

# Encrypt CloudTrail logs at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # ✅ Encrypt logs
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudTrail bucket policy
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AWSCloudTrailAclCheck"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action   = "s3:GetBucketAcl"
      Resource = aws_s3_bucket.cloudtrail.arn
    },
    {
      Sid    = "AWSCloudTrailWrite"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl" = "bucket-owner-full-control"
        }
      }
    }]
  })
}

# CloudTrail Trail
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true  # ✅ Cover all regions
  enable_log_file_validation    = true  # ✅ Integrity checking
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true  # ✅ Track infrastructure changes
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-cloudtrail"
  })
  
  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# CloudWatch alarm for security group changes
resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  alarm_name          = "${var.project_name}-security-group-changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SecurityGroupEventCount"
  namespace           = "CloudTrailMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert on security group changes"
  treat_missing_data  = "notBreaching"
  
  # Add SNS topic for notifications
  alarm_actions = [aws_sns_topic.security_alerts.arn]
}
```

**Source**: [CloudTrail User Guide](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html)  
**Reference**: [AWS Security Best Practices - Logging and Monitoring](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-controls-by-caf-capability/logging-and-monitoring-controls.html)  
**CIS Benchmark**: CIS AWS Foundations Benchmark v1.5.0 - Section 3.1-3.11 (CloudTrail requirements)  
**Effort**: Low (1-2 hours to implement)

---

### 6. Overly Permissive EC2 Instance Egress Rules

**Risk Rating**: Medium  
**Justification**: Allowing all outbound traffic (0.0.0.0/0 on all ports) violates least privilege and enables data exfiltration, command-and-control callbacks, and lateral movement if instance is compromised.

**Finding**:
- **Location**: `research.md:330-338` (EC2 Security Group egress rules)
- **Issue**: Egress rule allows ALL traffic to 0.0.0.0/0 instead of restricting to required destinations
- Design states: `cidr_blocks = ["0.0.0.0/0"]` with protocol `-1` (all protocols)

**Impact**:
- **Data Exfiltration**: Compromised instance can send data anywhere on internet
- **Command & Control**: Malware can communicate with external C2 servers
- **Least Privilege Violation**: Unnecessary network permissions
- **Compliance**: Fails principle of least privilege (NIST 800-53 AC-6)

**Evidence from Design**:
```
research.md:330-338:
"egress_rules = {
  all = {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound for system updates"
  }
}"
```

**Recommendation**:
1. **Restrict to Required Services**: Only allow HTTPS (443) for yum/apt updates
2. **Use VPC Endpoints**: Configure VPC endpoints for S3, EC2, Systems Manager (no internet needed)
3. **Specific Destinations**: Whitelist only required destinations (yum repositories, AWS endpoints)
4. **Monitor**: Use VPC Flow Logs to identify actual egress requirements

**Code Example**:
```hcl
# Current Design (Overly Permissive)
module "ec2_sg" {
  # ...
  egress_rules = {
    all = {
      protocol    = "-1"  # ❌ MEDIUM: All protocols
      cidr_blocks = ["0.0.0.0/0"]  # ❌ All destinations
    }
  }
}

# Recommended Restrictive Design
module "ec2_sg" {
  # ...
  egress_rules = {
    # HTTPS for package updates (yum/apt repositories)
    https_updates = {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]  # ✅ Specific protocol, still allows updates
      description = "HTTPS for system package updates"
    }
    
    # HTTP for package updates (some repos still use HTTP)
    http_updates = {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP for legacy package repositories"
    }
    
    # DNS for name resolution
    dns_tcp = {
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.default.cidr_block]  # ✅ VPC DNS only
      description = "DNS TCP queries"
    }
    
    dns_udp = {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = [data.aws_vpc.default.cidr_block]
      description = "DNS UDP queries"
    }
    
    # NTP for time synchronization
    ntp = {
      from_port   = 123
      to_port     = 123
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]  # NTP servers
      description = "NTP time synchronization"
    }
  }
}

# Better: Use VPC Endpoints (no internet egress needed)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.ap-southeast-1.s3"
  
  route_table_ids = [data.aws_vpc.default.main_route_table_id]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.ap-southeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [module.vpc_endpoints_sg.security_group_id]
  subnet_ids          = [for s in data.aws_subnet.az : s.id]
  private_dns_enabled = true  # ✅ Use private DNS, no internet needed
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ssm-endpoint"
  })
}
```

**Source**: [VPC Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)  
**Reference**: [AWS Well-Architected SEC05-BP01](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_stateless_stateful.html) - Create network layers  
**Additional**: [VPC Endpoints for AWS Services](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)  
**Effort**: Low (1 hour to restrict egress rules)

---

### 7. Missing EC2 Instance Metadata Service v2 (IMDSv2) Enforcement

**Risk Rating**: Medium  
**Justification**: Not enforcing IMDSv2 leaves instances vulnerable to Server-Side Request Forgery (SSRF) attacks that can steal IAM credentials from instance metadata service.

**Finding**:
- **Location**: Absence in `data-model.md:176-227` (EC2 Instance attributes)
- **Issue**: No configuration for Instance Metadata Service version
- Default behavior allows IMDSv1 (vulnerable to SSRF credential theft)

**Impact**:
- **Credential Theft**: SSRF attacks can retrieve IAM role credentials from metadata
- **Privilege Escalation**: Stolen credentials grant attacker EC2 instance permissions
- **Attack Vector**: IMDSv1 uses simple HTTP GET (no session token protection)
- **Compliance**: AWS best practice recommends IMDSv2 for all new instances

**Recommendation**:
1. Enforce IMDSv2 by setting `http_tokens = "required"` on all EC2 instances
2. Set `http_put_response_hop_limit = 1` to prevent container escapes
3. Consider disabling metadata service entirely if not needed (`http_endpoint = "disabled"`)

**Code Example**:
```hcl
# Current Design (Uses Default - Vulnerable)
module "ec2_instance" {
  # ... no metadata_options specified
  # ❌ MEDIUM: Defaults to IMDSv1 allowed (SSRF vulnerable)
}

# Recommended Secure Configuration
module "ec2_instance" {
  for_each = toset(local.availability_zones)
  
  source = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  
  # ... other configuration ...
  
  # Enforce IMDSv2
  metadata_options = {
    http_endpoint               = "enabled"   # Enable metadata service
    http_tokens                 = "required"  # ✅ Enforce IMDSv2 (session tokens)
    http_put_response_hop_limit = 1           # ✅ Prevent container escapes
    instance_metadata_tags      = "enabled"   # Optional: enable instance tags
  }
}

# Verify IMDSv2 enforcement with launch template (if using module with launch template)
# The module should support these metadata_options parameters
```

**Testing IMDSv2**:
```bash
# Old IMDSv1 (should fail with IMDSv2 enforcement)
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# IMDSv2 (requires session token)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

**Source**: [Use IMDSv2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)  
**Reference**: [AWS Security Best Practice - IMDSv2](https://docs.aws.amazon.com/securityhub/latest/userguide/ec2-controls.html#ec2-8)  
**Additional**: [SSRF Attack Mitigation](https://docs.aws.amazon.com/whitepapers/latest/security-practices-multi-tenant-saas-applications-eks/restrict-the-use-of-host-networking-and-block-access-to-instance-metadata-service.html)  
**Effort**: Low (15 minutes to add metadata_options to module configuration)

---

### 8. Default VPC Security Implications

**Risk Rating**: Medium  
**Justification**: Using default VPC creates security and architectural constraints including pre-existing resources, shared infrastructure, and inability to implement network isolation best practices.

**Finding**:
- **Location**: `spec.md:96` (FR-008), `research.md:93-155`
- **Issue**: Mandatory requirement to use existing default VPC
- Design states: "MUST use the existing default VPC in ap-southeast-1 region"

**Impact**:
- **Shared Resources**: Default VPC may have pre-existing resources from other projects
- **Network Design**: Default VPC CIDR (172.31.0.0/16) may conflict with corporate networks
- **Segmentation**: All subnets are public by default (no private subnet separation)
- **Immutability**: Cannot delete/recreate default VPC without AWS Support
- **Best Practices**: AWS recommends custom VPCs for production workloads
- **Acceptable for Development**: Suitable for demo/dev, not production

**Evidence from Design**:
```
research.md:120-125:
"Best Practices:
- Verify default VPC exists in region before deployment
- Use data sources instead of hardcoding VPC/subnet IDs
- Document dependency on default VPC existence
- Implement validation to fail fast if default VPC missing"
```

**Recommendation**:
1. **Development**: Document that default VPC usage is **development/demo only**
2. **Production Migration**: Create dedicated VPC with proper segmentation:
   - Public subnets for ALB (2 AZs)
   - Private subnets for EC2 instances (2 AZs)
   - Private subnets for data tier (2 AZs) - future expansion
   - Dedicated CIDR range (non-overlapping with corporate network)
3. **Validation**: Add Terraform validation to check for default VPC conflicts
4. **Tagging**: Tag all resources with "DefaultVPC=true" for visibility

**Code Example**:
```hcl
# Current Design (Default VPC - Development Only)
data "aws_vpc" "default" {
  default = true  # ❌ MEDIUM: Default VPC has security limitations
}

# Add validation
resource "null_resource" "vpc_validation" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "WARNING: Using default VPC - suitable for development only"
      echo "For production, create dedicated VPC with proper network segmentation"
    EOT
  }
}

# Recommended Production VPC Design
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"  # ✅ Custom CIDR range
  
  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]  # ✅ EC2 instances
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]  # ✅ ALB only
  
  enable_nat_gateway = true
  single_nat_gateway = false  # ✅ High availability (NAT per AZ)
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_retention_in_days           = 90
  
  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    VPCType     = "dedicated"  # ✅ Not default VPC
  })
}
```

**Source**: [VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)  
**Reference**: [AWS Well-Architected SEC05-BP02](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_layered.html)  
**Note**: This is a **design constraint** rather than a vulnerability. Document as accepted risk for development environment.  
**Effort**: N/A for current requirement (would be High 6-8 hours for production VPC migration)

---

## LOW Priority Findings (P3)

### 9. Incomplete Security-Related Resource Tagging

**Risk Rating**: Low  
**Justification**: Missing security-specific tags (DataClassification, SecurityLevel, ComplianceScope) reduces security visibility and complicates compliance auditing, but doesn't directly create vulnerabilities.

**Finding**:
- **Location**: `research.md:432-455` and `data-model.md:516-528`
- **Issue**: Tagging strategy missing security-specific metadata
- Current tags focus on cost tracking and environment, not security classification

**Impact**:
- **Visibility**: Cannot filter resources by data sensitivity or compliance scope
- **Compliance**: Harder to demonstrate compliance (HIPAA, PCI, SOC2)
- **Risk Assessment**: Cannot quickly identify high-value/high-risk resources
- **Automation**: Security tools can't auto-configure based on data classification

**Recommendation**:
Add security-specific tags to `common_tags`:
- `DataClassification`: Public/Internal/Confidential/Restricted
- `SecurityLevel`: development/staging/production
- `ComplianceScope`: PCI/HIPAA/SOC2/None
- `DataRetention`: 30d/90d/1y/7y
- `BackupRequired`: true/false

**Code Example**:
```hcl
# Current Tagging (Incomplete)
locals {
  common_tags = {
    Environment      = var.environment
    ManagedBy        = "terraform"
    Project          = var.project_name
    # ❌ LOW: Missing security classification tags
  }
}

# Recommended Enhanced Tagging
locals {
  common_tags = {
    # Existing tags
    Environment      = var.environment
    ManagedBy        = "terraform"
    Project          = var.project_name
    
    # ✅ Security-specific tags
    DataClassification = "Internal"  # Public/Internal/Confidential/Restricted
    SecurityLevel      = "development"  # development/staging/production
    ComplianceScope    = "None"  # PCI/HIPAA/SOC2/None (development has none)
    DataRetention      = "30d"  # Retention policy
    BackupRequired     = "false"  # Development doesn't require backups
    SecurityContact    = "security@example.com"
    CostCenter         = "engineering-demo"
    ChangeTicket       = "JIRA-123"  # Track to change management
  }
}

# Tag validation
variable "data_classification" {
  type        = string
  description = "Data classification level"
  
  validation {
    condition     = contains(["Public", "Internal", "Confidential", "Restricted"], var.data_classification)
    error_message = "Data classification must be Public, Internal, Confidential, or Restricted."
  }
}
```

**Source**: [AWS Tagging Best Practices](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html)  
**Reference**: [AWS Well-Architected SEC01-BP01](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_securely_operate_aws_account_identifiers.html)  
**Effort**: Low (30 minutes to add tags)

---

### 10. No AWS Systems Manager Session Manager Configuration

**Risk Rating**: Low  
**Justification**: Lack of Session Manager configuration prevents secure, audited instance access. Not critical since design blocks SSH entirely, but Session Manager provides better security than SSH for troubleshooting.

**Finding**:
- **Location**: Absence in design documents
- **Issue**: No Session Manager endpoint or IAM permissions configured
- Design blocks SSH access (good) but provides no alternative access method

**Impact**:
- **Troubleshooting**: No secure way to access instances for debugging
- **Audit Trail**: Cannot track who accessed instances and when
- **Port 22**: Would need to open SSH in security group for emergency access (bad practice)
- **Productivity**: Operations team has no access for log review, config verification

**Recommendation**:
1. Add VPC Interface Endpoint for Systems Manager
2. Add Session Manager permissions to EC2 IAM instance profile
3. Enable Session Manager logging to S3 and CloudWatch
4. Use Session Manager instead of SSH for all instance access

**Code Example**:
```hcl
# VPC Endpoint for Systems Manager
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.ap-southeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = [for s in data.aws_subnet.az : s.id]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.ap-southeast-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = [for s in data.aws_subnet.az : s.id]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.ap-southeast-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = [for s in data.aws_subnet.az : s.id]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2messages-endpoint"
  })
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "HTTPS from VPC"
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc-endpoints-sg"
  })
}

# IAM Policy for Session Manager
resource "aws_iam_role_policy" "session_manager" {
  name = "${var.project_name}-session-manager-policy"
  role = module.ec2_instance["ap-southeast-1a"].iam_role_name  # Attach to EC2 role
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          aws_s3_bucket.session_logs.arn,
          "${aws_s3_bucket.session_logs.arn}/*"
        ]
      }
    ]
  })
}

# S3 bucket for session logs
resource "aws_s3_bucket" "session_logs" {
  bucket = "${var.project_name}-session-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-session-logs"
  })
}

# Enable session logging
resource "aws_ssm_document" "session_preferences" {
  name            = "${var.project_name}-session-preferences"
  document_type   = "Session"
  document_format = "JSON"
  
  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session preferences for logging"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName                = aws_s3_bucket.session_logs.id
      s3KeyPrefix                 = "session-logs/"
      s3EncryptionEnabled         = true
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.session_logs.name
      cloudWatchEncryptionEnabled = true
    }
  })
}

# Usage: Connect to instance without SSH
# aws ssm start-session --target <instance-id> --region ap-southeast-1
```

**Source**: [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)  
**Reference**: [AWS Security Best Practices - Secure Instance Access](https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-bastion/session-manager.html)  
**Effort**: Medium (2-3 hours to configure VPC endpoints and IAM permissions)

---

## Security Architecture Strengths

The design demonstrates several security best practices:

✅ **HTTPS-Only Access**: No HTTP listener, enforces encryption in transit (FR-010, SC-004)  
✅ **Network Isolation**: Security groups restrict EC2 access to ALB only (FR-011)  
✅ **IAM Instance Profiles**: No hardcoded credentials, uses IAM roles (FR-012)  
✅ **Multi-AZ Deployment**: High availability across 2 availability zones (FR-001)  
✅ **Modern TLS Policy**: Uses `ELBSecurityPolicy-TLS13-1-2-2021-06` (research.md:217)  
✅ **Remote State Encryption**: HCP Terraform provides encrypted state storage  
✅ **No SSH Access**: Security groups block direct SSH (SC-006) - defense in depth  
✅ **Module-First Architecture**: Uses vetted private registry modules (constitution compliance)  

---

## Compliance Assessment

### CIS AWS Foundations Benchmark v1.5.0

| Control | Status | Finding |
|---------|--------|---------|
| 2.1.1 - Use secure connections | ⚠️ Partial | HTTPS enforced, but self-signed cert (Finding #2) |
| 3.1-3.11 - CloudTrail | ❌ Fail | No CloudTrail configured (Finding #5) |
| 5.1 - No overly permissive security groups | ✅ Pass | Security groups are restrictive |
| 5.3 - EC2 instances should not have public IPs | ❌ Fail | Public IPs assigned (Finding #3) |
| 5.4 - VPC Flow Logs enabled | ❌ Fail | No Flow Logs (Finding #4) |

**Overall CIS Compliance**: 1/5 controls passing (20%)

### NIST 800-53 Security Controls

| Control | Status | Gap |
|---------|--------|-----|
| AC-6 (Least Privilege) | ⚠️ Partial | Egress too permissive (Finding #6) |
| AU-2 (Audit Events) | ❌ Fail | No CloudTrail/Flow Logs (Findings #4, #5) |
| SC-8 (Transmission Confidentiality) | ✅ Pass | HTTPS enforced |
| SC-12 (Cryptographic Key Management) | ⚠️ Partial | Private key in state (Finding #1) |
| SC-13 (Cryptographic Protection) | ✅ Pass | TLS 1.3 supported |

**Overall NIST Compliance**: 2/5 controls passing (40%)

### SOC 2 Trust Service Criteria

| Criterion | Status | Note |
|-----------|--------|------|
| CC6.1 (Logical Access) | ⚠️ Partial | IAM roles used, but no CloudTrail audit |
| CC6.6 (Encryption) | ✅ Pass | HTTPS encryption in transit |
| CC7.2 (System Monitoring) | ❌ Fail | No VPC Flow Logs, no CloudTrail (Findings #4, #5) |
| CC7.3 (Incident Response) | ❌ Fail | No logging for incident investigation |

**Overall SOC 2 Readiness**: Not ready (development environment)

---

## Production Readiness Checklist

Before deploying to production, address these critical gaps:

### Security (Must-Have)
- [ ] **Replace self-signed certificate** with ACM certificate + DNS validation (Finding #2)
- [ ] **Move EC2 to private subnets** (Finding #3)
- [ ] **Enable VPC Flow Logs** with 90-day retention (Finding #4)
- [ ] **Enable CloudTrail** multi-region trail with log file validation (Finding #5)
- [ ] **Restrict egress rules** to required destinations only (Finding #6)
- [ ] **Enforce IMDSv2** on all EC2 instances (Finding #7)
- [ ] **Migrate to dedicated VPC** with proper segmentation (Finding #8)
- [ ] **Enable CloudWatch alarms** for security events
- [ ] **Configure AWS Config** for compliance monitoring
- [ ] **Enable GuardDuty** for threat detection

### Identity & Access (Must-Have)
- [ ] **Review IAM policies** for least privilege
- [ ] **Enable MFA** on all AWS accounts
- [ ] **Implement AWS SSO** for human access
- [ ] **Configure Session Manager** for instance access (Finding #10)
- [ ] **Remove all SSH access** (already done in design)

### Monitoring & Logging (Must-Have)
- [ ] **CloudWatch dashboards** for infrastructure health
- [ ] **SNS topics** for security alerts
- [ ] **Log aggregation** to SIEM or CloudWatch Logs Insights
- [ ] **Retention policies** (90 days minimum for security logs)

### Network Security (Recommended)
- [ ] **AWS WAF** on ALB for application firewall
- [ ] **Network ACLs** for subnet-level controls
- [ ] **VPC Endpoints** for AWS services (reduce internet egress)
- [ ] **PrivateLink** for internal service communication
- [ ] **Route53 Health Checks** with failover

### Data Protection (Recommended)
- [ ] **EBS encryption** enabled by default
- [ ] **S3 bucket encryption** for any application data
- [ ] **KMS customer-managed keys** for sensitive data
- [ ] **Backup strategy** with AWS Backup

### Compliance & Governance (Recommended)
- [ ] **Security tagging** for all resources (Finding #9)
- [ ] **Cost allocation tags** for chargeback
- [ ] **Service Control Policies** (SCPs) for account boundaries
- [ ] **Regular security assessments** (quarterly)
- [ ] **Penetration testing** approval and execution

---

## Risk Acceptance Statement

**For Development/Demo Environment ONLY**:

The following security limitations are **ACCEPTABLE** for this development environment:

1. ✅ **Self-signed TLS certificate** - Users will see browser warnings (acceptable for demo)
2. ✅ **Default VPC usage** - Architectural constraint per specification (FR-008)
3. ✅ **Public subnet EC2 instances** - With restrictive security groups (acceptable for dev)
4. ✅ **No VPC Flow Logs** - Not required for development environment
5. ✅ **No CloudTrail** - Account-level CloudTrail may already exist
6. ✅ **Cost optimization over security hardening** - Development cost target < $50/month

**NOT ACCEPTABLE for Production** without addressing all HIGH and MEDIUM findings.

**Risk Owner**: Development Team  
**Accepted Until**: Production deployment (requires security review re-run)  
**Compensating Controls**: 
- Restrictive security groups prevent direct internet access to instances
- HTTPS-only access enforces encryption in transit
- IAM instance profiles prevent credential exposure
- HCP Terraform encrypted state protects infrastructure secrets

---

## Recommendations Priority Matrix

| Priority | Timeframe | Findings | Estimated Effort |
|----------|-----------|----------|------------------|
| **P0 (Critical)** | Block deployment | None | N/A |
| **P1 (High)** | Before production | #1, #2, #3 | 10-15 hours total |
| **P2 (Medium)** | Current sprint | #4, #5, #6, #7, #8 | 5-7 hours total |
| **P3 (Low)** | Backlog | #9, #10 | 3-4 hours total |

**Total Remediation Effort**: 18-26 hours for full production readiness

---

## References

### AWS Documentation
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [Application Load Balancer Security](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html)
- [AWS Certificate Manager Best Practices](https://docs.aws.amazon.com/acm/latest/userguide/data-protection.html)
- [EC2 Security Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security.html)
- [Terraform State Security](https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-sensitive-data-secrets-manager-terraform/terraform-state-file.html)

### Compliance Frameworks
- [CIS AWS Foundations Benchmark v1.5.0](https://www.cisecurity.org/benchmark/amazon_web_services)
- [NIST 800-53 Rev 5](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [SOC 2 Trust Service Criteria](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/socforserviceorganizations)
- [OWASP Cloud Security](https://owasp.org/www-project-cloud-security/)

### AWS Services Referenced
- [AWS Certificate Manager (ACM)](https://docs.aws.amazon.com/acm/)
- [AWS CloudTrail](https://docs.aws.amazon.com/cloudtrail/)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Amazon GuardDuty](https://docs.aws.amazon.com/guardduty/)
- [AWS Config](https://docs.aws.amazon.com/config/)
- [AWS Security Hub](https://docs.aws.amazon.com/securityhub/)

---

**Review Complete**: 2025-02-01  
**Next Review**: After implementation, before production deployment  
**Contact**: AWS Security Advisor  

---

## Appendix: Security Testing Checklist

Use this checklist to validate security controls post-implementation:

### Network Security
- [ ] Verify ALB only accepts HTTPS (port 443)
- [ ] Confirm HTTP requests are rejected (not redirected)
- [ ] Test that EC2 instances cannot be accessed directly from internet
- [ ] Validate security group rules match design (no drift)
- [ ] Attempt SSH to instances (should fail)
- [ ] Test Session Manager access (if implemented)

### TLS/Certificate
- [ ] Verify TLS 1.3 is supported on ALB
- [ ] Confirm TLS 1.0/1.1 are disabled
- [ ] Test certificate in browser (expect self-signed warning for dev)
- [ ] Validate certificate chain and expiration date
- [ ] Run SSL Labs test on ALB endpoint

### IAM & Access
- [ ] Verify EC2 instances have IAM instance profile attached
- [ ] Confirm no hardcoded credentials in user data
- [ ] Test IMDSv2 enforcement (IMDSv1 should fail)
- [ ] Validate least privilege on IAM policies
- [ ] Check CloudTrail logs for deployment actions

### Logging & Monitoring
- [ ] Confirm VPC Flow Logs are being generated (if enabled)
- [ ] Verify CloudTrail is logging API calls (if enabled)
- [ ] Test CloudWatch alarms trigger correctly
- [ ] Check log retention policies are configured

### High Availability
- [ ] Terminate one EC2 instance, verify ALB continues serving traffic
- [ ] Confirm instances are in different AZs
- [ ] Validate ALB health checks mark instances healthy
- [ ] Test failover time (should be < 60 seconds)

### Compliance
- [ ] Scan with AWS Config rules (if enabled)
- [ ] Run AWS Security Hub checks
- [ ] Review findings from Amazon Inspector (if enabled)
- [ ] Validate tagging compliance
