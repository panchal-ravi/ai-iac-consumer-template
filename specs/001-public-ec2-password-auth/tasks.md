---
description: "Implementation tasks for Public EC2 Instance with Password Authentication"
---

# Tasks: Public EC2 Instance with Password Authentication

**Input**: Design documents from `/specs/001-public-ec2-password-auth/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md, quickstart.md
**Branch**: `001-public-ec2-password-auth`
**HCP Terraform**: Organization: `ravi-panchal-org`, Workspace: `sandbox_public_ec2_dev`
**AWS Region**: `ap-southeast-1` (Singapore)
**Environment**: Development/Sandbox

**Tests**: Not explicitly requested in the feature specification - tasks focus on implementation and validation.

**Organization**: Tasks are grouped by user story (from spec.md) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Terraform infrastructure project at repository root:
- Configuration files: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, etc.
- Templates: `user-data.sh.tpl` (user-data script template)
- Documentation: Repository root `README.md`

---

## Phase 1: Setup (Terraform Project Initialization)

**Purpose**: Initialize Terraform project structure and verify prerequisites

- [ ] T001 Create `backend.tf` with HCP Terraform remote backend configuration (org: ravi-panchal-org, workspace: sandbox_public_ec2_dev)
- [ ] T002 [P] Create `providers.tf` with AWS provider configuration (region: ap-southeast-1, version: ~> 6.0)
- [ ] T003 [P] Create `versions.tf` with Terraform version constraint (>= 1.5.0) and required providers
- [ ] T004 [P] Create `locals.tf` for computed local values (AMI lookup, VPC selection logic)
- [ ] T005 Initialize Terraform and verify HCP Terraform workspace connection (terraform init)
- [ ] T006 Verify HCP Terraform workspace variables are configured (AWS credentials, region)

---

## Phase 2: Foundational (Core Infrastructure Prerequisites)

**Purpose**: Core infrastructure components that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T007 Create `variables.tf` with all input variable declarations per contracts/variables-contract.md
- [ ] T008 [P] Create `outputs.tf` with all output declarations per contracts/outputs-contract.md
- [ ] T009 [P] Create data source for Ubuntu 22.04 LTS AMI lookup (filter: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*, owner: 099720109477) in locals.tf
- [ ] T010 [P] Create data source for default VPC lookup with fallback logic in locals.tf
- [ ] T011 Create `random_password` resource with 20-character complexity requirements in main.tf
- [ ] T012 [P] Create CloudWatch log group resource (/aws/ec2/ssh-auth, 7-day retention) in main.tf
- [ ] T013 [P] Create IAM role and instance profile for CloudWatch Agent (CloudWatchAgentServerPolicy) in main.tf
- [ ] T014 Create `user-data.sh.tpl` template with password setup, SSH config, and CloudWatch Agent installation

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Basic Instance Provisioning (Priority: P1) 🎯 MVP

**Goal**: Provision a running t3.micro EC2 instance with public IP in ap-southeast-1

**Independent Test**: 
- Instance is running: `terraform output instance_id` returns valid instance ID
- Instance has public IP: `terraform output instance_public_ip` returns valid IP address
- Instance is reachable: `ping <public-ip>` succeeds

**Acceptance**: 
- Instance state is "running" within 5 minutes
- Public IP is assigned via Elastic IP
- Instance is accessible on network (ICMP reachable)

### Implementation for User Story 1

- [ ] T015 [P] [US1] Create VPC module configuration in main.tf (use default VPC if exists, create custom VPC 10.0.0.0/16 if missing, per research.md)
- [ ] T016 [P] [US1] Create security group configuration in main.tf (allow SSH port 22 from 0.0.0.0/0, allow all egress)
- [ ] T017 [US1] Create EC2 instance module configuration in main.tf (source: app.terraform.io/ravi-panchal-org/ec2-instance/aws, version ~> 6.1.4, instance_type: t3.micro, ami: Ubuntu 22.04 LTS, subnet: public, user_data: template, iam_instance_profile: CloudWatch role)
- [ ] T018 [US1] Create Elastic IP allocation and association in main.tf
- [ ] T019 [US1] Apply Terraform configuration and verify instance provisioning (terraform apply)
- [ ] T020 [US1] Validate instance is running and accessible (aws ec2 describe-instances, ping test)

**Checkpoint**: At this point, User Story 1 should be fully functional - EC2 instance is provisioned and running with public IP

---

## Phase 4: User Story 2 - Password-Based SSH Access (Priority: P1)

**Goal**: Enable SSH authentication using username "devuser" and generated password

**Independent Test**:
- SSH connection succeeds: `ssh devuser@<public-ip>` prompts for password
- Authentication works: Enter password and gain shell access
- User environment is correct: `whoami` returns "devuser"

**Acceptance**:
- SSH connection with correct password succeeds
- User lands in working bash shell at /home/devuser
- Incorrect password attempts are denied

### Implementation for User Story 2

- [ ] T021 [US2] Complete user-data.sh.tpl script: add devuser creation, password setting from template variable, SSH config modification (PasswordAuthentication yes) in user-data.sh.tpl
- [ ] T022 [US2] Update EC2 instance module to pass generated password to user-data template in main.tf
- [ ] T023 [US2] Apply Terraform changes and wait for user-data script completion (terraform apply, wait 5-10 minutes)
- [ ] T024 [US2] Test SSH connection with password authentication (ssh devuser@<public-ip>, enter password from terraform output instance_password)
- [ ] T025 [US2] Verify user shell environment and permissions (whoami, pwd, ls -la /home/devuser)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - instance is accessible via SSH with password

---

## Phase 5: User Story 3 - Secure Credential Management (Priority: P2)

**Goal**: Ensure password is stored securely and not exposed in plain text

**Independent Test**:
- Password is marked sensitive: `terraform output instance_password` requires explicit access
- Password is not in logs: Review terraform plan/apply output - password is redacted
- Password retrieval is secure: Access via HCP Terraform workspace variables UI

**Acceptance**:
- Password stored in HCP Terraform as sensitive variable
- Password value is redacted in logs and UI
- Authorized users can securely retrieve password

### Implementation for User Story 3

- [ ] T026 [US3] Verify random_password resource has sensitive = true in outputs.tf
- [ ] T027 [US3] Verify password is not logged in user-data script (use stdin for chpasswd) in user-data.sh.tpl
- [ ] T028 [US3] Test password retrieval via HCP Terraform workspace (navigate to workspace, view sensitive outputs)
- [ ] T029 [US3] Verify password is redacted in terraform plan/apply output (grep for password value in logs)
- [ ] T030 [US3] Document password storage and retrieval process in CONNECTION-GUIDE.md

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should all work - instance accessible with securely stored credentials

---

## Phase 6: User Story 4 - Network Security Configuration (Priority: P2)

**Goal**: Configure appropriate network controls allowing SSH while blocking unauthorized access

**Independent Test**:
- SSH is accessible: `nc -zv <public-ip> 22` succeeds
- Unauthorized ports blocked: `nc -zv <public-ip> 3306` fails (connection refused)
- Optional HTTP/HTTPS work when enabled: Set enable_http=true, apply, test port 80

**Acceptance**:
- SSH connection from any internet IP succeeds on port 22
- Unauthorized ports (e.g., 3306, 5432, 27017) are blocked
- HTTP/HTTPS accessible only when explicitly enabled

### Implementation for User Story 4

- [ ] T031 [US4] Review security group rules in main.tf (verify SSH 22, optional HTTP 80, optional HTTPS 443)
- [ ] T032 [US4] Add conditional ingress rules for HTTP/HTTPS based on variables in main.tf
- [ ] T033 [US4] Apply configuration and test port accessibility (nc -zv tests for ports 22, 80, 443, 3306)
- [ ] T034 [US4] Test unauthorized port blocking (scan common ports: 21, 23, 3389, 5432, 27017)
- [ ] T035 [US4] Document security group configuration in README.md

**Checkpoint**: At this point, User Stories 1-4 should all work - instance has proper network security controls

---

## Phase 7: User Story 5 - Stable Public Access (Priority: P2)

**Goal**: Assign Elastic IP that persists across instance stop/start cycles

**Independent Test**:
- Record initial public IP: `terraform output instance_public_ip`
- Stop instance: `aws ec2 stop-instances --instance-ids <id>`
- Start instance: `aws ec2 start-instances --instance-ids <id>`
- Verify IP unchanged: `terraform output instance_public_ip` matches initial value

**Acceptance**:
- Elastic IP is allocated and associated with instance
- Public IP remains unchanged after stop/start
- Elastic IP is released on instance termination

### Implementation for User Story 5

- [ ] T036 [US5] Verify Elastic IP resource exists in main.tf (already created in T018)
- [ ] T037 [US5] Test instance stop/start cycle preserves IP (stop instance, wait, start instance, check IP)
- [ ] T038 [US5] Verify Elastic IP association in AWS console (EC2 > Elastic IPs)
- [ ] T039 [US5] Document Elastic IP behavior in README.md (stable IP, cost implications)

**Checkpoint**: At this point, User Stories 1-5 should all work - instance has stable public IP address

---

## Phase 8: User Story 6 - Access Monitoring and Logging (Priority: P3)

**Goal**: Capture SSH authentication events in CloudWatch for security monitoring

**Independent Test**:
- Make successful SSH connection: `ssh devuser@<public-ip>`
- Make failed SSH attempt: `ssh devuser@<public-ip>` with wrong password
- Check CloudWatch: Logs appear in /aws/ec2/ssh-auth within 5 minutes
- Verify log content: Logs include timestamp, IP, username, result

**Acceptance**:
- SSH authentication attempts logged to CloudWatch
- Logs include timestamp, source IP, username, result
- Failed authentication attempts recorded with details

### Implementation for User Story 6

- [ ] T040 [US6] Complete CloudWatch Agent configuration in user-data.sh.tpl (install agent, configure auth.log shipping, start service)
- [ ] T041 [US6] Apply configuration and verify CloudWatch Agent installation (terraform apply, check agent status on instance)
- [ ] T042 [US6] Generate test authentication events (successful and failed SSH attempts)
- [ ] T043 [US6] Verify logs appear in CloudWatch Logs within 5 minutes (AWS console or CLI: aws logs tail /aws/ec2/ssh-auth)
- [ ] T044 [US6] Verify log content includes required fields (timestamp, source IP, username, authentication result)
- [ ] T045 [US6] Document CloudWatch logging access in quickstart.md

**Checkpoint**: All user stories should now be independently functional - complete security monitoring in place

---

## Phase 9: Security Hardening (Critical Issues from aws-security-review.md)

**Purpose**: Address CRITICAL and HIGH severity security findings (development environment context)

**Note**: These security issues are acknowledged risks for development use. This phase implements mitigations where feasible without changing core requirements.

- [ ] T046 [P] Add security warning banner to README.md (password auth and 0.0.0.0/0 SSH access are development-only, NOT for production)
- [ ] T047 [P] Document risk acceptance in CONNECTION-GUIDE.md (CRITICAL-001: password authentication, CRITICAL-002: unrestricted SSH)
- [ ] T048 [P] Add terraform.tfvars.example with recommended security settings (ssh_cidr_blocks placeholder for IP restriction)
- [ ] T049 [P] Enable EBS volume encryption in EC2 module configuration (encrypted = true in root_block_device) in main.tf
- [ ] T050 [P] Add VPC Flow Logs configuration in main.tf (optional, can be enabled via variable)
- [ ] T051 Document production security requirements in README.md (key-based auth, IP restrictions, SSM Session Manager, fail2ban, MFA)

---

## Phase 10: Code Quality Improvements (from terraform-best-practices-review.md)

**Purpose**: Apply Terraform best practices and style guidelines

- [ ] T052 [P] Run `terraform fmt -recursive` to format all .tf files
- [ ] T053 [P] Run `terraform validate` to check syntax and configuration
- [ ] T054 [P] Add resource tags to all resources (Name, Environment, ManagedBy, Feature) in main.tf
- [ ] T055 [P] Add variable descriptions and validation rules per contracts/variables-contract.md in variables.tf
- [ ] T056 [P] Add output descriptions per contracts/outputs-contract.md in outputs.tf
- [ ] T057 Run `tflint` to check for best practice violations (if .tflint.hcl exists)
- [ ] T058 Fix any tflint warnings related to module usage and variable definitions

---

## Phase 11: HCP Terraform Workspace Configuration

**Purpose**: Configure HCP Terraform workspace for remote execution

- [ ] T059 Verify HCP Terraform workspace exists (sandbox_public_ec2_dev in ravi-panchal-org)
- [ ] T060 Configure workspace variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (environment variables, sensitive) in HCP Terraform UI
- [ ] T061 [P] Configure workspace settings: execution mode = remote, Terraform version = latest stable
- [ ] T062 [P] Configure workspace tags: environment=dev, feature=001-public-ec2-password-auth
- [ ] T063 Test remote execution: trigger plan from HCP Terraform UI or CLI (terraform plan)
- [ ] T064 Verify state storage in HCP Terraform workspace (check state versions in UI)

---

## Phase 12: Testing and Validation

**Purpose**: End-to-end testing of all user stories

- [ ] T065 Run complete infrastructure provisioning test (terraform destroy, terraform apply)
- [ ] T066 [P] Validate User Story 1: Instance provisioning (check instance state, public IP assignment)
- [ ] T067 [P] Validate User Story 2: SSH password authentication (test successful and failed login attempts)
- [ ] T068 [P] Validate User Story 3: Secure credential management (verify password is sensitive, test retrieval)
- [ ] T069 [P] Validate User Story 4: Network security (test port accessibility, verify unauthorized ports blocked)
- [ ] T070 [P] Validate User Story 5: Stable public access (test stop/start cycle, verify IP unchanged)
- [ ] T071 [P] Validate User Story 6: CloudWatch logging (verify SSH logs appear in CloudWatch)
- [ ] T072 Test quickstart.md walkthrough (follow all steps, verify accuracy, update as needed)
- [ ] T073 Verify cost estimation accuracy (check AWS billing, compare to estimated $10-15/month)

---

## Phase 13: Documentation

**Purpose**: Create comprehensive user and developer documentation

- [ ] T074 [P] Update README.md with feature overview, prerequisites, usage instructions, security warnings
- [ ] T075 [P] Create/update CONNECTION-GUIDE.md with SSH connection instructions, password retrieval, troubleshooting
- [ ] T076 [P] Verify quickstart.md accuracy (all commands work, outputs match expectations)
- [ ] T077 [P] Add cost estimation table to README.md (instance, storage, EIP, CloudWatch breakdown)
- [ ] T078 [P] Document HCP Terraform workspace setup in README.md (organization, workspace, variables)
- [ ] T079 Add troubleshooting section to README.md (common issues, debug steps, recovery procedures)
- [ ] T080 Document infrastructure cleanup process (terraform destroy, verify resource deletion)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - User stories CAN proceed in parallel (if team capacity allows)
  - Or sequentially in priority order (US1 → US2 → US3 → US4 → US5 → US6)
- **Security Hardening (Phase 9)**: Can run in parallel with late-stage user stories (US5, US6)
- **Code Quality (Phase 10)**: Can run in parallel with any phase (non-blocking)
- **HCP Terraform (Phase 11)**: Should be completed early (after Phase 1, before Phase 3)
- **Testing (Phase 12)**: Depends on all user stories being complete
- **Documentation (Phase 13)**: Can run in parallel with late-stage phases

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Depends on User Story 1 (needs running instance) - NOT independently testable until US1 complete
- **User Story 3 (P2)**: Depends on User Story 2 (password authentication exists) - Validates security of US2
- **User Story 4 (P2)**: Can start after Foundational (Phase 2) - Independent of other stories (network config)
- **User Story 5 (P2)**: Depends on User Story 1 (needs instance) - Can be tested independently
- **User Story 6 (P3)**: Depends on User Story 1 and 2 (needs instance and SSH) - Monitors existing functionality

### Critical Path

The critical path for MVP delivery (User Story 1 + User Story 2):

```
Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US1) → Phase 4 (US2) → MVP Complete
```

This represents the minimum deliverable: a running EC2 instance accessible via SSH with password authentication.

### Parallel Opportunities

- **Within Setup (Phase 1)**: T002, T003, T004 can run in parallel
- **Within Foundational (Phase 2)**: T008, T009, T010, T012, T013 can run in parallel (after T007)
- **Within US1 (Phase 3)**: T015, T016 can run in parallel
- **User Stories**: US4 (network security) can start in parallel with US2/US3 (both depend only on US1)
- **Security Hardening (Phase 9)**: T046, T047, T048, T049, T050 all run in parallel
- **Code Quality (Phase 10)**: T052, T053, T054, T055, T056 all run in parallel
- **Testing (Phase 12)**: T066-T071 all run in parallel (after T065 completes)
- **Documentation (Phase 13)**: T074-T078 all run in parallel

---

## Parallel Example: Foundational Phase

```bash
# These tasks can be launched together after T007 completes:

