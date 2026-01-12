# Terraform Module Interface Contract

**Feature**: EC2 Development Instance  
**Version**: 1.0.0  
**Date**: 2025-01-12  
**Status**: Complete

---

## Overview

This contract defines the public interface for the EC2 development instance Terraform configuration. It specifies required inputs, expected outputs, and behavioral guarantees for consumers of this infrastructure code.

---

## Module Information

**Module Name**: `ec2-dev-instance`  
**Source Repository**: Current Git repository (inline Terraform configuration)  
**Terraform Version**: >= 1.5.0  
**AWS Provider Version**: >= 5.0.0  

**Purpose**: Provision a public EC2 instance with password-based SSH authentication, security hardening, and CloudWatch monitoring for development environments.

---

## Input Variables Contract

### Required Variables

#### `aws_region`

- **Type**: `string`
- **Description**: AWS region for resource deployment
- **Default**: `"us-east-1"`
- **Validation**: Must be a valid AWS region code
- **Example**: `"us-east-1"`, `"us-west-2"`, `"eu-west-1"`
- **Used By**: AWS provider configuration, resource placement

```hcl
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Region must be a valid AWS region code (e.g., us-east-1)."
  }
}
```

---

#### `instance_type`

- **Type**: `string`
- **Description**: EC2 instance type for the development instance
- **Default**: `"t3.micro"`
- **Validation**: Must be from t3 instance family
- **Example**: `"t3.micro"`, `"t3.small"`, `"t3.medium"`
- **Cost Impact**: t3.micro ~$7.50/month, t3.small ~$15/month

```hcl
variable "instance_type" {
  description = "EC2 instance type (t3.micro recommended for development)"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Instance type must be from t3 family for cost optimization."
  }
}
```

---

#### `root_volume_size`

- **Type**: `number`
- **Description**: Root EBS volume size in GB
- **Default**: `30`
- **Validation**: Minimum 30 GB (AL2023 requirement), maximum 100 GB
- **Example**: `30`, `50`, `100`
- **Cost Impact**: ~$0.10/GB-month for gp3 volumes

```hcl
variable "root_volume_size" {
  description = "Root volume size in GB (minimum 30 for AL2023)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.root_volume_size >= 30 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 30 and 100 GB."
  }
}
```

---

#### `environment`

- **Type**: `string`
- **Description**: Environment name for resource tagging and naming
- **Default**: `"development"`
- **Validation**: Must be one of: `dev`, `development`, `sandbox`
- **Example**: `"development"`, `"sandbox"`
- **Used By**: Resource naming, tagging, compliance checks

```hcl
variable "environment" {
  description = "Deployment environment (development use only)"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["dev", "development", "sandbox"], var.environment)
    error_message = "Environment must be dev, development, or sandbox (production not supported)."
  }
}
```

---

#### `project_name`

- **Type**: `string`
- **Description**: Project identifier for resource naming
- **Default**: `"ec2-dev-instance"`
- **Validation**: Max 32 characters, alphanumeric and hyphens only
- **Example**: `"ec2-dev-instance"`, `"dev-workstation"`
- **Used By**: Resource name prefixes, tags

```hcl
variable "project_name" {
  description = "Project name for resource identification"
  type        = string
  default     = "ec2-dev-instance"
  
  validation {
    condition     = can(regex("^[a-z0-9-]{1,32}$", var.project_name))
    error_message = "Project name must be 1-32 characters, lowercase alphanumeric and hyphens only."
  }
}
```

---

### Optional Variables

#### `enable_monitoring`

- **Type**: `bool`
- **Description**: Enable CloudWatch detailed monitoring (1-minute metrics)
- **Default**: `false`
- **Cost Impact**: $2/month if enabled; basic monitoring (5-min) free
- **Recommendation**: Keep false for development environments

```hcl
variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring (adds cost)"
  type        = bool
  default     = false
}
```

---

#### `ssh_allowed_cidr_blocks`

