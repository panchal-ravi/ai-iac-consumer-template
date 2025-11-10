---
mode: agent
model: Claude Sonnet 4.5 (copilot)
description: Test harness for executing Speckit workflows non-interactively using subagents. Use when you need to test the complete Speckit pipeline (Phase 0 → Phase 3) or individual phases, validate artifact generation across all commands, automate testing of specification-to-implementation workflows, or verify cross-phase consistency. This skill orchestrates the execution of all Speckit commands in order without user intervention.
---

# GitHub Speckit Tester

A comprehensive test harness for validating the Speckit workflow system by executing all phases non-interactively using subagents. After each phase clear the context using /clear

## Overview

This skill provides automated testing capabilities for the complete Speckit pipeline, executing all commands in sequence from specification to implementation without requiring user interaction.

## Test Scenario
Please read the following file to load the test scenario:
#file: github/test-scenarios/${input:scenario}

## Speckit Workflow Phases

| Phase | Command | Purpose | Inputs | Outputs |
|-------|---------|---------|--------|---------|
| **Phase 0** | `/speckit.specify` | Create feature specifications from requirements | Feature description | `spec.md`, checklist template |
| **Phase 0** | `/speckit.clarify` | Resolve specification ambiguities | Ambiguous `spec.md` | Updated `spec.md` with clarifications |
| **Phase 0** | `/speckit.review-spec` | **[NEW]** Agent-as-a-Judge spec quality evaluation | `spec.md` | Quality score, dimension analysis, improvement recommendations |
| **Phase 0** | `/speckit.checklist` | Validate requirement quality | `spec.md` | `checklists/*.md` (requirements quality tests) |
| **Phase 1** | `/speckit.plan` | Design technical implementation | `spec.md`, `constitution.md` | `plan.md`, `data-model.md`, contracts/ |
| **Phase 1** | `/speckit.tasks` | Generate actionable task list | `plan.md` | `tasks.md` |
| **Phase 2** | `/speckit.analyze` | Validate cross-artifact consistency + Technical quality (dual-pass) | `spec.md`, `plan.md`, `tasks.md` | Analysis report + Technical quality score |
| **Phase 3** | `/speckit.implement` | Execute implementation | `plan.md`, `tasks.md` | Production code |
| **Phase 3** | `/speckit.review-code` | **[NEW]** Agent-as-a-Judge code quality evaluation | `*.tf` files | Security analysis, quality score, recommendations |

## Core Concepts

### Non-Interactive Execution

All Speckit commands must be executed without user intervention:
- Automatic decision-making for clarifications
- Default selections for ambiguous choices
- Automated validation and progression through phases
- Error handling and recovery without user input

### Subagent Orchestration

The test harness uses subagents to:
- Execute each phase independently
- Isolate phase execution for better debugging
- Parallelize independent phases when possible
- Maintain clean execution context per phase

### Artifact Validation

After each phase, validate generated artifacts:
- File existence and completeness
- Content structure and format
- Cross-artifact consistency
- Required sections and data

## Execution Modes

### Full Pipeline Test

Execute all phases sequentially from Phase 0 to Phase 3:
After each phase clear the context using /clear

```
Phase 0: Specification
├── /speckit.specify → spec.md
├── /speckit.review-spec → Quality evaluation (score + recommendations)
├── /speckit.clarify → Updated spec.md (if needed)
└── /speckit.checklist → checklists/*.md

Phase 1: Planning
├── /speckit.plan → plan.md, data-model.md
└── /speckit.tasks → tasks.md

Phase 2: Analysis (Dual-Pass)
└── /speckit.analyze → Consistency report + Technical quality evaluation

Phase 3: Implementation & Validation
├── /speckit.implement → Production code
└── /speckit.review-code → Security analysis + Quality score
```

### Phase-Specific Testing

Execute individual phases for targeted testing:

**Phase 0 Only**: Test specification generation
- Run `/speckit.specify` with test feature description
- Auto-resolve any clarifications
- Validate checklist generation

**Phase 1 Only**: Test planning (requires existing spec)
- Run `/speckit.plan` against existing spec.md
- Run `/speckit.tasks` from generated plan
- Validate task structure

