# Task Dependency Graph: AWS EC2 Infrastructure with ALB and Nginx

**Feature**: EC2 ALB Nginx Infrastructure  
**Created**: 2025-02-01  
**Purpose**: Visual representation of implementation task dependencies and execution workflow

---

## Executive Summary

This document provides a comprehensive dependency analysis of all implementation tasks for the EC2/ALB/Nginx infrastructure. The analysis identifies:

- **Total Tasks**: 28 implementation tasks
- **Critical Path Duration**: ~2.5 hours (T001 → T028)
- **Parallel Opportunities**: 12 tasks can run concurrently
- **Bottleneck Tasks**: Security groups (T010, T011) block multiple downstream tasks
- **Estimated Total Effort**: ~4 hours sequential, ~2.5 hours with parallelization

---

## 1. Complete Task Dependency Graph

### ASCII Dependency Tree

```
ROOT (Project Setup)
│
├─[T001] 15m Create project structure and directory layout
│   └─[T002] 10m Initialize Terraform configuration (versions.tf)
│       └─[T003] 10m Configure AWS and TLS providers (providers.tf)
│           │
│           ├─[T004] 15m Define input variables (variables.tf)
│           │   │
│           │   ├─[T005] 20m Configure data sources for VPC/subnets (main.tf - Part 1)
│           │   │   │
│           │   │   ├─[T006]║ 25m Generate TLS certificate (main.tf - Part 2)
│           │   │   │   └─[T007]║ 15m Import certificate to ACM (main.tf - Part 3)
│           │   │   │
│           │   │   ├─[T008]║ 20m Create user-data.sh script for Nginx
│           │   │   │
│           │   │   └─[T009]║ 15m Define output values (outputs.tf)
│           │   │
│           │   └─[T005] (Wait for completion)
│           │       │
│           │       ├─[T010] 20m Create ALB security group (main.tf - Part 4)
│           │       │   │
│           │       │   ├─[T011] 20m Create EC2 security group (main.tf - Part 5)
│           │       │   │   │
│           │       │   │   └─[T012] 25m Create EC2 instances with modules (main.tf - Part 6)
│           │       │   │       │
│           │       │   │       ├─[T013] 20m Create ALB target group (main.tf - Part 7)
│           │       │   │       │   │
│           │       │   │       │   └─[T014] 15m Register instances to target group (main.tf - Part 8)
│           │       │   │       │       │
│           │       │   │       │       └─[T015] 25m Create ALB with module (main.tf - Part 9)
│           │       │   │       │           │
│           │       │   │       │           └─[T016] 20m Configure HTTPS listener (main.tf - Part 10)
│           │       │   │       │
│           │       │   │       └─[T017]║ 15m Create terraform.tfvars
│           │       │   │
│           │       │   └─[T007] (ALB cert ready) ─────────┘
│           │       │
│           │       └─[T010] (Security groups ready)
│           │
│           └─[T003] (Providers configured)
│
│
VALIDATION PHASE (After all infrastructure code complete)
│
├─[T018] 10m Initialize Terraform workspace
│   └─[T019] 5m Validate Terraform configuration
│       └─[T020] 15m Plan infrastructure changes
│           └─[T021] 30m Apply infrastructure (deployment)
│               │
│               ├─[T022]║ 10m Verify EC2 instances running
│               ├─[T023]║ 10m Verify target health checks
│               ├─[T024]║ 10m Test HTTPS endpoint via ALB
│               └─[T025]║ 10m Verify security group rules
│
│
DOCUMENTATION & CLEANUP (Final phase)
│
└─[T021] (Infrastructure deployed)
    │
    ├─[T026]║ 15m Document deployment results
    ├─[T027]║ 10m Create operational runbook
    └─[T028] 5m Final validation checklist
```

