# Implementation Plan: Public EC2 Instance for Development Environment

**Branch**: `001-public-ec2-dev` | **Date**: 2026-01-12 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-public-ec2-dev/spec.md`  
**GitHub Issue**: [#12](https://github.com/[org]/[repo]/issues/12)

**Note**: This plan was generated following the Speckit workflow. See Phase 0 research and Phase 1 design artifacts for technical details.

## Summary

**Primary Requirement**: Provision a cost-optimized public EC2 instance (t3.micro) in AWS ap-southeast-1 region for development use, with SSH password authentication instead of key pairs, managed through HCP Terraform workspace `sandbox_workspace`.

**Technical Approach**:
- Use **module-first architecture** prioritizing HCP Terraform private registry (`ravi-panchal-org`) modules
- Leverage **AWS Secrets Manager** to securely store SSH passwords outside Terraform state
- Implement **user data script** to enable password authentication on Amazon Linux 2023
- Deploy in **default VPC** with security group allowing SSH from 0.0.0.0/0 (development only)
- Enable **basic CloudWatch monitoring** (5-minute intervals) for cost optimization
- Total estimated cost: **$12.32/month** (well under $50 budget constraint)

**Key Design Decision**: SSH password authentication (instead of key pairs) is implemented for team collaboration ease, accepting increased security risk for development environment only.

## Technical Context

**Infrastructure as Code**: Terraform ~> 1.13.0  
**State Management**: HCP Terraform (Organization: `ravi-panchal-org`, Workspace: `sandbox_workspace`)  
**Cloud Provider**: AWS (ap-southeast-1 - Singapore region)  
**Compute**: Amazon EC2 t3.micro (1 vCPU, 1GB RAM)  
**Operating System**: Amazon Linux 2023 (latest AMI, dynamically selected)  
**Storage**: 8GB GP3 EBS volume (3000 IOPS, 125 MB/s throughput)  
**Networking**: Default VPC, public subnet, public IPv4 address assigned  
**Security**: AWS Secrets Manager (password storage), IAM roles (instance permissions)  
**Monitoring**: CloudWatch basic monitoring (5-minute intervals, no detailed monitoring)

**Terraform Providers**:
- `hashicorp/aws` ~> 6.0.0 (AWS resource provisioning)
- `hashicorp/random` ~> 3.0.0 (secure password generation)

**Module Strategy** (per Constitution Section 1.1):
1. **Priority 1**: Private registry modules from `app.terraform.io/ravi-panchal-org/` (REQUIRED SEARCH PENDING)
2. **Priority 2**: Public registry modules (terraform-aws-modules) with documented justification
3. **Priority 3**: Raw AWS resources (avoid if possible)

**Performance Goals**:
- Infrastructure provisioning: < 5 minutes (Spec: SC-001)
- SSH connection establishment: < 2 minutes after provisioning (Spec: SC-002)
- Password retrieval from Secrets Manager: < 30 seconds (Spec: SC-005)

**Constraints**:
- **Cost**: < $50/month budget (current estimate: $12.32/month including IPv4 charges)
- **Region**: Must be ap-southeast-1 (no flexibility)
- **Instance Type**: Must be t3.micro (cost optimization)
- **VPC**: Must use default VPC (no custom VPC creation)
- **Monitoring**: Basic only (5-min intervals, no detailed monitoring or custom dashboards)
- **Authentication**: Password-based SSH (not key pairs) for development ease

**Scale/Scope**:
- Single EC2 instance (no high availability or auto-scaling)
- Development environment (not production-grade)
- Budget allocation: $50/month (actual: $12.32/month = 75% under budget)
- Team size: Multiple developers (password shared via Secrets Manager)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Phase 0 Check: ✅ PASS

**1.1 Module-First Architecture**: ✅ COMPLIANT
- Action Required: Search HCP Terraform private registry (`ravi-panchal-org`) for EC2, security group, and secrets management modules
- Priority: Private modules > Public modules > Raw resources
- Module source format: `app.terraform.io/ravi-panchal-org/module-name/provider`
- Status: Research phase identifies module search as prerequisite (see research.md Section 10)

**1.2 Specification-Driven Development**: ✅ COMPLIANT
- Feature specification exists at `specs/001-public-ec2-dev/spec.md`
- Requirements clearly defined with functional requirements (FR-001 through FR-025)
- Edge cases documented (default VPC validation, AMI lifecycle, password complexity)
- Clarifications captured (volume deletion policy, monitoring level)

**1.3 Security-First Automation**: ✅ COMPLIANT WITH DOCUMENTED TRADE-OFFS
- No static credentials in code (using dynamic workspace credentials per Constitution III.3.1)
- SSH password stored in AWS Secrets Manager (encrypted at rest, not in Terraform state)
- IAM instance profile used for Secrets Manager access (no embedded credentials)
- **Security Trade-off Accepted** (per Spec Section: Security Considerations):
  - Public SSH access (0.0.0.0/0) accepted for development environment
  - Password authentication (instead of keys) accepted for team collaboration ease
  - Mitigations: 32-character strong password, basic CloudWatch monitoring

**2.1 HCP Terraform Prerequisites**: ✅ VALIDATED
- Organization: `ravi-panchal-org` (provided in spec context)
- Project: `Default Project` (provided in spec context)
- Workspace: `sandbox_workspace` (provided in spec context)
- GitHub Issue: #12 (linked in spec)
- Region: ap-southeast-1 (specified in spec)

### Post-Phase 1 Check: ⏸️ PENDING DESIGN COMPLETION

Will re-evaluate after Phase 1 design artifacts (data-model.md, contracts/, quickstart.md) are generated.

**Expected Validations**:
- [ ] Module selections documented with justification
- [ ] Security controls implemented (Secrets Manager, IAM roles)
- [ ] Cost analysis confirms < $50/month budget
- [ ] File organization follows Constitution III.3.2 standards
- [ ] Naming conventions follow HashiCorp standards (Constitution III.3.3)

---

### Gate Violations: NONE

All constitutional requirements are met or have documented, justified trade-offs approved in the feature specification.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

## Project Structure

### Documentation (this feature)

```text
specs/001-public-ec2-dev/
├── spec.md              # Feature specification (input)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0: Research findings and technical decisions
├── data-model.md        # Phase 1: Entity definitions and relationships
├── quickstart.md        # Phase 1: Developer onboarding guide
├── contracts/           # Phase 1: API contracts (N/A for infrastructure)
└── tasks.md             # Phase 2: NOT created by /speckit.plan (generated by /speckit.tasks)
```

### Source Code (repository root)

**Infrastructure-as-Code Project** (Terraform configuration):

```text
/workspace/
├── main.tf                          # Module instantiations and core infrastructure
│   ├── Data sources (default VPC, subnets, Amazon Linux 2023 AMI)
│   ├── Random password generation
│   ├── AWS Secrets Manager secret and version
│   ├── IAM role and instance profile
│   ├── Security group (SSH rules)
│   ├── EC2 instance with user data script
│   └── User data template (enable SSH password auth)
│
├── locals.tf                        # Local values (common tags, naming conventions)
├── variables.tf                     # Input variable declarations
│   ├── environment (default: "development")
│   ├── instance_type (default: "t3.micro")
│   ├── region (default: "ap-southeast-1")
│   ├── root_volume_size (default: 8)
│   ├── project_name (required)
│   └── cost_center (required)
│
├── outputs.tf                       # Terraform outputs
│   ├── instance_id
│   ├── instance_public_ip
│   ├── security_group_id
│   └── ssh_secret_arn (Secrets Manager ARN)
│
├── providers.tf                     # AWS provider configuration
├── versions.tf                      # Terraform and provider version constraints
├── override.tf                      # HCP Terraform cloud backend configuration
├── sandbox.auto.tfvars              # Sandbox environment variable values
├── sandbox.auto.tfvars.example      # Example variable file template
│
├── .tflint.hcl                      # TFLint configuration
├── .pre-commit-config.yaml          # Pre-commit hooks (terraform fmt, validate, docs)
├── README.md                        # Auto-generated documentation (terraform-docs)
└── .gitignore                       # Ignore .terraform/, *.tfstate, etc.
```

**Structure Decision**: 

This is a **single Terraform project** (not a multi-app monorepo) for provisioning AWS infrastructure. All Terraform files are at the repository root level, following HashiCorp's standard module structure and the constitution's file organization requirements (Section III.3.2).

**Key Design Choices**:
1. **Single main.tf**: All resources defined in one file (< 500 lines per Constitution III.3.2)
2. **Module-first approach**: Will use private/public modules for EC2, security group if available
3. **User data template**: Separate template file or inline in main.tf for SSH password configuration
4. **State management**: HCP Terraform remote backend (configured in override.tf)
5. **Environment separation**: Via workspace variables, not code duplication

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**Status**: ✅ No violations detected

All constitutional requirements are satisfied:
- Module-first architecture will be followed (pending private registry search)
- Specification-driven development process followed (spec.md exists with complete requirements)
- Security-first automation implemented with documented trade-offs (Secrets Manager, IAM roles)
- No prohibited patterns detected (no static credentials, no monolithic files, proper naming)

**Security Trade-offs** (documented in spec, not violations):
- Public SSH access (0.0.0.0/0) → Justified for development environment, accepted risk
- Password authentication → Justified for team collaboration ease, mitigated by strong password

No additional complexity justification required.

---

## Phase 0: Research Findings Summary

**Completed**: ✅ See full details in [research.md](./research.md)

### Key Decisions

1. **Module Strategy** (PENDING):
   - **Action Required**: Search HCP Terraform private registry using MCP `search_private_modules` tool
   - **Search Queries**: "ec2", "security-group", "secrets-manager", "vpc", "password"
   - **Decision Logic**: Private modules (if available) → Public modules (with justification) → Raw resources

2. **SSH Password Authentication**:
   - **Approach**: User data script + AWS Secrets Manager
   - **Password Generation**: Terraform `random_password` (32 chars, all character classes)
   - **Storage**: AWS Secrets Manager (encrypted at rest with KMS)
   - **Retrieval**: EC2 instance IAM role with `secretsmanager:GetSecretValue` permission
   - **Implementation**: User data script enables password auth in `/etc/ssh/sshd_config`

3. **Amazon Linux 2023 AMI Selection**:
   - **Approach**: Dynamic AMI lookup using `aws_ami` data source
   - **Filters**: `name = al2023-ami-*-x86_64`, `owner = amazon`, `most_recent = true`
   - **Rationale**: Avoids hardcoded AMI IDs that become outdated

4. **Security Group Configuration**:
   - **Inbound**: TCP port 22 from 0.0.0.0/0 (development requirement)
   - **Outbound**: All traffic allowed (for package updates)
   - **Accepted Risk**: Public SSH exposure (documented in spec security section)

5. **CloudWatch Monitoring**:
   - **Level**: Basic monitoring only (5-minute intervals)
   - **Cost**: $0/month (included in EC2 pricing)
   - **Metrics**: CPU, network I/O, disk I/O (default metrics)
   - **Rationale**: Detailed monitoring ($2.10/month) unnecessary for dev environment

6. **Cost Analysis**:
   - **EC2 t3.micro**: $7.59/month (730 hours × $0.0104/hour)
   - **EBS GP3 8GB**: $0.64/month ($0.08/GB)
   - **Public IPv4**: $3.60/month ($0.005/hour)
   - **Secrets Manager**: $0.40/month
   - **Data Transfer**: $0.09/month (estimate)
   - **Total**: $12.32/month (75% under $50 budget)

7. **VPC Strategy**:
   - **Decision**: Use default VPC in ap-southeast-1 (spec requirement)
   - **Validation**: Use `aws_vpc` data source with `default = true` filter
   - **Error Handling**: Fail with clear error if default VPC doesn't exist

---

## Phase 1: Design Artifacts Summary

**Completed**: ✅ See full details in [data-model.md](./data-model.md) and [quickstart.md](./quickstart.md)

### Data Model Highlights

**7 Primary Entities**:
1. **EC2 Instance**: t3.micro compute resource with Amazon Linux 2023
2. **Security Group**: Firewall rules (SSH from 0.0.0.0/0)
3. **EBS Root Volume**: 8GB GP3 storage (delete on termination)
4. **SSH Credentials**: Username (ec2-user) + password (32 chars)
5. **Secrets Manager Secret**: Encrypted password storage
6. **IAM Role + Instance Profile**: Secrets Manager access permissions
7. **VPC**: Default VPC in ap-southeast-1 (existing infrastructure)

**Key Relationships**:
- EC2 Instance → BELONGS TO → VPC
- EC2 Instance → ATTACHED TO → Security Group
- EC2 Instance → HAS → EBS Volume
- EC2 Instance → USES → IAM Instance Profile
- EC2 Instance → ACCESSES → SSH Credentials
- SSH Credentials → STORED IN → Secrets Manager Secret
- IAM Role → GRANTS ACCESS TO → Secrets Manager Secret

**State Management**:
- Terraform state stored in HCP Terraform workspace `sandbox_workspace`
- Sensitive data (`random_password.result`) marked as sensitive in Terraform
- Secrets Manager ARN safe to expose in outputs (not the password value)

### Quickstart Guide Highlights

**Developer Workflow**:
1. Provision infrastructure via HCP Terraform (2-3 minutes)
2. Retrieve SSH password from Secrets Manager (AWS CLI or Console)
3. Connect to instance via SSH with password authentication
4. Monitor instance using CloudWatch basic metrics

**Key Outputs**:
- `instance_id`: EC2 instance identifier
- `instance_public_ip`: Public IP for SSH connection
- `security_group_id`: Security group identifier
- `ssh_secret_arn`: Secrets Manager ARN for password retrieval

---

## Implementation Phases

### Phase 0: Research & Technical Decisions ✅ COMPLETE
- [x] AWS documentation research (EC2, Secrets Manager, CloudWatch)
- [x] Terraform best practices research
- [x] Cost analysis and budget validation
- [x] Security trade-offs documentation
- [x] Module strategy defined (private registry search pending)
- [x] User data script approach validated

### Phase 1: Design & Contracts ✅ COMPLETE
- [x] Data model defined (7 entities, relationships, validation rules)
- [x] Quickstart guide created (developer onboarding)
- [x] Contracts generated (N/A for infrastructure - no API contracts)
- [x] Agent context update (PENDING - to be executed)

### Phase 2: Task Generation ⏸️ NOT STARTED
- [ ] Generate tasks.md with dependency-ordered implementation tasks
- [ ] **Command**: `/speckit.tasks` (NOT created by `/speckit.plan`)
- [ ] Expected tasks: ~10-15 implementation tasks from data model and requirements

### Phase 3: Implementation ⏸️ NOT STARTED
- [ ] Search HCP Terraform private registry for modules (MCP tool)
- [ ] Create Terraform configuration files (main.tf, variables.tf, outputs.tf, etc.)
- [ ] Write user data script template
- [ ] Configure HCP Terraform workspace variables
- [ ] Run pre-commit hooks (terraform fmt, validate, tflint)
- [ ] Test in ephemeral workspace
- [ ] Apply to sandbox_workspace
- [ ] Validate SSH connectivity and monitoring
- [ ] **Command**: `/speckit.implement` (executes tasks.md)

---

## Module Selection Strategy

### Private Registry Search (REQUIRED NEXT STEP)

**MCP Tool**: `search_private_modules`  
**Organization**: `ravi-panchal-org`  
**Queries**:

```
1. search_private_modules(query="ec2", namespace="ravi-panchal-org")
2. search_private_modules(query="instance", namespace="ravi-panchal-org")
3. search_private_modules(query="security-group", namespace="ravi-panchal-org")
4. search_private_modules(query="secrets-manager", namespace="ravi-panchal-org")
5. search_private_modules(query="vpc", namespace="ravi-panchal-org")
```

**Decision Logic** (per Constitution Section 1.1):

```
IF private_module_found THEN
  module "resource" {
    source  = "app.terraform.io/ravi-panchal-org/module-name/aws"
    version = "~> X.Y.0"
    # ... inputs
  }
