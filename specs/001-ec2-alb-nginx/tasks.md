# Tasks: EC2 ALB Nginx Development Environment

**Feature Branch**: `001-ec2-alb-nginx`  
**Input**: Design documents from `/workspace/specs/001-ec2-alb-nginx/`  
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, quickstart.md  
**Generated**: 2025-01-29

**Tests**: Not explicitly requested in specification - focusing on infrastructure deployment and manual validation tests

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each infrastructure component.

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, certificate generation, and repository structure

**Critical**: This phase establishes the foundation for all infrastructure deployment

- [ ] T001 Generate self-signed SSL certificate using OpenSSL and import to ACM in ap-southeast-1 region
- [ ] T002 Verify AWS prerequisites: default VPC exists in ap-southeast-1 with subnets in ap-southeast-1a and ap-southeast-1b
- [ ] T003 [P] Search private registry for ALB module (app.terraform.io/ravi-panchal-org/alb/aws) and validate version 10.2.0 compatibility
- [ ] T004 [P] Search private registry for EC2 module (app.terraform.io/ravi-panchal-org/ec2-instance/aws) and validate version 6.1.4 compatibility
- [ ] T005 Create Terraform project structure: main.tf, variables.tf, outputs.tf, locals.tf, providers.tf, versions.tf, override.tf at repository root
- [ ] T006 Configure HCP Terraform backend in override.tf with organization ravi-panchal-org and appropriate workspace

**Checkpoint**: Prerequisites validated, certificates ready, project structure created

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Terraform configuration that MUST be complete before infrastructure deployment

**⚠️ CRITICAL**: No infrastructure can be deployed until this phase is complete

- [ ] T007 Configure AWS provider in providers.tf with region ap-southeast-1 and required version >= 6.0
- [ ] T008 Define Terraform and provider version constraints in versions.tf (terraform >= 1.5.7, aws >= 6.0)
- [ ] T009 [P] Create data source for default VPC lookup in main.tf
- [ ] T010 [P] Create data source for default subnets in ap-southeast-1a and ap-southeast-1b in main.tf
- [ ] T011 [P] Define common_tags local in locals.tf (Environment, Project, ManagedBy, Terraform, CostCenter, Purpose)
- [ ] T012 [P] Create user_data_script local in locals.tf using contracts/user-data.sh content
- [ ] T013 [P] Define input variables in variables.tf: environment, region, instance_type, acm_certificate_arn, common_tags
- [ ] T014 [P] Create outputs in outputs.tf: alb_dns_name, alb_arn, target_group_arn, instance_ids (map), security_group_ids
- [ ] T015 Create sandbox.auto.tfvars with development environment values (env=dev, instance_type=t3.micro, region=ap-southeast-1)
- [ ] T016 Initialize Terraform and validate configuration syntax (terraform init && terraform validate)

**Checkpoint**: Foundation ready - infrastructure modules can now be configured

---

## Phase 3: User Story 1 - Access Application via HTTPS (Priority: P1) 🎯 MVP

**Goal**: Deploy a working HTTPS endpoint with load balancing across multiple AZs, serving static content from EC2 instances running Nginx. This is the core functionality that delivers immediate value for development testing.

**Independent Test**: Navigate to the ALB DNS name via HTTPS in a browser, accept the certificate warning (self-signed), and verify that a static HTML page loads with instance and availability zone information. HTTP requests should automatically redirect to HTTPS.

### Implementation for User Story 1

