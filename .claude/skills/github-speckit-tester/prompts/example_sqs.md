# Example: SQS with Lambda and SNS

Using the **github-speckit-tester** skill non-interactively.

## Infrastructure Requirements

Provision using Terraform:
- SQS queue with dead letter queue
- Lambda function triggered by SQS messages
- SNS topic for notifications
- CloudWatch alarms
- AWS Region: `ap-southeast-2`
- Environment: Development (minimal cost)
- Use existing default VPC

## HCP Terraform Configuration

- **Organization**: `hashi-demos-apj`
- **Project**: `sandbox`
- **Workspace**: `sandbox_sqs<GITHUB_REPO_NAME>`

## Workflow Instructions

- Always create a new branch
- Follow best practice
- Use subagents to make best practice decisions if you need clarity
- Don't prompt the user - make decisions yourself
- If you hit issues, resolve them without prompting

**IMPORTANT** - Do not prompt me, make best practice decisions independently