**Phase 2 Only**: Test analysis (requires spec, plan, tasks)
- Run `/speckit.analyze` on existing artifacts
- Validate consistency checks

**Phase 3 Only**: Test implementation (requires plan, tasks)
- Run `/speckit.implement` from existing plan/tasks
- Validate code generation

## Test Harness Usage

### Basic Syntax

To execute the test harness, use the Skill tool:

```
Skill command: "github-speckit-tester"
```

### Test Configuration

The skill accepts configuration to control test execution:

```yaml
test_mode: full | phase0 | phase1 | phase2 | phase3
feature_description: "Your test feature description"
auto_clarify: true | false  # Default: true
cleanup_after: true | false  # Default: false
validation_level: strict | normal | minimal  # Default: normal
enable_judge_evaluation: true | false  # Default: true (NEW)
judge_score_threshold: 7.0 | 8.0  # Min score to pass (NEW)
auto_refine_on_failure: true | false  # Default: false (NEW)
max_refinement_iterations: 3  # Default: 3 (NEW)
```

### Example Test Scenarios

**Scenario 1: Full Pipeline Validation**

```
Test a complete workflow from feature description to code:

1. Feature: "Add user authentication with OAuth2"
2. Execute all phases non-interactively
3. Validate all artifacts
4. Report any inconsistencies
```

**Scenario 2: Specification Quality Test**

```
Test Phase 0 specification generation:

1. Feature: "Create analytics dashboard"
2. Run /speckit.specify
3. Auto-resolve clarifications with defaults
4. Run /speckit.checklist
5. Validate all checklist items pass
```

**Scenario 3: Planning Consistency Test**

```
Test Phase 1 planning from existing spec:

1. Load existing spec.md
2. Run /speckit.plan
3. Run /speckit.tasks
4. Validate tasks align with plan
5. Check task dependencies
```

## Non-Interactive Guidelines

### Clarification Handling

When `/speckit.clarify` presents questions:
- **Auto-select defaults**: Choose option A by default
- **Document choices**: Log all automated decisions
- **Fallback strategy**: If no default, choose most conservative option

Example automated response:
```
Q1: Authentication method?
→ Auto-select: Option A (Standard OAuth2)

Q2: Data retention period?
→ Auto-select: Option A (Industry standard 90 days)

Q3: User roles?
→ Auto-select: Option B (Admin and User only)
```

### Validation Failures

When validation fails:
- **Log the failure**: Capture exact error and context
- **Attempt auto-fix**: Apply common fixes (formatting, missing sections)
- **Re-validate**: Check if auto-fix resolved issue
- **Report if unresolved**: Include failure details in test report

### Error Recovery

When commands fail:
- **Retry once**: Some failures are transient
- **Check prerequisites**: Validate required files exist
- **Log and continue**: Don't halt entire pipeline for non-critical errors
- **Final report**: Include all errors with context

## Artifact Validation Rules

### spec.md Validation

Required elements:
- [ ] Feature name and description
- [ ] User scenarios section
- [ ] Functional requirements
- [ ] Success criteria (measurable, technology-agnostic)
- [ ] Assumptions and dependencies
- [ ] No implementation details
- [ ] No [NEEDS CLARIFICATION] markers remaining

**[NEW] Agent-as-a-Judge Quality Dimensions**:
- [ ] Clarity & Completeness score ≥ 7.0/10
- [ ] Testability & Measurability score ≥ 7.0/10
- [ ] Technology Agnosticism score ≥ 7.0/10
- [ ] Constitution Alignment score ≥ 7.0/10
- [ ] User-Centricity & Value score ≥ 7.0/10
- [ ] Overall Quality Score ≥ 7.0/10

### plan.md Validation

Required elements:
- [ ] Architecture overview
- [ ] Component breakdown
- [ ] Data model reference
- [ ] API contracts (if applicable)
- [ ] Technology stack decisions
- [ ] Implementation phases
- [ ] Risk assessment

### tasks.md Validation

Required elements:
- [ ] Dependency-ordered tasks
- [ ] Clear acceptance criteria per task
- [ ] Estimated complexity/effort
- [ ] Prerequisites identified
- [ ] No circular dependencies
- [ ] Implementation steps detailed

