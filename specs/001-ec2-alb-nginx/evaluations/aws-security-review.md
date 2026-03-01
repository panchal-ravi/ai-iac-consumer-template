# AWS Security Review: EC2 ALB Nginx Infrastructure

**Feature**: `001-ec2-alb-nginx`  
**Review Date**: 2025-01-13  
**Reviewer**: AWS Security Advisor  
**Environment**: Development  
**Region**: ap-southeast-1  

---

## Executive Summary

This security review evaluates the proposed AWS infrastructure for an EC2-based web application with Application Load Balancer and Nginx. The infrastructure is designed for **development environment** use with self-signed certificates and minimal cost optimization.

### Overall Risk Assessment

| Severity | Count | Status |
|----------|-------|--------|
| **Critical (P0)** | 0 | ✅ None Found |
| **High (P1)** | 4 | ⚠️ Action Required |
| **Medium (P2)** | 5 | ⚠️ Recommended |
| **Low (P3)** | 3 | ℹ️ Advisory |
| **Total Issues** | 12 | Review Required |

### Key Findings

✅ **Strengths**:
- Security groups follow least-privilege principle (ALB → EC2 via SG reference)
- IMDSv2 enforcement planned for EC2 instances
- TLS encryption in transit from internet to ALB
- Multi-AZ deployment for high availability
- No hardcoded credentials in specification

⚠️ **Critical Gaps**:
- Missing ALB access logs (security audit trail)
- No encryption at rest for EBS volumes
- Overly permissive ALB security group (0.0.0.0/0 on port 443)
- Missing CloudWatch monitoring and alerting
- Self-signed certificate production security implications

---

## High Priority Findings (P1)

### 1. Missing ALB Access Logs

**Risk Rating**: High  
**Justification**: Access logs are critical for security auditing, incident investigation, and compliance. Without logs, security incidents cannot be detected or investigated effectively.

**Finding**: Specification does not include configuration for ALB access logs to S3. This violates AWS Well-Architected Framework Security Pillar best practice for logging and monitoring.

**Location**: `spec.md` - No requirement for access logging  
**Location**: `plan.md` - No mention of log configuration

**Impact**:
- **Security**: Cannot detect or investigate security incidents, DDoS attacks, or suspicious traffic patterns
- **Compliance**: Violates many compliance frameworks (PCI-DSS, HIPAA, SOC2) that require audit trails
- **Forensics**: No evidence trail for post-incident analysis
- **Cost**: Minimal (~$0.02-0.05/month for dev environment logs)

**Recommendation**:
1. Create an S3 bucket with encryption (SSE-S3) for ALB access logs
2. Configure bucket policy to grant Elastic Load Balancing service write permissions
3. Enable access logging on ALB with 5-minute intervals
4. Implement S3 lifecycle policy to expire logs after 90 days (dev environment)
5. Consider CloudWatch Logs integration for real-time monitoring

**Code Example**:

```hcl
# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-alb-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # SSE-S3
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire_logs"
    status = "Enabled"

    expiration {
      days = 90  # Retain for 90 days (dev environment)
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

# Enable access logs on ALB
module "alb" {
  source = "app.terraform.io/ravi-panchal-org/alb/aws"
  
  # ... existing configuration ...
  
  access_logs = {
    enabled = true
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
  }
}
```

**Source**: [ALB Access Logs - AWS Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html)  
**Reference**: [SEC04-BP01: Configure service and application logging - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_app_service_logging.html)  
**CIS Benchmark**: 3.9 - Ensure VPC flow logging is enabled in all VPCs  
**Effort**: Low (30 minutes implementation)

---

### 2. Missing EBS Encryption at Rest

**Risk Rating**: High  
**Justification**: Unencrypted EBS volumes expose data at rest to unauthorized access. Even in development environments, infrastructure-as-code and configuration data may contain sensitive information.

**Finding**: Specification does not require EBS encryption for EC2 instance root volumes. Data model does not specify encryption configuration.

**Location**: `spec.md` - FR-001, FR-024 (no encryption requirement)  
**Location**: `data-model.md` - EC2 instance configuration missing encryption parameters

**Impact**:
- **Data Exposure**: Unencrypted snapshots could be shared accidentally
- **Compliance**: Violates encryption-at-rest requirements in most frameworks
- **Forensics**: Potential data leakage through EBS volume recovery
- **Cost**: Zero additional cost (AWS-managed keys)

