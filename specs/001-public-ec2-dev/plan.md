# Implementation Plan: Public EC2 Instance with Password Authentication

**Branch**: `001-public-ec2-dev` | **Date**: 2025-01-17 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-public-ec2-dev/spec.md`  
**GitHub Issue**: #15

## Summary

This implementation plan provisions a public EC2 t3.micro instance in ap-southeast-1 with username/password SSH authentication for development purposes. The solution leverages private registry modules from `ravi-panchal-org` for EC2, security groups, CloudWatch, and IAM resources, achieving a module-first architecture that aligns with the project constitution. The instance uses Amazon Linux 2023 (latest via SSM parameter), has an 8GB encrypted GP3 root volume, and integrates with CloudWatch Logs for basic monitoring. Total monthly cost is estimated at $10-15, well under the $50 budget constraint.

## Technical Context

**Language/Version**: HCL (Terraform) ~> 1.5.0  
**Primary Dependencies**: 
- Terraform AWS Provider ~> 5.0
- Private Modules:
  - `app.terraform.io/ravi-panchal-org/ec2-instance/aws` v6.1.4
  - `app.terraform.io/ravi-panchal-org/security-group/aws` v5.3.1 (optional, using ec2-instance built-in)
  - `app.terraform.io/ravi-panchal-org/cloudwatch/aws` v5.7.2
  - `app.terraform.io/ravi-panchal-org/iam/aws` v6.2.3 (optional, using ec2-instance built-in)

**Storage**: 8GB GP3 EBS (encrypted with AWS-managed keys), delete-on-termination enabled  
**Testing**: Terraform validate, tflint, pre-commit hooks, manual SSH connectivity tests  
**Target Platform**: AWS EC2 (ap-southeast-1 region), Amazon Linux 2023 x86_64  
**Project Type**: Infrastructure as Code (Terraform root module)  
**Performance Goals**: 
- Instance provisioning: <5 minutes from apply to SSH-ready
- SSH connection: <30 seconds from password entry to shell access
- CloudWatch log ingestion: <5 minutes from instance launch

**Constraints**: 
- Monthly cost: <$50 (actual: ~$10-15)
- Network: Default VPC/subnet required (must pre-exist)
- Region: ap-southeast-1 only
- Authentication: Password-based SSH (development only, not production-grade)
- No termination protection (ephemeral dev environment)

**Scale/Scope**: 
- Single EC2 instance (stateless development environment)
- Single security group, single IAM role, single CloudWatch log group
- Expected lifespan: Ephemeral (hours to days)
- No high availability, auto-scaling, or backup requirements

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Module-First Architecture (Constitution §1.1)

**Status**: PASS

**Evidence**:
- All infrastructure provisioned through private registry modules:
  - EC2 instance: `app.terraform.io/ravi-panchal-org/ec2-instance/aws` v6.1.4
  - CloudWatch log group: `app.terraform.io/ravi-panchal-org/cloudwatch/aws` v5.7.2
- Module sources strictly follow `app.terraform.io/<org-name>/` format
- Zero raw AWS provider resources (all encapsulated in modules)
- Semantic versioning constraints: `version = "~> 6.1.4"`

**Justification**: N/A (no violations)

---

### ✅ Specification-Driven Development (Constitution §1.2)

**Status**: PASS

**Evidence**:
- Complete feature specification: `/specs/001-public-ec2-dev/spec.md`
- All requirements explicitly documented (FR-001 through FR-021)
- Phase 0 research completed: `research.md` resolves all technical unknowns
- Phase 1 design artifacts: `data-model.md`, `contracts/`, `quickstart.md`
- Terraform code will include requirement references in comments

**Justification**: N/A (no violations)

---

### ✅ Security-First Automation (Constitution §1.3)

**Status**: PASS

**Evidence**:
- No static credentials in code (AWS provider uses HCP Terraform workspace variable sets)
- Password generated using Terraform `random_password` resource (not hardcoded)
- Password marked as sensitive in outputs (not displayed in console)
- EBS root volume encrypted using AWS-managed KMS keys
- IAM instance profile uses least privilege (CloudWatchAgentServerPolicy only)
- Security group limits SSH to port 22 (all other ports implicitly denied)

**Security Considerations**:
- Password authentication acceptable for development environment (per spec)
- SSH from 0.0.0.0/0 acceptable for development environment (per spec)
- Production environments should use key-based auth and IP whitelisting

**Justification**: N/A (no violations; development security model per specification)

---

### ✅ HCP Terraform Prerequisites (Constitution §2.1)

**Status**: PASS

**Evidence**:
- Organization: `ravi-panchal-org` (specified in user requirements)
- Project: `Default Project` (specified in user requirements)
- Workspace: `sandbox_public_ec2_dev` (specified in user requirements)
- All HCP Terraform context determined before implementation

**Justification**: N/A (no violations)

---

### Gate Summary

| Gate | Status | Violations | Risk |
|------|--------|------------|------|
| Module-First Architecture | ✅ PASS | 0 | None |
| Specification-Driven Development | ✅ PASS | 0 | None |
| Security-First Automation | ✅ PASS | 0 | None |
| HCP Terraform Prerequisites | ✅ PASS | 0 | None |

**Overall**: ✅ **APPROVED** - Proceed to Phase 0 research

**Re-check After Phase 1**: Constitution compliance re-validated post-design (see below)

---

### Post-Design Re-check (After Phase 1)

*Re-validation after completing research, data model, and contracts*

#### ✅ Module-First Architecture

**Status**: PASS (Re-validated)

**Phase 1 Evidence**:
- Data model confirms all entities map to module outputs
- Contracts specify module interfaces (inputs/outputs)
- Zero raw resource usage planned in implementation
- Module capabilities sufficient for all requirements (no gaps requiring raw resources)

#### ✅ Specification-Driven Development

**Status**: PASS (Re-validated)

**Phase 1 Evidence**:
- Research document resolves all "NEEDS CLARIFICATION" items
- Data model defines all entities from specification
- Contracts specify interfaces for Terraform outputs and user data script
- Quickstart guide provides deployment workflow

#### ✅ Security-First Automation

**Status**: PASS (Re-validated)

**Phase 1 Evidence**:
- User data contract specifies password injection via Terraform template (not plaintext)
- CloudWatch IAM permissions limited to CloudWatchAgentServerPolicy
- No credentials stored on instance or in code
- EBS encryption enforced in data model

#### ✅ HCP Terraform Prerequisites

**Status**: PASS (Re-validated)

**Phase 1 Evidence**:
- All documentation references correct organization/project/workspace
- Quickstart guide validates HCP Terraform access as prerequisite
- Module sources reference private registry with org context

**Final Approval**: ✅ **APPROVED** - Proceed to Phase 2 task generation

## Project Structure

### Documentation (this feature)

```text
specs/001-public-ec2-dev/
├── spec.md                                  # Feature specification (user stories, requirements)
├── plan.md                                  # This file (implementation plan)
├── research.md                              # Phase 0: Technology research and decisions
├── data-model.md                            # Phase 1: Entity definitions and relationships
├── quickstart.md                            # Phase 1: Deployment guide
├── contracts/
│   ├── terraform-outputs-contract.md        # Output specifications
│   └── user-data-contract.md                # User data script specification
└── tasks.md                                 # Phase 2: Implementation tasks (not yet created)
```

### Source Code (repository root)

```text
.
├── main.tf                      # Primary Terraform configuration
│   ├── module "ec2_instance"    # EC2 instance with integrated security group, IAM
│   ├── module "cloudwatch_log_group"  # CloudWatch Logs configuration
│   ├── data "aws_vpc"           # Default VPC discovery
│   ├── data "aws_subnets"       # Default subnet discovery
│   └── resource "random_password"  # Password generation
│
├── outputs.tf                   # Terraform outputs (IP, instance ID, password, etc.)
├── variables.tf                 # Input variables (region, instance type, tags)
├── user_data.sh.tftpl          # User data template script
├── versions.tf                  # Provider and Terraform version constraints
├── terraform.tfvars             # Variable values (excluded from git)
│
├── .tflint.hcl                 # TFLint configuration
├── .pre-commit-config.yaml     # Pre-commit hooks configuration
├── .gitignore                  # Git ignore patterns (includes *.tfvars)
│
└── README.md                   # Repository documentation
```

**Structure Decision**: Single Terraform root module (not a reusable module)

This is a standalone Terraform configuration for a specific use case (public dev EC2 instance), not intended for reuse across multiple environments. All resources are defined in the root module with minimal abstraction. This approach is appropriate because:

1. **Single Environment**: This is a development-only configuration for a specific workspace (`sandbox_public_ec2_dev`)
2. **No Reusability Requirement**: Specification does not require multi-environment or multi-region deployment
3. **Simplicity Over Abstraction**: Direct resource definitions are clearer than layered modules for one-off infrastructure
4. **Module Consumption**: We consume tested modules from private registry rather than creating new wrapper modules

If this configuration were to be reused across multiple environments, it would be refactored into a reusable module structure with parameterized inputs.

## Complexity Tracking

No constitutional violations requiring justification. This implementation strictly adheres to all constitution principles:

- Module-first architecture: 100% module usage from private registry
- Specification-driven: Complete spec.md with FR-001 through FR-021
- Security-first: No static credentials, encrypted storage, least privilege IAM
- HCP Terraform: All prerequisites validated before implementation

**Complexity Score**: Low (single instance, single region, ephemeral dev environment)

---

## Phase 0: Research Summary

**Status**: ✅ COMPLETE

**Output**: `research.md` (15.5 KB)

**Key Decisions**:

1. **Module Selection**: ec2-instance module v6.1.4 as primary component
   - Integrated security group creation
   - Built-in IAM instance profile support
   - SSM parameter-based AMI discovery

2. **VPC Discovery**: AWS provider data sources (aws_vpc, aws_subnets)
   - Dynamic discovery of default VPC
   - No module available for data source queries (correct tool)

3. **AMI Selection**: SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
   - Auto-updates to latest AL2023
   - Natively supported by ec2-instance module

4. **Password Authentication**: User data script approach
   - Modify /etc/ssh/sshd_config
   - Create devuser with Terraform-generated password
   - Idempotent with error logging

5. **CloudWatch Integration**: Hybrid approach
   - CloudWatch module for log group creation
   - User data script for agent configuration/startup
   - Minimizes cost with basic monitoring only

6. **IAM Permissions**: Module-integrated instance profile
   - CloudWatchAgentServerPolicy (AWS-managed)
   - Least privilege for CloudWatch access only

7. **EBS Encryption**: AWS-managed keys
   - Free tier, automatic rotation
   - No custom KMS key required

8. **Security Group**: Module-integrated creation
   - SSH port 22 from 0.0.0.0/0
   - Appropriate for development environment

**Research Validation**: All "NEEDS CLARIFICATION" items resolved. Zero unknowns remaining.

---

## Phase 1: Design Summary

**Status**: ✅ COMPLETE

**Outputs**:
- `data-model.md` (17.3 KB) - Entity definitions and relationships
- `contracts/terraform-outputs-contract.md` (10.7 KB) - Output specifications
- `contracts/user-data-contract.md` (14.6 KB) - User data script contract
- `quickstart.md` (11.7 KB) - Deployment guide

### Data Model Highlights

**Core Entities**:
1. EC2 Instance (t3.micro, public IP, Amazon Linux 2023)
2. Security Group (SSH from 0.0.0.0/0)
3. IAM Instance Profile (CloudWatchAgentServerPolicy)
4. EBS Root Volume (8GB GP3 encrypted)
5. User Credentials (devuser + 16-char password)
6. CloudWatch Log Group (/aws/ec2/sandbox_public_ec2_dev)
7. VPC (data source, default VPC)
8. Subnet (data source, default subnet)
9. AMI (data source, AL2023 via SSM parameter)

**Entity Relationships**:
- EC2 Instance → Security Group (1:1 attached)
- EC2 Instance → IAM Instance Profile (1:1 uses)
- EC2 Instance → EBS Volume (1:1 has)
- EC2 Instance → Subnet (N:1 belongs to)
- Security Group → VPC (N:1 belongs to)
- CloudWatch Log Group → EC2 Instance (1:N receives logs from)

**State Management**:
- Terraform state in HCP Terraform workspace (encrypted)
- Computed attributes: instance_id, public_ip, volume_id, security_group_id
- Dependencies: CloudWatch log group must exist before instance launch
- Lifecycle: Instance ephemeral, log group persists after termination

### Contract Highlights

**Terraform Outputs** (7 outputs):
1. `instance_public_ip` (string, non-sensitive) - SSH target
2. `instance_id` (string, non-sensitive) - AWS resource ID
3. `ssh_username` (string, non-sensitive) - Fixed: "devuser"
4. `ssh_password` (string, **sensitive**) - 16-char generated
5. `cloudwatch_log_group_name` (string, non-sensitive) - Log monitoring
6. `security_group_id` (string, non-sensitive) - Firewall identification
7. `iam_instance_profile_arn` (string, non-sensitive) - IAM verification

**User Data Script Contract**:
- Bash shell, executed as root at first boot
- Idempotent with error logging to /var/log/user-data.log
- Seven functional requirements (FR-1 through FR-7):
  1. Error handling and logging
  2. Create devuser account
  3. Set devuser password
  4. Enable SSH password authentication
  5. Restart SSH service
  6. Configure CloudWatch agent
  7. Start CloudWatch agent
- Validation tests included (unit + integration)

### Quickstart Highlights

**Deployment Workflow**:
1. Clone repository and checkout branch
2. `terraform init` (downloads modules)
3. `terraform plan` (preview changes)
4. `terraform apply` (deploy infrastructure)
5. `terraform output ssh_password` (retrieve credentials)
6. SSH to instance: `ssh devuser@<public_ip>`

**Estimated Times**:
- Total deployment: 3-5 minutes
- Instance launch: 2-3 minutes
- User data execution: 30-60 seconds

**Cost Estimate**: $10-15/month (well under $50 budget)

**Troubleshooting Guide**: Covers 6 common issues:
- Default VPC not found
- SSH connection refused
- Permission denied (publickey)
- Password authentication failed
- No logs in CloudWatch
- Instance quota exceeded

---

## Architecture Decisions

### ADR-001: Use ec2-instance Module as Primary Component

**Context**: Need to provision EC2 instance with security group, IAM profile, and user data

**Decision**: Use `app.terraform.io/ravi-panchal-org/ec2-instance/aws` v6.1.4 as single module rather than composing separate EC2, security-group, and IAM modules

**Rationale**:
- Module provides integrated security group creation (`create_security_group = true`)
- Module provides integrated IAM instance profile creation (`create_iam_instance_profile = true`)
- Reduces inter-module dependencies and output/variable passing
- Consolidates configuration in one module call
- Module is actively maintained and tested

**Consequences**:
- ✅ Simpler configuration (fewer modules to coordinate)
- ✅ Fewer Terraform resources (no separate module blocks)
- ✅ Clearer dependency graph
- ❌ Less modular (harder to reuse security group independently)
- ❌ More coupled (changing security group requires module parameter changes)

**Status**: Accepted

---

### ADR-002: Use AWS Provider Data Sources for VPC/Subnet Discovery

**Context**: Need to identify existing default VPC and subnet without creating new network infrastructure

**Decision**: Use `data "aws_vpc"` and `data "aws_subnets"` with `default = true` filter

**Rationale**:
- Data sources are the correct Terraform tool for querying existing infrastructure
- Default VPC is guaranteed to exist in AWS accounts (unless manually deleted)
- No private module available for data source queries (would be inappropriate)
- Dynamic discovery works across accounts/regions without hardcoded IDs
- Aligns with constitution (data sources are read-only, not infrastructure creation)

**Alternatives Considered**:
- Hard-coded VPC/subnet IDs → Rejected (brittle, fails across accounts)
- VPC creation module → Rejected (out of scope, violates spec requirement for default VPC)

**Consequences**:
- ✅ Works across AWS accounts without modification
- ✅ No hardcoded infrastructure IDs
- ✅ Fails fast with clear error if default VPC missing
- ❌ Requires default VPC to exist (documented in prerequisites)

**Status**: Accepted

---

### ADR-003: Use SSM Parameter for AMI Discovery

**Context**: Need to automatically select latest Amazon Linux 2023 AMI without manual updates

**Decision**: Use SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` via ec2-instance module's `ami_ssm_parameter` input

