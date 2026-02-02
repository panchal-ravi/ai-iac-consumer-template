# Tasks: EC2 Instance with ALB and Nginx

**Input**: Design documents from `/specs/003-ec2-alb-nginx/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/
**Branch**: `003-ec2-alb-nginx`
**GitHub Issue**: #39

**Tests**: Tests are NOT requested in the feature specification. This is infrastructure validation via Terraform and AWS CLI commands.

**Organization**: Tasks are organized to enable incremental deployment and validation of infrastructure components, aligned with user stories from spec.md.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create Terraform project structure and configuration files

- [ ] T001 Create project directory structure (root, user-data/, docs/)
- [ ] T002 [P] Create versions.tf with Terraform version constraints (>= 1.6.0) and required providers (AWS ~> 6.0, TLS ~> 4.0)
- [ ] T003 [P] Create backend.tf with HCP Terraform Cloud configuration (organization: ravi-panchal-org, workspace: sandbox_workspace)
- [ ] T004 [P] Create providers.tf with AWS provider (region: ap-southeast-1) and TLS provider configuration
- [ ] T005 [P] Create variables.tf with 9 input variables (aws_region, project_name, environment, domain_name, instance_type, instance_count_per_az, certificate_validity_days, health_check_interval, health_check_path)
- [ ] T006 [P] Create outputs.tf stub file (outputs will be added incrementally)
- [ ] T007 [P] Create locals.tf with common_tags definition (Project, Environment, ManagedBy, Feature, GitHubIssue, Workspace, CostCenter, CreatedDate, Region)
- [ ] T008 [P] Create data.tf stub file (data sources will be added incrementally)
- [ ] T009 [P] Create main.tf stub file with file organization comments
- [ ] T010 [P] Create README.md with quick start instructions and link to quickstart.md
- [ ] T011 [P] Create .gitignore file for Terraform (.terraform/, *.tfstate, *.tfvars, .terraform.lock.hcl)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure discovery and certificate generation that ALL user stories depend on

**⚠️ CRITICAL**: No user story implementation can begin until this phase is complete

### Network Discovery (Required for ALL stories)

- [ ] T012 Add aws_vpc data source to data.tf (query default VPC in ap-southeast-1)
- [ ] T013 Add aws_subnets data source to data.tf (filter by vpc-id and default-for-az)
- [ ] T014 Add aws_subnet data source to data.tf (for_each over subnet IDs to get AZ details)
- [ ] T015 Add subnet selection logic to locals.tf (extract availability zones, select first 2 AZs, map AZ to subnet IDs)
- [ ] T016 Add network outputs to outputs.tf (vpc_id, subnet_ids, availability_zones)

### Certificate Generation (Required for User Story 1 - HTTPS access)

- [ ] T017 [P] Create tls_private_key resource in main.tf (algorithm: RSA, rsa_bits: 2048)
- [ ] T018 Create tls_self_signed_cert resource in main.tf (validity_period_hours from variable, subject CN: domain_name, dns_names: [domain_name], allowed_uses: key_encipherment, digital_signature, server_auth)
- [ ] T019 Create aws_acm_certificate resource in main.tf (import private key and certificate from TLS resources, lifecycle: create_before_destroy)
- [ ] T020 Add certificate outputs to outputs.tf (acm_certificate_arn, certificate_domain, certificate_validity_end)

**Checkpoint**: Foundation ready - VPC/subnets discovered, certificate generated, user story implementation can now begin

---

## Phase 3: User Story 2 - Infrastructure Provisioning via HCP Terraform (Priority: P1) 🎯 MVP

**Goal**: Deploy complete infrastructure stack using HCP Terraform with proper tagging and resource organization

**Independent Test**: Trigger terraform plan/apply in sandbox_workspace and verify all resources are created with consistent tags

**Why this is MVP**: This is the deployment mechanism - without it, no infrastructure exists. Completing this enables all other user stories.

### Security Groups (Foundation for EC2 and ALB)

- [ ] T021 [P] [US2] Add module.security_group_alb to main.tf (source: app.terraform.io/ravi-panchal-org/security-group/aws ~> 5.3.1, name: ${project_name}-${environment}-sg-alb, ingress: 443 from 0.0.0.0/0, egress: 80 to EC2 SG, tags)
- [ ] T022 [P] [US2] Add module.security_group_ec2 to main.tf (source: app.terraform.io/ravi-panchal-org/security-group/aws ~> 5.3.1, name: ${project_name}-${environment}-sg-ec2, ingress: 80 from ALB SG, egress: all, tags)
- [ ] T023 [US2] Add security group outputs to outputs.tf (alb_security_group_id, ec2_security_group_id)

### Nginx Bootstrap Script

- [ ] T024 [US2] Create user-data/nginx-bootstrap.sh with template variables (domain_name, environment)
- [ ] T025 [US2] Implement system update and Nginx installation section in nginx-bootstrap.sh (yum update, amazon-linux-extras install nginx1)
- [ ] T026 [US2] Implement instance metadata extraction in nginx-bootstrap.sh (INSTANCE_ID, AVAILABILITY_ZONE, PRIVATE_IP using ec2-metadata or IMDSv2)
- [ ] T027 [US2] Implement custom index.html generation in nginx-bootstrap.sh (write to /usr/share/nginx/html/index.html with instance metadata)
- [ ] T028 [US2] Implement Nginx configuration in nginx-bootstrap.sh (create /etc/nginx/conf.d/webapp.conf with / endpoint, /health endpoint, /nginx_status endpoint)
- [ ] T029 [US2] Implement service management in nginx-bootstrap.sh (systemctl start/enable nginx, disable firewalld)
- [ ] T030 [US2] Add error handling and logging to nginx-bootstrap.sh (set -e, exit codes, debug output)

### EC2 Instances

- [ ] T031 [US2] Add instance_configs local to locals.tf (for_each over selected_azs, generate instance names and subnet mappings)
- [ ] T032 [US2] Add nginx_user_data local to locals.tf (templatefile for user-data/nginx-bootstrap.sh)
- [ ] T033 [US2] Add module.ec2_instances to main.tf (source: app.terraform.io/ravi-panchal-org/ec2-instance/aws ~> 6.1.4, for_each over instance_configs, instance_type from variable, ami_ssm_parameter: /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64, user_data: nginx_user_data, vpc_security_group_ids: [ec2_sg_id], create_security_group: false, tags)
- [ ] T034 [US2] Add EC2 instance outputs to outputs.tf (ec2_instance_ids, ec2_instance_private_ips, ec2_instance_availability_zones)

### Application Load Balancer

- [ ] T035 [US2] Add module.alb to main.tf (source: app.terraform.io/ravi-panchal-org/alb/aws ~> 10.2.0, name: ${project_name}-${environment}-alb, load_balancer_type: application, internal: false, vpc_id, subnets: selected_subnet_ids, security_groups: [alb_sg_id], tags)
- [ ] T036 [US2] Add target_groups configuration to module.alb in main.tf (name: ${project_name}-${environment}-tg, backend_protocol: HTTP, backend_port: 80, target_type: instance, health_check with /health path and 30s interval, targets: EC2 instance IDs)
- [ ] T037 [US2] Add listeners configuration to module.alb in main.tf (port: 443, protocol: HTTPS, certificate_arn: acm_certificate_arn, default_action: forward to target group)
- [ ] T038 [US2] Add ALB outputs to outputs.tf (alb_id, alb_arn, alb_dns_name, alb_zone_id, target_group_arn, https_listener_arn)

### Connectivity Outputs

- [ ] T039 [US2] Add access_url output to outputs.tf (value: https://${domain_name})
- [ ] T040 [US2] Add alb_direct_url output to outputs.tf (value: https://${alb_dns_name})
- [ ] T041 [US2] Add deployment_timestamp output to outputs.tf (value: timestamp())
- [ ] T042 [US2] Add terraform_workspace output to outputs.tf (value: sandbox_workspace)

### Deployment and Validation

- [ ] T043 [US2] Run terraform init in project root (authenticate to HCP Terraform, download providers and modules)
- [ ] T044 [US2] Run terraform validate to verify configuration syntax
- [ ] T045 [US2] Run terraform fmt -recursive to format all .tf files
- [ ] T046 [US2] Run terraform plan and review resource creation (expect ~15-20 resources)
- [ ] T047 [US2] Run terraform apply to provision infrastructure (wait 5-8 minutes)
- [ ] T048 [US2] Verify all resources created with consistent tags in AWS Console (check Environment=development, Project=web-demo, ManagedBy=terraform)
- [ ] T049 [US2] Run terraform plan again to verify idempotency (should show no changes)

**Checkpoint**: At this point, complete infrastructure is deployed via HCP Terraform and User Story 2 is satisfied (infrastructure provisioning)

---

## Phase 4: User Story 1 - Access Web Content via HTTPS (Priority: P1)

**Goal**: Verify that web content is accessible through secure HTTPS endpoint with load balancing across instances

**Independent Test**: Navigate to https://web.demo.com (or ALB DNS) and verify Nginx welcome page loads, then make multiple requests to confirm load balancing

**Dependency**: Requires User Story 2 complete (infrastructure must be provisioned first)

### HTTPS Connectivity Validation

- [ ] T050 [US1] Retrieve ALB DNS name using terraform output -raw alb_dns_name
- [ ] T051 [US1] Test HTTPS connectivity to ALB using curl -k https://<alb_dns> (expect self-signed certificate warning and HTTP 200)
- [ ] T052 [US1] Verify response contains custom HTML with instance metadata (Instance ID, Availability Zone, Environment)
- [ ] T053 [US1] Open ALB URL in browser and manually accept certificate warning (verify Nginx welcome page displays)

### Load Balancing Verification

- [ ] T054 [US1] Execute load balancing test script (20 consecutive curl requests to ALB, extract Instance IDs from responses)
- [ ] T055 [US1] Verify traffic distribution shows approximately 10 requests per instance (both instances receiving traffic)
- [ ] T056 [US1] Document load balancing results in deployment log

### HTTP Rejection Test

- [ ] T057 [US1] Attempt HTTP connection to ALB on port 80 using curl http://<alb_dns> (should fail - connection refused or timeout)
- [ ] T058 [US1] Verify only HTTPS (port 443) is accessible per requirements

**Checkpoint**: At this point, User Story 1 is fully satisfied - web content accessible via HTTPS with load balancing confirmed

---

## Phase 5: User Story 3 - Verify Security Group Isolation (Priority: P2)

**Goal**: Confirm that EC2 instances only accept traffic from ALB and ALB only accepts HTTPS from internet

**Independent Test**: Attempt direct connections to EC2 instances (should fail) and HTTP to ALB (should fail), while HTTPS through ALB succeeds

**Dependency**: Requires User Story 2 complete (infrastructure must be provisioned)

### EC2 Isolation Tests

- [ ] T059 [US3] Retrieve EC2 instance private IPs using terraform output -json ec2_instance_private_ips
- [ ] T060 [US3] Attempt direct HTTP connection to first EC2 instance using curl --connect-timeout 5 http://<instance_ip> (should timeout - not accessible from internet)
- [ ] T061 [US3] Attempt direct HTTP connection to second EC2 instance (should timeout - not accessible from internet)
- [ ] T062 [US3] Document security isolation test results

### Security Group Rule Verification

- [ ] T063 [US3] Retrieve ALB security group ID and inspect rules in AWS Console or CLI
- [ ] T064 [US3] Verify ALB security group ingress allows only 443 from 0.0.0.0/0
- [ ] T065 [US3] Verify ALB security group egress allows only 80 to EC2 security group ID
- [ ] T066 [US3] Retrieve EC2 security group ID and inspect rules in AWS Console or CLI
- [ ] T067 [US3] Verify EC2 security group ingress allows only 80 from ALB security group ID (source_security_group_id reference)
- [ ] T068 [US3] Verify EC2 security group egress allows all outbound (for package installation)
- [ ] T069 [US3] Document security group configuration validation

### HTTPS-Only Enforcement

- [ ] T070 [US3] Re-test HTTP rejection on ALB to confirm HTTP (port 80) is blocked
- [ ] T071 [US3] Re-test HTTPS success on ALB to confirm only HTTPS (port 443) works

**Checkpoint**: At this point, User Story 3 is fully satisfied - security group isolation verified and documented

---

## Phase 6: User Story 4 - Monitor Instance Health and Availability (Priority: P3)

**Goal**: Verify ALB health checks correctly identify healthy instances and route traffic only to available instances

**Independent Test**: Stop Nginx on one instance and verify traffic continues flowing through healthy instance

**Dependency**: Requires User Story 1 and 2 complete (infrastructure and HTTPS access must work)

### Health Check Status Verification

- [ ] T072 [US4] Retrieve target group ARN using terraform output -raw target_group_arn
- [ ] T073 [US4] Check target health status using aws elbv2 describe-target-health --target-group-arn <arn> --region ap-southeast-1
- [ ] T074 [US4] Verify both EC2 instances show "healthy" state in target group
- [ ] T075 [US4] Document initial health check status (both targets healthy)

### Failure Scenario Simulation

- [ ] T076 [US4] Retrieve first EC2 instance ID using terraform output -json ec2_instance_ids | jq -r '.[0]'
- [ ] T077 [US4] Stop first EC2 instance using aws ec2 stop-instances --instance-ids <id> --region ap-southeast-1
- [ ] T078 [US4] Wait 70 seconds for health check to detect failure (2 consecutive failed checks at 30s interval)
- [ ] T079 [US4] Re-check target health status and verify first instance shows "unhealthy" or "draining"
- [ ] T080 [US4] Execute 10 consecutive curl requests to ALB and verify all responses come from healthy instance only
- [ ] T081 [US4] Document failover behavior (traffic routed only to healthy instance)

### Recovery Verification

- [ ] T082 [US4] Start first EC2 instance using aws ec2 start-instances --instance-ids <id> --region ap-southeast-1
- [ ] T083 [US4] Wait 120 seconds for instance to boot and pass health checks (2 consecutive successful checks)
- [ ] T084 [US4] Re-check target health status and verify first instance returns to "healthy" state
- [ ] T085 [US4] Execute 20 consecutive curl requests and verify traffic distributes across both instances again
- [ ] T086 [US4] Document recovery behavior (both instances serving traffic)

**Checkpoint**: At this point, User Story 4 is fully satisfied - health monitoring and failover behavior verified

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and final validation across all user stories

### Documentation

- [ ] T087 [P] Update README.md with final deployment results (ALB DNS, instance IDs, test results)
- [ ] T088 [P] Create deployment summary document in docs/deployment-summary.md (timestamps, resource IDs, costs, test outcomes)
- [ ] T089 [P] Update quickstart.md with any deployment-specific notes or deviations
- [ ] T090 [P] Create troubleshooting guide in docs/troubleshooting.md (common issues encountered and resolutions)

### Validation Tests

- [ ] T091 Run terraform validate again to ensure all changes are syntactically correct
- [ ] T092 Run terraform plan to confirm infrastructure matches desired state (no drift)
- [ ] T093 Execute full quickstart.md validation walkthrough from clean state
- [ ] T094 Verify all success criteria from spec.md are met (SC-001 through SC-010)

### Code Quality

- [ ] T095 [P] Run terraform fmt -check -recursive to verify formatting consistency
- [ ] T096 [P] Run tfsec . to check for security issues (optional - informational only)
- [ ] T097 [P] Run checkov -d . to check for compliance issues (optional - informational only)
- [ ] T098 Add inline comments to complex Terraform logic (locals.tf subnet selection, security group references)

### Cleanup and Cost Management

- [ ] T099 Document monthly cost estimate in README.md (~$40/month for development environment)
- [ ] T100 Test terraform destroy to verify clean teardown (run terraform destroy -auto-approve, verify all resources removed)
- [ ] T101 Re-deploy infrastructure to confirm repeatable deployment (terraform apply again after destroy)

**Final Checkpoint**: All user stories validated, documentation complete, infrastructure deployment repeatable

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 2 (Phase 3)**: Depends on Foundational phase - Infrastructure provisioning ENABLES other stories
- **User Story 1 (Phase 4)**: Depends on User Story 2 - Must have infrastructure to test HTTPS access
- **User Story 3 (Phase 5)**: Depends on User Story 2 - Must have infrastructure to test security groups
- **User Story 4 (Phase 6)**: Depends on User Story 1 and 2 - Requires working HTTPS and infrastructure
- **Polish (Phase 7)**: Depends on all user stories being complete

### Critical Path

```
Setup (Phase 1)
  ↓