### Cross-Artifact Consistency

Validation checks:
- [ ] All spec requirements map to plan components
- [ ] All plan components have corresponding tasks
- [ ] Task dependencies align with plan architecture
- [ ] Success criteria testable via implementation
- [ ] No orphaned tasks (no parent in plan)
- [ ] No missing implementations (plan without tasks)

**[NEW] Technical Quality Evaluation (Dual-Pass)**:
- [ ] Architecture Soundness score ≥ 7.0/10
- [ ] Security & Compliance Design score ≥ 7.0/10
- [ ] Task Quality & Feasibility score ≥ 7.0/10
- [ ] Testing Strategy score ≥ 7.0/10
- [ ] Documentation & Knowledge Transfer score ≥ 7.0/10
- [ ] Overall Technical Quality Score ≥ 7.0/10

### Production Code Validation (Phase 3)

**[NEW] Agent-as-a-Judge Code Quality**:
- [ ] Module Usage & Architecture score ≥ 8.0/10
- [ ] Security & Compliance score ≥ 8.0/10 (30% weight - critical)
- [ ] Code Quality & Maintainability score ≥ 8.0/10
- [ ] Variable & Output Management score ≥ 8.0/10
- [ ] Testing & Validation score ≥ 8.0/10
- [ ] Constitution & Plan Alignment score ≥ 8.0/10
- [ ] Overall Code Quality Score ≥ 8.0/10
- [ ] Zero CRITICAL (P0) security findings
- [ ] All pre-commit hooks pass (tfsec, trivy, checkov)

## Subagent Execution Strategy

### Sequential Phases

Phases must execute in order:
1. Phase 0 (Specification) → Complete before Phase 1
2. Phase 1 (Planning) → Complete before Phase 2
3. Phase 2 (Analysis) → Complete before Phase 3
4. Phase 3 (Implementation) → Final phase

### Parallel Within Phases

Within Phase 0:
- `/speckit.specify` and `/speckit.clarify` are sequential
- `/speckit.checklist` can run after spec finalization

Within Phase 1:
- `/speckit.plan` must complete first
- `/speckit.tasks` runs after plan completion
- Both can use separate subagents if plan is complete

### Subagent Isolation

Each subagent execution:
- Has clean working directory context
- Accesses generated artifacts via file system
- Reports results back to orchestrator
- Logs execution details for debugging

## Test Report Format

After test execution, generate comprehensive report:

```markdown
# Speckit Test Report

**Test Date**: [Timestamp]
**Test Mode**: [full|phase0|phase1|phase2|phase3]
**Feature**: [Feature description]
**Judge Evaluation**: [Enabled/Disabled]

## Execution Summary

| Phase | Command | Status | Duration | Artifacts | Quality Score |
|-------|---------|--------|----------|-----------|---------------|
| Phase 0 | /speckit.specify | ✓ Pass | 45s | spec.md | - |
| Phase 0 | /speckit.review-spec | ✓ Pass | 30s | Evaluation report | 7.8/10 ✅ |
| Phase 0 | /speckit.clarify | ⊘ Skipped | - | - | - |
| Phase 0 | /speckit.checklist | ✓ Pass | 12s | checklists/requirements.md | - |
| Phase 1 | /speckit.plan | ✓ Pass | 120s | plan.md, data-model.md | - |
| Phase 1 | /speckit.tasks | ✓ Pass | 60s | tasks.md | - |
| Phase 2 | /speckit.analyze | ✓ Pass | 45s | Analysis + Technical quality | 8.2/10 ✅ |
| Phase 3 | /speckit.implement | ✓ Pass | 90s | Production code | - |
| Phase 3 | /speckit.review-code | ✓ Pass | 60s | Security analysis | 8.5/10 ✅ |

## Validation Results

### spec.md (Structural + Judge Evaluation)
- ✓ All required sections present
- ✓ No implementation details
- ✓ Success criteria measurable
- ✓ No [NEEDS CLARIFICATION] markers

**Agent-as-a-Judge Quality Scores**:
- Clarity & Completeness: 8.0/10 ✅
- Testability & Measurability: 7.5/10 ✅
- Technology Agnosticism: 8.5/10 ✅
- Constitution Alignment: 7.0/10 ✅
- User-Centricity & Value: 7.8/10 ✅
- **Overall: 7.8/10** - Production Ready ✅

### plan.md & tasks.md (Technical Quality - Dual Pass)
- ✓ Architecture defined
- ✓ Components identified
- ✓ Technology stack documented
- ✓ Tasks dependency-ordered
- ✓ Clear acceptance criteria

**Technical Quality Evaluation**:
- Architecture Soundness: 8.5/10 ✅
- Security & Compliance Design: 8.0/10 ✅
- Task Quality & Feasibility: 8.0/10 ✅
- Testing Strategy: 7.5/10 ✅
- Documentation & Knowledge Transfer: 8.5/10 ✅
- **Overall: 8.2/10** - Excellent Design ✅

### Production Code (Code Quality Judge)
- ✓ Module-first architecture (private registry)
- ✓ Semantic versioning on all modules
- ✓ No hardcoded credentials
- ✓ Encryption enabled (at rest & in transit)
- ✓ IAM least privilege applied
- ✓ All pre-commit hooks pass

**Code Quality Scores**:
- Module Usage & Architecture: 9.0/10 ✅
- Security & Compliance: 8.5/10 ✅
- Code Quality & Maintainability: 8.0/10 ✅
- Variable & Output Management: 8.5/10 ✅
- Testing & Validation: 8.0/10 ✅
- Constitution & Plan Alignment: 9.0/10 ✅
- **Overall: 8.5/10** - Production Ready ✅

**Security Analysis**:
- ✅ Zero CRITICAL (P0) findings
- ✅ Zero HIGH (P1) vulnerabilities
- ✓ 2 MEDIUM findings (addressed via recommendations)

### Cross-Artifact Consistency
- ✓ All requirements mapped to plan
- ✓ All plan components have tasks
- ✓ Task dependencies valid
- ✓ No orphaned elements

## Errors and Warnings

### Errors (2)
1. **Phase 3 - Implementation**
   - Command: /speckit.implement
   - Error: Missing dependency in tasks.md
   - Context: Task "setup-database" references undefined task "install-orm"

2. **Validation - tasks.md**
   - Issue: Circular dependency detected
   - Tasks: "setup-api" ↔ "configure-auth"

### Warnings (1)
1. **Validation - spec.md**
   - Issue: Unclear success criterion
   - Detail: "System is fast" - not measurable

## Automated Decisions

1. **Clarification Q1**: Authentication method
   - Auto-selected: Option A (OAuth2)
   - Reason: Industry standard default

2. **Clarification Q2**: User role structure
   - Auto-selected: Option B (Simple: Admin/User)
   - Reason: Conservative choice for MVP

## Judge Evaluation Tracking

**Spec Quality Improvement**:
- Iteration 1: 6.5/10 → Auto-refinement applied
- Iteration 2: 7.8/10 ✅ (Δ +1.3) - Threshold met

**Technical Quality Assessment**:
- First evaluation: 8.2/10 ✅ - Excellent design, high confidence

**Code Quality Assessment**:
- First evaluation: 8.5/10 ✅ - Production ready
- Security score: 8.5/10 (30% weight) - No critical issues

**Judge-Human Agreement**:
- Evaluations tracked: 15
- Pearson correlation: 0.83 ✅ (Target: >0.80)
- Average delta: 0.4 points

## Recommendations

1. **Critical**: Resolve circular dependency in tasks.md before implementation
2. **High**: Add missing tasks for 3 orphaned plan components
3. **Medium**: Update spec.md success criteria to be measurable
4. **Low**: Remove [NEEDS CLARIFICATION] marker from spec.md

## Files Generated

- `specs/N-feature-name/spec.md`
- `specs/N-feature-name/plan.md`
- `specs/N-feature-name/tasks.md`
- `specs/N-feature-name/data-model.md`
- `specs/N-feature-name/checklists/requirements.md`
- `specs/N-feature-name/contracts/*.md`

## Test Outcome

**Overall Status**: FAIL (Critical errors in Phase 3)

**Next Steps**:
1. Fix circular dependency in tasks.md
2. Add missing task implementations
3. Re-run Phase 3 after fixes
```

## Best Practices

### Test Design

1. **Use realistic features**: Test with features similar to production use cases
2. **Vary complexity**: Test simple, medium, and complex features
3. **Test edge cases**: Empty descriptions, ambiguous requirements, complex dependencies
4. **Validate incrementally**: Check artifacts after each phase, not just at end

### Non-Interactive Patterns

1. **Default to conservative**: Choose simpler options when auto-selecting
2. **Document all choices**: Log every automated decision
3. **Fail gracefully**: Continue pipeline even if non-critical phases fail
4. **Comprehensive reporting**: Include all details for post-test analysis

### Validation Strategy

1. **Structural validation**: Check file structure and required sections
2. **Content validation**: Verify content quality and completeness
3. **Consistency validation**: Cross-check artifacts for alignment
4. **Semantic validation**: Ensure logical coherence across artifacts

### Error Handling

1. **Categorize errors**: Critical vs. warnings vs. info
2. **Provide context**: Include file locations, line numbers, exact errors
3. **Suggest fixes**: Recommend specific actions to resolve issues
4. **Track resolution**: Mark errors as fixed in subsequent runs

## Advanced Features

### Parallel Phase Testing

For independent validation, run phases in parallel:

```
Execute 3 tests simultaneously:
- Subagent 1: Test Phase 0 (Feature A)
- Subagent 2: Test Phase 1 (Existing spec B)
- Subagent 3: Test Phase 2 (Existing artifacts C)
```

### Regression Testing

Compare test results across runs:
- Track artifact quality over time
- Detect regressions in validation rules
- Monitor command execution performance
- Identify flaky test scenarios

### Custom Validation Rules

Extend validation with project-specific rules:
- Enforce naming conventions
- Check for required dependencies
- Validate against project constitution
- Apply coding standards

## Troubleshooting

### Common Issues

**Issue**: `/speckit.specify` hangs waiting for clarification
**Solution**: Ensure `auto_clarify: true` is set, or provide pre-answered clarifications

**Issue**: `/speckit.plan` fails with "Missing spec.md"
**Solution**: Verify Phase 0 completed successfully, check file paths

**Issue**: Cross-artifact validation fails
**Solution**: Run `/speckit.analyze` separately to get detailed consistency report

**Issue**: Subagent execution times out
**Solution**: Increase timeout threshold, check for infinite loops in commands

### Debug Mode

Enable verbose logging for troubleshooting:
```
debug: true
log_level: verbose
trace_commands: true
capture_subagent_logs: true
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Speckit Workflow Test

on:
  pull_request:
    paths:
      - '.specify/**'
      - '.claude/commands/speckit.*'

jobs:
  test-speckit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Speckit Test Harness
        run: |
          # Execute test harness via Claude Code
          claude-code --skill github-speckit-tester \
            --config test_mode=full \
            --config feature_description="Test feature" \
            --config auto_clarify=true

      - name: Validate Test Report
        run: |
          # Check test report for failures
          if grep -q "Overall Status: FAIL" speckit-test-report.md; then
            echo "Speckit tests failed"
            exit 1
          fi
```

### Pre-commit Hook

Validate Speckit artifacts before commit:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run focused validation on changed specs
changed_specs=$(git diff --cached --name-only | grep "specs/.*\.md$")

if [ -n "$changed_specs" ]; then
  echo "Validating Speckit artifacts..."
  claude-code --skill github-speckit-tester \
    --config test_mode=phase2 \
    --config validation_level=strict
fi
```

## Reference

### Command Execution Order

Full pipeline execution sequence:
1. `/speckit.specify` - Create initial spec
2. `/speckit.review-spec` - **[NEW]** Agent-as-a-Judge quality evaluation (optional but recommended)
3. `/speckit.clarify` - Resolve ambiguities (conditional)
4. `/speckit.checklist` - Validate spec quality
5. `/speckit.plan` - Design implementation
6. `/speckit.tasks` - Generate task list
7. `/speckit.analyze` - Cross-validate artifacts + **[NEW]** Technical quality evaluation (dual-pass)
8. `/speckit.implement` - Execute implementation
9. `/speckit.review-code` - **[NEW]** Agent-as-a-Judge code quality & security evaluation

### File Paths

Standard Speckit directory structure:
```
specs/
├── N-feature-name/
│   ├── spec.md              # Phase 0
│   ├── plan.md              # Phase 1
│   ├── tasks.md             # Phase 1
│   ├── data-model.md        # Phase 1
│   ├── checklists/
│   │   └── requirements.md  # Phase 0
│   ├── contracts/           # Phase 1
│   │   ├── api-*.md
│   │   └── interface-*.md
│   └── evaluations/         # NEW: Agent-as-a-Judge tracking
│       ├── spec-reviews.jsonl
│       ├── code-reviews.jsonl
│       ├── technical-quality.jsonl
│       └── judge-human-correlation.jsonl
```

### Validation Checklist

Comprehensive validation across all phases:

**Specification (Phase 0)**:
- [ ] spec.md exists and is well-formed
- [ ] All mandatory sections present
- [ ] No implementation details
- [ ] Success criteria measurable
- [ ] No [NEEDS CLARIFICATION] markers
- [ ] Checklist generated and validated

**Planning (Phase 1)**:
- [ ] plan.md architecture defined
- [ ] data-model.md entities documented
- [ ] contracts/ interfaces specified
- [ ] tasks.md generated with dependencies
- [ ] All spec requirements covered

**Analysis (Phase 2)**:
- [ ] Cross-artifact consistency validated
- [ ] No orphaned requirements
- [ ] No missing implementations
- [ ] Dependency graph valid
- [ ] Quality metrics met

**Implementation (Phase 3)**:
- [ ] Code generated per tasks.md
- [ ] All tasks completed
- [ ] Tests included
- [ ] Documentation updated

## Examples

### Example 1: Full Pipeline Test

```markdown
**Test**: Complete workflow validation

**Input**:
- Feature: "Add two-factor authentication for user login"
- Mode: full
- Auto-clarify: true

**Expected Flow**:
1. /speckit.specify creates spec.md
2. Auto-resolve any clarifications
3. /speckit.checklist validates spec
4. /speckit.plan creates architecture
5. /speckit.tasks generates task list
6. /speckit.analyze validates consistency
7. /speckit.implement generates code

**Success Criteria**:
- All phases complete without errors
- All validation checks pass
- Generated code compiles/runs
- Test report shows 100% pass rate
```

### Example 2: Specification Quality Test

```markdown
**Test**: Phase 0 specification quality

**Input**:
- Feature: "Create analytics dashboard with custom charts"
- Mode: phase0
- Auto-clarify: true
- Validation: strict

**Expected Flow**:
1. /speckit.specify generates spec.md
2. Auto-resolve clarifications with defaults
3. /speckit.checklist validates quality
4. Strict validation applied

**Success Criteria**:
- spec.md has all required sections
- No implementation details present
- All success criteria measurable
- Checklist 100% pass rate
- No [NEEDS CLARIFICATION] markers
```

### Example 3: Cross-Artifact Consistency Test

```markdown
**Test**: Phase 2 consistency validation

**Input**:
- Mode: phase2
- Existing: spec.md, plan.md, tasks.md
- Validation: strict

**Expected Flow**:
1. Load existing artifacts
2. /speckit.analyze validates consistency
3. Check all cross-references
4. Validate dependency graph

**Success Criteria**:
- All requirements map to plan components
- All plan components have tasks
- No circular dependencies
- No orphaned elements
- Consistency score > 95%
```

## Conclusion

The github-speckit-tester skill provides comprehensive automated testing for the Speckit workflow system. By executing all phases non-interactively using subagents, it enables:

- **Continuous validation** of Speckit commands
- **Regression testing** across workflow changes
- **Quality assurance** for generated artifacts
- **Automated testing** in CI/CD pipelines
- **Consistency verification** across phases

Use this skill to ensure Speckit workflows produce high-quality, consistent artifacts from specification through implementation.
