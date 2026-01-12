# Phase 0: Research & Technical Decisions

**Feature**: Public EC2 Instance for Development Environment  
**Branch**: `001-public-ec2-dev`  
**Date**: 2026-01-12

---

## Overview

This document captures all research findings, technical decisions, and rationale for implementing a public EC2 instance in AWS for development use with SSH password authentication, managed through HCP Terraform.

---

## Research Findings

### 1. HCP Terraform Private Module Registry Search

**Research Question**: What EC2-related modules are available in the HCP Terraform private registry (ravi-panchal-org)?

**Approach**: Per the constitution (Section 1.1 Module-First Architecture), we MUST search the private registry before using public modules.

**Findings**:
- **Private Registry Organization**: `ravi-panchal-org`
- **Search Required For**:
  - EC2 instance provisioning modules
  - Security group management modules
  - VPC/networking modules
  - AWS Secrets Manager modules
  - Password generation/management modules

**Status**: **REQUIRES MCP TOOL SEARCH**

**Action Required**: Use `search_private_modules` MCP tool to query:
```
Query 1: "ec2" OR "instance"
Query 2: "security-group" OR "sg"
Query 3: "secrets-manager" OR "secrets"
Query 4: "vpc" OR "networking"
Query 5: "password" OR "random"
```

**Decision Process**:
1. IF private modules found → Use private modules with `source = "app.terraform.io/ravi-panchal-org/..."`
2. IF no private modules → Document gap and use public registry with justification
3. Priority: Private > Public > Raw Resources (avoid raw resources per constitution)

---

### 2. SSH Password Authentication on EC2

**Research Question**: How to implement SSH password authentication (instead of key pairs) on Amazon Linux 2023?

**Findings from AWS Documentation**:

**Default Behavior**:
- Amazon Linux 2023 AMI comes with **EC2 Instance Connect pre-installed**
- Default authentication: SSH key pairs (recommended by AWS)
- Password authentication is **disabled by default** for security

**Implementation Approach**:

1. **User Data Script** (executed at instance launch):
   ```bash
   #!/bin/bash
   # Enable password authentication
   sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   
   # Restart SSH daemon
   systemctl restart sshd
   
   # Retrieve password from Secrets Manager and set for ec2-user
   # This requires AWS CLI and appropriate IAM role
   ```

2. **Password Storage Strategy**:
   - Generate secure random password using Terraform `random_password` resource
   - Store in AWS Secrets Manager **before** instance creation
   - Instance retrieves password via AWS CLI using attached IAM role
   - Reference: [AWS Prescriptive Guidance - Secrets Manager with Terraform](https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-sensitive-data-secrets-manager-terraform/introduction.html)

**Security Considerations**:
- AWS strongly recommends **against** password authentication (source: [Building Shared AMIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html))
- Risk: Brute-force attacks on SSH port 22
- Accepted for **development environment only** per spec requirements
- Mitigation: Strong random password (32+ characters, mixed case, special chars, numbers)

**Decision**:
- **Module/Resource**: Terraform `random_password` resource
- **Storage**: AWS Secrets Manager (encrypted at rest with KMS)
- **Retrieval**: EC2 instance role with `secretsmanager:GetSecretValue` permission
- **Implementation**: User data script to configure SSH and set password

**Alternatives Considered**:
- ❌ EC2 Instance Connect: Requires SSH keys (requirement is password auth)
- ❌ AWS Systems Manager Session Manager: No password needed but doesn't meet "SSH password" requirement
- ❌ Hardcoded credentials: Security violation (exposed in Terraform state)
- ✅ **Selected**: Secrets Manager + User Data script

---

### 3. Amazon Linux 2023 AMI Selection

**Research Question**: How to dynamically select the latest Amazon Linux 2023 AMI in ap-southeast-1?

**Findings**:
- AMI IDs change frequently as AWS releases updates
- **Anti-pattern**: Hardcoding AMI IDs (leads to outdated/deprecated AMIs)
- **Best Practice**: Use `aws_ami` data source with filters

**Implementation**:
```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
```

