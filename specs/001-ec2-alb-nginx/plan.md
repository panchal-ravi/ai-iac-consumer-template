# Implementation Plan: AWS EC2 Infrastructure with Application Load Balancer and Nginx

**Branch**: `001-ec2-alb-nginx` | **Date**: 2025-01-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-ec2-alb-nginx/spec.md`

## Summary

Provision a highly available web infrastructure in AWS ap-southeast-1 using Terraform with HCP Terraform state management. Deploy 2 EC2 instances (t3.micro) running Nginx across multiple availability zones, fronted by an internet-facing Application Load Balancer with HTTPS termination using a self-signed certificate. All infrastructure is provisioned using private registry modules from `ravi-panchal-org`, following organizational standards and security best practices.

**Key Decisions**:
- ✅ Private modules available for all components (ec2-instance, alb, security-group)
- ✅ Self-signed TLS certificate via Terraform TLS provider
- ✅ Multi-AZ deployment using existing default VPC
- ✅ Cost: $38.67/month (23% under $50 budget)
- ✅ Module-first architecture (constitution compliant)

## Technical Context

**Infrastructure-as-Code**: Terraform >= 1.7.0 (managed by HCP Terraform)  
**Primary Dependencies**: 
- AWS Provider ~> 5.0
- TLS Provider ~> 4.0
- Private Modules: ec2-instance (6.1.4), alb (10.2.0), security-group (5.3.1)

**State Management**: HCP Terraform (Organization: ravi-panchal-org, Workspace: sandbox_workspace)  
**Testing**: Manual validation via AWS CLI and curl commands  
**Target Platform**: AWS ap-southeast-1 (Singapore region)  
**Project Type**: Infrastructure (Terraform modules)  
**Performance Goals**: <2s response time, 100% availability with single instance failure  
**Constraints**: 
- Must use ap-southeast-1 region
- Exactly 2 x t3.micro instances
- Default VPC only (no custom VPC)
- Self-signed certificate (no DNS validation)
- Under $50/month cost

**Scale/Scope**: Development environment, 2 instances, minimal traffic (<100 req/min expected)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Module-First Architecture ✅ PASS

**Requirement**: All infrastructure MUST be provisioned through approved modules from Private Module Registry.

**Status**: ✅ COMPLIANT
- EC2 instances: Using `ravi-panchal-org/ec2-instance/aws` v6.1.4
- Load balancer: Using `ravi-panchal-org/alb/aws` v10.2.0
- Security groups: Using `ravi-panchal-org/security-group/aws` v5.3.1
- Direct resources: Only TLS certificate generation (no module exists for tls_private_key)

**Exception**: TLS certificate generation uses direct `tls_private_key` and `tls_self_signed_cert` resources because:
- No organizational module exists for certificate generation
- TLS provider resources are simple and don't require abstraction
- Certificate is imported to ACM immediately after generation

### Specification-Driven Development ✅ PASS

**Requirement**: Infrastructure code generation MUST be driven by explicit specifications.

**Status**: ✅ COMPLIANT
- Comprehensive spec.md with 27 functional requirements
- Research.md documents all technical decisions with rationale
- No implicit assumptions; all ambiguities resolved in Phase 0
- Implementation follows documented architecture patterns

### Security-First Automation ✅ PASS

**Requirement**: Generated code MUST assume zero trust and implement security controls by default.

**Status**: ✅ COMPLIANT
- No static credentials in code (using HCP Terraform workspace variables)
- IMDSv2 enforced on EC2 instances (metadata_options.http_tokens = "required")
- Least-privilege security groups (ALB → EC2 via security group reference)
- TLS encryption in transit (HTTPS only from internet to ALB)
- Private key stored in Terraform state (encrypted by HCP Terraform)

### HCP Terraform Prerequisites ✅ PASS

**Requirement**: HCP Terraform configuration details MUST be determined before operations.

**Status**: ✅ COMPLIANT
- Organization: ravi-panchal-org (specified in spec)
- Project: Default Project (specified in spec)
- Workspace: sandbox_workspace (specified in spec)
- All prerequisites documented and validated

**Constitution Check**: ✅ ALL GATES PASSED  
**Re-check After Phase 1**: ✅ NO VIOLATIONS INTRODUCED

## Project Structure

### Documentation (this feature)

```text
specs/001-ec2-alb-nginx/
├── spec.md              # Feature specification (user requirements)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0: Technical decisions and module analysis
├── data-model.md        # Phase 1: Terraform resource relationships
├── quickstart.md        # Phase 1: Deployment and testing guide
├── contracts/           # Phase 1: Terraform output contracts
│   └── terraform-outputs.md
└── tasks.md             # Phase 2: NOT created by /speckit.plan command
                         # Generated separately by /speckit.tasks command
