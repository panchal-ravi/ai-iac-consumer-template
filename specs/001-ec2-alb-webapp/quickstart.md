# Quick Start Guide: Web Application Infrastructure

**Feature**: 001-ec2-alb-webapp
**Date**: 2025-11-03
**Purpose**: Step-by-step deployment guide for highly available web application infrastructure

---

## Overview

This guide provides instructions for deploying a highly available web application infrastructure on AWS using HCP Terraform. The infrastructure includes:

- VPC with public and private subnets across 2 Availability Zones
- Application Load Balancer for HTTPS traffic distribution
- Auto Scaling Group with t3.micro EC2 instances
- SSL/TLS certificate via AWS Certificate Manager
- S3 bucket for static web content
- Security groups following least-privilege principles

**Estimated Deployment Time**: 20-30 minutes
**Estimated Monthly Cost**: $100-120 USD

---

## Prerequisites

### 1. HCP Terraform Access

- ✅ **Organization**: `hashi-demos-apj`
- ❓ **Project**: To be confirmed (Recommended: Default Project)
- ❓ **Workspaces**: dev, staging, prod workspaces (to be confirmed/created)
- ✅ **Permissions**: Ability to create/manage workspaces and variables

### 2. AWS Requirements

- AWS Account with appropriate permissions
- AWS credentials configured in HCP Terraform workspace variable sets
- Domain name for SSL certificate (e.g., `example.com`)
- DNS access to create validation records (Route53 or external DNS provider)

### 3. Local Development Environment

- Git installed
- Terraform CLI >= 1.0 (optional, for local validation)
- Pre-commit framework (will be installed/configured during setup)
- Text editor or IDE

### 4. Module Approvals

**⚠️ Important**: This project requires approval to use public Terraform registry modules:

- **ALB Module**: `terraform-aws-modules/alb/aws` (~> 9.0)
- **Auto Scaling Group Module**: `terraform-aws-modules/autoscaling/aws` (~> 7.0)

**Reason**: These modules are not available in the private registry (`hashi-demos-apj`).

**Constitution Compliance**: Using public modules with explicit approval follows Section 8.3 guidelines.

---

## Step 1: Confirm HCP Terraform Configuration

### 1.1 Confirm Project

**Confirmed Configuration** ✅:
```
Organization: hashi-demos-apj
Project Name: hackathon
Project ID: prj-hna8wHXsgBrDhHDz
Workspace: webapp-sandbox
Domain: web.simon-lynch.sbx.hashidemos.io
```

**Note**: Using single sandbox workspace for hackathon/demo environment. Production deployments would use separate dev/staging/prod workspaces.

### 1.3 Verify Git Repository Connection

```bash
git remote -v
# Should show: https://github.com/panchal-ravi/ai-iac-consumer-template.git
```

---

## Step 2: Clone and Configure Repository

### 2.1 Ensure Current Branch

```bash
git branch
# Should show: * 001-ec2-alb-webapp

# If not on this branch:
git checkout 001-ec2-alb-webapp
```

### 2.2 Verify Branch is Pushed to Remote

```bash
git status
# Ensure branch is up to date with remote

git push origin 001-ec2-alb-webapp
```

---

## Step 3: Gather Required Information

Before proceeding, collect the following information:

### 3.1 Network Configuration

- **VPC CIDR Block**: `10.0.0.0/16` (default, or specify custom)
- **Public Subnet CIDRs**: `10.0.1.0/24`, `10.0.2.0/24`
- **Private Subnet CIDRs**: `10.0.11.0/24`, `10.0.12.0/24`
- **Availability Zones**: `<region>a`, `<region>b` (e.g., `us-east-1a`, `us-east-1b`)

### 3.2 Domain and SSL

- ✅ **Domain Name**: `web.simon-lynch.sbx.hashidemos.io`
- **DNS Provider**: Assumed Route53 (hashidemos.io zone)
- **Access to DNS**: Ability to create CNAME records for ACM validation

### 3.3 Static Content

- **Content Location**: Where are your HTML, CSS, JS, images stored?
- **Content Size**: Approximate size for S3 bucket planning
- **Deployment Method**: Manual upload, CI/CD, or other

### 3.4 AWS Region

- **Primary Region**: Where to deploy infrastructure (e.g., `us-east-1`, `ap-southeast-2`)

---

## Step 4: Review and Approve Public Modules

### 4.1 ALB Module Review

