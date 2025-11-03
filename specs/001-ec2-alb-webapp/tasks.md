# Tasks: Web Application Infrastructure with High Availability

**Input**: Design documents from `/specs/001-ec2-alb-webapp/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/
**Feature Branch**: `001-ec2-alb-webapp`

**Tests**: Not included - testing via ephemeral HCP Terraform workspace with auto-apply/auto-destroy

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create .gitignore file at /workspace/.gitignore with Terraform-specific patterns
- [X] T002 [P] Create terraform.tf at /workspace/terraform.tf with Terraform version constraints (>= 1.0) and HCP Terraform backend configuration
- [X] T003 [P] Create .pre-commit-config.yaml at /workspace/.pre-commit-config.yaml with terraform fmt, validate, docs, tflint, tfsec hooks
- [X] T004 Install pre-commit hooks and run initial validation

**Checkpoint**: Foundation files ready - can proceed with variable and infrastructure definitions

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core variable definitions and IAM resources that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Create variables.tf at /workspace/variables.tf with all input variable declarations (environment, vpc_cidr, domain_name, region, availability_zones, etc.)
- [X] T006 [P] Create random_id resource in main.tf at /workspace/main.tf for S3 bucket suffix generation
- [X] T007 [P] Create IAM role resource aws_iam_role.ec2 in main.tf at /workspace/main.tf with EC2 assume role policy
- [X] T008 [P] Create IAM instance profile resource aws_iam_instance_profile.ec2 in main.tf at /workspace/main.tf
- [X] T009 Create IAM policy attachment aws_iam_role_policy_attachment.ssm in main.tf for Session Manager access
- [X] T010 Create S3 bucket resource aws_s3_bucket.static_content in main.tf at /workspace/main.tf with globally unique name
- [X] T011 [P] Create S3 bucket versioning resource aws_s3_bucket_versioning.static_content in main.tf
- [X] T012 [P] Create S3 bucket encryption resource aws_s3_bucket_server_side_encryption_configuration.static_content in main.tf
- [X] T013 [P] Create S3 bucket public access block resource aws_s3_bucket_public_access_block.static_content in main.tf
- [X] T014 Create IAM inline policy aws_iam_role_policy.s3_read in main.tf for S3 bucket read access (depends on T010)
- [X] T015 Create S3 bucket policy resource aws_s3_bucket_policy.static_content in main.tf allowing EC2 IAM role access (depends on T007, T010)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Access Web Application (Priority: P1) 🎯 MVP

**Goal**: Users can access the web application through a standard web browser to view content, with homepage loading successfully within 3 seconds

**Independent Test**: Navigate to application URL (ALB DNS name) in web browser and verify homepage loads within 3 seconds with 200 status code

### Network Infrastructure for User Story 1

- [X] T016 [P] [US1] Create VPC module instantiation in main.tf at /workspace/main.tf using hashi-demos-apj/vpc/aws v6.5.0
- [X] T017 [P] [US1] Configure VPC module with 2 AZs, public subnets (10.0.1.0/24, 10.0.2.0/24), private subnets (10.0.11.0/24, 10.0.12.0/24)
- [X] T018 [P] [US1] Enable NAT gateway and DNS settings in VPC module configuration

### Security Groups for User Story 1

- [X] T019 [P] [US1] Create ALB security group resource aws_security_group.alb in main.tf with ingress 80/443 from 0.0.0.0/0
- [X] T020 [P] [US1] Create EC2 security group resource aws_security_group.ec2 in main.tf with ingress 80 from ALB SG and egress 80/443 to internet

### SSL/TLS Certificate for User Story 1

- [X] T021 [US1] Create ACM certificate resource aws_acm_certificate.main in main.tf for domain web.simon-lynch.sbx.hashidemos.io with DNS validation
- [X] T022 [US1] Create Route53 validation records resource aws_route53_record.cert_validation in main.tf using for_each loop (requires Route53 zone ID variable)
- [X] T023 [US1] Create ACM certificate validation resource aws_acm_certificate_validation.main in main.tf (depends on T021, T022)

### Load Balancer for User Story 1

- [X] T024 [US1] Create ALB module instantiation in main.tf using terraform-aws-modules/alb/aws v9.0 with vpc_id, public subnets, ALB security group (depends on T016, T019)
- [X] T025 [US1] Configure ALB target group in ALB module with HTTP protocol, port 80, health check path /, interval 30s, thresholds 2/2
- [X] T026 [US1] Configure HTTP listener (port 80) in ALB module with redirect to HTTPS 443 (301 status)
- [X] T027 [US1] Configure HTTPS listener (port 443) in ALB module with ACM certificate ARN and forward to target group (depends on T023)

### Compute Infrastructure for User Story 1

- [X] T028 [US1] Create user data script template in main.tf for Nginx installation, configuration, S3 content sync (references S3 bucket name)
- [X] T029 [US1] Create Auto Scaling Group module instantiation in main.tf using terraform-aws-modules/autoscaling/aws v7.0 with launch template
- [X] T030 [US1] Configure ASG launch template with Amazon Linux 2023 AMI (SSM parameter), t3.micro instance type, EC2 security group, IAM instance profile, user data (depends on T008, T020, T028)
- [X] T031 [US1] Configure ASG parameters min_size=2, max_size=6, desired_capacity=2, private subnets, ELB health check type, 300s grace period (depends on T016, T024)
- [X] T032 [US1] Configure ASG to register instances with ALB target group (depends on T024)

### Outputs for User Story 1

- [X] T033 [P] [US1] Create outputs.tf at /workspace/outputs.tf with VPC ID, public/private subnet IDs, ALB DNS name, ALB zone ID, S3 bucket name
- [X] T034 [P] [US1] Add Auto Scaling Group ID and name outputs in outputs.tf
- [X] T035 [P] [US1] Add IAM role ARN and instance profile name outputs in outputs.tf

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently - users can access web application via ALB DNS over HTTPS

---

## Phase 4: User Story 2 - Continuous Availability (Priority: P2)

**Goal**: Web application remains available 24/7 without interruptions, even when infrastructure components fail or undergo maintenance

**Independent Test**: Terminate one EC2 instance and verify application remains accessible with no user-facing downtime; ALB automatically routes traffic to healthy instance

### High Availability Configuration for User Story 2

- [X] T036 [US2] Verify VPC module creates resources across exactly 2 Availability Zones per requirement (validation check in variables.tf)
- [X] T037 [US2] Verify ALB cross-zone load balancing enabled in ALB module configuration (set enable_cross_zone_load_balancing = true)
- [X] T038 [US2] Verify NAT gateway created per AZ (one_nat_gateway_per_az = true in VPC module) for AZ-level resilience
- [X] T039 [US2] Configure ALB target group deregistration delay to 30 seconds in ALB module for connection draining
- [X] T040 [US2] Verify ASG health check type is ELB (not EC2) so ALB health checks determine instance health
- [X] T041 [US2] Add ASG termination policy ["OldestInstance"] in ASG module configuration for predictable instance replacement

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - application accessible AND highly available across AZ failures

---

## Phase 5: User Story 3 - Scalable Performance (Priority: P3)

**Goal**: Users receive fast response times regardless of concurrent user count; infrastructure automatically scales to handle 200% traffic increases

**Independent Test**: Use load testing tool (e.g., Apache Bench) to simulate 200% baseline traffic and verify response times remain under 3 seconds for 95% of requests; confirm ASG launches additional instances

### Auto Scaling Policy for User Story 3

- [X] T042 [US3] Create target tracking scaling policy in ASG module scaling_policies configuration with predefined metric ASGAverageCPUUtilization
- [X] T043 [US3] Configure scaling policy target value to 50.0 (50% CPU utilization) to maintain headroom for t3.micro instances
- [X] T044 [US3] Set estimated instance warmup to 300 seconds (5 minutes) in scaling policy configuration
- [X] T045 [US3] Verify ASG max_size is at least 3x min_size (6 >= 2*3) for 200% scaling headroom per requirement

### Performance Optimization for User Story 3

- [X] T046 [P] [US3] Enable detailed CloudWatch monitoring for ASG instances (set enable_monitoring = true in launch template)
- [X] T047 [P] [US3] Configure ALB idle timeout to 60 seconds in ALB module configuration for long-running requests
- [X] T048 [US3] Verify launch template block device mapping has gp3 volume type (better performance than gp2) for root volume

**Checkpoint**: All user stories should now be independently functional - application is accessible, highly available, AND auto-scales under load

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and finalize deployment

### Documentation

- [X] T049 [P] Run terraform-docs to auto-generate README.md at /workspace/README.md with module usage, inputs, outputs
- [X] T050 [P] Add architecture diagram to README.md showing VPC, subnets, ALB, ASG, S3 flow
- [X] T051 [P] Document HCP Terraform workspace configuration requirements in README.md (organization, project, workspace names)

### Code Quality

- [X] T052 Run terraform fmt on all .tf files to ensure consistent formatting
- [~] T053 Run terraform validate (requires terraform init first) Run terraform validate to verify syntax and configuration correctness
- [~] T054 Run tflint (requires .tflint.hcl configuration) Run tflint to check for Terraform best practices violations
- [~] T055 Run tfsec (requires terraform init first) Run tfsec to scan for security issues and misconfigurations
- [~] T056 Fix any issues identified (deferred until validation runs) Fix any issues identified by linting and security tools

### HCP Terraform Workspace Setup

- [ ] T057 Create HCP Terraform workspace "webapp-sandbox" in organization hashi-demos-apj, project hackathon (prj-hna8wHXsgBrDhHDz)
- [ ] T058 Configure workspace VCS connection to branch 001-ec2-alb-webapp in repository panchal-ravi/ai-iac-consumer-template
- [ ] T059 Set workspace auto-apply to enabled for sandbox testing
- [ ] T060 Create workspace variable "environment" with value "sandbox" (Terraform variable)
- [ ] T061 Create workspace variable "vpc_cidr" with value "10.0.0.0/16" (Terraform variable)
- [ ] T062 Create workspace variable "domain_name" with value "web.simon-lynch.sbx.hashidemos.io" (Terraform variable)
- [ ] T063 Create workspace variable "region" with value matching AWS deployment region (Terraform variable)
- [ ] T064 Verify AWS credentials available via workspace variable sets (should already exist at organization level)

### Validation and Testing

- [ ] T065 Commit all Terraform code and push to branch 001-ec2-alb-webapp to trigger HCP Terraform run
- [ ] T066 Monitor HCP Terraform plan output and verify ~35-45 resources to be created with no unexpected deletions
- [ ] T067 Review and approve plan in HCP Terraform UI (or auto-apply if enabled)
- [ ] T068 Monitor apply progress and wait for successful completion (estimated 5-10 minutes)
- [ ] T069 Verify all outputs available in HCP Terraform UI (vpc_id, alb_dns_name, s3_bucket_name, etc.)
- [ ] T070 Check AWS Console - verify ALB target group shows 2 healthy targets (may take 2-5 minutes)
- [ ] T071 Test HTTP to HTTPS redirect using curl -I http://<alb-dns-name> (expect 301 redirect)
- [ ] T072 Test HTTPS access using curl -k https://<alb-dns-name> (expect 200 OK with Nginx default page)
- [ ] T073 Verify S3 bucket created and accessible by EC2 instances via Session Manager
- [ ] T074 Upload sample static content to S3 bucket and verify served through ALB

### Deployment Finalization

- [ ] T075 Create Route53 A record alias pointing domain web.simon-lynch.sbx.hashidemos.io to ALB DNS name
- [ ] T076 Wait for ACM certificate validation to complete (DNS validation via Route53 CNAME records)
- [ ] T077 Test application access via custom domain https://web.simon-lynch.sbx.hashidemos.io (no certificate warnings)
- [ ] T078 Verify Auto Scaling policy functioning by checking CloudWatch metrics and scaling activity
- [ ] T079 Document deployment validation results and any deviations from plan in AGENTS.md at /workspace/.claude/AGENTS.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion - No dependencies on other stories
- **User Story 2 (Phase 4)**: Depends on User Story 1 completion - Adds HA configuration to US1 infrastructure
- **User Story 3 (Phase 5)**: Depends on User Story 1 completion - Adds auto-scaling to US1 infrastructure
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories - MVP baseline
- **User Story 2 (P2)**: Requires User Story 1 infrastructure - Enhances with HA configuration across 2 AZs
- **User Story 3 (P3)**: Requires User Story 1 infrastructure - Enhances with auto-scaling policies

### Within Each User Story

- Network infrastructure (VPC) before security groups (need vpc_id)
- Security groups before load balancers (ALB needs security group IDs)
- ACM certificate before HTTPS listener (listener needs certificate ARN)
- Load balancer and target group before ASG registration (ASG needs target group ARN)
- IAM role and S3 bucket before ASG launch template (launch template needs instance profile and user data references)

### Parallel Opportunities

- **Phase 1 Setup**: All tasks marked [P] can run in parallel (T001-T004 are independent files)
- **Phase 2 Foundational**: T006, T007, T008 can run in parallel; T011, T012, T013 can run in parallel after T010
- **User Story 1**:
  - T016, T017, T018 (VPC configuration) can be done together
  - T019, T020 (security groups) can run in parallel after VPC
  - T033, T034, T035 (outputs) can run in parallel
- **User Story 3**: T046, T047, T048 can run in parallel
- **Phase 6 Polish**: T049, T050, T051 can run in parallel; T060-T064 (workspace variables) can be created in parallel

---

## Parallel Example: User Story 1 Network Infrastructure

```bash
# All VPC module configuration can be done together in single module block:
Task T016: Create VPC module instantiation
Task T017: Configure VPC with subnets and AZs
Task T018: Enable NAT gateway and DNS

