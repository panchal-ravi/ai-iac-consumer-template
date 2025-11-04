# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the github-speckit-tester skill.

## Skill Overview

This is a **Claude Skill repository** for the GitHub Speckit Test Harness - a specialized knowledge base that provides comprehensive documentation and guidance for executing Speckit workflows non-interactively using subagents. This skill acts as an automated test harness for validating the complete specification-to-implementation pipeline.

**Purpose**: Enable Claude to execute the entire Speckit workflow (Phase 0 → Phase 3) without user intervention, validate generated artifacts, ensure cross-artifact consistency, and provide comprehensive test reporting.

## Repository Structure

```
github-speckit-tester/
├── README.md     # Brief skill description
├── SKILL.md      # Main comprehensive guide
└── CLAUDE.md     # This file - guidance for Claude Code
```

## Core Skill Concepts

### Non-Interactive Execution

**Critical Understanding**: This skill must execute ALL Speckit commands without requiring user input:

1. **Auto-Clarification**: When `/speckit.clarify` presents questions:
   - Default to Option A unless context suggests otherwise
   - Document every automated decision
   - Use conservative choices (simpler over complex)
   - Never halt execution waiting for user input

2. **Error Recovery**: When commands fail:
   - Retry once for transient failures
   - Log detailed error context
   - Continue pipeline for non-critical errors
   - Generate comprehensive failure report

3. **Validation Automation**: After each phase:
   - Check artifact existence
   - Validate content structure
   - Cross-reference with previous artifacts
   - Document any issues found

### Subagent Orchestration Strategy

**Important**: Use the Task tool with subagent_type="general-purpose" for each phase:

1. **Sequential Phase Execution**:
   - Phase 0 (Specification) → MUST complete before Phase 1
   - Phase 1 (Planning) → MUST complete before Phase 2
   - Phase 2 (Analysis) → MUST complete before Phase 3
   - Phase 3 (Implementation) → Final phase

2. **Parallel Within Phases** (when safe):
   ```
   Phase 0:
   - /speckit.specify (first)
   - /speckit.clarify (second, if needed)
   - /speckit.checklist (third, after spec finalized)

   Phase 1:
   - /speckit.plan (first)
   - /speckit.tasks (second, after plan complete)
   ```

3. **Subagent Isolation**:
   - Each subagent has clean context
   - Artifacts passed via file system
   - Results reported back to orchestrator
   - No shared state between subagents

### Artifact Validation Rules

**Critical Validation Points**:

**After /speckit.specify**:
```
✓ spec.md exists
✓ Contains all mandatory sections
✓ No implementation details (frameworks, languages, APIs)
✓ Success criteria are measurable and technology-agnostic
✓ User scenarios defined
✗ [NEEDS CLARIFICATION] markers present → Trigger /speckit.clarify
```

**After /speckit.clarify**:
```
✓ All [NEEDS CLARIFICATION] markers resolved
✓ Spec updated with clarifications
✓ Still no implementation details
```

**After /speckit.plan**:
```
✓ plan.md exists
✓ Architecture overview present
✓ Component breakdown defined
✓ Technology stack documented (NOW implementation details ARE expected)
✓ data-model.md created (if data involved)
✓ contracts/ directory created (if APIs involved)
```

**After /speckit.tasks**:
```
✓ tasks.md exists
✓ Tasks are dependency-ordered
✓ No circular dependencies
✓ Each task has clear acceptance criteria
✓ Tasks map back to plan components
```

**After /speckit.analyze**:
```
✓ Consistency report generated
✓ All spec requirements map to plan
✓ All plan components have tasks
✓ No orphaned elements
✓ Dependency graph is valid
```

## Execution Flow

### Full Pipeline Execution

When user invokes this skill, execute this flow:

```
1. PREPARATION
   ├── Parse test configuration
   ├── Validate prerequisites
   └── Initialize test report

2. PHASE 0: SPECIFICATION
   ├── Subagent 1: Execute /speckit.specify
   │   ├── Input: Feature description
   │   ├── Output: spec.md
   │   └── Validate: Structure, completeness
   ├── Subagent 2: Execute /speckit.clarify (conditional)
   │   ├── Input: spec.md with [NEEDS CLARIFICATION]
   │   ├── Auto-select defaults
   │   ├── Output: Updated spec.md
   │   └── Validate: No markers remain
   └── Subagent 3: Execute /speckit.checklist
       ├── Input: Finalized spec.md
       ├── Output: checklists/requirements.md
       └── Validate: All checks pass

3. PHASE 1: PLANNING
   ├── Subagent 4: Execute /speckit.plan
   │   ├── Input: spec.md, constitution.md
   │   ├── Output: plan.md, data-model.md, contracts/
   │   └── Validate: Architecture completeness
   └── Subagent 5: Execute /speckit.tasks
       ├── Input: plan.md
       ├── Output: tasks.md
       └── Validate: Dependency order, no cycles

4. PHASE 2: ANALYSIS
   └── Subagent 6: Execute /speckit.analyze
       ├── Input: spec.md, plan.md, tasks.md
       ├── Output: Analysis report
       └── Validate: Consistency metrics

5. PHASE 3: IMPLEMENTATION
   └── Subagent 7: Execute /speckit.implement
       ├── Input: plan.md, tasks.md
       ├── Output: Production code
       └── Validate: Code completeness, tests

6. REPORTING
   ├── Aggregate all results
   ├── Generate comprehensive test report
   ├── Highlight errors and warnings
   └── Provide recommendations
```

