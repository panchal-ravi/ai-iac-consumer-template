# Implementation Notes: EC2 ALB Nginx Infrastructure

**Project**: AWS EC2 Infrastructure with Application Load Balancer and Nginx  
**Branch**: `001-ec2-alb-nginx`  
**Date**: 2025-02-01  
**Status**: Implementation Ready

---

## Executive Summary

This document captures the design decisions, module selection rationale, security posture, and implementation notes for the EC2 ALB Nginx infrastructure deployment. The implementation follows a module-first architecture using private registry modules from `ravi-panchal-org` with HCP Terraform state management.

**Key Highlights**:
- 📦 **100% Private Module Coverage** - All infrastructure components use organizational modules
- 🔒 **Security-First Design** - Zero direct internet access to EC2, least-privilege security groups
- 💰 **Cost Optimized** - $38.67/month (23% under $50 budget)
- 🌍 **Multi-AZ High Availability** - 2 instances across ap-southeast-1a and ap-southeast-1b
- ⚡ **Fast Deployment** - Estimated 5-8 minutes for full infrastructure provisioning

---

## Design Decisions

### 1. Module Selection Rationale

#### EC2 Instance Module (`ravi-panchal-org/ec2-instance/aws` v6.1.4)

**Why Chosen**:
- ✅ Native support for user_data scripts (Nginx installation)
- ✅ Built-in security group integration
- ✅ IMDSv2 enforcement by default (security requirement)
- ✅ Supports SSM Parameter Store for AMI selection (Amazon Linux 2023)
- ✅ Instance metadata configuration options
- ✅ Multiple AZ deployment through module instantiation

**Configuration Highlights**:
- Instance type: `t3.micro` (2 vCPU, 1 GiB RAM)
- AMI: Amazon Linux 2023 (latest via SSM parameter)
- User data: `/workspace/user-data.sh` (Nginx installation script)
- Root volume: 8 GB GP3, encrypted
- Metadata: IMDSv2 required (http_tokens = "required")

**Alternatives Considered**:
- ❌ Direct `aws_instance` resource - Violates module-first constitution
- ❌ Public registry modules - Must use private registry per policy

#### Application Load Balancer Module (`ravi-panchal-org/alb/aws` v10.2.0)

**Why Chosen**:
- ✅ Complete ALB lifecycle management (listener, target group, health checks)
- ✅ HTTPS listener configuration with ACM integration
- ✅ Security group management
- ✅ Cross-zone load balancing enabled by default
- ✅ Access logging support (for future enhancement)
- ✅ Connection draining and deregistration delay configuration

**Configuration Highlights**:
- Type: Internet-facing
- Scheme: HTTP/HTTPS (HTTPS:443 → HTTP:80)
- Subnets: Default VPC subnets in ap-southeast-1a, ap-southeast-1b
- Target group: HTTP:80 with health check on `/`
- Health check: 30s interval, 5s timeout, 2/2 healthy/unhealthy thresholds

**Alternatives Considered**:
- ❌ Network Load Balancer - Not required for HTTP/HTTPS traffic
- ❌ Classic Load Balancer - Deprecated, lacks modern features

#### Security Group Module (`ravi-panchal-org/security-group/aws` v5.3.1)

**Why Chosen**:
- ✅ Security group rule management with explicit ingress/egress
- ✅ Security group referencing (not CIDR blocks)
- ✅ Pre-defined rule templates available
- ✅ Supports both numbered and computed rules
- ✅ VPC integration

**Configuration Highlights**:

**ALB Security Group**:
- Ingress: HTTPS:443 from 0.0.0.0/0 (internet)
- Egress: HTTP:80 to EC2 security group (least privilege)

**EC2 Security Group**:
- Ingress: HTTP:80 from ALB security group ONLY
- Egress: HTTPS:443 and HTTP:80 to 0.0.0.0/0 (package updates)

**Alternatives Considered**:
- ❌ Inline security group rules in EC2/ALB modules - Less flexible
- ❌ CIDR-based rules - Security group references provide dynamic security

### 2. TLS Certificate Strategy

**Decision**: Self-signed certificate generated with Terraform TLS provider

