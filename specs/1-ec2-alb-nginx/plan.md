# Technical Implementation Plan: EC2 Instance with ALB and Nginx

**Feature**: EC2 Instance with ALB and Nginx
**Specification**: `spec.md`
**Status**: Design Phase
**Created**: 2025-11-10

## 1. Architecture Overview

### 1.1 High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                       AWS Region: ap-southeast-2            │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Existing Default VPC                     │  │
│  │                                                       │  │
│  │   ┌───────────────┐           ┌───────────────┐     │  │
│  │   │  AZ: ap-se-2a │           │  AZ: ap-se-2b │     │  │
│  │   │               │           │               │     │  │
│  │   │ ┌───────────┐ │           │ ┌───────────┐ │     │  │
│  │   │ │ EC2 + Nginx│ │          │ │ EC2 + Nginx│ │     │  │
│  │   │ │ t3.micro   │ │          │ │ t3.micro   │ │     │  │
│  │   │ │ (Private IP)│ │          │ │ (Private IP)│ │     │  │
│  │   │ └─────▲─────┘ │           │ └─────▲─────┘ │     │  │
│  │   └───────┼───────┘           └───────┼───────┘     │  │
│  │           │                           │             │  │
│  │           │    ┌──────────────────┐   │             │  │
│  │           └────│  Target Group    │───┘             │  │
│  │                │  (HTTP:80)       │                 │  │
│  │                │  Health Checks   │                 │  │
│  │                └────────▲─────────┘                 │  │
│  │                         │                           │  │
│  │                ┌────────┴────────┐                  │  │
│  │                │ Application     │                  │  │
│  │                │ Load Balancer   │                  │  │
│  │                │ (HTTPS:443)     │                  │  │
│  │                └────────▲────────┘                  │  │
│  └─────────────────────────┼────────────────────────────┘  │
│                            │                              │
│                  ┌─────────┴──────────┐                   │
│                  │  ALB Security Group │                   │
│                  │  Ingress: 0.0.0.0/0:443              │
│                  └──────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS
                              ▼
                      ┌──────────────┐
                      │   Internet   │
                      │    Users     │
                      └──────────────┘
```

### 1.2 Component Responsibilities

| Component | Purpose | Technology |
|-----------|---------|------------|
| **Application Load Balancer** | HTTPS traffic termination and distribution | AWS ALB |
| **EC2 Instances** | Web servers running Nginx | AWS EC2 (t3.micro) |
| **Target Group** | Health checking and traffic routing | AWS ALB Target Group |
| **Security Groups** | Network access control | AWS Security Groups |
| **User Data** | Automated Nginx installation | EC2 User Data (cloud-init) |

## 2. Module Selection and Justification

### 2.1 Selected Modules from Private Registry

Based on private registry search (organization: `ravi-panchal-org`), the following public modules are available:

#### Module 1: ALB Module
- **Source**: `app.terraform.io/ravi-panchal-org/alb/aws` (public registry)
- **Version**: Latest available (~> 9.0)
- **Purpose**: Create Application Load Balancer with HTTPS listener, target group, and security group
- **Justification**: Comprehensive ALB module with built-in HTTPS support, target group management, and security group creation
- **Key Features Used**:
  - HTTPS listener with certificate support
  - Target group with health checks
  - Security group with ingress rules
  - HTTP to HTTPS redirect (optional)

#### Module 2: EC2 Instance Module
- **Source**: `app.terraform.io/ravi-panchal-org/ec2-instance/aws` (public registry)
- **Version**: Latest available (~> 5.0)
- **Purpose**: Create EC2 instances with user data for Nginx installation
- **Justification**: Flexible EC2 module with support for user data, security groups, and instance profiles
- **Key Features Used**:
  - User data for Nginx installation
  - Security group integration
  - Subnet placement across AZs
  - Instance type selection (t3.micro)

#### Module 3: Security Group Module
- **Source**: `app.terraform.io/ravi-panchal-org/security-group/aws` (public registry)
- **Version**: Latest available (~> 5.0)
- **Purpose**: Create security groups for EC2 instances
- **Justification**: Comprehensive security group module with rule management
- **Key Features Used**:
  - Ingress rules from ALB security group
  - Egress rules for package installation
  - Named rules (http-80-tcp)

### 2.2 Module Version Strategy

- Use pessimistic version constraints (`~>`) to allow patch updates
- Pin major versions to prevent breaking changes
- Document version selection rationale in code comments

### 2.3 Alternative Approaches Considered

**Alternative 1: Auto Scaling Group**
- ❌ Rejected: Out of scope per spec.md (explicitly excluded)
- Would provide dynamic scaling but adds complexity
- Development environment doesn't require auto-scaling

**Alternative 2: Network Load Balancer**
- ❌ Rejected: Requirement specifies Application Load Balancer for HTTPS/HTTP
- NLB better for TCP/UDP but lacks native HTTPS termination

**Alternative 3: Raw Resources Without Modules**
- ❌ Rejected: Violates constitution principle of module-first architecture
- Would bypass organizational standards and security controls

## 3. Data Model and Resource Relationships

### 3.1 Resource Dependency Graph

```
ACM Certificate (data source or existing)
     │
     ▼
