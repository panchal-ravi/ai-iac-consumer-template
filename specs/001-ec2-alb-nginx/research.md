# Phase 0: Research & Design Decisions
## Feature: AWS EC2 Infrastructure with Application Load Balancer and Nginx

**Branch**: `001-ec2-alb-nginx`  
**Date**: 2025-01-13  
**Status**: Complete

---

## Overview

This research phase consolidates all technical decisions, best practices, and architectural patterns for provisioning a highly available web infrastructure with EC2 instances, Application Load Balancer, and Nginx in AWS ap-southeast-1 region using HCP Terraform.

---

## 1. Private Module Registry Analysis

### 1.1 Available Private Modules (ravi-panchal-org)

**Decision**: Use private registry modules exclusively for all infrastructure components.

**Available Modules**:

1. **EC2 Instance Module** (`ravi-panchal-org/ec2-instance/aws`)
   - Version: 6.1.4
   - Source: Based on terraform-aws-modules/ec2-instance/aws
   - Key Features:
     - Supports t3.micro instance type ✓
     - Built-in security group creation
     - IAM instance profile support
     - User data script support for Nginx installation
     - EBS volume management
     - Multiple AZ support through count/for_each
     - Metadata IMDSv2 enabled by default
     - SSM parameter support for AMI selection

2. **Application Load Balancer Module** (`ravi-panchal-org/alb/aws`)
   - Version: 10.2.0
   - Key Features:
     - Internet-facing and internal ALB support
     - HTTPS listener configuration
     - ACM certificate integration
     - Target group management with health checks
     - Security group creation and management
     - Cross-zone load balancing
     - Multiple target group support
     - Connection draining configuration

3. **Security Group Module** (`ravi-panchal-org/security-group/aws`)
   - Version: 5.3.1
   - Key Features:
     - VPC security group creation
     - Ingress/egress rule management
     - Source security group referencing
     - CIDR block rules
     - Prefix list support
     - Pre-defined rule templates

4. **VPC Module** (`ravi-panchal-org/vpc/aws`)
   - Version: 6.5.0
   - Usage: NOT NEEDED (using existing default VPC)
   - Note: Included for completeness but spec requires default VPC

**Rationale**: 
- All required modules exist in private registry
- Modules align with organizational standards
- No need for public registry fallback
- Meets constitution requirement for module-first architecture

---

## 2. AWS Architecture Decisions

### 2.1 Region and Availability Zone Strategy

**Decision**: Deploy in ap-southeast-1 (Singapore) across 2 availability zones

**Availability Zones**:
- Primary: ap-southeast-1a
- Secondary: ap-southeast-1b
- Tertiary: ap-southeast-1c (available but not used per spec requirement of exactly 2 instances)

**Rationale**:
- Spec mandates ap-southeast-1 region
- Default VPC has subnets in multiple AZs by default
- 2 AZs provide fault tolerance at minimum cost
- ALB requires minimum 2 AZs for high availability

### 2.2 Compute Instance Configuration

**Decision**: Use t3.micro instances with Amazon Linux 2023

**Instance Specifications**:
- Instance Type: t3.micro (2 vCPU, 1 GiB RAM)
- AMI: Amazon Linux 2023 (via SSM parameter)
- SSM Parameter: `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
- Root Volume: 8 GB GP3 EBS (default)
- Instance Metadata: IMDSv2 (enforced by module default)

**Rationale**:
- t3.micro meets spec requirement and cost constraint ($7-8/month per instance)
- Amazon Linux 2023 provides:
  - Long-term support until 2028
  - SELinux enabled by default
  - Modern systemd-based init
  - Native Nginx package availability
  - Optimized for AWS
- SSM parameter ensures latest security patches
- IMDSv2 provides enhanced security for instance metadata access

### 2.3 Network Architecture

**Decision**: Use existing default VPC with data source lookups

**Network Components**:
```hcl
# Default VPC lookup
data "aws_vpc" "default" {
  default = true
}

