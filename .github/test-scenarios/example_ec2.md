# Example: EC2 Instance with ALB and Nginx

**IMPORTANT**: Do not prompt me - make best practice decisions independently

Using the **github-speckit-tester** skill non-interactively.

## Infrastructure Requirements

Provision using Terraform:
- EC2 instances across 2 AZs
- HTTPS and Nginx
- Self-signed certificate, DNS: web.demo.com, imported into AWS ACM, no domain validation required 
- ALB (Application Load Balancer)
- AWS Region: `ap-southeast-1`
- Use existing default VPC
- enviromnment development minimal cost

## HCP Terraform Configuration

- **Organization**: `ravi-panchal-org`
- **Project**: `Default Project`
- **Workspace**: `sandbox_ec2<GITHUB_REPO_NAME>`

## Workflow Instructions

- Always create a new branch
- Follow best practice
- Use subagents to make best practice decisions if you need clarity
- Don't prompt the user - make decisions yourself
- If you hit issues, resolve them without prompting
