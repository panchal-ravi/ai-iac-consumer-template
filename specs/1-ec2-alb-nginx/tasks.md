# Implementation Tasks: EC2 Instance with ALB and Nginx

**Feature**: EC2 Instance with ALB and Nginx
**Plan**: `plan.md`
**Status**: Task Planning Phase
**Created**: 2025-11-10

## Task Organization

Tasks are organized into sequential phases. Each phase must complete before the next begins. Tasks within a phase may have dependencies indicated in the "Depends On" column.

---

## Phase 1: Foundation Setup (Data Sources and Locals)

**Phase Goal**: Establish infrastructure foundation with VPC discovery and common configuration

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 1.1 | Create data.tf | Create data sources file for default VPC and subnet discovery | File exists with proper structure | None | 5 min |
| 1.2 | Query default VPC | Add data source to retrieve default VPC in ap-southeast-2 | VPC ID retrieved successfully, error handling for missing VPC | 1.1 | 5 min |
| 1.3 | Query subnets across 2 AZs | Add data source to retrieve public subnets in 2 availability zones | At least 2 subnets from different AZs retrieved | 1.2 | 5 min |
| 1.4 | Query ACM certificate | Add data source to find ACM certificate or accept user input via variable | Certificate ARN available for ALB HTTPS listener | 1.2 | 5 min |
| 1.5 | Create locals.tf | Define common tags, naming conventions, and computed values | Standard tags defined (Environment, ManagedBy, Purpose, Project) | None | 5 min |
| 1.6 | Validate Phase 1 | Run `terraform validate` and `terraform fmt` | No validation errors, code properly formatted | 1.1-1.5 | 5 min |

**Phase 1 Total Estimated Time**: 30 minutes

---

## Phase 2: Security Configuration (Security Groups)

**Phase Goal**: Establish network security controls for ALB and EC2 instances

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 2.1 | Create ALB security group | Use security-group module to create ALB security group with HTTPS ingress | Security group created with port 443 ingress from 0.0.0.0/0 | 1.6 | 10 min |
| 2.2 | Create EC2 security group | Use security-group module to create EC2 security group | Security group created with proper VPC association | 1.6 | 5 min |
| 2.3 | Add EC2 ingress rule | Configure ingress rule allowing HTTP (80) from ALB security group only | Rule references ALB security group ID correctly | 2.1, 2.2 | 5 min |
| 2.4 | Add EC2 egress rules | Configure egress rules for HTTP/HTTPS (package installation) | Rules allow outbound 80/443 to 0.0.0.0/0 | 2.2 | 5 min |
| 2.5 | Run security scans | Execute tfsec, checkov, and trivy scans | Zero CRITICAL findings | 2.1-2.4 | 5 min |
| 2.6 | Validate Phase 2 | Run `terraform validate` and review plan output | Security groups in plan with correct rules | 2.1-2.5 | 5 min |

**Phase 2 Total Estimated Time**: 35 minutes

---

## Phase 3: Load Balancer Configuration (ALB and Target Group)

**Phase Goal**: Deploy Application Load Balancer with HTTPS listener and target group

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 3.1 | Create ALB module declaration | Declare ALB module with basic configuration | Module block created with required arguments | 1.6, 2.6 | 10 min |
| 3.2 | Configure HTTPS listener | Add HTTPS listener on port 443 with ACM certificate | Listener configured with certificate_arn from data source | 1.4, 3.1 | 10 min |
| 3.3 | Create target group | Define target group with HTTP protocol on port 80 | Target group created with correct protocol and port | 3.1 | 5 min |
| 3.4 | Configure health checks | Set health check parameters (path: /, interval: 30s, timeout: 5s, thresholds: 2) | Health check block configured per spec | 3.3 | 5 min |
| 3.5 | Attach ALB security group | Reference security group from Phase 2 in ALB configuration | ALB uses security group from task 2.1 | 2.1, 3.1 | 5 min |
| 3.6 | Configure ALB subnets | Use subnet IDs from Phase 1 data source for ALB placement | ALB deployed across 2 AZs | 1.3, 3.1 | 5 min |
| 3.7 | Validate Phase 3 | Run `terraform plan` and review ALB configuration | ALB, listener, and target group in plan | 3.1-3.6 | 10 min |