```

### Source Code (repository root)

```text
terraform/
├── main.tf              # Primary Terraform configuration
│   ├── Data sources (VPC, subnets)
│   ├── TLS certificate resources
│   ├── Security group modules
│   ├── EC2 instance modules
│   └── ALB module
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output value definitions
├── providers.tf         # Provider configuration (AWS, TLS)
├── versions.tf          # Terraform and provider version constraints
├── terraform.tfvars     # Variable values (non-sensitive)
└── user-data.sh         # EC2 instance user data script (Nginx installation)

.terraform/              # Terraform working directory (gitignored)
├── modules/             # Downloaded module cache
└── providers/           # Downloaded provider binaries

terraform.tfstate        # State file (stored in HCP Terraform, not local)
```

**Structure Decision**: Infrastructure-as-Code project using Terraform modules. All Terraform configuration files are in the repository root. HCP Terraform manages state remotely, so no local state files are committed. User data scripts are stored alongside Terraform files for easy reference and version control.

## Complexity Tracking

> **No violations detected** - Constitution check passed all gates without exceptions.

*This section is empty because no constitution violations were identified. The implementation follows organizational standards:*
- Uses private registry modules exclusively (where available)
- No direct resource declarations for infrastructure components
- Security-first approach with no hardcoded credentials
- Specification-driven with complete requirements documentation

---

## Implementation Phases

### Phase 0: Research & Design Decisions ✅ COMPLETE

**Objective**: Resolve all technical unknowns and document architectural decisions.

**Deliverables**:
- ✅ `research.md` - Comprehensive technical research document
  - Private module registry analysis (4 modules identified)
  - AWS architecture decisions (region, AZs, instance types)
  - Security architecture (TLS, security groups, IAM)
  - Cost analysis ($38.67/month, under budget)
  - Testing and validation strategy
  - Best practices alignment (AWS Well-Architected)

**Key Decisions Made**:
1. Use private registry modules exclusively (ravi-panchal-org)
2. Self-signed TLS certificate via Terraform TLS provider
3. Default VPC with multi-AZ deployment (ap-southeast-1a, ap-southeast-1b)
4. Amazon Linux 2023 with Nginx installed via user_data
5. Internet-facing ALB with HTTPS termination, HTTP backend
6. Cost-optimized with t3.micro instances

**Status**: ✅ All unknowns resolved, ready for design phase

---

### Phase 1: Design & Contracts ✅ COMPLETE

**Objective**: Define data model, resource relationships, and output contracts.

**Deliverables**:
- ✅ `data-model.md` - Terraform resource relationships and dependencies
  - Entity relationship diagram
  - Data source definitions (VPC, subnets, AMI)
  - Resource configurations via private modules
  - Input variable specifications with validation
  - Output value definitions
  - Dependency graph and state relationships

- ✅ `contracts/terraform-outputs.md` - Infrastructure API contract
  - Primary access point (alb_endpoint)
  - Infrastructure details (instance IDs, security groups)
  - Testing interface (health checks, verification commands)
  - Contract guarantees (availability, security, performance)

- ✅ `quickstart.md` - Deployment and operational guide
  - Prerequisites checklist
  - Step-by-step deployment instructions
  - Testing procedures (6 test scenarios)
  - Monitoring guidance
  - Troubleshooting common issues
  - Cost management strategies
  - Cleanup procedures

**Key Artifacts Created**:
1. Complete Terraform resource model with module references
2. Security group architecture (ALB SG, EC2 SG with least-privilege rules)
3. TLS certificate generation workflow (private key → self-signed cert → ACM import)
4. EC2 instance configuration with Nginx user data
5. ALB configuration with HTTPS listener and target group
6. Comprehensive testing and validation procedures

**Status**: ✅ Design complete, contracts defined, ready for implementation

---

### Phase 2: Task Generation (NOT PART OF THIS COMMAND)

**Objective**: Generate actionable, dependency-ordered task list for implementation.

**Command**: `/speckit.tasks` (separate command, NOT executed by `/speckit.plan`)

**Expected Output**: `tasks.md` with:
- Ordered list of implementation tasks
- Dependencies between tasks
- Acceptance criteria per task
- Time estimates
- Risk assessments

**Note**: This phase is executed separately after plan approval.

---

## Module Strategy Summary

### Private Registry Modules Used

| Module | Version | Purpose | Source |
|--------|---------|---------|--------|
| ec2-instance | 6.1.4 | EC2 instance provisioning | ravi-panchal-org/ec2-instance/aws |
| alb | 10.2.0 | Application Load Balancer | ravi-panchal-org/alb/aws |
| security-group | 5.3.1 | Network security groups | ravi-panchal-org/security-group/aws |

**Module Search Results**:
- ✅ EC2 module found with required features (t3.micro, user_data, IMDSv2, multi-AZ)
- ✅ ALB module found with HTTPS listener, ACM integration, target groups
- ✅ Security group module found with ingress/egress rule management
- ✅ VPC module found but NOT needed (using default VPC via data source)

**Public Registry**: ❌ No public registry modules needed (100% private registry coverage)

**Justification**: All required infrastructure components have approved private registry modules that meet specifications. No need to fall back to public registry.

---

## Resource Architecture

### High-Level Architecture

```
Internet
   ↓ HTTPS (443)