- **Type**: `list(string)`
- **Description**: CIDR blocks allowed for SSH access
- **Default**: `["0.0.0.0/0"]`
- **Validation**: Must be valid CIDR notation
- **Security Note**: 0.0.0.0/0 allows public access (development only)
- **Example**: `["203.0.113.0/24", "198.51.100.0/24"]`

```hcl
variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH (0.0.0.0/0 allows public access)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  
  validation {
    condition     = alltrue([for cidr in var.ssh_allowed_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "All elements must be valid CIDR blocks."
  }
}
```

---

#### `additional_tags`

- **Type**: `map(string)`
- **Description**: Additional tags to apply to all resources
- **Default**: `{}`
- **Example**: `{ Owner = "john.doe@example.com", CostCenter = "Engineering" }`
- **Merged With**: Standard tags (Environment, Project, ManagedBy, PublicAccess)

```hcl
variable "additional_tags" {
  description = "Additional tags to merge with standard tags"
  type        = map(string)
  default     = {}
}
```

---

## Output Values Contract

### Compute Outputs

#### `instance_id`

- **Type**: `string`
- **Description**: EC2 instance identifier
- **Sensitive**: `false`
- **Example**: `"i-0123456789abcdef0"`
- **Use Cases**: 
  - AWS Console navigation
  - Session Manager connection
  - CloudWatch metrics filtering

```hcl
output "instance_id" {
  description = "EC2 instance identifier"
  value       = aws_instance.dev.id
}
```

---

#### `instance_public_ip`

- **Type**: `string`
- **Description**: Elastic IP address for SSH access
- **Sensitive**: `false`
- **Example**: `"203.0.113.45"`
- **Use Cases**:
  - SSH connection string
  - DNS record configuration
  - Firewall allowlist rules

```hcl
output "instance_public_ip" {
  description = "Public IP address (Elastic IP) for SSH access"
  value       = aws_eip.dev_instance.public_ip
}
```

---

#### `instance_private_ip`

- **Type**: `string`
- **Description**: VPC private IP address
- **Sensitive**: `false`
- **Example**: `"172.31.32.100"`
- **Use Cases**:
  - Internal VPC routing
  - VPC peering connections
  - VPN access patterns

```hcl
output "instance_private_ip" {
  description = "VPC private IP address"
  value       = aws_instance.dev.private_ip
}
```

---

### Networking Outputs

#### `security_group_id`

- **Type**: `string`
- **Description**: Security group identifier
- **Sensitive**: `false`
- **Example**: `"sg-0abcdef1234567890"`
- **Use Cases**:
  - Security group rule modifications
  - Compliance auditing
  - Additional instance attachments

```hcl
output "security_group_id" {
  description = "Security group ID for SSH access"
  value       = aws_security_group.ec2_dev_ssh.id
}
```

---

#### `elastic_ip_id`

- **Type**: `string`
- **Description**: Elastic IP allocation identifier
- **Sensitive**: `false`
- **Example**: `"eipalloc-0123456789abcdef"`
- **Use Cases**:
  - EIP association changes
  - Cost tracking
  - IP allowlist management

```hcl
output "elastic_ip_id" {
  description = "Elastic IP allocation ID"
  value       = aws_eip.dev_instance.id
}
```

---

### IAM Outputs

#### `iam_role_arn`

- **Type**: `string`
- **Description**: IAM role ARN for EC2 instance
- **Sensitive**: `false`
- **Example**: `"arn:aws:iam::123456789012:role/ec2-dev-instance-ssm-role"`
- **Use Cases**:
  - Permission verification
  - Policy attachment
  - Audit trails

```hcl
output "iam_role_arn" {
  description = "IAM role ARN for Session Manager access"
  value       = aws_iam_role.ec2_ssm_role.arn
}
```

---

#### `iam_instance_profile_name`

- **Type**: `string`
- **Description**: IAM instance profile name
- **Sensitive**: `false`
- **Example**: `"ec2-dev-instance-profile"`
- **Use Cases**:
  - Instance profile modifications
  - Role association verification
  - Documentation

```hcl
output "iam_instance_profile_name" {
  description = "IAM instance profile name"
  value       = aws_iam_instance_profile.ec2_profile.name
}
```

---

### Monitoring Outputs

