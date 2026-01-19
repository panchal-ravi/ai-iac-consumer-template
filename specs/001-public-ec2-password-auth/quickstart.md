# Quickstart Guide: Public EC2 Instance with Password Authentication

**Feature**: Public EC2 Instance with Password Authentication  
**Audience**: Developers and DevOps engineers  
**Time to Complete**: ~15 minutes  
**Prerequisites**: HCP Terraform access, AWS credentials configured

---

## ⚠️ Security Warning

**This configuration is for DEVELOPMENT/SANDBOX environments ONLY.**

Risks accepted:
- Password authentication (less secure than SSH keys)
- SSH access from any IP (0.0.0.0/0)
- No automated security patching
- No multi-factor authentication

**DO NOT use in production without implementing proper security controls.**

---

## Prerequisites

### 1. HCP Terraform Access

- [ ] Access to HCP Terraform organization: `ravi-panchal-org`
- [ ] Permission to use workspace: `sandbox_public_ec2_dev`
- [ ] HCP Terraform token configured locally

### 2. AWS Requirements

- [ ] AWS account with active billing
- [ ] IAM permissions for: EC2, VPC, CloudWatch, IAM
- [ ] Service quotas available:
  - EC2 instances: t3.micro
  - Elastic IPs: 1 available
  - VPC resources (if default VPC missing)

### 3. Local Environment

- [ ] Terraform CLI installed (v1.5+)
- [ ] AWS CLI installed (for verification)
- [ ] SSH client installed
- [ ] Git installed

---

## Quick Start Steps

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd <repository-name>
git checkout 001-public-ec2-password-auth
```

### Step 2: Review Configuration

```bash
# Check variables
cat variables.tf

# Review modules
cat main.tf

# Verify remote backend
cat backend.tf
```

Expected configuration:
- Organization: `ravi-panchal-org`
- Workspace: `sandbox_public_ec2_dev`
- Region: `ap-southeast-1`

### Step 3: Initialize Terraform

```bash
# Initialize providers and modules
terraform init

# Expected output:
# - AWS provider initialized
# - Private modules downloaded from app.terraform.io/ravi-panchal-org
```

### Step 4: Validate Configuration

```bash
# Validate syntax
terraform validate

# Format code
terraform fmt -recursive

# Run linting (optional)
tflint
```

### Step 5: Plan Infrastructure

```bash
# Generate execution plan
terraform plan

# Review planned changes:
# - EC2 instance (t3.micro)
# - Security group (SSH port 22)
# - Elastic IP
# - CloudWatch log group
# - IAM role and instance profile
# - Random password generation
# - VPC/subnet (if default VPC missing)
```

**Expected Resource Count**: ~10-15 resources

### Step 6: Apply Infrastructure

```bash
# Apply configuration
terraform apply

# Type 'yes' when prompted

# Wait for completion (~5-10 minutes)
```

**Provisioning Timeline**:
- Minute 1-2: VPC/networking setup
- Minute 3-5: EC2 instance launch
- Minute 5-7: User-data script execution
- Minute 7-10: CloudWatch Agent installation

### Step 7: Retrieve Connection Details

```bash
# Get instance public IP
terraform output instance_public_ip

# Get connection instructions
terraform output connection_instructions

# Get password (sensitive - will prompt)
terraform output instance_password
```

**Copy password to secure location** (password manager recommended).

### Step 8: Connect via SSH

```bash
# Method 1: Manual SSH (will prompt for password)
ssh devuser@<INSTANCE_PUBLIC_IP>

# Enter password when prompted

# Method 2: Using sshpass (automation only)
sshpass -p '<PASSWORD>' ssh -o StrictHostKeyChecking=no devuser@<INSTANCE_PUBLIC_IP>
```

**First Connection**:
- Accept host key fingerprint (type `yes`)
- Enter password
- You should land in `/home/devuser` directory

### Step 9: Verify Installation

Once connected to the instance:

```bash
# Check OS version
lsb_release -a
# Expected: Ubuntu 22.04.x LTS

# Check user
whoami
# Expected: devuser

# Check CloudWatch Agent
sudo systemctl status amazon-cloudwatch-agent
# Expected: active (running)

