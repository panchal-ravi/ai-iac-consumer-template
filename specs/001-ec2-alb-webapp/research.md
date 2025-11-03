# Research: Web Application Infrastructure with High Availability

**Feature**: 001-ec2-alb-webapp
**Date**: 2025-11-03
**Status**: Complete

## Overview

This document consolidates research findings for deploying a highly available web application infrastructure on AWS using HCP Terraform. The research focused on identifying available private Terraform modules, determining HCP Terraform configuration requirements, and establishing best practices for AWS infrastructure components.

---

## 1. HCP Terraform Configuration

### Decision: Organization and Project Structure

**Organization Name**: `hashi-demos-apj`

**Rationale**:
- Confirmed via Terraform MCP server that this organization exists and contains relevant AWS infrastructure modules
- User explicitly specified to use this organization
- Organization contains 16 private modules including VPC and EC2 instance modules needed for this project

**Selected Project**:
- ✅ **Project Name**: `hackathon`
- ✅ **Project ID**: `prj-hna8wHXsgBrDhHDz`

**Workspace Configuration**:
- ✅ **Workspace Name**: `webapp-sandbox`
- ✅ **Environment Type**: Sandbox/Demo (hackathon environment)
- ✅ **Domain Name**: `web.simon-lynch.sbx.hashidemos.io`

**Note**: Using single sandbox workspace for hackathon. Production deployments would follow dev → staging → prod workflow with separate workspaces.

**Alternatives Considered**:
- Multiple organizations were available (10 total) but user specified hashi-demos-apj
- Could use existing projects like "Aarons AWS Projects" but Default Project provides clean slate

---

## 2. Available Private Terraform Modules

### Decision: Module Inventory and Gaps Analysis

#### ✅ Available Modules

**1. VPC Module** (`hashi-demos-apj/vpc/aws` v6.5.0)
- **Purpose**: Network foundation with subnets, route tables, NAT gateways, Internet gateway
- **Key Features**:
  - Multi-AZ subnet creation (public, private, database, elasticache, redshift, intra, outpost)
  - NAT Gateway support (single, per-AZ, or per-subnet)
  - VPC Flow Logs support
  - Network ACLs and Security Group management
  - IPv4 and IPv6 support
- **Inputs Needed**: VPC CIDR, AZs list, subnet CIDRs, NAT gateway configuration
- **Outputs**: VPC ID, subnet IDs, route table IDs, NAT gateway IDs, security group IDs
- **Source**: `app.terraform.io/hashi-demos-apj/vpc/aws`
- **Status**: Production-ready, based on terraform-aws-modules/vpc/aws

**2. EC2 Instance Module** (`hashi-demos-apj/ec2-instance/aws` v5.0.0)
- **Purpose**: Single EC2 instance creation with IAM role, user data, and EBS configuration
- **Key Features**:
  - Spot instance support
  - IAM instance profile creation
  - User data and user data base64 support
  - EBS volume attachment
  - Metadata options (IMDSv2)
  - SSM parameter lookup for AMI IDs
- **Inputs Needed**: AMI ID/SSM parameter, instance type, subnet ID, security groups, user data
- **Outputs**: Instance ID, public/private IPs, IAM role ARN
- **Source**: `app.terraform.io/hashi-demos-apj/ec2-instance/aws`
- **Status**: Production-ready, based on terraform-aws-modules/ec2-instance/aws
- **Limitation**: Single instance module - does not handle Auto Scaling Groups

#### ❌ Missing Modules (Gaps)

**1. Application Load Balancer (ALB) Module**
- **Searched For**: "alb", "load balancer"
- **Result**: No private ALB module available
- **Impact**: HIGH - ALB is core requirement (FR-002, FR-003)
- **Workaround Options**:
  - Use public Terraform registry module: `terraform-aws-modules/alb/aws`
  - Create raw AWS resources (violates constitution Module-First Architecture principle)
  - Request platform team to publish ALB module to private registry
- **Recommended**: Seek user approval to use public registry ALB module with version constraints

