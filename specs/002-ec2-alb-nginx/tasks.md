---
description: "Implementation tasks for EC2 Infrastructure with ALB and Nginx"
---

# Tasks: EC2 Infrastructure with ALB and Nginx

**Feature**: 002-ec2-alb-nginx  
**Branch**: `002-ec2-alb-nginx`  
**GitHub Issue**: #37  
**Input**: Design documents from `/workspace/specs/002-ec2-alb-nginx/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/terraform-interface.md

**Organization**: Tasks are grouped by user story to enable independent implementation and validation of each infrastructure capability.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Initialize Terraform project structure and configuration files

- [ ] T001 Create root module file structure in /workspace/ (main.tf, variables.tf, outputs.tf, locals.tf, providers.tf, terraform.tf, tls-certificate.tf)
- [ ] T002 Create sandbox.auto.tfvars.example template file in /workspace/sandbox.auto.tfvars.example
- [ ] T003 [P] Configure Terraform version constraints in /workspace/terraform.tf (>= 1.5.7)
- [ ] T004 [P] Configure AWS provider requirements in /workspace/terraform.tf (hashicorp/aws ~> 6.0)
- [ ] T005 [P] Configure TLS provider requirements in /workspace/terraform.tf (hashicorp/tls ~> 4.0)
- [ ] T006 Configure AWS provider settings in /workspace/providers.tf (region from var.region)
- [ ] T007 [P] Configure TLS provider in /workspace/providers.tf (no configuration required)
- [ ] T008 [P] Verify override.tf exists with HCP Terraform backend configuration (organization: ravi-panchal-org, workspace: sandbox_workspace)

**Checkpoint**: Project structure initialized - ready for infrastructure code generation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Terraform configuration that MUST be complete before ANY user story implementation

**⚠️ CRITICAL**: No user story implementation can begin until this phase is complete

- [ ] T009 Define input variable "region" in /workspace/variables.tf (string, description, validation for valid AWS region)
- [ ] T010 [P] Define input variable "project_name" in /workspace/variables.tf (string, description, validation for alphanumeric/hyphen 3-32 chars)
- [ ] T011 [P] Define input variable "environment" in /workspace/variables.tf (string, description, validation for development/staging/production)
- [ ] T012 [P] Define input variable "availability_zones" in /workspace/variables.tf (list(string), description, validation for exactly 2 AZs)
- [ ] T013 [P] Define input variable "domain_name" in /workspace/variables.tf (string, description, validation for valid domain format)
- [ ] T014 [P] Define input variable "instance_type" in /workspace/variables.tf (string, description, default "t3a.micro")
- [ ] T015 Define local values for common tags in /workspace/locals.tf (Environment, ManagedBy, Terraform, Project, Feature, Workspace, Organization, CostCenter, CostOptimization, Compliance, SecurityLevel)
- [ ] T016 [P] Define local values for availability_zones list in /workspace/locals.tf
- [ ] T017 Create data source for default VPC discovery in /workspace/main.tf (aws_vpc.default with default=true filter)
- [ ] T018 Create data source for subnet discovery in /workspace/main.tf (aws_subnets.default filtering by vpc-id and availability-zone)
- [ ] T019 Create data source map for individual subnets by AZ in /workspace/main.tf (aws_subnet.az using for_each with availability_zones)
- [ ] T020 Run terraform init to initialize providers and validate configuration
- [ ] T021 Run terraform fmt to format all Terraform files
- [ ] T022 Run terraform validate to verify syntax and configuration

**Checkpoint**: Foundation ready - all user story implementations can now proceed

---

## Phase 3: User Story 1 - Access Secure Web Application (Priority: P1) 🎯 MVP

**Goal**: Deploy a highly available web infrastructure accessible via HTTPS so that operators can serve web content securely across multiple availability zones.

**Independent Test**: Access the ALB DNS name via HTTPS in a browser and verify the connection is secure (certificate present, though self-signed) and content is served by Nginx.

**Acceptance Criteria**:
- Infrastructure accessible via ALB DNS with HTTPS protocol and TLS encryption
- Nginx test page loads successfully via HTTPS
- HTTP connections are rejected or redirected to HTTPS

### TLS Certificate Generation (Self-Signed)

- [ ] T023 [P] [US1] Create TLS private key resource in /workspace/tls-certificate.tf (tls_private_key.self_signed with RSA algorithm, 2048 bits)
- [ ] T024 [US1] Create self-signed certificate resource in /workspace/tls-certificate.tf (tls_self_signed_cert.self_signed with subject common_name=var.domain_name, organization, validity 8760 hours, allowed_uses)
- [ ] T025 [US1] Create ACM certificate import resource in /workspace/tls-certificate.tf (aws_acm_certificate.self_signed with private_key and certificate_body from TLS resources)

### Security Groups Configuration

- [ ] T026 [P] [US1] Create ALB security group module in /workspace/main.tf (app.terraform.io/ravi-panchal-org/security-group/aws v5.3.1, name="${var.project_name}-alb-sg", vpc_id from data source)
- [ ] T027 [P] [US1] Configure ALB security group ingress rule for HTTPS in /workspace/main.tf (port 443, protocol tcp, cidr_blocks 0.0.0.0/0, description "HTTPS from internet (FR-009)")
- [ ] T028 [P] [US1] Create EC2 security group module in /workspace/main.tf (app.terraform.io/ravi-panchal-org/security-group/aws v5.3.1, name="${var.project_name}-ec2-sg", vpc_id from data source)
- [ ] T029 [US1] Configure EC2 security group ingress rule for HTTP from ALB in /workspace/main.tf (port 80, protocol tcp, source_security_group_id from ALB SG, description "HTTP from ALB only (FR-011)")
- [ ] T030 [US1] Configure ALB security group egress rule to EC2 instances in /workspace/main.tf (port 80, protocol tcp, destination_security_group_id from EC2 SG, description "HTTP to EC2 instances (FR-010)")
- [ ] T031 [US1] Configure EC2 security group egress rule for all outbound in /workspace/main.tf (port 0, protocol -1, cidr_blocks 0.0.0.0/0, description "Outbound for system updates")

### EC2 Instances with Nginx

- [ ] T032 [US1] Create user data script for Nginx installation in /workspace/locals.tf (bash script: yum update, install nginx, create test page with instance metadata, systemctl enable/start nginx)
- [ ] T033 [US1] Create EC2 instance modules using for_each in /workspace/main.tf (app.terraform.io/ravi-panchal-org/ec2-instance/aws v6.1.4, iterate over availability_zones, name="${var.project_name}-${each.key}")
- [ ] T034 [US1] Configure EC2 instance parameters in /workspace/main.tf (instance_type=var.instance_type, availability_zone=each.key, subnet_id from data.aws_subnet.az, vpc_security_group_ids from EC2 SG, user_data from locals, associate_public_ip_address=true, create_iam_instance_profile=true, tags from locals.common_tags)

### Application Load Balancer

- [ ] T035 [US1] Create ALB module in /workspace/main.tf (app.terraform.io/ravi-panchal-org/alb/aws v10.2.0, name="${var.project_name}-alb", load_balancer_type="application", internal=false)
- [ ] T036 [US1] Configure ALB placement in /workspace/main.tf (security_groups from ALB SG, subnets from data.aws_subnets.default.ids, enable_deletion_protection=false, enable_http2=true, idle_timeout=60, tags from locals.common_tags)
- [ ] T037 [US1] Create target group configuration in /workspace/main.tf (name="${var.project_name}-tg", port=80, protocol="HTTP", vpc_id from data source, target_type="instance", deregistration_delay=30)
- [ ] T038 [US1] Configure target group health check in /workspace/main.tf (enabled=true, path="/", protocol="HTTP", port="traffic-port", healthy_threshold=2, unhealthy_threshold=2, timeout=5, interval=30, matcher="200")
- [ ] T039 [US1] Create HTTPS listener configuration in /workspace/main.tf (port=443, protocol="HTTPS", ssl_policy="ELBSecurityPolicy-TLS13-1-2-2021-06", certificate_arn from aws_acm_certificate.self_signed.arn, default_action forward to target group)
- [ ] T040 [US1] Create target attachments for EC2 instances in /workspace/main.tf (targets list from module.ec2_instance map, target_id=instance.id, port=80)

### Outputs Configuration

- [ ] T041 [P] [US1] Define output for ALB DNS name in /workspace/outputs.tf (value from module.alb.dns_name, description "ALB DNS name for HTTPS access")
- [ ] T042 [P] [US1] Define output for ALB ARN in /workspace/outputs.tf (value from module.alb.arn, description "ALB ARN")
- [ ] T043 [P] [US1] Define output for target group ARN in /workspace/outputs.tf (value from target group ARN, description "Target group ARN for health checks")
- [ ] T044 [P] [US1] Define output for EC2 instance IDs in /workspace/outputs.tf (value from module.ec2_instance map, description "EC2 instance IDs")
- [ ] T045 [P] [US1] Define output for ACM certificate ARN in /workspace/outputs.tf (value from aws_acm_certificate.self_signed.arn, description "ACM certificate ARN", sensitive=false)
- [ ] T046 [P] [US1] Define output for EC2 security group ID in /workspace/outputs.tf (value from module.ec2_security_group.security_group_id, description "EC2 security group ID")
- [ ] T047 [P] [US1] Define output for ALB security group ID in /workspace/outputs.tf (value from module.alb_security_group.security_group_id, description "ALB security group ID")

### Validation and Testing

- [ ] T048 [US1] Create sandbox.auto.tfvars file in /workspace/sandbox.auto.tfvars with values (project_name="nginx-alb", environment="development", region="ap-southeast-1", availability_zones=["ap-southeast-1a","ap-southeast-1b"], domain_name="web.demo.com", instance_type="t3a.micro")
- [ ] T049 [US1] Run terraform fmt to format all code
- [ ] T050 [US1] Run terraform validate to verify configuration syntax
- [ ] T051 [US1] Run terraform plan to preview resource creation
- [ ] T052 [US1] Run terraform apply to deploy infrastructure (wait for completion ~10 minutes)
- [ ] T053 [US1] Verify ALB DNS name output is generated
- [ ] T054 [US1] Test HTTPS access using curl -k https://<alb-dns-name> and verify Nginx test page loads
- [ ] T055 [US1] Verify TLS handshake using openssl s_client -connect <alb-dns-name>:443 -servername web.demo.com
- [ ] T056 [US1] Test browser access to https://<alb-dns-name> and accept self-signed certificate warning
- [ ] T057 [US1] Verify HTTP access is rejected (curl http://<alb-dns-name> should fail or redirect)

**Checkpoint**: User Story 1 complete - HTTPS web application accessible via ALB with TLS encryption and Nginx serving content

---

## Phase 4: User Story 2 - Verify High Availability Configuration (Priority: P2)

**Goal**: Verify that instances are distributed across multiple availability zones so that the application remains available even if one availability zone experiences issues.

**Independent Test**: Check EC2 console to confirm instances are in different AZs (ap-southeast-1a and ap-southeast-1b), then simulate failure of one instance and verify the ALB continues serving traffic from the remaining instance.

**Acceptance Criteria**:
- Instances distributed across ap-southeast-1a and ap-southeast-1b
- ALB automatically routes traffic only to healthy instance when one fails
- No service interruption when one instance is terminated

### High Availability Validation

- [ ] T058 [P] [US2] Verify EC2 instances are running in different AZs using aws ec2 describe-instances filtered by Feature tag
- [ ] T059 [P] [US2] Verify ALB target health shows both instances healthy using aws elbv2 describe-target-health
- [ ] T060 [US2] Terminate one EC2 instance using aws ec2 terminate-instances
- [ ] T061 [US2] Wait for instance termination using aws ec2 wait instance-terminated
- [ ] T062 [US2] Verify ALB continues serving traffic using curl -k https://<alb-dns-name> in a loop (10 requests, all should return 200)
- [ ] T063 [US2] Verify target health shows 1 healthy and 1 unhealthy/unused target
- [ ] T064 [US2] Document high availability test results in /workspace/specs/002-ec2-alb-nginx/ha-test-results.md

**Checkpoint**: User Story 2 complete - High availability verified with zero downtime during single instance failure

---

## Phase 5: User Story 3 - Validate Security Controls (Priority: P2)

**Goal**: Validate that all security controls are properly configured so that the infrastructure meets encryption and network isolation requirements.

**Independent Test**: Run security validation checks to verify TLS certificate in ACM, test security group rules block unauthorized access, confirm IAM roles follow least privilege, and validate no HTTP-only access is possible.

**Acceptance Criteria**:
- Self-signed certificate for web.demo.com is visible in AWS Certificate Manager
- Security groups block direct access to EC2 instances (only ALB can communicate)
- Only HTTPS (port 443) listener is enabled on ALB
- IAM roles have minimum required permissions

### Security Validation

- [ ] T065 [P] [US3] Verify ACM certificate is imported and status is ISSUED using aws acm describe-certificate
- [ ] T066 [P] [US3] Verify ALB listener configuration shows only HTTPS (port 443) using aws elbv2 describe-listeners
- [ ] T067 [P] [US3] Verify ALB security group allows HTTPS from 0.0.0.0/0 using aws ec2 describe-security-groups
- [ ] T068 [P] [US3] Verify EC2 security group allows HTTP only from ALB security group using aws ec2 describe-security-groups
- [ ] T069 [US3] Attempt direct SSH to EC2 instance public IP and verify connection timeout (should fail)
- [ ] T070 [US3] Verify IAM instance profile permissions are minimal (describe using aws iam get-instance-profile and aws iam list-attached-role-policies)
- [ ] T071 [US3] Verify no HTTP listener exists on ALB (only HTTPS)
- [ ] T072 [US3] Document security validation results in /workspace/specs/002-ec2-alb-nginx/security-validation.md

**Checkpoint**: User Story 3 complete - Security controls validated with encryption, network isolation, and least privilege

---

## Phase 6: User Story 4 - Deploy with Cost Optimization (Priority: P3)

**Goal**: Verify the infrastructure uses cost-effective instance types and configurations so that development environment costs remain minimal.

**Independent Test**: Review deployed infrastructure configuration, check instance types are t3.micro or similar, verify no unnecessary resources were created, and monitor AWS Cost Explorer for the first billing cycle.

**Acceptance Criteria**:
- Cost-effective instance types (t3.micro, t3.small, or t2.micro) in use
- No unnecessary resources (extra EIPs, NAT gateways, etc.)
- Using default VPC (no new VPC resources created)

### Cost Optimization Validation

- [ ] T073 [P] [US4] Verify EC2 instance types are cost-effective (t3a.micro) using aws ec2 describe-instances
- [ ] T074 [P] [US4] Verify no Elastic IPs were created using aws ec2 describe-addresses filtered by Feature tag
- [ ] T075 [P] [US4] Verify no NAT Gateways were created using aws ec2 describe-nat-gateways filtered by Feature tag
- [ ] T076 [P] [US4] Verify default VPC is being used (not a new VPC) using terraform show and data source values
- [ ] T077 [US4] Calculate estimated monthly cost (2 × t3a.micro instances ~$13.54 + 1 × ALB ~$16.20 + EBS ~$0.20 = ~$30-35/month)
- [ ] T078 [US4] Verify total estimated cost is under $50/month requirement
- [ ] T079 [US4] Document cost breakdown in /workspace/specs/002-ec2-alb-nginx/cost-analysis.md

**Checkpoint**: User Story 4 complete - Cost optimization validated with infrastructure under $50/month target

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, documentation, and quality assurance

- [ ] T080 [P] Run terraform fmt -recursive to format all Terraform files
- [ ] T081 [P] Run terraform validate to ensure all configuration is valid
- [ ] T082 [P] Run TFLint for best practices validation using tflint --init && tflint
- [ ] T083 [P] Run pre-commit hooks if configured using pre-commit run --all-files
- [ ] T084 Verify all success criteria from spec.md are met (SC-001 through SC-010)
- [ ] T085 [P] Update README.md with deployment instructions and architecture overview
- [ ] T086 [P] Verify quickstart.md steps execute successfully from start to finish
- [ ] T087 Create deployment verification checklist in /workspace/specs/002-ec2-alb-nginx/deployment-checklist.md
- [ ] T088 Tag all resources with proper metadata (verify via AWS Console or CLI)
- [ ] T089 Document any deviations from original plan in /workspace/specs/002-ec2-alb-nginx/implementation-notes.md
- [ ] T090 Commit all changes to feature branch 002-ec2-alb-nginx with descriptive commit message
- [ ] T091 Push feature branch to GitHub repository
- [ ] T092 Update GitHub Issue #37 with deployment results and ALB DNS name

**Checkpoint**: Infrastructure fully deployed, tested, documented, and ready for review

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion - Core infrastructure deployment
- **User Story 2 (Phase 4)**: Depends on User Story 1 (Phase 3) completion - Requires deployed infrastructure for HA testing
- **User Story 3 (Phase 5)**: Depends on User Story 1 (Phase 3) completion - Requires deployed infrastructure for security validation
- **User Story 4 (Phase 6)**: Depends on User Story 1 (Phase 3) completion - Requires deployed infrastructure for cost analysis
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

```
Setup (Phase 1)
    ↓