#### `log_group_name`

- **Type**: `string`
- **Description**: CloudWatch Logs group name for SSH authentication logs
- **Sensitive**: `false`
- **Example**: `"/aws/ec2/dev-instance/ssh-auth"`
- **Use Cases**:
  - Log streaming verification
  - CloudWatch Insights queries
  - Alarm configuration

```hcl
output "log_group_name" {
  description = "CloudWatch Logs group name for SSH authentication events"
  value       = aws_cloudwatch_log_group.ssh_auth_logs.name
}
```

---

#### `log_group_arn`

- **Type**: `string`
- **Description**: CloudWatch Logs group ARN
- **Sensitive**: `false`
- **Example**: `"arn:aws:logs:us-east-1:123456789012:log-group:/aws/ec2/dev-instance/ssh-auth:*"`
- **Use Cases**:
  - IAM policy configuration
  - Cross-account log access
  - Resource-based policies

```hcl
output "log_group_arn" {
  description = "CloudWatch Logs group ARN"
  value       = aws_cloudwatch_log_group.ssh_auth_logs.arn
}
```

---

### Convenience Outputs

#### `ssh_connection_command`

- **Type**: `string`
- **Description**: Ready-to-use SSH connection command
- **Sensitive**: `false`
- **Example**: `"ssh devuser@203.0.113.45"`
- **Use Cases**:
  - User documentation
  - Quick access instructions
  - Automation scripts

```hcl
output "ssh_connection_command" {
  description = "SSH connection command for accessing the instance"
  value       = "ssh devuser@${aws_eip.dev_instance.public_ip}"
}
```

---

#### `session_manager_command`

- **Type**: `string`
- **Description**: AWS CLI command for Session Manager access
- **Sensitive**: `false`
- **Example**: `"aws ssm start-session --target i-0123456789abcdef0"`
- **Use Cases**:
  - Emergency fallback access
  - Password reset procedures
  - Troubleshooting documentation

```hcl
output "session_manager_command" {
  description = "AWS CLI command for Session Manager access (fallback)"
  value       = "aws ssm start-session --target ${aws_instance.dev.id}"
}
```

---

## Resource Lifecycle Contract

### Creation Behavior

**Initial Deployment** (`terraform apply`):

1. **VPC Discovery** (0-10 seconds): Lookup default VPC and public subnets
2. **AMI Discovery** (0-10 seconds): Find latest Amazon Linux 2023 AMI
3. **IAM Resources** (10-30 seconds): Create role, policy attachment, instance profile
4. **Security Resources** (10-30 seconds): Create security group, CloudWatch log group
5. **EC2 Launch** (30-90 seconds): Launch instance with user-data script
6. **EIP Association** (10-20 seconds): Attach Elastic IP to instance
7. **User-Data Execution** (120-180 seconds): Install packages, configure security
8. **Total Duration**: 3-5 minutes

**Expected State After Creation**:
- Instance status: `running`
- SSH service: `active (running)`
- fail2ban service: `active (running)`
- CloudWatch agent: `active (running)`
- Password: NOT SET (requires operator action via Session Manager)

---

### Update Behavior

**In-Place Updates** (no instance replacement):
- Security group rule changes
- IAM policy attachments
- Instance tags
- CloudWatch log group retention

**Requires Replacement** (instance destroyed and recreated):
- AMI changes
- Instance type changes
- Subnet changes
- User-data script changes
- Root volume size changes

**Update Process**:
1. Terraform plan identifies changes requiring replacement
2. New instance created with new EIP
3. Old instance destroyed after successful creation
4. **Data Loss**: All data on root volume is lost
5. **Operator Action Required**: Reset devuser password via Session Manager

---

### Deletion Behavior

**Destroy Sequence** (`terraform destroy`):

1. **EIP Disassociation** (5-10 seconds): Release Elastic IP from instance
2. **EIP Release** (1-2 seconds): Return IP to AWS pool
3. **Instance Termination** (30-60 seconds): Stop and terminate instance
4. **Security Group Deletion** (5-10 seconds): Remove security group
5. **IAM Cleanup** (10-20 seconds): Delete instance profile, detach policies, delete role
6. **CloudWatch Cleanup** (5-10 seconds): Delete log group (purges all logs)
7. **Total Duration**: 1-2 minutes

