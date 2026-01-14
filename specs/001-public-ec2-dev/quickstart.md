# Quickstart: Public EC2 Development Instance

**Feature**: Public EC2 Development Instance  
**Branch**: `001-public-ec2-dev`  
**Deployment Time**: ~5 minutes

## Prerequisites

Before deploying this infrastructure, ensure you have:

### Required

- [x] HCP Terraform account access
- [x] AWS credentials configured in HCP Terraform workspace
- [x] Access to organization: `ravi-panchal-org`
- [x] Access to project: `Default Project`
- [x] Access to workspace: `sandbox_public_ec2_dev`
- [x] Default VPC exists in `ap-southeast-1` region
- [x] AWS EC2 instance quota available (at least 1 t3.micro)

### Optional (for testing)

- [x] SSH client installed locally
- [x] AWS CLI v2 installed and configured
- [x] `sshpass` utility (for non-interactive SSH)

## Quick Deploy

### Step 1: Clone Repository

```bash
# Clone the repository
git clone <repository-url>
cd <repository-name>

# Switch to feature branch
git checkout 001-public-ec2-dev
```

### Step 2: Review Configuration

The infrastructure is pre-configured with:
- **Region**: ap-southeast-1
- **Instance Type**: t3.micro
- **OS**: Amazon Linux 2023 (latest)
- **Storage**: 8GB GP3 encrypted
- **SSH Access**: Username/password (generated)
- **Monitoring**: CloudWatch Logs (basic)

No configuration changes required for default deployment.

### Step 3: Initialize Terraform

```bash
# Initialize Terraform (downloads modules from private registry)
terraform init
```

**Expected Output**:
```
Initializing modules...
- ec2_instance in app.terraform.io/ravi-panchal-org/ec2-instance/aws
- cloudwatch_log_group in app.terraform.io/ravi-panchal-org/cloudwatch/aws

Terraform has been successfully initialized!
```

### Step 4: Review Plan

```bash
# Generate execution plan
terraform plan
```

**Expected Resources**:
- 1 EC2 instance (t3.micro)
- 1 Security group (SSH from 0.0.0.0/0)
- 1 IAM role + instance profile
- 1 CloudWatch log group
- 1 Random password
- Data sources: Default VPC, subnets, AMI

**Estimated Cost**: ~$10-15/month

### Step 5: Deploy Infrastructure

```bash
# Apply Terraform configuration
terraform apply
```

**Confirmation Prompt**:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

**Deployment Progress** (~3-5 minutes):
1. Creating CloudWatch log group (5 seconds)
2. Creating IAM role and instance profile (10 seconds)
3. Creating security group (5 seconds)
4. Generating random password (instant)
5. Launching EC2 instance (2-3 minutes)
6. Running user data script (30-60 seconds)

**Success Output**:
```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

cloudwatch_log_group_name = "/aws/ec2/sandbox_public_ec2_dev"
iam_instance_profile_arn = "arn:aws:iam::123456789012:instance-profile/sandbox-public-ec2-dev"
instance_id = "i-0123456789abcdef0"
instance_public_ip = "54.169.123.45"
security_group_id = "sg-0123456789abcdef0"
ssh_password = <sensitive>
ssh_username = "devuser"
```

### Step 6: Retrieve SSH Password

```bash
# Display SSH password (sensitive output)
terraform output ssh_password
```

**Output**:
```
"aB3$dE6&hI9*kL2@"
```

**Copy this password** - you'll need it for SSH access.

### Step 7: Connect via SSH

```bash
# Get instance IP
export INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Connect with SSH (will prompt for password)
ssh devuser@${INSTANCE_IP}
```

**Password Prompt**:
```
devuser@54.169.123.45's password: [paste password from step 6]
```

**Success**:
```
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

[devuser@ip-172-31-0-1 ~]$
```

## Verify Deployment

### Test SSH Access

```bash
# Test SSH connection
ssh devuser@$(terraform output -raw instance_public_ip) 'echo "SSH access successful"'
```

**Expected**: `SSH access successful`

### Verify CloudWatch Logs

```bash
# View recent logs
aws logs tail /aws/ec2/sandbox_public_ec2_dev --follow
```

**Expected**: System logs from `/var/log/messages`

### Check Instance State

```bash
# Get instance status
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text
```

**Expected**: `running`

### Verify Security Group

```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id) \
  --query 'SecurityGroups[0].IpPermissions[0].{FromPort:FromPort,ToPort:ToPort,IpProtocol:IpProtocol,IpRanges:IpRanges[0].CidrIp}'
```

**Expected**:
```json
{
  "FromPort": 22,
  "ToPort": 22,
  "IpProtocol": "tcp",
  "IpRanges": "0.0.0.0/0"
}
```

## Common Tasks

### View All Outputs

```bash
terraform output
```

### Copy Files to Instance

```bash
# Using SCP (will prompt for password)
scp local-file.txt devuser@$(terraform output -raw instance_public_ip):~/

# Using sshpass (non-interactive)
sshpass -p "$(terraform output -raw ssh_password)" \
  scp local-file.txt devuser@$(terraform output -raw instance_public_ip):~/
```

### Execute Remote Commands

```bash
# Single command
ssh devuser@$(terraform output -raw instance_public_ip) 'uname -a'

# Multiple commands
ssh devuser@$(terraform output -raw instance_public_ip) << 'EOF'
  echo "Current directory: $(pwd)"
  echo "Disk usage:"
  df -h
EOF
```

### View CloudWatch Logs in Console

1. Open AWS Console → CloudWatch → Log groups
2. Select log group: `/aws/ec2/sandbox_public_ec2_dev`
3. Select log stream: `i-0123456789abcdef0` (your instance ID)
4. View logs in real-time