**Legend**:
- `[T###]` - Task ID with estimated duration
- `║` - Indicates parallelizable task (can run concurrently with siblings)
- `│`, `└─`, `├─` - Dependency flow (top-to-bottom, parent-to-child)
- Tasks at same level with `║` can execute in parallel

---

## 2. Task Execution Phases

### Phase 1: Project Setup (Sequential)
**Duration**: 45 minutes | **Tasks**: T001-T003 | **Parallelization**: None

```
T001 (15m) → T002 (10m) → T003 (10m) → T004 (10m)
```

These tasks must execute sequentially as each depends on the previous:
- T001: Creates directory structure
- T002: Requires directory structure to create versions.tf
- T003: Requires versions.tf to define providers
- T004: Requires providers to define variables

---

### Phase 2: Foundation & Certificate (Parallel + Sequential)
**Duration**: 40 minutes | **Tasks**: T005-T009 | **Parallelization**: High (60%)

```
         T005 (20m) ─────┐
              │          │
              ├─ T006 (25m) ───→ T007 (15m)
              │          │
              ├─ T008 (20m)
              │          │
              └─ T009 (15m)
                         │
                 Sync Point (All complete)
```

**Parallel Execution Groups**:
- **Group A**: T005 (data sources) - MUST complete first
- **Group B**: T006, T008, T009 - Can run in parallel after T005
  - T006: TLS certificate generation
  - T008: Nginx user data script
  - T009: Output definitions
- **Group C**: T007 - Depends only on T006

**Optimal Execution**:
1. Start T005 (20m)
2. After T005: Start T006 || T008 || T009 in parallel (max 25m)
3. After T006: Start T007 (15m)

**Critical Path**: T005 → T006 → T007 = 60 minutes
**Optimized Path**: 60 minutes (sequential on critical path)

---

### Phase 3: Network Security (Sequential)
**Duration**: 40 minutes | **Tasks**: T010-T011 | **Parallelization**: None

```
T010 (20m) → T011 (20m)
ALB SG       EC2 SG (depends on ALB SG ID)
```

**Why Sequential**:
- T011 (EC2 security group) must reference T010 (ALB security group ID) in ingress rules
- EC2 SG allows HTTP:80 only from ALB SG as source

---

### Phase 4: Compute & Load Balancer (Mixed)
**Duration**: 105 minutes sequential, 70 minutes optimized | **Tasks**: T012-T017 | **Parallelization**: Low

```
              T012 (25m)
                 │
        ┌────────┴────────┐
        │                 │
     T013 (20m)        T017 (15m) ║
        │
     T014 (15m)
        │
     T015 (25m)
        │
     T016 (20m)
```

**Parallel Opportunity**:
- T017 (terraform.tfvars) can run in parallel with T013-T016 chain
- Saves 15 minutes in Phase 4

**Critical Dependencies**:
- T013 depends on T012 (needs instance IDs)
- T014 depends on T013 (needs target group ARN)
- T015 depends on T014 + T007 (needs instances registered + ACM cert)
- T016 depends on T015 (needs ALB ARN)

---

### Phase 5: Validation & Testing (Sequential + Parallel)
**Duration**: 70 minutes sequential, 40 minutes optimized | **Tasks**: T018-T025 | **Parallelization**: High

```
T018 (10m) → T019 (5m) → T020 (15m) → T021 (30m)
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                 T022 (10m)║         T023 (10m)║         T024 (10m)║
                                         │
                                      T025 (10m)║
```

**Parallel Execution Groups**:
- **Sequential**: T018 → T019 → T020 → T021 (must complete in order)
- **Parallel**: T022, T023, T024, T025 (all can run simultaneously after T021)

**Optimization**:
- After infrastructure applies (T021), all verification tasks are independent
- Run all 4 verification tasks concurrently
- Saves 30 minutes (40m vs 70m sequential)

---

### Phase 6: Documentation (Parallel)
**Duration**: 30 minutes sequential, 15 minutes optimized | **Tasks**: T026-T028 | **Parallelization**: High