Task T008: Create outputs.tf with all output declarations
Task T009: Create AMI data source in locals.tf
Task T010: Create VPC lookup data source in locals.tf
Task T012: Create CloudWatch log group resource in main.tf
Task T013: Create IAM role and instance profile in main.tf
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

**Target**: Working EC2 instance with SSH access (core functionality)

1. Complete Phase 1: Setup (T001-T006) - ~30 minutes
2. Complete Phase 2: Foundational (T007-T014) - ~1-2 hours
3. Complete Phase 3: User Story 1 (T015-T020) - ~1-2 hours
4. Complete Phase 4: User Story 2 (T021-T025) - ~1 hour
5. **STOP and VALIDATE**: Test SSH access with password authentication
6. **MVP COMPLETE**: Ready for development use

**Total Time**: 4-6 hours for MVP

### Incremental Delivery

After MVP, add features incrementally:

1. **MVP** (US1 + US2): Provision + SSH access → Immediately usable for development
2. **+US3**: Add secure credential management → Production-grade credential handling
3. **+US4**: Add network security config → Proper security controls
4. **+US5**: Add Elastic IP → Stable connectivity
5. **+US6**: Add CloudWatch logging → Security monitoring
6. **+Phase 9**: Apply security hardening → Risk mitigation
7. **+Phase 13**: Complete documentation → Team handoff ready