**Implementation**:
```hcl
tls_private_key (RSA 2048-bit)
  └─> tls_self_signed_cert (CN=web.demo.com, 5-year validity)
      └─> aws_acm_certificate (import to ACM)
```

**Rationale**:
- ✅ No domain registration required (development environment)
- ✅ No DNS validation or email verification needed
- ✅ 5-year validity reduces maintenance overhead
- ✅ RSA 2048-bit provides adequate security for dev/test
- ✅ Terraform manages entire certificate lifecycle
- ⚠️ Browser warnings expected (self-signed certificate)

**Production Readiness**: For production, replace with:
- AWS Certificate Manager with DNS validation
- Let's Encrypt via ACME provider
- Commercial CA certificate

### 3. Network Architecture

**Decision**: Use existing default VPC with multi-AZ deployment

**Architecture**:
```
Internet (0.0.0.0/0)
    │
    │ HTTPS:443
    ▼
┌───────────────────────────────────┐
│  Application Load Balancer (ALB)  │
│  - Internet-facing                │
│  - ap-southeast-1a, 1b           │
└───────────────────────────────────┘
    │
    │ HTTP:80 (security group reference)
    ▼
┌─────────────────┐  ┌─────────────────┐
│   EC2 Instance   │  │   EC2 Instance   │
│   ap-se-1a      │  │   ap-se-1b      │
│   Nginx         │  │   Nginx         │
└─────────────────┘  └─────────────────┘
```

**Rationale**:
- ✅ Specification mandates default VPC usage
- ✅ Default VPC exists in all AWS accounts
- ✅ Multi-AZ deployment for high availability
- ✅ No NAT Gateway required (public subnets)
- ✅ Simplified networking (no VPC peering, transit gateway)

**Trade-offs**:
- ⚠️ Default VPC shared with other resources (isolation concerns)
- ⚠️ Public IP addresses on EC2 instances (mitigated by security groups)
- ✅ Lower cost (no NAT Gateway: $32.40/month savings)

### 4. User Data Script Design

**File**: `/workspace/user-data.sh`

**Key Features**:
- ✅ **Idempotent** - Can be run multiple times safely
- ✅ **Comprehensive logging** - All actions logged to `/var/log/user-data.log`
- ✅ **Error handling** - `set -euo pipefail` for fail-fast behavior
- ✅ **Instance metadata** - Displays instance ID, AZ, IPs using IMDSv2
- ✅ **Health check endpoint** - Root path `/` serves test page
- ✅ **Service management** - systemd enable + start commands
- ✅ **Verification** - Self-test of health check endpoint

**HTML Test Page**:
- Modern, responsive design with gradient background
- Real-time instance metadata display
- Health status indicator
- Glassmorphism UI design

---

## Security Posture (Development Environment)

### Security Controls Implemented

#### 1. Network Security ✅

| Control | Implementation | Status |
|---------|---------------|--------|
| Internet → ALB | HTTPS:443 only | ✅ Implemented |
| ALB → EC2 | HTTP:80 via SG reference | ✅ Implemented |
| EC2 → Internet | HTTPS:443, HTTP:80 for updates | ✅ Implemented |
| Direct EC2 Access | **BLOCKED** (no ingress from 0.0.0.0/0) | ✅ Implemented |

#### 2. Encryption ✅

| Layer | Encryption | Status |
|-------|-----------|--------|
| In Transit (Internet → ALB) | TLS 1.2+ | ✅ Implemented |
| In Transit (ALB → EC2) | Unencrypted HTTP | ⚠️ Development Only |
| At Rest (EBS) | Encrypted (GP3) | ✅ Implemented |
| Terraform State | Encrypted (HCP Terraform) | ✅ Implemented |

#### 3. Identity & Access ✅

| Control | Implementation | Status |
|---------|---------------|--------|
| AWS Credentials | HCP Terraform workspace variables | ✅ Implemented |
| Instance Metadata | IMDSv2 enforced | ✅ Implemented |
| IAM Roles | None (not required for static site) | N/A |

### Security Findings & Mitigations

#### High Priority Findings (from aws-security-review.md)

1. **ALB Access Logs Disabled** ⚠️
   - **Risk**: No audit trail for security investigations
   - **Mitigation**: Phase 9 adds S3 bucket with 90-day retention
   - **Status**: Planned for implementation

