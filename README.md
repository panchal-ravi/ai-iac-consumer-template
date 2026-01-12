# EC2 Development Instance with Password-Based SSH

Public EC2 development instance with password-based SSH authentication, security hardening, and CloudWatch monitoring. Deployed via HCP Terraform for infrastructure as code best practices.

## 🚀 Quick Start

See [quickstart.md](./specs/001-ec2-dev-instance/quickstart.md) for complete deployment and testing instructions.

### Prerequisites

- HCP Terraform workspace: `sandbox_ec2_dev_instance`
- AWS credentials configured via HCP Terraform Variable Sets
- Terraform >= 1.5.0
- AWS Provider >= 5.0.0

### Deploy

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy infrastructure
terraform apply

# IMPORTANT: Set devuser password via Session Manager (REQUIRED before SSH)
# Connect to instance via Session Manager
aws ssm start-session --target $(terraform output -raw instance_id)

# Set password for devuser account (must meet complexity requirements)
# Requirements: 14+ characters, uppercase, lowercase, digit, special character
sudo passwd devuser

# Disconnect from Session Manager (Ctrl+C or type 'exit')

# Connect via SSH with password authentication
ssh devuser@$(terraform output -raw instance_public_ip)
```

### Password Requirements

The `devuser` password must meet the following complexity requirements (FR-012, FR-013):

- **Minimum length**: 14 characters
- **Character classes**: Must include all 4 types:
  - Uppercase letters (A-Z)
  - Lowercase letters (a-z)
  - Digits (0-9)
  - Special characters (!@#$%^&*)
- **Maximum repeat**: No more than 2 consecutive identical characters
- **Password expiry**: 90 days with 7-day warning (FR-017)

## Feature Overview

This implementation provides a complete EC2 development environment with:

- **Infrastructure Deployment (US1)**: t3.micro instance in us-east-1 with Elastic IP
- **SSH Access (US2)**: Password-based authentication with `devuser` account
- **Security Hardening (US3)**: fail2ban protection, strong password policies
- **Monitoring (US4)**: CloudWatch logging of SSH authentication events

### Key Features

- ✅ Password-based SSH (no key pair management required)
- ✅ Automatic brute-force protection with fail2ban
- ✅ Emergency access via AWS Systems Manager Session Manager
- ✅ Real-time SSH authentication logging to CloudWatch
- ✅ Cost-optimized: ~$10/month for development use
- ✅ 3-5 minute deployment time

### Architecture

```
Internet
   │
   ├──> Elastic IP (203.0.113.x)
   │
   └──> EC2 t3.micro (Amazon Linux 2023)
        ├── Security Group (SSH port 22)
        ├── IAM Role (SSM access)
        ├── fail2ban (brute-force protection)
        └── CloudWatch Agent (log streaming)
```

## Documentation

- **[Specification](./specs/001-ec2-dev-instance/spec.md)** - Complete feature requirements
- **[Implementation Plan](./specs/001-ec2-dev-instance/plan.md)** - Architecture and technical decisions
- **[Quick Start Guide](./specs/001-ec2-dev-instance/quickstart.md)** - Deployment and testing
- **[Research](./specs/001-ec2-dev-instance/research.md)** - Technical decision rationale
- **[Data Model](./specs/001-ec2-dev-instance/data-model.md)** - Resource relationships
- **[Terraform Interface](./specs/001-ec2-dev-instance/contracts/terraform-interface.md)** - Input/output contract

## Cost Estimate

| Component | Monthly Cost |
|-----------|--------------|
| EC2 t3.micro | $7.50 |
| EBS gp3 30GB | $2.40 |
| CloudWatch Logs | $0.50 |
| **Total** | **~$10.40** |

Well within the $50/month budget ceiling (SC-005).

## Security Considerations

⚠️ **Development Environment Only**

This configuration is designed for development environments and is **NOT suitable for production use**:

- Public SSH access (0.0.0.0/0) with password authentication
- Not compliant with PCI-DSS, HIPAA, or SOC 2
- No data encryption beyond AWS defaults
- Single point of access (no high availability)

**Mitigations in place:**
- fail2ban automatic IP blocking after 5 failed attempts
- Strong password policy enforcement (14+ characters, 4 character classes)
- CloudWatch authentication logging for security monitoring
- Session Manager emergency fallback access

---

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.ssh_auth_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eip.dev_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_iam_instance_profile.ec2_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ec2_ssm_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ssm_managed_instance_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.dev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.ec2_dev_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ami.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_subnets.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional tags to merge with standard tags (Environment, Project, ManagedBy, PublicAccess) | `map(string)` | `{}` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for resource deployment (e.g., us-east-1, us-west-2) | `string` | `"us-east-1"` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Enable CloudWatch detailed monitoring (1-minute metrics, adds $2/month cost) | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment - development use only (production NOT supported) | `string` | `"development"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type from t3 family (t3.micro ~$7.50/month, t3.small ~$15/month) | `string` | `"t3.micro"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project identifier for resource naming (1-32 chars, lowercase alphanumeric and hyphens) | `string` | `"ec2-dev-instance"` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Root EBS volume size in GB (minimum 30 for AL2023, ~$0.10/GB-month for gp3) | `number` | `30` | no |
| <a name="input_ssh_allowed_cidr_blocks"></a> [ssh\_allowed\_cidr\_blocks](#input\_ssh\_allowed\_cidr\_blocks) | CIDR blocks allowed for SSH access (0.0.0.0/0 allows public access - development only) | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_elastic_ip_id"></a> [elastic\_ip\_id](#output\_elastic\_ip\_id) | Elastic IP allocation ID for cost tracking and IP allowlist management |
| <a name="output_iam_instance_profile_name"></a> [iam\_instance\_profile\_name](#output\_iam\_instance\_profile\_name) | IAM instance profile name for role association verification |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | IAM role ARN for Session Manager access and permission verification |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | EC2 instance identifier for AWS Console navigation and Session Manager |
| <a name="output_instance_private_ip"></a> [instance\_private\_ip](#output\_instance\_private\_ip) | VPC private IP address for internal routing and VPC peering |
| <a name="output_instance_public_ip"></a> [instance\_public\_ip](#output\_instance\_public\_ip) | Public IP address (Elastic IP) for SSH access and DNS configuration |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | CloudWatch Logs group ARN for IAM policies and cross-account access |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | CloudWatch Logs group name for SSH authentication events and log streaming |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID for SSH access rules and compliance auditing |
| <a name="output_session_manager_command"></a> [session\_manager\_command](#output\_session\_manager\_command) | AWS CLI command for Session Manager emergency fallback access |
| <a name="output_ssh_connection_command"></a> [ssh\_connection\_command](#output\_ssh\_connection\_command) | Ready-to-use SSH connection command (password must be set first via Session Manager) |
<!-- END_TF_DOCS -->
