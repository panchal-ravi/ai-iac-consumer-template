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

Once completed all tasks and Terraform is fully deployed, logs any issues in memory in the feature branch as deployment_log_<timestamp>.log
This helps build a comprehensive knowledge base for the codebase over time.