# Default subnets in multiple AZs
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
- Spec requires existing default VPC
- Default VPC includes:
  - Internet Gateway (0.0.0.0/0 route)
  - Public subnets with auto-assign public IP
  - Default DHCP options
  - DNS support enabled
- No custom VPC creation needed
- Reduces complexity and cost

### 2.4 Load Balancer Configuration

**Decision**: Internet-facing Application Load Balancer with TLS termination

**ALB Specifications**:
- Type: Application Load Balancer (Layer 7)
- Scheme: internet-facing
- IP Address Type: IPv4
- Subnets: Both AZ subnets (ap-southeast-1a, ap-southeast-1b)
- Security Group: Dedicated ALB security group
- Listeners:
  - Port 443 (HTTPS) - primary listener with ACM certificate
- Target Group:
  - Protocol: HTTP
  - Port: 80
  - Target Type: instance
  - Health Check: HTTP GET / (default path)
  - Deregistration Delay: 30 seconds (development environment)

**Rationale**:
- Application Load Balancer provides:
  - Path-based routing (future extensibility)
  - Host-based routing (multi-domain support)
  - HTTP/2 and WebSocket support
  - Native AWS WAF integration capability
- TLS termination at ALB reduces backend overhead
- HTTP backend simplifies instance configuration
- Health checks ensure traffic only routes to healthy instances

---

## 3. Security Architecture

### 3.1 TLS Certificate Strategy

**Decision**: Generate self-signed certificate using Terraform TLS provider

**Certificate Configuration**:
```hcl
# Certificate specifications
Algorithm: RSA
Key Size: 2048 bits
Validity Period: 5 years (1825 days)
Subject:
  Common Name: web.demo.com
  Organization: Development
  Organizational Unit: Engineering
  Country: SG
Subject Alternative Names: 
  - web.demo.com
  - *.web.demo.com (wildcard for subdomains)
```

**Certificate Resources**:
1. `tls_private_key` - Generate RSA private key
2. `tls_self_signed_cert` - Create self-signed certificate
3. `aws_acm_certificate` - Import certificate to ACM

**Rationale**:
- Self-signed certificate meets development environment needs
- No domain registration or DNS validation required
- 5-year validity reduces maintenance overhead
- ACM import enables ALB integration
- RSA 2048-bit provides adequate security for dev
- Browser warnings are expected and acceptable for development

### 3.2 Security Group Design

**Decision**: Implement least-privilege security groups with explicit rules

**Security Group Architecture**:

**ALB Security Group**:
```hcl
Name: alb-security-group
VPC: Default VPC
Ingress Rules:
  - Protocol: TCP
    Port: 443
    Source: 0.0.0.0/0
    Description: Allow HTTPS from internet
Egress Rules:
  - Protocol: TCP
    Port: 80
    Destination: EC2 security group ID
    Description: Forward HTTP to backend instances
```

**EC2 Security Group**:
```hcl
Name: ec2-security-group
VPC: Default VPC
Ingress Rules:
  - Protocol: TCP
    Port: 80
    Source: ALB security group ID
    Description: Allow HTTP from ALB only
Egress Rules:
  - Protocol: TCP
    Port: 443
    Destination: 0.0.0.0/0
    Description: Allow HTTPS for package updates
  - Protocol: TCP
    Port: 80
    Destination: 0.0.0.0/0
    Description: Allow HTTP for package repositories
```

**Rationale**:
- Least-privilege principle enforced
- EC2 instances not directly accessible from internet
- ALB is sole ingress point for web traffic
- Egress allows instances to download packages and updates
- Security group referencing (not CIDR) provides dynamic security
- Aligns with AWS Well-Architected security pillar

### 3.3 IAM and Secrets Management

**Decision**: Minimal IAM configuration for development environment

**IAM Considerations**:
- No IAM instance profile required for basic web server
- Future enhancements may add:
  - SSM Session Manager access (alternative to SSH)
  - CloudWatch Logs agent permissions
  - S3 access for static content
  - Secrets Manager for application secrets