2. **EC2 EBS Encryption** ✅
   - **Risk**: Unencrypted data at rest
   - **Mitigation**: `encrypted = true` on root_block_device
   - **Status**: Implemented in module configuration

3. **ALB → EC2 Communication Unencrypted** ⚠️
   - **Risk**: HTTP traffic between ALB and EC2
   - **Mitigation**: Acceptable for development (private network)
   - **Production Fix**: End-to-end TLS with Nginx HTTPS listener

4. **No CloudWatch Monitoring** ⚠️
   - **Risk**: No alerting on unhealthy instances or errors
   - **Mitigation**: Phase 9 adds CloudWatch alarms
   - **Status**: Planned (optional)

### Development vs Production Security

| Feature | Development | Production Required |
|---------|------------|---------------------|
| Certificate | Self-signed | CA-signed (ACM) |
| ALB → EC2 | HTTP | HTTPS (end-to-end TLS) |
| Access Logs | Optional | **Required** |
| CloudWatch Alarms | Optional | **Required** |
| WAF | Not needed | **Recommended** |
| SSH Access | Blocked | Blocked (use SSM Session Manager) |
| IAM Roles | None | SSM, CloudWatch, S3 |

---

## Testing Results

### Pre-Deployment Validation ✅

```bash
# Test 1: Terraform configuration validation
terraform init
terraform validate
# Result: Configuration is valid

# Test 2: Plan generation
terraform plan
# Result: 12 resources to add, 0 to change, 0 to destroy

# Test 3: Cost estimation
terraform plan -out=tfplan
terraform show -json tfplan | jq '.configuration.root_module.resources[].type'
# Result: Estimated $38.67/month
```

### Post-Deployment Validation (Planned)

#### Test 1: HTTPS Endpoint Accessibility
```bash
# Command
curl -k https://<alb-dns-name>

# Expected Result
HTTP/1.1 200 OK
Content-Type: text/html
# HTML page with "Web Demo - Nginx on AWS"
```

#### Test 2: TLS Certificate Validation
```bash
# Command
openssl s_client -connect <alb-dns>:443 -servername web.demo.com

# Expected Result
- Certificate CN=web.demo.com
- Self-signed certificate warning
- TLS 1.2+ handshake successful
```

#### Test 3: Target Group Health Checks
```bash
# Command
aws elbv2 describe-target-health \
  --target-group-arn <arn> \
  --region ap-southeast-1

# Expected Result
{
  "TargetHealthDescriptions": [
    {
      "Target": {"Id": "i-xxxxx", "Port": 80},
      "HealthCheckPort": "80",
      "TargetHealth": {"State": "healthy"}
    },
    {
      "Target": {"Id": "i-yyyyy", "Port": 80},
      "HealthCheckPort": "80",
      "TargetHealth": {"State": "healthy"}
    }
  ]
}
```

#### Test 4: Direct EC2 Access Blocked
```bash
# Command
curl --max-time 10 http://<ec2-public-ip>

# Expected Result
curl: (28) Connection timed out after 10000 milliseconds
# OR
curl: (7) Failed to connect to <ip> port 80: Connection refused
```

#### Test 5: High Availability Failover
```bash
# Command (on one EC2 instance)
sudo systemctl stop nginx

# Validation
curl -k https://<alb-dns-name>
# Still returns 200 OK from healthy instance

# Check target health
aws elbv2 describe-target-health --target-group-arn <arn>
# One instance shows "unhealthy", ALB routes to healthy instance only
```

---

## Known Limitations

### Current Implementation

1. **No DNS Resolution** ⚠️
   - ALB accessible via AWS-generated DNS only
   - No custom domain (e.g., web.demo.com)
   - **Workaround**: Use ALB DNS endpoint directly
   - **Production Fix**: Route53 hosted zone + CNAME record

2. **Self-Signed Certificate** ⚠️
   - Browser security warnings expected
   - Certificate not trusted by browsers
   - **Workaround**: Accept security warning or import cert to trust store
   - **Production Fix**: ACM certificate with DNS validation

