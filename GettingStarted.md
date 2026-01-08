# AI IaC Consumer Template

A prescriptive agent workflow template for AI-assisted Infrastructure as Code development, powered by **Claude Code** and **HCP Terraform**.

## Overview

This template provides an opinionated, end-to-end workflow for generating, validating, and deploying Terraform infrastructure using AI agents. It leverages the [**GitHub Spec Kit**](https://github.com/github/spec-kit) methodology - a structured approach to specification-driven development that guides AI agents through:

1. **Specification** - Defining infrastructure requirements in natural language
2. **Planning** - Generating detailed implementation plans with architecture decisions
3. **Task Generation** - Breaking down plans into actionable, dependency-ordered tasks
4. **Implementation** - Executing tasks to produce production-ready Terraform code
5. **Deployment** - Applying infrastructure via HCP Terraform with remote state management

### Key Features

- **Devcontainer-based Development** - Fully configured development environment with all tools pre-installed
- **HCP Terraform Integration** - Remote execution, state management, and workspace automation
- **SpecKit Workflow** - Structured AI agent workflow for consistent, high-quality infrastructure code
- **Non-interactive Testing** - Automated end-to-end testing capability using the `github-speckit-tester` skill
- **Best Practice Defaults** - Pre-configured for AWS with security and cost optimization in mind
- **Pre-configured MCP Servers** - Model Context Protocol servers for enhanced AI capabilities

### MCP Servers

This template includes pre-configured [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) servers that extend Claude's capabilities:

| Server | Description |
|--------|-------------|
| **terraform** | [HCP Terraform MCP Server](https://github.com/hashicorp/terraform-mcp-server) - Workspace management, run execution, registry lookups, and provider documentation |
| **aws-knowledge-mcp-server** | [AWS Knowledge MCP](https://awslabs.github.io/mcp/) - AWS documentation search, best practices, and service recommendations |

MCP servers are automatically configured via `.mcp.json` and available when running in the devcontainer.

## Prerequisites

Before using this template, ensure you have the following installed and configured:

### Required Software

- **Docker Desktop** - Required for running the devcontainer
  - [Download Docker Desktop](https://www.docker.com/products/docker-desktop/)

- **VS Code** - Recommended IDE with devcontainer support
  - [Download VS Code](https://code.visualstudio.com/)
  - Install the "Dev Containers" extension

### Required Environment Variables

Set these in your local environment before opening the devcontainer.

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | GitHub Personal Access Token with repo permissions. **Branch protection recommended** for production repositories. |
| `TEAM_TFE_TOKEN` | **HCP Terraform Team Token** - Must be a Team API Token (not user/org token) associated with a dedicated project for workspace management |

> **Important:** The `TEAM_TFE_TOKEN` must be a **Team API Token**, not a user or organization token. Create one in HCP Terraform under **Settings > Teams > [Your Team] > Team API Token**. The team should have access to a dedicated project where workspaces will be created.

### HCP Terraform Setup (Pre-requisite)

Before using this template, you must configure HCP Terraform with an isolated environment for testing:

1. **Create a Dedicated Project**
   - Navigate to **Projects** in HCP Terraform
   - Create a new project (e.g., `sandbox`)
   - This isolates test workspaces from production infrastructure

2. **Create a Dedicated Team**
   - Go to **Settings > Teams**
   - Create a new team and assign it to the dedicated project
   - Configure **Project Team Access** with the following permissions:

     **Project Access:**
     - **Read** - Baseline permission for reading the project record
     - **Create Workspaces** - Create workspaces in the project (grants read access on all workspaces)
     - **Delete Workspaces** - Delete workspaces in the project

     **Workspace Permissions:**
     - **Read Variables** - Access existing variable values for validation
     - **Read State** - View Terraform state for existing resources
     - **Write State** - Update state during apply operations
     - **Download Sentinel Mocks** - Download Sentinel mock data for policy testing
     - **Manage Workspace Run Tasks** - Assign and unassign run tasks on workspaces
     - **Lock/Unlock Workspaces** - Control workspace locking for safe operations

3. **Generate Team API Token**
   - In **Settings > Teams > [Your Team]**
   - Click **"Create a team token"**
   - Save this as your `TEAM_TFE_TOKEN`

4. **Configure Credential Inheritance**
   - Create a Variable Set with AWS credentials (see below)
   - Attach the Variable Set to your dedicated project
   - All workspaces created in the project will inherit credentials automatically

### AWS Credentials

AWS credentials should **not** be set locally. Instead, they are inherited from an HCP Terraform Variable Set attached to your project or workspace.

**Recommended approaches (in order of preference):**

1. **Dynamic Provider Credentials** (Recommended) - Use OIDC federation between HCP Terraform and AWS for short-lived, automatically rotated credentials. See [Dynamic Provider Credentials](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration).

2. **Variable Set with Environment Variables** - Create a Variable Set in HCP Terraform containing:
   - `AWS_ACCESS_KEY_ID` (environment variable, sensitive)
   - `AWS_SECRET_ACCESS_KEY` (environment variable, sensitive)
   - `AWS_REGION` (environment variable)

   Attach the Variable Set to your project so all workspaces inherit the credentials.

> **Note:** Variable Sets can be configured at **Settings > Variable Sets** in HCP Terraform. Attach them to projects for automatic inheritance by all workspaces in that project.

**For Bash** - Add to `~/.bashrc` or `~/.bash_profile`:

```bash
# GitHub Personal Access Token with repo permissions
export GITHUB_TOKEN="ghp_your_token_here"

# HCP Terraform Team Token - MUST be a Team Token with a dedicated project
# Create at: HCP Terraform > Settings > Teams > [Your Team] > Team API Token
export TEAM_TFE_TOKEN="your_terraform_team_token_here"
```

**For Zsh** - Add to `~/.zshrc`:

```zsh
# GitHub Personal Access Token with repo permissions
export GITHUB_TOKEN="ghp_your_token_here"

# HCP Terraform Team Token - MUST be a Team Token with a dedicated project
# Create at: HCP Terraform > Settings > Teams > [Your Team] > Team API Token
export TEAM_TFE_TOKEN="your_terraform_team_token_here"
```

After adding, reload your shell configuration:

```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc
```

## Getting Started

### 1. Create Repository from Template

1. Navigate to this repository on GitHub
2. Click **"Use this template"** button
3. Select **"Create a new repository"**
4. Name your repository and configure settings
5. Click **"Create repository"**

### 2. Clone and Open in VS Code

```bash
# Clone your new repository
git clone https://github.com/YOUR_ORG/your-new-repo.git

# Open in VS Code
code your-new-repo
```

### 3. Open in Devcontainer

When VS Code opens the repository, you should see a prompt:

> **"Folder contains a Dev Container configuration file. Reopen folder to develop in a container?"**

Click **"Reopen in Container"** to launch the devcontainer with all tools pre-configured.

If the prompt doesn't appear, use the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`) and select:
> **"Dev Containers: Reopen in Container"**

## Example Test Prompts

The following example prompts demonstrate various infrastructure patterns. These are designed for use with the `github-speckit-tester` skill for non-interactive, end-to-end testing.

**To run a test prompt**, invoke the skill first then provide the infrastructure requirements:

```text
Using the github-speckit-tester skill non-interactively.

[Your infrastructure requirements here]

HCP Terraform: Organization: [org], Project: [project]
Workspace: [prefix]_<GITHUB_REPO_NAME>
```

> **Workspace Naming:** Use `<GITHUB_REPO_NAME>` as a placeholder - it will be automatically replaced with your repository name to ensure unique workspace names across template instances.
>
> **Organization:** Replace `<YOUR_TFC_ORG>` with your HCP Terraform organization name. If your token only has access to a single organization, this can be omitted.
>
> **Testing Only:** The non-interactive approach shown in these examples is **recommended for testing and evaluation only**. For production use, remove the non-interactive directive to enable human-in-the-loop review of plans before applying infrastructure changes.

### EC2 Instance with ALB and Nginx

```text
Using the github-speckit-tester skill non-interactively.

Provision using Terraform:
- EC2 instances across 2 AZs
- HTTPS and Nginx with basic static content
- ALB (Application Load Balancer)
- AWS Region: ap-southeast-2
- Use existing default VPC
- Environment: Development (minimal cost)

HCP Terraform: Organization: <YOUR_TFC_ORG>, Project: sandbox
Workspace: sandbox_ec2_<GITHUB_REPO_NAME>
```

### Serverless Application

```text
Using the github-speckit-tester skill non-interactively.

Provision using Terraform:
- Lambda functions with API Gateway
- DynamoDB tables
- S3 buckets for static assets
- CloudWatch Logs and alarms
- AWS Region: ap-southeast-2
- Environment: Development (minimal cost)

HCP Terraform: Organization: <YOUR_TFC_ORG>, Project: sandbox
Workspace: sandbox_serverless_<GITHUB_REPO_NAME>
```

### CloudFront with Static Content

```text
Using the github-speckit-tester skill non-interactively.

Provision using Terraform:
- S3 bucket for static content storage
- CloudFront distribution with OAI
- SSL/TLS certificate via ACM
- CloudWatch metrics and alarms
- AWS Region: us-east-1 (ACM certs), S3 bucket: ap-southeast-2
- Environment: Development (minimal cost)

HCP Terraform: Organization: <YOUR_TFC_ORG>, Project: sandbox
Workspace: sandbox_cloudfront_<GITHUB_REPO_NAME>
```

### Auto-Scaling Group with ALB

```text
Using the github-speckit-tester skill non-interactively.

Provision using Terraform:
- Auto-scaling group with launch template
- Target tracking policies
- ALB with health checks across 2 AZs
- CloudWatch dashboards
- AWS Region: ap-southeast-2
- Environment: Development (minimal cost)

HCP Terraform: Organization: <YOUR_TFC_ORG>, Project: sandbox
Workspace: sandbox_asg_<GITHUB_REPO_NAME>
```

### ElastiCache Redis with Application Tier

```text
Using the github-speckit-tester skill non-interactively.

Provision using Terraform:
- ElastiCache Redis cluster in private subnets
- ECS across 2 AZs for application tier
- ALB with HTTPS
- AWS Region: ap-southeast-2
- Environment: Development (minimal cost)

HCP Terraform: Organization: <YOUR_TFC_ORG>, Project: sandbox
Workspace: sandbox_elasticache_<GITHUB_REPO_NAME>
```

### SQS with Lambda and SNS

```text
Using the github-speckit-tester skill non-interactively.

Provision using Terraform:
- SQS queue with dead letter queue
- Lambda function triggered by SQS messages
- SNS topic for notifications
- CloudWatch alarms
- AWS Region: ap-southeast-2
- Environment: Development (minimal cost)

HCP Terraform: Organization: <YOUR_TFC_ORG>, Project: sandbox
Workspace: sandbox_sqs_<GITHUB_REPO_NAME>
```

---

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
