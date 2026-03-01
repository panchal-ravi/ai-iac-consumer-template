# Tasks: AWS EC2 Infrastructure with Application Load Balancer and Nginx

**Input**: Design documents from `/specs/001-ec2-alb-nginx/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Tests are NOT explicitly requested in the feature specification. Test validation will be manual per quickstart.md.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Since this is infrastructure code, user stories represent different infrastructure components that can be validated independently.

## Format: `- [ ] [ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Terraform configuration

- [ ] T001 Create terraform/ directory structure at repository root
- [ ] T002 [P] Create terraform/versions.tf with Terraform >= 1.7.0 and provider version constraints (AWS ~> 5.0, TLS ~> 4.0)
- [ ] T003 [P] Create terraform/providers.tf with AWS provider configuration for ap-southeast-1 region and default tags
- [ ] T004 [P] Create terraform/variables.tf with input variable definitions and validation rules
- [ ] T005 [P] Create terraform/outputs.tf with output value definitions per contracts/terraform-outputs.md
- [ ] T006 Verify HCP Terraform workspace "sandbox_workspace" exists in organization "ravi-panchal-org"
- [ ] T007 Configure HCP Terraform workspace variables for AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY as sensitive)
- [ ] T008 Run terraform init to validate configuration and download providers

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Data sources and shared resources that MUST be complete before ANY user story infrastructure can be deployed

**⚠️ CRITICAL**: No infrastructure provisioning can begin until this phase is complete

- [ ] T009 [P] Create data source for default VPC in terraform/main.tf
- [ ] T010 [P] Create data source for availability zones in ap-southeast-1 in terraform/main.tf
- [ ] T011 [P] Create data source for default subnets filtered by AZs (ap-southeast-1a, ap-southeast-1b) in terraform/main.tf
- [ ] T012 [P] Create data source for latest Amazon Linux 2023 AMI using SSM parameter in terraform/main.tf
- [ ] T013 Run terraform validate to verify all data sources are correctly configured
- [ ] T014 Run terraform plan to confirm data sources can be resolved successfully

**Checkpoint**: Foundation ready - infrastructure provisioning can now begin

---

## Phase 3: User Story 1 - Deploy Basic Infrastructure (Priority: P1) 🎯 MVP

**Goal**: Provision two t3.micro EC2 instances running across different availability zones in the default VPC

**Independent Test**: Verify EC2 instances are running in different AZs by checking instance metadata and AWS console. SSH is not required - validation via AWS CLI.

### Implementation for User Story 1

- [ ] T015 [P] [US1] Create user data script terraform/user-data.sh for Nginx installation with HTML test page
- [ ] T016 [P] [US1] Create EC2 security group module call in terraform/main.tf allowing HTTP:80 from ALB security group (placeholder for now)
- [ ] T017 [US1] Create first EC2 instance module call in terraform/main.tf for ap-southeast-1a using ravi-panchal-org/ec2-instance/aws v6.1.4
- [ ] T018 [US1] Create second EC2 instance module call in terraform/main.tf for ap-southeast-1b using ravi-panchal-org/ec2-instance/aws v6.1.4
- [ ] T019 [US1] Configure both EC2 instances with t3.micro, user_data script, security group, and IMDSv2 enforcement
- [ ] T020 [US1] Add outputs in terraform/outputs.tf for ec2_instance_ids, ec2_availability_zones, ec2_public_ips
- [ ] T021 [US1] Run terraform plan and verify 2 EC2 instances will be created in different AZs
- [ ] T022 [US1] Create terraform/sandbox.auto.tfvars with environment-specific values (instance_type, environment, project_name)
- [ ] T023 [US1] Document planned changes in terraform/DEPLOYMENT_PLAN.md including resource counts and estimated costs

**Checkpoint**: At this point, EC2 infrastructure is defined and can be deployed independently (though without load balancer access)

---

## Phase 4: User Story 2 - Configure Web Server with HTTPS (Priority: P1)

**Goal**: Install and configure Nginx web server on EC2 instances with a self-signed TLS certificate for "web.demo.com"

