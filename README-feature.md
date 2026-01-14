# Public EC2 Development Instance with Password Authentication

> **Feature**: 001-public-ec2-dev  
> **GitHub Issue**: [#15](https://github.com/your-org/your-repo/issues/15)  
> **Branch**: `001-public-ec2-dev`  
> **HCP Terraform Workspace**: `sandbox_public_ec2_dev`

## Overview

This Terraform configuration provisions a single **t3.micro** EC2 instance in the **ap-southeast-1** region with:

- ✅ **Public IP** - Internet-accessible for development
- ✅ **Password Authentication** - SSH access via username/password (devuser)
- ✅ **CloudWatch Logs** - System log streaming to CloudWatch
- ✅ **Cost-Optimized** - Basic monitoring, ~$10-15/month
- ✅ **Security Baseline** - Encrypted storage, IAM instance profile
- ✅ **Default VPC** - Uses existing network infrastructure

## Prerequisites

### Required

- **HCP Terraform Account**: Access to `ravi-panchal-org` organization
- **HCP Terraform Workspace**: `sandbox_public_ec2_dev` in `Default Project`
- **AWS Credentials**: Configured in HCP Terraform workspace
- **Default VPC**: Must exist in `ap-southeast-1` region
- **EC2 Quota**: At least 1 t3.micro instance available

### Optional (for testing)

- **SSH Client**: For connecting to the instance
- **AWS CLI v2**: For resource verification
- **sshpass**: For non-interactive SSH connections

## Quick Start

For detailed deployment instructions, see [Quickstart Guide](./specs/001-public-ec2-dev/quickstart.md).

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review Plan

```bash
terraform plan
```

### 3. Deploy Infrastructure

```bash
terraform apply
```

### 4. Retrieve SSH Credentials

```bash
# Get public IP
terraform output instance_public_ip

# Get SSH password (sensitive)
terraform output ssh_password
```

### 5. Connect via SSH

```bash
ssh devuser@$(terraform output -raw instance_public_ip)
# Enter password when prompted
```

## Architecture

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────┐
│                  AWS ap-southeast-1                      │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │           Default VPC (172.31.0.0/16)          │    │
│  │                                                │    │
│  │  ┌──────────────────────────────────────┐     │    │
│  │  │     Default Subnet (Public)          │     │    │
│  │  │                                      │     │    │
│  │  │   ┌──────────────────────────┐      │     │    │
│  │  │   │   EC2 Instance           │      │     │    │
│  │  │   │   - Type: t3.micro       │      │     │    │
│  │  │   │   - OS: Amazon Linux 2023│      │     │    │
│  │  │   │   - Storage: 8GB GP3     │      │     │    │
│  │  │   │   - Public IP: Auto      │      │     │    │
│  │  │   └──────────┬───────────────┘      │     │    │
│  │  │              │                      │     │    │
│  │  └──────────────┼──────────────────────┘     │    │
│  │                 │                            │    │
│  │  ┌──────────────▼──────────────┐            │    │
│  │  │   Security Group            │            │    │
│  │  │   - SSH: 22 (0.0.0.0/0)     │            │    │
│  │  └─────────────────────────────┘            │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌───────────────────────────────────────────────┐     │
│  │   IAM Instance Profile                        │     │
│  │   - Role: CloudWatchAgentServerPolicy         │     │
│  └───────────────────────────────────────────────┘     │
│                                                          │
│  ┌───────────────────────────────────────────────┐     │
│  │   CloudWatch Logs                             │     │
│  │   - Log Group: /aws/ec2/sandbox_public_ec2_dev│     │
│  │   - Source: /var/log/messages                 │     │
│  └───────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### Modules Used

This configuration uses private registry modules from `app.terraform.io/ravi-panchal-org`:

- **ec2-instance** (v6.1.4) - EC2 instance with integrated IAM and security group
- **cloudwatch** (v5.7.2) - CloudWatch log group management

## Configuration

### Input Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `region` | string | `ap-southeast-1` | AWS region (validated, must be ap-southeast-1) |
| `instance_type` | string | `t3.micro` | EC2 instance type (validated pattern: t[2-3].(nano\|micro\|small\|medium)) |
| `password_length` | number | `16` | SSH password length (minimum 16 characters) |
| `tags` | map(string) | See below | Resource tags for governance |

**Default Tags**:
```hcl
{
  Environment = "development"
  Project     = "public-ec2-dev"
  ManagedBy   = "terraform"
  Purpose     = "development-testing"
  Terraform   = "true"
  Agent       = "copilot-terraform-agent"
}
```

### Outputs

| Output | Description | Sensitive |
|--------|-------------|-----------|
| `instance_id` | EC2 instance ID | No |
| `instance_public_ip` | Public IPv4 address | No |
| `security_group_id` | Security group ID | No |
| `cloudwatch_log_group_name` | CloudWatch log group name | No |
| `iam_instance_profile_arn` | IAM instance profile ARN | No |
| `ssh_username` | SSH username | No |
| `ssh_password` | SSH password | **Yes** |

## Cost Estimation

| Resource | Monthly Cost (ap-southeast-1) |
|----------|-------------------------------|
| EC2 Instance (t3.micro, 730 hours) | ~$7.50 |
| EBS Volume (8GB GP3) | ~$0.80 |
| CloudWatch Logs (estimated) | ~$2-5 |
| Data Transfer (minimal) | ~$0.00 |
| **Total** | **~$10-15/month** |

**Budget Target**: $50/month (well within target)

## Security Considerations

⚠️ **Development Environment** - This configuration is optimized for development convenience and is **NOT production-ready**.

### Security Features Enabled

- ✅ EBS volume encryption (AWS-managed keys)
- ✅ IAM instance profile with least-privilege policy
- ✅ CloudWatch Logs for audit trail
- ✅ Resource tagging for governance

### Security Limitations

- ⚠️ SSH accessible from 0.0.0.0/0 (any IP address)
- ⚠️ Password authentication enabled (instead of key-based)
- ⚠️ No VPC flow logs
- ⚠️ No GuardDuty monitoring
- ⚠️ Basic monitoring only (not detailed)

### Production Hardening Recommendations

For production deployments, implement:

1. **Network Security**
   - Restrict SSH to specific IP ranges (e.g., corporate VPN)
   - Use AWS Systems Manager Session Manager instead of SSH
   - Deploy in private subnet with bastion host

2. **Authentication**
   - Disable password authentication
   - Use EC2 key pairs or AWS SSM Session Manager
   - Implement MFA for SSH access

3. **Monitoring**
   - Enable detailed monitoring
   - Configure CloudWatch alarms (CPU, disk, network)
   - Enable VPC Flow Logs
   - Enable AWS GuardDuty

4. **Compliance**
   - Enable AWS Config rules
   - Implement AWS Security Hub
   - Regular vulnerability scanning
   - Automated patching schedule

## Troubleshooting

### Default VPC Not Found

**Error**: `No VPC found matching criteria`

**Resolution**:
```bash
# Create default VPC
aws ec2 create-default-vpc --region ap-southeast-1
```

### SSH Connection Refused

**Diagnosis**:
```bash
# Check instance state
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].State.Name'
```

**Common Causes**:
- Instance still booting (wait 2-3 minutes)
- User data script still executing (wait 30-60 seconds)
- Security group misconfiguration

### Password Authentication Failed

**Diagnosis**:
```bash
# Access via Session Manager to check user data logs
aws ssm start-session --target $(terraform output -raw instance_id)
sudo cat /var/log/user-data.log
```

### CloudWatch Logs Not Streaming

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
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: CloudWatch log group is NOT automatically deleted to preserve logs. To delete:

```bash
aws logs delete-log-group --log-group-name /aws/ec2/sandbox_public_ec2_dev
```

## Documentation

- **Feature Specification**: [spec.md](./specs/001-public-ec2-dev/spec.md)
- **Implementation Plan**: [plan.md](./specs/001-public-ec2-dev/plan.md)
- **Data Model**: [data-model.md](./specs/001-public-ec2-dev/data-model.md)
- **Quickstart Guide**: [quickstart.md](./specs/001-public-ec2-dev/quickstart.md)
- **Implementation Tasks**: [tasks.md](./specs/001-public-ec2-dev/tasks.md)

## Support

- **GitHub Issue**: [#15](https://github.com/your-org/your-repo/issues/15)
- **HCP Terraform Organization**: `ravi-panchal-org`
- **HCP Terraform Project**: `Default Project`
- **HCP Terraform Workspace**: `sandbox_public_ec2_dev`

## License

[Your License Here]