**Rationale**:
- AWS maintains SSM parameters with latest AMI IDs
- Parameter automatically updates when new AMIs are released
- ec2-instance module natively supports SSM parameter lookup
- Eliminates need for separate `data "aws_ami"` resource
- Follows AWS best practice for AMI discovery

**Alternatives Considered**:
- `data "aws_ami"` with filters → Rejected (more verbose, module supports SSM natively)
- Static AMI ID → Rejected (requires manual updates for security patches)

**Consequences**:
- ✅ Always uses latest AL2023 AMI (automatic security updates)
- ✅ Simpler configuration (one parameter vs. multiple filters)
- ✅ No separate data source needed
- ❌ Relies on AWS maintaining SSM parameter (low risk, AWS commitment)

**Status**: Accepted

---

### ADR-004: Use User Data Script for Password Authentication

**Context**: Need to enable SSH password authentication and create devuser account

**Decision**: Implement bash user data script with Terraform templatefile function to inject password

**Rationale**:
- Amazon Linux 2023 defaults to key-based SSH only (password auth disabled)
- User data scripts execute as root at instance launch (perfect for system configuration)
- Terraform `templatefile()` allows secure password injection without hardcoding
- Idempotent script design allows re-execution without errors
- CloudWatch logging provides troubleshooting visibility