**Recommendation**:
1. Enable EBS encryption by default at the account/region level
2. Explicitly configure encryption in EC2 module with AWS-managed KMS key
3. For production, use customer-managed KMS keys with key rotation
4. Validate encryption in CI/CD pipeline before deployment

**Code Example**:

```hcl
# Option 1: Enable EBS encryption by default (recommended)
resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}

# Option 2: Explicit encryption in EC2 module
module "ec2_instance" {
  source = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  
  # ... existing configuration ...
  
  root_block_device = [{
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true  # ✅ Encrypt with default AWS-managed key
    delete_on_termination = true
  }]
  
  # Enforce IMDSv2 (already planned)
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # ✅ IMDSv2
    http_put_response_hop_limit = 1
  }
}
```

**Source**: [Amazon EBS Encryption - AWS Documentation](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-encryption.html)  
**Reference**: [SEC08-BP02: Enforce encryption at rest - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_rest_encrypt.html)  
**CIS Benchmark**: 2.2.1 - Ensure EBS volume encryption is enabled  
**Effort**: Low (5 minutes configuration)

---

### 3. Overly Permissive ALB Security Group (0.0.0.0/0 on HTTPS)

**Risk Rating**: High  
**Justification**: While HTTPS from the internet is a common pattern, allowing unrestricted access (0.0.0.0/0) increases attack surface. For development environments, access should be restricted to known IP ranges.

**Finding**: Specification requires ALB security group to allow HTTPS (port 443) from 0.0.0.0/0 without considering IP allowlisting for dev environment.

**Location**: `spec.md` - FR-014: "System MUST create a security group for the ALB that allows inbound HTTPS traffic (port 443) from the internet"  
**Location**: `spec.md` - Acceptance Scenario 1 (Story 6): "allows inbound HTTPS traffic on port 443 from the internet (0.0.0.0/0)"

**Impact**:
- **Attack Surface**: Exposes ALB to global internet, increasing DDoS and vulnerability scanning exposure
- **Cost**: Potential unexpected charges from DDoS or traffic amplification attacks
- **Compliance**: May violate internal security policies for development environments
- **Mitigation**: Can be partially mitigated with AWS Shield Standard (free) and rate limiting

**Recommendation**:
1. **For Development**: Restrict HTTPS access to corporate IP ranges or VPN endpoints
2. **For Production**: Use AWS WAF with rate limiting, geo-blocking, and bot protection
3. Implement VPC Flow Logs to monitor rejected connections
4. Add CloudWatch metric filters for suspicious traffic patterns
5. Document accepted risk if 0.0.0.0/0 is required for business reasons

**Code Example**:

```hcl
# Development Environment (Recommended)
module "alb_security_group" {
  source = "app.terraform.io/ravi-panchal-org/security-group/aws"
  
  name        = "alb-sg"
  description = "ALB security group with restricted access"
  vpc_id      = data.aws_vpc.default.id
  
  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from corporate network"
      cidr_blocks = var.allowed_cidr_blocks  # ✅ Restrict to known IPs
      # Example: ["203.0.113.0/24", "198.51.100.0/24"]  # Corporate IP ranges
    }
  ]
  
  egress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP to backend instances"
      cidr_blocks = data.aws_vpc.default.cidr_block
    }
  ]
}

# Production Environment (with WAF)
resource "aws_wafv2_web_acl" "alb" {
  name  = "alb-waf"
  scope = "REGIONAL"
  
  default_action {
    allow {}
  }
  
  rule {
    name     = "rate-limit"
    priority = 1
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 2000  # Requests per 5 minutes
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-rule"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "alb-waf"
    sampled_requests_enabled   = true
  }
}
```

**Source**: [Security Groups for ALB - AWS Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html)  
**Reference**: [SEC05-BP01: Create network layers - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_create_layers.html)  
**CIS Benchmark**: 5.2 - Ensure no security groups allow ingress from 0.0.0.0/0 to port 22 or 3389 (adapted for HTTPS context)  
**AWS Control Tower**: CT.EC2.PR.3 - Require security group rules to not use source IP 0.0.0.0/0  
**Effort**: Low (15 minutes + stakeholder approval for IP ranges)

---

### 4. Missing CloudWatch Monitoring and Alerting

**Risk Rating**: High  
**Justification**: Without monitoring and alerting, security incidents, performance degradation, and availability issues cannot be detected in real-time. This violates the "detect" pillar of AWS Well-Architected Framework.

**Finding**: Specification explicitly excludes CloudWatch alarms and monitoring dashboards from scope.

**Location**: `spec.md` - Out of Scope: "CloudWatch alarms and monitoring dashboards"  
**Location**: `spec.md` - Out of Scope: "Production-grade monitoring and alerting"