Foundational (Phase 2) ← CRITICAL: Blocks all user stories
  ↓
User Story 2 (Phase 3) ← CRITICAL: Infrastructure provisioning
  ↓
User Story 1 (Phase 4) ← HTTPS access validation
  ├─→ User Story 3 (Phase 5) ← Security validation (can run in parallel with US4)
  └─→ User Story 4 (Phase 6) ← Health check validation (can run in parallel with US3)
  ↓
Polish (Phase 7)
```

### User Story Dependencies

- **User Story 1 (P1 - HTTPS Access)**: Can start after US2 complete - No dependencies on US3/US4
- **User Story 2 (P1 - Infrastructure Provisioning)**: Can start after Foundational - REQUIRED for all other stories
- **User Story 3 (P2 - Security Verification)**: Can start after US2 complete - Can run in parallel with US4
- **User Story 4 (P3 - Health Monitoring)**: Can start after US1 and US2 complete - Can run in parallel with US3

### Within Each Phase

**Setup (Phase 1)**:
- All tasks T002-T011 can run in parallel (marked with [P])
- T001 must complete first (creates directory structure)

**Foundational (Phase 2)**:
- Network discovery tasks (T012-T016) must complete sequentially
- Certificate tasks (T017-T020) can start after T017, T018-T019-T020 are sequential
- Certificate generation can run in parallel with network discovery

**User Story 2 (Phase 3)**:
- T021-T022 (security groups) can run in parallel
- T024-T030 (nginx bootstrap) can run in parallel with security groups
- T031-T034 (EC2 instances) depend on security groups and bootstrap script
- T035-T038 (ALB) depend on security groups and certificate
- T043-T049 (deployment) must run sequentially

**User Story 1 (Phase 4)**:
- All validation tasks must run sequentially (T050-T058)

**User Story 3 (Phase 5)**:
- All validation tasks must run sequentially (T059-T071)

**User Story 4 (Phase 6)**:
- All validation tasks must run sequentially (T072-T086)

**Polish (Phase 7)**:
- Documentation tasks (T087-T090) can run in parallel
- Validation tasks (T091-T094) must run sequentially
- Code quality tasks (T095-T098) can run in parallel

### Parallel Opportunities

- **Setup Phase**: 10 tasks can run in parallel (T002-T011)
- **Foundational Phase**: Network and certificate generation can run in parallel
- **User Story 2 Implementation**: Security groups, bootstrap script development can run in parallel
- **User Story 3 and 4 Testing**: These validation phases can run in parallel (different aspects of the infrastructure)
- **Polish Phase**: Documentation and code quality tasks can run in parallel

---

## Parallel Example: Setup Phase

```bash
# All these Terraform files can be created simultaneously:
Task T002: "Create versions.tf"
Task T003: "Create backend.tf"
Task T004: "Create providers.tf"
Task T005: "Create variables.tf"
Task T006: "Create outputs.tf stub"
Task T007: "Create locals.tf"
Task T008: "Create data.tf stub"
Task T009: "Create main.tf stub"
Task T010: "Create README.md"
Task T011: "Create .gitignore"
```

---

## Parallel Example: User Story 2 - Security Groups

```bash
# These module blocks can be added to main.tf in parallel:
Task T021: "Add module.security_group_alb to main.tf"
Task T022: "Add module.security_group_ec2 to main.tf"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup (T001-T011)
2. Complete Phase 2: Foundational (T012-T020) - CRITICAL
3. Complete Phase 3: User Story 2 - Infrastructure Provisioning (T021-T049)
4. Complete Phase 4: User Story 1 - HTTPS Access Validation (T050-T058)
5. **STOP and VALIDATE**: Infrastructure deployed, HTTPS access confirmed
6. **Deploy/Demo Ready**: This is the MVP - working infrastructure with HTTPS

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 2 → Infrastructure deployed via Terraform → Validate (MVP Core)
3. Add User Story 1 → HTTPS access validated → Validate (MVP Complete!)
4. Add User Story 3 → Security isolation validated → Deploy/Demo
5. Add User Story 4 → Health monitoring validated → Deploy/Demo
6. Add Polish → Documentation complete → Production-ready