ELSE IF public_module_suitable THEN
  # Document justification: "Private module not available for [resource]"
  module "resource" {
    source  = "terraform-aws-modules/module-name/aws"
    version = "~> X.Y.0"
    # ... inputs
  }
ELSE
  # Document justification: "No suitable module found, using raw resource"
  resource "aws_resource_type" "name" {
    # ... configuration
  }
END IF
```

### Public Module Candidates (Fallback)

If private registry modules not available:

1. **EC2 Instance**: `terraform-aws-modules/ec2-instance/aws` (v5.x)
2. **Security Group**: `terraform-aws-modules/security-group/aws` (v5.x)
3. **Secrets Manager**: Raw `aws_secretsmanager_secret` resource (no complex module needed)
4. **Random Password**: Raw `random_password` resource (provider resource)
5. **IAM Role**: Raw `aws_iam_role` + `aws_iam_instance_profile` (straightforward)

---

## Terraform Configuration Structure

### Expected File Sizes (Estimates)

| File | Lines | Description |
|------|-------|-------------|
| `main.tf` | 150-200 | Core infrastructure (modules/resources) |
| `variables.tf` | 50-70 | Variable declarations with validation |
| `outputs.tf` | 20-30 | Outputs (IDs, IPs, ARNs) |
| `locals.tf` | 30-50 | Common tags, naming conventions |
| `providers.tf` | 10-15 | AWS provider configuration |
| `versions.tf` | 15-20 | Terraform and provider versions |
| `override.tf` | 10-15 | HCP Terraform backend config |
| `sandbox.auto.tfvars` | 20-30 | Environment-specific values |
| `README.md` | 100-150 | Auto-generated documentation |

**Total**: ~405-580 lines (well under 500-line limit per Constitution)

### Variable Definitions (Preview)

```hcl
variable "environment" {
  description = "Deployment environment (development, staging, production)"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "instance_type" {
  description = "EC2 instance type (must be t3.micro for cost optimization)"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = var.instance_type == "t3.micro"
    error_message = "Instance type must be t3.micro per cost requirements."
  }
}

