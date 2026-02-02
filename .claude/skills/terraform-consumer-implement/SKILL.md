---
name: terraform-consumer-implement
description: Implements infrastructure provisioning based on approved design and tasks. Executes Terraform plans and applies changes while ensuring compliance with security and best practices.

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
For each task use concurrent subagents to speed up the process. 
Allocate subtask efficiently, some tasks like writing a file should only be created once, I will breakdown tasks to you.

0. Read GitHub issue from `gh-issue.json` file and use `gh issue view` command to retrieve the issue details. Confirm the gh issue is valid, when you start mark the issue to in-progress using the label in-progress, update the github issue with comments when you start and finish each speckit stage with a short summary
1. Validate environment and credentials by running `.specify/scripts/bash/validate-env.sh`
2. Use 2 concurrent subagents `speckit.implement` - Generate Terraform code and test in sandbox workspace (init, plan only)
3. commit and update Git issue and continue to next stage
4. Use 2 concurrent subagents `code-quality-judge` - Evaluate generated Terraform code quality
5. commit and update Git issue and continue to next stage
6. Deploy to HCP Terraform - Run `terraform init/plan/apply` via CLI (NOT MCP create_run)
7. Verify successful apply
8. commit and update Git issue and continue to next stage
9. Use 2 concurrent subagents `report-tf-deployment` - Generate comprehensive deployment report
10. Cleanup - Queue destroy plan only if confirmed
11. Create a PR linked to this GH issue with all committed changes for review.