**Data Retention**:
- CloudWatch Logs: DELETED (cannot be recovered)
- EBS Snapshots: NONE (no backup created)
- State File: Retains historical resource IDs

**Cost Impact After Deletion**:
- All recurring costs stop immediately
- No residual charges (EIP released, instance terminated)

---

## Behavioral Guarantees

### SSH Access

**Guaranteed**:
- SSH port 22 accessible from `var.ssh_allowed_cidr_blocks`
- Password authentication enabled for `devuser` account
- Key-based authentication disabled
- 30-minute idle session timeout
- fail2ban protection after 5 failed attempts

**Not Guaranteed**:
- Initial password is NOT set (operator must set via Session Manager)
- fail2ban may block legitimate users (use Session Manager as fallback)
- SSH availability during user-data execution (wait 3-5 minutes after launch)

---

### Security Hardening

**Guaranteed**:
- Password complexity: 14+ characters, 4 character classes
- fail2ban: 5 attempts / 10 minutes = 1-hour block
- Root SSH login disabled
- Password expiry: 90 days with 7-day warning
- CloudWatch logging of all authentication attempts

**Not Guaranteed**:
- Distributed brute-force attacks below fail2ban threshold
- Zero-day SSH vulnerabilities (requires manual patching)
- DDoS protection (AWS Shield Basic only)

---

### Monitoring

**Guaranteed**:
- SSH auth logs appear in CloudWatch within 2 minutes
- Log retention: Exactly 7 days, automatic purge
- Basic CloudWatch metrics: 5-minute intervals
- Session Manager access via IAM authentication

**Not Guaranteed**:
- Real-time log streaming (up to 2-minute delay)
- Log delivery during CloudWatch service outages
- Detailed metrics (1-minute) unless `enable_monitoring = true`

---

### Cost Predictability

**Guaranteed Monthly Costs**:
- t3.micro instance: $7.50 (on-demand, us-east-1)
- EBS gp3 30GB: $2.40
- CloudWatch Logs: $0.50 (estimated, variable)
- **Total**: ~$10.40/month

**Variable Costs**:
- Data transfer out (>1GB): $0.09/GB
- Detailed monitoring (if enabled): +$2.00/month
- Stopped instance EIP charges: $0.01/hour ($7.20/month)

**Cost Guarantees**:
- No hidden infrastructure costs (all resources explicitly created)
- Staying under $50/month budget with standard usage
- Free tier NOT assumed (pricing based on standard rates)

---

## Error Handling Contract

### Pre-Flight Validation Errors

**Invalid Variable Values**:
```
Error: Invalid value for variable "aws_region"
│   on variables.tf line 5:
│   Region must be a valid AWS region code (e.g., us-east-1).
```

**Resolution**: Correct variable value in `sandbox.auto.tfvars`

---

**Insufficient IAM Permissions**:
```
Error: creating EC2 Instance: UnauthorizedOperation: You are not authorized to perform this operation.
│   with aws_instance.dev
```

**Resolution**: Verify HCP Terraform workspace has required AWS permissions

---

### Runtime Errors

**Quota Exceeded**:
```
Error: creating EC2 EIP: AddressLimitExceeded: You have reached your quota of 5 Elastic IPs.
│   with aws_eip.dev_instance
```

**Resolution**: Release unused EIPs or request quota increase

---

**Default VPC Not Found**:
```
Error: no matching VPC found
│   with data.aws_vpc.default
```

**Resolution**: Region may not have default VPC; create custom VPC or use different region

---

**User-Data Script Failure**:
```
Instance launched successfully but SSH access not available after 10 minutes
```

**Resolution**: 
1. Connect via Session Manager
2. Check `/var/log/cloud-init-output.log`
3. Verify user-data script completed successfully

---

## Dependencies Contract

### External Dependencies

**Required AWS Services**:
- EC2 (compute)
- VPC (networking)
- IAM (authentication)
- CloudWatch Logs (monitoring)
- Systems Manager (Session Manager)

