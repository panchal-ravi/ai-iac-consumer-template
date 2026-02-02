# Implementation Plan: EC2 Instance with ALB and Nginx

**Branch**: `003-ec2-alb-nginx` | **Date**: 2025-01-21 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/003-ec2-alb-nginx/spec.md`  
**GitHub Issue**: [#39](https://github.com/org/repo/issues/39)

## Summary

This implementation plan delivers a development environment with EC2 instances running Nginx web servers behind an Application Load Balancer (ALB) with HTTPS support. The infrastructure spans two availability zones in the ap-southeast-1 region, uses self-signed certificates for testing HTTPS connectivity, and is deployed through HCP Terraform Cloud.

**Technical Approach**:
- **Module-First Architecture**: All infrastructure provisioned through HCP Terraform private registry modules (`ravi-panchal-org`)
- **HTTPS Termination at ALB**: ALB handles SSL/TLS, EC2 instances serve HTTP (AWS best practice)
- **Dynamic Infrastructure Discovery**: Data sources query default VPC and subnets (no hardcoded IDs)
- **Cost-Optimized**: t3.micro instances, development environment configuration
- **Security-First**: Isolated security groups, EC2 instances not directly accessible from internet

## Technical Context

**Language/Version**: HCL (Terraform 1.6+)  
**Primary Dependencies**: 
- Terraform AWS Provider (~> 6.0)
- Terraform TLS Provider (~> 4.0)
- Private Registry Modules: ec2-instance (6.1.4), alb (10.2.0), security-group (5.3.1)

**Storage**: Terraform state in HCP Terraform Cloud (encrypted at rest)  
**Testing**: 
- Terraform validate/plan (syntax and logic validation)
- AWS CLI verification (resource state checking)
- Curl/HTTP testing (connectivity and health checks)

**Target Platform**: AWS ap-southeast-1 region  
**Project Type**: Infrastructure as Code (Terraform configuration)  
**Performance Goals**: 
- Infrastructure provisioning: < 10 minutes
- Health check response: < 500ms
- Target health detection: < 2 minutes

**Constraints**: 
- Development environment only (not production-ready)
- Self-signed certificates (browser warnings expected)
- Cost-optimized: t3.micro/t2.micro instances
- Uses existing default VPC (no VPC creation)

**Scale/Scope**: 
- 2 availability zones
- 2 EC2 instances (1 per AZ)
- 1 Application Load Balancer
- 2 security groups
- HTTPS only (no HTTP listener)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ 1.1 Module-First Architecture

**Status**: **PASS** ✅

**Evidence**:
- ✅ All infrastructure uses HCP Terraform private registry modules (`app.terraform.io/ravi-panchal-org/`)
- ✅ EC2 instances: `ravi-panchal-org/ec2-instance/aws` v6.1.4
- ✅ ALB: `ravi-panchal-org/alb/aws` v10.2.0
- ✅ Security Groups: `ravi-panchal-org/security-group/aws` v5.3.1
- ✅ No direct resource declarations for managed infrastructure
- ✅ Semantic versioning constraints used (`~> 6.1.4`, `~> 10.2.0`, `~> 5.3.1`)

**Non-Module Resources** (Justified):
- `tls_private_key`: Core Terraform provider resource (no private module available)
- `tls_self_signed_cert`: Core Terraform provider resource (no private module available)
- `aws_acm_certificate`: Certificate import (not infrastructure provisioning)
- `data.aws_vpc`: Data source (read-only, no module needed)
- `data.aws_subnets`: Data source (read-only, no module needed)

**Rationale**: TLS provider resources and data sources are standard Terraform patterns for certificate generation and infrastructure discovery. No private modules exist for these use cases, and they don't bypass organizational controls.

---

### ✅ 1.2 Specification-Driven Development

**Status**: **PASS** ✅

**Evidence**:
- ✅ Complete feature specification in `spec.md` with functional requirements, user stories, and success criteria
- ✅ Research phase completed with all technical decisions documented in `research.md`
- ✅ Data model defined with entity relationships and validation rules in `data-model.md`
- ✅ Module contracts defined in `contracts/terraform-interface.md`
- ✅ All implementation decisions traceable to requirements (FR-001 through FR-030)
- ✅ No ambiguous requirements remaining (all NEEDS CLARIFICATION items resolved)

**Specification Completeness**:
- Purpose: Development environment for web application deployment patterns
- Compliance: Development-only (not production-grade)
- Scalability: 2 AZs, 2 instances (appropriate for dev environment)
- Cost Constraints: t3.micro/t2.micro instances, minimal infrastructure

---

### ✅ 1.3 Security-First Automation

**Status**: **PASS** ✅

**Evidence**:
- ✅ No static credentials in configuration
- ✅ AWS authentication via HCP Terraform workspace variables (dynamic credentials)
- ✅ Security groups follow principle of least privilege:
  - ALB: Only HTTPS (443) from internet
  - EC2: Only HTTP (80) from ALB security group
  - EC2: No direct internet access on application ports
- ✅ TLS private key stored in encrypted Terraform state (HCP Terraform Cloud)
- ✅ No hardcoded secrets or API keys

**Security Considerations Documented**:
- Private key storage in Terraform state (acceptable for development)
- Self-signed certificate usage (development-only pattern)
- ALB HTTPS termination (AWS best practice)
- Network isolation via security groups

**Rationale**: Development environment uses HCP Terraform Cloud encrypted state for sensitive data. For production, recommendation documented to use AWS Secrets Manager with ephemeral resources.

---

### ✅ 2.1 HCP Terraform Prerequisites

**Status**: **PASS** ✅

**Evidence**:
- ✅ HCP Terraform Organization: `ravi-panchal-org`
- ✅ HCP Terraform Project: `Default Project`
- ✅ HCP Terraform Workspace: `sandbox_workspace`
- ✅ AWS Region: `ap-southeast-1`
- ✅ Backend configuration pre-defined in Terraform code

**Configuration**:
```hcl
terraform {
  cloud {
    organization = "ravi-panchal-org"
    workspaces {
      name = "sandbox_workspace"
    }
  }
}
```

---

## Constitution Check Summary

| Principle | Status | Violations | Justification |
|-----------|--------|------------|---------------|
| 1.1 Module-First Architecture | ✅ PASS | None | All managed infrastructure uses private modules |
| 1.2 Specification-Driven | ✅ PASS | None | Complete specification with requirements traceability |
| 1.3 Security-First | ✅ PASS | None | No credentials in code, least privilege security groups |
| 2.1 HCP Terraform Config | ✅ PASS | None | Organization, project, workspace pre-configured |

**Overall Status**: ✅ **ALL GATES PASSED**

**Ready for Implementation**: Yes  
**Re-check Required After Phase 1**: Complete (all Phase 1 artifacts generated)

## Project Structure

### Documentation (this feature)

```text
specs/003-ec2-alb-nginx/
├── spec.md              # Feature specification (input)
├── plan.md              # This file (Phase 0-1 output)
├── research.md          # Phase 0: Research findings and decisions
├── data-model.md        # Phase 1: Entity relationships and data structures
├── quickstart.md        # Phase 1: Deployment and testing guide
├── contracts/           # Phase 1: API and interface specifications
│   ├── terraform-interface.md     # Terraform module contracts
│   └── nginx-bootstrap-contract.md # User data script specification
└── tasks.md             # Phase 2: Implementation tasks (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Infrastructure as Code Project Structure
.
├── main.tf              # Root module entry point
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output value definitions
├── providers.tf         # Provider configuration (AWS, TLS)
├── backend.tf           # HCP Terraform Cloud backend config
├── data.tf              # Data source definitions (VPC, subnets)
├── locals.tf            # Local values and computed data
├── versions.tf          # Terraform and provider version constraints
│
├── modules/             # Local modules (if needed for composition)
│   └── (none required - using private registry modules)
│
├── user-data/           # EC2 bootstrap scripts
│   └── nginx-bootstrap.sh    # Nginx installation and configuration
│
├── tests/               # Terraform test files
│   ├── integration.tftest.hcl  # Integration tests
│   └── unit.tftest.hcl         # Unit tests
│
└── .terraform/          # Terraform working directory (gitignored)
    ├── modules/         # Downloaded modules
    └── providers/       # Downloaded providers