**Independent Test**: Certificate is generated and available in Terraform state. Nginx installation validated through user data script execution (visible in CloudWatch logs or instance status).

### Implementation for User Story 2

- [ ] T024 [P] [US2] Create tls_private_key resource in terraform/main.tf for RSA 2048-bit private key
- [ ] T025 [US2] Create tls_self_signed_cert resource in terraform/main.tf with subject CN=web.demo.com and 5-year validity (depends on T024)
- [ ] T026 [US2] Configure TLS certificate with Subject Alternative Names (web.demo.com, *.web.demo.com) in terraform/main.tf
- [ ] T027 [US2] Verify user-data.sh script (from T015) includes Nginx installation commands for Amazon Linux 2023
- [ ] T028 [US2] Update user-data.sh to include systemd enable and start commands for Nginx service
- [ ] T029 [US2] Update user-data.sh to create HTML test page at /usr/share/nginx/html/index.html with instance metadata
- [ ] T030 [US2] Add outputs in terraform/outputs.tf for certificate details (subject, expiry date, fingerprint)
- [ ] T031 [US2] Run terraform plan and verify TLS resources will be created with correct domain

**Checkpoint**: At this point, TLS certificate is generated and Nginx configuration is embedded in user data

---

## Phase 5: User Story 3 - Import Certificate to AWS Certificate Manager (Priority: P1)

**Goal**: Import the self-signed TLS certificate into AWS Certificate Manager for use by the Application Load Balancer

**Independent Test**: Certificate appears in ACM console with domain "web.demo.com" and can be referenced by ARN

### Implementation for User Story 3

- [ ] T032 [US3] Create aws_acm_certificate resource in terraform/main.tf to import self-signed certificate (depends on T024, T025)
- [ ] T033 [US3] Configure ACM certificate import with certificate_body, private_key, and certificate_chain (none for self-signed)
- [ ] T034 [US3] Add lifecycle rule to prevent recreation of ACM certificate on non-critical changes
- [ ] T035 [US3] Add output in terraform/outputs.tf for acm_certificate_arn
- [ ] T036 [US3] Run terraform plan and verify ACM certificate will be imported successfully

**Checkpoint**: At this point, certificate is ready to be used by ALB HTTPS listener

---

## Phase 6: User Story 6 - Configure Security Groups (Priority: P1)

**Goal**: Configure network security groups with least-privilege rules to control traffic between internet, ALB, and EC2

**Independent Test**: Security group rules verified in AWS console. Direct internet access to EC2 port 80 is blocked, ALB can communicate with EC2.

### Implementation for User Story 6

- [ ] T037 [P] [US6] Create ALB security group module call in terraform/main.tf using ravi-panchal-org/security-group/aws v5.3.1
- [ ] T038 [US6] Configure ALB security group with ingress rule allowing HTTPS:443 from 0.0.0.0/0 in terraform/main.tf
- [ ] T039 [US6] Configure ALB security group with egress rule allowing HTTP:80 to EC2 security group reference in terraform/main.tf
- [ ] T040 [US6] Update EC2 security group (from T016) with ingress rule allowing HTTP:80 ONLY from ALB security group ID
- [ ] T041 [US6] Configure EC2 security group with egress rules allowing HTTPS:443 and HTTP:80 to 0.0.0.0/0 for package updates
- [ ] T042 [US6] Add outputs in terraform/outputs.tf for alb_security_group_id and ec2_security_group_id
- [ ] T043 [US6] Run terraform plan and verify security group rules are correctly configured with security group references (not CIDR)

**Checkpoint**: At this point, security groups enforce least-privilege access: Internet → ALB (443) → EC2 (80)

---

## Phase 7: User Story 4 - Deploy Application Load Balancer with HTTPS (Priority: P2)

**Goal**: Create internet-facing Application Load Balancer with HTTPS listener using ACM certificate and TLS termination

**Independent Test**: ALB DNS endpoint accessible via HTTPS (with browser warning for self-signed cert). TLS termination verified with openssl s_client.

### Implementation for User Story 4