**Phase 3 Total Estimated Time**: 50 minutes

---

## Phase 4: Compute Resources (EC2 Instances with Nginx)

**Phase Goal**: Deploy EC2 instances with automated Nginx installation across 2 AZs

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 4.1 | Create user data script | Write user data script for Nginx installation and configuration | Script installs Nginx, creates custom HTML page with hostname | None | 10 min |
| 4.2 | Create EC2 module for AZ1 | Declare ec2-instance module for first availability zone | Module created with instance_type: t3.micro | 1.6, 2.6, 4.1 | 10 min |
| 4.3 | Configure user data for AZ1 | Attach user data script to AZ1 instance | User data base64-encoded and attached | 4.1, 4.2 | 5 min |
| 4.4 | Attach security group to AZ1 | Reference EC2 security group in instance configuration | Instance uses security group from task 2.2 | 2.2, 4.2 | 5 min |
| 4.5 | Create EC2 module for AZ2 | Declare ec2-instance module for second availability zone | Module created with instance_type: t3.micro | 1.6, 2.6, 4.1 | 10 min |
| 4.6 | Configure user data for AZ2 | Attach user data script to AZ2 instance | User data base64-encoded and attached | 4.1, 4.5 | 5 min |
| 4.7 | Attach security group to AZ2 | Reference EC2 security group in instance configuration | Instance uses security group from task 2.2 | 2.2, 4.5 | 5 min |
| 4.8 | Attach instances to target group | Configure target group attachments for both instances | Both instances registered with target group from task 3.3 | 3.3, 4.2, 4.5 | 10 min |
| 4.9 | Validate Phase 4 | Run `terraform plan` and review EC2 configuration | 2 EC2 instances with user data and target group attachments in plan | 4.1-4.8 | 10 min |

**Phase 4 Total Estimated Time**: 70 minutes

---

## Phase 5: Outputs and Documentation

**Phase Goal**: Define outputs for observability and generate documentation

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 5.1 | Create outputs.tf | Create outputs file with all required outputs | File exists with proper structure | None | 5 min |
| 5.2 | Add ALB outputs | Define outputs for ALB DNS name, ARN, and zone ID | Outputs extract values from ALB module | 3.7 | 5 min |
| 5.3 | Add target group outputs | Define output for target group ARN | Output references target group correctly | 3.7 | 3 min |
| 5.4 | Add EC2 outputs | Define outputs for EC2 instance IDs and private IPs | Outputs extract values from both EC2 instances | 4.9 | 5 min |
| 5.5 | Add security group outputs | Define outputs for ALB and EC2 security group IDs | Outputs reference security groups from Phase 2 | 2.6 | 3 min |
| 5.6 | Configure terraform-docs | Ensure .pre-commit-config.yaml includes terraform-docs hook | Hook configured to auto-generate README.md | None | 5 min |
| 5.7 | Validate outputs | Run `terraform validate` and check output definitions | All outputs valid and properly typed | 5.1-5.5 | 5 min |

**Phase 5 Total Estimated Time**: 31 minutes

---

## Phase 6: Variables and Configuration Files

**Phase Goal**: Define input variables and create supporting configuration files

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 6.1 | Create variables.tf | Create variables file with all input variable definitions | File exists with proper structure | None | 10 min |
| 6.2 | Define required variables | Add variables for environment, project_name, aws_region | Variables have descriptions, types, and validation rules | 6.1 | 10 min |
| 6.3 | Define optional variables | Add variables for instance_type, health_check_*, certificate_arn | Variables have appropriate defaults | 6.1 | 10 min |
| 6.4 | Create sandbox.auto.tfvars.example | Create example variables file for testing | File documents all required variable values | 6.1-6.3 | 5 min |
| 6.5 | Create sandbox.auto.tfvars | Create actual variables file for testing | File contains values for sandbox testing | 6.4 | 5 min |
| 6.6 | Create override.tf | Create override file for HCP Terraform cloud backend configuration | Backend configured for `sandbox_ai-iac-consumer-template` workspace in Default Project | None | 5 min |
| 6.7 | Validate Phase 6 | Run `terraform validate` | All variables properly defined | 6.1-6.6 | 5 min |

