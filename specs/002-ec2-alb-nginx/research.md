# Research Document: EC2 Infrastructure with ALB and Nginx

**Feature**: 002-ec2-alb-nginx  
**Date**: 2025-02-01  
**Phase**: 0 - Research and Technology Selection

## Overview

This document captures research findings, technology decisions, and best practices for implementing a highly available, secure web infrastructure using EC2 instances with Application Load Balancer and Nginx in AWS ap-southeast-1 region.

## Key Research Areas

### 1. Private Module Registry Analysis

**Decision**: Use organization's private Terraform modules for all infrastructure components

**Available Modules** (verified via Terraform MCP Server):
- `app.terraform.io/ravi-panchal-org/ec2-instance/aws` (v6.1.4)
- `app.terraform.io/ravi-panchal-org/alb/aws` (v10.2.0)
- `app.terraform.io/ravi-panchal-org/security-group/aws` (v5.3.1)
- `app.terraform.io/ravi-panchal-org/acm/aws` (v6.3.0)

**Rationale**:
- Organizational mandate: constitution Section 1.1 requires module-first architecture
- Pre-vetted for security and compliance
- Reduces code duplication and maintenance burden
- Consistent patterns across organization
- Version pinning with semantic versioning ensures stability

**Alternatives Considered**:
- ❌ Public Terraform Registry modules: Rejected - violates organizational policy requiring `app.terraform.io/ravi-panchal-org/` source prefix
- ❌ Raw resource declarations: Rejected - bypasses organizational security controls and governance
- ❌ Custom local modules: Rejected - duplicates effort when approved modules exist

---

### 2. Self-Signed TLS Certificate Strategy

**Decision**: Use Terraform TLS provider to generate self-signed certificate, then import to ACM

**Implementation Approach**:
```hcl
# Generate private key
resource "tls_private_key" "self_signed" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate self-signed certificate
resource "tls_self_signed_cert" "self_signed" {
  private_key_pem = tls_private_key.self_signed.private_key_pem
  
  subject {
    common_name  = "web.demo.com"
    organization = "Demo Organization"
  }
  
  validity_period_hours = 8760  # 1 year
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Import to ACM
resource "aws_acm_certificate" "self_signed" {
  private_key      = tls_private_key.self_signed.private_key_pem
  certificate_body = tls_self_signed_cert.self_signed.cert_pem
}
```

**Rationale**:
- Requirement FR-003: Generate self-signed certificate for "web.demo.com"
- Requirement FR-004: Import to ACM without domain validation
- Infrastructure-as-code approach: certificate generation is repeatable and version-controlled
- No manual certificate creation or external tools required
- Terraform TLS provider is officially maintained by HashiCorp

**Alternatives Considered**:
- ❌ ACM module with DNS validation: Rejected - requires Route53 hosted zone and domain ownership
- ❌ ACM module with email validation: Rejected - requires domain email access
- ❌ Manual certificate creation + import: Rejected - not infrastructure-as-code, not repeatable
- ✅ Terraform TLS provider resources: Selected - meets self-signed requirement, fully automated

**Security Considerations**:
- Private key stored in Terraform state (encrypted at rest in HCP Terraform)
- Private key marked as `sensitive` in outputs
- Certificate lifecycle managed by Terraform (can rotate easily)
- Not suitable for production (browser warnings), but acceptable for development/demo per spec

---

### 3. Network Architecture with Default VPC

**Decision**: Use existing default VPC in ap-southeast-1 with data source lookup

**Implementation Pattern**:
```hcl
# Discover default VPC
data "aws_vpc" "default" {
  default = true
}

# Get subnets in required availability zones
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  filter {
    name   = "availability-zone"
    values = ["ap-southeast-1a", "ap-southeast-1b"]
  }
}
```

**Rationale**:
- Requirement FR-008: Must use existing default VPC
- Cost optimization (SC-007): No additional VPC charges
- Simplifies deployment: no VPC/subnet creation required
- Default VPC provides internet gateway and public subnets out of box

**Best Practices**:
- Verify default VPC exists in region before deployment
- Use data sources instead of hardcoding VPC/subnet IDs (portable across AWS accounts)
- Document dependency on default VPC existence
- Implement validation to fail fast if default VPC missing