```
         ┌─ T026 (15m)║
         │
T021 ───┼─ T027 (10m)║
         │
         └─ T028 (5m)║
```

All documentation tasks are independent and can run in parallel.

---

## 3. Critical Path Analysis

### Critical Path Identification

**Longest dependency chain (sequential execution)**:

```
T001 → T002 → T003 → T004 → T005 → T006 → T007 → T010 → T011 → T012 → T013 → T014 → T015 → T016 → T018 → T019 → T020 → T021 → T022
```

**Critical Path Duration**: 285 minutes (4 hours 45 minutes)

**Breakdown by Phase**:
1. Setup (T001-T004): 45 minutes
2. Foundation (T005-T007): 60 minutes
3. Security (T010-T011): 40 minutes
4. Infrastructure (T012-T016): 105 minutes
5. Validation (T018-T021): 60 minutes

**Bottleneck Tasks** (block multiple downstream tasks):
- **T005** (data sources): Blocks T006, T008, T009, T010
- **T007** (ACM import): Blocks T015 (ALB creation)
- **T010** (ALB SG): Blocks T011, T015
- **T011** (EC2 SG): Blocks T012 (EC2 instances)
- **T012** (EC2 instances): Blocks T013, T014
- **T021** (Apply): Blocks all testing tasks

---

### Optimization Opportunities

**Parallelization Savings**:

| Phase | Sequential | Optimized | Savings | Strategy |
|-------|-----------|-----------|---------|----------|
| Phase 1 (Setup) | 45m | 45m | 0m | No parallelization possible |
| Phase 2 (Foundation) | 85m | 60m | 25m | Run T008, T009 parallel with T006 |
| Phase 3 (Security) | 40m | 40m | 0m | T011 depends on T010 ID |
| Phase 4 (Compute) | 105m | 90m | 15m | Run T017 parallel with T013-T016 |
| Phase 5 (Validation) | 70m | 40m | 30m | Run T022-T025 in parallel |
| Phase 6 (Docs) | 30m | 15m | 15m | Run T026-T028 in parallel |
| **TOTAL** | **375m** | **290m** | **85m** | **23% faster** |

**Key Optimization**: With proper parallelization, total execution time reduces from **6.25 hours to 4.83 hours**.

---

## 4. Dependency Matrix

### Cross-Reference Table

| Task | Depends On | Blocks | Can Parallel With | Files Modified |
|------|-----------|--------|-------------------|----------------|
| T001 | None | T002 | - | Directory structure |
| T002 | T001 | T003 | - | versions.tf |
| T003 | T002 | T004, T005 | - | providers.tf |
| T004 | T003 | T005 | - | variables.tf |
| T005 | T004 | T006, T008, T009, T010 | - | main.tf (data sources) |
| T006 | T005 | T007 | T008, T009 | main.tf (TLS resources) |
| T007 | T006 | T015 | T008, T009 | main.tf (ACM import) |
| T008 | T005 | - | T006, T007, T009 | user-data.sh |
| T009 | T005 | - | T006, T007, T008 | outputs.tf |
| T010 | T005 | T011, T015 | T006, T007, T008, T009 | main.tf (ALB SG) |
| T011 | T010 | T012 | - | main.tf (EC2 SG) |
| T012 | T011 | T013 | T017 | main.tf (EC2 modules) |
| T013 | T012 | T014 | T017 | main.tf (target group) |
| T014 | T013 | T015 | T017 | main.tf (TG attachments) |
| T015 | T007, T010, T014 | T016 | T017 | main.tf (ALB module) |
| T016 | T015 | T018 | T017 | main.tf (HTTPS listener) |
| T017 | T012 | - | T013-T016 | terraform.tfvars |
| T018 | T016, T017 | T019 | - | terraform init |
| T019 | T018 | T020 | - | terraform validate |
| T020 | T019 | T021 | - | terraform plan |
| T021 | T020 | T022-T025 | - | terraform apply |
| T022 | T021 | T026 | T023, T024, T025 | Verification |
| T023 | T021 | T026 | T022, T024, T025 | Verification |
| T024 | T021 | T026 | T022, T023, T025 | Verification |
| T025 | T021 | T026 | T022, T023, T024 | Verification |
| T026 | T022-T025 | T028 | T027 | Documentation |
| T027 | T022-T025 | T028 | T026 | Documentation |
| T028 | T026, T027 | None | - | Final checklist |