**Alternatives Considered**:
- AWS Systems Manager Run Command → Rejected (requires SSM agent ready, adds complexity)
- EC2 Instance Connect → Rejected (doesn't support password auth, requires IAM)
- Pre-baked AMI → Rejected (AMI creation out of scope, reduces flexibility)

**Consequences**:
- ✅ Works immediately at instance launch
- ✅ No external dependencies (runs before any remote access)
- ✅ Password never visible in process list (piped to chpasswd)
- ❌ Runs only once at first boot (instance replacement required for changes)
- ❌ User data changes don't trigger instance replacement (unless configured)

**Status**: Accepted

---

### ADR-005: Hybrid Approach for CloudWatch Integration

**Context**: Need to create log group and configure CloudWatch agent

**Decision**: Use CloudWatch module for log group creation + user data script for agent configuration

**Rationale**:
- CloudWatch module creates log group with proper settings
- CloudWatch agent is pre-installed on AL2023 but requires configuration
- User data script is ideal for one-time agent setup at launch
- Separating log group creation ensures it exists before agent starts
- Module usage aligns with constitution (avoid raw aws_cloudwatch_log_group resource)

**Alternatives Considered**:
- CloudWatch module for both → Rejected (module doesn't support agent installation)
- Raw aws_cloudwatch_log_group resource → Rejected (violates module-first constitution)
- Manual log group creation → Rejected (not infrastructure as code)

**Consequences**:
- ✅ Log group exists before instance launch (prevents agent errors)
- ✅ Agent configuration in version control (user data template)
- ✅ Follows module-first architecture
- ❌ Split responsibility (module + user data script)

**Status**: Accepted

---

### ADR-006: Use Module-Integrated IAM Instance Profile

**Context**: Need IAM permissions for CloudWatch agent to write logs/metrics

**Decision**: Use ec2-instance module's `create_iam_instance_profile = true` with `iam_role_policies` map

**Rationale**:
- Module supports creating IAM role + instance profile + policy attachments
- CloudWatchAgentServerPolicy is AWS-managed (no custom policy needed)
- Least privilege (only CloudWatch permissions)
- Simpler than separate IAM module (fewer outputs to coordinate)

**Alternatives Considered**:
- Separate IAM module → Rejected (unnecessary complexity, module has built-in support)
- Custom IAM policy → Rejected (AWS-managed policy is maintained and sufficient)
- No IAM profile → Rejected (CloudWatch agent requires permissions)

**Consequences**:
- ✅ Least privilege (only CloudWatch access)
- ✅ AWS-managed policy (automatically updated by AWS)
- ✅ Single module configuration
- ❌ Tightly coupled to ec2-instance module

**Status**: Accepted

---

### ADR-007: Disable Termination Protection

**Context**: Development environment needs easy cleanup

**Decision**: Set `disable_api_termination = false` (termination protection disabled)

**Rationale**:
- Development environment is ephemeral (hours to days)
- No production data or critical workloads
- Easy cleanup via `terraform destroy` required
- Specification explicitly states "disable instance termination protection" (FR-021)
- Cost optimization (avoid forgetting to delete instance)

**Alternatives Considered**:
- Enable termination protection → Rejected (contradicts spec, complicates cleanup)

**Consequences**:
- ✅ Easy cleanup via `terraform destroy`
- ✅ No manual console steps to disable protection
- ✅ Aligns with ephemeral dev environment model
- ❌ Accidental deletion risk (acceptable for dev environment)

**Status**: Accepted

---

### ADR-008: Use AWS-Managed KMS Keys for EBS Encryption

**Context**: Need EBS root volume encryption for security compliance

**Decision**: Use AWS-managed KMS key (`aws/ebs`) instead of customer-managed key

**Rationale**:
- AWS-managed keys are free (no monthly cost)
- Automatic key rotation managed by AWS
- Sufficient encryption for development environment
- No additional KMS permissions required
- Specification does not require custom KMS key

**Alternatives Considered**:
- Customer-managed KMS key → Rejected ($1/month cost, adds complexity, not required)
- No encryption → Rejected (security best practice, spec requires encryption)

**Consequences**:
- ✅ Free tier (no KMS costs)
- ✅ Automatic key rotation by AWS
- ✅ No additional IAM permissions needed
- ❌ Cannot set custom key rotation schedule
- ❌ Cannot use key for cross-account access (not needed)

**Status**: Accepted

---

## Technology Stack

### Infrastructure as Code

| Component | Version | Purpose |
|-----------|---------|---------|
| Terraform | ~> 1.5.0 | Infrastructure provisioning |
| HCL2 | Latest | Terraform configuration language |
| HCP Terraform | SaaS | Remote state, execution environment |

### Terraform Providers

| Provider | Version | Purpose |
|----------|---------|---------|
| hashicorp/aws | ~> 5.0 | AWS resource management |
| hashicorp/random | ~> 3.0 | Password generation |

### Private Registry Modules

| Module | Version | Purpose |
|--------|---------|---------|
| ravi-panchal-org/ec2-instance/aws | ~> 6.1.4 | EC2 instance + security group + IAM |
| ravi-panchal-org/cloudwatch/aws | ~> 5.7.2 | CloudWatch log group |

### AWS Services

| Service | Purpose | Cost |
|---------|---------|------|
| EC2 (t3.micro) | Compute instance | ~$7.50/month |
| EBS (8GB GP3) | Root volume storage | ~$0.80/month |
| CloudWatch Logs | System log collection | ~$2-5/month |
| CloudWatch Metrics | Basic instance monitoring | Free |
| IAM | Instance permissions | Free |
| VPC | Networking (default VPC) | Free |
| SSM Parameter Store | AMI discovery | Free |

**Total Estimated Cost**: ~$10-15/month (80% under budget)

### Operating System

| Component | Version | Purpose |
|-----------|---------|---------|
| Amazon Linux | 2023 (latest) | EC2 operating system |
| Kernel | 6.1+ | Linux kernel |
| SSH | OpenSSH 8.7+ | Remote access |
| CloudWatch Agent | Latest | Log/metric shipping |

### Development Tools

| Tool | Purpose |
|------|---------|
| AWS CLI v2 | Manual AWS operations, testing |
| Terraform CLI | Local development, testing |
| tflint | Terraform linting |
| pre-commit | Git commit hooks |
| sshpass (optional) | Non-interactive SSH testing |

---

## Testing Strategy

### Validation Levels

1. **Terraform Validation**
   - `terraform validate` - Syntax and configuration validation
   - `terraform plan` - Preview changes before apply
   - `tflint` - Linting for best practices and errors

2. **Module Contract Testing**
   - Verify module inputs match documented contracts
   - Verify module outputs are accessible
   - Validate module versions are compatible

3. **Infrastructure Testing**
   - Terraform apply succeeds with zero errors
   - All resources reach desired state (running, active, etc.)
   - Outputs are populated with expected values

4. **Integration Testing**
   - SSH connection succeeds with username/password
   - CloudWatch log stream created within 5 minutes
   - Instance monitoring metrics appear in CloudWatch
   - Security group rules allow SSH, block other ports

5. **User Acceptance Testing**
   - Developer can SSH to instance within 5 minutes of apply
   - Password authentication works on first attempt
   - Instance is accessible from various public IPs
   - CloudWatch logs show recent system messages

### Test Execution

**Pre-Commit Tests** (automated):
```bash
# Run via pre-commit hook
terraform fmt -check
terraform validate
tflint
```

**Deployment Tests** (manual):
```bash
# Step 1: Validate configuration
terraform validate

# Step 2: Check plan output
terraform plan | grep "Plan:"
# Expected: Plan: 7 to add, 0 to change, 0 to destroy

# Step 3: Apply and capture outputs
terraform apply -auto-approve
terraform output -json > outputs.json

# Step 4: Test SSH connectivity
ssh -o PreferredAuthentications=password \
    devuser@$(terraform output -raw instance_public_ip)
```

**Integration Tests** (automated via scripts):
```bash
#!/bin/bash
set -e

# Test 1: Verify instance is running
INSTANCE_STATE=$(aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)
[[ "$INSTANCE_STATE" == "running" ]] || exit 1

# Test 2: Verify SSH port is open
nc -zv $(terraform output -raw instance_public_ip) 22 || exit 1

# Test 3: Verify CloudWatch log stream exists
aws logs describe-log-streams \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --log-stream-name-prefix $(terraform output -raw instance_id) \
  --query 'logStreams[0].logStreamName' \
  --output text || exit 1

# Test 4: Verify SSH password authentication
sshpass -p "$(terraform output -raw ssh_password)" \
  ssh -o StrictHostKeyChecking=no \
  devuser@$(terraform output -raw instance_public_ip) \
  'echo "SSH test passed"' || exit 1

echo "All integration tests passed!"
```

---

## Deployment Workflow

### Pre-Deployment Checklist

- [ ] HCP Terraform workspace access confirmed
- [ ] AWS credentials configured in workspace
- [ ] Default VPC exists in ap-southeast-1
- [ ] EC2 instance quota available (t3.micro)
- [ ] Git branch `001-public-ec2-dev` checked out
- [ ] `terraform init` completed successfully

### Deployment Steps

1. **Initialize Terraform** (1 minute)
   ```bash
   terraform init
   ```
   Downloads modules from private registry

2. **Review Plan** (1 minute)
   ```bash
   terraform plan
   ```
   Preview 7 resources to be created

3. **Apply Configuration** (3-5 minutes)
   ```bash
   terraform apply
   ```
   Create all infrastructure resources

4. **Retrieve Credentials** (30 seconds)
   ```bash
   terraform output ssh_password
   ```
   Copy password for SSH access

5. **Verify SSH Access** (30 seconds)
   ```bash
   ssh devuser@$(terraform output -raw instance_public_ip)
   ```
   Enter password when prompted

6. **Verify CloudWatch Logs** (1 minute)
   ```bash
   aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow
   ```
   Confirm logs streaming

**Total Time**: ~7-10 minutes from init to verified access

### Post-Deployment Validation

✅ **Success Criteria** (must pass all):
- [ ] Terraform apply completed with 0 errors
- [ ] 7 resources created (1 instance, 1 SG, 1 IAM role, 1 IAM profile, 1 log group, 1 password, data sources)
- [ ] Instance state is "running"
- [ ] Public IP assigned and accessible
- [ ] SSH connection succeeds with password
- [ ] CloudWatch log stream created
- [ ] Recent logs visible in CloudWatch
- [ ] Security group has SSH rule (port 22, 0.0.0.0/0)
- [ ] IAM instance profile attached with CloudWatch policy
- [ ] EBS volume is 8GB GP3 encrypted

---

## Monitoring and Operations

### CloudWatch Metrics (Basic Monitoring)

**Automatically Collected** (5-minute intervals, free):
- CPUUtilization
- DiskReadOps
- DiskWriteOps
- NetworkIn
- NetworkOut
- StatusCheckFailed
- StatusCheckFailed_Instance
- StatusCheckFailed_System

**Access**:
```bash
# View CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$(terraform output -raw instance_id) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### CloudWatch Logs

**Log Group**: `/aws/ec2/sandbox_public_ec2_dev`  
**Log Stream**: `{instance_id}` (e.g., `i-0123456789abcdef0`)  
**Log Source**: `/var/log/messages`

**Access**:
```bash
# Tail logs (real-time)
aws logs tail /aws/ec2/sandbox_public_ec2_dev --follow

# View specific instance logs
aws logs get-log-events \
  --log-group-name /aws/ec2/sandbox_public_ec2_dev \
  --log-stream-name $(terraform output -raw instance_id) \
  --limit 100
```

### Operational Tasks

**Start/Stop Instance** (cost optimization):
```bash
# Stop instance (saves compute costs)
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)

# Start instance (new public IP assigned)
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)