Foundational (Phase 2) ← CRITICAL BLOCKER
    ↓
    ├─→ User Story 1 (Phase 3) ← MVP CORE
    │       ↓
    │       ├─→ User Story 2 (Phase 4) ← Independent HA validation
    │       ├─→ User Story 3 (Phase 5) ← Independent security validation
    │       └─→ User Story 4 (Phase 6) ← Independent cost validation
    │
    └─→ Polish (Phase 7)
```

### Within Each Phase

**Phase 1 - Setup**:
- T001 must complete first (creates file structure)
- T002-T008 can run in parallel (marked with [P])

**Phase 2 - Foundational**:
- T009-T014 can run in parallel (all variable definitions)
- T015-T016 can run in parallel (locals definitions)
- T017-T019 must be sequential (data source dependencies)
- T020-T022 must be sequential at the end (validation)

**Phase 3 - User Story 1** (CRITICAL - MVP CORE):
- TLS Certificate (T023-T025): Sequential (private key → cert → ACM)
- Security Groups (T026-T031): T026-T028 parallel, then T029-T031 sequential
- EC2 Instances (T032-T034): T032 first, then T033-T034 sequential
- ALB (T035-T040): Sequential (ALB → target group → listener → attachments)
- Outputs (T041-T047): All can run in parallel
- Validation (T048-T057): Sequential (tfvars → fmt → validate → plan → apply → test)

**Phase 4 - User Story 2**:
- T058-T059 can run in parallel (initial verification)
- T060-T063 must be sequential (terminate → wait → test → verify)
- T064 runs last (documentation)

**Phase 5 - User Story 3**:
- T065-T068 can run in parallel (AWS API checks)
- T069-T072 must be sequential (connectivity tests and documentation)

**Phase 6 - User Story 4**:
- T073-T076 can run in parallel (verification checks)
- T077-T079 must be sequential (cost calculation and documentation)

**Phase 7 - Polish**:
- T080-T083 can run in parallel (formatting and validation)
- T084-T092 should be sequential (final verification and git operations)

### Parallel Opportunities

**Within Setup Phase**:
```bash
# Can run together after T001 completes:
T003: Configure Terraform version constraints
T004: Configure AWS provider requirements
T005: Configure TLS provider requirements
T007: Configure TLS provider
T008: Verify override.tf
```

**Within Foundational Phase**:
```bash
# Can run together:
T010: Define "project_name" variable
T011: Define "environment" variable
T012: Define "availability_zones" variable
T013: Define "domain_name" variable
T014: Define "instance_type" variable