### Check Instance Costs

```bash
# Get instance running hours
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].LaunchTime' \
  --output text

# Calculate estimated cost
# t3.micro in ap-southeast-1: $0.0104/hour
# Formula: (hours running) * $0.0104 + $0.80 (8GB EBS)
```

## Destroy Infrastructure

When you're done with the development instance:

```bash
# Destroy all resources
terraform destroy
```

**Confirmation Prompt**:
```
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
```

**Deletion Progress** (~2 minutes):
1. Terminating EC2 instance (60-90 seconds)
2. Deleting EBS volume (automatic, delete_on_termination = true)
3. Deleting security group (5 seconds)
4. Deleting IAM instance profile and role (10 seconds)
5. CloudWatch log group preserved (manual deletion required)

**Note**: CloudWatch log group is NOT deleted by default to preserve logs. To delete:

```bash
aws logs delete-log-group --log-group-name /aws/ec2/sandbox_public_ec2_dev
```

## Troubleshooting

### Issue: "Default VPC not found"

**Symptoms**:
```
Error: No VPC found matching criteria
```

**Resolution**:
1. Verify default VPC exists in ap-southeast-1:
   ```bash
   aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region ap-southeast-1
   ```
2. If no default VPC exists, create one:
   ```bash
   aws ec2 create-default-vpc --region ap-southeast-1
   ```

### Issue: "SSH connection refused"

**Symptoms**:
```
ssh: connect to host 54.169.123.45 port 22: Connection refused
```

**Diagnosis**:
1. Check instance state:
   ```bash
   aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) --query 'Reservations[0].Instances[0].State.Name'
   ```
2. Check user data execution:
   ```bash
   # Access via Systems Manager Session Manager
   aws ssm start-session --target $(terraform output -raw instance_id)
   
   # View user data logs
   sudo cat /var/log/user-data.log
   ```

**Resolution**:
- Wait for instance to reach 'running' state (2-3 minutes)
- Wait for user data script to complete (30-60 seconds)
- Verify security group allows your IP

### Issue: "Permission denied (publickey)"

**Symptoms**:
```
devuser@54.169.123.45: Permission denied (publickey).
```

**Resolution**:
SSH is attempting key-based auth. Force password authentication:
```bash
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no devuser@$(terraform output -raw instance_public_ip)
```

### Issue: "Password authentication failed"

**Symptoms**:
```
Permission denied, please try again.
```

**Resolution**:
1. Verify correct password:
   ```bash
   terraform output ssh_password
   ```
2. Check user data script executed successfully:
   ```bash
   # Access via Session Manager
   aws ssm start-session --target $(terraform output -raw instance_id)
   
   # Verify devuser exists
   id devuser
   
   # Check SSH config
   sudo grep PasswordAuthentication /etc/ssh/sshd_config
   ```

### Issue: "No logs in CloudWatch"

**Symptoms**:
- Log stream not created
- No recent log events

**Diagnosis**:
```bash
# Check CloudWatch agent status
aws ssm start-session --target $(terraform output -raw instance_id)
systemctl status amazon-cloudwatch-agent
```

**Resolution**:
```bash
# Restart CloudWatch agent
sudo systemctl restart amazon-cloudwatch-agent

# Check agent logs
sudo cat /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

### Issue: "Instance quota exceeded"

**Symptoms**:
```
Error: Error launching source instance: InstanceLimitExceeded
```

**Resolution**:
1. Check current quota:
   ```bash
   aws service-quotas get-service-quota \
     --service-code ec2 \
     --quota-code L-1216C47A \
     --region ap-southeast-1
   ```
2. Request quota increase via AWS Console → Service Quotas

## Next Steps

Now that your EC2 instance is running:

1. **Install Development Tools**
   ```bash
   ssh devuser@$(terraform output -raw instance_public_ip)
   sudo yum install -y git gcc python3-pip docker
   ```

2. **Configure Development Environment**
   - Set up Git credentials
   - Install language runtimes (Node.js, Go, etc.)
   - Configure Docker daemon

3. **Set Up Monitoring**
   - Create CloudWatch alarms for CPU/memory
   - Configure SNS notifications
   - Set up CloudWatch dashboards

4. **Security Hardening** (for production)
   - Restrict SSH to specific IP ranges
   - Enable SSH key-based authentication
   - Disable password authentication
   - Configure AWS Systems Manager Session Manager

## Cost Optimization

To minimize costs while instance is running:

1. **Stop instance when not in use**:
   ```bash
   aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)
   ```
   Saves compute costs (~$7.50/month) but keeps storage (~$0.80/month)

2. **Start instance when needed**:
   ```bash
   aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)
   ```
   New public IP will be assigned (update SSH connection)

3. **Schedule automated stop/start**:
   - Use AWS Instance Scheduler
   - Or EventBridge + Lambda
   - Example: Stop at 6 PM, start at 8 AM (weekdays only)

## Support

- **GitHub Issue**: #15
- **Feature Branch**: 001-public-ec2-dev
- **HCP Terraform Workspace**: sandbox_public_ec2_dev
- **Documentation**: [spec.md](./spec.md), [plan.md](./plan.md)

## Related Documentation

- [Feature Specification](./spec.md) - Requirements and acceptance criteria
- [Implementation Plan](./plan.md) - Architecture and technical decisions
- [Data Model](./data-model.md) - Entity relationships and state management
- [Terraform Outputs Contract](./contracts/terraform-outputs-contract.md) - Output specifications
- [User Data Contract](./contracts/user-data-contract.md) - User data script specification