### Error Handling Strategy

**Non-Critical Errors** (log and continue):
- Formatting issues in artifacts
- Missing optional sections
- Warning-level validation failures

**Critical Errors** (log and halt phase):
- Command execution failures
- Missing required artifacts
- Circular dependencies in tasks
- Validation failures with no auto-fix

**Recovery Actions**:
1. **Retry**: Attempt command once more
2. **Auto-fix**: Apply common fixes (formatting, missing sections)
3. **Log and continue**: For non-blocking issues
4. **Halt and report**: For critical failures

## Auto-Clarification Logic

When `/speckit.clarify` presents questions, use this decision tree:

```
For each question:
├── Does context suggest specific answer?
│   ├── Yes → Select that answer
│   └── No → Continue
├── Is Option A most conservative/simple?
│   ├── Yes → Select Option A
│   └── No → Continue
├── Is there an industry standard default?
│   ├── Yes → Select that option
│   └── No → Select Option A (fallback)
└── Document decision in test report
```

**Example Automated Decisions**:

```markdown
Q1: Authentication method for user login?
Options:
  A. OAuth2 (industry standard)
  B. Custom JWT
  C. Session-based

Decision: A (OAuth2)
Reason: Industry standard, most secure, conservative choice

Q2: Data retention period?
Options:
  A. 30 days
  B. 90 days (industry standard)
  C. 1 year

Decision: B (90 days)
Reason: Industry standard for most applications

Q3: User role complexity?
Options:
  A. Simple (Admin/User only)
  B. Medium (Admin/Editor/Viewer)
  C. Complex (Custom roles with permissions)

Decision: A (Simple)
Reason: Conservative choice, can expand later if needed
```

## Test Report Generation

After full pipeline execution, generate this report structure:

```markdown
# Speckit Test Report

**Generated**: [ISO 8601 timestamp]
**Test Mode**: [full|phase0|phase1|phase2|phase3]
**Feature**: "[Feature description]"
**Branch**: [N-feature-name]

## Executive Summary

**Overall Status**: [PASS|FAIL|PARTIAL]
**Total Duration**: [MM:SS]
**Phases Completed**: [X/7]
**Critical Errors**: [N]
**Warnings**: [N]

## Phase Results

[Table with each phase status]

## Artifacts Generated

[List all files with validation status]

## Validation Results

[Detailed validation for each artifact]

## Automated Decisions

[All auto-clarification choices]

## Errors & Warnings

[Detailed error log with context]

## Recommendations

[Prioritized action items]

## Next Steps

[What to do based on test outcome]
```

## Key Differences from User-Interactive Execution

Users manually executing Speckit commands may:
- Read clarification questions and choose thoughtfully
- Review artifacts between phases
- Fix issues before proceeding
- Make complex tradeoff decisions

**This skill must**:
- Auto-select clarifications without user input
- Validate artifacts programmatically
- Auto-fix common issues when possible
- Make conservative default decisions

## Common Pitfalls and Solutions

### Pitfall 1: Clarification Deadlock

**Problem**: `/speckit.clarify` waits for user input indefinitely

**Solution**:
```
- Set timeout for clarification command
- If timeout reached, auto-select all Option A
- Document as "Default selections due to timeout"
- Log as warning in test report
```

### Pitfall 2: Missing Prerequisites

**Problem**: Phase 1 fails because spec.md doesn't exist

**Solution**:
```
- Before each phase, verify required artifacts exist
- Check file paths are correct
- Validate file content is not empty
- Halt with clear error if prerequisites missing
```

### Pitfall 3: Circular Dependencies

**Problem**: tasks.md contains circular dependencies

**Solution**:
```
- Detect cycles in dependency graph
- Log specific tasks involved
- Mark as critical error
- Do NOT proceed to Phase 3
- Recommend manual intervention
```

### Pitfall 4: Validation Too Strict