┌──────────────────────────┐
│ Application Load Balancer│ ← ALB Security Group (HTTPS:443 from 0.0.0.0/0)
│ (internet-facing)        │
│ + TLS Termination        │
│ + ACM Certificate        │
└──────────┬───────────────┘
           │ HTTP (80)
           ↓
    ┌──────────────┐
    │ Target Group │
    │ Health Check │
    └──────┬───────┘
           │
    ┌──────┴───────┐
    ↓              ↓
┌─────────┐   ┌─────────┐
│ EC2 (1) │   │ EC2 (2) │ ← EC2 Security Group (HTTP:80 from ALB SG only)
│ Nginx   │   │ Nginx   │
│ AZ-1a   │   │ AZ-1b   │
└─────────┘   └─────────┘

Default VPC (ap-southeast-1)
- Subnet AZ-1a (public)
- Subnet AZ-1b (public)
```

### Network Design

- **VPC**: Default VPC in ap-southeast-1 (existing, data source)
- **Subnets**: 2 public subnets in different AZs (data source)
- **Internet Gateway**: Default VPC IGW (existing)
- **Routing**: Default route table with 0.0.0.0/0 → IGW

### Security Architecture

**Defense in Depth**:
1. **Network Layer**: Security groups with least-privilege rules
2. **Transport Layer**: TLS 1.3 encryption (HTTPS only from internet)
3. **Application Layer**: Nginx with default security configuration
4. **Access Layer**: No SSH keys (future: SSM Session Manager)

**Trust Boundaries**:
- Internet → ALB: TLS encrypted (HTTPS)
- ALB → EC2: HTTP (within VPC, trusted network)
- EC2 → Internet: HTTPS for package updates

---

## Cost Optimization

### Monthly Cost Breakdown

| Component | Unit Cost | Quantity | Monthly Cost |
|-----------|-----------|----------|--------------|
| EC2 t3.micro | $7.30 | 2 | $14.60 |
| EBS GP3 8GB | $0.80 | 2 | $1.60 |
| ALB | $22.27 | 1 | $22.27 |
| ALB LCU-hours | $0.008 | ~10 | $0.08 |
| Data transfer | $0.12/GB | ~1 GB | $0.12 |
| **TOTAL** | | | **$38.67** |

**Budget Compliance**: ✅ $38.67 < $50 (23% under budget)

### Optimization Strategies Applied

1. ✅ Minimal instance size (t3.micro)
2. ✅ Exactly 2 instances (meets HA requirement at minimum)
3. ✅ Default VPC (no NAT gateway costs)
4. ✅ Public subnets (no NAT required)
5. ✅ Self-signed certificate (no certificate cost)
6. ✅ Standard health check interval (not aggressive)
7. ✅ GP3 EBS (better price/performance than GP2)

---

## Deployment Timeline

### Estimated Durations

| Phase | Duration | Status |
|-------|----------|--------|
| Research & Design (Phase 0) | 30 mins | ✅ Complete |
| Data Model & Contracts (Phase 1) | 45 mins | ✅ Complete |
| **Planning Complete** | **1.25 hours** | **✅ Done** |
| Task Generation (Phase 2) | 15 mins | ⏳ Pending |
| Infrastructure Implementation | 2.5 hours | ⏳ Pending |
| Testing & Validation | 30 mins | ⏳ Pending |
| **Total Project Time** | **~4.5 hours** | **In Progress** |

### Critical Path

1. Generate TLS certificate ← No dependencies
2. Create security groups ← Requires VPC data source
3. Deploy EC2 instances ← Requires EC2 security group
4. Create ALB with target group ← Requires ACM cert, EC2 instances, ALB SG
5. Validate deployment ← Requires ALB DNS name

---

## Testing Strategy

### Validation Levels

1. **Terraform Validation**: `terraform validate`, `terraform plan`
2. **Resource Creation**: Verify all resources created successfully
3. **Connectivity**: Test ALB HTTPS endpoint
4. **Security**: Verify direct EC2 access blocked
5. **High Availability**: Test failover with one instance down
6. **Health Checks**: Verify target health monitoring

### Success Criteria Validation

| Criteria | Test Method | Expected Result |
|----------|-------------|-----------------|
| SC-001: Deploy < 10 min | Time terraform apply | ✅ Expected ~5-8 minutes |
| SC-002: Response < 2s | curl timing | ✅ ALB routing <500ms |
| SC-003: HA with 1 down | Stop Nginx on instance | ✅ ALB continues serving |
| SC-004: TLS termination | openssl s_client | ✅ Certificate validated |
| SC-005: Direct access blocked | curl EC2 public IP | ✅ Connection timeout |
| SC-006: Failure detection | Health check timing | ✅ 60s detection (2×30s) |
| SC-007: Cost < $50 | AWS Cost Explorer | ✅ Estimated $38.67 |
| SC-012: 100% success | Load test | ✅ All healthy targets |

---

## Risk Mitigation

### Pre-Deployment Validation

```bash
# Verify default VPC exists
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region ap-southeast-1