- [ ] T017 [P] [US1] Configure ALB module in main.tf with name, vpc_id, subnets, and internal=false
- [ ] T018 [P] [US1] Configure ALB security group ingress rules in main.tf: allow ports 80 and 443 from 0.0.0.0/0
- [ ] T019 [P] [US1] Configure ALB HTTP listener in main.tf with port 80 redirect to HTTPS (status_code HTTP_301)
- [ ] T020 [P] [US1] Configure ALB HTTPS listener in main.tf with port 443, certificate_arn variable, forward to target group
- [ ] T021 [P] [US1] Configure target group in ALB module in main.tf with name, port 80, protocol HTTP, vpc_id
- [ ] T022 [US1] Configure target group health check in main.tf: path="/", interval=30, timeout=5, healthy_threshold=2, unhealthy_threshold=2, matcher="200"
- [ ] T023 [P] [US1] Configure EC2 instance module for ap-southeast-1a in main.tf using for_each pattern
- [ ] T024 [P] [US1] Configure EC2 instance module for ap-southeast-1b in main.tf using for_each pattern
- [ ] T025 [US1] Configure EC2 instance properties in main.tf: ami_ssm_parameter, instance_type, subnet_id, availability_zone, user_data, key_name=null
- [ ] T026 [US1] Configure EC2 IAM role in main.tf: create_iam_instance_profile=true, iam_role_policies with AmazonSSMManagedInstanceCore
- [ ] T027 [US1] Configure EC2 security group in main.tf: create_security_group=true, allow port 80 from ALB security group only
- [ ] T028 [US1] Create target group attachment resources in main.tf for both EC2 instances to ALB target group
- [ ] T029 [US1] Run terraform plan and verify all resources: 2 EC2 instances, 1 ALB, 2 security groups, 2 IAM roles, 1 target group, 2 listeners, 2 attachments
- [ ] T030 [US1] Apply Terraform configuration (requires user approval before terraform apply)
- [ ] T031 [US1] Verify ALB DNS name resolves and returns valid response (may take 2-3 minutes for resources to stabilize)
- [ ] T032 [US1] Test HTTPS connectivity: curl -k https://<ALB_DNS>/ should return HTML with instance information
- [ ] T033 [US1] Test HTTP redirect: curl -I http://<ALB_DNS>/ should return 301 with Location header pointing to HTTPS
- [ ] T034 [US1] Test multi-AZ distribution: make 10 requests and verify responses from both ap-southeast-1a and ap-southeast-1b
- [ ] T035 [US1] Verify browser access with certificate warning acceptance and confirm page loads correctly

**Checkpoint**: User Story 1 complete - HTTPS endpoint is fully functional, load balancing across AZs, serving dynamic content

---

## Phase 4: User Story 2 - Instance Health Monitoring (Priority: P2)

**Goal**: Configure and validate automated health monitoring so the ALB automatically detects unhealthy instances and stops routing traffic to them, ensuring application reliability and demonstrating proper production patterns.

**Independent Test**: Stop Nginx on one EC2 instance using Systems Manager Session Manager, wait 60 seconds, verify that the ALB marks it unhealthy and routes all traffic to the healthy instance. Restart Nginx and verify the instance returns to healthy status.

### Implementation for User Story 2

- [ ] T036 [US2] Document health check configuration in quickstart.md: endpoint path, interval, thresholds, expected behavior
- [ ] T037 [US2] Verify target health using AWS CLI: aws elbv2 describe-target-health --target-group-arn <arn> --region ap-southeast-1
- [ ] T038 [US2] Confirm both instances show "healthy" status in target group (may take up to 90 seconds after deployment)
- [ ] T039 [US2] Test failure detection: connect to instance via Session Manager and stop Nginx (sudo systemctl stop nginx)
- [ ] T040 [US2] Wait 60 seconds and verify instance is marked "unhealthy" in target group health checks
- [ ] T041 [US2] Verify traffic routing: make multiple requests to ALB and confirm all go to healthy instance only
- [ ] T042 [US2] Test recovery: restart Nginx on failed instance (sudo systemctl start nginx)
- [ ] T043 [US2] Wait 60 seconds and verify instance returns to "healthy" status
- [ ] T044 [US2] Verify load balancing resumes: make multiple requests and confirm traffic distributes across both instances
- [ ] T045 [US2] Document CloudWatch metrics for monitoring: HealthyHostCount, UnHealthyHostCount, TargetResponseTime
- [ ] T046 [US2] Update quickstart.md with health check testing procedures and expected outcomes

**Checkpoint**: User Story 2 complete - Health monitoring is fully functional with automatic failover and recovery

---

## Phase 5: User Story 3 - Secure Instance Access (Priority: P3)

**Goal**: Enable secure access to EC2 instances for troubleshooting using AWS Systems Manager Session Manager without SSH keys, maintaining security best practices while providing operational debugging capabilities.

**Independent Test**: Use AWS Systems Manager Session Manager to connect to an EC2 instance without SSH keys, execute commands to view Nginx logs and status, then disconnect. Verify that traditional SSH access is not possible.

### Implementation for User Story 3

