# Quickstart Guide: EC2 Development Instance

**Feature**: Public EC2 Development Instance with Password-Based SSH  
**Branch**: `001-ec2-dev-instance`  
**Estimated Time**: 15 minutes (includes 5-minute deployment)  
**Prerequisites**: AWS account, HCP Terraform workspace configured

---

## Overview

This guide walks you through deploying a fully configured EC2 development instance with password-based SSH authentication, security hardening, and CloudWatch monitoring.

**What You'll Deploy**:
- t3.micro EC2 instance running Amazon Linux 2023
- Password-authenticated SSH access via Elastic IP
- fail2ban intrusion prevention
- CloudWatch log streaming for authentication events
- AWS Systems Manager Session Manager backup access

**Cost**: ~$10/month (see cost breakdown section)

---

## Prerequisites Checklist

### AWS Account Requirements

- [ ] Active AWS account with payment method configured
- [ ] Access to us-east-1 region
- [ ] Default VPC exists in us-east-1 (created automatically with new accounts)
- [ ] Available Elastic IP quota (at least 1 of 5 default quota)

### HCP Terraform Requirements

- [ ] HCP Terraform account with organization `ravi-panchal-org`
- [ ] Workspace `sandbox_ec2_dev_instance` configured in `Default Project`
- [ ] Workspace connected to Git repository feature branch
- [ ] AWS dynamic credentials configured via workspace variable sets

### Local Development Requirements

- [ ] Git installed and configured
- [ ] Terraform CLI >= 1.5.0 installed
- [ ] AWS CLI >= 2.0 installed (for Session Manager access)
- [ ] SSH client installed (OpenSSH, PuTTY, or equivalent)
- [ ] Text editor or IDE

### Validation Commands

```bash
# Check Terraform version
terraform version
# Required: Terraform v1.5.0 or later

# Check AWS CLI version
aws --version
# Required: aws-cli/2.0.0 or later

# Check Git status
git --version
# Required: git version 2.0 or later

# Check SSH client
ssh -V
# Required: OpenSSH_7.0 or later
```

---

## Step 1: Repository Setup

### 1.1 Clone Repository (If Not Already Cloned)

```bash
# Clone the repository
git clone <repository-url>
cd <repository-name>

# Verify you're on the dev branch
git branch --show-current
# Expected: dev
```

### 1.2 Create Feature Branch

```bash
# Ensure you're on dev branch first
git checkout dev
git pull origin dev

# Create and switch to feature branch
git checkout -b 001-ec2-dev-instance

# Verify branch
git branch --show-current
# Expected: 001-ec2-dev-instance
```

---

## Step 2: Review Feature Specification

### 2.1 Read the Specification

```bash
# View the feature specification
cat specs/001-ec2-dev-instance/spec.md | less

# Key sections to review:
# - User Scenarios & Testing (acceptance criteria)
# - Requirements (FR-001 through FR-025)
# - Success Criteria (measurable outcomes)
# - Risk Assessment (security considerations)
```

### 2.2 Understand Key Requirements

**Critical Requirements**:
- **FR-001**: t3.micro instance in us-east-1 with Amazon Linux 2023
- **FR-007**: Username `devuser` with sudo privileges
- **FR-008**: Password authentication enabled (no SSH keys)
- **FR-011a**: Initial password set via Session Manager (NOT in code)
- **FR-014**: fail2ban configured to block brute-force attacks
- **FR-019**: CloudWatch agent streams SSH logs
- **FR-020**: 7-day log retention for cost optimization

---

## Step 3: Configure Variables

### 3.1 Review Variable Definitions

```bash
# View all available variables
cat variables.tf

# Key variables:
# - aws_region: Deployment region (default: us-east-1)
# - instance_type: EC2 instance size (default: t3.micro)
# - root_volume_size: Disk size in GB (default: 30)
# - environment: Environment tag (default: development)
# - project_name: Resource naming prefix
# - enable_monitoring: Detailed metrics (default: false)
# - ssh_allowed_cidr_blocks: SSH source IPs (default: 0.0.0.0/0)
```

### 3.2 Create or Update Sandbox Variables