**Rationale**:
- Spec doesn't require IAM roles
- Nginx static site has no AWS API dependencies
- Keeps infrastructure simple
- IAM can be added incrementally

---

## 4. Application Configuration

### 4.1 Nginx Installation and Configuration

**Decision**: Install Nginx via user_data script with systemd management

**User Data Script**:
```bash
#!/bin/bash
set -e

# Update system packages
dnf update -y

# Install Nginx
dnf install -y nginx

# Create test HTML page
cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 ALB Nginx Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { margin: 0 0 1rem 0; }
        .info { 
            margin: 1rem 0;
            padding: 0.5rem;
            background: rgba(0, 0, 0, 0.2);
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 EC2 ALB Nginx Demo</h1>
        <p>Successfully deployed with Terraform!</p>
        <div class="info">
            <strong>Instance ID:</strong> $(ec2-metadata --instance-id | cut -d ' ' -f 2)<br>
            <strong>Availability Zone:</strong> $(ec2-metadata --availability-zone | cut -d ' ' -f 2)<br>
            <strong>Region:</strong> ap-southeast-1
        </div>
        <p style="font-size: 0.9rem; margin-top: 2rem;">
            ✅ TLS Terminated at ALB<br>
            ✅ High Availability Architecture<br>
            ✅ Managed by HCP Terraform
        </p>
    </div>
</body>
</html>
EOF

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx

# Verify Nginx is running
systemctl status nginx
```

**Rationale**:
- User data runs once at first boot
- dnf is native package manager for Amazon Linux 2023
- systemd ensures Nginx starts on reboot
- Test page displays instance metadata for verification
- Error handling with `set -e` ensures failures are visible
- Meets FR-004, FR-005, FR-013 requirements

### 4.2 Health Check Configuration

**Decision**: Simple HTTP health check on root path

**Health Check Parameters**:
```hcl
protocol            = "HTTP"
port                = 80
path                = "/"
interval            = 30      # Check every 30 seconds
timeout             = 5       # Timeout after 5 seconds
healthy_threshold   = 2       # 2 successful checks = healthy
unhealthy_threshold = 2       # 2 failed checks = unhealthy
matcher             = "200"   # HTTP 200 OK required
```

**Rationale**:
- Root path (/) is always available
- 30-second interval balances responsiveness and cost
- 2-check thresholds provide quick failover (60 seconds to detect failure)
- Meets FR-012, FR-026 requirements
- Conservative timeouts prevent false positives

---

## 5. Terraform Configuration

### 5.1 HCP Terraform Workspace Configuration

**Decision**: Use existing HCP Terraform workspace with VCS integration

**Workspace Details**:
```hcl
Organization: ravi-panchal-org
Project: Default Project
Workspace: sandbox_workspace
Execution Mode: Remote
Terraform Version: Latest (managed by HCP Terraform)
VCS Integration: GitHub (if configured)
```

**Rationale**:
- Spec mandates specific organization and workspace
- Remote execution provides:
  - Audit trail for all changes
  - Consistent execution environment
  - Automatic state locking
  - Secure credential management
- Meets FR-017, FR-018, FR-020 requirements

### 5.2 Terraform Provider Configuration

**Decision**: Use AWS provider with region constraint

**Provider Configuration**:
```hcl
terraform {
  required_version = ">= 1.7.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
  
  default_tags {
    tags = {
      Environment = "development"
      Project     = "ec2-alb-nginx"
      ManagedBy   = "terraform"
      Owner       = "DevOps"
    }
  }
}
```

**Rationale**:
- AWS provider ~> 5.0 provides latest features and security patches
- TLS provider for certificate generation
- Region constraint prevents accidental deployment to wrong region
- Default tags ensure all resources are properly tagged
- Version constraints provide stability while allowing patch updates

### 5.3 State Management

**Decision**: HCP Terraform remote state (automatic)

**State Configuration**:
- Backend: HCP Terraform (automatic when using workspace)
- State Locking: Automatic
- Encryption: At rest and in transit
- Versioning: Automatic with rollback capability
- Access Control: HCP Terraform RBAC

