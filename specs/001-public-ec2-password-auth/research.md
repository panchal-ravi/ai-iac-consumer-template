# Phase 0: Research & Technology Decisions

**Feature**: Public EC2 Instance with Password Authentication  
**Date**: 2025-01-21  
**Branch**: `001-public-ec2-password-auth`

---

## Executive Summary

This research phase consolidates all technology decisions and best practices for provisioning a public EC2 instance with password authentication in AWS ap-southeast-1. All previously identified "NEEDS CLARIFICATION" items have been resolved through user input and research findings.

---

## 1. Module Selection Strategy (Constitution Requirement)

### Decision: Use Private Registry Modules

**Rationale**: The project constitution mandates module-first architecture with consumption exclusively from the private registry (`app.terraform.io/ravi-panchal-org/`).

**Available Private Modules**:

| Module | Version | Purpose | Source |
|--------|---------|---------|--------|
| `ravi-panchal-org/ec2-instance/aws` | 6.1.4 | Core EC2 instance provisioning | app.terraform.io/ravi-panchal-org/ec2-instance/aws |
| `ravi-panchal-org/vpc/aws` | 6.5.0 | VPC with subnets and IGW | app.terraform.io/ravi-panchal-org/vpc/aws |
| `ravi-panchal-org/security-group/aws` | Latest | Security group management | app.terraform.io/ravi-panchal-org/security-group/aws |
| `ravi-panchal-org/cloudwatch/aws` | 5.7.2 | CloudWatch log groups | app.terraform.io/ravi-panchal-org/cloudwatch/aws |
| `ravi-panchal-org/iam/aws` | Latest | IAM roles and policies | app.terraform.io/ravi-panchal-org/iam/aws |

