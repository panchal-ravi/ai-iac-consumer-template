# Terraform Outputs Contract

**Feature**: Public EC2 Development Instance  
**Version**: 1.0.0  
**Date**: 2025-01-17

## Purpose

This contract defines the expected Terraform outputs that will be exposed after successful infrastructure deployment. These outputs are consumed by developers for SSH access and operational monitoring.

## Output Specifications

### 1. Instance Public IP

**Name**: `instance_public_ip`

**Type**: `string`

**Sensitivity**: `false`

**Description**: The public IPv4 address assigned to the EC2 instance for SSH access

**Example Value**: `"54.169.123.45"`

**Validation Rules**:
- Must be a valid IPv4 address in dotted-decimal notation
- Must be publicly routable (not RFC 1918 private range)
- Will be different on each instance recreation

**Usage**:
```bash
# Retrieve output
terraform output instance_public_ip

# SSH connection
ssh devuser@$(terraform output -raw instance_public_ip)
```

**Lifecycle**:
- Available after instance reaches 'running' state
- Changes when instance is stopped/started or recreated
- Becomes null when instance is terminated

---

### 2. Instance ID

**Name**: `instance_id`

**Type**: `string`

**Sensitivity**: `false`

**Description**: The AWS-generated unique identifier for the EC2 instance

**Example Value**: `"i-0123456789abcdef0"`

**Validation Rules**:
- Must match pattern: `i-[0-9a-f]{17}`
- Must be unique within AWS account
- Persists only for lifetime of instance

**Usage**:
```bash
# Retrieve output
terraform output instance_id

# AWS CLI operations
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id)

# CloudWatch log stream name
aws logs get-log-events --log-group-name /aws/ec2/sandbox_public_ec2_dev \
  --log-stream-name $(terraform output -raw instance_id)
```

**Lifecycle**:
- Available immediately after instance creation
- Immutable for instance lifetime
- Changes when instance is recreated

---

### 3. SSH Username

**Name**: `ssh_username`

**Type**: `string`

**Sensitivity**: `false`

**Description**: The username for SSH authentication

**Example Value**: `"devuser"`

**Validation Rules**:
- Fixed value: `"devuser"`
- Must be a valid Linux username (alphanumeric, underscore, dash)
- Corresponds to user created by user data script

**Usage**:
```bash
# Retrieve output
terraform output ssh_username

# SSH connection
ssh $(terraform output -raw ssh_username)@$(terraform output -raw instance_public_ip)
```

**Lifecycle**:
- Available after Terraform apply
- Static value, does not change

---

### 4. SSH Password

**Name**: `ssh_password`

**Type**: `string`

**Sensitivity**: `true`

**Description**: The randomly generated password for SSH authentication

**Example Value**: `"aB3$dE6&hI9*kL2@"`  *(16 characters, shown for illustration only)*

**Validation Rules**:
- Exactly 16 characters in length
- Must include at least one uppercase letter
- Must include at least one lowercase letter
- Must include at least one numeric digit
- Must include at least one special character
- Randomly generated on each Terraform apply

**Usage**:
```bash
# Retrieve output (will prompt for confirmation due to sensitivity)
terraform output ssh_password

# Retrieve without prompting (use with caution)
terraform output -raw ssh_password

# SSH connection (interactive password prompt)
ssh devuser@$(terraform output -raw instance_public_ip)
# Enter password when prompted: [paste from terraform output]
```

**Security Considerations**:
- Marked as sensitive in Terraform outputs (not displayed in console by default)
- Stored in Terraform state file (encrypted at rest by HCP Terraform)
- Should be rotated manually if compromised
- Suitable for development environments only

**Lifecycle**:
- Generated during Terraform plan phase
- Available after Terraform apply
- Changes if `random_password` resource is tainted/recreated
- Password stored in Linux `/etc/shadow` on instance

---

### 5. CloudWatch Log Group Name

**Name**: `cloudwatch_log_group_name`

**Type**: `string`

**Sensitivity**: `false`

**Description**: The CloudWatch Logs log group name where instance logs are streamed

**Example Value**: `"/aws/ec2/sandbox_public_ec2_dev"`

**Validation Rules**:
- Fixed value: `"/aws/ec2/sandbox_public_ec2_dev"`
- Must start with forward slash
- Must match pattern: `[\.\-_/#A-Za-z0-9]+`
- Length: 1-512 characters

**Usage**:
```bash
# Retrieve output
terraform output cloudwatch_log_group_name

# View recent logs via AWS CLI
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow

# View specific instance logs
aws logs get-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --log-stream-name $(terraform output -raw instance_id)
```

**Lifecycle**:
- Available after CloudWatch log group creation
- Static value, does not change
- Persists even after instance termination

---

### 6. Security Group ID

**Name**: `security_group_id`

**Type**: `string`

**Sensitivity**: `false`

**Description**: The AWS-generated unique identifier for the security group

**Example Value**: `"sg-0123456789abcdef0"`

**Validation Rules**:
- Must match pattern: `sg-[0-9a-f]{17}`
- Must be unique within AWS account and VPC
- Immutable for security group lifetime

