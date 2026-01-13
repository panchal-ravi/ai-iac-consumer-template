# Implementation Tasks: Public EC2 Instance for Development Environment

**Feature**: `001-public-ec2-dev`  
**Status**: In Progress  
**Created**: 2026-01-12

## Overview

This document provides a dependency-ordered task list for implementing the public EC2 development instance infrastructure based on the approved design in plan.md, data-model.md, and spec.md.

## Task Execution Rules

- **Sequential tasks**: Must be completed in order (blocking dependencies)
- **Parallel tasks [P]**: Can be executed simultaneously
- **File-based coordination**: Tasks affecting the same files must run sequentially

---

## Phase 1: Setup & Configuration

**Status**: [X]
**Status**: [X]  
**Description**: Create/verify .gitignore and .terraformignore files for Terraform project  
**Files**: `.gitignore`, `.terraformignore`  
**Dependencies**: None  
**Acceptance**: Ignore files exist with proper Terraform patterns

**Status**: [X]
**Status**: [X]  
**Description**: Configure Terraform version constraints and AWS provider  
**Files**: `versions.tf`, `providers.tf`, `override.tf`  
**Dependencies**: None [P]  
**Acceptance**: 
- Terraform >= 1.13.0 required
- AWS provider ~> 6.0.0 configured
- HCP Terraform backend configured for sandbox_workspace

---

## Phase 2: Variables and Data Sources

**Status**: [X]
**Status**: [X]  
**Description**: Define all input variables with validation rules  
**Files**: `variables.tf`  
**Dependencies**: Task 1.2  
**Acceptance**:
- Variables: environment, instance_type, region, root_volume_size, project_name, cost_center
- Validation rules enforce t3.micro, ap-southeast-1, 8GB constraints

**Status**: [X]
**Status**: [X]  
**Description**: Define common tags and naming conventions  
**Files**: `locals.tf`  
**Dependencies**: Task 2.1  
**Acceptance**:
- Common tags defined (Environment, ManagedBy, Project, CostCenter, Feature, Workspace)
- Naming conventions for resources established

**Status**: [X]
**Status**: [X]  
**Description**: Create data sources to find default VPC and subnets in ap-southeast-1  
**Files**: `main.tf`  
**Dependencies**: Task 2.1 [P]  
**Acceptance**:
- Data source for default VPC created
- Data source for default subnets created
- Error handling for missing VPC

**Status**: [X]
**Status**: [X]  
**Description**: Create data source to dynamically find latest Amazon Linux 2023 AMI  
**Files**: `main.tf`  
**Dependencies**: Task 2.1 [P]  
**Acceptance**:
- Data source filters for al2023-ami-*-x86_64
- Most recent AMI selected
- Owner filter set to amazon

---

## Phase 3: Security & Secrets Management

**Status**: [X]
**Status**: [X]  
**Description**: Create random password resource for SSH authentication  
**Files**: `main.tf`  
**Dependencies**: Task 2.2  
**Acceptance**:
- 32-character password generated
- All character classes included (upper, lower, number, special)
- Marked as sensitive in Terraform

**Status**: [X]
**Status**: [X]  
**Description**: Create AWS Secrets Manager secret and version for SSH password  
**Files**: `main.tf`  
**Dependencies**: Task 3.1  
**Acceptance**:
- Secret created with name dev-ec2-ssh-password
- Password stored in secret value
- Common tags applied
- Recovery window configured

**Status**: [X]
**Status**: [X]  
**Description**: Create IAM role allowing EC2 to access Secrets Manager  
**Files**: `main.tf`  
**Dependencies**: Task 3.2  
**Acceptance**:
- IAM role with EC2 trust policy created
- Inline policy granting secretsmanager:GetSecretValue permission
- Instance profile created and attached to role
- Common tags applied

**Status**: [X]
**Status**: [X]  
**Description**: Create security group with SSH ingress rule from 0.0.0.0/0  
**Files**: `main.tf`  
**Dependencies**: Task 2.3  
**Acceptance**:
- Security group in default VPC
- Ingress rule: TCP port 22 from 0.0.0.0/0
- Egress rule: All traffic allowed
- Common tags applied

---

## Phase 4: EC2 Instance Configuration

**Status**: [X]
**Status**: [X]  
**Description**: Create user data script to enable SSH password authentication  
**Files**: `main.tf` (or separate template file)  
**Dependencies**: Task 3.2  
**Acceptance**:
- Script retrieves password from Secrets Manager using IMDSv2
- Configures /etc/ssh/sshd_config for password auth
- Sets password for ec2-user
- Restarts sshd service
- Handles errors gracefully