**Rationale**:
- No manual backend configuration needed
- HCP Terraform handles all state management
- Team collaboration supported
- Audit trail for all state changes
- Meets FR-017 requirement

---

## 6. Cost Optimization Strategy

### 6.1 Cost Analysis

**Monthly Cost Estimate** (ap-southeast-1 pricing):

| Component | Quantity | Unit Cost | Monthly Cost |
|-----------|----------|-----------|--------------|
| EC2 t3.micro instances | 2 | $7.30 | $14.60 |
| EBS GP3 volumes (8GB each) | 2 | $0.80 | $1.60 |
| Application Load Balancer | 1 | $22.27 | $22.27 |
| ALB LCU hours (minimal traffic) | ~10 LCU-hrs | $0.008 | $0.08 |
| Data Transfer Out (minimal) | <1 GB | $0.12/GB | $0.12 |
| **Total Estimated Cost** | | | **$38.67/month** |

**Rationale**:
- Under $50/month budget (SC-007)
- t3.micro provides adequate performance for development
- GP3 EBS provides better cost/performance than GP2
- ALB cost is fixed for development workload
- Minimal data transfer in development environment

### 6.2 Cost Optimization Techniques

**Implemented Optimizations**:
1. Minimal instance size (t3.micro)
2. Only 2 instances (meets HA requirement at minimum)
3. Default VPC (no NAT gateway costs)
4. Public subnets (no NAT gateway needed)
5. Self-signed certificate (no ACM public certificate cost)
6. Standard health check interval (not aggressive)

**Future Optimization Opportunities** (not in scope):
- Reserved instances for 1-year commitment
- Savings plans for compute
- Auto-scaling schedule (nights/weekends off)
- CloudFront CDN for caching (reduces origin requests)

---

## 7. Testing and Validation Strategy

### 7.1 Infrastructure Testing Approach

**Decision**: Manual testing for development environment

**Testing Levels**:

1. **Terraform Validation**:
   ```bash
   terraform init
   terraform validate
   terraform plan
   ```

2. **Resource Creation Verification**:
   - EC2 instances in different AZs
   - ALB created and active
   - Target group with registered targets
   - Security groups with correct rules
   - ACM certificate imported

3. **Connectivity Testing**:
   ```bash
   # Test ALB endpoint
   curl -k https://<alb-dns-name>
   
   # Verify certificate
   openssl s_client -connect <alb-dns-name>:443 -servername web.demo.com
   
   # Check health status
   aws elbv2 describe-target-health --target-group-arn <tg-arn>
   ```

4. **Security Validation**:
   - Verify direct EC2 access blocked
   - Confirm ALB security group rules
   - Test traffic flow ALB → EC2

5. **Failover Testing**:
   ```bash
   # Stop Nginx on one instance
   aws ssm send-command --instance-ids <id> --document-name "AWS-RunShellScript" \
     --parameters 'commands=["sudo systemctl stop nginx"]'
   
   # Verify ALB continues serving traffic
   for i in {1..20}; do curl -k https://<alb-dns-name>; sleep 1; done
   ```

**Rationale**:
- Manual testing appropriate for development
- Automated testing can be added in future iterations
- Covers all acceptance criteria from spec
- Validates both functional and security requirements

### 7.2 Monitoring and Observability

**Decision**: AWS native monitoring with CloudWatch metrics (automatic)

**Automatic Metrics**:
- EC2: CPU, Network, Disk, Status Checks
- ALB: Request count, Target response time, HTTP codes
- Target Group: Healthy/unhealthy host count

**Rationale**:
- No additional configuration needed
- CloudWatch metrics included in service cost
- Sufficient for development environment
- Advanced monitoring (logs, traces) out of scope

---

## 8. Best Practices and Standards

### 8.1 Terraform Best Practices Applied

