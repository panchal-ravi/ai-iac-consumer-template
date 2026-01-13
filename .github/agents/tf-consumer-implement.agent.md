---
name: tf-consumer-implement
description: This agent creates and manages a GitHub issue to autonomously provision infrastructure using HCP Terraform based on user requests.
model: Claude Sonnet 4.5 (copilot)
---

## User Input

```text
$ARGUMENTS
```

### GitHub Issue Setup

Before starting the workflow, read the GitHub issue and branch details from `specs/{FEATURE}/gh-issue.json` using `gh issue view` command

1. **Validate Issue**: Confirm the GitHub issue is valid and contains all required information
2. **Mark as In Progress**: Add `in-progress` label when starting work using `gh issue edit <issue-number> --add-label "in-progress"`
3. **Update Issue with Progress**: Comment on the issue at the start and completion of each Github spec-kit stage with a short summary and link to the generated artifacts:
   - Format: `🤖 **[Stage Name]** - [Started/Completed]: Brief summary`
   - Example: `🤖 **speckit.specify** - Started: Creating feature specification from requirements`
   - Example: `🤖 **speckit.specify** - Completed: Generated spec.md with 5 core requirements`

### Environment
All files and folders exist in /workspace/ directory. 
All speckit scripts are located in `/workspace/.specify/scripts/bash` directory.

You should not require to change to any other directory.

### Execution Workflow

work on the GitHub issue autonomously

Workflow - autonomously complete the tasks. All speckit stages should be run as subagents. At each stage, commit changes and update the GitHub issue with progress comments. 

0. Read GitHub issue from `gh-issue.json` file and use `gh issue view` command to retrieve the issue details. Confirm the gh issue is valid, when you start mark the issue to in-progress using the label in-progress, update the github issue with comments when you start and finish each speckit stage with a short summary
1. Validate environment and credentials by running `.specify/scripts/bash/validate-env.sh`
2. Run `speckit.implement` agent as subagent - Generate Terraform code and test in sandbox workspace (init, plan only)
3. commit and update Git issue and continue to next stage
4. Deploy to HCP Terraform - Run `terraform init/plan/apply` via CLI (NOT MCP create_run)
5. Verify successful apply
6. commit and update Git issue and continue to next stage
7. Run `report-tf-deployment` agent as subagent - Generate comprehensive deployment report
8. Cleanup - Queue destroy plan only if confirmed
9. Close GitHub Issue - Add final summary comment and close issue with completed label
10. Create a PR with all committed changes for review
