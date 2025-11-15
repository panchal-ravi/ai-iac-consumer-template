---
name: review-tf-design
description: Comprehensive review of spec artifacts and AWS infrastructure security using specialized subagents
---

# Terraform Design Review Command

This command orchestrates a comprehensive multi-agent review of specification artifacts and AWS infrastructure security configurations.

## Overview

The review process validates:
1. **Specification Quality** - Requirements clarity, testability, and completeness
2. **Plan Quality** - Technical design and architecture decisions
3. **AWS Security** - Infrastructure security best practices and compliance (based on plan.md)
4. **Terraform Best Practices** - Alignment with Terraform style guide and HashiCorp standards (plan review)

## Prerequisites

Before running this review, ensure:

- [ ] `/speckit.specify` has been completed (spec.md exists)
- [ ] `/speckit.plan` has been completed (plan.md exists)
- [ ] AWS resources are defined in the plan (for security review)

**Workflow Position**: This review runs **after `/speckit.plan`** and **before `/speckit.tasks`**.

**Purpose**: Validates specification quality and architectural design decisions **before** breaking down into implementation tasks.

**Note**: No Terraform code exists at this stage - we're reviewing design documents only. For post-implementation code reviews (after `/speckit.implement`), use the `code-quality-judge` subagent.

## Review Execution

This command runs **3 concurrent reviews** for performance and isolation:

### 1. Specification Quality Review (spec-quality-judge)

**Purpose**: Evaluate the quality of the feature specification

**Subagent**: `spec-quality-judge`

**Evaluates**:
- Clarity & Completeness (25% weight)
- Testability & Measurability (20% weight)
- Technology Agnosticism (20% weight)
- Constitution Alignment (20% weight)
- User-Centricity & Value (15% weight)

**Quality Gate**: Score ≥ 7.0/10 for production readiness

**Output**:
- Detailed quality report with dimension scores
- Prioritized improvement roadmap (P0/P1/P2/P3)
- Specific file:line references for all issues
- Before/after examples for recommended fixes

### 2. AWS Security Review (aws-security-advisor)

**Purpose**: Security assessment of AWS infrastructure configurations

**Subagent**: `aws-security-advisor`

**Evaluates**:
- Identity and Access Management (IAM) policies
- Data Protection (encryption, key management)
- Network Security (security groups, VPC configuration)
- Logging and Monitoring (CloudTrail, VPC Flow Logs)
- Resilience (backup, disaster recovery)
- Compliance (CIS, NIST, SOC 2)

**Risk Ratings**:
- **Critical**: Immediate vulnerabilities requiring immediate fix
- **High**: Significant security gaps
- **Medium**: Security improvements
- **Low**: Hardening opportunities

**Output**:
- Risk-rated findings with justifications
- Authoritative citations (AWS Well-Architected Framework, CIS Benchmark, etc.)
- Code examples for remediation
- Effort estimates for fixes

## Execution Workflow

### Step 1: Validate Prerequisites

```bash
.specify/scripts/bash/check-prerequisites.sh --json --require-spec
```

Parse JSON to confirm:
- `FEATURE_DIR` is set
- `spec.md` exists
- `plan.md` exists

### Step 2: Launch Concurrent Reviews

**Important**: Use a single message with 3 tool calls for parallel execution (2x Task + 1x Skill).

#### Step 2a. Spec Quality Review

```
Use Task tool with:
- subagent_type: "spec-quality-judge"
- description: "Evaluate specification quality"
- model: "sonnet"
- prompt: "You are the spec-quality-judge agent defined in .claude/agents/spec-quality-judge.md.
           Evaluate the specification at the current feature directory using the agent-as-a-judge pattern.
           Provide scored feedback across five dimensions:
           1. Clarity & Completeness (25%)
           2. Testability & Measurability (20%)
           3. Technology Agnosticism (20%)
           4. Constitution Alignment (20%)
           5. User-Centricity & Value (15%)

           Generate a comprehensive evaluation report with:
           - Overall quality score (weighted average)
           - Dimension-by-dimension analysis
           - Prioritized improvement roadmap
           - Specific file:line references
           - Before/after examples for fixes

           If score < 7.0, offer iterative refinement options.

           Save evaluation to specs/[FEATURE_BRANCH]/evaluations/spec-reviews.jsonl"
```