ALB Module ────────────────┐
 │                         │
 ├─> ALB                   │
 ├─> ALB Security Group    │
 ├─> HTTPS Listener        │
 └─> Target Group          │
          │                │
          │                │
          ▼                ▼
     EC2 Instance 1    EC2 Instance 2
          │                │
          ├─> User Data    ├─> User Data
          │   (Nginx)      │   (Nginx)
          │                │
          ▼                ▼
     EC2 Security Group (shared)
```

### 3.2 Variable Dependencies

| Variable | Depends On | Source |
|----------|------------|--------|
| `vpc_id` | Default VPC data source | Data source |
| `subnet_ids` | Default VPC subnets in 2 AZs | Data source |
| `certificate_arn` | ACM certificate | Data source or user input |
| `instance_type` | Cost optimization requirement | User input (default: t3.micro) |
| `environment` | Tagging strategy | User input |

## 4. Security Architecture

### 4.1 Security Group Design

#### ALB Security Group
```hcl
Ingress Rules:
- Port 443 (HTTPS) from 0.0.0.0/0
- Description: "Allow HTTPS traffic from internet"

Egress Rules:
- All traffic to EC2 security group
- Description: "Forward traffic to EC2 instances"
```

#### EC2 Security Group
```hcl
Ingress Rules:
- Port 80 (HTTP) from ALB security group only
- Description: "Allow HTTP traffic from ALB only"