**Phase 6 Total Estimated Time**: 50 minutes

---

## Phase 7: Provider and Terraform Configuration

**Phase Goal**: Configure providers and Terraform settings

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 7.1 | Create versions.tf | Create Terraform and provider version constraints | Terraform >= 1.8, AWS provider ~> 6.0 | None | 5 min |
| 7.2 | Create providers.tf | Create AWS provider configuration | Provider configured for ap-southeast-2 with tags | None | 5 min |
| 7.3 | Create main.tf | Create main file or consolidate module declarations | Main file structure established | None | 5 min |
| 7.4 | Add provider tags | Configure default tags in AWS provider | Tags include Environment, ManagedBy, Project | 1.5, 7.2 | 5 min |
| 7.5 | Validate Phase 7 | Run `terraform init` and `terraform validate` | Initialization succeeds, validation passes | 7.1-7.4 | 5 min |

**Phase 7 Total Estimated Time**: 25 minutes

---

## Phase 8: Pre-commit and Code Quality

**Phase Goal**: Configure pre-commit hooks and run all quality checks

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 8.1 | Install/update pre-commit framework | Run installation script for pre-commit | Pre-commit framework installed and available | None | 5 min |
| 8.2 | Configure pre-commit hooks | Update .git/hooks/pre-commit to use framework | Hook file configured correctly | 8.1 | 5 min |
| 8.3 | Verify pre-commit config | Check .pre-commit-config.yaml has required hooks | Config includes terraform_fmt, terraform_validate, tfsec, checkov, trivy | None | 5 min |
| 8.4 | Run terraform fmt | Format all Terraform files | All files formatted consistently | All previous phases | 5 min |
| 8.5 | Run terraform validate | Validate Terraform configuration | Validation passes without errors | 8.4 | 5 min |
| 8.6 | Run tfsec scan | Execute security static analysis | Zero CRITICAL findings, document any MEDIUM/LOW findings | 8.5 | 5 min |
| 8.7 | Run checkov scan | Execute policy-as-code checks | Zero CRITICAL findings | 8.6 | 5 min |
| 8.8 | Run trivy scan | Execute misconfiguration detection | Zero CRITICAL findings | 8.7 | 5 min |
| 8.9 | Fix identified issues | Resolve any security or quality issues found | All blocking issues resolved | 8.6-8.8 | 15 min |
| 8.10 | Validate Phase 8 | Run all pre-commit hooks together | All hooks pass | 8.1-8.9 | 5 min |

**Phase 8 Total Estimated Time**: 60 minutes

---

## Phase 9: Git Operations and Branch Management

**Phase Goal**: Commit changes and push to remote repository

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 9.1 | Stage all files | Add all Terraform files to git staging | `git status` shows all files staged | All previous phases | 2 min |
| 9.2 | Commit changes | Commit with descriptive message | Commit includes reference to feature and spec | 9.1 | 3 min |
| 9.3 | Push feature branch | Push feature/ec2-alb-nginx branch to remote | Branch available on GitHub remote | 9.2 | 2 min |
| 9.4 | Verify push success | Confirm branch exists on GitHub | `gh repo view` shows feature branch | 9.3 | 2 min |

**Phase 9 Total Estimated Time**: 9 minutes

---

## Phase 10: Ephemeral Workspace Testing