#### Step 2b. AWS Security Review

```
Use Task tool with:
- subagent_type: "aws-security-advisor"
- description: "AWS security review"
- model: "sonnet"
- prompt: "You are the aws-security-advisor agent defined in .claude/agents/aws-security-advisor.md.

           Review the Terraform/AWS infrastructure plan in the current feature directory.

           Context:
           - Read plan.md to understand the AWS resources being deployed
           - If Terraform code exists, review .tf files for security issues
           - Focus on resources defined in the specification

           Perform comprehensive security assessment across:
           1. Identity and Access Management (IAM) - overly permissive policies
           2. Data Protection - encryption at rest/transit, secret handling
           3. Network Security - security groups, VPC config, public exposure
           4. Logging and Monitoring - CloudTrail, VPC Flow Logs, alerting
           5. Resilience - backup, disaster recovery, redundancy
           6. Compliance - CIS, NIST, applicable regulatory requirements

           For EVERY finding you MUST provide:
           - Risk Rating: [Critical|High|Medium|Low] with justification
           - Finding: Clear description of security issue
           - Impact: Potential consequences if exploited
           - Recommendation: Specific remediation steps
           - Code Example: Corrected configuration
           - Source: Citation with URL to AWS docs, Well-Architected Framework, or compliance standard
           - Effort: [Low|Medium|High] remediation estimate

           Use MCP tools (aws___search_documentation, aws___read_documentation) to:
           - Verify current AWS security best practices
           - Find authoritative citation sources
           - Reference specific Well-Architected Framework sections

           Prioritize findings by risk rating (Critical > High > Medium > Low).

           Generate security assessment report in markdown format with:
           - Executive summary of risk posture
           - Critical findings requiring immediate attention
           - High/Medium/Low findings organized by security area
           - Compliance gaps identified
           - Remediation roadmap with effort estimates

           Save report to specs/[FEATURE_BRANCH]/evaluations/aws-security-review.md"
```

#### Step 2c. Terraform Best Practices Review

```
Use Skill tool with:
- skill: "terraform-style-guide"

Follow up with specific prompt:
"Review the Terraform design plan in plan.md against Terraform best practices and the HashiCorp Style Guide.

**Context**: No Terraform code exists yet - this is a design review to ensure the planned architecture follows best practices.

Evaluate the plan for:

1. **Module Strategy**:
   - Are modules being used appropriately?
   - Are module sources properly versioned?
   - Is the module-first approach being followed?

2. **Variable Design**:
   - Are variable naming conventions clear (snake_case)?
   - Are variable descriptions, types, and validation rules planned?
   - Are sensitive variables properly identified?

3. **File Organization**:
   - Does the plan indicate proper file separation (main.tf, variables.tf, outputs.tf, etc.)?
   - Are locals being used appropriately for DRY principles?

4. **Output Strategy**:
   - Are important resource attributes planned as outputs?
   - Are sensitive outputs properly marked?
   - Do output names follow conventions?

5. **Provider Configuration**:
   - Are provider version constraints specified?
   - Are required providers documented?

6. **State Management**:
   - Is the backend configuration approach sound?
   - Are workspace naming conventions followed?

7. **Constitution Alignment**:
   - Does the plan follow project constitution principles?
   - Are security-first patterns evident?
   - Is ephemeral testing mentioned?

For each finding provide:
- Section/area of concern in plan.md
- Issue description
- Best practice recommendation
- Priority: [High|Medium|Low]

Generate a Terraform best practices review report in markdown format.

Save report to specs/[FEATURE_BRANCH]/evaluations/terraform-best-practices-review.md"
```

