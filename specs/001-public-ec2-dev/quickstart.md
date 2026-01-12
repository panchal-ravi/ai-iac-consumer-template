# Quick Start Guide: Public EC2 Development Instance

**Feature**: Public EC2 Instance for Development Environment  
**Branch**: `001-public-ec2-dev`  
**Date**: 2026-01-12

---

## Overview

This guide will help you:
1. Provision the EC2 development instance using HCP Terraform
2. Retrieve SSH credentials from AWS Secrets Manager
3. Connect to the instance via SSH with password authentication
4. Monitor the instance using CloudWatch

**Estimated Time**: 10 minutes

---

## Prerequisites

Before you begin, ensure you have:

- [ ] **AWS Account Access**: Permissions to view EC2, Secrets Manager, and CloudWatch
- [ ] **HCP Terraform Access**: Access to workspace `sandbox_workspace` in organization `ravi-panchal-org`
- [ ] **AWS CLI Installed**: Version 2.x or later ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- [ ] **AWS CLI Configured**: Valid credentials configured (`aws configure`)
- [ ] **SSH Client**: Available on your machine (built-in on macOS/Linux, use PuTTY on Windows)
- [ ] **Internet Connection**: To access the EC2 instance via public IP

### Verify Prerequisites

```bash
# Check AWS CLI installation and credentials
aws --version
aws sts get-caller-identity

# Expected output: Your AWS account ID and user/role ARN
```

---

## Step 1: Provision Infrastructure via HCP Terraform

### 1.1 Trigger Terraform Run