**Impact**:
- **Availability**: Cannot detect instance or ALB failures until user reports
- **Security**: Cannot detect brute force attacks, anomalous traffic, or credential theft
- **Performance**: Cannot identify performance degradation trends
- **Cost**: Missed opportunity for cost optimization through rightsizing alerts
- **SLA**: Cannot measure or enforce availability targets (SC-003 mentions 100% availability but no monitoring)

**Recommendation**:
1. Implement basic CloudWatch alarms for critical metrics (even in dev)
2. Configure SNS topic for alert notifications
3. Monitor: ALB target health, HTTP 5xx errors, UnHealthyHostCount, RequestCount
4. Monitor: EC2 CPU, memory (CloudWatch agent), StatusCheckFailed
5. Set up CloudWatch Logs for application logs from Nginx

**Code Example**:

```hcl
# SNS topic for alerts
resource "aws_sns_topic" "alarms" {
  name = "alb-nginx-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ALB Unhealthy Host Count Alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0  # Alert if ANY host is unhealthy
  alarm_description   = "Alert when backend instances are unhealthy"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    LoadBalancer = module.alb.load_balancer_arn_suffix
    TargetGroup  = module.alb.target_group_arn_suffix
  }
}

# ALB 5xx Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10  # More than 10 errors in 5 minutes
  alarm_description   = "Alert on backend server errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    LoadBalancer = module.alb.load_balancer_arn_suffix
  }
}

# EC2 Instance Status Check Failed
resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  count = var.instance_count
  
  alarm_name          = "ec2-status-check-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 instance status check failed"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  
  dimensions = {
    InstanceId = module.ec2_instance[count.index].id
  }
}

# CloudWatch Log Group for Nginx Access Logs
resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/aws/ec2/nginx/access"
  retention_in_days = 7  # Dev environment
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/aws/ec2/nginx/error"
  retention_in_days = 30  # Keep errors longer
}
```

**Source**: [CloudWatch Alarms - AWS Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)  
**Reference**: [SEC04-BP02: Analyze logs centrally - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_analyze_logs.html)  
**CIS Benchmark**: 4.3 - Ensure a log metric filter and alarm exist for usage of root account  
**Effort**: Medium (1-2 hours for comprehensive monitoring)

---

## Medium Priority Findings (P2)

### 5. Self-Signed Certificate Security Implications

**Risk Rating**: Medium  
**Justification**: Self-signed certificates provide encryption but not authentication. Users are trained to ignore certificate warnings, creating phishing vulnerability. Acceptable for dev but must not reach production.

**Finding**: Specification uses self-signed TLS certificate without documented controls to prevent production deployment.

**Location**: `spec.md` - FR-006, FR-007, FR-023  
**Location**: `spec.md` - Notes: Certificate Management section acknowledges warnings

**Impact**:
- **Trust**: Users cannot verify server authenticity (man-in-the-middle vulnerability)
- **Training**: Teaches users to ignore browser security warnings
- **Compliance**: Violates most compliance frameworks for production systems
- **Mitigation**: Acceptable for development with proper controls

**Recommendation**:
1. Add environment tags to certificate and infrastructure to prevent production use
2. Set short validity period (90 days) to force regular review
3. Document clear path to CA-signed certificates for production
4. Implement policy-as-code check (OPA, Sentinel) to block self-signed certs in production
5. Consider AWS Certificate Manager Private CA for realistic dev/test environment

**Code Example**:

```hcl
# Self-signed certificate with safeguards
resource "tls_private_key" "web" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "web" {
  private_key_pem = tls_private_key.web.private_key_pem
  
  subject {
    common_name  = "web.demo.com"
    organization = "Development Environment - NOT FOR PRODUCTION"  # ✅ Clear warning
  }
  
  validity_period_hours = 2160  # 90 days - force regular review
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "web" {
  private_key      = tls_private_key.web.private_key_pem
  certificate_body = tls_self_signed_cert.web.cert_pem
  
  tags = {
    Environment     = "development"  # ✅ Prevent production use
    CertificateType = "self-signed"
    SecurityWarning = "NOT_FOR_PRODUCTION"
    ValidUntil      = timeadd(timestamp(), "2160h")
  }
  
  lifecycle {
    create_before_destroy = true
    
    # ✅ Policy enforcement: Fail if deployed to production
    precondition {
      condition     = var.environment != "production"
      error_message = "Self-signed certificates are NOT allowed in production environment"
    }
  }
}

# Alternative: ACM Private CA for realistic dev environment
# resource "aws_acmpca_certificate_authority" "dev" {
#   certificate_authority_configuration {
#     key_algorithm     = "RSA_4096"
#     signing_algorithm = "SHA512WITHRSA"
#     
#     subject {
#       common_name = "Dev Internal CA"
#     }
#   }
#   
#   type = "ROOT"
#   
#   tags = {
#     Environment = "development"
#   }
# }
```