**Alternatives Considered**: Public registry modules (terraform-aws-modules/*) were rejected because they violate the constitution's module source requirement.

**Implementation Pattern**:
```hcl
module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"
  # ... inputs
}
```

---

## 2. AMI Selection Strategy

### Decision: Ubuntu 22.04 LTS with Dynamic Lookup

**Rationale**: Chosen based on user clarification. Ubuntu provides better package availability for CloudWatch Agent and widespread community support.

**Implementation Approach**:
- Use `aws_ami` data source with filter pattern: `ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*`
- Filter by `most_recent = true` to always get latest security patches
- Owner ID: `099720109477` (Canonical)

**Alternatives Considered**:
- Amazon Linux 2023: Rejected per user specification favoring Ubuntu
- Hardcoded AMI ID: Rejected due to lack of automatic security updates

**Research Finding**: AWS recommends dynamic AMI lookup to ensure security patches are applied automatically on infrastructure recreation.

---

## 3. Password Generation & Management

### Decision: Terraform `random_password` Resource

**Rationale**: User specified this approach for cryptographically secure password generation with Terraform state management.

**Configuration**:
```hcl
resource "random_password" "instance_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}
```

**Storage Strategy**:
- Mark as `sensitive = true` in Terraform outputs
- Store in HCP Terraform workspace as sensitive variable
- Never log or display in plain text

**Alternatives Considered**:
- AWS Secrets Manager: Rejected for simplicity; adds cost and complexity
- Manual password entry: Rejected for lack of automation and security

**Security Note**: AWS Inspector and security best practices strongly discourage password authentication (see Security Research below). This is accepted for development-only use.

---

## 4. VPC Strategy

### Decision: Default VPC with Custom VPC Fallback

**Rationale**: User specified to prefer default VPC for simplicity, with automatic custom VPC creation if default is missing.

**Implementation Logic**:
1. Check for default VPC in ap-southeast-1 using data source
2. If exists: Use default VPC and first available public subnet
3. If missing: Create custom VPC with:
   - CIDR: `10.0.0.0/16`
   - Public subnet: `10.0.1.0/24` in first available AZ
   - Internet Gateway attached
   - Route table with 0.0.0.0/0 → IGW route

**Module Usage**: `ravi-panchal-org/vpc/aws` module supports public subnet creation with IGW.

**Alternatives Considered**:
- Require default VPC: Rejected for lack of flexibility
- Always create custom VPC: Rejected as unnecessarily complex

---

## 5. CloudWatch Agent Configuration

### Decision: CloudWatch Agent with Auth Log Shipping

**Rationale**: User specified CloudWatch Agent to ship `/var/log/auth.log` to CloudWatch Logs for SSH authentication monitoring.

**Configuration Approach**:
- **Log Group**: `/aws/ec2/ssh-auth`
- **Log Stream**: Instance ID (`{instance_id}`)
- **Retention**: 7 days (minimum for development)
- **Agent Installation**: Via user-data script using AWS CloudWatch Agent

**CloudWatch Agent Configuration** (user-data embedded):
```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "/aws/ec2/ssh-auth",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
```

**IAM Requirements**:
- Attach AWS managed policy: `CloudWatchAgentServerPolicy`
- Provides permissions: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

**Research Findings** (AWS Documentation):
- CloudWatch Agent is the recommended method (older CloudWatch Logs agent is deprecated)
- Agent configuration can be embedded in user-data or stored in SSM Parameter Store
- For this use case, embedded configuration is simpler

**Alternatives Considered**:
- SSM Parameter Store for config: Rejected for simplicity
- Legacy CloudWatch Logs agent: Rejected (deprecated)
- Manual log shipping: Rejected (not automated)

---

## 6. Password Authentication Configuration

### Decision: User-data Script with SSH Configuration

**Rationale**: User specified user-data script approach for instance initialization, enabling password authentication.

**User-data Script Tasks**:
1. Create `devuser` account
2. Set password from Terraform variable (passed securely)
3. Modify `/etc/ssh/sshd_config`:
   - Set `PasswordAuthentication yes`
   - Set `ChallengeResponseAuthentication no`
   - Set `UsePAM yes`
4. Restart `sshd` service
5. Install and configure CloudWatch Agent
6. Log all actions to `/var/log/user-data.log`

**Error Handling**:
- Exit codes logged for each step
- Failures logged to CloudWatch (once agent is running)
- Manual recovery required for failures (no automated retry)

**Alternatives Considered**:
- AWS Systems Manager Run Command: Rejected; requires instance to boot first
- Pre-baked AMI: Rejected; reduces flexibility and increases maintenance

---

## 7. Security Configuration

### Decision: Security Group with Selective Port Access

**Configuration**:
- **Inbound Rules**:
  - SSH (port 22): `0.0.0.0/0` (required for development access)
  - HTTP (port 80): Optional, `0.0.0.0/0`
  - HTTPS (port 443): Optional, `0.0.0.0/0`
- **Outbound Rules**: All traffic allowed (required for package updates, CloudWatch)

**Security Research Findings** (AWS Documentation):

From **AWS Inspector Best Practices**:
> "It is recommended to disable password authentication and enable key-based authentication instead."

From **AWS Security Blog**:
> "Long-term credentials continue to be a significant security risk... Use IAM roles and federated access instead."

**Risk Acceptance**:
This implementation **violates AWS security best practices** by:
1. Enabling password authentication (vs. key-based)
2. Allowing SSH from `0.0.0.0/0` (vs. restricted IP ranges)
3. No MFA or additional protection layers

These violations are **explicitly accepted** for development/sandbox environment only. For production, the following would be required:
- Switch to SSH key-based authentication
- Restrict SSH to corporate IP ranges or VPN
- Implement AWS Systems Manager Session Manager
- Add fail2ban or similar intrusion prevention
- Enable MFA for SSH access

---

## 8. Elastic IP Configuration

### Decision: Elastic IP with Instance Association

**Rationale**: User story requires stable public IP across stop/start cycles.

**Configuration**:
- Allocate Elastic IP in VPC domain
- Associate with EC2 instance
- Release on instance termination (automated)

**Cost Impact**: Elastic IP is free when associated with running instance, but costs $0.005/hour when unassociated.

**Alternatives Considered**:
- Dynamic public IP: Rejected; changes on stop/start
- No public IP with VPN: Rejected; out of scope

---

## 9. Instance Configuration

### Decision: t3.micro in ap-southeast-1

**Specifications**:
- **Instance Type**: t3.micro (1 vCPU, 1 GB RAM)
- **Region**: ap-southeast-1 (Singapore)
- **Storage**: GP3 EBS root volume, 8-20 GB
- **Network**: Public subnet with Elastic IP

**Cost Estimation**:
- t3.micro: ~$0.0104/hour (~$7.50/month)
- EBS GP3 8GB: ~$0.80/month
- Elastic IP: $0 (while associated)
- CloudWatch Logs: ~$0.50/month (minimal usage)
- **Total**: ~$10-15/month

**Alternatives Considered**:
- Larger instance types: Rejected for cost
- Spot instances: Rejected for stability in development

---

## 10. HCP Terraform Configuration

### Decision: Use Specified Workspace Configuration

**Configuration**:
- **Organization**: `ravi-panchal-org`
- **Project**: Default Project
- **Workspace**: `sandbox_public_ec2_dev`
- **Execution Mode**: Remote (HCP Terraform)
- **Region**: ap-southeast-1

**Variable Management**:
- Store generated password as sensitive workspace variable
- Use variable sets for shared configuration (optional)

**Alternatives Considered**: None; specified by user.

---

## 11. Testing Strategy

### Decision: Multi-Phase Testing Approach

**Test Phases**:

1. **Infrastructure Validation** (Phase 1):
   - Terraform validate passes
   - Terraform plan shows expected resources
   - No resource drift

2. **Provisioning Tests** (Phase 2):
   - Instance launches successfully
   - Public IP assigned
   - Security group configured correctly
   - Elastic IP associated

3. **Access Tests** (Phase 3):
   - SSH connection succeeds with password
   - Correct user account (devuser)
   - Shell access functional

4. **Logging Tests** (Phase 4):
   - CloudWatch log group created
   - Auth logs appearing in CloudWatch
   - Log retention configured

5. **Security Tests** (Phase 5):
   - Unauthorized ports blocked
   - Wrong password denied
   - Logs capture failed attempts

**Alternatives Considered**:
- Automated integration tests: Deferred to implementation phase
- Compliance scanning: Out of scope for development

---

## 12. Documentation Requirements

### Decision: Comprehensive User Documentation

**Required Documentation**:
1. **Connection Guide**: SSH command with placeholders
2. **Password Retrieval**: Step-by-step from HCP Terraform
3. **Troubleshooting Guide**: Common connection issues
4. **Security Warnings**: Risk acknowledgment
5. **Cost Monitoring**: How to track spend
6. **Cleanup Instructions**: Resource termination

**Format**: Markdown with code examples and screenshots.

**Alternatives Considered**: None; specified in requirements.

---

## 13. User-data Script Error Handling

### Decision: Log-based Error Tracking with Manual Recovery

**Rationale**: User specified manual recovery approach for simplicity.

**Error Handling Strategy**:
- Log all actions to `/var/log/user-data.log`
- Log to CloudWatch once agent is running
- Use exit codes for each step
- No automated retry or rollback

**User-data Script Structure**:
```bash
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user-data script..."

# Step 1: Create user
if ! useradd -m -s /bin/bash devuser; then
  echo "ERROR: Failed to create devuser (exit code: 1)"
  exit 1
fi

# Step 2: Set password
# ... (continue for each step)
```

**Monitoring**: Check CloudWatch Logs and instance console output for failures.

**Alternatives Considered**:
- Automated retry: Rejected for complexity
- CloudFormation wait conditions: Rejected; using Terraform

---

## 14. Technology Stack Summary

| Component | Technology | Version | Justification |
|-----------|-----------|---------|---------------|
| IaC Tool | Terraform | Latest | Org standard, HCP Terraform integration |
| Orchestration | HCP Terraform | SaaS | Specified workspace configuration |
| OS | Ubuntu 22.04 LTS | Latest | User specification, package availability |
| Instance Type | t3.micro | N/A | Cost optimization requirement |
| Password Gen | random_password | Terraform | User specification for automation |
| Logging | CloudWatch Agent | Latest | AWS recommended, user specified |
| VPC | Default + Fallback | N/A | User specification for simplicity |
| Network | Public Subnet + EIP | N/A | Public access requirement |
| IAM | Instance Profile | N/A | CloudWatch Agent permissions |
| Region | ap-southeast-1 | N/A | User specification |

---

## 15. Risk Summary

| Risk ID | Description | Severity | Mitigation | Acceptance |
|---------|-------------|----------|------------|------------|
| RISK-001 | Password authentication less secure than keys | HIGH | Strong password, logging | Accepted (dev only) |
| RISK-002 | Open SSH access (0.0.0.0/0) | HIGH | CloudWatch monitoring | Accepted (dev only) |
| RISK-003 | No automated security patching | MEDIUM | Manual updates | Accepted (dev only) |
| RISK-004 | Single instance (no HA) | LOW | Manual recreation | Accepted (dev only) |
| RISK-005 | No automated password rotation | MEDIUM | Manual rotation | Accepted (dev only) |

**Overall Risk Posture**: This implementation is **NOT suitable for production** and is explicitly designed for development/sandbox environments only.

---

## 16. Open Questions & Answers

All "NEEDS CLARIFICATION" items from Technical Context have been resolved:

| Question | Answer | Source |
|----------|--------|--------|
| AMI selection strategy? | Ubuntu 22.04 LTS with dynamic lookup | User clarification |
| Password generation approach? | Terraform random_password resource | User clarification |
| CloudWatch logging scope? | Ship /var/log/auth.log via CloudWatch Agent | User clarification |
| VPC strategy? | Default VPC with custom fallback | User clarification |
| User-data error handling? | Log to CloudWatch, manual recovery | User clarification |

---

## 17. Dependencies & Prerequisites

**External Dependencies**:
- AWS account with active billing
- HCP Terraform organization: `ravi-panchal-org`
- IAM permissions: EC2, VPC, CloudWatch, IAM
- AWS region ap-southeast-1 operational

**Infrastructure Dependencies**:
- Default VPC (or ability to create custom VPC)
- Elastic IP quota available
- t3.micro capacity in ap-southeast-1
- Ubuntu 22.04 LTS AMI available

**No Internal Dependencies**: This is a standalone infrastructure feature.

---

## 18. Next Steps (Phase 1)

Phase 0 research is complete. Proceed to Phase 1 with the following tasks:

1. **Create data-model.md**: Define entities (Instance, VPC, Security Group, etc.)
2. **Generate contracts/**: Terraform variable contracts and output contracts
3. **Create quickstart.md**: Quick start guide for users
4. **Update agent context**: Add Terraform/AWS context for agent awareness

All technology decisions are now finalized and documented.

---

**Research Phase Complete**: All unknowns resolved. Ready for Phase 1 (Design & Contracts).