---

## 5. Resource Dependency Graph

### Terraform Resource Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES (T005)                       │
│  - aws_vpc (default VPC)                                        │
│  - aws_availability_zones (ap-southeast-1)                      │
│  - aws_subnets (filter by VPC)                                  │
│  - aws_ami (Amazon Linux 2023)                                  │
└───────────┬──────────────────────────────────┬──────────────────┘
            │                                  │
            │                                  │
    ┌───────▼────────┐              ┌─────────▼──────────┐
    │ TLS Certificate│              │  Security Groups   │
    │    (T006-T007) │              │    (T010-T011)     │
    │                │              │                    │
    │ • tls_private_key             │ • ALB SG (T010)   │
    │ • tls_self_signed_cert        │   - HTTP:443 ← 0.0.0.0/0
    │ • aws_acm_certificate         │   - HTTP:80 → EC2 SG
    └───────┬────────┘              │                    │
            │                       │ • EC2 SG (T011)   │
            │                       │   - HTTP:80 ← ALB SG only
            │                       └─────────┬──────────┘
            │                                 │
            │                                 │
            │                       ┌─────────▼──────────┐
            │                       │   EC2 Instances    │
            │                       │      (T012)        │
            │                       │                    │
            │                       │ • module.ec2_instance_1 (AZ-a)
            │                       │ • module.ec2_instance_2 (AZ-b)
            │                       │ • user_data: user-data.sh (T008)
            │                       └─────────┬──────────┘
            │                                 │
            │                       ┌─────────▼──────────┐
            │                       │   Target Group     │
            │                       │      (T013)        │
            │                       │                    │
            │                       │ • aws_lb_target_group
            │                       │ • Health check: HTTP:80 /
            │                       └─────────┬──────────┘
            │                                 │
            │                       ┌─────────▼──────────┐
            │                       │ TG Attachments     │
            │                       │      (T014)        │
            │                       │                    │
            │                       │ • Register instance 1
            │                       │ • Register instance 2
            │                       └─────────┬──────────┘
            │                                 │
            └─────────────────┬───────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Load Balancer     │
                    │      (T015)        │
                    │                    │
                    │ • module.alb       │
                    │ • internet-facing  │
                    │ • Multi-AZ         │
                    │ • ALB SG attached  │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │ HTTPS Listener     │
                    │      (T016)        │
                    │                    │
                    │ • Port: 443        │
                    │ • Certificate: ACM │
                    │ • Forward to: TG   │
                    └────────────────────┘