**Source**: [Importing Certificates - AWS ACM Documentation](https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html)  
**Reference**: [SEC09-BP01: Implement secure key and certificate management - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_protect_data_transit_key_cert_mgmt.html)  
**OWASP**: A02:2021 - Cryptographic Failures  
**Effort**: Low (existing implementation, add safeguards 15 minutes)

---

### 6. Missing VPC Flow Logs

**Risk Rating**: Medium  
**Justification**: VPC Flow Logs provide network-level visibility for security analysis, troubleshooting, and compliance. Required for many security frameworks.

**Finding**: Specification does not include VPC Flow Logs configuration.

**Location**: `spec.md` - Out of scope: "Centralized logging"  
**Impact**:
- **Security**: Cannot detect port scanning, DDoS, or data exfiltration
- **Compliance**: Required by PCI-DSS, HIPAA, SOC2
- **Troubleshooting**: Cannot diagnose network connectivity issues
- **Cost**: ~$0.50/month for dev environment

**Recommendation**:

```hcl
resource "aws_flow_log" "vpc" {
  vpc_id          = data.aws_vpc.default.id
  traffic_type    = "ALL"  # ACCEPT, REJECT, or ALL
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 7  # Dev environment
}

resource "aws_iam_role" "flow_logs" {
  name = "vpc-flow-logs-role"
  
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
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
```

**Source**: [VPC Flow Logs - AWS Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)  
**Reference**: [SEC04-BP01: Configure service and application logging](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_detect_investigate_events_app_service_logging.html)  
**CIS Benchmark**: 3.9 - Ensure VPC flow logging is enabled in all VPCs  
**Effort**: Low (30 minutes)

---

### 7. Missing IAM Instance Profile for EC2

**Risk Rating**: Medium  
**Justification**: EC2 instances without IAM roles cannot securely access AWS services. Using access keys in user data or application code is a security anti-pattern.

**Finding**: Specification states "IAM role creation for EC2 instances (unless specifically required for functionality)" is out of scope. However, best practice is to always use instance profiles.

**Location**: `spec.md` - Out of Scope: "IAM role creation for EC2 instances"  
**Location**: `plan.md` - Security-First Automation mentions IMDSv2 but not IAM roles

**Impact**:
- **Security**: Cannot securely access CloudWatch Logs, S3, or other AWS services
- **Best Practice**: IAM roles should be default, not optional
- **Future**: Blocks integration with AWS services (CloudWatch agent, SSM, etc.)

**Recommendation**:

```hcl
# IAM role for EC2 instances
resource "aws_iam_role" "ec2_instance" {
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

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"  # For SSM Session Manager
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"  # For CloudWatch Logs
}

# Custom policy for least privilege
resource "aws_iam_role_policy" "nginx_logs" {
  name = "nginx-logs-policy"
  role = aws_iam_role.ec2_instance.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.nginx_access.arn}:*",
          "${aws_cloudwatch_log_group.nginx_error.arn}:*"
        ]
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "ec2" {
  name = "ec2-nginx-instance-profile"
  role = aws_iam_role.ec2_instance.name
}

# Attach to EC2 module
module "ec2_instance" {
  source = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  
  # ... existing configuration ...
  
  iam_instance_profile = aws_iam_instance_profile.ec2.name  # ✅ Attach IAM role
}
```

**Source**: [IAM Roles for EC2 - AWS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)  
**Reference**: [SEC02-BP02: Use temporary credentials - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_identities_use_temp_credentials.html)  
**CIS Benchmark**: 1.16 - Ensure IAM instance roles are used for AWS resource access from instances  
**Effort**: Low (30 minutes)

---

### 8. Unencrypted Communication Between ALB and EC2

**Risk Rating**: Medium  
**Justification**: ALB terminates TLS and forwards HTTP to backend instances. While traffic is within VPC, defense-in-depth recommends end-to-end encryption.

**Finding**: Specification requires HTTP (port 80) between ALB and EC2 instances without encryption.

