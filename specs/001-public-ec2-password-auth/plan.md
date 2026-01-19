# Implementation Plan: Public EC2 Instance with Password Authentication

**Branch**: `001-public-ec2-password-auth` | **Date**: 2025-01-21 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/001-public-ec2-password-auth/spec.md`

---

## Executive Summary

This implementation plan delivers a public-facing EC2 instance in AWS ap-southeast-1 with SSH password authentication for development use. The solution uses private registry modules per constitution requirements, implements CloudWatch logging for SSH authentication monitoring, and maintains cost optimization with t3.micro instance type.

**Key Technical Decisions**:
- **Module Strategy**: Exclusive use of `app.terraform.io/ravi-panchal-org/*` private modules
- **OS**: Ubuntu 22.04 LTS with dynamic AMI lookup
- **Authentication**: Password-based SSH (random_password resource, 20 chars)
- **Networking**: Default VPC with custom VPC fallback
- **Logging**: CloudWatch Agent shipping /var/log/auth.log
- **Access**: Elastic IP for stable public connectivity
- **Cost Target**: $10-15/month

**Security Posture**: Development/sandbox only - violates AWS best practices for password auth and open SSH.

---

## Technical Context

**Language/Version**: HCL (Terraform) v1.5+  
**Primary Dependencies**: 
- AWS Provider v6.0+
- Private Modules: ec2-instance (6.1.4), vpc (6.5.0), cloudwatch (5.7.2), security-group, iam
- random_password provider

**Storage**: EBS GP3 (8-20 GB root volume)  
**Testing**: Terraform validate, tflint, manual SSH connectivity tests  
**Target Platform**: AWS ap-southeast-1 (Singapore)  
**Project Type**: Infrastructure-as-Code (Terraform modules)  
**Performance Goals**: 
- Instance launch: <10 minutes
- SSH connection: <30 seconds
- CloudWatch log delivery: <5 minutes

**Constraints**: 
- Must use t3.micro (cost)
- Must use private registry modules (constitution)
- Must be in ap-southeast-1 (user requirement)
- Development security posture only

**Scale/Scope**: Single EC2 instance, single environment (dev)

---

## Constitution Check

✅ **GATE PASSED** - All constitution requirements satisfied

### 1.1 Module-First Architecture
**Status**: ✅ COMPLIANT

- All infrastructure uses private registry modules: `app.terraform.io/ravi-panchal-org/*`
- Modules identified and validated:
  - `ec2-instance/aws` (v6.1.4)
  - `vpc/aws` (v6.5.0)
  - `cloudwatch/aws` (v5.7.2)
  - `security-group/aws`
  - `iam/aws`
- Module versions use semantic versioning constraints (~> 6.1.4)
- No direct resource declarations bypass organizational controls

### 1.2 Specification-Driven Development
**Status**: ✅ COMPLIANT

- Feature specification completed: `spec.md`
- All clarifications documented (AMI, password strategy, VPC, logging, error handling)
- Data model defined: `data-model.md`
- Technical research completed: `research.md`
- Implementation plan references spec requirements explicitly

### 1.3 Security-First Automation
**Status**: ⚠️ ACCEPTABLE WITH CAVEATS

- No static credentials in code ✅
- Provider authentication via workspace variable sets ✅
- Sensitive values (password) marked `sensitive = true` ✅
- **Caveat**: Password authentication violates AWS best practices but is accepted for development use

### 2.1 HCP Terraform Prerequisites
**Status**: ✅ COMPLIANT

- Organization: `ravi-panchal-org` (verified)
- Project: Default Project
- Workspace: `sandbox_public_ec2_dev`
- Remote backend configuration verified

**Re-check After Phase 1**: ✅ All gates remain passed after design phase.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-public-ec2-password-auth/
├── plan.md                     # This file (Phase 0-2 complete)
├── spec.md                     # Feature specification
├── research.md                 # Phase 0: Technology research
├── data-model.md               # Phase 1: Entity definitions
├── quickstart.md               # Phase 1: User quick start guide
├── contracts/                  # Phase 1: Terraform contracts
│   ├── variables-contract.md   # Input variable specifications
│   └── outputs-contract.md     # Output value specifications
├── checklists/                 # Feature-specific checklists
└── CONNECTION-GUIDE.md         # SSH connection instructions
```

### Source Code (repository root)

```text
/workspace/
├── main.tf                     # Root module - orchestrates private modules
├── variables.tf                # Variable declarations
├── outputs.tf                  # Output declarations
├── providers.tf                # AWS provider configuration
├── backend.tf                  # HCP Terraform backend (generated)
├── versions.tf                 # Provider version constraints
├── locals.tf                   # Local values and computed data
├── terraform.tfvars.example    # Example variable values
├── user-data.sh.tpl            # User-data template for EC2
│
├── modules/                    # (Optional) Local module wrappers
│   └── ec2-password-auth/      # Feature-specific module composition
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── user-data.sh.tpl
│
└── .specify/                   # Speckit framework
    ├── memory/
    │   └── constitution.md
    ├── scripts/
    └── templates/
```

**Structure Decision**: Single-project Terraform root module that composes private registry modules. This aligns with Terraform best practices for infrastructure composition and satisfies the constitution's module-first requirement.

---

## Complexity Tracking

**No Constitution Violations** - This section intentionally left empty as all gates passed.

The implementation follows the module-first architecture without exceptions. While password authentication is a security concern, it does not violate the constitution's technical requirements.