```

---

## 6. Parallel Execution Strategy

### Execution Groups by Dependency Level

**Level 0** (No dependencies):
- T001: Create project structure [15m]

**Level 1** (Depends on Level 0):
- T002: Initialize Terraform [10m]

**Level 2** (Depends on Level 1):
- T003: Configure providers [10m]

**Level 3** (Depends on Level 2):
- T004: Define variables [10m]

**Level 4** (Depends on Level 3):
- T005: Configure data sources [20m]

**Level 5** (Depends on Level 4) - **PARALLEL GROUP**:
- T006: Generate TLS certificate [25m] ║
- T008: Create user-data.sh [20m] ║
- T009: Define outputs [15m] ║
- T010: Create ALB security group [20m] ║

**Level 6** (Mixed dependencies):
- T007: Import certificate to ACM [15m] (depends on T006)
- T011: Create EC2 security group [20m] (depends on T010)

**Level 7** (Depends on Level 6):
- T012: Create EC2 instances [25m]

**Level 8** (Mixed dependencies) - **SEMI-PARALLEL GROUP**:
- T013: Create target group [20m] (depends on T012)
- T017: Create tfvars [15m] (depends on T012) ║

**Level 9** (Depends on T013):
- T014: Register instances to TG [15m]

**Level 10** (Depends on T007, T014):
- T015: Create ALB [25m]

**Level 11** (Depends on T015):
- T016: Configure HTTPS listener [20m]

**Level 12** (Depends on T016, T017):
- T018: Initialize workspace [10m]

**Level 13** (Sequential validation):
- T019: Validate configuration [5m]
- T020: Plan infrastructure [15m]
- T021: Apply infrastructure [30m]

**Level 14** (Depends on T021) - **PARALLEL GROUP**:
- T022: Verify EC2 instances [10m] ║
- T023: Verify target health [10m] ║
- T024: Test HTTPS endpoint [10m] ║
- T025: Verify security groups [10m] ║

**Level 15** (Depends on Level 14) - **PARALLEL GROUP**:
- T026: Document deployment [15m] ║
- T027: Create runbook [10m] ║

**Level 16** (Depends on Level 15):
- T028: Final validation [5m]

---

### Parallel Execution Plan

**Phase 1: Setup** (Sequential - 45m)
```bash
# No parallelization possible
T001 → T002 → T003 → T004
```

**Phase 2: Foundation** (Parallel - 60m total, saves 25m)
```bash
# Start T005 first
T005 [20m]

# After T005 completes, start parallel group:
T006 [25m] || T008 [20m] || T009 [15m] || T010 [20m]

# After T006 completes:
T007 [15m]

# After T010 completes:
T011 [20m]
```

**Phase 3: Infrastructure** (Mixed - 90m total, saves 15m)
```bash
T012 [25m]

# Parallel group:
T013 [20m] || T017 [15m]

# Sequential:
T014 [15m] → T015 [25m] → T016 [20m]
```

**Phase 4: Validation** (Parallel - 40m total, saves 30m)
```bash
# Sequential prerequisites:
T018 [10m] → T019 [5m] → T020 [15m] → T021 [30m]