```bash
# Copy example file if it doesn't exist
cp sandbox.auto.tfvars.example sandbox.auto.tfvars

# Edit variables for your deployment
vim sandbox.auto.tfvars
```

**Recommended Configuration** (`sandbox.auto.tfvars`):

```hcl
# AWS Configuration
aws_region = "us-east-1"

# Instance Configuration
instance_type    = "t3.micro"
root_volume_size = 30  # GB

# Environment and Project
environment  = "sandbox"
project_name = "ec2-dev-instance"

# Monitoring
enable_monitoring = false  # Keep false to save $2/month

# Security - SSH Access
# SECURITY WARNING: 0.0.0.0/0 allows access from anywhere
# Consider restricting to your office/VPN IP range for better security
ssh_allowed_cidr_blocks = ["0.0.0.0/0"]

# Additional Tags
additional_tags = {
  Owner      = "your-email@example.com"
  Team       = "Platform Engineering"
  CostCenter = "Development"
}
```

### 3.3 (Optional) Restrict SSH Access

**For Enhanced Security**:

```hcl
# Option 1: Single IP address
ssh_allowed_cidr_blocks = ["203.0.113.45/32"]

# Option 2: Office network range
ssh_allowed_cidr_blocks = ["198.51.100.0/24"]

# Option 3: Multiple locations
ssh_allowed_cidr_blocks = [
  "203.0.113.45/32",    # Home office
  "198.51.100.0/24",    # Company office
  "192.0.2.100/32"      # VPN endpoint
]
```

**Get Your Current IP**:
```bash
curl -s https://checkip.amazonaws.com
# Returns: 203.0.113.45
```

---

## Step 4: Initialize Terraform

### 4.1 Configure Terraform Cloud Credentials

```bash
# Set HCP Terraform token environment variable
export TFE_TOKEN="your-hcp-terraform-token"

# Create Terraform CLI configuration
mkdir -p ~/.terraform.d && cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "${TFE_TOKEN}"
    }
  }
}
EOF
```

**Get Your Token**:
1. Visit https://app.terraform.io/app/settings/tokens
2. Generate new API token
3. Copy token and set in environment variable

### 4.2 Initialize TFLint and Pre-Commit

```bash
# Initialize TFLint for code quality checks
echo "Initializing TFLint..."
tflint --init

# Install pre-commit hooks (if available)
if command -v pre-commit &> /dev/null; then
  echo "Installing pre-commit hooks..."
  pre-commit install
else
  echo "Pre-commit not available - skipping (optional)"
fi
```

### 4.3 Initialize Terraform

```bash
# Initialize Terraform providers and backend
terraform init

# Expected output:
# Initializing Terraform Cloud...
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0.0"...
# - Installing hashicorp/aws v5.0.x...
# Terraform has been successfully initialized!
```

**Troubleshooting**:

```bash
# If backend configuration fails
terraform init -reconfigure

# If provider download fails
terraform init -upgrade
```

---

## Step 5: Validate Configuration

### 5.1 Run Terraform Validate

```bash
# Check syntax and configuration
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### 5.2 Check Formatting

```bash
# Verify Terraform code formatting
terraform fmt -check -recursive

# If changes needed, auto-format:
terraform fmt -recursive
```

### 5.3 Run TFLint

```bash
# Run linting checks
tflint

# Expected output:
# No issues found
```

### 5.4 Run Pre-Commit Checks

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Expected output:
# Terraform fmt............................................................Passed
# Terraform validate.......................................................Passed
# TFLint...................................................................Passed
```

---

## Step 6: Review Deployment Plan

### 6.1 Generate Terraform Plan

```bash
# Create execution plan
terraform plan -out=plan.tfplan

# Review the plan output carefully
# Expected resources to be created:
# - aws_instance.dev (EC2 instance)
# - aws_eip.dev_instance (Elastic IP)
# - aws_security_group.ec2_dev_ssh (Security group)
# - aws_iam_role.ec2_ssm_role (IAM role)
# - aws_iam_role_policy_attachment.ssm_managed_instance_core (Policy)
# - aws_iam_instance_profile.ec2_profile (Instance profile)
# - aws_cloudwatch_log_group.ssh_auth_logs (Log group)
# - data.aws_vpc.default (VPC lookup)
# - data.aws_subnets.public (Subnet lookup)
# - data.aws_ami.amazon_linux_2023 (AMI lookup)
```

