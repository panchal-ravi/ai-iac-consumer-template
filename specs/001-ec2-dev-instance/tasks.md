# Tasks: EC2 Development Instance with Password-Based SSH

**Input**: Design documents from `/specs/001-ec2-dev-instance/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are NOT requested in this specification. Focus on implementation and manual validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

This is a Terraform infrastructure project with files at repository root:
- **Root-level Terraform files**: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `versions.tf`, `locals.tf`, `override.tf`
- **Variable files**: `sandbox.auto.tfvars`, `sandbox.auto.tfvars.example`
- **Documentation**: `README.md`, `specs/001-ec2-dev-instance/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Terraform configuration structure

- [ ] T001 Create versions.tf with Terraform >= 1.5.0 and AWS provider ~> 5.0.0 constraints
- [ ] T002 [P] Create providers.tf with AWS provider configuration using var.aws_region
- [ ] T003 [P] Update override.tf with HCP Terraform backend for workspace sandbox_ec2_dev_instance
- [ ] T004 [P] Create variables.tf with 8 input variable declarations (aws_region, instance_type, root_volume_size, environment, project_name, enable_monitoring, ssh_allowed_cidr_blocks, additional_tags)
- [ ] T005 [P] Create outputs.tf with 11 output value definitions (instance_id, IPs, security_group_id, IAM outputs, log group, connection commands)
- [ ] T006 [P] Create locals.tf with common_tags, security_group_name, iam_role_name, and user_data_script local values
- [ ] T007 [P] Update sandbox.auto.tfvars with environment-specific variable values for testing
- [ ] T008 [P] Create sandbox.auto.tfvars.example as template with placeholder values
- [ ] T009 [P] Update README.md with EC2 dev instance feature overview and quick start reference

**Checkpoint**: Terraform configuration structure complete - ready for resource implementation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T010 Add aws_vpc data source to main.tf for default VPC discovery in us-east-1
- [ ] T011 [P] Add aws_subnets data source to main.tf for public subnet discovery with map-public-ip-on-launch filter
- [ ] T012 [P] Add aws_ami data source to main.tf for latest Amazon Linux 2023 AMI lookup with filters (name: al2023-ami-*-x86_64, virtualization-type: hvm, owner: amazon)
- [ ] T013 Create aws_iam_role resource in main.tf for EC2 SSM role with ec2.amazonaws.com trust policy (enables Session Manager backup access)
- [ ] T014 Create aws_iam_role_policy_attachment resource in main.tf attaching AmazonSSMManagedInstanceCore managed policy to SSM role
- [ ] T015 Create aws_iam_instance_profile resource in main.tf associating SSM role for EC2 instance attachment
- [ ] T016 Create aws_cloudwatch_log_group resource in main.tf for SSH authentication logs with 7-day retention and KMS encryption (FR-020)
- [ ] T017 Create aws_security_group resource in main.tf allowing SSH ingress (port 22, TCP, 0.0.0.0/0) and all egress traffic

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Infrastructure Deployment (Priority: P1) 🎯 MVP

**Goal**: Deploy a running EC2 instance with public IP through HCP Terraform so DevOps engineer can establish development environment quickly

**Independent Test**: Run terraform apply through HCP Terraform and verify instance appears in AWS Console with correct tags, network configuration, and "running" state with elastic IP attached

### Implementation for User Story 1