1. **Module-First Architecture**: Using private registry modules exclusively
2. **Variable Validation**: Input validation with custom conditions
3. **Output Definitions**: Key outputs for downstream dependencies
4. **Resource Naming**: Consistent naming convention with environment prefix
5. **Tagging Strategy**: Consistent tags across all resources
6. **Documentation**: Inline comments referencing spec requirements
7. **Version Constraints**: Semantic versioning for modules and providers

### 8.2 AWS Well-Architected Framework Alignment

**Operational Excellence**:
- Infrastructure as Code with Terraform
- Version control for all configurations
- HCP Terraform for change management

**Security**:
- Least-privilege security groups
- TLS encryption in transit
- IMDSv2 for instance metadata
- No public key pairs (SSM Session Manager for future access)

**Reliability**:
- Multi-AZ deployment
- Auto-healing with health checks
- Stateless application architecture

**Performance Efficiency**:
- Right-sized instances for workload
- Application Load Balancer for efficient routing
- GP3 EBS for better performance/cost

**Cost Optimization**:
- Minimal instance sizes
- No over-provisioning
- Default VPC to avoid NAT costs
- Development-appropriate architecture

**Sustainability**:
- Minimal resource footprint
- No always-on bastion hosts
- Efficient instance types

---

## 9. Risks and Mitigations

### 9.1 Identified Risks from Spec

| Risk | Impact | Mitigation Strategy | Status |
|------|--------|---------------------|--------|
| Default VPC not exist | High | Pre-deployment validation script | Documented |
| Certificate expiration (5 years) | Medium | Set 5-year validity; document renewal process | Resolved |
| Both instances unhealthy | High | Monitoring and alerting; documented in outputs | Accepted |
| t3.micro insufficient | Medium | Monitoring CPU/memory; easy to upgrade | Accepted |
| Cost exceeds $50/month | Medium | Monthly cost = $38.67; 23% under budget | Resolved |
| Health check false positives | Medium | Conservative thresholds (2 checks, 30s interval) | Resolved |

### 9.2 Additional Technical Risks

| Risk | Mitigation |
|------|------------|
| User data script failure | Add validation checks; log to CloudWatch on failure |
| Security group cyclic dependency | Create security groups before instances and ALB |
| AMI unavailable in region | Use SSM parameter with fallback to specific AMI ID |
| Module version incompatibility | Pin module versions; test before production |

---

## 10. Implementation Roadmap

### 10.1 Implementation Phases

**Phase 1: Foundation** (Estimated: 30 minutes)
- Set up Terraform configuration
- Import default VPC and subnet data sources
- Generate and import TLS certificate

**Phase 2: Security** (Estimated: 20 minutes)
- Create ALB security group
- Create EC2 security group
- Configure security group rules

**Phase 3: Compute** (Estimated: 30 minutes)
- Deploy EC2 instances with user data
- Verify Nginx installation
- Test instance accessibility

**Phase 4: Load Balancer** (Estimated: 30 minutes)
- Create target group
- Deploy Application Load Balancer
- Configure HTTPS listener
- Register instances with target group

**Phase 5: Validation** (Estimated: 30 minutes)
- Test ALB endpoint
- Verify certificate
- Test failover scenario
- Validate security groups

**Total Estimated Time**: 2.5 hours

### 10.2 Rollback Strategy

**Terraform Destroy Order**:
1. Application Load Balancer
2. Target Group
3. EC2 Instances
4. Security Groups
5. ACM Certificate
6. TLS Resources (private key, certificate)

**Rationale**:
- Stateless architecture allows clean destroy
- No data loss concerns
- Can recreate from code in minutes

---

## 11. Documentation and Knowledge Transfer

### 11.1 Required Documentation

1. **Architecture Diagram**: Network topology showing VPC, subnets, ALB, EC2, security groups
2. **Deployment Guide**: Step-by-step instructions for applying Terraform
3. **Testing Guide**: How to validate deployment and test failover
4. **Troubleshooting Guide**: Common issues and resolutions
5. **Cost Breakdown**: Detailed cost analysis with optimization opportunities

### 11.2 Knowledge Transfer Topics