- [ ] T047 [US3] Verify IAM role attachment to EC2 instances includes AmazonSSMManagedInstanceCore policy
- [ ] T048 [US3] Wait 2-3 minutes after instance launch for SSM agent to register with Systems Manager
- [ ] T049 [US3] Test Session Manager connection: aws ssm start-session --target <instance-id-az-a> --region ap-southeast-1
- [ ] T050 [US3] Verify session establishes successfully and execute test commands: whoami, systemctl status nginx, curl localhost
- [ ] T051 [US3] Test Session Manager connection to second instance: aws ssm start-session --target <instance-id-az-b> --region ap-southeast-1
- [ ] T052 [US3] Verify no SSH key pairs are configured: aws ec2 describe-instances --instance-ids <id> --query 'Reservations[0].Instances[0].KeyName'
- [ ] T053 [US3] Verify no SSH security group rules exist: aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*ec2-sg*" --query 'SecurityGroups[].IpPermissions[?FromPort==`22`]'
- [ ] T054 [US3] Document Session Manager access procedures in quickstart.md with troubleshooting commands
- [ ] T055 [US3] Create troubleshooting section in quickstart.md: viewing logs, checking Nginx status, testing endpoints locally
- [ ] T056 [US3] Verify VPC endpoints for Systems Manager are available (or instances have internet connectivity for SSM)

**Checkpoint**: User Story 3 complete - Secure instance access is fully functional without SSH keys

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, security hardening, and cost optimization across all user stories

- [ ] T057 [P] Complete quickstart.md with all deployment steps, validation tests, and troubleshooting guide
- [ ] T058 [P] Add cost monitoring section to quickstart.md: monthly estimates, cost breakdown, shutdown procedures
- [ ] T059 [P] Document cleanup procedures in quickstart.md: terraform destroy, ACM certificate deletion, verification
- [ ] T060 [P] Verify all resources are tagged correctly: Environment, Project, ManagedBy, Terraform, CostCenter, Purpose
- [ ] T061 [P] Run terraform fmt to ensure consistent code formatting
- [ ] T062 [P] Validate specification compliance: review all FR-001 through FR-024 functional requirements
- [ ] T063 [P] Validate success criteria: verify SC-001 through SC-010 measurable outcomes
- [ ] T064 [P] Update README.md at repository root with project overview, architecture diagram, and quickstart link
- [ ] T065 Run complete quickstart.md validation from end to end: certificate creation through cleanup
- [ ] T066 Verify monthly cost estimate is under $100 USD using AWS Cost Explorer or Pricing Calculator
- [ ] T067 Document edge cases and limitations in quickstart.md: certificate expiration, simultaneous AZ failures, cost controls
- [ ] T068 Create architecture diagram in specs/001-ec2-alb-nginx/ showing VPC, ALB, EC2 instances, security groups, and traffic flow
- [ ] T069 Final security validation: verify no CRITICAL findings, confirm least-privilege IAM, validate security group rules

**Checkpoint**: All documentation complete, code formatted, specification validated

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
  - Requires: OpenSSL, AWS CLI, AWS credentials with appropriate permissions
  - Blocks: All subsequent phases (need certificates and project structure)

- **Foundational (Phase 2)**: Depends on Setup (Phase 1) completion
  - Requires: Certificates imported to ACM, project structure created
  - Blocks: All infrastructure deployment phases
  - CRITICAL: Must complete before ANY infrastructure resources can be created

- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion
  - Requires: Terraform initialized, variables defined, certificate ARN available
  - Blocks: User Story 2 and User Story 3 (need working infrastructure)
  - MVP DELIVERY: This phase delivers a working HTTPS endpoint

- **User Story 2 (Phase 4)**: Depends on User Story 1 (Phase 3) completion
  - Requires: ALB deployed, EC2 instances running, health checks configured
  - Can run independently: Does not block User Story 3
  - Validates: Health monitoring and automatic failover

- **User Story 3 (Phase 5)**: Depends on User Story 1 (Phase 3) completion
  - Requires: EC2 instances deployed with IAM roles
  - Can run in parallel with User Story 2 if staffed
  - Validates: Secure access without SSH keys

- **Polish (Phase 6)**: Depends on all user stories being complete
  - Requires: All infrastructure deployed and tested
  - No blockers: Documentation and validation tasks

### User Story Dependencies

```
Setup (Phase 1)
    │
    └─→ Foundational (Phase 2) [BLOCKS ALL STORIES]
            │
            ├─→ User Story 1 (Phase 3) - HTTPS Access [MVP] ⭐
            │       │
            │       ├─→ User Story 2 (Phase 4) - Health Monitoring
            │       │
            │       └─→ User Story 3 (Phase 5) - Secure Access
            │
            └─→ Polish (Phase 6) - Documentation & Validation
```

### Within Each Phase