### Sequential Execution (Single Developer)

1. Work through Phase 1 (Setup) - 1-2 hours
2. Work through Phase 2 (Foundational) - 1-2 hours
3. Work through Phase 3 (User Story 2) - 3-4 hours
4. Deploy and validate infrastructure
5. Work through Phase 4 (User Story 1) - 30 minutes
6. Work through Phase 5 (User Story 3) - 30 minutes
7. Work through Phase 6 (User Story 4) - 1 hour
8. Work through Phase 7 (Polish) - 1-2 hours

**Total Estimated Time**: 8-12 hours

---

## Task Complexity Estimates

### Setup Phase (T001-T011)
- **Complexity**: Low (file creation, configuration templates)
- **Time**: 1-2 hours total
- **Skills**: Basic Terraform knowledge, file organization

### Foundational Phase (T012-T020)
- **Complexity**: Medium (data sources, certificate generation, local values)
- **Time**: 1-2 hours total
- **Skills**: Terraform data sources, TLS provider, locals

### User Story 2 - Infrastructure Provisioning (T021-T049)
- **Complexity**: High (module composition, networking, security groups, ALB configuration)
- **Time**: 3-4 hours implementation + 5-8 minutes deployment + 30 minutes validation
- **Skills**: Advanced Terraform, AWS networking, HCP Terraform, module composition