# Both security groups can be created in parallel (different resources):
Task T019: Create ALB security group
Task T020: Create EC2 security group
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently via HCP Terraform ephemeral workspace
5. Deploy to webapp-sandbox workspace if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy (MVP!)
3. Add User Story 2 → Test independently → Verify HA works
4. Add User Story 3 → Test independently → Verify auto-scaling works
5. Each story adds value without breaking previous stories

### HCP Terraform Testing Strategy

**Ephemeral Workspace Testing** (recommended before sandbox deployment):
1. Create ephemeral test workspace with auto-apply and auto-destroy (2 hours)
2. Deploy all user stories to ephemeral workspace
3. Validate all success criteria met
4. Let auto-destroy clean up resources
5. Deploy to webapp-sandbox workspace with confidence

**Sandbox Workspace Deployment**:
1. Deploy all validated user stories to webapp-sandbox
2. Configure custom domain DNS
3. Upload production static content
4. Monitor for 24 hours
5. Promote to dev → staging → prod workspaces following GitOps workflow

---

## Notes

- [P] tasks = different files/resources, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- All tasks use declarative Terraform - no imperative scripts needed
- HCP Terraform manages remote state automatically - no local state files
- Pre-commit hooks enforce code quality before every commit
- Constitution compliance: Using approved public modules (ALB, ASG) with explicit version constraints
- Estimated total resources: ~40-45 AWS resources across all user stories
- Estimated deployment time: 10-15 minutes for initial apply
- Estimated monthly cost: $100-120 USD for sandbox environment

---

## Validation Checklist

After completing all tasks, verify:

- ✅ All .tf files formatted and validated
- ✅ Pre-commit hooks installed and passing
- ✅ HCP Terraform workspace created and configured
- ✅ Terraform plan shows expected resources (~40-45 resources)
- ✅ Apply completes successfully with no errors
- ✅ ALB DNS accessible via HTTPS with valid certificate
- ✅ Target group shows 2 healthy instances
- ✅ Auto Scaling Group has 2 running instances
- ✅ S3 bucket accessible from EC2 instances
- ✅ HTTP redirects to HTTPS (301)
- ✅ Custom domain resolves to ALB
- ✅ Static content served successfully
- ✅ Auto-scaling policy active and monitoring CPU
- ✅ All outputs documented in README.md
- ✅ No security issues reported by tfsec