**Location**: `spec.md` - FR-010: "configure ALB to perform TLS termination, then forward traffic to backend instances via HTTP on port 80"  
**Location**: `plan.md` - Trust Boundaries: "ALB → EC2: HTTP (within VPC, trusted network)"

**Impact**:
- **Defense-in-Depth**: Single layer of security (VPC isolation only)
- **Compliance**: Some frameworks require end-to-end encryption
- **Insider Threat**: Unencrypted traffic visible to anyone with VPC access
- **Mitigation**: Acceptable for dev if VPC is trusted; recommend HTTPS for production

**Recommendation**:
1. **Development**: Accept HTTP backend (current design)
2. **Production**: Configure Nginx for HTTPS on port 443 with internal certificate
3. Use ACM Private CA for internal certificates
4. Configure ALB target group to use HTTPS protocol

**Code Example**:

```hcl
# Production configuration (end-to-end encryption)
module "alb" {
  source = "app.terraform.io/ravi-panchal-org/alb/aws"
  
  # ... existing configuration ...
  
  target_groups = [
    {
      name             = "nginx-tg"
      backend_protocol = "HTTPS"  # ✅ HTTPS to backend
      backend_port     = 443
      target_type      = "instance"
      
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "443"
        protocol            = "HTTPS"  # ✅ HTTPS health check
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200"
      }
    }
  ]
}

# Update EC2 security group
module "ec2_security_group" {
  source = "app.terraform.io/ravi-panchal-org/security-group/aws"
  
  ingress_with_source_security_group_id = [
    {
      from_port                = 443  # ✅ HTTPS from ALB
      to_port                  = 443
      protocol                 = "tcp"
      description              = "HTTPS from ALB"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]
}
```

**Source**: [ALB Target Groups - AWS Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)  
**Reference**: [SEC09-BP02: Enforce encryption in transit - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_protect_data_transit_encrypt.html)  
**NIST**: SC-8 - Transmission Confidentiality and Integrity  
**Effort**: Medium (1 hour for certificate setup, Nginx reconfiguration)

---

### 9. No Resource Tagging Strategy for Security

**Risk Rating**: Medium  
**Justification**: Tags are critical for cost allocation, access control (ABAC), automated compliance, and incident response. Missing tags reduce operational maturity.

**Finding**: Specification mentions tagging for "cost tracking and management" (FR-022) but lacks comprehensive tagging strategy for security, compliance, and automation.

**Location**: `spec.md` - FR-022 mentions tags but no security tags  
**Location**: `spec.md` - Notes: Resource Tagging Strategy lists basic tags only

**Impact**:
- **Access Control**: Cannot implement attribute-based access control (ABAC)
- **Compliance**: Cannot automate compliance reporting by environment/data classification
- **Incident Response**: Cannot quickly identify all resources in scope during security incident
- **Cost**: Cannot accurately attribute costs to teams or projects

**Recommendation**:

```hcl
# Standard tags for all resources
locals {
  common_tags = {
    # Identity & Ownership
    Project     = "ec2-alb-nginx"
    Environment = var.environment  # dev, staging, prod
    ManagedBy   = "terraform"
    Owner       = var.owner_email
    
    # Security & Compliance
    DataClassification = "internal"  # public, internal, confidential, restricted
    ComplianceScope    = "none"      # pci-dss, hipaa, sox, none
    BackupRequired     = "false"     # true/false
    
    # Automation
    AutoShutdown       = var.environment == "dev" ? "true" : "false"
    PatchGroup         = "nginx-web-servers"
    
    # Cost Management
    CostCenter         = var.cost_center
    Application        = "nginx-web"
    
    # Operational
    SLA                = "dev"  # dev, standard, high, critical
    SupportTeam        = "platform-engineering"
    
    # Terraform Metadata
    TerraformWorkspace = terraform.workspace
    TerraformRepo      = "speckit"
  }
}

# Apply to all resources
module "ec2_instance" {
  source = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  
  # ... configuration ...
  
  tags = merge(
    local.common_tags,
    {
      Name = "nginx-web-${count.index + 1}"
      Role = "web-server"
    }
  )
}

# Enforce required tags with policy
resource "aws_organizations_policy" "required_tags" {
  name        = "required-tags-policy"
  description = "Enforce required tags on all resources"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateVolume",
          "elasticloadbalancing:CreateLoadBalancer"
        ]
        Resource = "*"
        Condition = {
          "StringNotEquals" = {
            "aws:RequestTag/Environment"        = ["dev", "staging", "prod"]
            "aws:RequestTag/ManagedBy"          = "terraform"
            "aws:RequestTag/DataClassification" = ["public", "internal", "confidential", "restricted"]
          }
        }
      }
    ]
  })
}
```