**Alternatives Considered**:
- ❌ Create new VPC: Rejected - violates FR-008 and increases costs
- ❌ Use private registry VPC module: Rejected - spec requires default VPC usage
- ✅ Data source lookup: Selected - meets requirement, flexible, cost-effective

**Edge Case Handling**:
- If default VPC doesn't exist: deployment fails with clear error message (per spec edge cases)
- If fewer than 2 AZs available: deployment should fail or warn (high availability requirement)

---

### 4. EC2 Instance Configuration Best Practices

**Decision**: Use private registry EC2 module with organization-approved patterns

**Key Configuration Decisions**:

#### Instance Type Selection
- **Decision**: t3.micro or t3a.micro
- **Rationale**: 
  - Cost optimization requirement (SC-007: < $50/month)
  - Development environment workload
  - t3a.micro: ~10% cheaper than t3.micro with similar performance
  - Burstable performance suitable for demo/development workload
  - Nginx has minimal resource requirements for static content

#### AMI Selection
- **Decision**: Use module's default AMI SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
- **Rationale**:
  - Amazon Linux 2023 is AWS-optimized, secure, and well-supported
  - SSM parameter ensures latest patched AMI automatically
  - Module default reduces configuration complexity
  - Nginx installation via user data is straightforward on Amazon Linux

#### User Data for Nginx Installation
```bash
#!/bin/bash
# Install Nginx
yum update -y
yum install -y nginx

# Create test page (FR-007)
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>EC2 ALB Demo</title></head>
<body>
  <h1>Welcome to EC2 ALB Nginx Demo</h1>
  <p>Instance: $(ec2-metadata --instance-id | cut -d' ' -f2)</p>
  <p>Availability Zone: $(ec2-metadata --availability-zone | cut -d' ' -f2)</p>
</body>
</html>
EOF

# Start Nginx (FR-006)
systemctl enable nginx
systemctl start nginx
```

#### IAM Instance Profile
- **Decision**: Use module's `create_iam_instance_profile = true` with minimal permissions
- **Rationale**:
  - Constitution Section IV: EC2 instances must use IAM instance profiles
  - Least privilege: no specific AWS API calls needed for this demo
  - Module creates profile automatically with proper trust relationships
  - Future-proof: allows adding SSM Session Manager access if needed

**Alternatives Considered**:
- ❌ t2.micro: Rejected - t3.micro offers better performance-per-dollar and is current generation
- ❌ Larger instances (t3.small+): Rejected - unnecessary for development demo, violates cost constraint
- ❌ Manual AMI ID: Rejected - not maintainable, misses security patches
- ❌ Pre-baked AMI with Nginx: Rejected - adds complexity, user data approach simpler for demo

---

### 5. Application Load Balancer Configuration

**Decision**: Use private registry ALB module with HTTPS-only listener

**Key Configuration Decisions**:

#### Listener Configuration
- **HTTPS Listener**: Port 443 with ACM certificate
- **No HTTP Listener**: Per FR-003 and FR-010, HTTPS-only access
- **SSL Policy**: `ELBSecurityPolicy-TLS13-1-2-2021-06` (modern, secure)

#### Target Group Configuration
```hcl
# Targeting EC2 instances on port 80
target_group = {
  name     = "${var.project_name}-tg"
  port     = 80       # Nginx listens on port 80 internally
  protocol = "HTTP"   # HTTP between ALB and instances (internal network)
  
  health_check = {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}
```

**Rationale**:
- HTTPS termination at ALB: simplified EC2 configuration, centralized certificate management
- HTTP between ALB and instances: internal network traffic, reduces CPU overhead on instances
- Health check on `/`: validates Nginx is running and serving content (FR-013)
- Fast health check parameters: instances marked healthy within 1-2 minutes

#### ALB Placement
- **Decision**: Public-facing ALB in public subnets
- **Rationale**:
  - Requirement FR-009: Allow HTTPS traffic from internet
  - Default VPC subnets are public with internet gateway
  - Users need to access via ALB DNS name

**Best Practices from ALB Module**:
- Enable deletion protection: `false` for development (easy cleanup)
- Enable HTTP/2: `true` for better performance
- Idle timeout: 60 seconds (default, suitable for web traffic)
- Cross-zone load balancing: `true` (even distribution across AZs)
- Access logs: `false` for development (reduces costs, enable for production)