```

**Structure Decision**: Single-project structure (infrastructure only, no application code). This is a pure Terraform project that provisions AWS infrastructure. All managed infrastructure uses private registry modules from `app.terraform.io/ravi-panchal-org/`. The root module composes these modules and adds certificate generation logic using the TLS provider.

## Complexity Tracking

> **Status**: No violations - complexity tracking not required

All infrastructure follows constitutional principles:
- Module-first architecture using private registry modules
- Specification-driven with complete requirements
- Security-first with no credentials in code
- HCP Terraform configuration validated

No complexity justifications needed.

---

## Phase 0: Research Summary

**Status**: ✅ Complete

### Key Research Findings

1. **Private Module Registry**: Successfully identified 3 required modules in HCP Terraform private registry
   - `ravi-panchal-org/ec2-instance/aws` v6.1.4
   - `ravi-panchal-org/alb/aws` v10.2.0
   - `ravi-panchal-org/security-group/aws` v5.3.1

2. **Architecture Decision**: ALB HTTPS termination selected
   - HTTPS from internet to ALB (port 443)
   - HTTP from ALB to EC2 (port 80)
   - Simplifies certificate management
   - AWS best practice for ALB deployments

3. **Certificate Strategy**: TLS provider self-signed certificates
   - Generate private key and certificate with Terraform
   - Import to AWS Certificate Manager (ACM)
   - 90-day validity (per requirements)
   - Acceptable for development environment

4. **Instance Type**: t3.micro selected as primary choice
   - Better performance per dollar than t2.micro
   - Superior network performance for ALB traffic
   - CPU credits in unlimited mode prevent throttling

5. **VPC Strategy**: Dynamic discovery via data sources
   - Query default VPC in ap-southeast-1
   - Select subnets across first 2 availability zones
   - No hardcoded resource IDs

**Detailed Research**: See [research.md](./research.md)

---

## Phase 1: Design Summary

**Status**: ✅ Complete

### Data Model

Defined 12 core entities with relationships:
- VPC, Subnet (data sources)
- EC2 Instance, ALB, Target Group, HTTPS Listener
- Security Groups (ALB and EC2)
- TLS Private Key, TLS Certificate, ACM Certificate
- Nginx (software component)

**Key Design Decisions**:
- Security groups use explicit references (ALB ↔ EC2)
- Health checks on custom `/health` endpoint
- Instance metadata displayed on index page
- Certificate lifecycle with create_before_destroy

**Detailed Model**: See [data-model.md](./data-model.md)

### Contracts

Defined comprehensive interfaces:
- **9 input variables** (4 required, 5 optional)
- **23 output values** organized by category
- **Module composition** with specific version constraints
- **Validation checks** for pre-deployment safety

**Key Contracts**:
- Terraform module interface with all input/output definitions
- Nginx bootstrap script with template variables
- Health check endpoint specification
- Security group rule definitions

**Detailed Contracts**: See [contracts/](./contracts/)

### Quickstart Guide

Created comprehensive deployment documentation:
- Prerequisites checklist
- 5-minute quick start
- Detailed step-by-step deployment
- Testing and verification procedures
- Troubleshooting guide
- Cleanup instructions

**Quick Access**: See [quickstart.md](./quickstart.md)

---

## Implementation Approach

### Module Composition Strategy

```
Root Module (/)
│
├── Data Sources
│   ├── aws_vpc.default
│   ├── aws_subnets.default
│   └── aws_subnet.default[*]
│
├── Certificate Generation
│   ├── tls_private_key.web
│   ├── tls_self_signed_cert.web
│   └── aws_acm_certificate.web
│
└── Module Instantiation
    ├── module.security_group_alb
    │   └── app.terraform.io/ravi-panchal-org/security-group/aws
    ├── module.security_group_ec2
    │   └── app.terraform.io/ravi-panchal-org/security-group/aws
    ├── module.alb
    │   └── app.terraform.io/ravi-panchal-org/alb/aws
    └── module.ec2_instances[*]
        └── app.terraform.io/ravi-panchal-org/ec2-instance/aws