# Check auth logs
tail -f /var/log/auth.log
# Should show your recent SSH connection
```

### Step 10: Verify CloudWatch Logging

```bash
# From your local machine

# Get log group
terraform output cloudwatch_log_group

# View logs in AWS Console
# Navigate to: CloudWatch > Log groups > /aws/ec2/ssh-auth
# Select log stream matching your instance ID

# Or use AWS CLI
aws logs tail /aws/ec2/ssh-auth --follow --region ap-southeast-1
```

---

## Configuration Options

### Enable HTTP/HTTPS Access

Edit `terraform.tfvars`:

```hcl
enable_http  = true   # Enable port 80
enable_https = true   # Enable port 443
```

Apply changes:

```bash
terraform apply
```

### Adjust Root Volume Size

Edit `terraform.tfvars`:

```hcl
root_volume_size = 20  # Max: 20 GB
```

### Change Log Retention

Edit `terraform.tfvars`:

```hcl
cloudwatch_log_retention_days = 30  # Min: 7 days
```

---

## Troubleshooting

### Issue: Terraform Init Fails

**Symptom**: Cannot download private modules

**Solution**:
```bash
# Verify HCP Terraform token
cat ~/.terraform.d/credentials.tfrc.json

# Re-login to HCP Terraform
terraform login
```

### Issue: SSH Connection Refused

**Symptom**: `Connection refused` error

**Possible Causes**:
1. **User-data script still running**: Wait 5-10 minutes
2. **Security group misconfigured**: Verify port 22 is open
3. **Wrong IP address**: Verify using `terraform output instance_public_ip`

**Debug Steps**:
```bash
# Check instance state
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --region ap-southeast-1

# Check user-data logs (via AWS Console)
# EC2 > Instances > Actions > Monitor and troubleshoot > Get system log
```

### Issue: Password Authentication Fails

**Symptom**: `Permission denied (publickey,password)`

**Possible Causes**:
1. **User-data script failed**: Check `/var/log/user-data.log` via console
2. **Wrong password**: Re-retrieve from Terraform output
3. **SSH config disabled password auth**: Check sshd_config

**Debug Steps**:
```bash
# Verify password was set (connect via EC2 Instance Connect or SSM)
sudo cat /etc/ssh/sshd_config | grep PasswordAuthentication
# Should show: PasswordAuthentication yes

# Check user exists
id devuser

# Check user-data execution log
sudo cat /var/log/user-data.log
```

### Issue: CloudWatch Logs Not Appearing

**Symptom**: No logs in `/aws/ec2/ssh-auth` log group

**Possible Causes**:
1. **CloudWatch Agent not running**: Check service status
2. **IAM permissions missing**: Verify instance profile
3. **Log group not created**: Verify Terraform applied correctly

**Debug Steps**:
```bash
# SSH to instance
ssh devuser@<INSTANCE_IP>

# Check agent status
sudo systemctl status amazon-cloudwatch-agent

# Check agent logs
sudo tail -100 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

# Restart agent
sudo systemctl restart amazon-cloudwatch-agent
```

### Issue: Instance Cost Higher Than Expected

**Symptom**: AWS bill exceeds $15/month estimate

**Check**:
```bash
# Verify instance type
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].InstanceType'
# Should be: t3.micro

# Check Elastic IP allocation
aws ec2 describe-addresses --region ap-southeast-1
# Ensure IP is associated (free) not unassociated (charged)

# Review CloudWatch costs
# AWS Console > CloudWatch > Settings > View billing
```

---

## Common Tasks

### Stop Instance (Saves Cost)

```bash
# Stop instance
aws ec2 stop-instances --instance-ids <INSTANCE_ID> --region ap-southeast-1

# Elastic IP remains associated (no charge)
```

### Start Instance

```bash
# Start instance
aws ec2 start-instances --instance-ids <INSTANCE_ID> --region ap-southeast-1

# Get new public IP (if not using Elastic IP)
terraform refresh
terraform output instance_public_ip
```

### Rotate Password

```bash
# Force new password generation
terraform taint random_password.instance_password

# Apply changes
terraform apply