- [ ] T018 [US1] Create aws_instance resource in main.tf with t3.micro instance_type, Amazon Linux 2023 AMI reference, subnet placement, IAM instance profile attachment, security group association, and required tags (Environment=development, Project=ec2-dev-instance, ManagedBy=terraform, PublicAccess=true)
- [ ] T019 [US1] Configure root block device in aws_instance with 30GB gp3 volume, encrypted=true, delete_on_termination=true (addressing security review EBS encryption requirement)
- [ ] T020 [US1] Add CloudWatch monitoring configuration to aws_instance with monitoring=false for basic 5-minute metrics (FR-024)
- [ ] T021 [US1] Create aws_eip resource in main.tf for elastic IP with domain="vpc" and instance association to ensure consistent public IP across reboots (FR-002)
- [ ] T022 [US1] Add lifecycle block to aws_eip with create_before_destroy=true to prevent IP address changes during updates
- [ ] T023 [US1] Validate all required tags are applied to aws_instance: Environment, Project, ManagedBy, PublicAccess (FR-005)
- [ ] T024 [US1] Update outputs.tf to ensure instance_id, instance_public_ip, instance_private_ip, elastic_ip_id, ssh_connection_command, and session_manager_command outputs are correctly referencing created resources

**Checkpoint**: At this point, User Story 1 should be fully functional - infrastructure deployed and testable independently via AWS Console and terraform outputs

---

## Phase 4: User Story 2 - SSH Access Configuration (Priority: P2)

**Goal**: Enable SSH connection using username 'devuser' and password so developer can access the development environment without managing SSH key pairs

**Independent Test**: Attempt SSH connection from any workstation using `ssh devuser@<elastic-ip>` with password authentication. Connection succeeds and user gains shell access with sudo privileges.

### Implementation for User Story 2

- [ ] T025 [US2] Create user-data script in locals.tf creating 'devuser' account with useradd, adding to wheel group for sudo, and configuring home directory with /bin/bash shell (FR-007)
- [ ] T026 [US2] Add SSH daemon configuration to user-data script in locals.tf setting PasswordAuthentication=yes, PubkeyAuthentication=no, PermitRootLogin=no (FR-008, FR-009)
- [ ] T027 [US2] Configure SSH session timeouts in user-data script with ClientAliveInterval=900 and ClientAliveCountMax=2 for 30-minute idle timeout (FR-011)
- [ ] T028 [US2] Add SSH service restart and enable commands to user-data script ensuring sshd starts on boot (FR-010)
- [ ] T029 [US2] Configure PAM password quality settings in user-data script with minlen=14, minclass=4, dcredit=-1, ucredit=-1, lcredit=-1, ocredit=-1 in /etc/security/pwquality.conf (FR-012, FR-013)
- [ ] T030 [US2] Add password expiry policy to user-data script using chage command: -M 90 (max days), -m 1 (min days), -W 7 (warning days) for devuser account (FR-017)
- [ ] T031 [US2] Add user-data script reference to aws_instance resource in main.tf using base64encode function with local.user_data_script value
- [ ] T032 [US2] Update README.md with post-deployment instructions: "After infrastructure deployment, connect via Session Manager and set devuser password using 'sudo passwd devuser' command" (FR-011a)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - SSH access functional after password set via Session Manager

---

## Phase 5: User Story 3 - Security Hardening (Priority: P3)

**Goal**: Enforce strong password policies and automatic brute-force protection so development environment maintains basic security standards despite public exposure

**Independent Test**: Attempt SSH login with weak passwords (should be rejected), attempt 5+ failed logins (should trigger fail2ban IP block for 1 hour), verify password complexity requirements enforced

### Implementation for User Story 3

- [ ] T033 [US3] Add fail2ban installation to user-data script in locals.tf using yum install -y fail2ban fail2ban-systemd (FR-014)
- [ ] T034 [US3] Create fail2ban jail configuration in user-data script writing /etc/fail2ban/jail.local with [sshd] section: enabled=true, port=ssh, logpath=/var/log/secure, maxretry=5, findtime=600, bantime=3600 (FR-015)
- [ ] T035 [US3] Add fail2ban service enable and start commands to user-data script with systemctl enable fail2ban and systemctl start fail2ban
- [ ] T036 [US3] Configure all SSH authentication logging to /var/log/secure in user-data script (FR-016)
- [ ] T037 [US3] Add validation check to user-data script verifying fail2ban service is active before completion
- [ ] T038 [US3] Update quickstart.md documentation section with fail2ban testing instructions: "Test by attempting 5 failed SSH logins - 6th attempt should be blocked"