**Required AWS Resources**:
- Default VPC in target region
- Public subnet with internet gateway
- EIP quota availability (1 EIP required)

**Required HCP Terraform Configuration**:
- Workspace: `sandbox_ec2_dev_instance` pre-configured
- Variable Sets: AWS dynamic credentials configured
- Git Repository: Connected to feature branch

---

### Provider Dependencies

**Terraform**:
- Version: >= 1.5.0
- Backend: HCP Terraform Cloud
- State locking: Automatic via workspace

**AWS Provider**:
- Version: >= 5.0.0
- Region: Configurable via `var.aws_region`
- Authentication: Dynamic credentials from workspace variable sets

---

## Compliance Contract

### Security Posture

**Development Environment Only**:
- Public SSH access with password authentication
- NOT suitable for production workloads
- NOT compliant with PCI-DSS, HIPAA, SOC 2

**Tagging for Audit**:
- `Environment=development`
- `PublicAccess=true`
- `ManagedBy=terraform`

**Risk Acceptance**:
- RISK-001: Public SSH (HIGH severity) - Accepted for development
- RISK-009: Non-compliant architecture - Documented limitation

---

### Data Classification

**Supported Data Types**:
- Development code and test data only
- Non-production environment variables
- Public or synthetic test data

**Prohibited Data Types**:
- Production data
- Personally Identifiable Information (PII)
- Protected Health Information (PHI)
- Payment Card Data
- Trade secrets or confidential business data

---

## Testing Contract

### Pre-Deployment Tests

**Required Validations**:
```bash
terraform init        # Provider initialization
terraform validate    # Syntax validation
terraform fmt -check  # Formatting check
tflint               # Linting
pre-commit run --all-files  # Constitution compliance
```

**Expected Results**: All checks pass with zero errors

---

### Post-Deployment Tests

**SSH Connectivity**:
```bash
ssh devuser@$(terraform output -raw instance_public_ip)
# Expected: Password prompt (password must be set first via Session Manager)
```

**fail2ban Protection**:
```bash
# 5 failed attempts should trigger IP block
for i in {1..6}; do ssh devuser@IP_ADDRESS; done
# Expected: 6th attempt refused or timeout
```

**Session Manager Access**:
```bash
aws ssm start-session --target $(terraform output -raw instance_id)
# Expected: Shell session opens via AWS CLI
```

**CloudWatch Logging**:
```bash
aws logs tail $(terraform output -raw log_group_name) --follow
# Expected: SSH authentication events stream in real-time
```

---

## Versioning Contract

**Module Version**: 1.0.0 (inline configuration, not versioned module)

**Change Management**:
- Breaking changes: Require spec update and new feature branch
- Non-breaking changes: In-place updates on feature branch
- Bug fixes: Patch updates with documentation

**Backward Compatibility**:
- State schema: Compatible within Terraform 1.5.x and 1.6.x
- AWS provider: Forward compatible with 5.x releases
- HCP Terraform: Compatible with current workspace configuration

---

## Support Contract

**Supported Use Cases**:
- Development environment SSH access
- Security testing and hardening validation
- CloudWatch monitoring pattern demonstration
- Terraform learning and experimentation

**Unsupported Use Cases**:
- Production workloads
- Compliance-regulated data processing
- High-availability requirements
- Multi-instance deployments

**Support Channels**:
- Feature specification: `/workspace/specs/001-ec2-dev-instance/spec.md`
- Technical questions: Platform team
- Security incidents: Follow organizational incident response procedures

---

## Conclusion

This contract defines the complete interface for the EC2 development instance Terraform configuration, including inputs, outputs, behaviors, guarantees, and limitations. All consumers of this infrastructure code must adhere to these specifications to ensure predictable and secure operation.

**Key Takeaways**:
- Development environment only (not production-ready)
- Requires post-deployment password setup via Session Manager
- CloudWatch monitoring with 7-day retention
- Estimated $10/month operational cost
- 3-5 minute deployment time including user-data execution

**Next Steps**: Review quickstart.md for step-by-step deployment instructions.