**Module**: `terraform-aws-modules/alb/aws`
**Version**: `~> 9.0`
**Source**: https://registry.terraform.io/modules/terraform-aws-modules/alb/aws

**Why Needed**: Private registry lacks ALB module

**Security Review**:
- ✅ Official HashiCorp-verified module
- ✅ 100M+ downloads, actively maintained
- ✅ Follows AWS best practices
- ✅ Supports HTTPS, security groups, target groups

**Approval**: ✅ **APPROVED** by user

### 4.2 Auto Scaling Group Module Review

**Module**: `terraform-aws-modules/autoscaling/aws`
**Version**: `~> 7.0`
**Source**: https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws

**Why Needed**: Private registry lacks ASG module

**Security Review**:
- ✅ Official HashiCorp-verified module
- ✅ 50M+ downloads, actively maintained
- ✅ Supports launch templates, target groups, scaling policies
- ✅ IMDSv2 support

**Approval**: ✅ **APPROVED** by user

---

## Step 5: Terraform Code Generation

**Note**: Code generation occurs during `/speckit.implement` phase. This quickstart assumes code has been generated.

### 5.1 Verify File Structure

Expected files in repository root:

```
/workspace/
├── main.tf                  # Module instantiations
├── variables.tf             # Input variable declarations
├── outputs.tf               # Infrastructure outputs
├── terraform.tf             # Provider and version constraints
├── README.md                # Auto-generated documentation
├── .gitignore               # Terraform-specific ignores
├── .pre-commit-config.yaml  # Pre-commit hooks config
└── .git/hooks/
    └── pre-commit           # Pre-commit hook script
```

### 5.2 Review Variable Definitions

Open `variables.tf` and verify required variables:

```hcl
# Example variables (actual implementation may vary)
variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Domain name for ACM certificate"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
```

---

## Step 6: Configure Pre-commit Hooks

### 6.1 Install Pre-commit Framework

```bash
# Check if pre-commit is installed
which pre-commit

# If not installed:
pip install pre-commit

# Or using Homebrew (macOS):
brew install pre-commit
```

### 6.2 Install Pre-commit Hooks

```bash
# From repository root
pre-commit install

# Verify installation
pre-commit --version
```

### 6.3 Verify Pre-commit Configuration

Review `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
          - --hook-config=--create-file-if-not-exist=true
      - id: terraform_tflint
      - id: terraform_tfsec
```

### 6.4 Run Pre-commit Manually (First Time)

```bash
# Run all hooks on all files
pre-commit run --all-files

# Fix any issues reported
# Common issues: trailing whitespace, file formatting
```

---

## Step 7: Create Ephemeral Test Workspace

**Purpose**: Test Terraform code in isolated environment before promoting to dev

### 7.1 Workspace Naming

```
Target Workspace: webapp-sandbox
Ephemeral Test Workspace: test-webapp-<timestamp> (for pre-deployment testing)
Example: test-webapp-20251103-143022
```

### 7.2 Workspace Configuration

**Using Terraform MCP Server** (automated approach):

The `/speckit.tasks` command will automatically:
1. Create ephemeral workspace
2. Connect to `001-ec2-alb-webapp` branch
3. Enable auto-apply
4. Configure auto-destroy (2 hours)
5. Create required workspace variables

**Manual Alternative** (if MCP unavailable):

1. Navigate to HCP Terraform UI → `hashi-demos-apj` organization
2. Create new workspace: `test-webapp-<timestamp>`
3. **VCS Connection**:
   - Repository: `panchal-ravi/ai-iac-consumer-template`
   - Branch: `001-ec2-alb-webapp`
4. **Settings**:
   - Auto-apply: ✅ Enabled
   - Auto-destroy: ✅ Enabled (2 hours)
5. **Project**: Assign to selected project

### 7.3 Configure Workspace Variables

**Environment Variables** (configured at workspace level):

| Variable | Value | Sensitive | Category | Description |
|----------|-------|-----------|----------|-------------|
| `environment` | `sandbox` | No | Terraform | Deployment environment |
| `vpc_cidr` | `10.0.0.0/16` | No | Terraform | VPC CIDR block |
| `domain_name` | `web.simon-lynch.sbx.hashidemos.io` | No | Terraform | Domain for webapp |
| `region` | `us-east-1` | No | Terraform | AWS region |

**AWS Credentials** (pre-configured via variable sets):
- ✅ Should already exist via organization variable sets
- ❌ Do NOT create AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY manually