**Phase Goal**: Test infrastructure in ephemeral HCP Terraform workspace

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 10.1 | Create ephemeral workspace | Create HCP Terraform workspace for testing | Workspace `sandbox_ai-iac-consumer-template` created with auto-apply and auto-destroy (2 hours) | 9.4 | 5 min |
| 10.2 | Connect workspace to branch | Configure workspace to use feature/ec2-alb-nginx branch | Workspace VCS connection established | 10.1 | 5 min |
| 10.3 | Create workspace variables | Analyze variables.tf and create workspace variables from sandbox.auto.tfvars | All required variables created (environment, project_name, certificate_arn if needed) | 6.5, 10.1 | 10 min |
| 10.4 | Validate variable values | Prompt user for certificate ARN and other non-determinable values | User confirms variable values | 10.3 | 5 min |
| 10.5 | Trigger Terraform plan | Initiate Terraform plan in ephemeral workspace | Plan executes successfully | 10.2-10.4 | 10 min |
| 10.6 | Review plan output | Analyze plan output for issues | Plan shows expected resources: 1 ALB, 2 EC2, 2 SGs, 1 TG | 10.5 | 10 min |
| 10.7 | Execute Terraform apply | Allow auto-apply to proceed | Apply completes successfully | 10.6 | 15 min |
| 10.8 | Wait for instances healthy | Monitor target group health status | Both EC2 instances show healthy within 5 minutes | 10.7 | 10 min |
| 10.9 | Test HTTPS accessibility | curl ALB DNS name via HTTPS | HTTP 200 response with Nginx page | 10.8 | 5 min |
| 10.10 | Prompt user validation | Ask user to validate deployed resources | User confirms resources created correctly | 10.9 | 5 min |
| 10.11 | Fix any issues | If testing reveals issues, fix code and re-test | All tests pass | 10.5-10.10 | Variable |
| 10.12 | Document test results | Record test outcomes and any issues encountered | Test report created | 10.9-10.11 | 5 min |

**Phase 10 Total Estimated Time**: 85 minutes (excluding issue fixes)

---

## Phase 11: Dev Workspace Setup

**Phase Goal**: Configure dev workspace with validated variables

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 11.1 | Identify dev workspace | Determine dev workspace name from repository/user | Dev workspace name confirmed | 10.12 | 2 min |
| 11.2 | Create dev workspace variables | Create identical variables from ephemeral workspace in dev workspace | All variables created with same values | 10.12, 11.1 | 10 min |
| 11.3 | Document variable requirements | Update README with variable requirements for staging/prod | Documentation includes all variable descriptions and values | 11.2 | 5 min |
| 11.4 | Validate Phase 11 | Confirm dev workspace ready for deployment | Workspace configured correctly | 11.1-11.3 | 3 min |

**Phase 11 Total Estimated Time**: 20 minutes

---

## Phase 12: Ephemeral Workspace Cleanup

**Phase Goal**: Clean up ephemeral workspace to minimize costs

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 12.1 | Trigger workspace destroy | Queue destroy run in ephemeral workspace | Destroy plan created | 10.12, 11.4 | 5 min |
| 12.2 | Monitor destroy operation | Watch destroy run progress | All resources destroyed successfully | 12.1 | 10 min |
| 12.3 | Verify cleanup | Confirm no resources remain in AWS | EC2, ALB, SGs all deleted | 12.2 | 5 min |
| 12.4 | Delete ephemeral workspace | Remove ephemeral workspace from HCP Terraform | Workspace deleted (or will auto-destroy in 2 hours) | 12.3 | 3 min |

**Phase 12 Total Estimated Time**: 23 minutes

---

## Phase 13: Documentation and Finalization

**Phase Goal**: Generate final documentation and prepare for review