- [ ] T044 [US4] Create ALB target group with health check configuration in terraform/main.tf for HTTP:80 path /
- [ ] T045 [US4] Configure target group health check parameters (interval=30s, timeout=5s, healthy_threshold=2, unhealthy_threshold=2)
- [ ] T046 [US4] Create Application Load Balancer module call in terraform/main.tf using ravi-panchal-org/alb/aws v10.2.0
- [ ] T047 [US4] Configure ALB as internet-facing across both AZ subnets with ALB security group (depends on T037-T039, T011)
- [ ] T048 [US4] Create ALB HTTPS listener on port 443 with ACM certificate ARN and forward action to target group (depends on T032)
- [ ] T049 [US4] Configure ALB listener to use TLS 1.2+ and forward traffic to target group via HTTP:80
- [ ] T050 [US4] Add outputs in terraform/outputs.tf for alb_dns_name, alb_arn, alb_endpoint (https://DNS), target_group_arn
- [ ] T051 [US4] Run terraform plan and verify ALB with HTTPS listener will be created with correct certificate and target group

**Checkpoint**: At this point, ALB is defined and will terminate TLS connections, forwarding HTTP to backend

---

## Phase 8: User Story 5 - Configure Health Checks and Target Group (Priority: P2)

**Goal**: Register EC2 instances with target group and configure health checks for automatic failover

**Independent Test**: Health checks show both instances as healthy in target group. Stopping Nginx on one instance causes ALB to route only to healthy instance.

### Implementation for User Story 5

- [ ] T052 [US5] Create first target group attachment resource in terraform/main.tf registering EC2 instance 1 (depends on T017, T044)
- [ ] T053 [US5] Create second target group attachment resource in terraform/main.tf registering EC2 instance 2 (depends on T018, T044)
- [ ] T054 [US5] Verify target group health check configuration from T045 (HTTP GET / on port 80)
- [ ] T055 [US5] Add output in terraform/outputs.tf for target_group_targets with instance IDs and health check path
- [ ] T056 [US5] Run terraform plan and verify both EC2 instances will be registered with target group
- [ ] T057 [US5] Update terraform/DEPLOYMENT_PLAN.md with complete infrastructure graph showing all dependencies

**Checkpoint**: At this point, complete infrastructure is defined and ready for deployment validation

---

## Phase 9: Security Enhancements (from aws-security-review.md)

**Purpose**: Address high-priority security findings from security review

- [ ] T058 [P] Create S3 bucket resource in terraform/main.tf for ALB access logs with server-side encryption (SSE-S3)
- [ ] T059 [P] Create S3 bucket lifecycle configuration in terraform/main.tf to expire logs after 90 days
- [ ] T060 [P] Create S3 bucket policy in terraform/main.tf granting elasticloadbalancing.amazonaws.com PutObject permission
- [ ] T061 Update ALB module call (from T046) to enable access_logs with S3 bucket and prefix "alb/" (depends on T058-T060)
- [ ] T062 [P] Enable EBS encryption by default using aws_ebs_encryption_by_default resource in terraform/main.tf
- [ ] T063 Update EC2 instance module calls (T017, T018) to explicitly set root_block_device encrypted=true
- [ ] T064 [P] Create CloudWatch alarm resource for ALB UnHealthyHostCount in terraform/main.tf with SNS notification (optional)
- [ ] T065 [P] Create CloudWatch alarm resource for ALB HTTP 5XX errors in terraform/main.tf with SNS notification (optional)
- [ ] T066 Add outputs in terraform/outputs.tf for alb_logs_bucket and cloudwatch_alarm_arns
- [ ] T067 Run terraform plan and verify security enhancements will be applied

---

## Phase 10: Testing & Validation

**Purpose**: Verify infrastructure deployment and validate all acceptance criteria

- [ ] T068 Run terraform init to ensure all modules and providers are initialized
- [ ] T069 Run terraform validate to check configuration syntax and consistency
- [ ] T070 Run terraform plan and review complete infrastructure changes (save plan output to terraform/PLAN_OUTPUT.txt)
- [ ] T071 Verify plan output shows: 2 EC2 instances, 1 ALB, 1 target group, 2 security groups, TLS resources, ACM cert, S3 bucket
- [ ] T072 Review estimated monthly cost in plan output and confirm under $50 budget
- [ ] T073 Execute terraform apply to provision infrastructure (expected duration: 5-8 minutes)
- [ ] T074 Verify terraform apply completes successfully with all resources created
- [ ] T075 Test ALB HTTPS endpoint using curl: `curl -k https://<alb-dns-name>` returns HTTP 200 with test page
- [ ] T076 Verify TLS certificate using openssl: `openssl s_client -connect <alb-dns>:443 -servername web.demo.com`
- [ ] T077 Check target group health status: `aws elbv2 describe-target-health --target-group-arn <arn> --region ap-southeast-1`
- [ ] T078 Verify both EC2 instances report as "healthy" in target group
- [ ] T079 Test direct EC2 access blocked: `curl http://<ec2-public-ip>` should timeout or refuse connection
- [ ] T080 Validate security group rules in AWS console match least-privilege requirements
- [ ] T081 Test failover: Stop Nginx on one instance and verify ALB continues serving traffic from healthy instance
- [ ] T082 Check CloudWatch metrics for ALB: RequestCount, TargetResponseTime, HealthyHostCount
- [ ] T083 Verify S3 bucket contains ALB access logs within 5 minutes of traffic
- [ ] T084 Validate all resources are tagged correctly with Environment, Project, ManagedBy, Owner tags

---

## Phase 11: Documentation

**Purpose**: Create deployment documentation and operational guides

- [ ] T085 [P] Create terraform/README.md with deployment instructions, prerequisites, and usage examples
- [ ] T086 [P] Update specs/001-ec2-alb-nginx/quickstart.md with actual deployment results and timing
- [ ] T087 [P] Document terraform outputs in README.md explaining each output value's purpose
- [ ] T088 [P] Create terraform/TROUBLESHOOTING.md with common issues and resolution steps
- [ ] T089 Create terraform/ARCHITECTURE.md with architecture diagram and component descriptions
- [ ] T090 Document cost breakdown in terraform/COSTS.md comparing estimated vs actual monthly costs
- [ ] T091 [P] Add security group rules documentation in terraform/SECURITY.md
- [ ] T092 Create terraform/ROLLBACK.md with disaster recovery and rollback procedures
- [ ] T093 Update specs/001-ec2-alb-nginx/contracts/terraform-outputs.md with actual output values and verification commands
- [ ] T094 Run validation tests from quickstart.md and document results

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) - BLOCKS all infrastructure provisioning
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) - EC2 infrastructure definition
- **User Story 2 (Phase 4)**: Can proceed in parallel with US1 - TLS certificate generation (no dependencies on US1)
- **User Story 3 (Phase 5)**: Depends on User Story 2 (TLS cert must exist before ACM import)
- **User Story 6 (Phase 6)**: Can proceed in parallel with US1-3 - Security groups (no dependencies)
- **User Story 4 (Phase 7)**: Depends on US3 (ACM cert) and US6 (security groups) - ALB creation
- **User Story 5 (Phase 8)**: Depends on US1 (EC2 instances) and US4 (target group) - Target registration
- **Security Enhancements (Phase 9)**: Can proceed after US4 (ALB exists) - S3 logging and encryption
- **Testing (Phase 10)**: Depends on all implementation phases (1-9) complete
- **Documentation (Phase 11)**: Can proceed in parallel with testing