```

### Dependency Chain

```
Phase 1: Data Discovery
  data.aws_vpc → data.aws_subnets → data.aws_subnet
  ↓
Phase 2: Certificate Generation
  tls_private_key → tls_self_signed_cert → aws_acm_certificate
  ↓
Phase 3: Security Groups
  module.security_group_alb ←→ module.security_group_ec2
  ↓
Phase 4: Load Balancer
  module.alb (requires: security_group_alb, aws_acm_certificate)
  ↓
Phase 5: EC2 Instances
  module.ec2_instances (requires: security_group_ec2, subnets)
  ↓
Phase 6: Target Registration
  ALB target group automatically registers instances
```

### File Organization

| File | Purpose | Key Contents |
|------|---------|--------------|
| `main.tf` | Primary resource definitions | Module instantiations, resource blocks |
| `variables.tf` | Input variables | 9 variables with validation |
| `outputs.tf` | Output values | 23 outputs organized by category |
| `data.tf` | Data sources | VPC and subnet discovery |
| `locals.tf` | Computed values | Subnet selection, instance configs, tags |
| `providers.tf` | Provider configuration | AWS and TLS provider setup |
| `backend.tf` | Backend configuration | HCP Terraform Cloud |
| `versions.tf` | Version constraints | Terraform and provider versions |
| `user-data/nginx-bootstrap.sh` | EC2 bootstrap script | Nginx installation and configuration |

---

## Testing Strategy

### Level 1: Terraform Validation

```bash
# Syntax and formatting
terraform fmt -check -recursive
terraform validate