**Phase 1 - Setup**:
- T001 must complete before any Terraform work (need certificate ARN)
- T002 must complete to validate prerequisites
- T003, T004 can run in parallel (different module searches)
- T005, T006 sequential (project structure)

**Phase 2 - Foundational**:
- T007, T008 can run in parallel (different files)
- T009, T010, T011, T012, T013, T014 can run in parallel (independent configurations)
- T015 depends on all variable definitions
- T016 must be last (validates all previous work)

**Phase 3 - User Story 1**:
- ALB configuration (T017-T022) can run in parallel - different module sections
- EC2 configuration (T023-T027) can run in parallel - different module sections
- T028 depends on both ALB and EC2 modules being configured
- T029-T035 must be sequential (deployment and validation flow)

**Phase 4 - User Story 2**:
- All tasks are sequential (testing workflow)
- T036-T046 follow logical testing progression

**Phase 5 - User Story 3**:
- T047-T056 mostly sequential (testing workflow)
- Can run in parallel with Phase 4 if multiple team members

**Phase 6 - Polish**:
- T057-T064 can run in parallel (different documentation files)
- T065-T069 should be sequential (validation flow)

### Parallel Opportunities

**Within Setup (Phase 1)**:
```bash
# Can run in parallel:
T003: Search private registry for ALB module
T004: Search private registry for EC2 module
```

**Within Foundational (Phase 2)**:
```bash
# Can run in parallel:
T007: Configure AWS provider in providers.tf
T008: Define version constraints in versions.tf
T009: Create VPC data source in main.tf
T010: Create subnet data source in main.tf
T011: Define common_tags in locals.tf
T012: Create user_data_script in locals.tf
T013: Define variables in variables.tf
T014: Create outputs in outputs.tf
```

**Within User Story 1 (Phase 3)**:
```bash
# ALB configuration - can run in parallel:
T017: Configure ALB module basic settings
T018: Configure ALB security group rules
T019: Configure HTTP listener with redirect
T020: Configure HTTPS listener
T021: Configure target group
T022: Configure health check

# EC2 configuration - can run in parallel:
T023: Configure EC2 instance for az-a
T024: Configure EC2 instance for az-b
```

**Across User Stories** (if multiple developers):
```bash
# After Phase 3 (User Story 1) is deployed:
Developer A: Phase 4 - User Story 2 (Health Monitoring tests)
Developer B: Phase 5 - User Story 3 (Session Manager tests)
# Both can proceed in parallel
```

**Within Polish (Phase 6)**:
```bash
# Can run in parallel:
T057: Complete quickstart.md
T058: Add cost monitoring section
T059: Document cleanup procedures
T060: Verify resource tagging
T061: Run terraform fmt
T062: Validate specification compliance
T063: Validate success criteria
T064: Update README.md
```

---

## Implementation Strategy

### MVP First (User Story 1 Only) - RECOMMENDED

**Goal**: Deliver working HTTPS endpoint as quickly as possible

1. ✅ Complete Phase 1: Setup (~15-20 minutes)
   - Generate certificates
   - Validate prerequisites
   - Create project structure

2. ✅ Complete Phase 2: Foundational (~30-45 minutes)
   - Configure all Terraform files
   - Initialize and validate
   - **CRITICAL CHECKPOINT**: Terraform validate must pass

3. ✅ Complete Phase 3: User Story 1 (~45-60 minutes)
   - Configure ALB and EC2 modules
   - Deploy infrastructure (terraform apply)
   - Validate HTTPS endpoint works
   - **MVP DELIVERY CHECKPOINT**: Working HTTPS application

4. **STOP and VALIDATE**:
   - Test independently: Access ALB via HTTPS
   - Verify HTTP redirect works
   - Confirm multi-AZ distribution
   - Demo to stakeholders if ready

5. Decision point: Deploy now or continue with User Stories 2 & 3

**Total MVP Time**: ~90-125 minutes (1.5-2 hours)

### Incremental Delivery (Recommended for Full Feature)

**Goal**: Add user stories incrementally, validating each one independently

1. ✅ Complete Setup + Foundational → Foundation ready (~45-65 minutes)

2. ✅ Add User Story 1 → Test independently → MVP Deployed! (~45-60 minutes)
   - **Deliverable**: HTTPS endpoint serving content across multiple AZs

3. ✅ Add User Story 2 → Test independently → Enhanced! (~30-45 minutes)
   - **Deliverable**: Automated health monitoring with failover

4. ✅ Add User Story 3 → Test independently → Complete! (~30-45 minutes)
   - **Deliverable**: Secure access without SSH keys