### User Story Dependencies (Terraform Resource Dependencies)

```
Phase 2 (Foundational)
  ├─ Data Sources (VPC, Subnets, AZs, AMI)
  │
  ├─ Phase 4 (US2 - TLS Certificate)
  │   └─ tls_private_key → tls_self_signed_cert
  │       └─ Phase 5 (US3 - ACM Import)
  │           └─ aws_acm_certificate
  │
  ├─ Phase 6 (US6 - Security Groups)
  │   ├─ ALB Security Group
  │   └─ EC2 Security Group (references ALB SG)
  │
  ├─ Phase 3 (US1 - EC2 Instances)
  │   ├─ Depends on: EC2 Security Group, Subnets, AMI
  │   └─ EC2 Instance 1, EC2 Instance 2
  │
  └─ Phase 7 (US4 - ALB)
      ├─ Depends on: ALB Security Group, ACM Certificate, Subnets
      ├─ Target Group (depends on VPC)
      └─ ALB Listener (depends on ALB, Target Group, ACM Cert)
          └─ Phase 8 (US5 - Target Registration)
              └─ Depends on: EC2 Instances, Target Group
```

### Critical Path (Sequential Tasks)

1. **T001-T008**: Setup (Terraform configuration files)
2. **T009-T014**: Data sources (MUST resolve before any resources)
3. **T024-T026**: TLS certificate generation (MUST exist before ACM import)
4. **T032-T036**: ACM certificate import (MUST exist before ALB listener)
5. **T037-T043**: Security groups (MUST exist before EC2 and ALB)
6. **T015-T023**: EC2 instances (MUST exist before target registration)
7. **T044-T051**: ALB and listener (MUST exist before target registration)
8. **T052-T057**: Target group registration (final step before testing)