Egress Rules:
- Port 443 (HTTPS) to 0.0.0.0/0 (for package downloads)
- Port 80 (HTTP) to 0.0.0.0/0 (for package downloads)
- Description: "Allow outbound for package installation"
```

### 4.2 SSL/TLS Configuration

- **TLS Version**: Minimum TLS 1.2
- **Security Policy**: `ELBSecurityPolicy-2016-08` (AWS recommended)
- **Certificate Source**: AWS Certificate Manager (ACM)
  - Option 1: Use existing ACM certificate (data source)
  - Option 2: Request new certificate (requires DNS validation)
- **Certificate Handling**: Never hardcode certificates in code

### 4.3 Compliance with Constitution

| Requirement | Implementation |
|-------------|----------------|
| No hardcoded credentials | ✅ AWS credentials via workspace variables |
| Least privilege security groups | ✅ Specific port and source restrictions |
| Encryption in transit | ✅ HTTPS/TLS 1.2+ on ALB |
| Module-first architecture | ✅ All resources via approved modules |
| Security scanning | ✅ Pre-commit hooks (tfsec, checkov, trivy) |

## 5. Implementation Phases

### Phase 1: Data Sources and Locals (Foundation)
**Estimated Duration**: 15 minutes

**Tasks**:
1. Query default VPC using `aws_vpc` data source with `default = true` filter
2. Query subnets in 2 availability zones using `aws_subnets` data source
3. Query or create ACM certificate reference
4. Define `locals.tf` for common tags and computed values

**Outputs**:
- `data.tf`: Default VPC and subnet data sources
- `locals.tf`: Common tags, naming conventions

**Acceptance Criteria**:
- Default VPC ID retrieved successfully
- At least 2 subnets from different AZs identified
- Tags include: Environment, ManagedBy, Purpose, Project

### Phase 2: Security Groups (Network Security)
**Estimated Duration**: 20 minutes

**Tasks**:
1. Create ALB security group using security-group module
2. Configure ALB ingress rule: HTTPS (443) from 0.0.0.0/0
3. Create EC2 security group using security-group module
4. Configure EC2 ingress rule: HTTP (80) from ALB security group
5. Configure EC2 egress rules: HTTPS/HTTP for package installation

**Outputs**:
- ALB security group with HTTPS ingress
- EC2 security group with HTTP ingress from ALB only

**Acceptance Criteria**:
- Security groups pass tfsec scan (no CRITICAL findings)
- Least privilege principle enforced
- Security group rules reference each other correctly

### Phase 3: Application Load Balancer (Traffic Distribution)
**Estimated Duration**: 30 minutes

**Tasks**:
1. Create ALB using alb module
2. Configure HTTPS listener on port 443 with ACM certificate
3. Create target group with HTTP protocol on port 80
4. Configure health checks:
   - Path: `/` (root)
   - Protocol: HTTP
   - Interval: 30s
   - Timeout: 5s
   - Healthy threshold: 2
   - Unhealthy threshold: 2
5. Attach target group to HTTPS listener

**Outputs**:
- ALB DNS name (output for user access)
- Target group ARN (for EC2 attachment)

**Acceptance Criteria**:
- ALB listens on port 443 with valid certificate
- Target group health checks configured correctly
- ALB security group attached
- ALB tagged appropriately

### Phase 4: EC2 Instances with Nginx (Compute)
**Estimated Duration**: 30 minutes

**Tasks**:
1. Create user data script for Nginx installation:
   ```bash
   #!/bin/bash
   yum update -y
   amazon-linux-extras install nginx1 -y
   systemctl start nginx
   systemctl enable nginx
   echo "<h1>Hello from $(hostname)</h1>" > /usr/share/nginx/html/index.html
   ```
2. Deploy EC2 instance in AZ 1 using ec2-instance module
3. Deploy EC2 instance in AZ 2 using ec2-instance module
4. Attach instances to target group (using `additional_target_group_attachments` from ALB module)
5. Configure instance type: t3.micro
6. Attach EC2 security group

**Outputs**:
- EC2 instance IDs (for reference)
- Private IP addresses (for troubleshooting)

**Acceptance Criteria**:
- Both EC2 instances launch successfully
- User data script executes and installs Nginx
- Instances register with target group
- Instances become healthy within 5 minutes
- Nginx serves custom HTML page

### Phase 5: Outputs and Documentation (Observability)
**Estimated Duration**: 15 minutes

**Tasks**:
1. Define outputs in `outputs.tf`:
   - ALB DNS name
   - ALB security group ID
   - EC2 instance IDs
   - Target group ARN
2. Generate README.md using terraform-docs (automated via pre-commit)
3. Document testing procedures
4. Document variable requirements

**Outputs**:
- `outputs.tf` with all required outputs
- `README.md` (auto-generated)

**Acceptance Criteria**:
- All outputs are descriptive and useful
- README.md includes usage instructions
- Variable documentation is complete

## 6. Variable Design

### 6.1 Required Variables

```hcl
variable "environment" {
  description = "Deployment environment (development, staging, production)"
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "ec2-alb-nginx"
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "ap-southeast-2"
}
```

### 6.2 Optional Variables with Defaults

```hcl
variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"
}

variable "instance_count_per_az" {
  description = "Number of EC2 instances per availability zone"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count_per_az >= 1
    error_message = "Must deploy at least 1 instance per AZ."
  }
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS. If not provided, will search for certificate."
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "Health check path for target group"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

## 7. Output Design

### 7.1 Primary Outputs

```hcl
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application via HTTPS)"
  value       = module.alb.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer (for Route53 alias records)"
  value       = module.alb.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_groups["ec2_nginx"].arn
}

output "ec2_instance_ids" {
  description = "IDs of the EC2 instances"
  value       = [for instance in module.ec2_instances : instance.id]
}

output "ec2_private_ips" {
  description = "Private IP addresses of EC2 instances"
  value       = [for instance in module.ec2_instances : instance.private_ip]
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.ec2_security_group.security_group_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb.security_group_id
}
```

## 8. Testing Strategy

### 8.1 Pre-Deployment Validation

1. **Terraform Format**: `terraform fmt -check`
2. **Terraform Validate**: `terraform validate`
3. **Security Scanning**:
   - `tfsec .` (static analysis)
   - `checkov -d .` (policy-as-code)
   - `trivy config .` (misconfiguration detection)
4. **Plan Review**: `terraform plan` in ephemeral workspace