**Usage**:
```bash
# Retrieve output
terraform output security_group_id

# Describe security group rules
aws ec2 describe-security-groups --group-ids $(terraform output -raw security_group_id)
```

**Lifecycle**:
- Available after security group creation
- Immutable for security group lifetime
- Changes when infrastructure is recreated

---

### 7. IAM Instance Profile ARN

**Name**: `iam_instance_profile_arn`

**Type**: `string`

**Sensitivity**: `false`

**Description**: The Amazon Resource Name (ARN) of the IAM instance profile attached to the EC2 instance

**Example Value**: `"arn:aws:iam::123456789012:instance-profile/sandbox-public-ec2-dev-profile"`

**Validation Rules**:
- Must match ARN format: `arn:aws:iam::<account-id>:instance-profile/<profile-name>`
- Must exist in AWS account
- Must have CloudWatchAgentServerPolicy attached

**Usage**:
```bash
# Retrieve output
terraform output iam_instance_profile_arn

# Get instance profile details
aws iam get-instance-profile --instance-profile-name \
  $(terraform output -raw iam_instance_profile_arn | awk -F/ '{print $NF}')
```

**Lifecycle**:
- Available after IAM instance profile creation
- Immutable for instance profile lifetime
- Changes when infrastructure is recreated

---

## Output Summary Table

| Output Name | Type | Sensitive | Example | Purpose |
|-------------|------|-----------|---------|---------|
| `instance_public_ip` | string | false | `54.169.123.45` | SSH connection target |
| `instance_id` | string | false | `i-0123456789abcdef0` | AWS resource identification |
| `ssh_username` | string | false | `devuser` | SSH authentication username |
| `ssh_password` | string | **true** | `aB3$dE6&hI9*kL2@` | SSH authentication password |
| `cloudwatch_log_group_name` | string | false | `/aws/ec2/sandbox_public_ec2_dev` | Log monitoring |
| `security_group_id` | string | false | `sg-0123456789abcdef0` | Firewall rule identification |
| `iam_instance_profile_arn` | string | false | `arn:aws:iam::...:instance-profile/...` | IAM permissions verification |

## Terraform Implementation

```hcl
# outputs.tf

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2_instance.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2_instance.id
}

output "ssh_username" {
  description = "SSH username for connecting to the instance"
  value       = "devuser"
}

output "ssh_password" {
  description = "SSH password for devuser account (randomly generated)"
  value       = random_password.devuser.result
  sensitive   = true
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logs log group name for instance logs"
  value       = module.cloudwatch_log_group.cloudwatch_log_group_name
}

output "security_group_id" {
  description = "Security group ID attached to the instance"
  value       = module.ec2_instance.security_group_id
}

output "iam_instance_profile_arn" {
  description = "IAM instance profile ARN"
  value       = module.ec2_instance.iam_instance_profile_arn
}
```

## Consumer Integration

### HCP Terraform Workspace Integration

HCP Terraform automatically exposes outputs via:

1. **Workspace UI**: Outputs visible in workspace "Outputs" tab
2. **API**: Accessible via HCP Terraform API
3. **CLI**: Retrieved using `terraform output` command
4. **Remote State**: Consumable by other Terraform workspaces via `terraform_remote_state` data source

### SSH Connection Workflow

```bash
# Step 1: Export outputs to environment variables
export INSTANCE_IP=$(terraform output -raw instance_public_ip)
export SSH_USER=$(terraform output -raw ssh_username)
export SSH_PASS=$(terraform output -raw ssh_password)

# Step 2: Connect via SSH (manual password entry)
ssh ${SSH_USER}@${INSTANCE_IP}

# Step 3: Paste password when prompted
# Password: [paste from $SSH_PASS]

# Alternative: Use sshpass for non-interactive login (development only)
sshpass -p "${SSH_PASS}" ssh ${SSH_USER}@${INSTANCE_IP}
```

### CloudWatch Logs Integration

```bash
# View logs in real-time
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow

# Export logs to file
aws logs get-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --log-stream-name $(terraform output -raw instance_id) \
  --output json > instance-logs.json
```

## Error Scenarios

### Output Not Available

**Cause**: Terraform apply has not completed successfully

**Resolution**:
1. Verify Terraform apply succeeded: `terraform show`
2. Check for resources in failed state
3. Re-run `terraform apply` to complete provisioning

### Sensitive Output Redacted

**Cause**: SSH password is marked as sensitive

**Resolution**:
```bash
# Use -raw flag to retrieve sensitive value
terraform output -raw ssh_password
```

### Public IP is null

**Cause**: Instance does not have public IP assigned

**Resolution**:
1. Verify subnet has `map_public_ip_on_launch = true`
2. Check default VPC has internet gateway attached
3. Verify instance is in 'running' state

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-17 | Initial contract definition |

## Related Contracts

- [terraform-inputs-contract.md](./terraform-inputs-contract.md) - Input variable specifications
- [module-interface-contract.md](./module-interface-contract.md) - Module input/output contracts