| Task ID | Task | Description | Acceptance Criteria | Dependencies | Est. Time |
|---------|------|-------------|---------------------|--------------|-----------|
| 13.1 | Run terraform-docs | Generate README.md using terraform-docs | README includes inputs, outputs, modules | All previous phases | 5 min |
| 13.2 | Update README with testing info | Add testing section to README | Testing procedures documented | 13.1 | 10 min |
| 13.3 | Update README with deployment info | Add deployment section with HCP Terraform instructions | Deployment steps clear and complete | 13.2 | 10 min |
| 13.4 | Create deployment log | Log all deployment details, issues, and resolutions | Log file created with timestamp | 10.12, 12.4 | 10 min |
| 13.5 | Commit documentation updates | Commit README and documentation changes | Documentation committed to feature branch | 13.1-13.4 | 3 min |
| 13.6 | Push documentation | Push final changes to remote | Changes available on GitHub | 13.5 | 2 min |
| 13.7 | Validate Phase 13 | Review all documentation | Documentation complete and accurate | 13.1-13.6 | 5 min |

**Phase 13 Total Estimated Time**: 45 minutes

---

## Summary

### Total Task Count: 91 tasks across 13 phases

### Total Estimated Time: ~533 minutes (~8.9 hours)

**Note**: Actual time may vary based on:
- AWS resource provisioning speed
- Network latency
- Issue resolution time in Phase 10.11
- User response time for validations

### Phase Summary

| Phase | Tasks | Est. Time | Critical Path |
|-------|-------|-----------|---------------|
| Phase 1: Foundation | 6 | 30 min | ✅ |
| Phase 2: Security | 6 | 35 min | ✅ |
| Phase 3: Load Balancer | 7 | 50 min | ✅ |
| Phase 4: Compute | 9 | 70 min | ✅ |
| Phase 5: Outputs | 7 | 31 min | - |
| Phase 6: Variables | 7 | 50 min | ✅ |
| Phase 7: Provider Config | 5 | 25 min | ✅ |
| Phase 8: Code Quality | 10 | 60 min | ✅ |
| Phase 9: Git Operations | 4 | 9 min | ✅ |
| Phase 10: Testing | 12 | 85 min | ✅ |
| Phase 11: Dev Setup | 4 | 20 min | - |
| Phase 12: Cleanup | 4 | 23 min | - |
| Phase 13: Documentation | 7 | 45 min | - |

### Success Criteria Summary

✅ **Code Quality**:
- Terraform fmt passes
- Terraform validate passes
- Zero CRITICAL findings from security scans

✅ **Functionality**:
- ALB responds to HTTPS requests (HTTP 200)
- Both EC2 instances healthy within 5 minutes
- Nginx serves custom HTML page

✅ **Security**:
- HTTPS-only access to ALB
- EC2 instances not directly accessible
- Security groups follow least privilege

✅ **Cost**:
- Estimated monthly cost < $50 USD

✅ **Documentation**:
- README.md auto-generated with complete information
- Variable requirements documented
- Testing procedures documented

### Dependencies Between Phases

```
Phase 1 (Foundation) → Phase 2 (Security) → Phase 3 (ALB) → Phase 4 (Compute)
                                                    ↓
Phase 6 (Variables) → Phase 7 (Providers) → Phase 8 (Quality) → Phase 9 (Git)
                                                                       ↓
                                                Phase 10 (Testing) → Phase 11 (Dev)
                                                       ↓
                                            Phase 12 (Cleanup) → Phase 13 (Docs)

Phase 5 (Outputs) can run parallel with Phase 6-7
```

### Key Milestones

1. **Foundation Complete** (After Phase 1): VPC and subnets discovered
2. **Security Complete** (After Phase 2): Security groups configured and scanned
3. **Infrastructure Complete** (After Phase 4): All resources defined
4. **Code Quality Verified** (After Phase 8): Pre-commit checks pass
5. **Testing Complete** (After Phase 10): Infrastructure validated in ephemeral workspace
6. **Ready for Dev Deployment** (After Phase 11): Dev workspace configured
7. **Project Complete** (After Phase 13): Documentation finalized

---

**Task Status**: ✅ **READY FOR IMPLEMENTATION**

**Next Steps**:
1. Review task breakdown with stakeholders
2. Run `/speckit.analyze` for cross-artifact validation
3. Proceed to `/speckit.implement` when approved