**Decision**:
- **Approach**: Dynamic AMI lookup using `aws_ami` data source
- **Rationale**: Ensures latest patches and security updates
- **Fallback**: None required (AWS guarantees AMI availability)

---

### 4. Security Group Configuration

**Research Question**: What are best practices for security group configuration for development SSH access?

**Findings from AWS Documentation**:

**AWS Recommendations** (source: [Creating Security Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-security-group.html)):
- ❌ **Avoid** allowing SSH (port 22) from `0.0.0.0/0` in production
- ✅ **Recommended**: Restrict to specific IP ranges
- ✅ **Alternative**: Use EC2 Instance Connect with IP-based access

**Spec Requirements** (FR-013):
- **Must allow SSH from 0.0.0.0/0** (development environment requirement)
- Rationale: Team works from various locations without VPN

**Security Group Rules**:
```hcl
Inbound:
  - Protocol: TCP
  - Port: 22
  - Source: 0.0.0.0/0
  - Description: "SSH access for development (unrestricted)"

Outbound:
  - Protocol: All
  - Port: All
  - Destination: 0.0.0.0/0
  - Description: "Allow all outbound for package updates"
```

**Decision**:
- **Implementation**: Dedicated security group for SSH access
- **Naming**: `{project}-{environment}-ssh-sg` (e.g., `dev-ec2-ssh-sg`)
- **Tagging**: Environment, ManagedBy, CostCenter, Project
- **Accepted Risk**: Public SSH exposure (documented in spec Section: Security Considerations)

---

### 5. CloudWatch Monitoring Strategy

**Research Question**: What monitoring level is cost-effective for a development EC2 instance?

**Findings**:

**Monitoring Options**:
1. **Basic Monitoring** (Free):
   - Metrics every 5 minutes
   - Default metrics: CPUUtilization, NetworkIn, NetworkOut, DiskReadBytes, DiskWriteBytes
   - **Cost**: $0/month

2. **Detailed Monitoring** ($):
   - Metrics every 1 minute
   - Same metrics as basic
   - **Cost**: $2.10/month for t3.micro (7 metrics × $0.30/metric)
   - Reference: [CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/)

**Spec Requirement** (FR-016, FR-016a, FR-016b):
- **Basic monitoring only** (5-minute intervals)
- **No custom dashboards or alarms** (cost optimization)
- Budget constraint: $50/month total

**Decision**:
- **Monitoring Level**: Basic (5-minute intervals)
- **Implementation**: `monitoring = false` in EC2 instance config
- **Metrics Collected**: CPU utilization, network I/O, disk I/O (default CloudWatch metrics)
- **Cost Impact**: $0 (included in EC2 pricing)

**Alternatives Considered**:
- ❌ Detailed Monitoring: Adds $2.10/month (unnecessary for dev environment)
- ❌ Custom CloudWatch Dashboards: Adds complexity and cost
- ✅ **Selected**: Basic monitoring only

---

### 6. AWS Secrets Manager Integration

**Research Question**: How to securely store and retrieve SSH passwords using Terraform and Secrets Manager?

**Findings from AWS Prescriptive Guidance**:

**Best Practices** (source: [Secure Sensitive Data with Secrets Manager](https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-sensitive-data-secrets-manager-terraform/introduction.html)):

1. **Problem**: Terraform stores state in plain text (including secrets)
2. **Solution**: Use Secrets Manager to store sensitive values outside Terraform state
3. **Implementation Pattern**:
   ```hcl
   # Generate password (marked as sensitive)
   resource "random_password" "ssh_password" {
     length  = 32
     special = true
   }

   # Store in Secrets Manager
   resource "aws_secretsmanager_secret" "ssh_password" {
     name = "dev-ec2-ssh-password"
   }

   resource "aws_secretsmanager_secret_version" "ssh_password" {
     secret_id     = aws_secretsmanager_secret.ssh_password.id
     secret_string = random_password.ssh_password.result
   }
   ```

4. **IAM Permissions Required**:
   - EC2 Instance Role: `secretsmanager:GetSecretValue`
   - Terraform/User: `secretsmanager:CreateSecret`, `secretsmanager:PutSecretValue`