# Get new public IP after start
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

**Password Rotation** (manual):
```bash
# Step 1: Taint password resource
terraform taint random_password.devuser

# Step 2: Apply changes (recreates password and updates user data)
terraform apply

# Step 3: Retrieve new password
terraform output ssh_password

# Note: Requires instance replacement to apply new password
```

**View User Data Logs**:
```bash
# Access instance via Session Manager
aws ssm start-session --target $(terraform output -raw instance_id)

# View user data execution log
sudo cat /var/log/user-data.log

# View cloud-init log
sudo cat /var/log/cloud-init-output.log
```

---

## Security Considerations

### Development vs. Production

**Current Configuration** (Development):
- ✅ Password authentication enabled
- ✅ SSH from 0.0.0.0/0 (any IP)
- ✅ No termination protection
- ✅ AWS-managed encryption keys
- ✅ Basic monitoring only

**Production Hardening** (if needed):
- ❌ Disable password authentication → Use SSH keys only
- ❌ Restrict SSH to specific IP ranges → Update security group CIDR
- ❌ Enable termination protection → Set `disable_api_termination = true`
- ❌ Use customer-managed KMS keys → Create CMK for encryption
- ❌ Enable detailed monitoring → Set `monitoring = true`
- ❌ Implement CloudWatch alarms → Add alarm resources
- ❌ Enable VPC Flow Logs → Add flow log resources
- ❌ Use IMDSv2 only → Already enforced by module (metadata_options.http_tokens = required)