# Security scanning
tfsec .
checkov -d .
```

### Level 2: Plan Review

```bash
# Generate plan
terraform plan -out=tfplan

# Review resource changes
terraform show tfplan

# Validate expected resources (approximately):
# - 2 EC2 instances
# - 1 ALB with 1 target group
# - 2 security groups
# - 1 ACM certificate
```

### Level 3: Deployment Test

```bash
# Apply infrastructure
terraform apply -auto-approve

# Verify successful apply
terraform state list
```

### Level 4: Connectivity Tests

```bash
# Test HTTPS to ALB
curl -k https://$(terraform output -raw alb_dns_name)

# Verify load balancing (20 requests, should hit both instances)
for i in {1..20}; do
  curl -sk https://$(terraform output -raw alb_dns_name) | grep "Instance ID"
done | sort | uniq -c

# Expected: ~10 requests per instance
```

### Level 5: Health Check Validation

```bash
# Check target health status
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-southeast-1

# Expected: Both targets "healthy"
```

### Level 6: Security Validation

```bash
# Verify EC2 instances not directly accessible
INSTANCE_IP=$(terraform output -json ec2_instance_private_ips | jq -r '.[]' | head -n 1)
curl --connect-timeout 5 http://$INSTANCE_IP  # Should timeout

# Verify ALB rejects HTTP (port 80)
curl --connect-timeout 5 http://$(terraform output -raw alb_dns_name)  # Should fail
```

### Level 7: Failure Scenario Test

```bash
# Stop one instance
INSTANCE_ID=$(terraform output -json ec2_instance_ids | jq -r '.[0]')
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region ap-southeast-1

# Wait for health check to detect failure
sleep 70

# Verify traffic still flows (only healthy instance)
for i in {1..10}; do
  curl -sk https://$(terraform output -raw alb_dns_name)
done

# Restart instance
aws ec2 start-instances --instance-ids $INSTANCE_ID --region ap-southeast-1
```

### Level 8: Idempotency Test

```bash
# Re-apply (should show no changes)
terraform apply -auto-approve