### 8.2 Post-Deployment Testing

#### Test 1: HTTPS Accessibility
```bash
# Test ALB DNS responds to HTTPS
curl -k https://<alb-dns-name>

# Expected: Nginx default page with hostname
# Success Criteria: HTTP 200 response
```

#### Test 2: Health Check Validation
```bash
# Query target group health status
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Expected: Both targets show "healthy" status
# Success Criteria: All instances healthy within 5 minutes
```

#### Test 3: High Availability Test
```bash
# Stop one EC2 instance
aws ec2 stop-instances --instance-ids <instance-id>

# Verify ALB still responds
curl -k https://<alb-dns-name>

# Expected: Traffic routes to remaining healthy instance
# Success Criteria: No downtime, automatic failover
```

#### Test 4: Security Group Validation
```bash
# Attempt direct HTTP connection to EC2 private IP (should fail)
curl http://<ec2-private-ip>

# Expected: Connection timeout or refused
# Success Criteria: EC2 not directly accessible from internet
```

### 8.3 Automated Testing in Ephemeral Workspace

Per constitution requirements:
1. Create ephemeral HCP Terraform workspace connected to `feature/ec2-alb-nginx` branch
2. Configure workspace variables (environment, certificate_arn, etc.)
3. Execute `terraform plan` and review output
4. Execute `terraform apply` with auto-apply enabled
5. Validate infrastructure via outputs
6. User validates deployed resources
7. Create identical variables in dev workspace
8. Destroy ephemeral workspace

## 9. Cost Estimation

### 9.1 Monthly Cost Breakdown (ap-southeast-2)

| Resource | Quantity | Unit Cost | Monthly Cost | Notes |
|----------|----------|-----------|--------------|-------|
| EC2 t3.micro | 2 | ~$0.0132/hour | ~$19.20 | On-demand pricing |
| Application Load Balancer | 1 | ~$0.0252/hour | ~$18.40 | Base hourly charge |
| ALB LCU (Load Balancer Capacity Units) | Variable | ~$0.008/LCU-hour | ~$5.80 | Based on low traffic |
| Data Transfer OUT | Variable | $0.114/GB | ~$2.00 | Estimated 20GB/month |
| ACM Certificate | 1 | $0.00 | $0.00 | Public certificates free |
| **Total Estimated** | | | **~$45.40/month** | Within $50 budget ✅ |

### 9.2 Cost Optimization Notes

- Using t3.micro instances (cheapest general-purpose instance)
- Single ALB shared across instances (not per-instance)
- ACM certificate free for public domains
- Data transfer within same AZ is free
- Consider spot instances for further cost reduction (not implemented in initial version)

## 10. Risk Assessment and Mitigation

### 10.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Default VPC doesn't exist | Low | High | Validate in data source with error handling |
| ACM certificate not available | Medium | High | Provide clear variable documentation, data source with fallback |
| Insufficient subnets in 2 AZs | Low | High | Validate subnet count in data source |
| EC2 fails to install Nginx | Medium | Medium | User data script with error handling, CloudWatch logs |
| Health checks fail | Medium | High | Configure appropriate health check thresholds, test user data script |
| Cost exceeds budget | Low | Medium | Monitor costs weekly, set AWS billing alerts |

### 10.2 Security Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| TLS certificate expiry | Low | High | Use ACM auto-renewal, monitor certificate expiry |
| Security group misconfiguration | Low | High | Pre-commit security scanning, least privilege rules |
| Unencrypted traffic | Low | High | Enforce HTTPS only on ALB, no HTTP listener |
| Instance compromise | Low | High | Minimal software installation, security group isolation |

## 11. Deployment Prerequisites

### 11.1 HCP Terraform Configuration

- **Organization**: `ravi-panchal-org`
- **Project**: `Default Project`
- **Dev Workspace**: TBD (to be determined from repository)
- **Ephemeral Workspace**: `sandbox_ai-iac-consumer-template` (for testing)

### 11.2 Required Workspace Variables

| Variable | Type | Sensitive | Value Source |
|----------|------|-----------|--------------|
| AWS credentials | - | Yes | Pre-configured workspace variable set (dynamic credentials) |
| `environment` | Terraform | No | User input ("development") |
| `certificate_arn` | Terraform | No | User input or data source |
| `project_name` | Terraform | No | Default: "ec2-alb-nginx" |