### 6.2 Key Plan Validation Points

**Verify These Attributes**:

```
# EC2 Instance
  + instance_type          = "t3.micro"
  + ami                    = <latest AL2023 AMI>
  + monitoring             = false
  + vpc_security_group_ids = [<security group ID>]
  + iam_instance_profile   = <instance profile name>

# Security Group
  + ingress {
      + cidr_blocks      = ["0.0.0.0/0"]  # Or your restricted CIDR
      + from_port        = 22
      + to_port          = 22
      + protocol         = "tcp"
    }

# CloudWatch Log Group
  + name              = "/aws/ec2/dev-instance/ssh-auth"
  + retention_in_days = 7

# IAM Role Policy Attachment
  + policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
```

### 6.3 Cost Estimation

**Review Estimated Costs**:

```bash
# Terraform Cloud workspaces show cost estimates in the plan output
# Look for:
# - Monthly cost: ~$10.40
# - t3.micro instance: $7.50
# - EBS gp3 30GB: $2.40
# - CloudWatch Logs: ~$0.50
```

---

## Step 7: Deploy Infrastructure

### 7.1 Apply Terraform Configuration

```bash
# Apply the planned changes
terraform apply plan.tfplan

# Deployment will take approximately 3-5 minutes
# Progress indicators:
# - Creating IAM resources... (30 seconds)
# - Creating security group... (20 seconds)
# - Creating CloudWatch log group... (10 seconds)
# - Launching EC2 instance... (90 seconds)
# - Attaching Elastic IP... (15 seconds)
# - Executing user-data script... (2-3 minutes)
```

### 7.2 Monitor Deployment Progress

**In AWS Console**:
1. Navigate to EC2 → Instances
2. Find instance tagged with `Project=ec2-dev-instance`
3. Status checks: Wait until "2/2 checks passed"
4. System log: EC2 Console → Actions → Monitor and troubleshoot → Get system log

**Check User-Data Execution**:
```bash
# User-data runs asynchronously after instance launch
# Allow 3-5 minutes for complete execution
# (fail2ban, CloudWatch agent, SSH configuration)
```

### 7.3 Save Deployment Outputs

```bash
# Display all outputs
terraform output

# Save specific outputs for later use
echo "INSTANCE_ID=$(terraform output -raw instance_id)" >> ~/.bashrc
echo "INSTANCE_IP=$(terraform output -raw instance_public_ip)" >> ~/.bashrc
source ~/.bashrc

# Display convenient connection commands
terraform output ssh_connection_command
terraform output session_manager_command
```

**Example Output**:
```
instance_id              = "i-0123456789abcdef0"
instance_public_ip       = "203.0.113.45"
instance_private_ip      = "172.31.32.100"
security_group_id        = "sg-0abcdef1234567890"
iam_role_arn            = "arn:aws:iam::123456789012:role/ec2-dev-instance-ssm-role"
log_group_name          = "/aws/ec2/dev-instance/ssh-auth"
ssh_connection_command  = "ssh devuser@203.0.113.45"
session_manager_command = "aws ssm start-session --target i-0123456789abcdef0"
```

---

## Step 8: Configure Initial Password

**CRITICAL**: SSH access requires setting the `devuser` password first. This is intentionally NOT automated to avoid storing credentials in Terraform state.

### 8.1 Connect via Session Manager

```bash
# Connect using AWS CLI
aws ssm start-session --target $(terraform output -raw instance_id)

# If AWS CLI not configured for SSM:
aws configure set region us-east-1
aws configure set output json

# Alternative: Use AWS Console
# 1. Navigate to Systems Manager → Session Manager
# 2. Click "Start session"
# 3. Select instance ID (shown in terraform output)
# 4. Click "Start session"
```

### 8.2 Set Password for devuser

**In Session Manager Terminal**:

```bash
# Switch to root (Session Manager starts as ssm-user)
sudo su -

# Set password for devuser
passwd devuser

# You'll be prompted:
# New password: [enter 14+ character password with complexity]
# Retype new password: [confirm password]

# Successful output:
# passwd: all authentication tokens updated successfully
```

**Password Requirements**:
- Minimum 14 characters
- At least 1 uppercase letter (A-Z)
- At least 1 lowercase letter (a-z)
- At least 1 digit (0-9)
- At least 1 special character (!@#$%^&*...)
- Maximum 2 repeating characters
- Must NOT contain username

**Example Strong Password**:
```
DevUser2025!Secure#
```

### 8.3 Verify Password Configuration

```bash
# Still in Session Manager as root

# Check password expiry settings
chage -l devuser

# Expected output:
# Last password change                    : Jan 12, 2025
# Password expires                        : Apr 12, 2025  (90 days)
# Password inactive                       : never
# Account expires                         : never
# Minimum number of days between password change : 1
# Maximum number of days between password change : 90
# Number of days of warning before password expires : 7

# Verify sudo privileges
su - devuser
sudo whoami
# Expected: root

# Exit Session Manager
exit  # exit devuser
exit  # exit root
exit  # close session
```

---

## Step 9: Test SSH Access

### 9.1 Wait for User-Data Completion

```bash
# Wait 5 minutes after "terraform apply" completes
# This ensures:
# - fail2ban installation complete
# - SSH configuration applied
# - CloudWatch agent started

# Check instance readiness
aws ec2 describe-instance-status \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'InstanceStatuses[0].InstanceStatus.Status' \
  --output text

# Expected: ok
```

### 9.2 Attempt SSH Connection

```bash
# Use the SSH command from terraform output
ssh devuser@$(terraform output -raw instance_public_ip)

# You'll see:
# The authenticity of host '203.0.113.45 (203.0.113.45)' can't be established.
# ED25519 key fingerprint is SHA256:...
# Are you sure you want to continue connecting (yes/no/[fingerprint])? yes

# Enter the password you set in Step 8.2

# Successful connection:
# Warning: Permanently added '203.0.113.45' (ED25519) to the list of known hosts.
# devuser@203.0.113.45's password: [enter password]
#    ,     #_
#    ~\_  ####_        Amazon Linux 2023
#   ~~  \_#####\
#   ~~     \###|
#   ~~       \#/ ___   https://aws.amazon.com/linux/amazon-linux-2023
#    ~~       V~' '->
#     ~~~         /
#       ~~._.   _/
#          _/ _/
#        _/m/'
# 
# Last login: Sun Jan 12 10:30:45 2025 from 198.51.100.123
# [devuser@ip-172-31-32-100 ~]$
```

### 9.3 Verify Instance Configuration

**Run These Commands in SSH Session**:

```bash
# Check fail2ban status
sudo systemctl status fail2ban
# Expected: active (running)

# Check CloudWatch agent status
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a query -m ec2 -c default -s
# Expected: "status": "running"

# Verify SSH configuration
grep "^PasswordAuthentication" /etc/ssh/sshd_config
# Expected: PasswordAuthentication yes

grep "^PubkeyAuthentication" /etc/ssh/sshd_config
# Expected: PubkeyAuthentication no

grep "^PermitRootLogin" /etc/ssh/sshd_config
# Expected: PermitRootLogin no

# Check sudo access
sudo whoami
# Expected: root

# Check disk space
df -h /
# Expected: 30G total

# Check instance type
curl -s http://169.254.169.254/latest/meta-data/instance-type
# Expected: t3.micro

# Exit SSH session
exit
```

---

## Step 10: Verify Monitoring

### 10.1 Check CloudWatch Logs

```bash
# List log streams (should show your instance ID)
aws logs describe-log-streams \
  --log-group-name $(terraform output -raw log_group_name) \
  --query 'logStreams[0].logStreamName' \
  --output text

# Expected: i-0123456789abcdef0

# Tail SSH authentication logs
aws logs tail $(terraform output -raw log_group_name) --follow

# You should see logs like:
# 2025-01-12T10:30:45+00:00 i-0123456789abcdef0 Accepted password for devuser from 198.51.100.123 port 54321 ssh2
```

### 10.2 Test fail2ban Protection

**WARNING**: This will temporarily lock you out from your current IP. Only proceed if you have alternative access (different IP or Session Manager).

```bash
# From a different workstation/IP (or use a proxy)
# Attempt 6 failed SSH logins

for i in {1..6}; do
  sshpass -p "WrongPassword123" ssh devuser@$(terraform output -raw instance_public_ip) 2>&1 | grep -i "permission denied"
  sleep 2
done

# After 5 failed attempts, 6th attempt should timeout or be refused
# Expected on 6th attempt:
# ssh: connect to host 203.0.113.45 port 22: Connection refused
# OR
# ssh: connect to host 203.0.113.45 port 22: Connection timed out
```

**Verify Ban in CloudWatch Logs**:
```bash
aws logs tail $(terraform output -raw log_group_name) --since 5m

# Expected log entries:
# Failed password for devuser from 198.51.100.100 port 58392 ssh2
# Failed password for devuser from 198.51.100.100 port 58393 ssh2
# ... (5 total failed attempts)
```

**Check fail2ban Status** (via Session Manager):
```bash
aws ssm start-session --target $(terraform output -raw instance_id)
sudo fail2ban-client status sshd

# Expected output:
# Status for the jail: sshd
# |- Filter
# |  |- Currently failed: 0
# |  |- Total failed:     5
# |  `- File list:        /var/log/secure
# `- Actions
#    |- Currently banned: 1
#    |- Total banned:     1
#    `- Banned IP list:   198.51.100.100
```

### 10.3 Check CloudWatch Metrics

**In AWS Console**:
1. Navigate to CloudWatch → Metrics → EC2 → Per-Instance Metrics
2. Select instance ID from terraform output
3. Select metrics:
   - `CPUUtilization` (should be low, <10% for idle instance)
   - `NetworkIn` (bytes received)
   - `NetworkOut` (bytes sent)

**Via AWS CLI**:
```bash
# Get CPU utilization (last 5 minutes)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$(terraform output -raw instance_id) \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --query 'Datapoints[0].Average'

# Expected: 1-5% (low CPU usage for idle instance)
```

---

## Step 11: Cost Monitoring Setup

### 11.1 Create AWS Budget

```bash
# Set budget alert at $40 (80% of $50 budget)
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json

# budget.json content:
cat > budget.json <<EOF
{
  "BudgetName": "ec2-dev-instance-budget",
  "BudgetLimit": {
    "Amount": "50",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "TagKeyValue": ["user:Project\$ec2-dev-instance"]
  }
}
EOF
```

### 11.2 Review Current Costs

```bash
# Check current month-to-date costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://cost-filter.json

# cost-filter.json content:
cat > cost-filter.json <<EOF
{
  "Tags": {
    "Key": "Project",
    "Values": ["ec2-dev-instance"]
  }
}
EOF
```

### 11.3 Expected Cost Breakdown

| Service | Resource | Monthly Cost |
|---------|----------|--------------|
| EC2 | t3.micro instance (730 hours) | $7.50 |
| EBS | gp3 30GB volume | $2.40 |
| EC2 | Elastic IP (attached) | $0.00 |
| CloudWatch | Logs ingestion (~200 MB) | $0.10 |
| CloudWatch | Logs storage (7-day retention) | $0.01 |
| CloudWatch | Basic monitoring | $0.00 |
| Data Transfer | Outbound (<1 GB) | $0.09 |
| **Total** | | **~$10.10/month** |

---

## Step 12: Document and Commit

### 12.1 Update Documentation

```bash
# Create deployment notes
cat > DEPLOYMENT_NOTES.md <<EOF
# EC2 Dev Instance Deployment

**Deployed**: $(date)
**Instance ID**: $(terraform output -raw instance_id)
**Public IP**: $(terraform output -raw instance_public_ip)
**SSH Command**: $(terraform output -raw ssh_connection_command)
**Session Manager**: $(terraform output -raw session_manager_command)

## Access Information
- Username: devuser
- Password: [Stored in password manager]
- SSH Port: 22
- Security: fail2ban enabled (5 attempts/10 min = 1 hour block)

## Monitoring
- CloudWatch Log Group: $(terraform output -raw log_group_name)
- Log Retention: 7 days
- Basic Metrics: Enabled (5-minute intervals)

## Maintenance
- Password Expiry: Every 90 days (set $(date))
- Next Password Change: $(date -d '+90 days' +%Y-%m-%d)
- OS Patching: Manual (not automated)

## Cost
- Estimated: \$10/month
- Budget Alert: \$40 threshold
EOF
```

### 12.2 Commit Terraform Code

```bash
# Check status
git status

# Add all Terraform files
git add main.tf variables.tf outputs.tf providers.tf versions.tf
git add override.tf sandbox.auto.tfvars
git add specs/001-ec2-dev-instance/

# Commit with descriptive message
git commit -m "feat: implement EC2 dev instance with password SSH

- Provisions t3.micro instance in us-east-1
- Configures password-only SSH authentication for devuser
- Implements fail2ban intrusion prevention (5 attempts/10 min)
- Sets up CloudWatch logging with 7-day retention
- Enables Session Manager for emergency access
- Deploys with Elastic IP for consistent access

Refs: specs/001-ec2-dev-instance/spec.md
Cost: ~\$10/month estimated
Security: Development environment only (not production-ready)"

# Push to remote
git push origin 001-ec2-dev-instance
```

### 12.3 Create Pull Request

**Via GitHub Web Interface**:
1. Navigate to repository on GitHub
2. Click "Compare & pull request" for `001-ec2-dev-instance` branch
3. Title: `feat: EC2 development instance with password SSH`
4. Description:
   ```markdown
   ## Summary
   Implements public EC2 development instance with password-based SSH authentication.
   
   ## Changes
   - EC2 t3.micro instance with Amazon Linux 2023
   - Password-only SSH access (devuser account)
   - fail2ban intrusion prevention
   - CloudWatch log streaming (7-day retention)
   - AWS Systems Manager Session Manager fallback
   - Elastic IP for consistent access
   
   ## Testing
   - [x] Terraform validate passed
   - [x] TFLint checks passed
   - [x] Pre-commit hooks passed
   - [x] Infrastructure deployed successfully
   - [x] SSH access verified with password authentication
   - [x] fail2ban tested and working
   - [x] CloudWatch logs streaming successfully
   - [x] Session Manager access confirmed
   
   ## Security Notes
   - Development environment only (NOT production-ready)
   - Public SSH access (0.0.0.0/0) - documented risk
   - Password complexity enforced (14+ chars, 4 classes)
   - 90-day password rotation policy
   
   ## Cost
   - Estimated: $10/month
   - Within budget: Yes ($50 ceiling)
   
   ## Documentation
   - Spec: `specs/001-ec2-dev-instance/spec.md`
   - Data Model: `specs/001-ec2-dev-instance/data-model.md`
   - Contract: `specs/001-ec2-dev-instance/contracts/terraform-interface.md`
   - Quickstart: `specs/001-ec2-dev-instance/quickstart.md`
   ```
5. Assign reviewers: Platform team members
6. Labels: `infrastructure`, `development`, `security-reviewed`
7. Click "Create pull request"

---

## Troubleshooting

### SSH Connection Refused

**Symptoms**:
```
ssh: connect to host 203.0.113.45 port 22: Connection refused
```

**Possible Causes & Solutions**:

1. **User-data script still running** (most common)
   ```bash
   # Wait 5 minutes after terraform apply completes
   # Check instance status logs via Session Manager
   aws ssm start-session --target $(terraform output -raw instance_id)
   tail -f /var/log/cloud-init-output.log
   ```

2. **Security group not allowing your IP**
   ```bash
   # Check your current IP
   curl -s https://checkip.amazonaws.com
   
   # Verify security group rules
   aws ec2 describe-security-groups \
     --group-ids $(terraform output -raw security_group_id) \
     --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'
   
   # If needed, update ssh_allowed_cidr_blocks in sandbox.auto.tfvars
   # and run terraform apply again
   ```

3. **fail2ban blocked your IP**
   ```bash
   # Connect via Session Manager
   aws ssm start-session --target $(terraform output -raw instance_id)
   
   # Check banned IPs
   sudo fail2ban-client status sshd
   
   # Unban your IP
   sudo fail2ban-client set sshd unbanip YOUR_IP_ADDRESS
   ```

---

### Password Authentication Failed

**Symptoms**:
```
Permission denied (publickey,password).
```

**Possible Causes & Solutions**:

1. **Password not set yet**
   ```bash
   # Set password via Session Manager (see Step 8)
   aws ssm start-session --target $(terraform output -raw instance_id)
   sudo passwd devuser
   ```

2. **Incorrect password**
   ```bash
   # Reset password via Session Manager
   aws ssm start-session --target $(terraform output -raw instance_id)
   sudo passwd devuser
   ```

3. **SSH configuration issue**
   ```bash
   # Connect via Session Manager and check SSH config
   aws ssm start-session --target $(terraform output -raw instance_id)
   grep "^PasswordAuthentication" /etc/ssh/sshd_config
   # Should show: PasswordAuthentication yes
   
   # If not, re-run user-data script or manually edit
   sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```

---

### Session Manager Connection Failed

**Symptoms**:
```
An error occurred (TargetNotConnected) when calling the StartSession operation
```

**Possible Causes & Solutions**:

1. **SSM agent not running**
   ```bash
   # Check instance status in AWS Console
   # Systems Manager → Fleet Manager → Node not showing?
   
   # Verify IAM instance profile attached
   aws ec2 describe-instances \
     --instance-ids $(terraform output -raw instance_id) \
     --query 'Reservations[0].Instances[0].IamInstanceProfile'
   
   # Should show: ec2-dev-instance-profile
   ```

2. **IAM permissions issue**
   ```bash
   # Verify IAM role policy attachment
   aws iam list-attached-role-policies \
     --role-name ec2-dev-instance-ssm-role
   
   # Should show: AmazonSSMManagedInstanceCore
   ```

3. **Network connectivity issue**
   ```bash
   # Instance must reach SSM endpoints
   # Check security group allows outbound HTTPS (443)
   aws ec2 describe-security-groups \
     --group-ids $(terraform output -raw security_group_id) \
     --query 'SecurityGroups[0].IpPermissionsEgress'
   
   # Should allow 0.0.0.0/0 on all protocols
   ```

---

### CloudWatch Logs Not Appearing

**Symptoms**:
No log streams or events in CloudWatch Logs group.

**Possible Causes & Solutions**:

1. **CloudWatch agent not running**
   ```bash
   # Connect via Session Manager
   aws ssm start-session --target $(terraform output -raw instance_id)
   
   # Check agent status
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
     -a query -m ec2 -c default -s
   
   # If stopped, start agent
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
     -a fetch-config -m ec2 -s \
     -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
   ```

2. **IAM permissions missing**
   ```bash
   # Verify instance profile has CloudWatch Logs permissions
   # (Included in AmazonSSMManagedInstanceCore managed policy)
   aws iam get-role-policy \
     --role-name ec2-dev-instance-ssm-role \
     --policy-name CloudWatchLogsPolicy
   ```

3. **Log group not created**
   ```bash
   # Verify log group exists
   aws logs describe-log-groups \
     --log-group-name-prefix /aws/ec2/dev-instance
   
   # If missing, create manually or re-run terraform apply
   terraform apply -target=aws_cloudwatch_log_group.ssh_auth_logs
   ```

---

### High Costs

**Symptoms**:
AWS bill higher than expected $10/month.

**Possible Causes & Solutions**:

1. **Detailed monitoring enabled**
   ```bash
   # Check monitoring setting
   aws ec2 describe-instances \
     --instance-ids $(terraform output -raw instance_id) \
     --query 'Reservations[0].Instances[0].Monitoring.State'
   
   # Should be: disabled
   # If enabled, set enable_monitoring = false and re-apply
   ```

2. **Instance stopped with attached EIP**
   ```bash
   # Elastic IP charges $0.01/hour when instance is stopped
   # Always keep instance running or release EIP
   
   # Check instance state
   aws ec2 describe-instances \
     --instance-ids $(terraform output -raw instance_id) \
     --query 'Reservations[0].Instances[0].State.Name'
   
   # Should be: running
   ```

3. **Large log volume**
   ```bash
   # Check log ingestion volume
   aws logs describe-log-groups \
     --log-group-name-prefix /aws/ec2/dev-instance \
     --query 'logGroups[0].storedBytes'
   
   # Should be < 200 MB
   # If higher, check for excessive authentication attempts
   ```

---

## Maintenance

### Password Rotation (Every 90 Days)

```bash
# Connect via SSH
ssh devuser@$(terraform output -raw instance_public_ip)

# Change password (will prompt for current password)
passwd

# Enter current password, then new password twice
# New password must meet complexity requirements (14+ chars, 4 classes)

# Verify new expiry date
chage -l devuser

# Update documentation with new password change date
```

### OS Security Patching

```bash
# Connect via SSH
ssh devuser@$(terraform output -raw instance_public_ip)

# Update all packages
sudo yum update -y

# Reboot if kernel updated
sudo reboot

# Reconnect after 2-3 minutes
ssh devuser@$(terraform output -raw instance_public_ip)

# Verify updates applied
sudo yum history
```

### Instance Resize (If Needed)

```bash
# Update instance type in sandbox.auto.tfvars
# Example: upgrade to t3.small for more resources
instance_type = "t3.small"

# Plan and apply changes
terraform plan -out=resize.tfplan
terraform apply resize.tfplan

# WARNING: This will REPLACE the instance
# - All data on root volume will be LOST
# - Password must be reset via Session Manager
# - New Elastic IP will be assigned (update firewall rules)
```

---

## Cleanup / Teardown

### When No Longer Needed

```bash
# Destroy all infrastructure
terraform destroy

# Review resources to be destroyed:
# - EC2 instance
# - Elastic IP
# - Security group
# - IAM role and policies
# - CloudWatch log group (ALL LOGS DELETED)

# Confirm destruction
# Type: yes

# Expected duration: 1-2 minutes

# Verify cleanup
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=ec2-dev-instance" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'

# Should return empty list

# Delete feature branch (after PR merged)
git checkout dev
git branch -d 001-ec2-dev-instance
git push origin --delete 001-ec2-dev-instance
```

---

## Next Steps

### After Successful Deployment

1. **Security Hardening** (Optional):
   - Restrict SSH CIDR blocks to known IPs
   - Enable CloudWatch alarms for unusual activity
   - Set up SNS notifications for failed login attempts

2. **Development Usage**:
   - Install development tools (git, docker, etc.)
   - Configure application environments
   - Set up persistent data volumes if needed

3. **Monitoring**:
   - Review CloudWatch logs weekly
   - Monitor costs via AWS Cost Explorer
   - Set up CloudWatch dashboards for instance metrics

4. **Documentation**:
   - Add instance details to team wiki
   - Document custom configurations
   - Share SSH access procedures with team

---

## Getting Help

### Resources

- **Feature Specification**: `specs/001-ec2-dev-instance/spec.md`
- **Data Model**: `specs/001-ec2-dev-instance/data-model.md`
- **API Contract**: `specs/001-ec2-dev-instance/contracts/terraform-interface.md`
- **Implementation Plan**: `specs/001-ec2-dev-instance/plan.md`

### Support Channels

- **Platform Team**: platform-team@example.com
- **Terraform Issues**: Create issue in repository
- **Security Incidents**: Follow organizational incident response procedures
- **AWS Support**: Via AWS Console (if applicable support plan)

---

## Summary

**You've Successfully Deployed**:
- ✅ EC2 t3.micro instance in us-east-1
- ✅ Password-based SSH authentication (devuser)
- ✅ fail2ban intrusion prevention
- ✅ CloudWatch log streaming (7-day retention)
- ✅ Session Manager emergency access
- ✅ Elastic IP for consistent connectivity

**Estimated Cost**: ~$10/month  
**Deployment Time**: 15 minutes (including setup)  
**Next Password Change**: 90 days from today

**Remember**: This is a **development environment only**. Not suitable for production workloads or compliance-regulated data.