### Security Best Practices Applied

1. **Encryption at Rest**: EBS root volume encrypted with AWS-managed keys
2. **Least Privilege IAM**: Instance profile limited to CloudWatchAgentServerPolicy
3. **No Static Credentials**: AWS provider uses workspace variable sets, password generated dynamically
4. **Sensitive Output Handling**: Password marked as sensitive in Terraform outputs
5. **IMDSv2 Enforcement**: Instance metadata requires session tokens (prevents SSRF)
6. **Security Group Minimalism**: Only SSH port 22 exposed, all others implicitly denied

### Compliance Notes

- **GDPR**: No personal data stored (development instance only)
- **SOC 2**: Encryption at rest, least privilege IAM, audit logging via CloudWatch
- **CIS Benchmarks**: Follows CIS Amazon Linux 2023 Benchmark recommendations where applicable
- **AWS Well-Architected**: Security pillar principles applied (encryption, IAM, monitoring)

---

## Cost Management

### Monthly Cost Breakdown

| Resource | Unit Cost | Quantity | Monthly Cost |
|----------|-----------|----------|--------------|
| t3.micro instance (ap-southeast-1) | $0.0104/hour | 730 hours | $7.59 |
| EBS GP3 storage | $0.10/GB-month | 8 GB | $0.80 |
| CloudWatch Logs ingestion | $0.50/GB (after 5GB free) | ~3 GB | $0.00 (within free tier) |
| CloudWatch Logs storage | $0.03/GB-month | ~3 GB | $0.09 |
| Data transfer OUT | $0.00/GB (first 1GB free) | ~0.5 GB | $0.00 |
| **TOTAL** | | | **$8.48/month** |

