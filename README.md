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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.30.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb"></a> [alb](#module\_alb) | app.terraform.io/ravi-panchal-org/alb/aws | 10.2.0 |
| <a name="module_alb_security_group"></a> [alb\_security\_group](#module\_alb\_security\_group) | app.terraform.io/ravi-panchal-org/security-group/aws | 5.3.1 |
| <a name="module_ec2_instance"></a> [ec2\_instance](#module\_ec2\_instance) | app.terraform.io/ravi-panchal-org/ec2-instance/aws | 6.1.4 |
| <a name="module_ec2_security_group"></a> [ec2\_security\_group](#module\_ec2\_security\_group) | app.terraform.io/ravi-panchal-org/security-group/aws | 5.3.1 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.self_signed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_lb_target_group_attachment.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_security_group_rule.alb_to_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [tls_private_key.self_signed](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.self_signed](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_subnet.az](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones for instance distribution (exactly 2 required) | `list(string)` | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for TLS certificate (e.g., web.demo.com) | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (development, staging, production) | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for web servers | `string` | `"t3a.micro"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name used for resource naming and tagging | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region for infrastructure deployment | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | ACM certificate ARN for self-signed TLS certificate |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ALB ARN |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | ALB DNS name for HTTPS access |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | ALB security group ID |
| <a name="output_ec2_instance_ids"></a> [ec2\_instance\_ids](#output\_ec2\_instance\_ids) | EC2 instance IDs by availability zone |
| <a name="output_ec2_security_group_id"></a> [ec2\_security\_group\_id](#output\_ec2\_security\_group\_id) | EC2 security group ID |
| <a name="output_https_url"></a> [https\_url](#output\_https\_url) | HTTPS URL for accessing the application |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet IDs used for deployment |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | Target group ARN for health checks |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID (default VPC) |
<!-- END_TF_DOCS -->