### Step 3: Aggregate Results

After all reviews complete:

1. **Collect Reports**:
   - Spec quality score and findings
   - AWS security risk ratings and recommendations (from plan analysis)
   - Terraform best practices findings (from plan review)

2. **Identify Blocking Issues**:
   - P0 specification issues (score < 7.0)
   - Critical/High AWS security risks in planned architecture
   - High priority Terraform best practice violations

3. **Generate Consolidated Report**:

```markdown
# Terraform Design Review Summary

**Feature**: [Feature name]
**Reviewed**: [ISO-8601 timestamp]
**Reviewers**: spec-quality-judge, speckit.analyze, aws-security-advisor

---

## Review Status

| Review Area | Status | Score/Rating | Blockers |
|-------------|--------|--------------|----------|
| Specification Quality | [✅/⚠️/❌] | X.X/10 | X issues |
| AWS Security (Plan) | [✅/⚠️/❌] | X Critical, X High | X issues |
| Terraform Best Practices (Plan) | [✅/⚠️/❌] | X High, X Medium | X issues |

**Overall Gate Status**: [✅ PASS | ⚠️ REVIEW REQUIRED | ❌ BLOCKED]

---

## Critical Actions Required

### P0 - Must Fix Before Implementation

1. **[Category]** [Issue description] ([source report])
   - Action: [Specific remediation]
   - Owner: [spec/plan/tasks/code]

[List all blocking issues from all three reviews]

---

## Detailed Review Findings

### 1. Specification Quality Review

**Score**: X.X/10 - [Production Ready | Refinement Recommended | Rework Required]

**Top Strengths**:
- [Strength 1]
- [Strength 2]
- [Strength 3]

**Priority Improvements**:
- **[P0/P1/P2]** [Issue with file:line reference]

**Full Report**: [Link to spec-reviews.jsonl or evaluation report]

---

### 2. AWS Security Review

**Risk Summary**:
- Critical Risks: X
- High Risks: X
- Medium Risks: X
- Low Risks: X

**Critical Security Findings**:

#### [Issue Title] - CRITICAL
- **Impact**: [Security impact]
- **Recommendation**: [Remediation]
- **Source**: [AWS Well-Architected citation]
- **Effort**: [Low/Medium/High]

**Full Report**: [Link to aws-security-review.md]

---

### 3. Terraform Best Practices Review (Plan)

**Status**: [✅ Aligned | ⚠️ Issues Found | ❌ Major Gaps]

**Best Practice Findings**:
- High Priority Issues: X
- Medium Priority Issues: X
- Low Priority Issues: X

**Top Findings**:

#### [Issue Title] - HIGH
- **Plan Section**: [Section of plan.md]
- **Issue**: [Description]
- **Recommendation**: [Best practice guidance]

**Full Report**: [Link to terraform-best-practices-review.md]

---

## Remediation Roadmap

### Phase 1: Block Removal (Required)
- [ ] [P0 spec issue] - Estimated: [time]
- [ ] [CRITICAL security finding] - Estimated: [effort]
- [ ] [HIGH Terraform best practice violation] - Estimated: [time]

### Phase 2: Quality Improvements (Recommended)
- [ ] [P1 spec issue]
- [ ] [HIGH security finding]
- [ ] [MEDIUM Terraform best practice issue]

### Phase 3: Enhancements (Optional)
- [ ] [P2/P3 improvements]
- [ ] [MEDIUM/LOW findings]

---

## Next Steps

**If All Reviews Pass (Score ≥ 7.0, No Critical Issues)**:
✅ Design is ready for implementation
- Run `/speckit.implement` to generate Terraform code
- Apply security recommendations during implementation

**If Reviews Have Blockers**:
❌ Address critical issues before proceeding
1. Fix all P0 specification issues
2. Remediate all CRITICAL security findings
3. Resolve CRITICAL consistency gaps
4. Re-run `/review-tf-design` to validate fixes

**If Reviews Need Improvement**:
⚠️ Refinement recommended but not blocking
1. Address P1 spec issues and HIGH security findings
2. Consider running spec-quality-judge in iterative mode
3. Update plan.md or tasks.md based on consistency findings
4. Proceed to implementation with caution

---

## Evaluation Artifacts

All review outputs are saved to:

```
specs/[FEATURE]/evaluations/
├── spec-reviews.jsonl                     # Spec quality evaluation history
├── aws-security-review.md                 # Security assessment report (plan-based)
├── terraform-best-practices-review.md     # Terraform best practices review (plan-based)
└── design-review-summary.md               # This consolidated report
```

---

## Judge Calibration

**Spec Quality Judge**: Targeting >0.80 Pearson correlation with human evaluation
**Security Advisor**: Risk ratings calibrated to AWS Well-Architected Framework severity levels

---

## Questions or Concerns?

If any findings are unclear or recommendations seem impractical:
1. Review the detailed reports linked above
2. Ask clarifying questions about specific findings
3. Discuss trade-offs between security and operational requirements
4. Request alternative remediation approaches
```

