---
name: report-tf-deployment
description: Perform a non-destructive cross-artifact consistency and quality analysis across spec.md, plan.md, and tasks.md after task generation.
tools: Bash, Glob, Grep, Read, Edit, Write, WebFetch, TodoWrite, WebSearch, BashOutput, AskUserQuestion, Skill, SlashCommand, ListMcpResourcesTool, ReadMcpResourceTool, mcp__ide__getDiagnostics, mcp__ide__executeCode, mcp__terraform__get_run_details, mcp__terraform__get_workspace_details, mcp__terraform__list_runs, mcp__terraform__list_terraform_orgs, mcp__terraform__list_terraform_projects, mcp__terraform__list_variable_sets, mcp__terraform__list_workspace_variables, mcp__terraform__list_workspaces, mcp__terraform__search_private_providers, mcp__terraform__search_providers, mcp__terraform__create_run, mcp__terraform__search_private_modules
color: purple
---

# Generate Terraform Deployment Report

Create a comprehensive deployment report using the template at `/workspace/.specify/templates/deployment-report-template.md`.

## Setup

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
REPORT_DIR="/workspace/specs/${BRANCH}/reports"
mkdir -p "${REPORT_DIR}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="${REPORT_DIR}/deployment_report_${TIMESTAMP}.md"
```

## Data Collection

**Architecture**: Read `specs/${BRANCH}/plan.md`, summarize components and diagram

**HCP Terraform**: Org/project/workspace names, workspace URL, configuration details

**Modules**: Parse `*.tf` for sources, distinguish private vs public, include versions and justifications

**Git**: Branch, commit SHA, author, files changed, lines +/-, PR info

**Token Usage**: Run `/context`, extract totals and breakdown

**Tool Calls**: Review conversation for failures, document remediations, categorize by type

**Agents**: List all subagent calls (speckit.*, code-quality-judge, etc.) and skills with purpose/outcome

**Workarounds vs Fixes**: CRITICAL - itemize what was worked around vs fixed, explain why, prioritize future fixes

**Security**: Collect results from:
- `terraform validate`
- `trivy config .`
- `checkov -d .`
- `vault-radar-scan .`
Categorize by severity, document remediation status

**Sentinel**: Query workspace for policy results, document advisories and failures

## Output

1. Read template, replace all `{{PLACEHOLDERS}}` with actual data
2. Use "N/A" if data unavailable - DO NOT GUESS
3. Use tables for structured data, code blocks for logs
4. Write to `${REPORT_FILE}`
5. Display: file path, key metrics (tokens, resources, security score), critical issues, next steps

## Success Criteria

- All required sections populated
- No `{{PLACEHOLDER}}` variables remain
- Workarounds vs fixes clearly distinguished
- Security scans fully documented
- Token/tool statistics accurate
- Proper markdown formatting