5. ✅ Complete Polish → Production Ready (~30-45 minutes)
   - **Deliverable**: Full documentation and validation

**Total Time**: ~3-4 hours for complete feature

### Parallel Team Strategy

**Goal**: Maximize throughput with multiple developers

**Team of 3 Developers**:

1. **All Together**: Complete Setup + Foundational (~45-65 minutes)
   - Joint effort to establish foundation
   - **CHECKPOINT**: Terraform validate passes

2. **Developer A (Infrastructure Lead)**: Phase 3 - User Story 1 (~45-60 minutes)
   - Deploy ALB and EC2 infrastructure
   - Validate HTTPS endpoint
   - **CHECKPOINT**: Infrastructure deployed and accessible

3. **Once User Story 1 is deployed**:
   - **Developer B**: Phase 4 - User Story 2 Health Monitoring (~30-45 minutes)
   - **Developer C**: Phase 5 - User Story 3 Secure Access (~30-45 minutes)
   - Both proceed in parallel (independent testing)

4. **All Together**: Phase 6 - Polish (~30-45 minutes)
   - Combine documentation
   - Run final validation
   - **CHECKPOINT**: All documentation complete

**Total Time with 3 Developers**: ~2.5-3 hours

**Team of 2 Developers**:

1. **Both**: Setup + Foundational (~45-65 minutes)
2. **Developer A**: User Story 1 (~45-60 minutes)
3. **After US1 deployed**:
   - **Developer A**: User Story 2 (~30-45 minutes)
   - **Developer B**: User Story 3 (~30-45 minutes) - in parallel
4. **Both**: Polish (~30-45 minutes)

**Total Time with 2 Developers**: ~2.5-3.5 hours

---

## Validation Checklist

Use this checklist to confirm successful implementation at each checkpoint:

### Phase 1 - Setup Complete ✓
- [ ] Self-signed certificate generated with OpenSSL
- [ ] Certificate imported to ACM in ap-southeast-1 region
- [ ] Certificate ARN captured and saved
- [ ] Default VPC exists in ap-southeast-1
- [ ] Subnets exist in ap-southeast-1a and ap-southeast-1b
- [ ] Private registry modules located and version validated
- [ ] Project structure created (6 core .tf files)
- [ ] HCP Terraform backend configured

### Phase 2 - Foundational Complete ✓
- [ ] AWS provider configured with correct region
- [ ] Version constraints defined (Terraform >= 1.5.7, AWS >= 6.0)
- [ ] VPC and subnet data sources created
- [ ] Common tags local defined with all 6 required tags
- [ ] User data script local created from contracts/user-data.sh
- [ ] All input variables defined with descriptions
- [ ] All outputs defined (ALB DNS, ARNs, instance IDs)
- [ ] sandbox.auto.tfvars created with dev environment values
- [ ] `terraform init` succeeds
- [ ] `terraform validate` succeeds with no errors

### Phase 3 - User Story 1 Complete ✓ (MVP)
- [ ] ALB module configured with all listeners and target group
- [ ] HTTP listener redirects to HTTPS (301 status)
- [ ] HTTPS listener uses ACM certificate
- [ ] Target group health check configured (30s interval)
- [ ] EC2 modules configured for both AZs
- [ ] IAM roles include AmazonSSMManagedInstanceCore
- [ ] Security groups restrict EC2 to ALB traffic only
- [ ] Target group attachments created for both instances
- [ ] `terraform plan` shows expected resources (~15-20 resources)
- [ ] `terraform apply` succeeds
- [ ] ALB DNS name resolves
- [ ] HTTPS endpoint loads in browser (after certificate warning)
- [ ] HTTP requests redirect to HTTPS
- [ ] Page shows instance ID and availability zone
- [ ] Multiple requests show both AZs (ap-southeast-1a and 1b)

### Phase 4 - User Story 2 Complete ✓
- [ ] Both instances show "healthy" status
- [ ] Health check endpoint (/) returns 200 OK
- [ ] Stopping Nginx marks instance "unhealthy" after 60s
- [ ] Traffic routes only to healthy instance during failure
- [ ] Restarting Nginx returns instance to "healthy" after 60s
- [ ] Load balancing resumes across both instances
- [ ] CloudWatch metrics documented in quickstart.md
- [ ] Health check testing procedures documented