**Alternatives Considered**:
- ❌ Network Load Balancer: Rejected - ALB provides Layer 7 features, better for HTTP/HTTPS
- ❌ HTTP listener with redirect: Rejected - spec requires HTTPS-only (no HTTP access)
- ❌ HTTPS to instances: Rejected - adds complexity, certificate management per instance
- ✅ HTTPS at ALB, HTTP to instances: Selected - industry standard pattern

---

### 6. Security Group Strategy

**Decision**: Three security groups with least privilege access

#### Security Group Architecture
```
Internet → [ALB SG: HTTPS 443 from 0.0.0.0/0] → ALB
           ↓
           [EC2 SG: HTTP 80 from ALB SG only] → EC2 Instances
           ↓
           [Outbound: All traffic for updates]
```

**Security Group 1: ALB Security Group**
```hcl
module "alb_sg" {
  source = "app.terraform.io/ravi-panchal-org/security-group/aws"
  
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id
  
  ingress_rules = {
    https = {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access from internet (FR-009)"
    }
  }
  
  egress_rules = {
    to_instances = {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.ec2_sg.security_group_id
      description              = "HTTP to EC2 instances (FR-010)"
    }
  }
}
```

**Security Group 2: EC2 Security Group**
```hcl
module "ec2_sg" {
  source = "app.terraform.io/ravi-panchal-org/security-group/aws"
  
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = data.aws_vpc.default.id
  
  ingress_rules = {
    from_alb = {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
      description              = "HTTP from ALB only (FR-011)"
    }
  }
  
  egress_rules = {
    all = {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow outbound for system updates"
    }
  }
}
```

**Rationale**:
- FR-009: Security groups allow HTTPS (443) to ALB from internet
- FR-010: Traffic from ALB to EC2 instances on Nginx port (80)
- FR-011: Block direct public access to EC2 instances
- Constitution Section IV: Implement least privilege by default
- Security group references (not CIDR blocks) for ALB→EC2 communication: more secure, survives IP changes

**Best Practices**:
- Descriptive security group names with resource type prefix
- Explicit rule descriptions referencing requirements (FR-XXX)
- No SSH access by default (add only if needed for troubleshooting)
- Egress rules: restrictive on ALB, permissive on EC2 (for package updates)

**Alternatives Considered**:
- ❌ Single security group for all resources: Rejected - violates least privilege
- ❌ Allow SSH access: Rejected - not required by spec, reduces security posture
- ❌ HTTP listener on ALB: Rejected - spec requires HTTPS-only
- ✅ Separate security groups with minimal rules: Selected - follows AWS best practices

---

### 7. High Availability Architecture

**Decision**: 2 EC2 instances distributed across 2 availability zones

**Architecture Pattern**:
```
ap-southeast-1a          ap-southeast-1b
     |                        |
  [EC2-1]                  [EC2-2]
     |                        |
     └────────┬───────────────┘
              |
         [ALB Target Group]
              |
            [ALB]
              |
      (HTTPS from Internet)
```

**Implementation Strategy**:
```hcl
# Use for_each with availability zones
locals {
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]
}

module "ec2_instance" {
  for_each = toset(local.availability_zones)
  
  source = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  
  name              = "${var.project_name}-${each.key}"
  availability_zone = each.key
  subnet_id         = data.aws_subnet.az[each.key].id
  
  # ... other configuration
}
```

**Rationale**:
- FR-001: Instances in exactly 2 different AZs in ap-southeast-1
- SC-003: Zero downtime during single-instance failure
- High availability: service continues if one AZ fails
- Even distribution: `for_each` ensures 1 instance per AZ

**ALB Cross-Zone Load Balancing**:
- Enable cross-zone load balancing: true (even traffic distribution)
- ALB spans both availability zones automatically
- Health checks ensure only healthy instances receive traffic

**Best Practices**:
- Use `for_each` instead of `count` for better state management
- Subnet selection per AZ: ensures proper distribution
- Independent instance naming: includes AZ identifier
- Graceful degradation: system functions with 1 instance, though not optimal