Each increment adds value without breaking previous functionality.

### Full Implementation Timeline

**Estimated Timeline**: 12-16 hours total

- **Phase 1-2** (Setup + Foundational): 2-3 hours
- **Phase 3-4** (US1 + US2 - MVP): 2-3 hours → **MVP Checkpoint**
- **Phase 5-6** (US3 + US4): 1-2 hours
- **Phase 7-8** (US5 + US6): 1-2 hours
- **Phase 9-10** (Security + Quality): 2-3 hours
- **Phase 11** (HCP Terraform): 1 hour
- **Phase 12-13** (Testing + Docs): 3-4 hours

---

## Notes

- [P] tasks = different files, no dependencies (can run in parallel)
- [Story] label maps task to specific user story for traceability
- User Story 1 must complete before User Story 2 (dependency)
- User Stories 4, 5, 6 can start in parallel after Foundational phase
- Commit after each phase or logical group of tasks
- Stop at any checkpoint to validate story independently
- Security warnings: This is a development-only configuration (password auth + 0.0.0.0/0 SSH)
- HCP Terraform workspace must be configured before Phase 3 (T059-T062 should be done early)
- Testing phase validates all user stories work correctly
- Documentation phase ensures team can use and maintain the infrastructure

---

## Success Criteria Validation

After completing all tasks, verify these success criteria from spec.md:

- **SC-001**: Developer can connect via SSH with password within 2 minutes ✓ (User Story 2)
- **SC-002**: Instance accessible with 99% uptime ✓ (User Story 1)
- **SC-003**: Infrastructure provisioning completes within 10 minutes ✓ (Phase 3)
- **SC-004**: SSH logs appear in CloudWatch within 5 minutes ✓ (User Story 6)
- **SC-005**: Password retrieval requires proper authentication ✓ (User Story 3)
- **SC-006**: All validation checks pass on first attempt ✓ (Phase 12)
- **SC-007**: Monthly cost remains under $20 ✓ (Phase 12)
- **SC-008**: Public IP stable across stop/start ✓ (User Story 5)
- **SC-009**: Authorized SSH connections succeed ✓ (User Story 2)
- **SC-010**: Unauthorized SSH connections denied ✓ (User Story 2)
- **SC-011**: Security group blocks non-authorized ports ✓ (User Story 4)
- **SC-012**: Documentation enables self-service connection ✓ (Phase 13)

---

**Tasks.md Complete** | Total Tasks: 80 | Parallel Opportunities: 25+ | MVP Tasks: 30 | Estimated Time: 12-16 hours (4-6 hours for MVP)