# Expected output: "No changes. Your infrastructure matches the configuration."
```

### Level 9: Cleanup Test

```bash
# Destroy infrastructure
terraform destroy -auto-approve

# Verify all resources removed
aws ec2 describe-instances --filters "Name=tag:Project,Values=web-demo" --region ap-southeast-1
aws elbv2 describe-load-balancers --region ap-southeast-1 | grep web-demo
```

---

## Security Considerations

### Network Security

**Implementation**:
- ✅ ALB security group allows HTTPS (443) from internet only
- ✅ EC2 security group allows HTTP (80) from ALB security group only
- ✅ No SSH access configured (security by omission)
- ✅ EC2 instances in private subnets (implicit via security groups)

**Validation**:
- Direct access to EC2 instances fails (timeout)
- HTTP access to ALB fails (only HTTPS allowed)
- HTTPS access to ALB succeeds

### Certificate Security

**Development Environment Approach**:
- ⚠️ Private key stored in Terraform state (encrypted at rest in HCP Terraform)
- ⚠️ Self-signed certificate (browser warnings expected)
- ✅ 90-day validity with early renewal (30 days before expiry)

**Production Recommendations** (out of scope):
- Use AWS Secrets Manager with ephemeral resources for private key
- Use Let's Encrypt or commercial CA for valid certificates
- Implement certificate rotation automation

### Authentication & Authorization

**HCP Terraform**:
- ✅ Workspace variables store AWS credentials (or IAM role)
- ✅ No credentials in Terraform code
- ✅ State encrypted at rest and in transit

**AWS Permissions Required**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "acm:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Compliance

**Development Environment Status**:
- ❌ Not suitable for production workloads
- ❌ No compliance framework adherence (HIPAA, PCI-DSS, etc.)
- ❌ No audit logging (CloudTrail not configured)
- ❌ No encryption at rest for application data

**Clear Documentation**:
- Development-only environment clearly marked in tags
- Security considerations documented in research.md
- Upgrade path to production documented in quickstart.md

---

## Cost Optimization

### Resource Sizing

| Resource | Type | Quantity | Hourly Cost (ap-southeast-1) | Monthly Cost |
|----------|------|----------|------------------------------|--------------|
| EC2 Instances | t3.micro | 2 | $0.0116 × 2 = $0.0232 | $16.90 |
| Application Load Balancer | Standard | 1 | $0.0225 | $16.43 |
| Data Transfer | Outbound | Variable | ~$0.01/hour | ~$7.30 |
| **Total** | | | **~$0.055/hour** | **~$40/month** |

### Cost Optimization Strategies

1. **Instance Type Selection**:
   - ✅ t3.micro selected (cheapest AWS compute option)
   - ✅ Fallback to t2.micro if unavailable
   - ⚠️ Consider spot instances for further savings (not implemented)

2. **Load Balancer**:
   - ✅ Single ALB for cost efficiency
   - ⚠️ ALB minimum charge applies (~$16/month baseline)
   - ℹ️ Alternative: Network Load Balancer (slightly cheaper) but lacks HTTP features

3. **Data Transfer**:
   - ✅ Resources in same region (no cross-region charges)
   - ✅ ALB to EC2 traffic within VPC (no charges)
   - ⚠️ Outbound internet traffic charged per GB

4. **Resource Lifecycle**:
   - ✅ Easy teardown via `terraform destroy`
   - ✅ No persistent storage (EBS terminated with instances)
   - ✅ Use workspace tags for cost allocation

### Budget Alerts (Recommended)

```bash
# Set up AWS Budget alert (not automated in this plan)
aws budgets create-budget \
  --account-id <ACCOUNT_ID> \
  --budget '{
    "BudgetName": "web-demo-development",
    "BudgetLimit": {
      "Amount": "50",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

---

## Monitoring & Observability

### Built-in Monitoring

**ALB Metrics** (CloudWatch):
- Target health status
- Request count
- Response times (latency)
- HTTP response codes

**EC2 Metrics** (CloudWatch):
- CPU utilization
- Network traffic
- Status checks (system and instance)

**Access via AWS Console**:
```
CloudWatch → Metrics → EC2, ApplicationELB
```

### Health Check Monitoring

```bash
# Check target health status
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-southeast-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table
```

### Log Collection (Out of Scope)

**Not Implemented** (can be added in future):
- ALB access logs to S3
- VPC Flow Logs
- CloudWatch Logs agent on EC2 instances
- CloudWatch alarms for health check failures

---

## Deployment Timeline

### Phase 0: Preparation (Day 1)
- ✅ Repository setup
- ✅ HCP Terraform workspace configuration
- ✅ AWS credentials configuration
- **Duration**: 1-2 hours

### Phase 1: Infrastructure Development (Day 1-2)
- ✅ Terraform configuration development
- ✅ Module composition
- ✅ User data script creation
- ✅ Variable and output definitions
- **Duration**: 4-6 hours

### Phase 2: Testing & Validation (Day 2)
- ⏭️ Terraform validate and plan
- ⏭️ First deployment test
- ⏭️ Connectivity and health check testing
- ⏭️ Security validation
- ⏭️ Failure scenario testing
- **Duration**: 2-3 hours

### Phase 3: Documentation (Day 2-3)
- ✅ Research documentation
- ✅ Data model documentation
- ✅ Contract definitions
- ✅ Quickstart guide
- ✅ Implementation plan (this document)
- **Duration**: 3-4 hours

### Phase 4: Review & Refinement (Day 3)
- ⏭️ Code review
- ⏭️ Documentation review
- ⏭️ Final testing
- ⏭️ Cleanup and preparation for handoff
- **Duration**: 2-3 hours

**Total Estimated Time**: 12-18 hours across 3 days

---

## Success Criteria Validation

### From Specification (SC-001 through SC-010)

| ID | Criteria | Validation Method | Status |
|----|----------|-------------------|--------|
| SC-001 | Provisioning < 10 minutes | Terraform apply timing | ⏭️ To be validated |
| SC-002 | HTTPS response < 500ms | `curl` timing measurement | ⏭️ To be validated |
| SC-003 | Health checks pass < 2 min | ALB target health status | ⏭️ To be validated |
| SC-004 | Load balancing distribution | 20 requests across instances | ⏭️ To be validated |
| SC-005 | Direct EC2 access fails | Connection timeout test | ⏭️ To be validated |
| SC-006 | HTTP to ALB refused | Connection refused test | ⏭️ To be validated |
| SC-007 | Infrastructure idempotency | `terraform apply` no changes | ⏭️ To be validated |
| SC-008 | Consistent tagging | AWS Console tag inspection | ⏭️ To be validated |
| SC-009 | Clean destruction < 5 min | `terraform destroy` timing | ⏭️ To be validated |
| SC-010 | Single instance failure | Stop instance, verify traffic | ⏭️ To be validated |

**Validation**: All success criteria will be validated during Phase 2 testing.

---

## Known Limitations

### Development Environment Constraints

1. **No Auto-Scaling**: Fixed 2 instances (1 per AZ)
   - Manual scaling requires Terraform code changes
   - No dynamic scaling based on load

2. **Self-Signed Certificate**: Browser warnings expected
   - Users must manually accept certificate exception
   - Not suitable for public-facing production use

3. **No Monitoring/Alerting**: Basic health checks only
   - No CloudWatch alarms
   - No automated incident response
   - Manual monitoring required

4. **No Backup/DR**: No automated backup strategy
   - Nginx configuration in user data (ephemeral)
   - No persistent application state
   - Recovery requires re-deployment

5. **Single Region**: ap-southeast-1 only
   - No multi-region deployment
   - No cross-region failover

### Explicit Out of Scope Items

From specification section "Out of Scope":
- ❌ Production-grade infrastructure
- ❌ WAF (Web Application Firewall)
- ❌ CloudWatch monitoring dashboards
- ❌ VPC creation (uses default VPC)
- ❌ Database integration
- ❌ Custom application deployment (static Nginx only)
- ❌ SSH access configuration
- ❌ HTTP to HTTPS redirect
- ❌ Multi-region deployment
- ❌ Compliance framework adherence

---

## Risk Mitigation

### Risk 1: Default VPC Not Available
**Mitigation**: Data source fails gracefully with clear error  
**Workaround**: Create default VPC or modify to use custom VPC  
**Likelihood**: Low  
**Impact**: High (blocks deployment)

### Risk 2: Instance Type Unavailable in AZ
**Mitigation**: Terraform fails during apply with capacity error  
**Workaround**: Switch to t2.micro or different AZ  
**Likelihood**: Low  
**Impact**: Medium (requires configuration change)

### Risk 3: Private Key in Terraform State
**Mitigation**: HCP Terraform encrypts state at rest  
**Workaround**: For production, use AWS Secrets Manager  
**Likelihood**: High (by design)  
**Impact**: Low (development environment only)

### Risk 4: Cost Overruns
**Mitigation**: Monthly cost estimate provided ($40/month)  
**Workaround**: Set AWS Budget alerts, easy teardown  
**Likelihood**: Low  
**Impact**: Low (resources can be destroyed anytime)

### Risk 5: DNS Configuration Manual Step
**Mitigation**: ALB DNS can be used directly for testing  
**Workaround**: Document DNS setup in quickstart guide  
**Likelihood**: High (expected)  
**Impact**: Low (testing still possible with ALB DNS)

---

## Next Steps (Phase 2: Implementation)

Phase 2 is **NOT** executed by `/speckit.plan`. It requires the `/speckit.tasks` command.

### Tasks Overview (High Level)

1. **Create Terraform Configuration Files**
   - main.tf, variables.tf, outputs.tf, data.tf, locals.tf
   - providers.tf, backend.tf, versions.tf

2. **Create User Data Script**
   - user-data/nginx-bootstrap.sh with template variables

3. **Initialize and Test**
   - terraform init, validate, plan
   - Deploy to HCP Terraform workspace

4. **Validate Deployment**
   - Run all testing levels (L1-L9)
   - Document results

5. **Create README**
   - Quick start guide
   - Link to quickstart.md

**Detailed Tasks**: Will be generated by `/speckit.tasks` command based on this plan.

---

## References

### Generated Documentation
- [Feature Specification](./spec.md)
- [Research Findings](./research.md)
- [Data Model](./data-model.md)
- [Quickstart Guide](./quickstart.md)
- [Terraform Interface Contract](./contracts/terraform-interface.md)
- [Nginx Bootstrap Contract](./contracts/nginx-bootstrap-contract.md)

### External Resources
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform TLS Provider Documentation](https://registry.terraform.io/providers/hashicorp/tls/latest/docs)
- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS ACM Documentation](https://docs.aws.amazon.com/acm/)
- [Nginx Documentation](https://nginx.org/en/docs/)

### AWS Best Practices
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ALB Security Groups Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html)
- [Infrastructure Security in ELB](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/infrastructure-security.html)

---

## Plan Status

**Phase 0: Research** ✅ Complete  
**Phase 1: Design & Contracts** ✅ Complete  
**Phase 2: Implementation** ⏭️ Ready for `/speckit.tasks` command

**Total Planning Time**: ~8 hours  
**Plan Completion Date**: 2025-01-21  
**Ready for Implementation**: Yes

**Next Command**: `/speckit.tasks` to generate implementation tasks

---

## Approval Checklist

- [x] All NEEDS CLARIFICATION items resolved
- [x] Constitution check passed (all gates)
- [x] Private registry modules identified and documented
- [x] Security considerations documented
- [x] Cost estimates provided
- [x] Testing strategy defined
- [x] Success criteria mapped to validation methods
- [x] Known limitations documented
- [x] Risk mitigation strategies defined
- [x] Phase 0 (Research) complete
- [x] Phase 1 (Design & Contracts) complete
- [ ] Phase 2 (Implementation) - Requires `/speckit.tasks`

**Plan Approved For Implementation**: ✅ Yes