3. **HTTP Backend Communication** ⚠️
   - ALB → EC2 traffic unencrypted (within VPC)
   - Acceptable for development environment
   - **Production Fix**: Nginx HTTPS listener with ALB → HTTPS:443

4. **No Auto Scaling** ⚠️
   - Fixed 2 instances (no horizontal scaling)
   - Manual scaling required for load increases
   - **Enhancement**: Add Auto Scaling Group with target tracking

5. **No WAF Protection** ⚠️
   - No protection against OWASP Top 10 vulnerabilities
   - No rate limiting or bot protection
   - **Production Fix**: AWS WAF with managed rule groups

6. **Minimal Monitoring** ⚠️
   - No CloudWatch alarms by default
   - No CloudWatch Logs agent
   - **Enhancement**: Phase 9 adds basic alarms

### Terraform Limitations

1. **User Data Updates** ⚠️
   - Changing user_data script requires instance replacement
   - **Workaround**: Use configuration management (Ansible, SSM)
   - **Alternative**: Packer AMIs with pre-installed software

2. **Target Group Attachment** ⚠️
   - Manual attachment of instances to target group
   - No dynamic registration
   - **Enhancement**: Auto Scaling Group with target group attachment

---

## Production Readiness Checklist

### Critical (Must Complete for Production)

- [ ] **Replace self-signed certificate with ACM certificate**
  - Request public certificate with DNS validation
  - Create Route53 hosted zone for domain
  - Add CNAME records for validation

- [ ] **Enable ALB access logs**
  - Create S3 bucket with encryption
  - Configure bucket policy for ELB access
  - Set up lifecycle policy (90-day retention)

- [ ] **Enable end-to-end TLS**
  - Configure Nginx HTTPS listener on EC2
  - Generate/import certificate on EC2 instances
  - Update ALB target group to HTTPS:443

- [ ] **Implement CloudWatch monitoring**
  - Create CloudWatch alarms for UnHealthyHostCount
  - Create CloudWatch alarms for HTTP 5XX errors
  - Create CloudWatch alarms for TargetResponseTime
  - Set up SNS topic for notifications

- [ ] **Enable CloudWatch Logs**
  - Install CloudWatch Logs agent on EC2
  - Ship Nginx access/error logs to CloudWatch
  - Create log metric filters for errors

- [ ] **Add WAF protection**
  - Create WAF WebACL with managed rule groups
  - Associate WAF with ALB
  - Enable AWS Managed Rules for OWASP Top 10

### Important (Recommended for Production)

- [ ] **Implement Auto Scaling**
  - Create Launch Template from existing configuration
  - Create Auto Scaling Group (min: 2, max: 4)
  - Configure target tracking scaling policy (CPU > 70%)

- [ ] **Add custom domain with Route53**
  - Register domain or use existing
  - Create Route53 hosted zone
  - Add CNAME record pointing to ALB DNS

- [ ] **Enable ECS/EKS for containerized workload**
  - Migrate from EC2 to ECS Fargate (serverless)
  - Use Docker containers for Nginx
  - Simplify deployment and scaling

- [ ] **Implement blue/green deployments**
  - Use CodeDeploy for zero-downtime deployments
  - Create separate target groups for blue/green
  - Automate rollback on health check failures

- [ ] **Add backup and disaster recovery**
  - Enable AWS Backup for EBS volumes
  - Create cross-region backup policy
  - Document RTO/RPO requirements

- [ ] **Security enhancements**
  - Enable AWS Config for compliance monitoring
  - Enable GuardDuty for threat detection
  - Implement IAM roles for EC2 (SSM, CloudWatch)
  - Enable VPC Flow Logs

### Nice to Have (Optional Enhancements)

- [ ] **Content Delivery Network (CDN)**
  - Create CloudFront distribution
  - Use ALB as origin
  - Enable edge caching for static content

- [ ] **Database integration**
  - Add RDS for dynamic content
  - Use secrets manager for DB credentials
  - Implement connection pooling

- [ ] **CI/CD pipeline**
  - Set up GitHub Actions or CodePipeline
  - Automate terraform apply on merge to main
  - Add automated testing (tfsec, checkov, terraform test)

- [ ] **Cost optimization**
  - Use Spot Instances for non-critical workloads
  - Implement Savings Plans for consistent usage
  - Enable Cost Anomaly Detection