# Can run together:
T015: Define common tags locals
T016: Define availability_zones locals
```

**Within User Story 1**:
```bash
# Can run together:
T026: Create ALB security group
T027: Configure ALB SG HTTPS ingress
T028: Create EC2 security group

# Can run together (outputs):
T041: Output ALB DNS
T042: Output ALB ARN
T043: Output target group ARN
T044: Output EC2 instance IDs
T045: Output ACM certificate ARN
T046: Output EC2 security group ID
T047: Output ALB security group ID
```

**Within User Story 2**:
```bash
# Can run together:
T058: Verify EC2 AZ distribution
T059: Verify ALB target health
```

**Within User Story 3**:
```bash
# Can run together:
T065: Verify ACM certificate
T066: Verify ALB listener
T067: Verify ALB security group
T068: Verify EC2 security group
```

**Within User Story 4**:
```bash
# Can run together:
T073: Verify instance types
T074: Verify no Elastic IPs
T075: Verify no NAT Gateways
T076: Verify default VPC usage
```

**Within Polish Phase**:
```bash
# Can run together:
T080: terraform fmt
T081: terraform validate
T082: TFLint
T083: pre-commit hooks
T085: Update README
T086: Verify quickstart
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. ✅ Complete Phase 1: Setup (~30 minutes)
2. ✅ Complete Phase 2: Foundational (~45 minutes)
3. ✅ Complete Phase 3: User Story 1 (~2 hours)
4. **STOP and VALIDATE**: Test HTTPS access, verify certificate, check Nginx page
5. **Deploy/Demo**: Working HTTPS web application with ALB and Nginx (MVP COMPLETE!)