**Status**: [X]
**Status**: [X]  
**Description**: Provision EC2 t3.micro instance with all configurations  
**Files**: `main.tf`  
**Dependencies**: Task 2.4, Task 3.3, Task 3.4, Task 4.1  
**Acceptance**:
- Instance type: t3.micro
- AMI: Amazon Linux 2023 (from data source)
- VPC: Default VPC (from data source)
- Public IP assigned
- IAM instance profile attached
- Security group attached
- Root volume: 8GB GP3, delete_on_termination=true
- User data script applied
- Basic monitoring enabled (detailed monitoring disabled)
- Common tags applied

---

## Phase 5: Outputs and Documentation

**Status**: [X]
**Status**: [X]  
**Description**: Create outputs for instance ID, public IP, secret ARN  
**Files**: `outputs.tf`  
**Dependencies**: Task 4.2  
**Acceptance**:
- Output: instance_id with description
- Output: instance_public_ip with description
- Output: instance_private_ip with description
- Output: security_group_id with description
- Output: ssh_secret_arn with description
- Password value NOT exposed in outputs

**Status**: [X]
**Status**: [X]  
**Description**: Create sandbox.auto.tfvars with environment-specific values  
**Files**: `sandbox.auto.tfvars`, `sandbox.auto.tfvars.example`  
**Dependencies**: Task 2.1 [P]  
**Acceptance**:
- project_name and cost_center values defined
- Example file created for reference
- Sensitive values excluded

**Status**: [X]
**Status**: [X]  
**Description**: Create comprehensive README with terraform-docs or manual documentation  
**Files**: `README.md`  
**Dependencies**: Task 5.1 [P]  
**Acceptance**:
- Requirements section (prerequisites)
- Usage section (terraform init/plan/apply)
- Inputs table (all variables documented)
- Outputs table (all outputs documented)
- Cost breakdown section
- Security considerations section

---

## Phase 6: Testing and Validation

**Status**: [X]
**Status**: [X]  
**Description**: Run terraform init in workspace  
**Files**: N/A  
**Dependencies**: All Phase 1-5 tasks complete  
**Acceptance**:
- Terraform initialized successfully
- Providers downloaded
- Backend configured for HCP Terraform

**Status**: [X]
**Status**: [X]  
**Description**: Run terraform validate and terraform fmt  
**Files**: All .tf files  
**Dependencies**: Task 6.1  
**Acceptance**:
- terraform validate passes with no errors
- terraform fmt applied successfully
- No syntax errors

**Status**: [X]
**Status**: [X]  
**Description**: Generate and review terraform plan in sandbox workspace  
**Files**: N/A  
**Dependencies**: Task 6.2  
**Acceptance**:
- Plan completes successfully
- Resources to create: ~10-12 (VPC lookup, AMI lookup, password, secret, IAM, SG, instance)
- No unexpected changes
- Cost estimate under $50/month

**Status**: [X]
**Status**: [X]  
**Description**: Apply configuration to sandbox workspace for testing  
**Files**: N/A  
**Dependencies**: Task 6.3  
**Acceptance**:
- Apply completes within 5 minutes
- All resources created successfully
- Outputs populated with valid values
- No errors in execution

**Status**: [X]
**Status**: [X]  
**Description**: Test SSH connection to instance with password  
**Files**: N/A  
**Dependencies**: Task 6.4  
**Acceptance**:
- Password retrievable from Secrets Manager
- SSH connection successful with ec2-user and password
- Instance accessible from external IP
- User data script executed successfully

---

## Summary

**Total Tasks**: 22  
**Phases**: 6  
**Estimated Time**: 2-4 hours (excluding apply/test time)

**Critical Path**:
1. Setup (Tasks 1.1 - 1.2)
2. Variables & Data (Tasks 2.1 - 2.4)
3. Security (Tasks 3.1 - 3.4)
4. EC2 (Tasks 4.1 - 4.2)
5. Outputs (Tasks 5.1 - 5.3)
6. Testing (Tasks 6.1 - 6.3)

**Parallel Opportunities**:
- Task 2.1 and 2.3, 2.4 can run in parallel after Task 1.2
- Task 5.2 can run in parallel with Task 5.1
- Task 5.3 can run in parallel with Task 5.1

---

**Next Action**: Begin with Task 1.1 - Project Setup and Ignore Files
