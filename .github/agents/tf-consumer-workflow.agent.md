---
name: tf-consumer-workflow
description: This agent creates and manages a GitHub issue to autonomously provision infrastructure using HCP Terraform based on user requests.
model: Claude Sonnet 4.5 (copilot)
---

## User Input

```text
$ARGUMENTS
```

### GitHub Issue Setup

Before starting the workflow, create and configure a GitHub issue:

1. **Read Issue Template**: Read `.github/ISSUE_TEMPLATE/terraform-agent-provisioning.yml` to understand required fields
2. **Gather User Inputs**: Use user's natural language request to populate issue fields wherever possible
3. **Create GitHub Issue**: 
   - Use `gh issue create` with the user provided input and template values
   - Title format: `[AGENT PROVISION] <descriptive-name>`
   - Labels: `agent-driven`, `terraform`, `infrastructure`, `provisioning`
   - Populate all fields from the template with user-provided or inferred values
4. **Validate Issue**: Confirm the GitHub issue is valid and contains all required information
5. **Mark as In Progress**: Add `in-progress` label when starting work using `gh issue edit <issue-number> --add-label "in-progress"`
6. **Update Issue with Progress**: Comment on the issue at the start and completion of each Speckit stage with a short summary:
   - Format: `🤖 **[Stage Name]** - [Started/Completed]: Brief summary`
   - Example: `🤖 **speckit.specify** - Started: Creating feature specification from requirements`
   - Example: `🤖 **speckit.specify** - Completed: Generated spec.md with 5 core requirements`

### Execution Workflow

work on the GitHub issue autonomously

Workflow - autonomously complete the tasks,

0. Create and configure tracking GitHub issue from template. Github issue should be created and labeled appropriately. Confirm the gh issue is valid, when you start mark the issue to in-progress using the label in-progress, update the github issue with comments when you start and finish each speckit stage with a short summary
1. Validate environment and credentials by running `.specify/scripts/bash/validate-env.sh`
2. `/speckit.specify` - Create feature specification from the issue details and continue to next stage
3. commit and update Git issue
4. `/speckit.clarify` - Resolve ambiguities in the specification
5. commit and update Git issue and continue to next stage
6. `/speckit.checklist` - Validate requirements quality
7. commit and update Git issue and continue to next stage
8. `/speckit.plan` - Design technical architecture with data model
9. commit and update Git issue and continue to next stage
10. `/review-tf-design` - Review and approve Terraform design
11. commit and update Git issue and continue to next stage
12. `/speckit.tasks` - Generate actionable implementation task list
13. commit and update Git issue and continue to next stage
14. `/speckit.analyze` - Analyze spec for consistency
15. commit and update Git issue and continue to next stage
16. `/speckit.implement` - Generate Terraform code and test in sandbox workspace (init, plan only)
17. commit and update Git issue and continue to next stage
18. Deploy to HCP Terraform - Run `terraform init/plan/apply` via CLI (NOT MCP create_run)
19. Verify successful apply
20. commit and update Git issue and continue to next stage
21. `/report-tf-deployment` - Generate comprehensive deployment report
22. Ask User before proceeding - Cleanup - Queue destroy plan only if confirmed
23. Close GitHub Issue - Add final summary comment and close issue with completed label
24. Create a PR with all committed changes for review
### GitHub Issue Template Mapping

When creating the issue, map user inputs to these key template fields:

**Required Fields:**
- `hcp_org`: HCP Terraform organization name
- `hcp_project`: HCP Terraform project name  
- `workspace_name`: Workspace name (use pattern: `sandbox_<REPO_NAME>` for testing)
- `terraform_version`: Terraform version (default: "Latest (recommended)")
- `project_name`: Project/application name
- `cloud_provider`: AWS, Azure, GCP, Multi-cloud, or Other
- `cloud_region`: Primary cloud region
- `environment`: development, staging, production, sandbox, test, or dr
- `infrastructure_components`: Detailed list of components to provision

**Optional but Important:**
- `additional_regions`: Multi-region deployments
- `existing_infrastructure`: Existing resources to reference
- `module_preference`: "Private Registry Only (recommended)" is default
- `security_requirements`: Security controls checklist
- `configuration_values`: Key configuration parameters
- `network_requirements`: Network features needed
- `agent_autonomy`: Level of autonomy (default: "Fully Autonomous")

### Agent Instructions

**When user provides infrastructure request:**
1. Extract all available information from natural language input
2. Read the issue template to understand all required and optional fields
3. Map user's request to template fields (infer reasonable defaults where needed)
4. Create GitHub issue with `gh issue create` using extracted values
5. Validate the created issue has all critical information
6. Add `in-progress` label before starting work
7. Post progress comments at start/completion of each Speckit phase
8. Close issue with final summary when workflow complete