# Parallel testing:
T022 [10m] || T023 [10m] || T024 [10m] || T025 [10m]
```

**Phase 5: Documentation** (Parallel - 15m total, saves 15m)
```bash
T026 [15m] || T027 [10m]
T028 [5m]
```

**Total Optimized Duration**: ~290 minutes (4.83 hours)

---

## 7. File Modification Timeline

### Sequential File Access Pattern

```
Time    Task    File                Action          Lock Required
------  ------  ------------------  --------------  -------------
0:00    T001    (directories)       Create dirs     No
0:15    T002    versions.tf         Create          No
0:25    T003    providers.tf        Create          No
0:35    T004    variables.tf        Create          No
0:45    T005    main.tf             Create          Yes
1:05    T006    main.tf             Append          Yes (wait for T005)
1:30    T007    main.tf             Append          Yes (wait for T006)
1:30    T008    user-data.sh        Create          No (parallel)
1:30    T009    outputs.tf          Create          No (parallel)
1:45    T010    main.tf             Append          Yes (wait for T007)
2:05    T011    main.tf             Append          Yes (wait for T010)
2:25    T012    main.tf             Append          Yes (wait for T011)
2:50    T013    main.tf             Append          Yes (wait for T012)
2:50    T017    terraform.tfvars    Create          No (parallel)
3:10    T014    main.tf             Append          Yes (wait for T013)
3:25    T015    main.tf             Append          Yes (wait for T014)
3:50    T016    main.tf             Append          Yes (wait for T015)
```

**File Contention**:
- `main.tf` is the primary bottleneck (11 sequential modifications)
- All other files can be created in parallel
- Proper ordering is critical to avoid merge conflicts

---

## 8. Risk Analysis

### High-Risk Dependencies

| Dependency | Risk Level | Impact if Failed | Mitigation |
|-----------|-----------|------------------|------------|
| T005 → T006/T010 | HIGH | Blocks certificate AND security groups | Validate VPC exists before T005 |
| T006 → T007 | HIGH | No HTTPS without ACM cert | Test TLS provider before T006 |
| T010 → T011 | HIGH | Security group reference failure | Validate SG ID immediately after T010 |
| T011 → T012 | HIGH | EC2 instances cannot launch | Test AMI availability before T012 |
| T012 → T013-T016 | CRITICAL | No load balancer without instances | Implement retry logic in T012 |
| T021 (Apply) | CRITICAL | Infrastructure doesn't exist | Require successful plan (T020) first |

### Task Failure Recovery

**Retry Strategy**:
- **Terraform Tasks (T018-T021)**: Retry up to 3 times with exponential backoff
- **Validation Tasks (T022-T025)**: Retry up to 5 times (infrastructure may take time to stabilize)
- **Code Tasks (T001-T017)**: No retry (fix and re-run)

**Rollback Points**:
1. After T004: Can discard and restart (no infrastructure created)
2. After T017: Can discard and restart (only code, no cloud resources)
3. After T020: Can review plan before apply (last safe point)
4. After T021: Must run `terraform destroy` to rollback

---

## 9. Effort Estimation

### Task Duration Summary

| Phase | Task Range | Total Time | Avg per Task | Critical Path |
|-------|-----------|------------|--------------|---------------|
| Setup | T001-T004 | 45m | 11.25m | Yes (all tasks) |
| Foundation | T005-T009 | 95m | 19m | Partial (T005-T007) |
| Security | T010-T011 | 40m | 20m | Yes (all tasks) |
| Infrastructure | T012-T017 | 120m | 20m | Partial (T012-T016) |
| Validation | T018-T025 | 115m | 14.4m | Partial (T018-T021) |
| Documentation | T026-T028 | 30m | 10m | No |
| **TOTAL** | **T001-T028** | **445m** | **15.9m** | **285m (64%)** |

### Resource Requirements

**Human Resources**:
- **DevOps Engineer**: T001-T021 (infrastructure implementation)
- **Tester/QA**: T022-T025 (can run in parallel with documentation)
- **Technical Writer**: T026-T028 (can run in parallel with testing)

**Optimal Team Configuration**:
- **Sequential Execution**: 1 DevOps engineer = 7.4 hours
- **Parallel Execution**: 1 DevOps + 1 Tester + 1 Writer = 4.8 hours
- **Efficiency Gain**: 35% time savings with team of 3

---

## 10. Execution Recommendations

### Best Practices

1. **Pre-Flight Checks** (Before T001):
   ```bash
   # Verify AWS credentials
   aws sts get-caller-identity --region ap-southeast-1
   
   # Verify default VPC exists
   aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region ap-southeast-1
   
   # Verify HCP Terraform access
   terraform login
   ```

2. **Checkpoint Validation** (After each phase):
   - Phase 1 (T004): Run `terraform fmt -check` and `terraform validate`
   - Phase 2 (T009): Verify all data sources return expected results
   - Phase 3 (T011): Test security group rules with `aws ec2 describe-security-groups`
   - Phase 4 (T017): Review generated plan for unexpected changes
   - Phase 5 (T025): Full smoke test before documentation

3. **Parallel Execution Commands**:
   ```bash
   # Example: Run T022-T025 in parallel after T021
   (
     ./scripts/verify_ec2.sh &       # T022
     ./scripts/verify_health.sh &     # T023
     ./scripts/verify_https.sh &      # T024
     ./scripts/verify_security.sh &   # T025
     wait
   )
   ```

4. **Progress Tracking**:
   - Use a task board (Jira, GitHub Issues, Trello)
   - Mark blockers immediately when discovered
   - Update estimates based on actual completion times
   - Review critical path after each phase

---

## 11. Monitoring & Observability

### Task Progress Metrics

Track these metrics during execution:

1. **Velocity**: Tasks completed per hour (target: 4-5 tasks/hour)
2. **Blocking Time**: Total time tasks are blocked by dependencies
3. **Rework Rate**: Tasks requiring fixes after initial completion
4. **Critical Path Adherence**: Actual vs estimated duration on critical path

### Success Criteria

- [ ] All 28 tasks complete successfully
- [ ] Total execution time < 6 hours (with parallelization)
- [ ] Zero critical path tasks blocked > 15 minutes
- [ ] Infrastructure deploys on first `terraform apply`
- [ ] All validation tasks pass without errors
- [ ] Documentation complete and accurate

---

## 12. Appendix: Quick Reference

### Task ID Quick Lookup

| ID | Task | Duration | Dependencies | Parallel? |
|----|------|----------|--------------|-----------|
| T001 | Create project structure | 15m | None | No |
| T002 | Initialize Terraform | 10m | T001 | No |
| T003 | Configure providers | 10m | T002 | No |
| T004 | Define variables | 10m | T003 | No |
| T005 | Configure data sources | 20m | T004 | No |
| T006 | Generate TLS certificate | 25m | T005 | Yes (with T008, T009) |
| T007 | Import cert to ACM | 15m | T006 | No |
| T008 | Create user-data script | 20m | T005 | Yes (with T006, T009) |
| T009 | Define outputs | 15m | T005 | Yes (with T006, T008) |
| T010 | Create ALB SG | 20m | T005 | Yes (with T006-T009) |
| T011 | Create EC2 SG | 20m | T010 | No |
| T012 | Create EC2 instances | 25m | T011 | No |
| T013 | Create target group | 20m | T012 | Yes (with T017) |
| T014 | Register instances | 15m | T013 | No |
| T015 | Create ALB | 25m | T007, T014 | No |
| T016 | Configure HTTPS listener | 20m | T015 | No |
| T017 | Create tfvars | 15m | T012 | Yes (with T013-T016) |
| T018 | Init Terraform workspace | 10m | T016, T017 | No |
| T019 | Validate configuration | 5m | T018 | No |
| T020 | Plan infrastructure | 15m | T019 | No |
| T021 | Apply infrastructure | 30m | T020 | No |
| T022 | Verify EC2 instances | 10m | T021 | Yes (with T023-T025) |
| T023 | Verify target health | 10m | T021 | Yes (with T022, T024, T025) |
| T024 | Test HTTPS endpoint | 10m | T021 | Yes (with T022, T023, T025) |
| T025 | Verify security groups | 10m | T021 | Yes (with T022-T024) |
| T026 | Document deployment | 15m | T022-T025 | Yes (with T027) |
| T027 | Create runbook | 10m | T022-T025 | Yes (with T026) |
| T028 | Final validation | 5m | T026, T027 | No |

### Bottleneck Summary

**Top 5 Blocking Tasks**:
1. **T005** (Data sources): Blocks 6 tasks (T006-T011)
2. **T012** (EC2 instances): Blocks 5 tasks (T013-T017)
3. **T021** (Apply): Blocks 4 tasks (T022-T025)
4. **T010** (ALB SG): Blocks 3 tasks (T011, T015, T016)
5. **T006** (TLS cert): Blocks 2 tasks (T007, T015)

**Optimization Focus**: Ensure these 5 tasks complete as quickly as possible to minimize total execution time.

---

## Document Control

**Last Updated**: 2025-02-01  
**Version**: 1.0  
**Approved By**: Pending review  
**Next Review**: After implementation completion  

---

**End of Task Dependency Graph**