# Verify availability zones available
aws ec2 describe-availability-zones --region ap-southeast-1

# Verify t3.micro available
aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters "Name=instance-type,Values=t3.micro" --region ap-southeast-1
```

### Rollback Plan

1. **Terraform Destroy**: `terraform destroy` removes all resources
2. **No Data Loss**: Stateless architecture, no persistent data
3. **Quick Recovery**: Re-apply takes ~5-8 minutes
4. **State Backup**: HCP Terraform maintains state history

---

## Next Steps

### Immediate Actions

1. ✅ Review plan.md for completeness
2. ✅ Validate research.md technical decisions
3. ✅ Confirm data-model.md resource relationships
4. ⏳ Execute `/speckit.tasks` to generate tasks.md
5. ⏳ Begin implementation following tasks.md

### Post-Implementation

1. Document actual deployment time vs estimates
2. Capture CloudWatch metrics for performance baseline
3. Document any issues encountered and resolutions
4. Create runbook for operational procedures
5. Schedule cost review after 30 days

---

## Artifact Summary

### Generated Files

- ✅ `research.md` - 25KB, comprehensive technical research
- ✅ `data-model.md` - Terraform resource model
- ✅ `quickstart.md` - 9KB, deployment guide
- ✅ `contracts/terraform-outputs.md` - Output API contract
- ✅ `plan.md` - This file, implementation plan

### Module References

- All modules use `app.terraform.io/ravi-panchal-org/` prefix
- All modules pinned with `~>` version constraints
- Module documentation reviewed for compatibility

---

## Planning Sign-Off

**Phase 0 (Research)**: ✅ COMPLETE  
**Phase 1 (Design)**: ✅ COMPLETE  
**Constitution Compliance**: ✅ ALL GATES PASSED  
**Cost Validation**: ✅ UNDER BUDGET ($38.67 < $50)  
**Security Review**: ✅ BEST PRACTICES FOLLOWED  
**Module Strategy**: ✅ 100% PRIVATE REGISTRY  

**Planning Phase Complete** ✅  
**Ready for Task Generation** ✅  
**Branch**: `001-ec2-alb-nginx`  
**Date**: 2025-01-13

---

**End of Implementation Plan**