**Note**: Variable values depend on your `variables.tf` implementation.

---

## Step 8: Commit and Push Code

### 8.1 Stage Changes

```bash
# Check status
git status

# Stage all Terraform files
git add main.tf variables.tf outputs.tf terraform.tf

# Stage configuration files
git add .gitignore .pre-commit-config.yaml README.md

# Review changes
git diff --staged
```

### 8.2 Commit with Pre-commit Hooks

```bash
# Commit (pre-commit hooks run automatically)
git commit -m "feat: Add highly available web application infrastructure

- VPC with public/private subnets across 2 AZs
- Application Load Balancer with HTTPS
- Auto Scaling Group with t3.micro instances
- ACM certificate for SSL/TLS
- S3 bucket for static content
- Security groups with least-privilege rules

🤖 Generated with Claude Code (https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Pre-commit hooks will:
# - Format Terraform code (terraform fmt)
# - Validate syntax (terraform validate)
# - Update README.md (terraform-docs)
# - Run security checks (tfsec)
# - Run linting (tflint)
```

### 8.3 Handle Pre-commit Hook Failures

If pre-commit hooks modify files:

```bash
# Hooks modified files (e.g., formatted code, updated README)
# Review changes
git diff

# Stage modified files
git add -u

# Amend commit
git commit --amend --no-edit
```

### 8.4 Push to Remote

```bash
# Push feature branch
git push origin 001-ec2-alb-webapp

# HCP Terraform VCS workflow triggers automatically
```

---

## Step 9: Monitor Terraform Run

### 9.1 Access HCP Terraform UI

1. Navigate to `app.terraform.io`
2. Select organization: `hashi-demos-apj`
3. Find workspace: `test-webapp-<timestamp>`
4. View current run

### 9.2 Terraform Plan Phase

**HCP Terraform automatically runs**:
1. `terraform init` (initializes providers and modules)
2. `terraform plan` (shows infrastructure changes)

**Review Plan Output**:
- ✅ Resources to be created (VPC, subnets, ALB, ASG, etc.)
- ✅ No unexpected deletions or modifications
- ✅ Estimated costs (if enabled)

**Expected Resources**:
- ~35-45 resources to be created (varies by configuration)
- VPC: 1, Subnets: 4, Security Groups: 2, ALB: 1, Target Group: 1, ASG: 1, etc.

### 9.3 Terraform Apply Phase

**Auto-Apply** (configured in ephemeral workspace):
- Plan succeeds → Apply starts automatically
- No manual approval needed for ephemeral workspace

**Monitor Apply Progress**:
- Watch resource creation in real-time
- Note any errors or warnings
- Typical apply time: 5-10 minutes

### 9.4 Handle Apply Failures

If apply fails:

1. **Review Error Messages**:
   - Check logs for specific resource errors
   - Common issues: AWS quota limits, permission errors, invalid configurations

2. **Fix Issues**:
   - Update Terraform code if needed
   - Adjust workspace variables if needed
   - Commit and push fixes

3. **Retry**:
   - HCP Terraform VCS workflow triggers new run automatically
   - Or manually trigger via UI

---

## Step 10: Validate Deployment

### 10.1 Verify Resource Creation

**In HCP Terraform UI**:
- ✅ All resources created successfully
- ✅ No errors in apply log
- ✅ Outputs displayed

**Check Key Outputs**:
```
Outputs:
  vpc_id = "vpc-0abcd1234efgh5678"
  alb_dns_name = "webapp-alb-1234567890.us-east-1.elb.amazonaws.com"
  alb_zone_id = "Z35SXDOTRQ7X7K"
  autoscaling_group_id = "webapp-asg-20251103..."
  s3_bucket_name = "webapp-static-content-a1b2c3d4"
```

### 10.2 Verify ALB Target Health

**In AWS Console**:
1. Navigate to EC2 → Load Balancers
2. Select ALB: `webapp-alb`
3. Check **Target Groups** tab
4. Verify targets are "healthy"
   - ✅ 2 healthy targets (minimum)
   - ⏳ Wait 2-5 minutes if showing "initial"

**Expected States**:
- `initial` → `healthy` (successful)
- `initial` → `unhealthy` (investigate)

### 10.3 Test HTTP to HTTPS Redirect

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://<alb-dns-name>