### User Story 1 - HTTPS Access (T050-T058)
- **Complexity**: Low (validation only)
- **Time**: 20-30 minutes
- **Skills**: curl, basic HTTP/HTTPS testing

### User Story 3 - Security Verification (T059-T071)
- **Complexity**: Low (validation only)
- **Time**: 20-30 minutes
- **Skills**: AWS CLI, security group concepts, network testing

### User Story 4 - Health Monitoring (T072-T086)
- **Complexity**: Medium (requires instance manipulation and timing)
- **Time**: 45-60 minutes
- **Skills**: AWS CLI, ALB health checks, patience for timing windows

### Polish Phase (T087-T101)
- **Complexity**: Low to Medium (documentation, validation, cleanup)
- **Time**: 1-2 hours
- **Skills**: Technical writing, Terraform validation, cost analysis

---

## Acceptance Criteria Summary

### User Story 1 - Access Web Content via HTTPS
- ✅ HTTPS connection to ALB successful with self-signed certificate warning
- ✅ Nginx welcome page displays with instance metadata
- ✅ Load balancing confirmed across both instances
- ✅ HTTP connections to ALB rejected

### User Story 2 - Infrastructure Provisioning via HCP Terraform
- ✅ Terraform plan/apply succeeds in HCP Terraform workspace
- ✅ All resources created with consistent tags
- ✅ Infrastructure is idempotent (no changes on re-apply)
- ✅ Terraform destroy cleanly removes all resources