**2. Auto Scaling Group (ASG) Module**
- **Searched For**: "autoscaling", "asg", "auto scaling"
- **Result**: No private ASG module available
- **Impact**: HIGH - Auto Scaling is core requirement (FR-011, SC-004)
- **Workaround Options**:
  - Use public Terraform registry module: `terraform-aws-modules/autoscaling/aws`
  - Create raw AWS resources (violates constitution)
  - Use EC2 instance module with count/for_each (doesn't provide auto-scaling functionality)
  - Request platform team to publish ASG module
- **Recommended**: Seek user approval to use public registry ASG module with version constraints

**3. Security Group Module**
- **Searched For**: "security", "security group"
- **Result**: No dedicated security group module (VPC module includes default SG only)
- **Impact**: MEDIUM - Can create inline but dedicated module preferred
- **Workaround Options**:
  - Use public registry module: `terraform-aws-modules/security-group/aws`
  - Create raw aws_security_group resources
  - Define security rules inline within VPC/ALB/ASG configurations
- **Recommended**: Use raw resources with least-privilege rules as defined in constitution

**4. S3 Module**
- **Searched For**: "s3", "bucket"
- **Result**: No private S3 module available
- **Impact**: LOW - Static content storage requirement
- **Workaround Options**:
  - Use public registry module: `terraform-aws-modules/s3-bucket/aws`
  - Create raw aws_s3_bucket resources
  - Host static content within EC2 instances (not scalable)
- **Recommended**: Use raw aws_s3_bucket resource with encryption and versioning enabled

**5. ACM Certificate Module**
- **Searched For**: Implicit (not directly searched)
- **Result**: No private ACM module identified
- **Impact**: MEDIUM - HTTPS requirement (FR-005, FR-010)
- **Workaround Options**:
  - Use public registry module: `terraform-aws-modules/acm/aws`
  - Create raw aws_acm_certificate resource
  - Use existing manually-created certificate
- **Recommended**: Use raw aws_acm_certificate resource with DNS validation

---

## 3. AWS Provider and Version Constraints

### Decision: AWS Provider v5.0+

**Selected Version**: `~> 5.0`

**Rationale**:
- VPC module requires `>= 6.0`
- EC2 instance module requires `>= 4.20`
- Using `~> 5.0` provides compatibility with both modules while allowing patch updates
- AWS Provider 5.x is stable and widely adopted
- Allows for gradual migration to v6.0 when needed

**Terraform Version**: `>= 1.0`
- Both modules compatible with Terraform 1.0+
- HCP Terraform workspace will manage Terraform version separately
- Aligns with organizational standards

**Alternatives Considered**:
- AWS Provider 4.x: Too old, missing newer AWS features
- AWS Provider 6.x: VPC module supports it, but may introduce breaking changes
- Locked specific versions (5.0.0): Too restrictive, prevents security patches

---

## 4. Architectural Patterns and Design Decisions

### Decision: Two-Tier Architecture with Public/Private Subnets

**Architecture**:
```
Internet
    ↓
Internet Gateway
    ↓
Application Load Balancer (Public Subnets in 2 AZs)
    ↓
Auto Scaling Group with EC2 Instances (Private Subnets in 2 AZs)
    ↓
NAT Gateway (for outbound internet access)
    ↓
S3 Bucket (static content)
```

**Rationale**:
- **Public Subnets**: ALB requires public subnets for internet-facing traffic
- **Private Subnets**: EC2 instances in private subnets for security (least privilege)
- **NAT Gateway**: Enables EC2 instances to pull updates/packages from internet
- **2 AZs**: Meets 99.9% uptime requirement (FR-004, SC-001)
- **ALB Health Checks**: Satisfies FR-003 (automatic detection of unhealthy instances)

**VPC Configuration**:
- CIDR: `10.0.0.0/16` (65,536 IPs)
- Public Subnets: `10.0.1.0/24`, `10.0.2.0/24` (2 AZs, 512 IPs total)
- Private Subnets: `10.0.11.0/24`, `10.0.12.0/24` (2 AZs, 512 IPs total)
- Enable NAT Gateway: `true` (one per AZ for HA)
- Enable DNS hostnames: `true`
- Enable DNS support: `true`

**Alternatives Considered**:
- Single-tier architecture (all public): Security risk, violates least privilege
- Three-tier architecture (with database tier): Over-engineering for static content
- Single AZ deployment: Doesn't meet 99.9% uptime requirement
- Single NAT Gateway: Cost savings but single point of failure

---

## 5. Auto Scaling Configuration

### Decision: Target Tracking Scaling Policy Based on CPU

**Auto Scaling Group Configuration**:
- **Min Size**: 2 instances (one per AZ for HA baseline)
- **Max Size**: 6 instances (3x baseline for 200% scaling requirement per SC-004)
- **Desired Capacity**: 2 instances (matches minimum)
- **Health Check Type**: ELB (ALB health checks determine instance health)
- **Health Check Grace Period**: 300 seconds (5 minutes for instance startup)

**Scaling Policy**:
- **Type**: Target Tracking
- **Metric**: Average CPU Utilization
- **Target Value**: 50% CPU utilization
- **Rationale**:
  - Maintains headroom for traffic spikes
  - Balances cost vs performance
  - t3.micro instances have limited CPU (2 vCPU), need aggressive scaling

**Scaling Behavior**:
- **Scale Out**: When avg CPU > 50% for 2 consecutive periods (2 minutes)
- **Scale In**: When avg CPU < 50% for 15 minutes (prevents flapping)
- **Cooldown**: 300 seconds between scaling actions

**Alternatives Considered**:
- Request-based scaling: More accurate but requires ALB integration complexity
- Schedule-based scaling: No predictable traffic patterns specified
- Step scaling: More complex, target tracking simpler for CPU metrics
- Higher CPU target (70%): Less headroom for spikes on t3.micro
- Fixed capacity: Doesn't meet auto-scaling requirement (FR-011)

---

## 6. Application Load Balancer Configuration

### Decision: Internet-Facing ALB with HTTPS Listener

**ALB Configuration**:
- **Type**: Application Load Balancer
- **Scheme**: internet-facing
- **IP Address Type**: ipv4
- **Subnets**: Public subnets in 2 AZs
- **Cross-Zone Load Balancing**: Enabled (even distribution)

**Listeners**:
1. **HTTP Listener (Port 80)**:
   - Action: Redirect to HTTPS (301 permanent redirect)
   - Enforces HTTPS for all traffic

2. **HTTPS Listener (Port 443)**:
   - Protocol: HTTPS
   - SSL Certificate: AWS Certificate Manager (ACM) certificate
   - SSL Policy: `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.2+ minimum)
   - Default Action: Forward to target group

**Target Group**:
- **Protocol**: HTTP (internal communication)
- **Port**: 80
- **Target Type**: instance
- **Health Check**:
  - Protocol: HTTP
  - Path: `/` or `/health` (to be determined)
  - Interval: 30 seconds
  - Timeout: 5 seconds
  - Healthy Threshold: 2 consecutive successes
  - Unhealthy Threshold: 2 consecutive failures
  - Matcher: 200-299 HTTP status codes

**Security**:
- **Deregistration Delay**: 30 seconds (connection draining)
- **Stickiness**: Disabled (stateless application assumed)

**Rationale**:
- Internet-facing required for external user access (User Story 1)
- HTTPS enforces secure connections (FR-005, FR-010)
- HTTP to HTTPS redirect improves user experience
- TLS 1.2+ minimum follows AWS security best practices
- Health checks satisfy FR-003 (detect unhealthy instances)

**Alternatives Considered**:
- Network Load Balancer: Not needed, HTTP/HTTPS traffic fits ALB
- HTTP-only: Violates HTTPS requirement (FR-005)
- Self-signed certificates: Poor user experience, browser warnings
- Classic Load Balancer: Deprecated, lacks modern features

---

## 7. SSL/TLS Certificate Management

### Decision: AWS Certificate Manager (ACM) with DNS Validation

**Configuration**:
- **Certificate Authority**: AWS Certificate Manager (free)
- **Validation Method**: DNS validation (automated)
- **Domain**: User must provide domain name (NEEDS USER INPUT)
- **Subject Alternative Names**: www subdomain + apex domain
- **Auto-Renewal**: Enabled (ACM automatic renewal)

**DNS Configuration Required**:
- User must have control over domain's DNS
- CNAME records for validation will be created
- A record pointing domain to ALB DNS name

**Rationale**:
- ACM certificates are free and auto-renew
- DNS validation is automated once CNAME records added
- No certificate expiration management needed
- Aligns with clarification in spec.md (line 107)

**Alternatives Considered**:
- Email validation: Requires manual intervention every renewal
- Self-signed certificate: Browser warnings, poor UX
- Third-party CA: Additional cost, manual renewal process
- Let's Encrypt: Requires custom automation, ACM is simpler

**User Input Required**:
- Domain name for the web application
- Confirmation of DNS access for validation records

---

## 8. EC2 Instance Configuration

### Decision: Amazon Linux 2023 on t3.micro with User Data Bootstrap

**Instance Specification**:
- **Instance Type**: t3.micro (per spec requirement line 111)
- **AMI**: Amazon Linux 2023 (latest via SSM parameter)
- **AMI SSM Parameter**: `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
- **User Data**: Nginx web server installation and configuration
- **Monitoring**: Basic CloudWatch monitoring (per constitution minimal observability)

**User Data Script**:
```bash
#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx

# Configure simple health check endpoint
echo "OK" > /usr/share/nginx/html/health

# Download static content from S3 (if available)
# aws s3 sync s3://${bucket_name}/ /usr/share/nginx/html/
```

**IAM Instance Profile**:
- **Permissions**: S3 read access to static content bucket
- **Session Manager**: SSM session manager access for secure shell access
- **CloudWatch Logs**: Log streaming permissions (optional)

**EBS Configuration**:
- **Root Volume**: 8 GB gp3 (default)
- **Encryption**: Enabled (AWS-managed KMS key)
- **Delete on Termination**: true

**Metadata Options** (IMDSv2):
- **HTTP Tokens**: required (IMDSv2 only for security)
- **HTTP Put Response Hop Limit**: 1

**Rationale**:
- Amazon Linux 2023 is AWS-optimized, free, receives security updates
- t3.micro meets cost constraint while providing burstable performance
- Nginx is lightweight, stable, suitable for static content
- SSM parameter ensures latest AMI without hardcoding
- IMDSv2 follows AWS security best practices
- IAM instance profile avoids embedded credentials (constitution requirement)

**Alternatives Considered**:
- Ubuntu/Debian: More familiar to some but AL2023 better AWS integration
- Apache httpd: Nginx more performant for static content
- Larger instance type: Violates cost constraint (t3.micro specified)
- Docker/containerized approach: Over-engineering for simple static site
- Hardcoded AMI ID: Becomes outdated, security risk

---

## 9. S3 Static Content Storage

### Decision: S3 Bucket with Encryption and Versioning

**S3 Configuration**:
- **Bucket Name**: `webapp-static-content-${random_id}` (globally unique)
- **Versioning**: Enabled (content change tracking)
- **Encryption**: AES256 (SSE-S3) or AWS KMS (customer managed)
- **Public Access Block**: All public access blocked
- **Bucket Policy**: Allow access from EC2 instance IAM roles only
- **Lifecycle Policy**: Transition old versions to Glacier after 90 days (cost optimization)

**Content Delivery**:
- **Method**: EC2 instances sync from S3 on startup via user data
- **Alternative**: Serve directly from S3 + CloudFront (out of scope per spec line 143)

**Rationale**:
- S3 provides durable storage for static assets
- Encryption at rest meets security requirements
- Versioning allows rollback of content changes
- Private bucket with IAM access follows least privilege
- EC2 sync approach keeps architecture simple

**Alternatives Considered**:
- CloudFront + S3: Better performance but out of scope (line 143)
- EFS: Overkill for static content, higher cost
- Store on EBS: Not shared across instances, deployment complexity
- Public S3 bucket: Security risk, violates least privilege

**User Input Required**:
- Static content files (HTML, CSS, JavaScript, images) location/source
- Content deployment workflow preferences

---

## 10. Security Group Configuration

### Decision: Least-Privilege Security Groups for Each Tier

**ALB Security Group**:
- **Inbound**:
  - Port 80 (HTTP) from 0.0.0.0/0 → Redirect to HTTPS
  - Port 443 (HTTPS) from 0.0.0.0/0 → Accept user traffic
- **Outbound**:
  - Port 80 (HTTP) to EC2 security group → Health checks and forwarding
- **Rationale**: Allows public HTTPS access, restricts outbound to EC2 instances only

**EC2 Security Group**:
- **Inbound**:
  - Port 80 (HTTP) from ALB security group → Accept load balancer traffic only
  - Port 443 (HTTPS) from ALB security group → If needed for internal TLS
- **Outbound**:
  - Port 443 (HTTPS) to 0.0.0.0/0 → S3 API calls, yum updates
  - Port 80 (HTTP) to 0.0.0.0/0 → Package downloads
- **Rationale**: Blocks direct internet access, allows only ALB traffic inbound

**VPC Endpoints (Optional Enhancement)**:
- S3 Gateway Endpoint: Free, keeps S3 traffic within AWS network
- SSM VPC Endpoints: Session Manager access without public internet

**Rationale**:
- Follows constitution least-privilege principle (Section 3.4)
- EC2 instances not directly accessible from internet
- Security groups use source/destination security group references
- Minimizes attack surface

**Alternatives Considered**:
- Single security group: Less granular, harder to audit
- Allow SSH (port 22): Violates security best practice, use SSM instead
- Wider CIDR ranges: Violates least privilege principle

---

## 11. Monitoring and Observability

### Decision: Minimal Monitoring per Specification

**Per Spec Requirement** (line 109, 133):
- Use AWS service health dashboards only
- No custom CloudWatch metrics
- No custom alarms
- No third-party monitoring

**Basic Visibility**:
- **ALB**: Access logs (optional, to S3 bucket)
- **EC2**: Basic CloudWatch metrics (CPU, network, disk)
- **Auto Scaling**: Scaling activity history
- **VPC Flow Logs**: Optional, for network traffic analysis

**Health Checks**:
- ALB target group health checks determine instance health
- Auto Scaling uses ELB health check type
- Unhealthy instances automatically replaced

**Rationale**:
- Specification explicitly defines minimal observability (line 109)
- Constitution allows basic monitoring but not required
- Health dashboard access satisfies FR-008
- Keeps infrastructure simple and cost-effective

**Alternatives Considered**:
- CloudWatch detailed monitoring: Not required per spec
- Custom metrics and alarms: Out of scope (line 144)
- Third-party APM: Out of scope (line 144)

---

## 12. Cost Optimization Strategies

### Decisions for Cost-Effective Deployment

**Instance Sizing**:
- t3.micro mandated by spec (line 111, 124)
- Burstable credits handle occasional spikes
- Auto Scaling adds instances rather than scaling instance size

**NAT Gateway**:
- One NAT Gateway per AZ (2 total) for high availability
- Cost: ~$0.045/hour × 2 × 730 hours = ~$65.70/month
- Alternative: Single NAT Gateway saves 50% but creates single point of failure
- **Decision**: Use 2 NAT Gateways to meet 99.9% uptime goal

**S3**:
- Lifecycle policies move old versions to cheaper storage
- Intelligent-Tiering for unknown access patterns
- Estimated cost: $0.023/GB/month for Standard

**Data Transfer**:
- NAT Gateway data processing: $0.045/GB
- ALB data processing: Included in ALB hourly cost
- Minimize cross-AZ transfer where possible

**Estimated Monthly Cost** (2 AZ, baseline 2 × t3.micro):
- EC2 instances: 2 × $0.0104/hour × 730 = ~$15
- ALB: $0.0225/hour × 730 = ~$16.43
- NAT Gateways: 2 × $0.045/hour × 730 = ~$65.70
- EBS: 2 × 8GB × $0.08/GB = ~$1.28
- S3: Variable based on content size
- ACM Certificate: Free
- **Total**: ~$100-120/month (before data transfer)

**Alternatives Considered**:
- Reserved Instances: Requires 1-year commitment, not suitable for testing
- Spot Instances: Could save 70% but adds complexity (constitution allows)
- Single AZ: Violates HA requirements
- Smaller instance type: t3.micro is smallest viable option

---

## 13. Missing Information / User Input Required

### Critical Decisions Requiring User Input

1. **HCP Terraform Configuration**:
   - ✅ Organization: `hashi-demos-apj` (confirmed)
   - ✅ Project: `hackathon` (prj-hna8wHXsgBrDhHDz) (confirmed)
   - ✅ Workspace name: `webapp-sandbox` (confirmed)

2. **Domain and DNS**:
   - ✅ Domain name: `web.simon-lynch.sbx.hashidemos.io` (confirmed)
   - ✅ DNS hosting: Assumed Route53 (hashidemos.io zone)
   - ❓ Access to create DNS validation records? (Assumed yes for hashidemos.io)

3. **Module Gaps - Public Registry Approval**:
   - ✅ APPROVED: Public registry ALB module (`terraform-aws-modules/alb/aws` ~> 9.0)
   - ✅ APPROVED: Public registry ASG module (`terraform-aws-modules/autoscaling/aws` ~> 7.0)
   - **Note**: User approved per constitution Section 8.3 guidelines for module gaps

4. **Static Content**:
   - ❓ Location of existing static web content (HTML, CSS, JS, images)?
   - ❓ Deployment workflow preferences (manual upload to S3, CI/CD integration)?
   - ❓ Content size estimates (for cost estimation)?

5. **Application Configuration**:
   - ❓ Health check endpoint path (default to `/` or custom `/health`)?
   - ❓ Any custom Nginx configuration needed?
   - ❓ Custom headers or security headers requirements?

6. **Network Configuration**:
   - ❓ VPC CIDR block preference (default 10.0.0.0/16 or custom)?
   - ❓ Specific subnet CIDR requirements?
   - ❓ VPC Flow Logs needed for compliance? (adds cost)

7. **Access and Security**:
   - ❓ Who needs access to EC2 instances via Session Manager?
   - ❓ Any IP whitelisting requirements for admin access?
   - ❓ Specific compliance requirements (PCI-DSS, HIPAA, etc.)?

---

## 14. Constitution Compliance Summary

### Alignment with Organizational Principles

**✅ Module-First Architecture (1.1)**:
- Using private VPC module: `hashi-demos-apj/vpc/aws`
- Using private EC2 instance module: `hashi-demos-apj/ec2-instance/aws`
- **Gap**: ALB and ASG modules not in private registry → Requires user approval for public modules

**✅ Specification-Driven Development (1.2)**:
- Detailed feature spec exists with requirements, acceptance criteria
- Research findings documented here
- No code generation until specification approved

**✅ Security-First Automation (1.3)**:
- No static credentials in configuration
- HTTPS enforced via ACM
- IMDSv2 required for EC2 metadata
- Private subnets for EC2 instances
- Security groups follow least privilege

**✅ HCP Terraform Prerequisites (Section II)**:
- Organization identified: `hashi-demos-apj`
- Project and workspace names pending user confirmation

**✅ Git Branch Strategy (3.1)**:
- Current branch: `001-ec2-alb-webapp` (feature branch)
- Will merge to `dev` → `staging` → `main`
- Each branch maps to HCP Terraform workspace

**✅ Security Best Practices (Section IV)**:
- Encryption at rest: EBS volumes, S3 buckets
- Encryption in transit: HTTPS/TLS 1.2+
- No hardcoded credentials
- IAM instance profiles for AWS API access
- Least privilege security groups

**✅ Testing Framework (Section X)**:
- Plan includes ephemeral workspace testing
- Auto-apply and auto-destroy after 2 hours
- Variables will be defined and tested before promotion

**⚠️ Module Coverage Gap**:
- Private registry lacks ALB and ASG modules
- Options:
  1. Request platform team to publish modules (delays project)
  2. Use public registry with approval (faster, constitution-compliant with approval)
  3. Create raw resources (violates Module-First principle)
- **Recommendation**: Option 2 - seek approval for public modules

---

## 15. Next Steps and Recommendations

### Immediate Actions Required

1. **User Confirmations**:
   - Confirm HCP Terraform project and workspace names
   - Provide domain name for ACM certificate
   - Approve public registry module usage for ALB and ASG
   - Confirm static content source and deployment approach

2. **Module Decision**:
   - If public modules approved:
     - Use `terraform-aws-modules/alb/aws` (latest stable version)
     - Use `terraform-aws-modules/autoscaling/aws` (latest stable version)
     - Document version constraints in terraform.tf
   - If public modules rejected:
     - Work with platform team to publish required modules
     - Timeline impact: 1-2 weeks delay estimated

3. **Proceed to Phase 1**:
   - Generate data-model.md (infrastructure entities)
   - Generate contracts/ (API/configuration contracts)
   - Generate quickstart.md (deployment guide)
   - Update agent context

4. **After Phase 1**:
   - Run `/speckit.tasks` to generate implementation tasks
   - Generate Terraform code
   - Test in ephemeral HCP Terraform workspace
   - Deploy to dev workspace upon successful testing

---

## Conclusion

Research phase successfully identified:
- ✅ HCP Terraform organization: `hashi-demos-apj`
- ✅ Available private modules: VPC (v6.5.0), EC2 Instance (v5.0.0)
- ❌ Missing private modules: ALB, ASG, Security Group, S3, ACM
- ✅ Architecture pattern: Two-tier with public/private subnets across 2 AZs
- ✅ AWS provider version: ~> 5.0
- ✅ Cost estimate: ~$100-120/month baseline

**Primary blocker**: Module gaps require user approval to use public Terraform registry modules.

**Recommendation**: Proceed with public registry modules for ALB and ASG with explicit version constraints, document in code comments per constitution requirements.