**Budget Utilization**: 17% of $50 budget (83% margin)

### Cost Optimization Strategies

1. **Stop When Not In Use**: Save ~$7.50/month on compute (keep $0.80/month storage)
2. **Delete After Session**: Full cost savings (remember to backup any data)
3. **Adjust Log Retention**: Default is indefinite, can set to 7/14/30 days for cost reduction
4. **Use Spot Instances**: ~70% discount (not recommended for dev due to interruptions)

### Cost Alerting

**Recommended CloudWatch Billing Alert**:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name ec2-cost-alert \
  --alarm-description "Alert when EC2 costs exceed $15" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 15 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ServiceName,Value=AmazonEC2
```

---

## Troubleshooting Guide

See [quickstart.md](./quickstart.md#troubleshooting) for detailed troubleshooting steps covering:

- Default VPC not found
- SSH connection refused
- Permission denied (publickey)
- Password authentication failed
- No logs in CloudWatch
- Instance quota exceeded

---

## Next Steps

This implementation plan is now complete. The next phase is **Phase 2: Task Generation** via the `/speckit.tasks` command, which will:

1. Break down implementation into atomic tasks
2. Order tasks by dependency
3. Define acceptance criteria per task
4. Estimate effort and complexity
5. Generate `tasks.md` for execution tracking

**Command**: `/speckit.tasks`

**Output**: `tasks.md` with dependency-ordered implementation tasks

---

## References

### Internal Documentation
- [Feature Specification](./spec.md)
- [Research Document](./research.md)
- [Data Model](./data-model.md)
- [Quickstart Guide](./quickstart.md)
- [Terraform Outputs Contract](./contracts/terraform-outputs-contract.md)
- [User Data Contract](./contracts/user-data-contract.md)

### AWS Documentation
- [Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/)
- [EC2 User Data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Default VPCs](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html)
- [CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)

### Module Documentation
- [ec2-instance v6.1.4](https://github.com/panchal-ravi/terraform-aws-ec2-instance)
- [cloudwatch v5.7.2](https://github.com/panchal-ravi/terraform-aws-cloudwatch)

### Terraform Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs)
- [Data Sources](https://developer.hashicorp.com/terraform/language/data-sources)

### Constitution
- [Project Constitution](./.specify/memory/constitution.md)

---

**Plan Status**: ✅ COMPLETE (Phase 0 + Phase 1)  
**Ready for**: Phase 2 - Task Generation (`/speckit.tasks`)  
**Branch**: 001-public-ec2-dev  
**Issue**: #15