# Expected Response:
# HTTP/1.1 301 Moved Permanently
# Location: https://<alb-dns-name>/
```

### 10.4 Test HTTPS Access

**⚠️ Certificate Warning Expected**:
- ALB DNS name doesn't match certificate domain
- Browser will show warning unless using custom domain

**Option A: Using curl (ignore cert)**:
```bash
curl -k https://<alb-dns-name>
# Should return Nginx default page or your content
```

**Option B: Using custom domain** (if DNS configured):
```bash
curl https://test.example.com
# Should return content without certificate warnings
```

### 10.5 Verify Auto Scaling

**Check ASG Status**:
```bash
# Using AWS CLI (if configured)
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names webapp-asg-<identifier> \
  --region us-east-1
```

**Expected**:
- Desired Capacity: 2
- Min Size: 2
- Max Size: 6
- Current Instances: 2
- Healthy Instances: 2

### 10.6 Verify S3 Bucket

**Check Bucket Creation**:
```bash
aws s3 ls | grep webapp-static-content
```

**Upload Test Content** (optional):
```bash
echo "<h1>Test Page</h1>" > test.html
aws s3 cp test.html s3://webapp-static-content-<suffix>/
```

### 10.7 Verify EC2 Instance Access to S3

**SSH via Session Manager**:
```bash
# Find instance ID from ASG
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=webapp-asg-*" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output table

# Connect via Session Manager
aws ssm start-session --target <instance-id>

# Inside instance, test S3 access:
aws s3 ls s3://webapp-static-content-<suffix>/
# Should list bucket contents successfully
```

---

## Step 11: Promote to Dev Workspace

### 11.1 Verify Ephemeral Workspace Success

**Checklist**:
- ✅ All resources created successfully
- ✅ ALB targets are healthy
- ✅ HTTP redirects to HTTPS
- ✅ Auto Scaling Group has 2 instances
- ✅ No errors in logs

### 11.2 Create Dev Workspace Variables

**Using Terraform MCP Server** (automated):
- Automatically creates identical variables in dev workspace
- Excludes ephemeral workspace-specific values

**Manual Process**:
1. Navigate to `webapp-dev` workspace
2. Add variables (same as ephemeral):
   - `environment` = `dev`
   - `vpc_cidr` = `10.0.0.0/16` (or production CIDR)
   - `domain_name` = `dev.example.com` (production domain)
   - `region` = `us-east-1`

### 11.3 Merge Feature Branch to Dev

```bash
# Ensure feature branch is up to date
git pull origin 001-ec2-alb-webapp

# Switch to dev branch
git checkout dev
git pull origin dev

# Merge feature branch
git merge 001-ec2-alb-webapp