**Checkpoint**: All user stories should now be independently functional - security hardening active with fail2ban protecting against brute-force attacks

---

## Phase 6: User Story 4 - Monitoring and Observability (Priority: P4)

**Goal**: Monitor SSH authentication attempts and basic instance metrics so DevOps engineer can detect unauthorized access attempts and track resource utilization

**Independent Test**: Generate SSH login attempts (successful and failed) and verify they appear in CloudWatch Logs within 5 minutes with username and source IP. Delivers operational visibility.

### Implementation for User Story 4

- [ ] T039 [US4] Add CloudWatch agent installation to user-data script in locals.tf using yum install -y amazon-cloudwatch-agent
- [ ] T040 [US4] Create CloudWatch agent configuration in user-data script writing /opt/aws/amazon-cloudwatch-agent/etc/config.json with logs.logs_collected.files.collect_list entry for /var/log/secure file (FR-019)
- [ ] T041 [US4] Configure CloudWatch agent log stream naming in config.json using {instance_id} placeholder and log_group_name=/aws/ec2/dev-instance/ssh-auth with timezone=UTC
- [ ] T042 [US4] Add IAM permissions validation to user-data script checking instance profile has CloudWatch Logs PutLogEvents permission (included in AmazonSSMManagedInstanceCore)
- [ ] T043 [US4] Add CloudWatch agent start command to user-data script using /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
- [ ] T044 [US4] Update aws_cloudwatch_log_group resource in main.tf to add KMS encryption with kms_key_id argument for log encryption at rest (addressing security review CloudWatch KMS recommendation)
- [ ] T045 [US4] Verify CloudWatch log group retention is set to exactly 7 days in aws_cloudwatch_log_group resource (FR-020, FR-025)
- [ ] T046 [US4] Add CloudWatch monitoring validation to quickstart.md: "Verify logs with: aws logs tail /aws/ec2/dev-instance/ssh-auth --follow"

**Checkpoint**: All user stories complete - full observability with CloudWatch logging of SSH authentication events and basic instance metrics

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final validation

- [ ] T047 [P] Add comprehensive variable validation blocks to variables.tf for aws_region (regex pattern), instance_type (t3.* family), root_volume_size (30-100 range), environment (dev/development/sandbox), project_name (alphanumeric 1-32 chars)
- [ ] T048 [P] Add variable descriptions and examples to all variables in variables.tf with cost impact notes where applicable
- [ ] T049 [P] Review and enhance all output descriptions in outputs.tf with use case examples
- [ ] T050 [P] Add depends_on meta-arguments to aws_instance resource ensuring IAM instance profile and CloudWatch log group are created first
- [ ] T051 [P] Add tags to all taggable resources in main.tf using merge(local.common_tags, var.additional_tags) pattern
- [ ] T052 Validate user-data script syntax in locals.tf with proper bash error handling (set -e, error logging)
- [ ] T053 [P] Create comprehensive comments in main.tf documenting each resource purpose and FR requirement mapping
- [ ] T054 [P] Update quickstart.md with complete testing section covering all 4 user stories' acceptance criteria
- [ ] T055 Run terraform fmt on all .tf files to ensure consistent formatting
- [ ] T056 Run terraform validate to ensure configuration syntax is correct
- [ ] T057 Run tflint to check for AWS-specific issues and best practices
- [ ] T058 Run pre-commit hooks to validate constitution compliance
- [ ] T059 Execute quickstart.md validation: Follow deployment guide end-to-end and verify all 4 user stories function independently
- [ ] T060 [P] Create git commit with message: "feat: implement EC2 dev instance with password SSH (US1-US4)" following conventional commits
- [ ] T061 Create pull request from 001-ec2-dev-instance to dev branch with spec.md, plan.md, and quickstart.md references

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-6)**: All depend on Foundational phase completion
  - User Story 1 (P1): Can start after Foundational - No dependencies on other stories
  - User Story 2 (P2): Depends on User Story 1 (requires EC2 instance from US1) - Adds user-data to existing instance
  - User Story 3 (P3): Depends on User Story 2 (requires SSH configuration from US2) - Extends user-data script
  - User Story 4 (P4): Depends on User Story 1 and Foundational (requires EC2 instance and CloudWatch log group) - Parallel with US2/US3
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Creates EC2 instance infrastructure
- **User Story 2 (P2)**: Depends on User Story 1 - Adds SSH configuration to instance via user-data
- **User Story 3 (P3)**: Depends on User Story 2 - Extends user-data with fail2ban security hardening
- **User Story 4 (P4)**: Depends on User Story 1 (instance) and Foundational (log group) - Can be parallel with US2/US3 but user-data script must be coordinated

