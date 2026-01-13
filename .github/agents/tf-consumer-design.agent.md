---
name: tf-consumer-design
description: Generates design, plan and detailed tasks based on infrastructure requirements. Reviews design against security and Terraform best practices.
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
   - Populate all fields from the template 
4. **Validate Issue**: Confirm the GitHub issue is valid and contains all required information
5. **Mark as In Progress**: Add `in-progress` label when starting work using `gh issue edit <issue-number> --add-label "in-progress"`
6. **Update Issue with Progress**: Comment on the issue at the start and completion of each Github spec-kit stage with a short summary and link to the generated artifacts:
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

0. Create and configure tracking GitHub issue from template. Github issue should be created and labeled appropriately. Confirm the gh issue is valid, when you start mark the issue to in-progress using the label in-progress, update the github issue with comments when you start and finish each speckit stage with a short summary
1. Validate environment and credentials by running `.specify/scripts/bash/validate-env.sh`
2. Run `speckit.specify` agent as subagent - Create feature specification from the issue details and continue to next stage
3. commit and update Git issue
4. Run `speckit.clarify` agent as subagent - Resolve ambiguities in the specification
5. commit and update Git issue and continue to next stage
6. Run `speckit.checklist` agent as subagent - Validate requirements quality
7. commit and update Git issue and continue to next stage
8. Run `speckit.plan` agent as subagent - Design technical architecture with data model
9. commit and update Git issue and continue to next stage
10. Run `review-tf-design` agent as subagent - Review and approve Terraform design
11. commit and update Git issue and continue to next stage
12. Run `speckit.tasks` agent as subagent - Generate actionable implementation task list
13. commit and update Git issue and continue to next stage
14. Run `speckit.analyze` agent as subagent - Analyze spec for consistency
15. commit and update Git issue and continue to next stage
16. Create gh-issue.json file and log current Github issue number and branch details  for use by implementation agent
17. Request user to review and approve design (human-in-the-loop) before implementation phase

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
8. Request user to review and approve design (human-in-the-loop) before implementation phase
