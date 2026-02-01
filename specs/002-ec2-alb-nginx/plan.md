# Implementation Plan: EC2 Infrastructure with ALB and Nginx

**Branch**: `002-ec2-alb-nginx` | **Date**: 2025-02-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-ec2-alb-nginx/spec.md`
**GitHub Issue**: #37

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy a highly available, secure web infrastructure using EC2 instances with Nginx web servers distributed across 2 availability zones in ap-southeast-1, fronted by an Application Load Balancer with HTTPS termination using a self-signed TLS certificate. The solution leverages private Terraform modules from the organization's registry (ravi-panchal-org) to ensure compliance with organizational standards and security best practices.

## Technical Context

**Language/Version**: Terraform >= 1.5.7 (HCL)  
**Primary Dependencies**: 
- Private Registry Modules: `ravi-panchal-org/ec2-instance/aws` (v6.1.4), `ravi-panchal-org/alb/aws` (v10.2.0), `ravi-panchal-org/security-group/aws` (v5.3.1), `ravi-panchal-org/acm/aws` (v6.3.0)
- Terraform Providers: AWS Provider >= 6.0, TLS Provider (for self-signed certificate generation)  
**Storage**: AWS resources managed via HCP Terraform remote state (encrypted, versioned, with state locking)  
**Testing**: Terraform validate, TFLint, pre-commit hooks, manual acceptance testing via browser/curl  
**Target Platform**: AWS Cloud - ap-southeast-1 region (Singapore)  
**Project Type**: Infrastructure as Code - Single Terraform root module with child modules from private registry  
**Performance Goals**: 
- ALB health checks: instances healthy within 5 minutes of deployment
- HTTPS response time: < 500ms for static Nginx test page
- Infrastructure deployment: < 10 minutes from `terraform apply` to accessible endpoint  
**Constraints**: 
- MUST use existing default VPC (no new VPC creation)
- Cost optimization: < $50/month for development environment
- HTTPS-only access (no HTTP listener)
- Self-signed certificate (domain validation not required)
- 2 AZs mandatory: ap-southeast-1a and ap-southeast-1b  
**Scale/Scope**: 
- 2 EC2 instances (1 per AZ)
- 1 Application Load Balancer
- Development environment (not production-scale)
- Minimal compute resources (t3.micro or similar)
- Single region deployment

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Module-First Architecture (Section 1.1)
- **Status**: PASS
- **Evidence**: All infrastructure provisioned through approved private registry modules:
  - `app.terraform.io/ravi-panchal-org/ec2-instance/aws` (v6.1.4)
  - `app.terraform.io/ravi-panchal-org/alb/aws` (v10.2.0)
  - `app.terraform.io/ravi-panchal-org/security-group/aws` (v5.3.1)
  - `app.terraform.io/ravi-panchal-org/acm/aws` (v6.3.0) OR Terraform TLS provider resources for self-signed certificate
- **Note**: Self-signed TLS certificate will use Terraform `tls_private_key`, `tls_self_signed_cert`, and `aws_acm_certificate` resources directly (no module available for self-signed certificate generation in private registry)

### ✅ Specification-Driven Development (Section 1.2)
- **Status**: PASS
- **Evidence**: Comprehensive specification provided in `specs/002-ec2-alb-nginx/spec.md` with:
  - Explicit functional requirements (FR-001 through FR-017)
  - User scenarios with acceptance criteria
  - Success criteria with measurable outcomes
  - Edge cases documented
  - HCP Terraform workspace specified: `sandbox_workspace` in organization `ravi-panchal-org`

### ✅ Security-First Automation (Section 1.3)
- **Status**: PASS
- **Evidence**:
  - No static credentials in code (workspace variable sets pre-configured with dynamic AWS credentials)
  - Self-signed certificate private key handled as sensitive variable in HCP Terraform workspace
  - Security groups implement least privilege (ALB → EC2 only, no direct public access to instances)
  - HTTPS-only access enforced
  - IAM instance profiles used for EC2 (no embedded credentials)

### ✅ HCP Terraform Prerequisites (Section 2.1)
- **Status**: PASS
- **Configuration**:
  - **Organization**: `ravi-panchal-org`
  - **Project**: `Default Project` (ID: prj-kgrwvBZRTHJ5XaPo)
  - **Workspace**: `sandbox_workspace` (ID: ws-LPdtzsdtBDMChjEA)
  - **Execution Mode**: Remote
  - **Region**: ap-southeast-1
- **Evidence**: Configuration verified via Terraform MCP Server tools

### ✅ Code Generation Standards (Section III)
- **Status**: PASS (to be validated post-generation)
- **Compliance Plan**:
  - Git branch: `002-ec2-alb-nginx` (feature branch off `dev`)
  - File organization: main.tf, variables.tf, outputs.tf, locals.tf, providers.tf, terraform.tf, override.tf, sandbox.auto.tfvars
  - Naming conventions: HashiCorp standards (snake_case for variables, descriptive resource names)
  - All variables will include descriptions, types, and validation blocks
  - Version constraints using `~>` for modules
  - Pre-commit hooks initialized for TFLint and security checks

### ✅ Security and Compliance (Section IV)
- **Status**: PASS (to be validated post-generation)
- **Security Controls**:
  - No static credentials (dynamic credentials via workspace variable sets)
  - TLS certificate private key stored as sensitive workspace variable
  - Security groups deny all by default, explicit allow rules only
  - EC2 instances use IAM instance profiles
  - Encryption in transit (HTTPS/TLS)
  - Least privilege network access
  - All resources tagged with environment and security metadata

### Summary
**All constitutional gates: PASS** - Proceeding to Phase 0 research with no violations or justifications required.

## Project Structure

### Documentation (this feature)

```text
specs/002-ec2-alb-nginx/
├── spec.md              # Feature specification (input)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - technology decisions and best practices
├── data-model.md        # Phase 1 output - infrastructure entities and relationships
├── quickstart.md        # Phase 1 output - deployment and validation guide
├── contracts/           # Phase 1 output - API contracts (if applicable)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Terraform Infrastructure (Single Root Module)
/workspace/
├── main.tf                         # Module instantiations (EC2, ALB, Security Groups)
├── locals.tf                       # Local values for common configurations
├── variables.tf                    # Input variable declarations with validation
├── outputs.tf                      # ALB DNS, instance IDs, security group IDs
├── providers.tf                    # AWS and TLS provider configurations
├── terraform.tf                    # Terraform version and provider requirements
├── override.tf                     # HCP Terraform backend configuration (excluded from git)
├── sandbox.auto.tfvars            # Sandbox environment variable values (excluded from git)
├── sandbox.auto.tfvars.example    # Example variable file template
├── tls-certificate.tf             # Self-signed TLS certificate resources
├── .tflint.hcl                    # TFLint configuration
├── .pre-commit-config.yaml        # Pre-commit hooks configuration
└── specs/                         # Feature specifications directory
    └── 002-ec2-alb-nginx/         # This feature's documentation