**MVP Delivery Time**: ~3-4 hours  
**MVP Value**: Fully functional, secure web infrastructure accessible via HTTPS

### Incremental Delivery

1. **Foundation** (Phase 1 + 2): ~1.5 hours → Terraform project ready
2. **MVP** (Phase 3): ~2 hours → HTTPS web app deployed and accessible
3. **HA Validation** (Phase 4): ~30 minutes → High availability verified
4. **Security Validation** (Phase 5): ~30 minutes → Security controls confirmed
5. **Cost Validation** (Phase 6): ~30 minutes → Cost optimization verified
6. **Polish** (Phase 7): ~30 minutes → Documentation and final checks

**Total Time**: ~5-6 hours for complete feature with all validations

### Parallel Team Strategy

With multiple team members:

1. **Team**: Complete Setup + Foundational together (~1.5 hours)
2. **Once Foundational complete**:
   - **Developer A**: User Story 1 (MVP core infrastructure) - CRITICAL PATH
   - **After US1 deployed**:
     - **Developer B**: User Story 2 (HA validation) - Independent
     - **Developer C**: User Story 3 (Security validation) - Independent
     - **Developer D**: User Story 4 (Cost validation) - Independent
3. **Team**: Polish and documentation together (~30 minutes)

**Parallel Completion Time**: ~3-4 hours with proper coordination