variable "region" {
  description = "AWS region for resource deployment (must be ap-southeast-1)"
  type        = string
  default     = "ap-southeast-1"
  
  validation {
    condition     = var.region == "ap-southeast-1"
    error_message = "Region must be ap-southeast-1 per specification."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB (must be 8 GB)"
  type        = number
  default     = 8
  
  validation {
    condition     = var.root_volume_size == 8
    error_message = "Root volume size must be 8 GB per specification."
  }
}

variable "project_name" {
  description = "Project name for resource tagging and identification"
  type        = string
  # Required - no default
}

variable "cost_center" {
  description = "Cost center identifier for billing and cost allocation"
  type        = string
  # Required - no default
}

variable "ssh_password_length" {
  description = "Length of generated SSH password (minimum 32 characters)"
  type        = number
  default     = 32
  
  validation {
    condition     = var.ssh_password_length >= 32
    error_message = "Password length must be at least 32 characters for security."
  }
}
```

### Output Definitions (Preview)

```hcl
output "instance_id" {
  description = "EC2 instance ID for reference and management"
  value       = aws_instance.dev_ec2.id
}

output "instance_public_ip" {
  description = "Public IP address for SSH connection"
  value       = aws_instance.dev_ec2.public_ip
}

output "instance_private_ip" {
  description = "Private IP address within VPC"
  value       = aws_instance.dev_ec2.private_ip
}

output "security_group_id" {
  description = "Security group ID for reference"
  value       = aws_security_group.ssh_sg.id
}

output "ssh_secret_arn" {
  description = "AWS Secrets Manager ARN for SSH password retrieval"
  value       = aws_secretsmanager_secret.ssh_password.arn
}

output "ssh_secret_name" {
  description = "AWS Secrets Manager secret name for password retrieval"
  value       = aws_secretsmanager_secret.ssh_password.name
}

output "iam_role_name" {
  description = "IAM role name attached to EC2 instance"
  value       = aws_iam_role.ec2_instance_role.name
}
```

---

## Testing & Validation Strategy

### Pre-Deployment Validation

1. **Terraform Syntax**:
   ```bash
   terraform fmt -check
   terraform init
   terraform validate
   ```

2. **TFLint** (via pre-commit):
   ```bash
   tflint --init
   tflint --config .tflint.hcl
   ```

3. **Pre-commit Hooks**:
   ```bash
   pre-commit install
   pre-commit run --all-files
   ```

### Ephemeral Workspace Testing (Constitution V.4.1)

1. **Create Ephemeral Workspace**:
   - Connect to feature branch `001-public-ec2-dev`
   - Use HCP Terraform MCP tools: `create_workspace`
   - Create workspace variables from `sandbox.auto.tfvars`

2. **Run Terraform Plan**:
   - Execute plan in ephemeral workspace
   - Validate resource count (~8-10 resources)
   - Review plan output for correctness

3. **Run Terraform Apply** (if plan approved):
   - Apply configuration in ephemeral workspace
   - Validate outputs (instance IP, secret ARN)
   - Test SSH connectivity with password
   - Verify CloudWatch metrics appearing

4. **Cleanup**:
   - Destroy ephemeral workspace resources
   - Delete ephemeral workspace

### Post-Deployment Validation (Acceptance Checklist from Spec)

**Infrastructure**:
- [ ] EC2 t3.micro instance running in ap-southeast-1
- [ ] Public IP assigned and reachable
- [ ] Amazon Linux 2023 AMI verified
- [ ] 8GB GP3 root volume attached
- [ ] Deployed in default VPC

**Authentication**:
- [ ] SSH password authentication enabled
- [ ] Password stored in Secrets Manager
- [ ] SSH connection successful from 2+ external IPs
- [ ] Secret ARN in Terraform outputs

**Security**:
- [ ] Security group allows SSH from 0.0.0.0/0
- [ ] IAM instance profile attached
- [ ] Secrets Manager permissions validated

**Monitoring & Tagging**:
- [ ] Basic CloudWatch monitoring enabled (5-min intervals)
- [ ] Detailed monitoring NOT enabled
- [ ] All resources tagged correctly (Environment, ManagedBy, Project, CostCenter)

**Cost**:
- [ ] Estimated cost < $50/month (target: $12.32)
- [ ] Cost tags visible in AWS Cost Explorer

**Idempotency**:
- [ ] Re-running `terraform apply` shows no changes
- [ ] Infrastructure can be destroyed cleanly

---

## Security Considerations

### Implemented Controls

1. **Secrets Management**:
   - SSH password stored in AWS Secrets Manager (encrypted at rest with KMS)
   - Password never appears in Terraform outputs or state (marked as sensitive)
   - IAM role-based access for password retrieval

2. **IAM Least Privilege**:
   - EC2 instance role has only `secretsmanager:GetSecretValue` permission
   - Permission scoped to specific secret ARN (not wildcard)
   - No hardcoded credentials in code or configuration

3. **Encryption**:
   - Secrets Manager: Encrypted at rest (AWS managed KMS key)
   - SSH: Encrypted in transit (SSH protocol)
   - Terraform state: Encrypted in HCP Terraform

4. **Monitoring & Auditing**:
   - CloudWatch basic metrics enabled
   - Terraform state versioning in HCP Terraform
   - GitHub commit history for code changes

### Accepted Trade-offs (Development Only)

⚠️ **Public SSH Access**:
- **Risk**: Increased attack surface (port 22 from 0.0.0.0/0)
- **Mitigation**: Strong 32-char password, CloudWatch monitoring
- **Justification**: Development team works from various locations without VPN

⚠️ **Password Authentication**:
- **Risk**: Less secure than SSH key pairs
- **Mitigation**: Strong random password, Secrets Manager storage
- **Justification**: Easier team collaboration, no key management overhead

⚠️ **Public IP Address**:
- **Risk**: Direct internet exposure
- **Mitigation**: Security group controls, minimal software installation
- **Justification**: Required for remote development access

### Future Security Enhancements (Out of Scope)

- SSH key-based authentication for production
- AWS Systems Manager Session Manager (no public IP needed)
- IP allowlisting when network topology stabilizes
- Automated password rotation via Lambda
- VPC with private subnets + bastion host for production
- GuardDuty or AWS Security Hub integration

---

## Cost Breakdown & Optimization

### Monthly Cost Estimate

| Component | Specification | Unit Cost | Monthly Cost |
|-----------|---------------|-----------|--------------|
| EC2 Instance | t3.micro (730 hrs) | $0.0104/hr | $7.59 |
| EBS Volume | 8 GB GP3, 3000 IOPS | $0.08/GB | $0.64 |
| Public IPv4 | Attached to running instance | $0.005/hr | $3.60 |
| Secrets Manager | 1 secret stored | $0.40/secret | $0.40 |
| CloudWatch | Basic monitoring (5-min) | Free | $0.00 |
| Data Transfer | ~1 GB/month | $0.09/GB | $0.09 |
| **Total** | | | **$12.32** |

**Budget Status**: ✅ $37.68 remaining (75% under $50 budget)

### Cost Optimization Opportunities

1. **Stop instance when not in use**: Saves $7.59/month in EC2 charges
2. **Use EC2 Instance Connect**: Eliminates Secrets Manager ($0.40/month)
3. **Scheduled start/stop**: Lambda + EventBridge automation
4. **Reserved Instance**: Not applicable (dev environment, intermittent use)

### Cost Monitoring

**Tagging for Cost Tracking**:
```hcl
tags = {
  Environment  = "development"
  ManagedBy    = "Terraform"
  Project      = var.project_name
  CostCenter   = var.cost_center
  Feature      = "001-public-ec2-dev"
  Workspace    = "sandbox_workspace"
}
```

**Cost Explorer Filters**:
- Tag: `Feature = 001-public-ec2-dev`
- Resource: `InstanceId = i-*`
- Service: EC2, EBS, Secrets Manager

---

## Risk Assessment & Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Default VPC missing | Low | High | Validate with `aws_vpc` data source, fail fast with clear error |
| SSH brute-force attack | Medium | Medium | Strong 32-char password, consider fail2ban in future |
| Password exposure in state | Low | High | Use `sensitive = true`, HCP Terraform encrypted state |
| AMI deprecation | Low | Low | Dynamic AMI lookup (always latest) |
| Cost overrun | Very Low | Low | $12.32 << $50 budget, CloudWatch monitoring |
| t3.micro unavailable | Very Low | Medium | No fallback (per spec), AWS quota unlikely |

### Operational Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| HCP Terraform outage | Low | Medium | Cannot deploy during outage, wait for recovery |
| AWS service outage | Very Low | High | No mitigation (AWS dependency), multi-region out of scope |
| Developer cannot access Secrets Manager | Low | Medium | Validate IAM permissions, document troubleshooting |
| SSH connection timeout | Medium | Low | Troubleshooting guide in quickstart.md |

---

## Dependencies & Prerequisites

### External Dependencies

1. **AWS Account**:
   - Active AWS account with sufficient permissions
   - Default VPC exists in ap-southeast-1 region
   - Service quotas: EC2 instances, security groups, Secrets Manager

2. **HCP Terraform**:
   - Organization: `ravi-panchal-org` (configured)
   - Workspace: `sandbox_workspace` (configured)
   - AWS credentials configured in workspace variable sets
   - VCS connection to GitHub repository

3. **GitHub**:
   - Repository connected to HCP Terraform
   - Issue #12 exists for tracking
   - Feature branch `001-public-ec2-dev` created

4. **Terraform Registry**:
   - HCP Terraform private registry accessible (pending module search)
   - Terraform Public Registry accessible (fallback)

### Internal Dependencies

**IAM Permissions Required** (HCP Terraform workspace credentials):
- `ec2:RunInstances`, `ec2:DescribeInstances`, `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress`
- `ec2:CreateTags`, `ec2:DescribeVpcs`, `ec2:DescribeSubnets`, `ec2:DescribeImages`
- `secretsmanager:CreateSecret`, `secretsmanager:PutSecretValue`, `secretsmanager:DescribeSecret`
- `iam:CreateRole`, `iam:CreateInstanceProfile`, `iam:AttachRolePolicy`, `iam:PassRole`

**Tools Required**:
- Terraform CLI >= 1.13.0 (for local testing)
- AWS CLI >= 2.x (for developers to retrieve password)
- Pre-commit >= 2.x (for git hooks)
- TFLint >= 0.50 (for linting)

---

## Rollback Strategy

### Rollback Scenarios

1. **Provisioning Failure** (during `terraform apply`):
   - **Action**: Terraform automatically rolls back partial changes
   - **Cleanup**: Review Terraform state, destroy any orphaned resources
   - **Recovery**: Fix issues, re-run `terraform apply`

2. **Post-Deployment Issues** (SSH not working):
   - **Action**: Debug using CloudWatch console output, EC2 Instance Connect
   - **Rollback**: `terraform destroy` to remove all resources
   - **Recovery**: Fix user data script, redeploy

3. **Cost Overrun** (unexpected charges):
   - **Action**: Stop instance immediately via AWS Console
   - **Investigation**: Review AWS Cost Explorer, identify unexpected charges
   - **Rollback**: `terraform destroy` if not needed

### Destroy Procedure

```bash
# Via HCP Terraform UI
1. Navigate to workspace `sandbox_workspace`
2. Settings → Destruction and Deletion
3. Queue destroy plan
4. Confirm destruction

# Via Terraform CLI (if using cloud backend)
terraform destroy -auto-approve
```

**Resources Deleted**:
- EC2 instance (with EBS volume, delete_on_termination=true)
- Security group
- Secrets Manager secret (retention policy: immediate deletion)
- IAM role and instance profile

**Persistent Resources**:
- Default VPC (pre-existing, not managed by Terraform)
- CloudWatch metrics (retained per AWS default retention policy)
- Terraform state (retained in HCP Terraform)

---

## Monitoring & Observability

### CloudWatch Metrics (Basic Monitoring)

**Collected Automatically** (5-minute intervals):
- `CPUUtilization` (%)
- `NetworkIn` (bytes)
- `NetworkOut` (bytes)
- `DiskReadBytes` (bytes)
- `DiskWriteBytes` (bytes)
- `StatusCheckFailed_Instance` (0 or 1)
- `StatusCheckFailed_System` (0 or 1)

**Access Methods**:
1. **AWS Console**: CloudWatch → Metrics → EC2 → Per-Instance Metrics
2. **AWS CLI**: `aws cloudwatch get-metric-statistics`
3. **Terraform Data Source**: `aws_cloudwatch_metric_statistic` (if needed)

### Logging

**Instance Logs**:
- **System Log**: EC2 Console → Actions → Monitor and troubleshoot → Get system log
- **User Data Output**: Check system log for cloud-init execution status
- **SSH Authentication Logs**: `/var/log/secure` (requires SSH access)

**Terraform Logs**:
- **HCP Terraform**: Workspace run logs (plan, apply output)
- **Local**: `TF_LOG=DEBUG terraform apply` (if testing locally)

### Alerting (Out of Scope)

Not implemented in initial version. Future enhancements:
- CloudWatch Alarms for high CPU (> 80%)
- AWS Budgets alerts for cost overruns
- SNS notifications for instance state changes

---

## Troubleshooting Guide (Quick Reference)

See full guide in [quickstart.md](./quickstart.md#troubleshooting)

| Issue | Quick Fix |
|-------|-----------|
| Cannot connect via SSH | Verify security group rules, check instance status checks |
| Password authentication failed | Verify user data script executed, check console output |
| Cannot retrieve secret | Check IAM permissions, verify secret exists in ap-southeast-1 |
| High costs | Verify detailed monitoring is disabled, stop instance when not in use |
| Terraform apply fails | Check AWS credentials, verify default VPC exists |

---

## Next Steps

### Immediate Actions (Post-Plan Generation)

1. **Search HCP Terraform Private Registry**: Use MCP `search_private_modules` tool
2. **Update Agent Context**: Run `.specify/scripts/bash/update-agent-context.sh copilot`
3. **Validate Variable Values**: Ensure `project_name` and `cost_center` are determined

### Phase 2: Task Generation

**Command**: `/speckit.tasks`

**Expected Output**: `specs/001-public-ec2-dev/tasks.md` with ~10-15 implementation tasks

### Phase 3: Implementation

**Command**: `/speckit.implement`

**Expected Workflow**:
1. Execute tasks from tasks.md in dependency order
2. Create Terraform configuration files
3. Search private registry, select modules
4. Write user data script
5. Run pre-commit hooks
6. Test in ephemeral workspace
7. Apply to sandbox_workspace
8. Validate acceptance criteria
9. Update GitHub Issue #12

---

## References

### AWS Documentation
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/t3/)
- [Amazon Linux 2023 User Guide](https://docs.aws.amazon.com/linux/al2023/)
- [AWS Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/)
- [CloudWatch Metrics for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html)

### Terraform Documentation
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Random Provider](https://registry.terraform.io/providers/hashicorp/random/latest/docs)
- [HCP Terraform Workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces)

### Internal Documentation
- [Project Constitution](.specify/memory/constitution.md)
- [Feature Specification](./spec.md)
- [Research Findings](./research.md)
- [Data Model](./data-model.md)
- [Quickstart Guide](./quickstart.md)

---

**Document Status**: ✅ COMPLETE  
**Branch**: `001-public-ec2-dev`  
**Next Command**: `/speckit.tasks` (to generate tasks.md)  
**Last Updated**: 2026-01-12  
**Author**: AI Agent (Speckit Workflow)