**Option A: Via HCP Terraform Web UI**
1. Navigate to [HCP Terraform](https://app.terraform.io/)
2. Select organization: `ravi-panchal-org`
3. Select workspace: `sandbox_workspace`
4. Click **Actions** → **Start new run**
5. Select **Plan and apply**
6. Add message: "Provisioning public EC2 dev instance (Issue #12)"
7. Click **Start run**

**Option B: Via Terraform CLI (if VCS-driven)**
```bash
# From repository root
git checkout 001-public-ec2-dev
git pull origin 001-public-ec2-dev

# Push changes (if any) to trigger run
git push origin 001-public-ec2-dev
```

**Option C: Via Terraform Cloud API**
```bash
# Set environment variables
export TFE_TOKEN="your-terraform-cloud-token"
export TFE_ORG="ravi-panchal-org"
export TFE_WORKSPACE="sandbox_workspace"

# Trigger run via API (requires curl and jq)
curl \
  --header "Authorization: Bearer $TFE_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data '{
    "data": {
      "type": "runs",
      "attributes": {
        "message": "Provisioning public EC2 dev instance (Issue #12)"
      },
      "relationships": {
        "workspace": {
          "data": {
            "type": "workspaces",
            "id": "'"$(terraform workspace show)"'"
          }
        }
      }
    }
  }' \
  https://app.terraform.io/api/v2/runs
```

### 1.2 Monitor Terraform Run

1. Wait for **Plan** phase to complete (~30 seconds)
2. Review plan output:
   - ✅ Resources to add: ~8-10 (EC2, security group, secrets, IAM role, etc.)
   - ⚠️ Resources to change: 0
   - ❌ Resources to destroy: 0
3. Confirm and **Apply** if plan looks correct
4. Wait for **Apply** phase to complete (~2-3 minutes)

### 1.3 Retrieve Terraform Outputs

Once the apply completes successfully, retrieve outputs:

**Via HCP Terraform UI:**
1. Navigate to the workspace → **Outputs** tab
2. Copy the following values:
   - `instance_id`: EC2 instance identifier (e.g., `i-0123456789abcdef`)
   - `instance_public_ip`: Public IP address (e.g., `54.255.100.50`)
   - `ssh_secret_arn`: Secrets Manager ARN (e.g., `arn:aws:secretsmanager:ap-southeast-1:...`)

**Via Terraform CLI (if using remote backend):**
```bash
terraform output instance_id
terraform output instance_public_ip
terraform output ssh_secret_arn
```

**Expected Output:**
```
instance_id = "i-0123456789abcdef"
instance_public_ip = "54.255.100.50"
security_group_id = "sg-0987654321fedcba"
ssh_secret_arn = "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:dev-ec2-ssh-password-AbCdEf"
```

---

## Step 2: Retrieve SSH Password from Secrets Manager

### 2.1 Using AWS CLI

The SSH password is stored securely in AWS Secrets Manager. Retrieve it using the AWS CLI:

```bash
# Set the secret ARN (from Terraform outputs)
SECRET_ARN="arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:dev-ec2-ssh-password-AbCdEf"

# Retrieve the password
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region ap-southeast-1 \
  --query SecretString \
  --output text
```

**Expected Output:**
```
Xy7#mK9$pQ2!nR8@vL5^wT3&hJ6*fG4%
```

### 2.2 Using AWS Console

1. Navigate to [AWS Secrets Manager Console](https://console.aws.amazon.com/secretsmanager/)
2. Ensure region is set to **ap-southeast-1** (Singapore)
3. Search for secret: `dev-ec2-ssh-password`
4. Click on the secret name
5. Scroll to **Secret value** section
6. Click **Retrieve secret value**
7. Copy the password (plain text)

### 2.3 Store Password Securely

⚠️ **Security Best Practice**: Do not save the password in plain text files or share via email/chat.

**Recommended Options:**
- Store in a password manager (1Password, LastPass, etc.)
- Store in environment variable (temporary session):
  ```bash
  export EC2_PASSWORD="<password-from-secrets-manager>"
  ```

---

## Step 3: Connect to EC2 Instance via SSH

### 3.1 SSH Connection (Linux/macOS)

```bash
# Set variables (from Step 1 outputs and Step 2)
INSTANCE_IP="54.255.100.50"
SSH_PASSWORD="<password-from-secrets-manager>"

# Connect via SSH
ssh ec2-user@$INSTANCE_IP

# When prompted for password, enter the SSH password
# (or use environment variable)
```

**Interactive Session:**
```
$ ssh ec2-user@54.255.100.50
ec2-user@54.255.100.50's password: [enter password]

   ,     #_
   ~\_  ####_        Amazon Linux 2023
  ~~  \_#####\
  ~~     \###|
  ~~       \#/ ___   https://aws.amazon.com/linux/amazon-linux-2023
   ~~       V~' '->
    ~~~         /
      ~~._.   _/
         _/ _/
       _/m/'

Last login: Sun Jan 12 14:30:00 2026 from 203.0.113.45
[ec2-user@ip-172-31-10-100 ~]$
```

### 3.2 SSH Connection (Windows - PuTTY)

1. Download and install [PuTTY](https://www.putty.org/)
2. Open PuTTY
3. Configuration:
   - **Host Name**: `ec2-user@54.255.100.50`
   - **Port**: `22`
   - **Connection Type**: `SSH`
4. Click **Open**
5. If prompted about host key, click **Accept**
6. Enter password when prompted

### 3.3 SSH Connection with sshpass (Non-Interactive)

⚠️ **Not recommended for production** (password exposed in process list)

```bash
# Install sshpass (if not already installed)
# macOS: brew install hudochenkov/sshpass/sshpass
# Linux: sudo apt-get install sshpass

# Connect without interactive password prompt
sshpass -p "$EC2_PASSWORD" ssh -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP
```

### 3.4 Verify Connection

Once connected, verify the environment:

```bash
# Check OS version
cat /etc/os-release

# Expected output:
# NAME="Amazon Linux"
# VERSION="2023"
# ID="amzn"
# ...

# Check instance metadata
curl -s http://169.254.169.254/latest/meta-data/instance-id
# Output: i-0123456789abcdef

# Check instance type
curl -s http://169.254.169.254/latest/meta-data/instance-type
# Output: t3.micro

# Check public IP
curl -s http://169.254.169.254/latest/meta-data/public-ipv4
# Output: 54.255.100.50
```

---

## Step 4: Monitor Instance (Optional)

### 4.1 CloudWatch Metrics via AWS Console

1. Navigate to [AWS CloudWatch Console](https://console.aws.amazon.com/cloudwatch/)
2. Ensure region is set to **ap-southeast-1** (Singapore)
3. In left sidebar, click **Metrics** → **All metrics**
4. Click **EC2** → **Per-Instance Metrics**
5. Search for your instance ID: `i-0123456789abcdef`
6. Select metrics to view:
   - `CPUUtilization`
   - `NetworkIn` / `NetworkOut`
   - `DiskReadBytes` / `DiskWriteBytes`
   - `StatusCheckFailed`

**Note**: Metrics update every **5 minutes** (basic monitoring).

### 4.2 CloudWatch Metrics via AWS CLI

```bash
# Get CPU utilization for the last hour
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-0123456789abcdef \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region ap-southeast-1
```

### 4.3 Instance Status via AWS CLI

```bash
# Check instance status
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef \
  --region ap-southeast-1 \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,InstanceType]' \
  --output table

# Expected output:
# ---------------------------------
# |      DescribeInstances        |
# +--------------+----------------+
# |  i-0123456789abcdef           |
# |  running                       |
# |  54.255.100.50                |
# |  t3.micro                      |
# +--------------+----------------+
```

---

## Common Tasks

### Update SSH Password

To rotate the SSH password:

1. **Generate new password in Terraform**:
   ```bash
   # Edit variables or re-run with new random seed
   terraform apply -var="force_password_rotation=true"
   ```

2. **Update on EC2 instance**:
   ```bash
   # SSH into the instance (with old password)
   ssh ec2-user@$INSTANCE_IP

   # Retrieve new password from Secrets Manager
   NEW_PASSWORD=$(aws secretsmanager get-secret-value \
     --secret-id "$SECRET_ARN" \
     --region ap-southeast-1 \
     --query SecretString \
     --output text)

   # Update password
   echo "ec2-user:$NEW_PASSWORD" | sudo chpasswd
   ```

### Stop Instance (Cost Savings)

To stop the instance when not in use:

```bash
# Stop instance (retains configuration, charged only for EBS)
aws ec2 stop-instances \
  --instance-ids i-0123456789abcdef \
  --region ap-southeast-1

# Start instance again
aws ec2 start-instances \
  --instance-ids i-0123456789abcdef \
  --region ap-southeast-1

# Note: Public IP will change after stop/start
```

### View Resource Tags

```bash
# View instance tags
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef \
  --region ap-southeast-1 \
  --query 'Reservations[0].Instances[0].Tags' \
  --output table

# Expected tags:
# - Environment: development
# - ManagedBy: Terraform
# - Project: <project-name>
# - CostCenter: <cost-center>
# - Feature: 001-public-ec2-dev
# - Workspace: sandbox_workspace
```

### Destroy Infrastructure

⚠️ **Warning**: This will permanently delete the EC2 instance and all associated resources.

**Via HCP Terraform UI:**
1. Navigate to workspace `sandbox_workspace`
2. Settings → **Destruction and Deletion**
3. Click **Queue destroy plan**
4. Confirm destruction

**Via Terraform CLI:**
```bash
terraform destroy -auto-approve
```

---

## Troubleshooting

### Issue: Cannot connect via SSH (Connection timeout)

**Possible Causes:**
1. Security group rules not applied
2. Instance not fully initialized
3. Incorrect public IP

**Solutions:**
```bash
# 1. Verify security group allows SSH from your IP
aws ec2 describe-security-groups \
  --group-ids sg-0987654321fedcba \
  --region ap-southeast-1 \
  --query 'SecurityGroups[0].IpPermissions'

# Expected: Ingress rule for port 22 from 0.0.0.0/0

# 2. Check instance status checks
aws ec2 describe-instance-status \
  --instance-ids i-0123456789abcdef \
  --region ap-southeast-1

# Expected: SystemStatus and InstanceStatus both "ok"

# 3. Verify public IP
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef \
  --region ap-southeast-1 \
  --query 'Reservations[0].Instances[0].PublicIpAddress'
```

### Issue: SSH connection refused

**Possible Causes:**
1. SSH daemon not running
2. User data script failed

**Solutions:**
```bash
# Check instance system log (console output)
aws ec2 get-console-output \
  --instance-id i-0123456789abcdef \
  --region ap-southeast-1 \
  --output text

# Look for errors in user data execution
# SSH should show "sshd" started successfully
```

### Issue: Password authentication failed

**Possible Causes:**
1. User data script didn't complete
2. Incorrect password retrieved
3. Password not set for ec2-user

**Solutions:**
```bash
# 1. Verify password in Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region ap-southeast-1 \
  --query SecretString \
  --output text

# 2. Check user data script execution in console output
aws ec2 get-console-output \
  --instance-id i-0123456789abcdef \
  --region ap-southeast-1 \
  --output text | grep -A 10 "cloud-init"

# 3. If all else fails, use EC2 Instance Connect (temporary key-based access)
#    to manually debug and fix password authentication
```

### Issue: Cannot retrieve secret from Secrets Manager

**Possible Causes:**
1. Insufficient IAM permissions
2. Secret not created
3. Wrong region

**Solutions:**
```bash
# 1. Verify IAM permissions
aws iam get-user

# 2. List secrets in region
aws secretsmanager list-secrets --region ap-southeast-1

# 3. Check secret exists
aws secretsmanager describe-secret \
  --secret-id dev-ec2-ssh-password \
  --region ap-southeast-1
```

### Issue: High costs

**Possible Causes:**
1. Detailed monitoring enabled (should be disabled)
2. Instance not stopped when not in use
3. Data transfer charges

**Solutions:**
```bash
# 1. Verify monitoring setting
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef \
  --region ap-southeast-1 \
  --query 'Reservations[0].Instances[0].Monitoring.State'

# Expected: "disabled" (basic monitoring only)

# 2. Check cost and usage
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=TAG,Key=Feature \
  --filter file://filter.json

# filter.json:
# {
#   "Tags": {
#     "Key": "Feature",
#     "Values": ["001-public-ec2-dev"]
#   }
# }
```

---

## Cost Tracking

### Monthly Cost Breakdown

| Component | Cost (USD/month) |
|-----------|------------------|
| EC2 Instance (t3.micro, 730 hrs) | $7.59 |
| EBS Volume (8 GB GP3) | $0.64 |
| Public IPv4 Address | $3.60 |
| Secrets Manager | $0.40 |
| Data Transfer (estimate) | $0.09 |
| **Total** | **$12.32** |

### Cost Optimization Tips

1. **Stop instance when not in use**: Stops EC2 charges (~$7.59/month savings)
2. **Use EC2 Instance Connect instead**: Eliminates Secrets Manager cost ($0.40/month)
3. **Schedule instance start/stop**: Use Lambda or EventBridge for automation

### View Costs in AWS Cost Explorer

1. Navigate to [AWS Cost Explorer](https://console.aws.amazon.com/cost-management/home)
2. Select **Cost Explorer**
3. Filter by tag: `Feature = 001-public-ec2-dev`
4. View daily/monthly costs

---

## Next Steps

1. ✅ Provision infrastructure via HCP Terraform
2. ✅ Retrieve SSH password from Secrets Manager
3. ✅ Connect to instance via SSH
4. ✅ Verify monitoring in CloudWatch

**Additional Resources:**
- [Amazon Linux 2023 Documentation](https://docs.aws.amazon.com/linux/al2023/)
- [AWS Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/)
- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)

**Related GitHub Issue:** [#12 - Public EC2 Dev Instance](https://github.com/<org>/<repo>/issues/12)

---

## Support & Feedback

For issues or questions:
- **GitHub Issues**: [Create a new issue](https://github.com/<org>/<repo>/issues/new)
- **Slack Channel**: #infrastructure-support
- **Email**: devops-team@company.com

---

**Document Status**: ✅ Complete  
**Last Updated**: 2026-01-12  
**Maintainer**: DevOps Team
