# Research: Public EC2 Instance with Password Authentication

**Feature**: Public EC2 Development Instance  
**Branch**: `001-public-ec2-dev`  
**Date**: 2025-01-17

## Executive Summary

This research document resolves all technical unknowns for provisioning a public EC2 instance with username/password authentication in the ap-southeast-1 region. The solution leverages private registry modules from `ravi-panchal-org` for EC2, security groups, CloudWatch, and IAM resources, with AWS provider data sources for VPC/subnet discovery and AMI selection.

## Module Registry Analysis

### Available Private Modules

Research confirmed the following modules are available in the private registry (`app.terraform.io/ravi-panchal-org`):

1. **ec2-instance** (v6.1.4)
   - Source: `app.terraform.io/ravi-panchal-org/ec2-instance/aws`
   - Supports: IAM instance profile creation, user data, EBS encryption, security group creation, monitoring
   - Key capabilities: Automatic AMI lookup via SSM parameter, root volume encryption, CloudWatch integration

2. **security-group** (v5.3.1)
   - Source: `app.terraform.io/ravi-panchal-org/security-group/aws`
   - Supports: Ingress/egress rules, VPC association, predefined rule templates
   - Key capabilities: SSH rule templates, CIDR-based access control

3. **cloudwatch** (v5.7.2)
   - Source: `app.terraform.io/ravi-panchal-org/cloudwatch/aws`
   - Supports: Log groups, log streams, metric filters, alarms
   - Key capabilities: Log group creation with retention, KMS encryption support

4. **iam** (v6.2.3)
   - Source: `app.terraform.io/ravi-panchal-org/iam/aws`
   - Supports: Roles, instance profiles, policy attachments
   - Key capabilities: EC2 service roles, managed policy attachments

## Technical Decisions

### 1. Module Selection Strategy

**Decision**: Use ec2-instance module as primary infrastructure component

**Rationale**:
- The ec2-instance module includes built-in capabilities for IAM instance profile creation (`create_iam_instance_profile = true`)
- Supports automatic AMI discovery via SSM parameter (`ami_ssm_parameter`)
- Includes integrated security group creation (`create_security_group = true`)
- Provides root volume encryption configuration (`root_block_device`)
- This consolidated approach reduces complexity and inter-module dependencies

**Alternatives Considered**:
- **Separate modules**: Using standalone IAM and security-group modules would require additional outputs/variables and increase configuration complexity
- **Raw AWS provider resources**: Would violate constitution requirement for module-first architecture
- **Rejected because**: The ec2-instance module provides all required functionality in a single, tested component

### 2. VPC and Subnet Discovery

**Decision**: Use AWS provider data sources `aws_vpc` and `aws_subnet` to discover default VPC/subnet

**Rationale**:
- AWS automatically creates a default VPC in each region with CIDR 172.31.0.0/16
- Default VPC includes internet gateway and public subnet configuration
- Data sources are read-only and align with constitution principles
- No module available for VPC discovery (data source is the correct tool)

**Implementation**:
```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
```

**Alternatives Considered**:
- **Hard-coded VPC ID**: Would fail if default VPC is recreated or in different accounts
- **VPC creation module**: Out of scope and contradicts requirement to use existing default VPC
- **Rejected because**: Data sources provide dynamic discovery with zero infrastructure changes

### 3. AMI Selection