**Note**: User Stories 2, 3, and 4 all modify the user-data script in locals.tf, so they should be implemented sequentially to avoid conflicts, even though US4 could theoretically be parallel.

### Within Each User Story

- **User Story 1**: T018 (instance) → T019 (EBS config) → T020 (monitoring) → T021 (EIP) → T022 (lifecycle) → T023 (tags) → T024 (outputs)
- **User Story 2**: User-data script tasks can be done in any order (T025-T030), then T031 adds to instance, T032 updates docs
- **User Story 3**: fail2ban tasks sequential (T033 install → T034 config → T035 enable → T036 logging → T037 validation → T038 docs)
- **User Story 4**: CloudWatch tasks sequential (T039 install → T040-T041 config → T042 permissions → T043 start → T044-T045 log group updates → T046 docs)

### Parallel Opportunities

- **Setup Phase**: T002-T009 can all run in parallel (different files)
- **Foundational Phase**: T011-T012 (data sources) can run in parallel; T014-T015 must be sequential (role → attachment → profile)
- **User Story 1**: T019-T020 can run in parallel (both edit aws_instance); T023-T024 can run in parallel
- **Polish Phase**: T047-T049 (documentation) can run in parallel; T053-T054 (docs) can run in parallel; T055-T058 (validation) should be sequential

---

## Parallel Example: Setup Phase

