# Public EC2 Development Instance

Infrastructure as Code for provisioning a cost-optimized public EC2 instance in AWS for development environments with SSH password authentication.

## Overview

This Terraform configuration provisions:
- EC2 t3.micro instance with Amazon Linux 2023
- SSH password authentication (instead of key pairs)
- Public IP for remote access
- Security group allowing SSH from anywhere (0.0.0.0/0)
- AWS Secrets Manager for secure password storage
- Basic CloudWatch monitoring (5-minute intervals)

**Feature ID**: 001-public-ec2-dev  
**GitHub Issue**: #12  
**Specification**: [specs/001-public-ec2-dev/spec.md](specs/001-public-ec2-dev/spec.md)

## Architecture

```
┌─────────────────────────────────────────────┐
│          Default VPC (ap-southeast-1)       │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │     Security Group (SSH - 0.0.0.0/0) │  │
│  │                                       │  │
│  │  ┌────────────────────────────────┐  │  │
│  │  │   EC2 Instance (t3.micro)      │  │  │
│  │  │   - Amazon Linux 2023          │  │  │
│  │  │   - 8GB GP3 Root Volume        │  │  │
│  │  │   - Public IP: X.X.X.X         │  │  │
│  │  │   - SSH Password Auth Enabled  │  │  │
│  │  └────────────────────────────────┘  │  │
│  └──────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
                     │
                     │ IAM Instance Profile
                     ▼
         ┌───────────────────────────┐
         │  Secrets Manager Secret   │
         │  (SSH Password)           │
         └───────────────────────────┘
```

## Prerequisites

### Required Tools

- **Terraform** >= 1.13.0
- **AWS CLI** configured with credentials
- **HCP Terraform Account** with workspace `sandbox_workspace`

### Required Permissions

Your AWS credentials must have permissions to:
- Create EC2 instances, security groups, and network interfaces
- Create IAM roles and instance profiles
- Create Secrets Manager secrets
- Describe VPCs and subnets

### Environment Setup

1. **HCP Terraform Configuration**:
   - Organization: `ravi-panchal-org`
   - Workspace: `sandbox_workspace`
   - Execution mode: Remote

2. **AWS Credentials**:
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="ap-southeast-1"
   ```

## Quick Start

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review Configuration

```bash
terraform plan
```

Expected output: ~12 resources to create
- Data sources (VPC, subnets, AMI)
- Random password
- Secrets Manager secret
- IAM role and instance profile
- Security group with ingress/egress rules
- EC2 instance

### 3. Apply Configuration

```bash
terraform apply
```

Provisioning time: ~2-3 minutes

### 4. Retrieve SSH Password

```bash
# Using AWS CLI
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw ssh_secret_arn) \
  --region ap-southeast-1 \
  --query SecretString \
  --output text
```

### 5. Connect via SSH

```bash
# Get public IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Connect (you'll be prompted for password)
ssh ec2-user@$INSTANCE_IP
```

## Configuration

### Input Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `region` | AWS region (must be ap-southeast-1) | `ap-southeast-1` | No |
| `environment` | Environment name | `development` | No |
| `instance_type` | EC2 instance type (must be t3.micro) | `t3.micro` | No |
| `root_volume_size` | Root volume size in GB (must be 8) | `8` | No |
| `root_volume_type` | EBS volume type (must be gp3) | `gp3` | No |
| `ssh_password_length` | Password length (minimum 32) | `32` | No |
| `project_name` | Project name for tagging | - | **Yes** |
| `cost_center` | Cost center for billing | - | **Yes** |
| `enable_detailed_monitoring` | Detailed CloudWatch monitoring (must be false) | `false` | No |

### Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | EC2 instance identifier |
| `instance_public_ip` | Public IP address for SSH |
| `instance_private_ip` | Private IP within VPC |
| `security_group_id` | Security group identifier |
| `ssh_secret_arn` | Secrets Manager ARN for password |
| `ssh_connection_command` | SSH command to connect |
| `password_retrieval_command` | AWS CLI command to get password |
| `estimated_monthly_cost` | Estimated monthly cost |

### Environment Variables

Copy `terraform.tfvars.example` to `sandbox.auto.tfvars` and customize:

```hcl
# Required Variables
project_name = "your-project-name"
cost_center  = "your-cost-center"

# Optional Overrides (defaults shown)
region               = "ap-southeast-1"
environment          = "development"
instance_type        = "t3.micro"
root_volume_size     = 8
ssh_password_length  = 32
```

## Cost Breakdown

| Component | Monthly Cost (USD) |
|-----------|-------------------|
| EC2 t3.micro (730 hrs) | $7.59 |
| EBS GP3 8GB | $0.64 |
| Public IPv4 Address | $3.60 |
| Secrets Manager | $0.40 |
| Data Transfer (estimate) | $0.09 |
| **Total** | **~$12.32** |

**Budget**: $50/month (76% under budget)

## Security Considerations

⚠️ **Development Environment Trade-offs**

This configuration is designed for **development use only** with the following security trade-offs:

1. **Public SSH Access (0.0.0.0/0)**
   - Risk: Exposed to internet-based attacks
   - Mitigation: Strong 32-character password, basic monitoring
   - Recommendation: Use IP allowlisting for production

2. **Password Authentication**
   - Risk: Less secure than SSH key pairs
   - Mitigation: Cryptographically secure random password, Secrets Manager storage
   - Recommendation: Use SSH keys for production

3. **Public IP Address**
   - Risk: Direct internet exposure
   - Mitigation: Security group controls, minimal software
   - Recommendation: Use private subnets with bastion for production

### Security Controls Implemented

- ✅ Password stored encrypted in AWS Secrets Manager
- ✅ Strong password generation (32 chars, all character classes)
- ✅ IAM instance profile for Secrets Manager access (no embedded credentials)
- ✅ Security group with principle of least privilege
- ✅ Resource tagging for audit and tracking
- ✅ Basic CloudWatch monitoring enabled

## Monitoring

### CloudWatch Metrics

Basic monitoring (5-minute intervals) is enabled for:
- CPU Utilization
- Network In/Out
- Disk Read/Write Bytes
- Status Check Failed

### Viewing Metrics

```bash
# Get CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$(terraform output -raw instance_id) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region ap-southeast-1
```

## Troubleshooting

### Cannot connect via SSH

**Symptoms**: Connection timeout or connection refused

**Solutions**:
1. Verify instance is running:
   ```bash
   terraform output instance_id
   aws ec2 describe-instances --instance-ids <instance-id>
   ```

2. Check security group rules:
   ```bash
   terraform output security_group_id
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