**Alternatives Considered**:
- ❌ Single instance: Rejected - violates high availability requirement (FR-001)
- ❌ 3+ instances: Rejected - unnecessary cost for development, spec requires exactly 2 AZs
- ❌ Auto Scaling Group: Rejected - adds complexity, fixed 2-instance count per spec
- ✅ 2 instances (1 per AZ) with ALB: Selected - meets requirements, cost-effective

---

### 8. Tagging Strategy

**Decision**: Comprehensive tagging for cost tracking, environment identification, and governance

**Required Tags** (per FR-015 and organizational standards):
```hcl
locals {
  common_tags = {
    # Required tags
    Environment      = var.environment           # "development"
    ManagedBy        = "terraform"
    Terraform        = "true"
    
    # Feature identification
    Project          = var.project_name          # "nginx-alb"
    Feature          = "002-ec2-alb-nginx"
    
    # HCP Terraform context
    Workspace        = "sandbox_workspace"
    Organization     = "ravi-panchal-org"
    
    # Cost optimization
    CostCenter       = "development"
    CostOptimization = "minimal"
    
    # Compliance
    Compliance       = "organizational-standards"
    SecurityLevel    = "development"
  }
}
```

**Tag Application Pattern**:
- All modules accept `tags` input parameter
- Merge common_tags with resource-specific tags
- Consistent tagging enables AWS Cost Explorer filtering
- Required for organizational governance and compliance

**Best Practices**:
- Define tags in `locals.tf` for reusability
- Use variables for dynamic tag values (environment, project_name)
- Document tag purpose and values in variables.tf
- Include FR reference for compliance traceability

---

### 9. Cost Optimization Strategy

**Decision**: Minimize costs while meeting functional requirements

**Cost-Saving Measures**:

1. **Instance Type**: t3a.micro (cheapest suitable option)
   - On-Demand: ~$0.0094/hour = ~$6.77/month per instance
   - 2 instances: ~$13.54/month

2. **ALB**: Application Load Balancer
   - Fixed cost: ~$16.20/month (ap-southeast-1)
   - LCU costs: minimal for low traffic

3. **Data Transfer**: Minimal for development/demo
   - First 1 GB/month: Free
   - Expected usage: < 1 GB/month

4. **EBS Volumes**: Minimal storage
   - Root volumes: 8 GB gp3 per instance
   - Cost: ~$0.096/month per volume = ~$0.19/month total

5. **No Additional Costs**:
   - No NAT Gateway (using default VPC public subnets)
   - No additional EBS volumes
   - No Elastic IPs (using ALB DNS)
   - No CloudWatch detailed monitoring
   - No ALB access logs (S3 storage cost)

**Total Estimated Cost**: ~$30-35/month (well under $50/month requirement SC-007)

**Cost Monitoring**:
- Tag all resources for AWS Cost Explorer filtering
- Recommend setting up AWS Budget alert at $40/month
- Document cost breakdown in quickstart.md

**Alternatives Considered**:
- ❌ t2.micro: Rejected - similar price, worse performance than t3.micro
- ❌ Spot instances: Rejected - may cause availability issues for demo
- ❌ Reserved Instances: Rejected - short-term demo, no commitment benefit
- ✅ On-Demand t3a.micro: Selected - predictable cost, sufficient performance

---

### 10. Testing and Validation Strategy

**Decision**: Multi-layer testing approach for infrastructure validation

**Testing Layers**:

#### 1. Pre-Deployment Validation
```bash
# Terraform syntax validation
terraform fmt -check
terraform validate

# TFLint for best practices
tflint --init
tflint

# Pre-commit hooks
pre-commit run --all-files
```

#### 2. Deployment Validation
```bash
# Plan review
terraform plan -out=tfplan

# Apply with confirmation
terraform apply tfplan

# Verify deployment
terraform show
```

#### 3. Infrastructure Health Checks
```bash
# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Feature,Values=002-ec2-alb-nginx" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,AvailabilityZone]'

# Check ALB health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Get ALB DNS name
terraform output alb_dns_name
```

#### 4. Functional Testing
```bash
# Test HTTPS access (accept self-signed cert)
curl -k https://<alb-dns-name>

# Verify TLS handshake
openssl s_client -connect <alb-dns-name>:443 -servername web.demo.com

# Browser testing
# Navigate to: https://<alb-dns-name>
# Accept self-signed certificate warning
# Verify test page loads
```

