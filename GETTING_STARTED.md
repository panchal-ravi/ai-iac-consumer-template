# Getting Started with AI-Assisted Terraform Development

Welcome to the AI-assisted Terraform development template! This guide will help you get started with spec-driven infrastructure development using AI assistants (Claude Code or VS Code Agent) and the Speckit workflow framework.

## Overview

This template provides a structured approach to Terraform development where specifications drive implementation through AI assistance. You'll create detailed specifications first, then let AI generate production-ready Terraform code based on those specs.

**Compatible AI Assistants**:
- **Claude Code** - Anthropic's AI coding assistant
- **VS Code Agent** - AI agent integrated with Visual Studio Code

## Prerequisites

### Required Tools

- **AI Assistant** (choose one):
  - [Claude Code](https://claude.com/code) - Standalone AI coding assistant
  - [VS Code](https://code.visualstudio.com/) with Anthropic extension - For VS Code Agent
- **[Terraform](https://www.terraform.io/)** >= 1.8 - Infrastructure as Code tool
- **[HCP Terraform Account](https://app.terraform.io/)** - For testing and state management
- **[Git](https://git-scm.com/)** - Version control
- **[Docker](https://www.docker.com/)** - For MCP server support

### Optional Tools

- **[Pre-commit Framework](https://pre-commit.com/)** - Code quality hooks (recommended)

### Environment Setup

Set your HCP Terraform API token for private registry access:

```bash
export TFE_TOKEN="your-hcp-terraform-token"
```

To get your token:
1. Visit [HCP Terraform](https://app.terraform.io/)
2. Go to User Settings → Tokens
3. Create a new API token

## Quick Start

### 1. Create Your Repository

Create a new repository from this template:

```bash
# Using GitHub CLI
gh repo create my-infrastructure --template ai-iac-consumer-template --private
cd my-infrastructure

# Or use the GitHub web interface
# Click "Use this template" → "Create a new repository"
```

### 2. Set Up Your Development Environment

#### Option A: Using VS Code with Devcontainer (Recommended)

The devcontainer configuration is validated for both VS Code Agent and Claude Code:

1. Open the repository in VS Code
2. When prompted, click "Reopen in Container"
3. Wait for the container to build (first time only)
4. The environment includes all required tools pre-installed

**Available devcontainer configurations**:
- `.devcontainer/vscode-agent/` - Optimized for VS Code Agent
- `.devcontainer/claude-code/` - Optimized for Claude Code

#### Option B: Local Setup

Install dependencies locally:

```bash
# Install pre-commit
pip install pre-commit
pre-commit install

# Verify Terraform installation
terraform version

# Verify Docker is running
docker ps
```

### 3. Configure MCP Servers

The template includes two MCP servers for enhanced AI capabilities:

- **Terraform MCP Server** - Access to Terraform Registry and workspace management
- **AWS Knowledge MCP Server** - AWS documentation and recommendations

Configuration is in [.mcp.json](.mcp.json). No additional setup needed if using the devcontainer.

### 4. Start Your First Infrastructure Project

Open your AI assistant and begin with a specification:

```
/speckit.specify

I need to deploy a highly available web application infrastructure in AWS:
- VPC with public and private subnets across 3 availability zones
- Application Load Balancer in public subnets
- EC2 instances running nginx in private subnets
- Auto Scaling Group for the EC2 instances
- Security groups with minimal required access
- Region: us-east-1
```

## Understanding the Speckit Workflow

The development process follows distinct phases. **Never skip directly to code generation!**

### Phase 0: Specification & Requirements

#### `/speckit.specify` - Create Feature Specification

**What it does**: Converts your infrastructure description into a structured specification document.

**When to use**: Starting any new infrastructure feature or component.

**Example output**:
- `spec.md` - Detailed feature specification
- Checklist template for requirements validation

**What to provide**:
- Infrastructure requirements and goals
- Target cloud provider and region
- Compliance or security requirements
- Integration needs with existing infrastructure
- Cost or performance constraints

---

#### `/speckit.clarify` - Resolve Ambiguities

**What it does**: Identifies vague requirements and asks clarifying questions.

**When to use**: After creating `spec.md` and before planning.

**Example questions you might get**:
- "Should the VPC use single or multi-region deployment?"
- "What backup strategy is required for stateful resources?"
- "Which Terraform state backend: S3, HCP Terraform, or local?"

**What happens**: Your answers are integrated directly into `spec.md`.

---

#### `/speckit.checklist` - Validate Requirements

**What it does**: Creates domain-specific checklists to test requirement quality.

**When to use**: After clarification, before technical planning.

**Important**: Checklists test requirements, NOT implementation:
- ✅ "Are VPC CIDR ranges explicitly specified?"
- ✅ "Are high-availability requirements quantified (e.g., 99.99%)?"
- ❌ NOT "Verify VPC is created successfully" (that's implementation testing)

---

### Phase 1: Technical Planning & Design

#### `/speckit.plan` - Design Implementation

**What it does**: Creates detailed technical design using MCP tools to search Terraform modules.

**When to use**: After requirements are validated and clear.

**Example output**:
- `plan.md` - Complete architecture and module selections
- `data-model.md` - Resource relationships and data structures
- `contracts/` - Module interface contracts
- `research.md` - Decision rationale and alternatives considered

**What the AI does**:
- Searches private Terraform registry for relevant modules
- Retrieves complete module specifications
- Maps requirements to module capabilities
- Documents architecture decisions
- Plans variable structure and outputs

---

#### `/speckit.tasks` - Generate Task List

**What it does**: Breaks the plan into discrete, ordered implementation tasks.

**When to use**: After `plan.md` is approved.

**Example output**: `tasks.md` with:
- Phase-grouped tasks
- Task dependencies
- Acceptance criteria linked to requirements
- Estimated effort

---

#### `/speckit.analyze` - Validate Consistency

**What it does**: Read-only analysis of spec, plan, and tasks for consistency.

**When to use**: Before implementation to catch issues early.

**What it checks**:
- Every requirement has corresponding tasks
- No conflicts between artifacts
- Module selections match spec capabilities
- Complete variable coverage
- No constitution violations

**Important**: This does NOT modify files - you decide on remediation.

---

### Phase 3: Implementation

#### `/speckit.implement` - Generate Code

**What it does**: Generates production-ready Terraform code based on approved specifications.

**When to use**: Only after all prior phases are complete.

**Prerequisites checklist**:
- ✅ `/speckit.specify` completed
- ✅ `/speckit.clarify` completed (if needed)
- ✅ `/speckit.plan` completed and approved
- ✅ `/speckit.tasks` completed
- ✅ `/speckit.analyze` passed (or issues acknowledged)

**What gets generated**:
- `main.tf` - Module declarations and resources
- `variables.tf` - Input variables with validation
- `outputs.tf` - Output values
- `versions.tf` - Version constraints
- `providers.tf` - Provider configuration
- `locals.tf` - Local values
- `override.tf` - HCP Terraform backend config (for testing)
- `sandbox.auto.tfvars.example` - Example variable values
- `sandbox.auto.tfvars` - Testing variable values

**What happens next**:
1. Pre-commit hooks are installed/updated
2. Code is automatically tested in ephemeral HCP Terraform workspace
3. Results are validated
4. Documentation is updated
5. You receive deployment instructions

---

## Automated Testing

### Ephemeral Workspace Testing

All generated code is automatically tested before you use it:

**How it works**:
1. AI commits code to your `feature/*` branch
2. Pushes to remote repository
3. Creates ephemeral workspace: `sandbox_<repo-name>`
4. Configures variables from `variables.tf`
5. Runs `terraform plan` and `terraform apply`
6. Validates results
7. Prompts you to verify created resources
8. Auto-destroys workspace after 2 hours

**Benefits**:
- Safe testing in isolated environment
- No impact on existing infrastructure
- Automatic cleanup to minimize costs
- Validation before production use

### Manual Testing

You can also test manually:

```bash
# Copy and edit example variables
cp sandbox.auto.tfvars.example sandbox.auto.tfvars
vim sandbox.auto.tfvars

# Initialize with cloud backend
terraform init

# Review planned changes
terraform plan

# Apply if everything looks good
terraform apply
```

## Pre-commit Hooks

Quality gates run automatically on every commit:

| Hook | Purpose |
|------|---------|
| `terraform_fmt` | Format code to canonical style |
| `terraform_validate` | Validate configuration syntax |
| `terraform_docs` | Auto-generate README documentation |
| `terraform_tflint` | Lint for best practices and errors |
| `terraform_tfsec` | Security vulnerability scanning |
| Standard checks | Trailing whitespace, YAML syntax, large files, secrets |

**Run manually**:
```bash
pre-commit run --all-files
```

**Update hooks**:
```bash
pre-commit autoupdate
```

## Available Skills

Specialized AI agents for enhanced capabilities:

### terraform-test
Comprehensive guide for writing and running Terraform tests.

**When to use**: Creating test files, validating modules, troubleshooting test syntax.

**Invoke**:
```
Use the terraform-test skill to help me write tests for this module
```

### terraform-stacks
HashiCorp Terraform Stacks configuration support.

**When to use**: Working with stack components, multi-region deployments, stack syntax.

**Invoke**:
```
Use the terraform-stacks skill to help configure my deployment stack
```

### github-speckit-tester
Non-interactive workflow validation and testing harness.

**When to use**: Testing complete Speckit pipeline, automating specification workflows.

**Invoke**:
```
Use the github-speckit-tester skill to validate my workflow
```

## MCP Server Integration

### Terraform MCP Server

Provides direct access to:
- Private Terraform registry modules
- Module specifications and documentation
- HCP Terraform workspace management
- Terraform run creation and monitoring

The AI uses this automatically during `/speckit.plan` to search and verify modules.

### AWS Knowledge MCP Server

Provides access to:
- AWS service documentation
- Architectural best practices
- Regional service availability
- AWS Well-Architected Framework guidance

The AI can use this during planning for AWS infrastructure.

## Project Structure

```
.
├── .claude/                      # AI assistant configuration
│   ├── CLAUDE.md                # AI agent instructions
│   ├── commands/                # Speckit slash commands
│   │   ├── speckit.specify.md
│   │   ├── speckit.clarify.md
│   │   ├── speckit.checklist.md
│   │   ├── speckit.plan.md
│   │   ├── speckit.tasks.md
│   │   ├── speckit.analyze.md
│   │   └── speckit.implement.md
│   ├── skills/                  # Specialized AI agents
│   │   ├── terraform-test/
│   │   ├── terraform-stacks/
│   │   └── github-speckit-tester/
│   └── settings.local.json      # Local settings
├── .devcontainer/               # Development containers (validated)
│   ├── claude-code/            # Claude Code devcontainer
│   └── vscode-agent/           # VS Code Agent devcontainer
├── .github/                     # GitHub configuration
│   ├── dependabot.yml          # Dependency updates
│   └── prompts/                # GitHub prompt templates
├── .specify/                    # Speckit framework
│   ├── memory/                 # Workflow state and history
│   ├── scripts/                # Automation scripts
│   └── templates/              # Document templates
├── .gitignore                   # Git ignore patterns
├── .mcp.json                    # MCP server configuration
├── .pre-commit-config.yaml     # Pre-commit hooks
├── .tflint.hcl                 # TFLint configuration
├── AGENTS.md                    # Detailed AI agent guidance
├── GETTING_STARTED.md          # This file
├── README.md                    # Template README
└── *.tf                         # Generated Terraform files
```

## Best Practices

### 1. Always Follow the Workflow Phases

Don't skip to code generation. Each phase builds on the previous:
- Spec → Clarify → Checklist → Plan → Tasks → Analyze → Implement

### 2. Be Specific in Requirements

**Vague**: "I need a secure, scalable VPC"
**Better**: "I need a VPC with /16 CIDR, 3 AZs, public/private subnets, NAT gateways, and network ACLs for defense-in-depth"

### 3. Use Clarification Actively

Don't assume the AI knows your preferences. Answer clarification questions thoroughly.

### 4. Review Plans Before Implementation

Always review `plan.md` to ensure the architecture matches your expectations.

### 5. Leverage MCP Tools

The AI will automatically search private registry modules. Ensure `TFE_TOKEN` is set.

### 6. Test in Ephemeral Workspaces

Use the automated testing before promoting to production environments.

### 7. Document Discoveries

Update [AGENTS.md](AGENTS.md) when you learn new patterns or solutions.

## Common Workflows

### Creating a New Infrastructure Component

```
# Phase 0: Requirements
/speckit.specify
[Describe your infrastructure needs]

/speckit.clarify
[Answer clarification questions]

/speckit.checklist
[Review and address any requirement quality issues]

# Phase 1: Design
/speckit.plan
[Review the generated plan.md]

/speckit.tasks
[Review tasks.md]

/speckit.analyze
[Address any consistency issues]

# Phase 3: Implementation
/speckit.implement
[AI generates code, runs tests, provides deployment instructions]
```

### Updating Existing Infrastructure

```
# Update spec.md with new requirements
/speckit.clarify
[Clarify new requirements]

# Regenerate plan with new requirements
/speckit.plan

# Update tasks
/speckit.tasks

# Validate consistency
/speckit.analyze

# Implement changes
/speckit.implement
```

### Testing a Module

```
Use the terraform-test skill to help me write tests for the VPC module
```

## Troubleshooting

### MCP Server Connection Issues

**Problem**: "Cannot connect to Terraform MCP server"

**Solution**:
```bash
# Verify Docker is running
docker ps

# Check if container is running
docker ps | grep terraform-mcp-server

# Verify token is set
echo $TFE_TOKEN

# Test token validity
terraform login
```

### Pre-commit Hook Failures

**Problem**: Commit blocked by pre-commit hooks

**Solution**:
```bash
# Run hooks manually to see details
pre-commit run --all-files

# Common fixes:
terraform fmt -recursive     # Fix formatting
terraform validate          # Check syntax
pre-commit autoupdate       # Update hook versions
```

### HCP Terraform Authentication

**Problem**: "Authentication failed" during testing

**Solution**:
```bash
# Set token environment variable
export TFE_TOKEN="your-token-here"

# Or configure via terraform login
terraform login

# Verify token works
terraform workspace list
```

### Ephemeral Workspace Issues

**Problem**: Automated testing fails to create workspace

**Solution**:
1. Verify `TFE_TOKEN` is set and valid
2. Check you have permissions in HCP Terraform organization
3. Verify the repository is connected to HCP Terraform
4. Ensure the feature branch is pushed to remote

### Module Not Found

**Problem**: "Module not found in private registry"

**Solution**:
1. Verify `TFE_TOKEN` has access to private registry
2. Try broader search terms in `/speckit.plan`
3. Consider using public registry modules (with approval)
4. Check organization name in module source path

## AI Assistant Comparison

| Feature | Claude Code | VS Code Agent |
|---------|-------------|---------------|
| Speckit Commands | ✅ Full support | ✅ Full support |
| MCP Servers | ✅ Configured | ✅ Configured |
| Devcontainer | ✅ `.devcontainer/claude-code/` | ✅ `.devcontainer/vscode-agent/` |
| Skills | ✅ Available | ✅ Available |
| Pre-commit Integration | ✅ Automated | ✅ Automated |
| Ephemeral Testing | ✅ Automated | ✅ Automated |

Choose the assistant that best fits your workflow - both are fully supported!

## Next Steps

1. **Read [AGENTS.md](AGENTS.md)** - Comprehensive project guidance
2. **Explore [.claude/commands/](.claude/commands/)** - Detailed command documentation
3. **Try the workflow** - Start with a simple infrastructure component
4. **Customize** - Add your own skills, commands, or templates
5. **Share** - Contribute improvements back to the template

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [Claude Code Documentation](https://docs.claude.com/claude-code)
- [VS Code Anthropic Extension](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude)
- [Pre-commit Documentation](https://pre-commit.com/)
- [MCP Protocol](https://modelcontextprotocol.io/)

## Support

For issues or questions:
- Review [AGENTS.md](AGENTS.md) for detailed guidance
- Check command documentation in [.claude/commands/](.claude/commands/)
- Consult skill documentation in [.claude/skills/](.claude/skills/)
- Open an issue in your repository

---

**Ready to start?** Open your AI assistant (Claude Code or VS Code Agent) and run `/speckit.specify` to begin your first infrastructure project!