# Retrieve new password
terraform output instance_password
```

**Note**: Requires SSH to instance to update password manually OR re-run user-data.

### View CloudWatch Logs

```bash
# Using AWS CLI
aws logs tail /aws/ec2/ssh-auth --follow --region ap-southeast-1

# Using AWS Console
# https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-1#logsV2:log-groups/log-group/$252Faws$252Fec2$252Fssh-auth
```

### Destroy Infrastructure

```bash
# Plan destruction
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type 'yes' when prompted

# Verify cleanup
aws ec2 describe-instances --region ap-southeast-1 --filters "Name=tag:ManagedBy,Values=Terraform"
```

**Warning**: Destroying infrastructure is **irreversible**. All data on the instance will be lost.

---

## Cost Management

### Monthly Cost Estimate

| Resource | Cost (USD/month) |
|----------|------------------|
| t3.micro instance | $7.50 |
| EBS GP3 8GB | $0.80 |
| Elastic IP (associated) | $0.00 |
| CloudWatch Logs (minimal) | $0.50 |
| **Total** | **~$8.80** |

### Cost Optimization Tips

1. **Stop instance when not in use** (saves ~$7.50/month)
2. **Use smaller EBS volume** (8GB vs 20GB saves ~$1.20/month)
3. **Reduce log retention** (7 days vs 30 days)
4. **Destroy when project complete** (saves all costs)

### Monitor Costs

```bash
# Set up AWS Budget Alert
aws budgets create-budget \
  --account-id <ACCOUNT_ID> \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

---

## Next Steps

After successful provisioning:

1. ✅ **Test SSH access** with password authentication
2. ✅ **Verify CloudWatch logs** are streaming
3. ✅ **Review security group rules** in AWS Console
4. ✅ **Document password location** in team password manager
5. ✅ **Set up cost alerts** for budget monitoring
6. ⚠️ **Plan security improvements** for production use

---

## Security Hardening (Optional - For Production)

**If moving to production**, implement these controls:

### 1. Switch to SSH Key Authentication

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "devuser@ec2"

# Update Terraform configuration to use key_name
# Remove password authentication
```

### 2. Restrict SSH Access

```hcl
# In terraform.tfvars
ssh_cidr_blocks = ["<YOUR_OFFICE_IP>/32"]  # Replace 0.0.0.0/0
```

### 3. Enable Fail2ban

```bash
# SSH to instance
sudo apt-get install fail2ban -y

# Configure jail
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 4. Enable EBS Encryption

```hcl
# In Terraform
root_block_device {
  encrypted = true
}
```

### 5. Add VPN/Bastion Host

- Deploy AWS Client VPN or bastion host
- Remove direct internet SSH access
- Access instance through secure tunnel

---

## Support & Resources

### Documentation

- Feature Specification: `specs/001-public-ec2-password-auth/spec.md`
- Data Model: `specs/001-public-ec2-password-auth/data-model.md`
- Research: `specs/001-public-ec2-password-auth/research.md`

### AWS Resources

- EC2 User Guide: https://docs.aws.amazon.com/ec2/
- CloudWatch Agent: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html
- Security Best Practices: https://docs.aws.amazon.com/security/

### Terraform Resources

- HCP Terraform: https://app.terraform.io/app/ravi-panchal-org
- Private Modules: https://app.terraform.io/app/ravi-panchal-org/registry/modules

### Getting Help

- **HCP Terraform Issues**: Check workspace runs for error details
- **AWS Issues**: Review CloudWatch logs and EC2 system logs
- **Terraform Issues**: Run `terraform validate` and check syntax

---

## Summary Checklist

- [ ] Prerequisites verified
- [ ] Repository cloned
- [ ] Terraform initialized
- [ ] Infrastructure planned and reviewed
- [ ] Infrastructure applied successfully
- [ ] Password retrieved and stored securely
- [ ] SSH connection successful
- [ ] CloudWatch logs verified
- [ ] Cost monitoring configured
- [ ] Security warnings understood

**Congratulations!** Your public EC2 instance with password authentication is now running. Remember: **Development use only** - implement security hardening for production.

---

**Quickstart Guide Complete** | For detailed implementation, see `plan.md`