#### 5. High Availability Testing
```bash
# Terminate one instance
aws ec2 terminate-instances --instance-ids <instance-id>

# Verify ALB still serves traffic (should succeed)
curl -k https://<alb-dns-name>

# Check target health (should show 1 healthy, 1 unhealthy)
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

**Success Criteria Validation** (maps to spec SC-001 through SC-010):
- SC-001: HTTPS access via ALB DNS within 60 seconds ✓
- SC-002: Nginx test page loads with valid TLS ✓
- SC-003: Service available with 1 instance terminated ✓
- SC-004: No HTTP access (only HTTPS) ✓
- SC-005: `terraform validate` passes ✓
- SC-006: Cannot SSH to instances directly ✓
- SC-007: Cost under $50/month ✓
- SC-008: Instances healthy within 5 minutes ✓
- SC-009: Certificate in ACM console ✓
- SC-010: Instances in different AZs ✓

**Alternatives Considered**:
- ❌ Automated integration tests (Terratest): Rejected - overkill for single-feature demo
- ❌ Load testing: Rejected - not required for development environment
- ✅ Manual validation with documented steps: Selected - appropriate for demo scope

---

### 11. Terraform Provider Versions

**Decision**: Pin provider versions for consistency and reproducibility

**Provider Configuration**:
```hcl
terraform {
  required_version = ">= 1.5.7"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"  # Compatible with private modules
    }
    
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"  # For self-signed certificate
    }
  }
}

provider "aws" {
  region = var.region
  
  # Dynamic credentials from HCP Terraform workspace variable sets
  # No explicit credentials configuration required
}

provider "tls" {
  # No configuration required
}
```

**Rationale**:
- AWS Provider >= 6.0: Required by private registry modules (ec2-instance, alb, security-group)
- TLS Provider ~> 4.0: Current stable version for certificate generation
- Use `~>` constraint: allows patch updates, prevents breaking changes
- HCP Terraform workspace handles provider authentication automatically

**Best Practices**:
- Pin required_version to match organizational standards
- Use semantic versioning constraints for predictable updates
- Document provider version requirements in README
- Test module compatibility with provider versions before deployment

---

## Summary of Key Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| **Module Strategy** | Private registry modules only | Organizational mandate, security compliance |
| **TLS Certificate** | Terraform TLS provider → Self-signed → ACM import | Meets self-signed requirement, fully automated |
| **Network** | Default VPC with data sources | Cost optimization, spec requirement |
| **Compute** | t3a.micro instances | Cost optimization, sufficient for demo |
| **Load Balancer** | ALB with HTTPS-only | Layer 7 features, TLS termination |
| **High Availability** | 2 instances, 1 per AZ | Meets spec, survives single AZ failure |
| **Security** | 3 security groups, least privilege | Best practice, blocks direct instance access |
| **Cost Target** | ~$30-35/month | Under $50/month requirement |
| **Testing** | Manual validation with documented steps | Appropriate for demo scope |

---

## Open Questions / Future Considerations

### Resolved Questions
- ✅ Which modules to use? → Private registry modules identified and verified
- ✅ How to handle self-signed certificate? → Terraform TLS provider resources
- ✅ How to distribute instances across AZs? → `for_each` with AZ list
- ✅ How to restrict access to instances? → Security group with ALB-only access

### Future Enhancements (out of scope for this feature)
- Auto Scaling Group for dynamic capacity
- Route53 domain with valid TLS certificate (Let's Encrypt/ACM validation)
- CloudWatch dashboards and alarms
- AWS WAF for application firewall
- VPC Flow Logs for network monitoring
- SSM Session Manager for secure instance access
- Blue-green deployment strategy
- Multi-region failover

---

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform TLS Provider Documentation](https://registry.terraform.io/providers/hashicorp/tls/latest/docs)
- [AWS ALB Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/best-practices.html)
- [Nginx Configuration Best Practices](https://www.nginx.com/blog/tuning-nginx/)
- Organizational Constitution: `.specify/memory/constitution.md`

---

**Research Complete**: All technical decisions documented with rationale and alternatives considered. Ready to proceed to Phase 1: Design & Contracts.