3. Verify user data script execution:
   ```bash
   aws ec2 get-console-output --instance-id <instance-id>
   ```

### Password authentication failed

**Symptoms**: SSH password rejected

**Solutions**:
1. Verify password retrieval:
   ```bash
   terraform output password_retrieval_command
   # Run the output command
   ```

2. Check user data script logs on instance (if you can connect with EC2 Instance Connect):
   ```bash
   sudo cat /var/log/user-data.log
   ```

### Default VPC not found

**Symptoms**: Terraform plan fails with "no VPC found"

**Solution**: Create default VPC in ap-southeast-1:
```bash
aws ec2 create-default-vpc --region ap-southeast-1
```

## Maintenance

### Rotate SSH Password

```bash
# Force password rotation
terraform taint random_password.ssh_password
terraform apply

# Update password on running instance
NEW_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw ssh_secret_arn) \
  --query SecretString --output text)

# SSH into instance and run:
echo "ec2-user:$NEW_PASSWORD" | sudo chpasswd
```

### Stop Instance (Cost Savings)

```bash
# Stop instance (only pay for EBS)
aws ec2 stop-instances \
  --instance-ids $(terraform output -raw instance_id)

# Start instance
aws ec2 start-instances \
  --instance-ids $(terraform output -raw instance_id)

# Note: Public IP will change after stop/start
```

### Destroy Infrastructure

⚠️ **Warning**: This permanently deletes all resources

```bash
terraform destroy
```

## File Structure

```
.
├── main.tf                      # Main infrastructure configuration
├── variables.tf                 # Input variable definitions
├── locals.tf                    # Local values (tags, naming)
├── outputs.tf                   # Output definitions
├── providers.tf                 # Provider configuration
├── versions.tf                  # Terraform version constraints
├── override.tf                  # HCP Terraform backend (excluded from git)
├── user_data.sh                 # EC2 user data script
├── sandbox.auto.tfvars          # Sandbox environment values (excluded from git)
├── terraform.tfvars.example     # Example variable file
├── README.md                    # This file
└── specs/001-public-ec2-dev/    # Feature specification
    ├── spec.md                  # Requirements and acceptance criteria
    ├── plan.md                  # Implementation plan
    ├── data-model.md            # Entity definitions
    ├── quickstart.md            # Developer onboarding guide
    └── tasks.md                 # Implementation tasks
```

## Resources Created

1. **Data Sources** (read-only)
   - `data.aws_vpc.default` - Default VPC lookup
   - `data.aws_subnets.default` - Default subnets lookup
   - `data.aws_ami.amazon_linux_2023` - Latest AL2023 AMI

2. **Security Resources**
   - `random_password.ssh_password` - Generated SSH password
   - `aws_secretsmanager_secret.ssh_password` - Secret storage
   - `aws_secretsmanager_secret_version.ssh_password` - Secret value

3. **IAM Resources**
   - `aws_iam_role.instance_role` - EC2 instance role
   - `aws_iam_role_policy.secrets_access` - Secrets Manager permissions
   - `aws_iam_instance_profile.instance_profile` - Instance profile

4. **Network Resources**
   - `aws_security_group.ssh` - SSH security group
   - `aws_vpc_security_group_ingress_rule.ssh` - SSH inbound rule
   - `aws_vpc_security_group_egress_rule.all_outbound` - Outbound rule

5. **Compute Resources**
   - `aws_instance.dev_ec2` - EC2 t3.micro instance

## References

- **Feature Specification**: [specs/001-public-ec2-dev/spec.md](specs/001-public-ec2-dev/spec.md)
- **Implementation Plan**: [specs/001-public-ec2-dev/plan.md](specs/001-public-ec2-dev/plan.md)
- **Quick Start Guide**: [specs/001-public-ec2-dev/quickstart.md](specs/001-public-ec2-dev/quickstart.md)
- **GitHub Issue**: [#12](https://github.com/[org]/[repo]/issues/12)

## Support

For issues or questions:
- Review the [troubleshooting section](#troubleshooting)
- Check the [feature specification](specs/001-public-ec2-dev/spec.md)
- Review Terraform logs: `terraform plan -out=plan.tfplan`

## License

[Your License Here]

---

**Last Updated**: 2026-01-12  
**Terraform Version**: >= 1.13.0  
**AWS Provider Version**: ~> 6.0
