# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note**: This project uses AGENTS.md files for detailed guidance. 

## Primary Reference

Please see the root `./AGENTS.md` in this same directory for the main project documentation and guidance. 

@/workspace/AGENTS.md


## Additional Component-Specific Guidance

For detailed module-specific implementation guides, also check for AGENTS.md files in subdirectories throughout the project

These component-specific AGENTS.md files contain targeted guidance for working with those particular areas of the codebase.

## Updating AGENTS.md Files

When you discover new information that would be helpful for future development work, please:

- **Update existing AGENTS.md files** when you learn implementation details, debugging insights, or architectural patterns specific to that component
- **Create new AGENTS.md files** in relevant directories when working with areas that don't yet have documentation
- **Add valuable insights** such as common pitfalls, debugging techniques, dependency relationships, or implementation patterns

## Important use subagents liberally

When performing any research concurrent subagents can be used for performance and isolation
use subagents whenever you can and clear context between spec-kit phases using /clear

# Final deployment report

Once completed all tasks and Terraform is fully deployed, logs any issues in memory in the feature branch as deployment_log_<timestamp>.log

Important to include the following (table formats are preferred):

### Required Information

- **Architecture Summary**: High-level overview of the deployed infrastructure
- **HCP Terraform Organization**: The organization name used
- **HCP Terraform Project**: The project name used
- **HCP Terraform Workspace**: The workspace name(s) used
- **Private Modules Utilsed** Include all modules and full source address for Terraform module
- **Git Branch**: The feature branch that was created
- **Claude Token Usage**: Total tokens consumed during the session
- **Failed Tool Calls**: Any failed tool calls and remediation attempts made
- **Skills Calls**: Documentation of all skills invoked
- **Subagents**: Total count of subagent calls made with names and amount called

### Critical Items

**Important**: The following must be clearly documented:

- **Workarounds vs Fixes**: What issues were worked around instead of properly fixing. These need to be clearly itemized with explanations of why a workaround was chosen over a fix.
- **Security Reports**: Include all available security reports. Use a separate table for pre-commit reports (terraform_validate, tfsec, checkov, trivy, etc.)
- **Sentinel Policy Advisories**: Document advisory details from Sentinel policy output in workspace runs

This helps build a comprehensive knowledge base for the codebase over time.