---

## Success Criteria Mapping

Each task maps to functional requirements (FR) and success criteria (SC) from spec.md:

| Task(s) | Requirement | Success Criteria |
|---------|-------------|------------------|
| T017-T019 | FR-008 | Use existing default VPC |
| T023-T025 | FR-003, FR-004 | Self-signed cert for web.demo.com imported to ACM |
| T026-T031 | FR-009, FR-010, FR-011 | Security groups with least privilege |
| T032-T034 | FR-001, FR-006, FR-007, FR-014 | 2 EC2 instances across AZs with Nginx |
| T035-T040 | FR-002, FR-005, FR-013 | ALB with HTTPS listener and health checks |
| T048 | FR-015 | Environment tag "development" |
| T051-T057 | SC-001, SC-002, SC-004, SC-005 | Infrastructure accessible via HTTPS |
| T058-T063 | SC-003, SC-010 | HA verified across AZs |
| T065-T071 | SC-006, SC-009 | Security controls validated |
| T073-T078 | SC-007 | Cost under $50/month |
| T052 | FR-016, FR-017 | Deployable to HCP Terraform workspace |

---

## Notes

- [P] tasks = different files or independent operations, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story builds on US1 but validates different aspects independently
- User Story 1 is the MVP - infrastructure must be fully deployed before other validations
- Terraform apply (T052) takes ~10 minutes - factor into timeline
- All validation tasks (US2, US3, US4) require deployed infrastructure from US1
- Cost analysis uses AWS pricing as of 2025-02-01 (ap-southeast-1 region)
- Security validations require AWS CLI access with proper permissions
- Commit frequently with descriptive messages referencing task IDs
- Stop at any checkpoint to validate story independently
- Verify tests succeed before marking story complete

---

**Implementation Readiness**: ✅ All tasks defined with clear dependencies, acceptance criteria, and execution order. Ready for implementation via `/speckit.implement` command.

**Estimated Total Time**: 5-6 hours  
**MVP Time**: 3-4 hours (Phases 1-3 only)  
**Total Tasks**: 92  
**Parallelizable Tasks**: 34 (marked with [P])  
**User Stories**: 4 (P1, P2, P2, P3)  
**Critical Path**: Setup → Foundational → User Story 1 (MVP)