# Push to remote (triggers dev workspace run)
git push origin dev
```

### 11.4 Monitor Dev Deployment

1. Navigate to HCP Terraform → `webapp-dev` workspace
2. Review plan generated by VCS workflow
3. **Manually approve** plan (dev requires human approval per constitution)
4. Monitor apply progress
5. Validate deployment (repeat Step 10 validation)

### 11.5 Clean Up Ephemeral Workspace

**Auto-Destroy**:
- Ephemeral workspace auto-destroys after 2 hours
- All AWS resources deleted automatically

**Manual Cleanup** (if needed before 2 hours):
1. Navigate to ephemeral workspace
2. Queue destroy plan
3. Approve and apply destruction
4. Delete workspace after resources destroyed

---

## Step 12: Configure DNS (Production)

### 12.1 ACM Certificate Validation

**If using Route53**:
- Validation records automatically created by Terraform
- Wait 5-10 minutes for validation to complete

**If using External DNS**:
1. Get validation CNAME records from ACM console or Terraform outputs
2. Add CNAME records to your DNS provider:
   ```
   Name: _<random-string>.test.example.com
   Type: CNAME
   Value: _<random-string>.acm-validations.aws.
   TTL: 300
   ```
3. Wait for ACM to validate (5-30 minutes)

### 12.2 Create DNS A Record for ALB

**Option A: Route53**:
```hcl
# Add to Terraform code or create manually
resource "aws_route53_record" "webapp" {
  zone_id = var.route53_zone_id
  name    = "webapp.example.com"
  type    = "A"

  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
```

**Option B: External DNS**:
- Create CNAME record:
  ```
  Name: webapp.example.com
  Type: CNAME
  Value: <alb-dns-name>
  TTL: 300
  ```

### 12.3 Test Custom Domain

```bash
# Wait for DNS propagation (1-5 minutes)
dig webapp.example.com

# Test HTTPS access
curl https://webapp.example.com
# Should return content without certificate warnings
```

---

## Step 13: Deploy Static Content

### 13.1 Prepare Static Content

Ensure static files are ready:
```
content/
├── index.html
├── css/
│   └── styles.css
├── js/
│   └── app.js
└── images/
    └── logo.png
```

### 13.2 Upload to S3

**Using AWS CLI**:
```bash
# Sync entire directory
aws s3 sync ./content/ s3://webapp-static-content-<suffix>/ \
  --delete \
  --region us-east-1

# Verify upload
aws s3 ls s3://webapp-static-content-<suffix>/ --recursive
```

**Using S3 Console**:
1. Navigate to S3 → `webapp-static-content-<suffix>`
2. Click "Upload"
3. Drag and drop files/folders
4. Upload

### 13.3 Sync Content to EC2 Instances

**Option A: Restart instances** (triggers user data sync):
```bash
# Terminate instances (ASG replaces automatically)
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id <instance-id> \
  --should-decrement-desired-capacity false
```

**Option B: Manual sync** (via Session Manager):
```bash
# Connect to each instance
aws ssm start-session --target <instance-id>

# Sync from S3
sudo aws s3 sync s3://webapp-static-content-<suffix>/ /usr/share/nginx/html/

# Reload Nginx
sudo systemctl reload nginx
```

### 13.4 Verify Content Delivery

```bash
# Test via ALB
curl https://webapp.example.com
# Should return your custom content

# Check specific files
curl https://webapp.example.com/css/styles.css
```

---

## Step 14: Monitoring and Maintenance

### 14.1 Monitor ALB Metrics

**CloudWatch Metrics** (AWS Console):
- `RequestCount`: Total requests
- `TargetResponseTime`: Latency
- `HealthyHostCount`: Healthy targets
- `UnHealthyHostCount`: Unhealthy targets

### 14.2 Monitor Auto Scaling Activity

**ASG Activity** (AWS Console → EC2 → Auto Scaling Groups):
- View scaling history
- Check scaling policies
- Monitor instance launches/terminations

### 14.3 Monitor Costs

**Cost Explorer**:
- Track infrastructure costs daily
- Expected baseline: $100-120/month
- Set budget alerts for overruns

### 14.4 Update Infrastructure

**Making Changes**:
1. Create new feature branch from `dev`
2. Make Terraform code changes
3. Commit and push
4. Test in ephemeral workspace
5. Merge to `dev` → `staging` → `main`

**Update Static Content**:
1. Upload new content to S3
2. Sync to EC2 instances (or restart)

---

## Troubleshooting

### Issue: ALB Targets Remain Unhealthy

**Symptoms**:
- Target group shows "unhealthy" status
- HTTP requests timeout or return 502/503

**Solutions**:
1. **Check Security Groups**:
   - EC2 SG must allow port 80 from ALB SG
   - ALB SG must allow egress to EC2 SG

2. **Verify Nginx is Running**:
   ```bash
   aws ssm start-session --target <instance-id>
   sudo systemctl status nginx
   sudo systemctl start nginx  # if not running
   ```

3. **Check Health Check Path**:
   - Ensure `/` or configured path exists and returns 200
   - `curl http://localhost/` from inside instance

4. **Review User Data Logs**:
   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```

### Issue: Cannot Access ALB DNS

**Symptoms**:
- DNS lookup fails
- Connection timeout

**Solutions**:
1. **Verify ALB is Active**:
   - Check AWS Console → Load Balancers
   - Status should be "active"

2. **Check Security Group**:
   - ALB SG must allow inbound 80 and 443 from `0.0.0.0/0`

3. **Verify Subnets**:
   - ALB must be in public subnets
   - Subnets must have route to Internet Gateway

### Issue: ACM Certificate Stuck in Pending

**Symptoms**:
- Certificate status: "Pending validation"
- HTTPS listener fails to create

**Solutions**:
1. **Check DNS Records**:
   - Verify CNAME validation records added to DNS
   - Wait 5-30 minutes for propagation

2. **Manual Validation**:
   ```bash
   dig _<validation-string>.<domain>.com CNAME
   # Should return ACM validation record
   ```

3. **Recreate Certificate** (if DNS correct but still pending):
   - Delete and recreate ACM certificate resource

### Issue: EC2 Instances Cannot Access S3

**Symptoms**:
- `aws s3 ls` fails with permission denied
- User data script fails to sync content

**Solutions**:
1. **Verify IAM Instance Profile**:
   - Instance must have attached instance profile
   - Role must have S3 read permissions

2. **Check S3 Bucket Policy**:
   - Bucket policy must allow IAM role
   - Verify role ARN matches

3. **Test from Instance**:
   ```bash
   aws sts get-caller-identity  # Verify role assumed
   aws s3 ls s3://bucket-name/  # Test access
   ```

### Issue: Auto Scaling Not Triggering

**Symptoms**:
- CPU high but no new instances launching
- Scale-in not removing excess instances

**Solutions**:
1. **Check Scaling Policy**:
   - Verify target tracking policy exists
   - Target value set correctly (50% CPU)

2. **Check CloudWatch Metrics**:
   - ASG must publish metrics
   - Verify CPU data is flowing

3. **Review Scaling Activity**:
   - Check scaling activity history for errors
   - Look for failures (capacity limits, unhealthy instances)

---

## Next Steps

### After Successful Dev Deployment

1. **Test Functionality**:
   - Verify all user stories from spec.md
   - Load test to validate performance goals
   - Test failure scenarios (instance termination, AZ failure)

2. **Documentation**:
   - Update README.md with deployment details
   - Document any customizations made
   - Add operational runbooks

3. **Promote to Staging**:
   - Merge `dev` → `staging` branch
   - Create staging workspace variables
   - Deploy and validate

4. **Production Deployment**:
   - Merge `staging` → `main` branch
   - Create production workspace variables (with production domain)
   - **Requires manual approval** per constitution
   - Deploy during maintenance window
   - Monitor closely post-deployment

---

## Cost Optimization Tips

1. **Use Reserved Instances** (after testing):
   - 1-year commitment can save 30-40%
   - Best for known baseline capacity

2. **Right-Size Instances** (after monitoring):
   - If t3.micro insufficient, consider t3.small
   - If underutilized, keep t3.micro

3. **Schedule ASG** (for non-production):
   - Scale down to 0 instances outside business hours
   - Saves ~70% for dev/test environments

4. **Enable S3 Intelligent-Tiering**:
   - Automatically moves objects to cheaper storage tiers

5. **Review CloudWatch Logs Retention**:
   - Set retention to 7-30 days for non-prod
   - Reduces CloudWatch Logs costs

---

## Security Best Practices

1. **Rotate AWS Credentials Regularly**:
   - Use dynamic credentials via workspace variable sets
   - No long-lived access keys

2. **Enable VPC Flow Logs** (production):
   - Audit network traffic
   - Detect suspicious activity

3. **Enable CloudTrail** (if not already):
   - Log all AWS API calls
   - Required for compliance audits

4. **Regular Security Scans**:
   - Pre-commit hooks run `tfsec` automatically
   - Review findings and remediate

5. **Patch Management**:
   - Keep Amazon Linux 2023 instances updated
   - User data includes `yum update -y`
   - Consider AWS Systems Manager Patch Manager

---

## Support and Resources

### Internal Resources

- **Platform Team**: Contact for module gaps or workspace issues
- **HCP Terraform Docs**: https://developer.hashicorp.com/terraform/cloud-docs
- **Organization**: https://app.terraform.io/app/hashi-demos-apj

### External Resources

- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **VPC Module Docs**: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
- **ALB Module Docs**: https://registry.terraform.io/modules/terraform-aws-modules/alb/aws
- **ASG Module Docs**: https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws

### Reporting Issues

- **Terraform Code Issues**: Create issue in repository
- **AWS Service Issues**: Check AWS Service Health Dashboard
- **HCP Terraform Issues**: Contact HashiCorp support

---

## Conclusion

This quickstart guide provides a complete workflow for deploying highly available web application infrastructure on AWS using HCP Terraform. Key accomplishments:

✅ VPC with multi-AZ high availability
✅ Application Load Balancer with HTTPS
✅ Auto Scaling EC2 instances
✅ S3-backed static content
✅ Security group least-privilege rules
✅ Automated testing in ephemeral workspace
✅ GitOps workflow with branch protection

**Estimated Time Spent**:
- Initial setup: 30 minutes
- Ephemeral testing: 15 minutes
- Dev deployment: 20 minutes
- DNS configuration: 10 minutes
- **Total**: ~75 minutes

**What's Next**: Run `/speckit.tasks` to generate detailed implementation tasks and begin actual Terraform code development.