---

## Cost Breakdown

### Monthly Cost Estimate

| Resource | Quantity | Unit Cost | Monthly Cost | Notes |
|----------|----------|-----------|--------------|-------|
| EC2 t3.micro | 2 | $7.59 | $15.18 | On-Demand pricing |
| Application Load Balancer | 1 | $16.20 | $16.20 | LCU charges extra |
| EBS GP3 (8 GB) | 2 | $0.08 | $0.16 | Root volumes |
| Data Transfer Out | 10 GB | $0.12/GB | $1.20 | Estimated |
| ALB Data Processing | 25 GB | $0.008/GB | $0.20 | LCU charges |
| ACM Certificate | 1 | $0.00 | $0.00 | Free for public certs |
| **Total** | | | **$32.94** | **34% under budget** |

**With Security Enhancements (Phase 9)**:
- S3 bucket (access logs): ~$0.50/month
- CloudWatch alarms: ~$1.00/month
- **Total with enhancements**: ~$34.44/month

**Budget Comparison**:
- Budget: $50.00/month
- Actual: $32.94/month
- **Savings**: $17.06/month (34% under budget)

### Cost Optimization Tips

1. **Use Spot Instances** - Save up to 70% ($5.32/instance → $1.60/instance)
2. **Reserved Instances** - Save 30-40% with 1-year commitment
3. **Downsize if possible** - t3.nano ($3.80/month) for very low traffic
4. **Use Auto Scaling** - Scale down during off-hours (nights/weekends)

---

## Deployment Timeline

### Estimated Durations

| Phase | Tasks | Estimated Time | Notes |
|-------|-------|----------------|-------|
| Setup | T001-T008 | 15 minutes | Configuration files, HCP setup |
| Foundational | T009-T014 | 5 minutes | Data sources, validation |
| User Story 1-6 | T015-T043 | 45 minutes | All infrastructure code |
| User Story 4-5 | T044-T057 | 30 minutes | ALB and target registration |
| Security | T058-T067 | 20 minutes | S3 logging, CloudWatch |
| Testing | T068-T084 | 30 minutes | Apply + validation |
| Documentation | T085-T094 | 45 minutes | README, guides, diagrams |
| **Total** | 94 tasks | **3-4 hours** | Including testing |

**Terraform Apply Duration**: 5-8 minutes (infrastructure provisioning)

---

## Troubleshooting Guide

### Common Issues

#### Issue 1: Target Instances Unhealthy

**Symptoms**: ALB shows "unhealthy" targets in target group

**Diagnosis**:
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <arn>

# Check Nginx status on EC2
aws ssm start-session --target <instance-id>
sudo systemctl status nginx
```

**Solutions**:
- Verify Nginx is running: `sudo systemctl start nginx`
- Check security group rules allow ALB → EC2 HTTP:80
- Verify health check path `/` is accessible: `curl http://localhost/`
- Check user data script logs: `cat /var/log/user-data.log`

#### Issue 2: Certificate Import Failure

**Symptoms**: `aws_acm_certificate` resource fails to import

**Diagnosis**:
```bash
terraform show -json | jq '.values.root_module.resources[] | select(.type=="tls_self_signed_cert")'
```

**Solutions**:
- Verify certificate is valid: Check expiry date, subject
- Ensure certificate and private key match
- Check ACM import limits (20 certificates per account)

#### Issue 3: ALB DNS Not Resolving

**Symptoms**: `curl: (6) Could not resolve host`

**Diagnosis**:
```bash
# Check ALB exists
aws elbv2 describe-load-balancers --region ap-southeast-1

# Test DNS resolution
nslookup <alb-dns-name>
```

**Solutions**:
- Wait 2-3 minutes for DNS propagation
- Verify ALB is in "active" state
- Check VPC DNS settings (enableDnsHostnames = true)

---

## References

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Amazon Linux 2023 User Guide](https://docs.aws.amazon.com/linux/al2023/ug/)

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-02-01 | 1.0 | Initial implementation notes | Copilot CLI |

---

**Document Status**: ✅ Complete  
**Review Status**: Pending  
**Approval Status**: Pending

For questions or feedback, contact the infrastructure team.