```bash
# Launch all Setup documentation tasks together:
Task T002: "Create providers.tf with AWS provider configuration"
Task T003: "Update override.tf with HCP Terraform backend"
Task T004: "Create variables.tf with input variable declarations"
Task T005: "Create outputs.tf with output value definitions"
Task T006: "Create locals.tf with local values"
Task T007: "Update sandbox.auto.tfvars with variable values"
Task T008: "Create sandbox.auto.tfvars.example template"
Task T009: "Update README.md with feature overview"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T009)
2. Complete Phase 2: Foundational (T010-T017) - CRITICAL - blocks all stories
3. Complete Phase 3: User Story 1 (T018-T024)
4. **STOP and VALIDATE**: Deploy via HCP Terraform and verify instance appears in AWS Console
5. Verify outputs show instance_id and instance_public_ip
6. Check AWS Console shows running instance with correct tags

**At this point you have a minimal viable EC2 instance deployment** - not yet usable for SSH but infrastructure is deployed.

### Incremental Delivery

1. Complete Setup + Foundational (T001-T017) → Foundation ready
2. Add User Story 1 (T018-T024) → Deploy/Validate → EC2 instance running with Elastic IP (MVP infrastructure!)
3. Add User Story 2 (T025-T032) → Deploy/Validate → SSH access functional with password authentication
4. Add User Story 3 (T033-T038) → Deploy/Validate → Security hardening with fail2ban active
5. Add User Story 4 (T039-T046) → Deploy/Validate → Full monitoring with CloudWatch logs
6. Complete Polish (T047-T061) → Final validation and PR creation

Each story adds value without breaking previous stories - infrastructure evolves incrementally.

### Sequential Implementation (Recommended)

Due to user-data script dependencies (US2, US3, US4 all modify same script):

1. **Week 1**: Setup + Foundational + User Story 1 (Core infrastructure)
2. **Week 2**: User Story 2 (SSH access) - Test and validate
3. **Week 3**: User Story 3 (Security hardening) - Test and validate
4. **Week 4**: User Story 4 (Monitoring) - Test and validate
5. **Week 5**: Polish and final validation

---

## Testing Validation Checklist

After completing all tasks, validate against spec.md acceptance scenarios:

### User Story 1 - Infrastructure Deployment
- [ ] Terraform plan shows EC2 instance, security group, EIP creation with no errors
- [ ] t3.micro instance exists in us-east-1 with status "running" in AWS Console
- [ ] Instance has elastic IP attached and is in default VPC public subnet
- [ ] HCP Terraform workspace shows successful apply with output values for instance ID and public IP

### User Story 2 - SSH Access Configuration
- [ ] SSH connection succeeds using `ssh devuser@<elastic-ip>` with correct password (after password set via Session Manager)
- [ ] Security group shows inbound rule allowing TCP port 22 from 0.0.0.0/0
- [ ] Incorrect password attempts fail with proper error message
- [ ] SSH session automatically disconnects after 30 minutes of idle time

### User Story 3 - Security Hardening
- [ ] Password with less than 14 characters is rejected during setup
- [ ] Password without special characters is rejected per strong password policy
- [ ] 5 failed SSH login attempts from same IP results in 1-hour block (6th attempt fails)
- [ ] fail2ban blocking event recorded in logs with timestamp, IP address, and reason

### User Story 4 - Monitoring and Observability
- [ ] SSH authentication success event appears in CloudWatch Logs within 2 minutes with username and source IP
- [ ] SSH authentication failure event appears in CloudWatch Logs within 2 minutes with attempted username and source IP
- [ ] Basic monitoring metrics (CPU, network) visible in CloudWatch with 5-minute granularity
- [ ] CloudWatch Logs retention set to exactly 7 days (verify in console)

### Success Criteria Validation (from spec.md)
- [ ] SC-001: Infrastructure deployment completes within 5 minutes from Terraform apply to running state
- [ ] SC-002: SSH connection establishment succeeds within 10 seconds of entering correct credentials
- [ ] SC-003: Failed SSH attempts blocked after 5 attempts within 10 minutes
- [ ] SC-004: SSH authentication events appear in CloudWatch Logs within 2 minutes
- [ ] SC-005: Estimated monthly cost under $50 (actual ~$10/month: check AWS Cost Explorer)

---

## Notes

- **[P] tasks**: Different files, no dependencies - can be parallelized
- **[Story] label**: Maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each user story phase completion for incremental progress
- Stop at any checkpoint to validate story independently
- **Security Review**: EBS encryption and CloudWatch KMS encryption requirements addressed in T019 and T044
- **HCP Terraform**: All deployments through workspace sandbox_ec2_dev_instance
- **Password Setup**: MUST be done via Session Manager after deployment (T032) - never in code or state
- **Cost Optimization**: Basic monitoring (T020), 7-day log retention (T016), t3.micro instance (T018)

---

## File-to-Task Mapping

For reference, here's which tasks modify which files:

- **versions.tf**: T001
- **providers.tf**: T002
- **override.tf**: T003
- **variables.tf**: T004, T047, T048
- **outputs.tf**: T005, T024, T049
- **locals.tf**: T006, T025-T030, T033-T036, T039-T043, T052
- **sandbox.auto.tfvars**: T007
- **sandbox.auto.tfvars.example**: T008
- **README.md**: T009, T032
- **main.tf**: T010-T021, T023, T044-T045, T050-T051, T053
- **quickstart.md**: T038, T046, T054
- **All .tf files**: T055-T058 (formatting and validation)

---

**Total Tasks**: 61 tasks organized into 7 phases
**Estimated Duration**: 4-5 weeks for complete implementation
**MVP Milestone**: Phase 3 completion (User Story 1) - deployable EC2 infrastructure
**Full Feature**: Phase 6 completion (User Story 4) - production-ready development instance