**Decision**: Use AMI SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`

**Rationale**:
- AWS maintains SSM parameters with latest Amazon Linux 2023 AMI IDs
- Parameter automatically updates when new AMIs are released
- The ec2-instance module's `ami_ssm_parameter` input supports this natively
- Eliminates need for manual AMI ID updates or data source queries
- Amazon Linux 2023 provides 5 years of support with security updates

**Implementation**:
```hcl
module "ec2_instance" {
  ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
```

**Alternatives Considered**:
- **Data source with filters**: `data "aws_ami" "amazon_linux_2023"` with owner/name filters
  - More verbose and requires explicit data source management
- **Static AMI ID**: Would require manual updates for security patches
- **Rejected because**: SSM parameter is the AWS-recommended best practice and is natively supported by the module

### 4. SSH Password Authentication

**Decision**: Implement user data script to configure password authentication and create devuser

**Rationale**:
- Amazon Linux 2023 defaults to key-based SSH authentication
- Password authentication requires modifying `/etc/ssh/sshd_config` and creating user with password
- User data script executes once at instance launch with root privileges
- Idempotent script with error logging ensures reliability

**Implementation**:
```bash
#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

# Create devuser with generated password
useradd -m -s /bin/bash devuser || true
echo "devuser:${PASSWORD}" | chpasswd

# Enable password authentication
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service
systemctl restart sshd

echo "Password authentication configured successfully"
```

**Security Considerations**:
- 16-character password generated using Terraform `random_password` resource
- Password marked as sensitive in Terraform outputs
- SSH access restricted to port 22 via security group
- Development environment only (not production-grade)

**Alternatives Considered**:
- **AWS Systems Manager Session Manager**: Provides passwordless access but doesn't meet requirement for SSH with username/password
- **EC2 Instance Connect**: Requires IAM credentials, not username/password
- **Rejected because**: Neither alternative satisfies the explicit requirement for SSH password authentication

### 5. CloudWatch Integration

**Decision**: Use CloudWatch agent in user data script for log collection

**Rationale**:
- CloudWatch agent is pre-installed on Amazon Linux 2023 but requires configuration
- Agent can stream `/var/log/messages` to CloudWatch Logs group
- Basic monitoring (5-minute intervals) is free; detailed monitoring costs extra
- Log group must be created before instance launch to ensure agent has a target

**Implementation**:
```bash
# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/sandbox_public_ec2_dev",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

**Cost Optimization**:
- Basic monitoring: Free (5-minute intervals)
- Detailed monitoring: Disabled (would cost $2.10/month)
- CloudWatch Logs: First 5GB free, $0.50/GB afterward
- Estimated monthly cost: ~$2-5 for logs (well under $50 budget)

**Alternatives Considered**:
- **CloudWatch module for agent**: Module provides log group creation but not agent installation/configuration
- **Manual log group only**: Would not capture instance logs
- **Rejected because**: Combination of CloudWatch module for log group + user data script for agent provides complete solution

### 6. IAM Instance Profile

**Decision**: Use ec2-instance module's `create_iam_instance_profile` capability with CloudWatchAgentServerPolicy

**Rationale**:
- EC2 instances require IAM instance profile to access CloudWatch APIs
- Module supports creating instance profile with attached policies
- CloudWatchAgentServerPolicy is AWS-managed and provides minimum required permissions
- Follows least privilege principle

**Implementation**:
```hcl
module "ec2_instance" {
  create_iam_instance_profile = true
  iam_role_policies = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }
}
```

**Alternatives Considered**:
- **Separate IAM module**: Would require coordinating outputs and increase complexity
- **Custom IAM policy**: Would require defining specific permissions (more maintenance)
- **Rejected because**: Module's built-in capability with managed policy is simpler and sufficient

### 7. EBS Encryption

**Decision**: Enable encryption on root volume using AWS-managed keys

**Rationale**:
- AWS-managed KMS keys (`aws/ebs`) are free and automatically rotated
- Provides encryption at rest for security compliance
- No performance impact on t3.micro instances
- Module's `root_block_device` parameter supports encryption configuration

**Implementation**:
```hcl
module "ec2_instance" {
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }
}
```

**Alternatives Considered**:
- **Customer-managed KMS key**: Would cost $1/month + $0.03 per 10k requests
- **No encryption**: Would violate security best practices
- **Rejected because**: AWS-managed keys provide encryption at no cost with automatic rotation

### 8. Security Group Configuration

**Decision**: Use module's built-in security group creation with SSH ingress rule

**Rationale**:
- EC2 instance module includes `create_security_group` parameter
- Module supports defining ingress rules via `security_group_ingress_rules` map
- Egress rules default to allow all (appropriate for development instance)
- Single security group simplifies management

**Implementation**:
```hcl
module "ec2_instance" {
  create_security_group = true
  security_group_vpc_id = data.aws_vpc.default.id
  security_group_ingress_rules = {
    ssh = {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow SSH from anywhere"
    }
  }
}
```

**Security Considerations**:
- 0.0.0.0/0 allows SSH from any IP (acceptable for development environment)
- Production environments should restrict to specific CIDR ranges
- Only port 22 is exposed; all other ports are implicitly denied

**Alternatives Considered**:
- **Separate security-group module**: Would require passing security group ID to EC2 module
- **IP whitelist**: Would require maintaining list of developer IPs
- **Rejected because**: Module's built-in security group is simpler, and 0.0.0.0/0 is acceptable for dev environment per spec

## Architecture Patterns

### Password Generation

**Decision**: Use Terraform `random_password` resource with 16-character length

**Implementation**:
```hcl
resource "random_password" "devuser" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}
```

**Rationale**:
- Terraform-native resource for secure random generation
- Stored in state file (encrypted by HCP Terraform)
- Marked as sensitive to prevent console output
- Meets SSH password complexity requirements

### User Data Idempotency

**Decision**: Make user data script idempotent with `|| true` for user creation

**Implementation**:
```bash
useradd -m -s /bin/bash devuser || true
```

**Rationale**:
- If user already exists, command returns non-zero exit code
- `|| true` prevents script failure and allows re-execution
- Password update via `chpasswd` is idempotent (always succeeds)

### Cost Optimization

**Decision**: Disable detailed monitoring and use basic monitoring

**Implementation**:
```hcl
module "ec2_instance" {
  monitoring = false  # Disable detailed monitoring
}
```

**Cost Breakdown**:
- t3.micro instance: ~$7.50/month (730 hours × $0.0104/hour in ap-southeast-1)
- EBS GP3 8GB: ~$0.80/month ($0.10/GB)
- Data transfer: ~$0 (ingress free, minimal egress)
- CloudWatch Logs: ~$2-5/month (5GB free tier)
- **Total: ~$10-15/month** (well under $50 budget)

## References

### AWS Documentation
- [Amazon Linux 2023 on EC2](https://docs.aws.amazon.com/linux/al2023/ug/ec2.html)
- [Default VPCs](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html)
- [CloudWatch Logs Configuration](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html)
- [CloudWatch Agent for EC2](https://docs.aws.amazon.com/prescriptive-guidance/latest/implementing-logging-monitoring-cloudwatch/configure-cloudwatch-ec2-on-premises.html)

### Module Documentation
- [ec2-instance module](https://github.com/panchal-ravi/terraform-aws-ec2-instance) - v6.1.4
- [security-group module](https://github.com/panchal-ravi/terraform-aws-security-group) - v5.3.1
- [cloudwatch module](https://github.com/panchal-ravi/terraform-aws-cloudwatch) - v5.7.2
- [iam module](https://github.com/panchal-ravi/terraform-aws-iam) - v6.2.3

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Default VPC doesn't exist | Low | High | Error on terraform plan; document manual VPC creation steps |
| t3.micro quota exhausted | Low | High | Check AWS service quotas before deployment; request increase if needed |
| User data script fails | Medium | Medium | Implement comprehensive error logging; fallback to Systems Manager Session Manager |
| Password in Terraform state | Low | Medium | HCP Terraform encrypts state at rest; mark output as sensitive |
| CloudWatch agent fails to start | Low | Low | Instance is still accessible; logs available in `/var/log/user-data.log` |
| Cost exceeds budget | Low | Low | t3.micro + 8GB storage is ~$10-15/month; significant margin under $50 budget |

## Open Questions (Resolved)

All technical unknowns from the specification have been resolved:

✅ **Q**: Which modules are available in the private registry?  
**A**: ec2-instance, security-group, cloudwatch, and iam modules are available and sufficient for all requirements.

✅ **Q**: How to discover default VPC and subnet?  
**A**: Use AWS provider data sources `aws_vpc` and `aws_subnet` with `default = true` filter.

✅ **Q**: How to automatically select latest Amazon Linux 2023 AMI?  
**A**: Use SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` via module's `ami_ssm_parameter` input.

✅ **Q**: How to configure SSH password authentication?  
**A**: User data script to modify `/etc/ssh/sshd_config`, create devuser, and restart sshd service.

✅ **Q**: How to integrate CloudWatch Logs?  
**A**: Combination of CloudWatch module for log group creation and user data script for CloudWatch agent configuration.

✅ **Q**: How to attach CloudWatchAgentServerPolicy?  
**A**: Use ec2-instance module's `create_iam_instance_profile` with `iam_role_policies` map.

✅ **Q**: How to minimize costs?  
**A**: Disable detailed monitoring, use basic monitoring (free), GP3 volumes, and t3.micro instance type.

## Next Steps

Proceed to **Phase 1: Design & Contracts** to:
1. Generate data-model.md with entity relationships
2. Create contract definitions in `/contracts/` directory
3. Generate quickstart.md with deployment instructions
4. Update agent context with new technologies