### User Story 3 - Verify Security Group Isolation
- ✅ Direct connections to EC2 instances fail (timeout)
- ✅ HTTP connections to ALB fail (only HTTPS allowed)
- ✅ Security group rules verified (ALB SG → EC2 SG references correct)
- ✅ EC2 instances only accept traffic from ALB

### User Story 4 - Monitor Instance Health and Availability
- ✅ Both instances show healthy in target group
- ✅ Traffic stops flowing to unhealthy instance within 60 seconds
- ✅ Healthy instance continues serving 100% of traffic during failover
- ✅ Failed instance returns to service after restart

---

## Success Criteria Validation (from spec.md)

| ID | Criteria | Validation Task | Pass/Fail |
|----|----------|-----------------|-----------|
| SC-001 | Infrastructure provisioning < 10 minutes | T047 (terraform apply timing) | ⏭️ |
| SC-002 | HTTPS response < 500ms | T051 (curl timing) | ⏭️ |
| SC-003 | Health checks pass < 2 minutes | T074 (target health check) | ⏭️ |
| SC-004 | Load balancing distribution | T055 (20 requests test) | ⏭️ |
| SC-005 | Direct EC2 access fails | T060, T061 (connection timeout) | ⏭️ |
| SC-006 | HTTP to ALB refused | T057 (connection refused) | ⏭️ |
| SC-007 | Infrastructure idempotency | T049 (terraform plan no changes) | ⏭️ |
| SC-008 | Consistent tagging | T048 (AWS Console inspection) | ⏭️ |
| SC-009 | Clean destruction < 5 minutes | T100 (terraform destroy timing) | ⏭️ |
| SC-010 | Single instance failure handling | T080 (traffic during failover) | ⏭️ |

---

## Notes

- **Infrastructure as Code**: All tasks involve Terraform configuration and AWS resource management
- **No Application Tests**: This is infrastructure deployment - validation is via Terraform outputs and AWS CLI commands
- **Self-Signed Certificates**: Certificate warnings are expected and documented throughout
- **Cost Awareness**: Estimated $40/month for development environment - can be destroyed when not in use
- **Module Dependencies**: Tasks reference exact module versions from private registry (ravi-panchal-org)
- **Timing Windows**: Health check tests require patience (60-120 seconds for state changes)
- **Prerequisites**: Requires HCP Terraform access, AWS credentials, and terraform CLI 1.6+
- **Validation Focus**: Each user story has explicit validation tasks to confirm requirements met
- **Incremental Delivery**: MVP is User Stories 1+2 complete (infrastructure + HTTPS access)

---

**Tasks Status**: Ready for implementation  
**Total Task Count**: 101 tasks  
**Estimated Implementation Time**: 8-12 hours  
**MVP Task Count**: 58 tasks (T001-T058, Phases 1-4)  
**MVP Estimated Time**: 5-7 hours