**Problem**: Minor formatting issues fail validation

**Solution**:
```
- Categorize validation issues by severity:
  - Critical: Missing required content
  - Warning: Formatting issues
  - Info: Style suggestions
- Only halt on critical issues
- Auto-fix warnings when possible
```

## Integration Points

### With Speckit Commands

This skill invokes standard Speckit slash commands:
- Use SlashCommand tool for execution
- Capture command output
- Parse results for validation
- Extract generated file paths

### With Git

This skill should NOT:
- Create commits (testing only)
- Push branches (testing only)
- Modify git history

This skill SHOULD:
- Check current branch
- Verify clean working directory
- Read generated files from branch

### With File System

Artifact locations:
```
specs/
└── N-feature-name/
    ├── spec.md
    ├── plan.md
    ├── tasks.md
    ├── data-model.md
    ├── checklists/
    │   └── requirements.md
    └── contracts/
        └── *.md
```

## Performance Considerations

### Execution Time

Expected durations (approximate):
- Phase 0: 1-2 minutes total
  - /speckit.specify: 30-60s
  - /speckit.clarify: 15-30s (if needed)
  - /speckit.checklist: 10-15s
- Phase 1: 2-3 minutes total
  - /speckit.plan: 90-120s
  - /speckit.tasks: 45-60s
- Phase 2: 30-45 seconds
  - /speckit.analyze: 30-45s
- Phase 3: 3-5 minutes
  - /speckit.implement: 180-300s

**Total pipeline**: 7-11 minutes for typical feature

### Optimization Strategies

1. **Parallel execution** (when safe):
   - Run validation checks concurrently
   - Execute independent analyses in parallel

2. **Caching**:
   - Reuse validated artifacts from previous runs
   - Skip phases if artifacts unchanged

3. **Incremental testing**:
   - Test only changed phases
   - Validate only affected artifacts

## Testing Best Practices

### Test Feature Selection

**Good test features** (realistic, representative):
- "Add user authentication with OAuth2"
- "Create analytics dashboard with charts"
- "Implement payment processing integration"

**Poor test features** (too vague or trivial):
- "Make it better"
- "Add a button"
- "Fix the bug"

### Validation Levels

**Strict** (recommended for CI/CD):
- All checks must pass
- No warnings tolerated
- Perfect cross-artifact consistency

**Normal** (recommended for development):
- Critical checks must pass
- Warnings logged but allowed
- High consistency threshold (>90%)

**Minimal** (recommended for quick checks):
- Basic structure validation only
- Warnings and info ignored
- Consistency not checked

## Troubleshooting Guide

### Debug Mode

Enable verbose logging:
```
Set environment:
  DEBUG=true
  LOG_LEVEL=verbose
  TRACE_SUBAGENTS=true

Output includes:
  - Subagent execution logs
  - Command outputs
  - Validation details
  - Timing information
```

### Common Error Messages

**"spec.md not found"**
```
Cause: Phase 0 didn't complete successfully
Fix: Check /speckit.specify execution logs
Verify: Branch was created and switched
```

**"Circular dependency detected"**
```
Cause: tasks.md has cycle in dependency graph
Fix: Review tasks.md manually
Identify: Specific tasks in cycle
Break: Remove or reorder dependencies
```

**"Validation failed: Missing success criteria"**
```
Cause: spec.md doesn't have measurable success criteria
Fix: Add quantitative success metrics
Example: "Users complete checkout in <3 minutes"
```

## Advanced Usage

### Custom Validation Rules

Extend validation with project-specific rules:

```markdown
Additional checks:
- Naming conventions (PascalCase for components)
- Required dependencies (React, TypeScript)
- Architecture patterns (MVC, microservices)
- Security requirements (HTTPS, auth)
```

### Regression Testing

Track metrics across runs:
```
Metrics to monitor:
- Artifact generation time
- Validation pass rate
- Consistency scores
- Error frequency
- Auto-fix success rate
```

### CI/CD Integration

Recommended GitHub Actions workflow:

```yaml
- name: Test Speckit Pipeline
  run: |
    claude-code \
      --skill github-speckit-tester \
      --config test_mode=full \
      --config feature_description="${{ matrix.feature }}" \
      --config auto_clarify=true \
      --config validation_level=strict
```

## Conclusion

This skill provides comprehensive automated testing for the Speckit workflow system. When using this skill:

1. **Trust automation**: Let the skill make default decisions
2. **Review reports**: Check test reports for issues
3. **Iterate**: Use failures to improve Speckit commands
4. **Monitor**: Track quality metrics over time

The goal is to ensure Speckit workflows produce consistent, high-quality artifacts from specification through implementation, with minimal human intervention required during testing.