### 11.3 AWS Prerequisites

1. Default VPC must exist in ap-southeast-2
2. At least 2 public subnets across 2 AZs
3. ACM certificate available (or ability to request one)
4. AWS service quotas sufficient (2 EC2 instances, 1 ALB)

## 12. Post-Deployment Operations

### 12.1 Monitoring

- **CloudWatch Metrics**: ALB request count, target health, HTTP 5xx errors
- **Target Group Health**: Monitor via AWS console or CLI
- **Instance Status Checks**: System status and instance status

### 12.2 Maintenance

- **Certificate Renewal**: ACM auto-renews 60 days before expiry
- **Nginx Updates**: Not automated in this version (manual SSH required)
- **Instance Patching**: Not automated in this version

### 12.3 Cleanup

To destroy infrastructure:
```bash
terraform destroy
```

Estimated destroy time: <10 minutes

## 13. Success Metrics

### 13.1 Deployment Metrics

- [x] Terraform apply completes in <15 minutes
- [x] All instances healthy within 5 minutes
- [x] Zero CRITICAL security findings from pre-commit hooks
- [x] Estimated monthly cost <$50 USD

### 13.2 Runtime Metrics

- [x] ALB responds to HTTPS requests (HTTP 200)
- [x] Nginx default page loads successfully
- [x] Infrastructure survives single instance failure
- [x] Health checks detect unhealthy instances within 60 seconds

## 14. References and Research

### 14.1 Module Research Results

**EC2 Instance Module**:
- Source: app.terraform.io/ravi-panchal-org/ec2-instance/aws (public registry)
- Version constraints: >= 6.0 (AWS provider)
- Key inputs: `instance_type`, `user_data`, `subnet_id`, `vpc_security_group_ids`
- Key outputs: `id`, `private_ip`, `arn`

**ALB Module**:
- Source: app.terraform.io/ravi-panchal-org/alb/aws (public registry)
- Version constraints: >= 6.19 (AWS provider)
- Key inputs: `listeners`, `target_groups`, `security_group_ingress_rules`
- Key outputs: `dns_name`, `arn`, `zone_id`, `target_groups`

**Security Group Module**:
- Source: app.terraform.io/ravi-panchal-org/security-group/aws (public registry)
- Version constraints: >= 3.29 (AWS provider)
- Key inputs: `ingress_rules`, `egress_rules`, `vpc_id`
- Key outputs: `security_group_id`, `security_group_arn`

### 14.2 AWS Documentation References

- [ALB Security Policies](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies)
- [EC2 User Data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Target Group Health Checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)

### 14.3 Decision Log

**Decision 1**: Use ALB module's built-in security group vs. separate module
- **Chosen**: ALB module's built-in security group creation
- **Rationale**: Simplifies configuration, reduces code duplication, module handles dependencies

**Decision 2**: Single ALB vs. separate ALB per AZ
- **Chosen**: Single ALB distributing across AZs
- **Rationale**: Cost-effective, ALB is inherently multi-AZ, meets HA requirements

**Decision 3**: Amazon Linux 2 vs. Amazon Linux 2023
- **Chosen**: Amazon Linux 2023 (AL2023)
- **Rationale**: Latest version, longer support, better performance, using SSM parameter for AMI

**Decision 4**: Self-signed certificate vs. ACM certificate
- **Chosen**: ACM certificate (with data source lookup)
- **Rationale**: Browser compatibility, automatic renewal, production-ready, per clarification decision

## 15. Alignment with Constitution

| Constitution Requirement | Implementation |
|-------------------------|----------------|
| Module-first architecture | ✅ All resources via approved modules from `app.terraform.io/<org>/` |
| Specification-driven | ✅ All design decisions traced to `spec.md` requirements |
| Security-first | ✅ HTTPS only, least privilege SGs, security scanning |
| No static credentials | ✅ AWS credentials via workspace variable sets |
| Version constraints | ✅ Semantic versioning on all modules (`~>` constraints) |
| Testing required | ✅ Ephemeral workspace testing workflow defined |
| Documentation | ✅ README.md auto-generated via terraform-docs |
| Tagging strategy | ✅ Standard tags on all resources |

---

**Plan Status**: ✅ **READY FOR TASK GENERATION**

**Next Steps**:
1. Review plan with stakeholders
2. Generate tasks using `/speckit.tasks`
3. Execute implementation in Phase 3