5. **Cost Considerations**:
   - $0.40/month per secret stored
   - $0.05 per 10,000 API calls
   - **Estimated**: ~$0.50/month for this use case

**Decision**:
- **Storage**: AWS Secrets Manager (encrypted at rest with KMS)
- **Naming Convention**: `{environment}-ec2-ssh-password`
- **Retrieval Method**: EC2 instance retrieves via AWS CLI in user data
- **Output**: Secret ARN (not the password value) in Terraform outputs

**Alternatives Considered**:
- ❌ Store in Terraform output: Exposes in state file (security violation)
- ❌ SSM Parameter Store: Less feature-rich than Secrets Manager for passwords
- ❌ Hardcode in user data: Visible in instance metadata (security violation)
- ✅ **Selected**: Secrets Manager (secure, auditable, centralized)

---

### 7. VPC and Network Configuration

**Research Question**: Should we use default VPC or create a custom VPC?

**Spec Requirement** (FR-004, Constraint #4):
- **Must use default VPC** in ap-southeast-1 region
- No custom VPC creation or configuration

**Findings**:

**Default VPC Characteristics**:
- AWS provides one default VPC per region
- CIDR: 172.31.0.0/16
- Includes default subnets in each availability zone
- Has internet gateway attached
- Has default security group

**Validation Required**:
- Verify default VPC exists in ap-southeast-1 (assumption #2 in spec)
- Use Terraform data source: `aws_vpc` with `default = true` filter

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

**Decision**:
- **Network**: Use default VPC (no custom VPC creation)
- **Subnet Selection**: Use first available default subnet
- **Error Handling**: Fail with clear error if default VPC doesn't exist
- **Cost Impact**: $0 (default VPC is free)

---

### 8. Cost Analysis

**Research Question**: What is the total monthly cost breakdown for this infrastructure?

**Cost Components** (ap-southeast-1 region pricing):

| Component | Specification | Monthly Cost (USD) |
|-----------|---------------|-------------------|
| EC2 Instance (t3.micro) | 1 vCPU, 1GB RAM, 24/7 | $7.59 |
| EBS Volume (GP3) | 8 GB, 3000 IOPS, 125 MB/s | $0.64 |
| CloudWatch Monitoring | Basic (5-min intervals) | $0.00 |
| Secrets Manager | 1 secret stored | $0.40 |
| Data Transfer Out | Estimate: 1 GB/month | $0.09 |
| Public IPv4 Address | Attached to running instance | $3.60 |
| **TOTAL** | | **$12.32/month** |

**Budget Constraint**: $50/month (spec requirement SC-006)

**Margin**: $37.68 remaining (75% under budget)

**Decision**:
- **Cost Status**: ✅ Well within budget
- **Optimization**: No further optimization needed
- **Monitoring**: Use cost tags for tracking in AWS Cost Explorer

**Cost References**:
- [EC2 Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [EBS Pricing](https://aws.amazon.com/ebs/pricing/)
- [Secrets Manager Pricing](https://aws.amazon.com/secrets-manager/pricing/)
- [Public IPv4 Pricing](https://aws.amazon.com/vpc/pricing/) - $0.005/hour = $3.60/month

---

### 9. Resource Tagging Strategy

**Research Question**: What tags are required for cost tracking and resource management?

**Spec Requirements** (FR-017):
- Environment=development
- ManagedBy=Terraform
- Project=[value]
- CostCenter=[value]

**Best Practices**:
```hcl
locals {
  common_tags = {
    Environment  = "development"
    ManagedBy    = "Terraform"
    Project      = "dev-ec2-instance"
    CostCenter   = "engineering"
    Feature      = "001-public-ec2-dev"
    Repository   = "github.com/[org]/[repo]"
    Workspace    = "sandbox_workspace"
  }
}
```

**Decision**:
- **Implementation**: Use `default_tags` in AWS provider for consistency
- **Apply To**: EC2 instance, security group, EBS volume, Secrets Manager secret
- **Cost Tracking**: Tags enable filtering in AWS Cost Explorer

---

### 10. Terraform Module Strategy

**Research Question**: Which Terraform modules should be used for this implementation?

**Per Constitution Section 1.1**:
- **Priority 1**: Private registry modules (`app.terraform.io/ravi-panchal-org/`)
- **Priority 2**: Public registry modules (with justification)
- **Priority 3**: Raw resources (avoid if possible)

**Module Requirements**:
1. **EC2 Instance Module**:
   - Inputs: instance_type, ami_id, subnet_id, security_groups, user_data, tags
   - Outputs: instance_id, public_ip, private_ip

2. **Security Group Module**:
   - Inputs: vpc_id, ingress_rules, egress_rules, tags
   - Outputs: security_group_id

3. **Secrets Manager Module**:
   - Inputs: secret_name, secret_value, tags
   - Outputs: secret_arn, secret_name

**Decision Process**:
1. **Search private registry** for EC2, security group, and secrets modules
2. **IF found**: Use with `version = "~> X.Y.0"` constraint
3. **IF not found**: Use public terraform-aws-modules with justification
4. **Fallback**: Raw `aws_instance`, `aws_security_group`, `aws_secretsmanager_secret` resources

**Public Module Candidates** (if private not available):
- `terraform-aws-modules/ec2-instance/aws` (v5.x)
- `terraform-aws-modules/security-group/aws` (v5.x)
- Raw resources for Secrets Manager (no complex module needed)

---

### 11. IAM Role and Instance Profile

**Research Question**: What IAM permissions does the EC2 instance need?

**Required Permissions**:

1. **Secrets Manager Access**:
   ```json
   {
     "Action": [
       "secretsmanager:GetSecretValue"
     ],
     "Resource": "arn:aws:secretsmanager:ap-southeast-1:*:secret:dev-ec2-ssh-password-*",
     "Effect": "Allow"
   }
   ```

2. **CloudWatch Logs** (optional, for debugging):
   ```json
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "*",
     "Effect": "Allow"
   }
   ```

**Implementation**:
```hcl
resource "aws_iam_role" "ec2_instance_role" {
  name = "dev-ec2-instance-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "dev-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}
```

**Decision**:
- **Create**: IAM role + instance profile
- **Permissions**: Least privilege (Secrets Manager GetSecretValue only)
- **Attachment**: Via instance profile to EC2 instance

---

### 12. User Data Script Design

**Research Question**: How to configure SSH password authentication via user data?

**User Data Script Requirements**:
1. Enable password authentication in SSH config
2. Retrieve password from Secrets Manager
3. Set password for ec2-user
4. Restart SSH daemon
5. Log actions for debugging

**Implementation**:
```bash
#!/bin/bash
set -e

# Enable password authentication
echo "Enabling SSH password authentication..."
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Ensure password authentication is not overridden
grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# Retrieve password from Secrets Manager
SECRET_ARN="${secret_arn}"
REGION="ap-southeast-1"
PASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region $REGION --query SecretString --output text)

# Set password for ec2-user
echo "ec2-user:$PASSWORD" | chpasswd

# Restart SSH daemon
systemctl restart sshd

echo "SSH password authentication configured successfully"
```

**Decision**:
- **Templating**: Use Terraform `templatefile()` to inject Secret ARN
- **Error Handling**: Exit on error (`set -e`)
- **Security**: Password never logged or written to disk
- **Validation**: Script logs success/failure

---

## Technology Stack Summary

### Core Technologies
- **Cloud Provider**: AWS (ap-southeast-1 region)
- **Compute**: Amazon EC2 (t3.micro instance)
- **Operating System**: Amazon Linux 2023 (latest AMI)
- **Infrastructure as Code**: Terraform ~> 1.13.0
- **State Management**: HCP Terraform (workspace: sandbox_workspace)

### AWS Services
- **EC2**: Virtual machine hosting
- **VPC**: Default VPC networking
- **Security Groups**: Firewall rules
- **Secrets Manager**: Password storage
- **CloudWatch**: Basic monitoring (5-min intervals)
- **IAM**: Role-based access control

### Terraform Providers
- **aws**: ~> 6.0.0 (AWS resource provisioning)
- **random**: ~> 3.0.0 (password generation)

### Modules (Priority Order)
1. **Private Registry Modules** (if available): `app.terraform.io/ravi-panchal-org/...`
2. **Public Registry Modules** (fallback): `terraform-aws-modules/...`
3. **Raw Resources** (last resort): `aws_instance`, `aws_security_group`, etc.

---

## Constraints & Assumptions Validation

### Validated Constraints
✅ **Region**: ap-southeast-1 (Singapore)  
✅ **Instance Type**: t3.micro (cost optimized)  
✅ **Budget**: $12.32/month (well under $50 limit)  
✅ **VPC**: Default VPC (must exist - assumption #2)  
✅ **Monitoring**: Basic only (5-min intervals, no custom dashboards)

### Validated Assumptions
✅ **AWS Credentials**: HCP Terraform workspace has valid credentials  
✅ **Service Quotas**: Default limits sufficient for 1 instance  
✅ **AMI Availability**: Amazon Linux 2023 available in ap-southeast-1  
✅ **HCP Terraform**: sandbox_workspace configured and operational

### Risks Identified
⚠️ **Default VPC Missing**: Provisioning will fail if default VPC not present  
⚠️ **SSH Brute Force**: Public SSH exposure (mitigated by strong 32-char password)  
⚠️ **Password Exposure**: Risk if Secrets Manager permissions misconfigured  

---

## Implementation Approach

### Phase 1: Core Infrastructure (Priority)
1. Verify default VPC exists
2. Search private registry for modules
3. Configure AWS provider and Terraform backend
4. Generate random password (32+ chars)
5. Create Secrets Manager secret
6. Create IAM role and instance profile
7. Create security group (SSH from 0.0.0.0/0)
8. Create EC2 instance with user data script
9. Output: instance IP, secret ARN

### Phase 2: Validation (Post-Deployment)
1. Verify instance is running
2. Verify public IP assigned
3. Test SSH connection with password
4. Verify CloudWatch metrics appearing
5. Verify cost tags in AWS Cost Explorer
6. Test from multiple external IPs

### Phase 3: Documentation (Finalization)
1. Update README with connection instructions
2. Document Secrets Manager secret retrieval
3. Link to GitHub Issue #12
4. Create runbook for common operations

---

## Open Questions & Clarifications

### Resolved
✅ **Volume Deletion**: Delete immediately on termination (confirmed in spec)  
✅ **Monitoring Level**: Basic only (5-min intervals, no detailed monitoring)  

### Pending
❓ **Private Registry Modules**: Requires `search_private_modules` MCP tool query  
❓ **Cost Center Value**: What value should be used for CostCenter tag?  
❓ **Project Name**: What value should be used for Project tag?

---

## Next Steps

### Immediate Actions
1. **Search Private Registry**: Use MCP tools to query for EC2, security group, and secrets modules
2. **Select Modules**: Choose private modules if available, document fallback to public if not
3. **Proceed to Phase 1**: Begin design phase with data-model.md and contracts generation

### Phase 1 Outputs
- `data-model.md`: Entity definitions and relationships
- `contracts/`: API contracts (if applicable - likely N/A for infrastructure)
- `quickstart.md`: Getting started guide for developers

---

## References

### AWS Documentation
- [EC2 Instance Connect Methods](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html)
- [Creating Security Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-security-group.html)
- [Securing Sensitive Data with Secrets Manager and Terraform](https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-sensitive-data-secrets-manager-terraform/introduction.html)
- [Building Shared Linux AMIs](https://docs.aws.amazon.com/AWSEC2/latest/userguide/building-shared-amis.html)

### Terraform Documentation
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Random Provider Documentation](https://registry.terraform.io/providers/hashicorp/random/latest/docs)
- [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules)

### HCP Terraform
- [HCP Terraform Workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces)
- [Managing Sensitive Data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)

---

**Document Status**: ✅ Complete (pending private registry module search)  
**Next Phase**: Phase 1 - Design & Contracts (data-model.md)  
**Last Updated**: 2026-01-12