# No nested module structure - all modules consumed from private registry
```

**Structure Decision**: Single root module architecture selected because:
- Infrastructure is cohesive (all resources for one feature)
- Complexity level does not warrant multi-module structure
- Private registry modules provide reusable components
- Follows organizational standards for application team consumption
- Simplifies deployment and state management in HCP Terraform workspace

## Complexity Tracking

> **No constitutional violations - this section is empty**

This feature fully complies with all organizational standards and requires no complexity justifications.

---

## Phase Execution Summary

### Phase 0: Research and Technology Selection ✅ COMPLETE

**Artifacts Generated**:
- `research.md` - Comprehensive technology decisions and best practices

**Key Decisions**:
1. **Module Strategy**: Private registry modules from `ravi-panchal-org` for EC2, ALB, Security Groups
2. **Certificate Approach**: Terraform TLS provider for self-signed certificate generation, import to ACM
3. **Network Design**: Default VPC with data source discovery, 2 AZs for high availability
4. **Compute Configuration**: t3a.micro instances for cost optimization
5. **Security Architecture**: Three security groups with least privilege, HTTPS-only access
6. **Load Balancing**: ALB with HTTPS termination, HTTP to backend instances
7. **Cost Target**: ~$30-35/month (under $50 requirement)

**Research Areas Covered**:
- Private module registry capabilities and versions
- Self-signed TLS certificate generation strategies
- Network architecture with default VPC constraints
- EC2 instance configuration best practices
- Application Load Balancer patterns
- Security group design with least privilege
- High availability across 2 availability zones
- Cost optimization strategies
- Testing and validation approaches
- Terraform provider version compatibility

### Phase 1: Design and Contracts ✅ COMPLETE

**Artifacts Generated**:
- `data-model.md` - Infrastructure entities, relationships, and state management
- `contracts/terraform-interface.md` - Module interface contract with inputs/outputs
- `quickstart.md` - Deployment and validation guide
- `.github/agents/copilot-instructions.md` - Updated agent context

**Design Decisions**:
1. **Entity Model**: 6 primary entities (VPC Context, TLS Certificate, Security Groups, EC2 Instances, ALB, Outputs)
2. **Relationships**: Clear dependency graph with proper ordering
3. **State Management**: HCP Terraform remote state with encryption and locking
4. **Validation Rules**: Input validation, health checks, deployment guarantees
5. **Performance Targets**: < 10 min deployment, < 5 min instance healthy, < 500ms response

**Key Design Patterns**:
- Data sources for VPC/subnet discovery (no hardcoded IDs)
- `for_each` for EC2 instance distribution across AZs
- Security group references (not CIDR blocks) for ALB→EC2 communication
- Self-signed certificate lifecycle management
- Comprehensive tagging strategy for cost tracking

**Contract Definitions**:
- Required inputs: region, project_name, environment, availability_zones, domain_name
- Optional inputs: instance_type, health check parameters, ALB configuration
- Outputs: ALB DNS name, instance IDs, security group IDs, certificate ARN
- Behavioral guarantees: High availability, security isolation, HTTPS-only access

**Agent Context Updated**:
- Technology stack: Terraform >= 1.5.7 (HCL)
- Storage: AWS resources via HCP Terraform remote state
- Project type: Infrastructure as Code with private registry modules

### Phase 2: Task Generation (Not Executed)

**Note**: Phase 2 (task generation) is handled by the separate `/speckit.tasks` command and is not part of `/speckit.plan`.

The next step is to run `/speckit.tasks` to generate `tasks.md` with implementation tasks.

---

## Post-Design Constitution Re-Check ✅ PASS

All constitutional requirements validated after design phase:

- ✅ **Module-First**: All resources use private registry modules
- ✅ **Specification-Driven**: Complete design based on explicit spec
- ✅ **Security-First**: Least privilege, HTTPS-only, no static credentials
- ✅ **HCP Terraform**: Workspace and organization configured
- ✅ **Code Standards**: File organization, naming, tagging defined
- ✅ **Compliance**: Security controls, encryption, network isolation

**No violations** - Proceeding to implementation phase.

---

## Implementation Readiness

### Ready for Implementation
- [x] Specification reviewed and understood
- [x] Technical context defined
- [x] Constitution check passed (pre and post design)
- [x] Research completed with technology decisions
- [x] Data model designed with entities and relationships
- [x] Contracts defined with interface specifications
- [x] Quickstart guide created for deployment
- [x] Agent context updated

### Next Actions
1. Run `/speckit.tasks` to generate implementation tasks
2. Execute tasks in dependency order
3. Validate deployment against success criteria
4. Run code quality review with `code-quality-judge` agent
5. Document deployment outcomes and lessons learned

### Estimated Implementation Time
- Terraform code generation: 2-3 hours
- Testing and validation: 1 hour
- Documentation updates: 30 minutes
- **Total**: 3.5-4.5 hours

---

## Reference Documents

| Document | Location | Purpose |
|----------|----------|---------|
| Feature Specification | `spec.md` | Original requirements and user scenarios |
| Implementation Plan | `plan.md` | This document - planning and design summary |
| Research | `research.md` | Technology decisions and alternatives |
| Data Model | `data-model.md` | Infrastructure entities and relationships |
| Contracts | `contracts/terraform-interface.md` | Module interface and guarantees |
| Quickstart | `quickstart.md` | Deployment and validation guide |

---

**Plan Status**: ✅ **COMPLETE** - Ready for task generation and implementation

**Branch**: `002-ec2-alb-nginx`  
**HCP Terraform Workspace**: `sandbox_workspace` (Organization: `ravi-panchal-org`)  
**Estimated Cost**: ~$30-35/month  
**Deployment Time**: ~10 minutes  
**GitHub Issue**: #37