**Source**: [Tagging AWS Resources - AWS Documentation](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)  
**Reference**: [COST02-BP01: Adopt a consumption model with tagging](https://docs.aws.amazon.com/wellarchitected/latest/framework/cost_govern_usage_cost_tagging.html)  
**CIS Benchmark**: Custom organizational requirement  
**Effort**: Low (15 minutes to define, enforce across resources)

---

## Low Priority Findings (P3)

### 10. Default VPC Security Posture

**Risk Rating**: Low  
**Justification**: Default VPC is acceptable for development but lacks customization for security controls like dedicated CIDR, custom NACLs, and VPC endpoints.

**Finding**: Specification requires use of default VPC which has known limitations.

**Location**: `spec.md` - Constraints: "MUST use existing default VPC and subnets"  
**Location**: `spec.md` - FR-003: "System MUST use the existing default VPC and its default subnets"

**Impact**:
- **Network Isolation**: Cannot implement custom IP addressing or network segmentation
- **NACLs**: Default network ACLs are permissive
- **VPC Endpoints**: Cannot use private endpoints for AWS services (egress via IGW)
- **Mitigation**: Acceptable for dev; requires custom VPC for production

**Recommendation**:
1. Accept default VPC for development (as specified)
2. Document migration path to custom VPC for production
3. Implement security group controls as primary defense layer (already planned)
4. Consider VPC endpoint for S3 (ALB logs) to avoid internet egress

**Code Example**:

```hcl
# VPC endpoint for S3 (optional enhancement)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.ap-southeast-1.s3"
  
  route_table_ids = data.aws_route_tables.default.ids
  
  tags = merge(
    local.common_tags,
    {
      Name = "s3-vpc-endpoint"
    }
  )
}

# VPC endpoint policy (restrict to ALB logs bucket only)
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]
    
    resources = [
      "${aws_s3_bucket.alb_logs.arn}/*"
    ]
  }
}
```

**Source**: [Default VPC - AWS Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html)  
**Reference**: [SEC05-BP02: Control traffic at all layers - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_network_protection_layered.html)  
**Effort**: Low (document migration path, optional VPC endpoint 30 minutes)

---

### 11. Missing AWS Systems Manager (SSM) Session Manager

**Risk Rating**: Low  
**Justification**: Specification notes "SSH access to EC2 instances is not required" but provides no alternative for secure access. SSM Session Manager is the modern secure alternative.

**Finding**: No secure shell access mechanism defined. SSH keys not mentioned, SSM not configured.

**Location**: `spec.md` - Assumptions: "SSH access to EC2 instances is not required for this feature (can be added separately if needed)"  
**Location**: `spec.md` - Out of Scope: "SSH bastion host or remote access configuration"

**Impact**:
- **Troubleshooting**: Cannot access instances for debugging without modifying security groups
- **Security**: If SSH is added later, it's often done insecurely (0.0.0.0/0, weak keys)
- **Audit**: SSH access is not logged; SSM Session Manager provides audit trail
- **Cost**: SSM Session Manager is free

**Recommendation**:

```hcl
# IAM role for EC2 with SSM (already recommended in Finding #7)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# SSM VPC endpoints (optional, for private subnet access)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.ap-southeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.ap-southeast-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.ap-southeast-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}
```

**Access via CLI**:
```bash
# Connect to instance without SSH or public IP
aws ssm start-session --target i-1234567890abcdef0

# Port forwarding for local debugging
aws ssm start-session --target i-1234567890abcdef0 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["80"],"localPortNumber":["8080"]}'
```

**Source**: [AWS Systems Manager Session Manager - AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)  
**Reference**: [SEC03-BP03: Establish access controls](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_lifecycle.html)  
**CIS Benchmark**: 1.17 - Ensure a support role has been created to manage incidents with AWS Support  
**Effort**: Low (30 minutes, requires IAM role from Finding #7)

---

### 12. No Automated Security Scanning

**Risk Rating**: Low  
**Justification**: For a production-ready infrastructure, automated security scanning should be integrated into CI/CD pipeline. While out of scope for this dev environment, it's a recommended practice.

**Finding**: Specification explicitly excludes security scanning from scope.

**Location**: `spec.md` - Out of Scope: "Security scanning or vulnerability assessments"

**Impact**:
- **Vulnerabilities**: Cannot detect known vulnerabilities in AMI or packages
- **Compliance**: Many frameworks require regular vulnerability scanning
- **Drift**: Cannot detect infrastructure drift or misconfigurations
- **Cost**: AWS Inspector is pay-per-scan (~$0.30/instance/month)

**Recommendation**:

```hcl
# AWS Inspector for vulnerability scanning
resource "aws_inspector2_enabler" "account" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["EC2", "ECR"]  # Scan EC2 instances
}

# Alternative: Open-source tools in CI/CD
# - Checkov: Terraform static analysis
# - tfsec: Terraform security scanner
# - Trivy: Container/OS vulnerability scanner
# - Prowler: AWS security best practices scanner
```

**CI/CD Pipeline Example**:
```yaml
# .github/workflows/security-scan.yml
name: Security Scan
on: [pull_request]

jobs:
  terraform-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
          
      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          soft_fail: false
          
      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: '.'
```

**Source**: [Amazon Inspector - AWS Documentation](https://docs.aws.amazon.com/inspector/latest/user/what-is-inspector.html)  
**Reference**: [SEC10-BP05: Run automated security tests](https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_application_security_testing.html)  
**OWASP**: ASVS V14 - Configuration Verification Requirements  
**Effort**: Medium (1-2 hours to integrate into CI/CD)

---

## Compliance Assessment

### CIS AWS Foundations Benchmark v2.0

| Control | Requirement | Status | Notes |
|---------|-------------|--------|-------|
| 2.1.1 | Ensure EBS encryption enabled | ❌ FAIL | See Finding #2 |
| 2.2.1 | Ensure EBS volume encryption enabled | ❌ FAIL | See Finding #2 |
| 3.9 | Ensure VPC flow logging enabled | ❌ FAIL | See Finding #6 |
| 4.3 | Ensure log metric filter for root account | ⚠️ PARTIAL | No CloudWatch alarms |
| 5.1 | Ensure no Network ACLs allow ingress 0.0.0.0/0 to port 22 | ✅ PASS | Default VPC NACLs |
| 5.2 | Ensure security groups restrict 0.0.0.0/0 | ⚠️ PARTIAL | ALB allows 443 from 0.0.0.0/0 (Finding #3) |
| 5.3 | Ensure default security group restricts all traffic | ✅ PASS | Using custom SGs |

**Overall CIS Compliance**: 43% (3/7 controls passing)

---

### AWS Well-Architected Framework - Security Pillar

| Best Practice | Status | Findings |
|---------------|--------|----------|
| **SEC01: Operate workloads securely** | ⚠️ PARTIAL | Missing automated security scanning (#12) |
| **SEC02: Manage identities** | ⚠️ PARTIAL | No IAM instance profile (#7) |
| **SEC03: Manage permissions** | ⚠️ PARTIAL | Security groups good, missing ABAC tags (#9) |
| **SEC04: Detect security events** | ❌ FAIL | No logging (#1, #6), no monitoring (#4) |
| **SEC05: Protect network resources** | ⚠️ PARTIAL | Security groups good, overly permissive ALB (#3) |
| **SEC06: Protect compute resources** | ⚠️ PARTIAL | IMDSv2 planned, missing EBS encryption (#2) |
| **SEC08: Protect data at rest** | ❌ FAIL | No EBS encryption (#2) |
| **SEC09: Protect data in transit** | ⚠️ PARTIAL | HTTPS to ALB, HTTP to backend (#8) |

**Overall Well-Architected Score**: 38% (0/8 pillars fully implemented)

---

## Prioritized Remediation Roadmap

### Phase 1: Critical Security Controls (Week 1)

**Priority**: Fix all High (P1) findings before deployment

1. **Enable EBS Encryption** (Finding #2) - 5 minutes
   - Set `aws_ebs_encryption_by_default.enabled = true`
   - Update EC2 module with `encrypted = true`
   
2. **Configure ALB Access Logs** (Finding #1) - 30 minutes
   - Create S3 bucket with SSE-S3 encryption
   - Enable access logs on ALB
   
3. **Implement Basic CloudWatch Alarms** (Finding #4) - 1 hour
   - UnHealthyHostCount, 5xx errors, instance status checks
   - SNS topic for email notifications
   
4. **Restrict ALB Security Group** (Finding #3) - 15 minutes + approval
   - Obtain corporate IP ranges
   - Update security group ingress rules
   - Document accepted risk if 0.0.0.0/0 required

**Estimated Effort**: 2 hours + stakeholder approvals

---

### Phase 2: Defense in Depth (Week 2-3)

**Priority**: Medium (P2) findings for production readiness

5. **Enable VPC Flow Logs** (Finding #6) - 30 minutes
6. **Create IAM Instance Profile** (Finding #7) - 30 minutes
7. **Add Comprehensive Resource Tags** (Finding #9) - 15 minutes
8. **Document Self-Signed Certificate Controls** (Finding #5) - 30 minutes

**Estimated Effort**: 2 hours

---

### Phase 3: Operational Excellence (Future)

**Priority**: Low (P3) findings and enhancements

9. **Enable SSM Session Manager** (Finding #11) - 30 minutes
10. **Integrate Security Scanning** (Finding #12) - 2 hours
11. **Evaluate Custom VPC Migration** (Finding #10) - Planning only
12. **Plan End-to-End Encryption** (Finding #8) - Production requirement

**Estimated Effort**: 3 hours

---

## Risk Acceptance

The following findings may be accepted as-is for **development environment** with documented justification:

### Accepted Risks for Development

| Finding | Justification | Mitigation | Review Date |
|---------|---------------|------------|-------------|
| #3: 0.0.0.0/0 on ALB | Development requires public access for testing | AWS Shield Standard (free) provides basic DDoS protection | 2025-Q2 |
| #5: Self-Signed Certificate | Development only, no production data | Environment tags prevent production deployment | 2025-Q2 |
| #8: HTTP Backend | Within VPC, trusted network | Review for production migration | Production |
| #10: Default VPC | Specified requirement, development scope | Custom VPC required for production | Production |

**Production Deployment**: ALL High (P1) and Medium (P2) findings MUST be resolved before production deployment.

---

## Action Items

### Immediate (This Sprint)

- [ ] Enable EBS encryption by default in ap-southeast-1 region
- [ ] Configure ALB access logs to encrypted S3 bucket
- [ ] Implement CloudWatch alarms for ALB and EC2 health
- [ ] Obtain corporate IP ranges for ALB security group restriction
- [ ] Add IAM instance profile to EC2 configuration

### Short-Term (Next Sprint)

- [ ] Enable VPC Flow Logs with 7-day retention
- [ ] Implement comprehensive tagging strategy
- [ ] Document self-signed certificate usage and controls
- [ ] Set up SSM Session Manager for secure access

### Long-Term (Production Readiness)

- [ ] Replace self-signed certificate with ACM-issued certificate
- [ ] Implement end-to-end encryption (ALB → EC2 HTTPS)
- [ ] Migrate to custom VPC with private subnets and NAT gateway
- [ ] Integrate automated security scanning in CI/CD pipeline
- [ ] Implement AWS WAF with managed rule sets
- [ ] Enable AWS Config for compliance monitoring

---

## References

### AWS Documentation

1. [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
2. [Amazon EBS Encryption](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-encryption.html)
3. [ALB Access Logs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html)
4. [IMDSv2 Migration Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-metadata-transition-to-version-2.html)
5. [VPC Security Groups Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
6. [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

### Compliance Frameworks

1. [CIS AWS Foundations Benchmark v2.0](https://www.cisecurity.org/benchmark/amazon_web_services)
2. [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
3. [OWASP Top 10:2021](https://owasp.org/Top10/)
4. [PCI-DSS v4.0](https://www.pcisecuritystandards.org/)

### Tools

1. [Checkov - Terraform Security Scanner](https://www.checkov.io/)
2. [tfsec - Terraform Static Analysis](https://github.com/aquasecurity/tfsec)
3. [Trivy - Vulnerability Scanner](https://github.com/aquasecurity/trivy)
4. [Prowler - AWS Security Best Practices](https://github.com/prowler-cloud/prowler)

---

## Sign-Off

**Security Review Status**: ⚠️ **CONDITIONAL APPROVAL**

**Conditions for Deployment**:
1. ✅ All Critical (P0) findings resolved: NONE FOUND
2. ⚠️ All High (P1) findings resolved OR risk accepted: **4 FINDINGS REQUIRE ACTION**
3. ℹ️ Medium (P2) findings documented for future sprints: 5 FINDINGS
4. ℹ️ Low (P3) findings documented for backlog: 3 FINDINGS

**Recommendation**: **HOLD DEPLOYMENT** until High (P1) findings #1, #2, #4 are resolved. Finding #3 (0.0.0.0/0 ALB) may be accepted for development with documented risk.

**Next Review**: After implementation of High (P1) findings

---

**Reviewed By**: AWS Security Advisor  
**Date**: 2025-01-13  
**Feature**: `001-ec2-alb-nginx`  
**Environment**: Development (ap-southeast-1)
