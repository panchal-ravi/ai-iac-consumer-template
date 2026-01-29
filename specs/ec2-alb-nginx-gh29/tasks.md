---
description: "Implementation tasks for EC2 ALB Nginx infrastructure"
---

# Tasks: EC2 Instance with ALB and Nginx Infrastructure

**Input**: Design documents from `/specs/ec2-alb-nginx-gh29/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, evaluations/  
**Feature Branch**: `feature/ec2-alb-nginx-gh29`  
**GitHub Issue**: #29

**Tests**: Not requested in feature specification - focused on infrastructure provisioning and validation

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Terraform root module**: Files at repository root (`/workspace/*.tf`)
- **Contracts**: `/workspace/specs/ec2-alb-nginx-gh29/contracts/`
- **Documentation**: `/workspace/README.md`, `/workspace/specs/ec2-alb-nginx-gh29/`

---

## Phase 1: Setup (Repository & Branch Configuration)

**Purpose**: Project initialization and repository structure setup

- [ ] T001 Verify feature branch `feature/ec2-alb-nginx-gh29` is checked out with `git branch --show-current`
- [ ] T002 [P] Verify HCP Terraform backend configuration in override.tf references workspace `sandbox_workspace`
- [ ] T003 [P] Verify sandbox variable file sandbox.auto.tfvars exists with correct environment settings
- [ ] T004 Initialize Terraform with `terraform init` to configure HCP Terraform backend

**Checkpoint**: Repository structure ready, HCP Terraform backend initialized

---

## Phase 2: Foundational (Core Terraform Infrastructure)

**Purpose**: Core Terraform configuration that MUST be complete before ANY user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Create Terraform version constraints in versions.tf requiring Terraform >= 1.5.7
- [ ] T006 [P] Configure AWS provider in providers.tf with region set to ap-southeast-1
- [ ] T007 [P] Define locals in locals.tf for common tags (environment, project, managed-by)
- [ ] T008 Create data source in data.tf to lookup default VPC with filter for isDefault=true
- [ ] T009 [P] Create data source in data.tf to lookup default VPC subnets across all availability zones
- [ ] T010 [P] Create data source in data.tf to lookup latest Amazon Linux 2023 AMI via SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
- [ ] T011 [P] Create data source in data.tf to get availability zones in ap-southeast-1 with state=available filter
- [ ] T012 Define variable `region` in variables.tf with type string, default "ap-southeast-1", validation for ap-southeast-* pattern
- [ ] T013 [P] Define variable `environment` in variables.tf with type string, default "dev", validation for allowed values
- [ ] T014 [P] Define variable `instance_type` in variables.tf with type string, default "t3.micro", description for cost-optimized development
- [ ] T015 [P] Define variable `instance_count` in variables.tf with type number, default 2, validation for minimum 2 instances
- [ ] T016 [P] Define variable `acm_certificate_arn` in variables.tf with type string, description for ACM certificate ARN for HTTPS listener
- [ ] T017 [P] Define variable `common_tags` in variables.tf with type map(string), default tags for environment, project, managed-by

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Deploy Web Infrastructure (Priority: P1) 🎯 MVP

**Goal**: Provision EC2 instances across 2 availability zones in the default VPC to establish basic compute capacity

**Independent Test**: Provision EC2 instances across 2 AZs and verify instances are running in separate zones with `aws ec2 describe-instances`

**Acceptance Criteria**:
- EC2 instances created in 2 different availability zones within default VPC
- All EC2 instances in running state and accessible within VPC
- Instances use cost-optimized t3.micro instance type

### Security & IAM for User Story 1

**CRITICAL**: Addresses aws-security-review.md finding #1 (Missing IAM Least Privilege Implementation)

- [ ] T018 [P] [US1] Create IAM policy document in data.tf for EC2 Session Manager with minimal permissions (ssm:UpdateInstanceInformation, ssmmessages:*, ec2messages:*)
- [ ] T019 [US1] Create custom IAM policy resource in main.tf using policy document from T018 with name "ec2-nginx-session-manager-policy"
- [ ] T020 [US1] Create IAM role in main.tf for EC2 instances with assume_role_policy allowing ec2.amazonaws.com service
- [ ] T021 [US1] Attach custom IAM policy from T019 to IAM role in main.tf (remove generic managed policies per security review)
- [ ] T022 [US1] Create IAM instance profile in main.tf referencing IAM role for EC2 attachment

### EC2 Instances for User Story 1

**CRITICAL**: Addresses aws-security-review.md findings #2 (EBS Encryption), #3 (IMDSv2 enforcement)

- [ ] T023 [P] [US1] Create EC2 security group module call in main.tf using `app.terraform.io/ravi-panchal-org/security-group/aws` version 5.3.1 for instance security group
- [ ] T024 [US1] Configure EC2 security group ingress rule to allow HTTP port 80 from ALB security group (security group reference, not CIDR)
- [ ] T025 [P] [US1] Configure EC2 security group egress rule for HTTPS port 443 to 0.0.0.0/0 for package updates and AWS APIs
- [ ] T026 [P] [US1] Configure EC2 security group egress rule for HTTP port 80 to 0.0.0.0/0 for Amazon Linux package repositories
- [ ] T027 [US1] Copy Nginx user data script from specs/ec2-alb-nginx-gh29/contracts/nginx-user-data.sh to workspace root as user-data-nginx.sh
- [ ] T028 [US1] Create first EC2 instance module call in main.tf using `app.terraform.io/ravi-panchal-org/ec2-instance/aws` version 6.1.4 for availability zone A
- [ ] T029 [US1] Configure first EC2 instance with ami=data.aws_ami latest AL2023, instance_type=var.instance_type, subnet_id=first AZ subnet, user_data=file(user-data-nginx.sh)
- [ ] T030 [US1] Enable EBS encryption on first EC2 instance with root_block_device.encrypted=true and root_block_device.kms_key_id for default AWS managed key (addresses security finding #2)
- [ ] T031 [US1] Enforce IMDSv2 on first EC2 instance with metadata_options.http_tokens="required" and metadata_options.http_put_response_hop_limit=1 (addresses security finding #3)
- [ ] T032 [US1] Attach IAM instance profile from T022 to first EC2 instance
- [ ] T033 [US1] Apply common_tags and Name tag to first EC2 instance with value "ec2-alb-nginx-instance-1-${var.environment}"
- [ ] T034 [P] [US1] Create second EC2 instance module call in main.tf for availability zone B following same configuration as T028-T033 with Name tag "ec2-alb-nginx-instance-2-${var.environment}"
- [ ] T035 [P] [US1] Define output `ec2_instance_ids` in outputs.tf with value list of both instance IDs and description "EC2 instance IDs for Nginx servers"
- [ ] T036 [P] [US1] Define output `ec2_instance_private_ips` in outputs.tf with value list of private IPs and description "Private IP addresses of EC2 instances"
- [ ] T037 [P] [US1] Define output `ec2_availability_zones` in outputs.tf with value list of AZ names and description "Availability zones where instances are deployed"

**Checkpoint**: User Story 1 complete - EC2 instances provisioned across 2 AZs with security hardening

---

## Phase 4: User Story 2 - Secure HTTPS Access (Priority: P2)

**Goal**: Configure Application Load Balancer with HTTPS listener and SSL certificate to encrypt all traffic

**Independent Test**: Configure ALB with HTTPS listener, verify HTTPS connections succeed and HTTP requests are rejected/redirected

**Acceptance Criteria**:
- ALB accepts HTTPS connections with valid SSL certificate
- HTTP connections are refused or redirected to HTTPS
- SSL certificate is valid and properly associated with ALB

### SSL Certificate Configuration

- [ ] T038 [P] [US2] Create data source in data.tf to lookup ACM certificate with domain matching var.certificate_domain, status ISSUED, most_recent=true
- [ ] T039 [P] [US2] Define variable `certificate_domain` in variables.tf with type string, description "Domain name for ACM certificate (e.g., dev.example.com)"
- [ ] T040 [P] [US2] Add validation to certificate_domain variable to ensure non-empty value

### Application Load Balancer Configuration

**CRITICAL**: Implements HTTPS-only access with post-quantum TLS policy per security review

- [ ] T041 [P] [US2] Create ALB security group module call in main.tf using `app.terraform.io/ravi-panchal-org/security-group/aws` version 5.3.1
- [ ] T042 [US2] Configure ALB security group ingress rule for HTTPS port 443 from 0.0.0.0/0 for public internet access
- [ ] T043 [P] [US2] Configure ALB security group ingress rule for HTTP port 80 from 0.0.0.0/0 for redirect to HTTPS
- [ ] T044 [US2] Configure ALB security group egress rule to EC2 security group on port 80 using security group reference (not CIDR)
- [ ] T045 [US2] Create ALB module call in main.tf using `app.terraform.io/ravi-panchal-org/alb/aws` version 10.2.0
- [ ] T046 [US2] Configure ALB with name "ec2-alb-nginx-alb", load_balancer_type="application", subnets covering both availability zones, security_groups from T041
- [ ] T047 [US2] Configure ALB HTTPS listener on port 443 with protocol HTTPS, ssl_policy="ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09" for post-quantum TLS
- [ ] T048 [US2] Configure HTTPS listener certificate_arn from ACM data source (T038)
- [ ] T049 [US2] Configure HTTP listener on port 80 with redirect action to HTTPS port 443 with status_code HTTP_301
- [ ] T050 [P] [US2] Apply common_tags to ALB with additional tag Environment=var.environment
- [ ] T051 [P] [US2] Define output `alb_dns_name` in outputs.tf with value ALB DNS name and description "ALB DNS endpoint for HTTPS access"
- [ ] T052 [P] [US2] Define output `alb_arn` in outputs.tf with value ALB ARN and description "ALB resource ARN"
- [ ] T053 [P] [US2] Define output `alb_zone_id` in outputs.tf with value ALB zone ID and description "Route53 hosted zone ID for ALB"
- [ ] T054 [P] [US2] Define output `https_endpoint` in outputs.tf with value "https://${alb_dns_name}" and description "Full HTTPS URL for accessing the application"

**Checkpoint**: User Story 2 complete - ALB configured with HTTPS listener and SSL certificate

---

## Phase 5: User Story 3 - Load Balanced Traffic Distribution (Priority: P3)

**Goal**: Configure target group and register EC2 instances to distribute traffic evenly across availability zones

**Independent Test**: Send requests through ALB and verify traffic distribution across all healthy instances in both AZs

**Acceptance Criteria**:
- Requests distributed across all healthy instances in both availability zones
- Unhealthy instances automatically removed from rotation by ALB health checks
- Traffic continues without manual intervention during load variations

### Target Group Configuration

**CRITICAL**: Implements health check configuration from research.md Decision 4

- [ ] T055 [US3] Create target group in ALB module configuration with target_type="instance", port=80, protocol="HTTP", vpc_id=default VPC
- [ ] T056 [US3] Configure target group health check with enabled=true, healthy_threshold=2, unhealthy_threshold=2, interval=30, timeout=5, path="/", protocol="HTTP", matcher="200"
- [ ] T057 [US3] Configure target group deregistration_delay=30 for faster failover during deployments
- [ ] T058 [US3] Configure target group stickiness with type="lb_cookie", enabled=false for even distribution
- [ ] T059 [US3] Register first EC2 instance (from T028) to target group with target_id=instance_id, port=80
- [ ] T060 [P] [US3] Register second EC2 instance (from T034) to target group with target_id=instance_id, port=80
- [ ] T061 [US3] Update HTTPS listener from T047 to use target group as default_action forward target
- [ ] T062 [P] [US3] Define output `target_group_arn` in outputs.tf with value target group ARN and description "Target group ARN for EC2 instances"
- [ ] T063 [P] [US3] Define output `target_health_check_path` in outputs.tf with value health check path and description "Health check path configured for target group"

**Checkpoint**: User Story 3 complete - Traffic distributed across instances with health monitoring

---

## Phase 6: User Story 4 - Serve Static Web Content (Priority: P4)

**Goal**: Validate Nginx installation and static content serving through ALB HTTPS endpoint

**Independent Test**: Access ALB HTTPS endpoint and verify Nginx default or custom static content is returned successfully

**Acceptance Criteria**:
- Static HTML content returned successfully via HTTPS through ALB endpoint
- Nginx server headers visible (or hidden per security policy)
- Load balancer rotates traffic showing content from both instances

### Nginx Content Validation

- [ ] T064 [P] [US4] Verify user data script from T027 includes Nginx installation commands with `yum install -y nginx`
- [ ] T065 [P] [US4] Verify user data script enables and starts Nginx service with `systemctl enable nginx && systemctl start nginx`
- [ ] T066 [P] [US4] Verify user data script creates custom HTML content in /usr/share/nginx/html/index.html with environment identifier
- [ ] T067 [P] [US4] Add output to user data script to write instance metadata (instance_id, AZ) to HTML content for verification
- [ ] T068 [US4] Update user data script to configure Nginx to hide server version with `server_tokens off;` in nginx.conf
- [ ] T069 [US4] Ensure user data script logs Nginx installation status to /var/log/user-data.log for troubleshooting

**Checkpoint**: All user stories complete - Full infrastructure functional end-to-end

---

## Phase 7: Security Hardening (Cross-Cutting Security Requirements)

**Purpose**: Address critical and high-priority security findings from aws-security-review.md

**Security Findings Addressed**:
- ✅ Finding #1 (Critical): IAM Least Privilege - Addressed in T018-T022
- ✅ Finding #2 (High): EBS Encryption - Addressed in T030
- ✅ Finding #3 (High): IMDSv2 Enforcement - Addressed in T031
- ⚠️ Finding #4 (High): Excessive EC2 Egress - Addressed in T025-T026 with documentation

### Security Documentation and Validation

- [ ] T070 [P] Document IAM policy least privilege justification in README.md explaining why each permission is required
- [ ] T071 [P] Document security group egress rules justification in README.md for HTTP/HTTPS internet access (package updates, AWS APIs)
- [ ] T072 Document VPC endpoint alternative in README.md for eliminating internet egress with cost/benefit analysis ($14/month for 3 endpoints)
- [ ] T073 [P] Create security checklist validation in README.md confirming HTTPS-only, IMDSv2, EBS encryption, least-privilege IAM
- [ ] T074 Add terraform plan validation command to README.md for security review

### Medium Priority Security Improvements

**Note**: Medium priority findings (P2) from security review - implement if time permits

- [ ] T075 [P] Add IAM Access Analyzer resource in main.tf to validate least-privilege access patterns
- [ ] T076 [P] Configure GuardDuty threat detection for EC2 instances
- [ ] T077 [P] Add condition keys to IAM policy to restrict SSM access to instances with tag Project=ec2-alb-nginx
- [ ] T078 [P] Document missing CloudWatch Logs configuration in README.md with implementation steps

---

## Phase 8: Code Quality Improvements (Terraform Best Practices)

**Purpose**: Address findings from evaluations/terraform-best-practices-review.md

### Code Quality and Structure

- [ ] T079 [P] Add description to all variables in variables.tf with clear purpose and expected values
- [ ] T080 [P] Add description to all outputs in outputs.tf explaining value meaning and use cases
- [ ] T081 Add sensitive=true flag to outputs containing potentially sensitive data
- [ ] T082 [P] Add validation blocks to all variables enforcing constraints
- [ ] T083 [P] Format all Terraform files with `terraform fmt -recursive`
- [ ] T084 Validate Terraform configuration with `terraform validate`
- [ ] T085 [P] Add comments to all resource blocks in main.tf explaining purpose and mapping to functional requirements
- [ ] T086 [P] Group related resources in main.tf with comment headers

### Module Version Constraints

- [ ] T087 [P] Add version constraints to all module calls with exact version pins
- [ ] T088 [P] Document module version selection rationale in README.md
- [ ] T089 Document module upgrade path in README.md

---

## Phase 9: Testing and Validation

**Purpose**: Validate infrastructure deployment and functional requirements

### Pre-Deployment Validation

- [ ] T090 Run `terraform fmt -check` to verify all files are properly formatted
- [ ] T091 Run `terraform validate` to verify configuration syntax is correct
- [ ] T092 Run `tflint` with `.tflint.hcl` configuration
- [ ] T093 [P] Verify ACM certificate exists for domain
- [ ] T094 [P] Verify default VPC exists in ap-southeast-1
- [ ] T095 [P] Verify HCP Terraform workspace exists and is accessible

### Deployment Execution

- [ ] T096 Create Terraform plan with `terraform plan -out=plan.tfplan`
- [ ] T097 Review plan output for expected resources
- [ ] T098 Verify plan shows encryption enabled on EBS volumes
- [ ] T099 Verify plan shows IMDSv2 required
- [ ] T100 Apply Terraform configuration with `terraform apply plan.tfplan`
- [ ] T101 Capture Terraform outputs with `terraform output -json > outputs.json`

### Post-Deployment Validation

- [ ] T102 Verify 2 EC2 instances running in different AZs
- [ ] T103 Verify instances use t3.micro instance type
- [ ] T104 Verify EBS volumes are encrypted
- [ ] T105 Verify IMDSv2 is required
- [ ] T106 [P] Verify ALB is active
- [ ] T107 [P] Verify HTTPS listener exists on port 443
- [ ] T108 [P] Verify HTTP listener redirects to HTTPS
- [ ] T109 Verify target group has 2 registered targets
- [ ] T110 Wait for targets to become healthy (max 5 minutes)
- [ ] T111 Verify both targets are healthy
- [ ] T112 Test HTTPS access and verify HTTP 200 response
- [ ] T113 Verify SSL certificate is valid
- [ ] T114 Test HTTP redirect and verify HTTP 301 redirect to HTTPS
- [ ] T115 Verify Nginx content is served
- [ ] T116 Send 10 requests to verify traffic distribution
- [ ] T117 Verify requests distributed across both availability zones
- [ ] T118 Verify health check path is "/"
- [ ] T119 Verify health check interval is 30 seconds
- [ ] T120 Simulate instance failure and verify target marked unhealthy
- [ ] T121 Verify traffic only routes to healthy instance after failure
- [ ] T122 Restart Nginx and verify instance returns to healthy state
- [ ] T123 [P] Verify ALB security group allows only 443 and 80 inbound
- [ ] T124 [P] Verify EC2 security group allows only ALB security group inbound
- [ ] T125 Verify IAM role has only Session Manager permissions
- [ ] T126 Verify IAM role does NOT have CloudWatchAgentServerPolicy attached
- [ ] T127 Verify all resources have required tags
- [ ] T128 Estimate monthly cost
- [ ] T129 Verify estimated monthly cost is within $31-34 range
- [ ] T130 Enable AWS Cost Explorer tags for tracking
- [ ] T131 Run performance test with 100 concurrent HTTPS connections
- [ ] T132 Verify 95th percentile response time is under 500ms
- [ ] T133 Verify zero failed requests (100% success rate)

---

## Phase 10: Documentation

**Purpose**: Complete user-facing and operational documentation

### README and Operational Documentation

- [ ] T134 Update README.md with architecture overview diagram
- [ ] T135 [P] Document prerequisites in README.md
- [ ] T136 [P] Document deployment instructions in README.md
- [ ] T137 [P] Document validation steps in README.md
- [ ] T138 Document troubleshooting guide in README.md
- [ ] T139 [P] Document cost breakdown in README.md
- [ ] T140 Document operational procedures in README.md
- [ ] T141 Document module versions and rationale in README.md
- [ ] T142 [P] Document security controls in README.md

### Architecture and Design Documentation

- [ ] T143 Create architecture diagram
- [ ] T144 Document data flow in README.md
- [ ] T145 Document security architecture in README.md
- [ ] T146 [P] Add functional requirements mapping table in README.md
- [ ] T147 [P] Add success criteria validation table in README.md

### Code Documentation

- [ ] T148 Add inline comments to main.tf
- [ ] T149 [P] Add inline comments to variables.tf
- [ ] T150 [P] Add inline comments to outputs.tf
- [ ] T151 Add header comment to all .tf files

### Runbook and Operational Playbooks

- [ ] T152 Create RUNBOOK.md with deployment checklist
- [ ] T153 [P] Add failover testing procedure to RUNBOOK.md
- [ ] T154 [P] Add instance replacement procedure to RUNBOOK.md
- [ ] T155 Add rollback procedure to RUNBOOK.md
- [ ] T156 Add monitoring setup in RUNBOOK.md
- [ ] T157 Document backup strategy in RUNBOOK.md

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements and quality enhancements

- [ ] T158 [P] Run pre-commit hooks with `pre-commit run --all-files`
- [ ] T159 Run terraform-docs to auto-generate documentation
- [ ] T160 Verify all security findings addressed with checklist validation
- [ ] T161 Verify code quality score improvements from 0.5/10 to target 8.0+/10
- [ ] T162 [P] Clean up any commented-out code in .tf files
- [ ] T163 [P] Verify all .tf files pass tflint validation with zero warnings
- [ ] T164 Create CHANGELOG.md documenting implementation decisions
- [ ] T165 Tag repository with version v1.0.0-ec2-alb-nginx
- [ ] T166 Update GitHub issue #29 with deployment summary

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational
- **User Story 2 (Phase 4)**: Depends on Foundational
- **User Story 3 (Phase 5)**: Depends on US1 + US2
- **User Story 4 (Phase 6)**: Depends on US3
- **Security Hardening (Phase 7)**: Integrated throughout US1-US4
- **Code Quality (Phase 8)**: Parallel after code exists
- **Testing (Phase 9)**: Depends on US1-US4
- **Documentation (Phase 10)**: Parallel during implementation
- **Polish (Phase 11)**: Depends on all previous phases

### Critical Path

1. Phase 1: Setup → 15 minutes
2. Phase 2: Foundational → 30 minutes
3. Phase 3: US1 - EC2 Infrastructure → 2 hours
4. Phase 4: US2 - HTTPS/ALB → 1.5 hours
5. Phase 5: US3 - Load Balancing → 1 hour
6. Phase 6: US4 - Static Content → 30 minutes
7. Phase 9: Testing & Validation → 2 hours

**Total Critical Path**: ~8 hours for MVP deployment

---

## Implementation Strategy

### MVP First (Recommended)

1. Complete Phase 1-2 (Setup + Foundational)
2. Complete Phase 3-6 (All user stories)
3. Run Phase 9 testing
4. Deploy to HCP Terraform workspace

**Time to MVP**: ~6-8 hours

### Security-First Approach

1. Complete Phase 1-2
2. Implement Phase 3 WITH Phase 7 security tasks
3. Implement Phase 4-6
4. Complete Phase 7 documentation
5. Validate with security checklist

**Time to Secure MVP**: ~10-12 hours

---

## Notes

- **Total Tasks**: 166
- **Estimated Time**: 12-15 hours
- **Parallel Opportunities**: ~40% of tasks
- **Module Versions**: ec2-instance=6.1.4, alb=10.2.0, security-group=5.3.1
- **Cost Target**: $31-34/month
- **Deployment Time**: 15-22 minutes