### Phase 5 - User Story 3 Complete ✓
- [ ] IAM role with SSM policy attached to instances
- [ ] SSM agent registered with Systems Manager
- [ ] Session Manager connection succeeds to instance in az-a
- [ ] Session Manager connection succeeds to instance in az-b
- [ ] Commands execute successfully in Session Manager session
- [ ] No SSH key pairs configured on instances
- [ ] No SSH security group rules exist (port 22)
- [ ] Troubleshooting procedures documented in quickstart.md

### Phase 6 - Polish Complete ✓
- [ ] quickstart.md complete with all deployment steps
- [ ] Cost monitoring section added with monthly estimates
- [ ] Cleanup procedures documented (destroy + certificate deletion)
- [ ] All resources have correct tags (6 required tags)
- [ ] Code formatted with `terraform fmt`
- [ ] All functional requirements (FR-001 to FR-024) validated
- [ ] All success criteria (SC-001 to SC-010) verified
- [ ] README.md updated with project overview
- [ ] Complete quickstart validation run successful
- [ ] Monthly cost confirmed under $100 USD
- [ ] Edge cases and limitations documented
- [ ] Architecture diagram created
- [ ] Security validation complete (no CRITICAL findings)

---

## Cost Tracking

**Target**: Monthly costs < $100 USD

**Estimated Monthly Costs** (24/7 operation in ap-southeast-1):

| Component | Specification | Monthly Cost |
|-----------|--------------|--------------|
| EC2 Instances | 2x t3.micro, on-demand | ~$15.12 |
| Application Load Balancer | Base hourly charge | ~$18.14 |
| ALB LCU | Minimal usage (dev environment) | ~$5-10 |
| Data Transfer | Outbound internet (minimal testing) | ~$2-5 |
| ACM Certificate | Self-signed import | $0.00 |
| CloudWatch Metrics | Basic monitoring (free tier) | $0.00 |
| Systems Manager | Session Manager | $0.00 |
| **Total Estimated** | | **~$40-48/month** ✅ |

**Cost Optimization Notes**:
- Well below $100 target (50% under budget)
- Stop instances when not in use to reduce EC2 costs by ~70%
- ALB charges continue even when instances stopped
- Destroy infrastructure after testing to eliminate all charges
- No NAT Gateway = ~$32/month saved
- No CloudWatch Logs = ~$5-10/month saved

**Cost Monitoring**:
- Use AWS Cost Explorer after deployment
- Set up billing alerts for unexpected charges
- Document shutdown procedures in quickstart.md
- Implement tagging for cost allocation (CostCenter: development)

---

## Risk Mitigation

### Technical Risks

**Risk**: Default VPC may not exist or missing required subnets
- **Mitigation**: T002 validates prerequisites before any deployment
- **Fallback**: Error message directs user to create default VPC

**Risk**: User data script fails, instances without Nginx
- **Mitigation**: User data script includes error handling and logging
- **Validation**: Health checks detect installation failures
- **Debug**: Session Manager access allows log inspection

**Risk**: Self-signed certificate browser warnings
- **Mitigation**: Documented in quickstart.md with acceptance procedures
- **Alternative**: Can use ACM with custom domain if available

### Cost Risks

**Risk**: Resources left running exceed budget
- **Mitigation**: Tagging strategy for cost tracking
- **Mitigation**: Documented shutdown and destroy procedures
- **Alert**: CloudWatch billing alerts recommended

**Risk**: Data transfer costs exceed estimates
- **Mitigation**: Development environment (minimal traffic expected)
- **Mitigation**: Destroy resources after validation

### Security Risks

**Risk**: Public ALB with self-signed certificate
- **Mitigation**: Acceptable for development environment
- **Mitigation**: Documented limitations in quickstart.md
- **Production**: Recommend ACM with valid domain

**Risk**: Security group misconfiguration
- **Mitigation**: T060 validates security group rules
- **Mitigation**: EC2 instances only accept ALB traffic
- **Validation**: No SSH access possible (verified in T052-T053)

---

## Notes

- Tasks marked [P] can run in parallel (different files, no dependencies)
- Tasks marked [Story] map to specific user stories for traceability
- Each user story delivers independently testable functionality
- Terraform apply requires explicit user approval (not automated)
- Stop at any checkpoint to validate before proceeding
- Certificate generation (T001) is a prerequisite for all infrastructure
- Session Manager access may take 2-3 minutes after instance launch
- Browser warnings for self-signed certificates are expected (not errors)
- Monthly cost estimates assume 24/7 operation (can be reduced with shutdown strategy)

---

**End of Tasks Document**
