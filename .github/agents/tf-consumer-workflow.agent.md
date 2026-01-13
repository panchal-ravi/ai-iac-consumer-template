---
name: tf-consumer-workflow
description: Orchestrates the full workflow from design to implementation for infrastructure provisioning using Terraform. Manages GitHub issues and coordinates subagents for each stage.
model: Claude Sonnet 4.5 (copilot)
---

## User Input

```text
$ARGUMENTS
```

## Execution Workflow
1. Run tf-consumer-design-min agent as subagent to create design and task list
2. Prompt user to review and approve the design (human-in-the-loop)
3. Upon user approval, run tf-consumer-implement agent as subagent to implement the design.