### Parallel Opportunities

**Phase 1 (Setup)**: Tasks T002-T005 can run in parallel (different files)

**Phase 2 (Foundational)**: Tasks T009-T012 can run in parallel (independent data sources)

**User Stories (after Foundational complete)**:
- US2 (TLS cert) and US6 (Security groups) can proceed in parallel
- US1 (EC2) can start as soon as US6 security groups are defined
- US4 (ALB) can start as soon as US3 (ACM) and US6 (SG) are complete

**Phase 9 (Security)**: Tasks T058-T060 (S3 setup) and T062-T063 (EBS encryption) can run in parallel

**Phase 11 (Documentation)**: Tasks T085-T094 can run in parallel (different documentation files)

---

## Parallel Example: Security Groups (User Story 6)

```bash
# These tasks can run in parallel (different resources):
Task T037: "Create ALB security group module call in terraform/main.tf"
Task T038: "Configure ALB security group with ingress rule"
Task T039: "Configure ALB security group with egress rule"

# Note: T040-T041 depend on T037 completing (need ALB SG ID reference)
```

---

## Implementation Strategy

### MVP First (Essential User Stories Only)

**Minimum viable deployment** includes:
1. Complete Phase 1: Setup ✅
2. Complete Phase 2: Foundational ✅
3. Complete Phase 4: User Story 2 (TLS Certificate) ✅
4. Complete Phase 5: User Story 3 (ACM Import) ✅
5. Complete Phase 6: User Story 6 (Security Groups) ✅
6. Complete Phase 3: User Story 1 (EC2 Instances) ✅
7. Complete Phase 7: User Story 4 (ALB) ✅
8. Complete Phase 8: User Story 5 (Target Registration) ✅
9. **STOP and VALIDATE**: Run terraform apply and test

This delivers a fully functional, highly available web infrastructure with HTTPS.

### Incremental Delivery

1. **Foundation** (Phases 1-2): Terraform configuration and data sources → Ready for resource creation
2. **Core Infrastructure** (Phases 3-8): EC2 + TLS + Security + ALB → Test independently → **MVP Complete!**
3. **Security Enhancements** (Phase 9): S3 logging + encryption → Test independently → Production-ready
4. **Documentation** (Phase 11): Operational guides → Handoff ready

Each increment adds security and operational value without breaking previous work.

### Terraform Apply Strategy

**Option 1: Single Apply (Recommended for MVP)**
```bash
# All resources in one apply after all code is written
terraform plan -out=tfplan
terraform apply tfplan
```

**Option 2: Incremental Apply (for learning/debugging)**
```bash
# Apply in stages using -target flag
terraform apply -target=module.security_group_alb
terraform apply -target=module.ec2_instance
terraform apply -target=module.alb
terraform apply  # Apply remaining resources
```

**Option 3: Workspace Runs (HCP Terraform)**
```bash
# Create runs via HCP Terraform UI or API
# Review plan in UI before applying
# Automatic state locking and collaboration
```

---

## Validation Checklist

After completing all tasks, verify:

- [ ] ✅ **FR-001**: Exactly 2 t3.micro EC2 instances created
- [ ] ✅ **FR-002**: Instances in different AZs (ap-southeast-1a, ap-southeast-1b)
- [ ] ✅ **FR-003**: Default VPC and subnets used
- [ ] ✅ **FR-004, FR-005**: Nginx installed and serving HTTP on port 80
- [ ] ✅ **FR-006**: Self-signed TLS certificate for web.demo.com
- [ ] ✅ **FR-007**: Certificate imported to ACM
- [ ] ✅ **FR-008**: Internet-facing ALB across multiple AZs
- [ ] ✅ **FR-009**: HTTPS listener on port 443 with ACM certificate
- [ ] ✅ **FR-010**: TLS termination at ALB, HTTP to backends
- [ ] ✅ **FR-011, FR-012**: Target group with health checks
- [ ] ✅ **FR-013**: Static HTML test page deployed
- [ ] ✅ **FR-014**: ALB security group allows HTTPS from internet
- [ ] ✅ **FR-015**: EC2 security group allows HTTP from ALB only
- [ ] ✅ **FR-016**: Direct EC2 access blocked
- [ ] ✅ **FR-017, FR-018**: HCP Terraform state management
- [ ] ✅ **FR-022**: Resource tagging implemented
- [ ] ✅ **SC-001**: Deployment completes in <10 minutes
- [ ] ✅ **SC-002**: Response time <2 seconds
- [ ] ✅ **SC-003**: 100% availability with one instance down
- [ ] ✅ **SC-007**: Cost under $50/month

---

## Format Validation Summary

**Total Tasks**: 94 tasks across 11 phases

**Task Distribution by Phase**:
- Phase 1 (Setup): 8 tasks
- Phase 2 (Foundational): 6 tasks
- Phase 3 (US1 - EC2): 9 tasks
- Phase 4 (US2 - TLS): 8 tasks
- Phase 5 (US3 - ACM): 5 tasks
- Phase 6 (US6 - Security): 7 tasks
- Phase 7 (US4 - ALB): 8 tasks
- Phase 8 (US5 - Targets): 6 tasks
- Phase 9 (Security): 10 tasks
- Phase 10 (Testing): 17 tasks
- Phase 11 (Documentation): 10 tasks

**Parallelizable Tasks**: 24 tasks marked with [P]

**User Story Distribution**:
- [US1]: 9 tasks (EC2 instances)
- [US2]: 8 tasks (TLS certificate and Nginx)
- [US3]: 5 tasks (ACM import)
- [US4]: 8 tasks (ALB deployment)
- [US5]: 6 tasks (Health checks and target registration)
- [US6]: 7 tasks (Security groups)

**Independent Test Criteria**:
- US1: EC2 instances running in different AZs (AWS CLI validation)
- US2: TLS certificate generated with correct domain (Terraform state)
- US3: Certificate in ACM with valid ARN (AWS console)
- US6: Security group rules enforce least-privilege (AWS console + connection tests)
- US4: ALB HTTPS endpoint accessible (curl + openssl)
- US5: Health checks detect failures within 60s (failover test)

**Suggested MVP Scope**: 
All user stories US1-US6 are P1 priority and required for basic functionality. MVP = Phases 1-8 complete (tasks T001-T057).

**Format Compliance**: ✅ All tasks follow strict checklist format:
- ✅ Checkbox prefix `- [ ]`
- ✅ Sequential Task IDs (T001-T094)
- ✅ [P] marker for parallelizable tasks
- ✅ [Story] labels for user story phases
- ✅ Exact file paths in descriptions
- ✅ Clear acceptance criteria

---

## Notes

- All tasks follow Terraform dependency order (data sources → resources → attachments)
- Security groups created before instances and ALB
- TLS certificate generated before ACM import
- ACM certificate imported before ALB listener configuration
- Target group created before instance registration
- Each user story represents independently deployable infrastructure component
- Security enhancements (Phase 9) address findings from aws-security-review.md
- Testing strategy (Phase 10) maps to quickstart.md validation procedures
- All tasks reference exact file paths for LLM executability
- Tasks aligned with private module usage (ravi-panchal-org registry)
- Cost optimization maintained throughout ($38.67/month estimated)