- How to access ALB endpoint
- How to interpret health check status
- How to view CloudWatch metrics
- How to update Nginx content
- How to add more instances
- How to troubleshoot certificate issues

---

## 12. Alternatives Considered and Rejected

### 12.1 Network Load Balancer (NLB)

**Reason for Rejection**:
- Application Load Balancer better suited for HTTP/HTTPS traffic
- ALB provides Layer 7 features (path routing, host headers)
- NLB is Layer 4 (TCP/UDP) - overkill for this use case
- ALB has better integration with ACM certificates

### 12.2 Auto Scaling Group

**Reason for Rejection**:
- Spec requires exactly 2 instances
- Auto-scaling adds complexity not needed for development
- Manual instance management acceptable for dev environment
- Can be added in future iteration if needed

### 12.3 CloudFront CDN

**Reason for Rejection**:
- Out of scope per spec
- Adds cost and complexity
- Not necessary for development environment
- Regional traffic only (no global distribution needed)

### 12.4 AWS Certificate Manager Public Certificate

**Reason for Rejection**:
- Requires domain ownership and DNS validation
- Adds cost and complexity
- Self-signed certificate sufficient for development
- Spec explicitly requires self-signed certificate

### 12.5 Custom VPC

**Reason for Rejection**:
- Spec explicitly requires default VPC
- Adds unnecessary complexity
- Default VPC has all necessary components
- No custom networking requirements

---

## 13. Success Criteria Validation

### 13.1 Functional Requirements Coverage

✅ All 27 functional requirements addressed:
- FR-001 to FR-027: Covered in architecture decisions
- Module-first approach (FR-019)
- HCP Terraform integration (FR-017, FR-018)
- Security best practices (FR-021)
- Cost optimization (FR-024)

### 13.2 Success Criteria Mapping

✅ All 13 success criteria achievable:
- SC-001: Terraform apply time < 10 minutes
- SC-002: Response time < 2 seconds (ALB provides sub-second routing)
- SC-003: 100% availability with one instance down
- SC-004: TLS termination validated
- SC-005: Direct access blocked via security groups
- SC-006: Health checks detect failure in 60 seconds (2 checks × 30s)
- SC-007: Cost $38.67/month (under $50 target)
- SC-008: Security groups auditable via Terraform state
- SC-009: HCP Terraform state management
- SC-010: Infrastructure reproducible via `terraform destroy && apply`
- SC-011: Certificate shows web.demo.com (with warnings)
- SC-012: 100% success rate to healthy instances
- SC-013: Round-robin distribution by default

---

## 14. Conclusion

### 14.1 Key Takeaways

1. **Private modules available**: All required modules exist in ravi-panchal-org registry
2. **Architecture validated**: Design meets all functional and non-functional requirements
3. **Cost within budget**: $38.67/month vs $50 budget (23% under)
4. **Security posture strong**: Least-privilege, TLS termination, no direct instance access
5. **High availability**: Multi-AZ deployment with automatic failover
6. **Terraform ready**: Configuration patterns identified and documented

### 14.2 Ready for Implementation

All NEEDS CLARIFICATION items from Technical Context have been resolved:
- ✅ Terraform version: Latest (managed by HCP Terraform)
- ✅ AWS provider version: ~> 5.0
- ✅ Module versions: Identified from private registry
- ✅ Testing strategy: Manual validation appropriate for development
- ✅ Instance type: t3.micro confirmed available in ap-southeast-1
- ✅ Network architecture: Default VPC with multi-AZ subnets
- ✅ Certificate strategy: Self-signed via TLS provider
- ✅ Cost estimation: $38.67/month detailed breakdown

### 14.3 Next Steps

Proceed to **Phase 1: Design & Contracts**
- Generate data-model.md with Terraform resource relationships
- Create API contracts (Terraform outputs as "API")
- Generate quickstart.md for deployment instructions
- Update agent context with technology decisions

---

**Research Phase Complete** ✅  
**All unknowns resolved** ✅  
**Ready for implementation planning** ✅