### Step 4: Provide Recommendations

Based on aggregate results:

1. **All Pass** (Spec ≥7.0, No Critical Issues):
   - Clear to proceed to `/speckit.implement`
   - Note any P1/P2 improvements to address during implementation

2. **Blockers Present**:
   - List specific actions to unblock
   - Offer to auto-fix P0 issues if user approves
   - Recommend re-running review after fixes

3. **Needs Improvement**:
   - Explain impact of proceeding vs. fixing
   - Suggest iterative refinement workflow
   - Allow user to decide path forward

## Usage Example

```bash
# User invokes the review command
User: /review-tf-design

# Claude validates prerequisites
Claude: Checking prerequisites... ✅ spec.md, plan.md found

# Claude launches 3 concurrent reviews
Claude: Launching concurrent reviews:
  1. Spec Quality Review (spec-quality-judge)
  2. AWS Security Review (aws-security-advisor)
  3. Terraform Best Practices Review (terraform-style-guide)

# After reviews complete, Claude aggregates and presents consolidated report
Claude: [Consolidated Design Review Summary with status, findings, and recommendations]

# Claude provides clear next steps based on results
Claude: ✅ All reviews passed! Ready to proceed to /speckit.implement
```

## Implementation Notes

When implementing this command in the main agent:

1. **Always run reviews in parallel** - Use a single message with 3 tool calls (2x Task + 1x Skill)
2. **Review plan documents** - Focus on spec.md and plan.md, not code (code doesn't exist yet)
3. **Clear context between phases** - Reviews should be isolated from specification generation
4. **Save all outputs** - Store reviews in `specs/[FEATURE_BRANCH]/evaluations/` for audit trail
5. **Aggregate objectively** - Don't override subagent findings, present them faithfully
6. **Provide clear gates** - Make blocking vs. non-blocking issues obvious
7. **Enable iteration** - Allow users to fix and re-review
8. **Use appropriate tools** - Task for subagents, Skill for terraform-style-guide

## Benefits

- **Comprehensive Coverage**: Three specialized reviewers with distinct expertise
- **Objective Evaluation**: Agent-as-a-judge pattern removes bias
- **Parallel Execution**: Fast review through concurrent subagents
- **Actionable Output**: Specific file:line references and code examples
- **Quality Gates**: Clear criteria for proceeding to implementation
- **Audit Trail**: All reviews logged for tracking and correlation analysis
- **Security-First**: Mandatory risk ratings and authoritative citations

## Customization

To adapt this review for different infrastructure types:

- **GCP/Azure**: Replace `aws-security-advisor` with GCP/Azure security subagent
- **Non-IaC Projects**: Skip security review, add domain-specific reviewers
- **Stricter Gates**: Increase score thresholds (e.g., 8.0 instead of 7.0)
- **Additional Reviews**: Add code-style, performance, or cost-optimization subagents

---

$ARGUMENTS