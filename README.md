# EC2 ALB Nginx Infrastructure

High-availability web infrastructure using EC2 instances with Application Load Balancer and Nginx web server across 2 availability zones.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Validation](#validation)
- [Security](#security)
- [Cost Estimation](#cost-estimation)
- [Troubleshooting](#troubleshooting)

## 🏗️ Architecture Overview

```
Internet
    │
    ├─── ALB (HTTPS:443 / HTTP:80→HTTPS)
    │      │
    │      ├─── Target Group (Health Checks)
    │      │         │
    │      │         ├─── EC2 Instance 1 (Nginx) - AZ-A
    │      │         └─── EC2 Instance 2 (Nginx) - AZ-B
```

### Components

- **Application Load Balancer**: Internet-facing ALB with HTTPS listener (post-quantum TLS policy)
- **EC2 Instances**: 2x t3.micro instances running Amazon Linux 2023 with Nginx
- **Security Groups**: Least-privilege network access controls
- **IAM**: Custom IAM role with minimal permissions for Session Manager
- **High Availability**: Multi-AZ deployment across 2 availability zones

### Key Features

✅ **HTTPS-Only Access**: All HTTP traffic redirected to HTTPS (HTTP 301)  
✅ **Post-Quantum TLS**: `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09` SSL policy  
✅ **EBS Encryption**: All volumes encrypted with AWS managed keys  
✅ **IMDSv2 Enforcement**: Instance metadata requires session tokens  
✅ **Least Privilege IAM**: Custom IAM policy (no generic managed policies)  
✅ **Health Checks**: Automatic failover for unhealthy instances  
✅ **Session Manager Access**: Secure shell access without SSH keys

## 📦 Prerequisites

### Required

1. **HCP Terraform Account** with organization `ravi-panchal-org`
2. **AWS Account** with credentials configured in HCP Terraform workspace
3. **ACM Certificate** in ap-southeast-1 region for HTTPS listener
4. **Default VPC** in ap-southeast-1 with default subnets

### Terraform Requirements

- Terraform >= 1.5.7
- AWS Provider >= 6.0

### Private Registry Modules

- `app.terraform.io/ravi-panchal-org/ec2-instance/aws` (v6.1.4)
- `app.terraform.io/ravi-panchal-org/alb/aws` (v10.2.0)
- `app.terraform.io/ravi-panchal-org/security-group/aws` (v5.3.1)

## 🚀 Quick Start

### 1. Setup ACM Certificate

**Option A: Generate and Import Self-Signed Certificate (Development)**

```bash
./setup-acm-cert.sh
```

This will:
- Generate a self-signed certificate
- Import it to ACM in ap-southeast-1
- Display the Certificate ARN

**Option B: Use Existing ACM Certificate**

Get the ARN of an existing certificate:
```bash
aws acm list-certificates --region ap-southeast-1
```

### 2. Update Configuration

Edit `sandbox.auto.tfvars` and update the ACM certificate ARN:

```hcl
acm_certificate_arn = "arn:aws:acm:ap-southeast-1:ACCOUNT_ID:certificate/CERT_ID"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Validate Configuration

```bash
terraform validate
terraform fmt -check
```

### 5. Create Plan

```bash
terraform plan -out=tfplan
```

### 6. Review and Apply (⚠️ DO NOT RUN - Testing Only)

```bash
# Review the plan
terraform show tfplan

# Apply ONLY if approved (NOT for this sandbox test)
# terraform apply tfplan
```

## ⚙️ Configuration

### Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `region` | string | `"ap-southeast-1"` | AWS region (Singapore) |
| `environment` | string | `"dev"` | Environment name (dev/staging/prod) |
| `instance_type` | string | `"t3.micro"` | EC2 instance type |
| `instance_count` | number | `2` | Number of EC2 instances (minimum 2) |
| `acm_certificate_arn` | string | *required* | ACM certificate ARN for HTTPS |
| `common_tags` | map(string) | See tfvars | Common resource tags |

### Customization

Edit `sandbox.auto.tfvars` to customize:
- Instance type (cost vs performance)
- Tags for cost allocation
- Environment name

## 🚢 Deployment

### Deployment Steps

1. **Pre-Deployment Checks**
   ```bash
   terraform fmt -check
   terraform validate
   ```

2. **Create Execution Plan**
   ```bash
   terraform plan -out=tfplan
   ```

3. **Review Plan Output**
   - Verify 2 EC2 instances in different AZs
   - Confirm EBS encryption enabled
   - Check IMDSv2 enforcement
   - Validate security group rules

4. **Apply Changes** (⚠️ Production Only)
   ```bash
   terraform apply tfplan
   ```

5. **Capture Outputs**
   ```bash
   terraform output -json > outputs.json
   terraform output https_endpoint
   ```

### Deployment Time

- **Initial Deployment**: 15-22 minutes
  - EC2 instance creation: 2-3 minutes
  - Nginx installation: 3-5 minutes per instance
  - ALB provisioning: 3-5 minutes
  - Target health checks: 2-4 minutes

## ✅ Validation

### Post-Deployment Validation

1. **Verify Infrastructure**
   ```bash
   # Check EC2 instances
   terraform output ec2_instance_ids
   terraform output ec2_availability_zones
   
   # Check ALB
   terraform output alb_dns_name
   terraform output https_endpoint
   ```

2. **Test HTTPS Access**
   ```bash
   HTTPS_URL=$(terraform output -raw https_endpoint)
   curl -I $HTTPS_URL
   # Expected: HTTP/2 200
   ```

3. **Test HTTP Redirect**
   ```bash
   ALB_DNS=$(terraform output -raw alb_dns_name)
   curl -I http://$ALB_DNS
   # Expected: HTTP/1.1 301 Moved Permanently
   # Location: https://...
   ```

4. **Verify Load Distribution**
   ```bash
   for i in {1..10}; do
     curl -s $HTTPS_URL | grep "Instance ID"
   done
   # Should show both instance IDs rotating
   ```

5. **Check Target Health**
   ```bash
   # View health check status in AWS Console:
   # EC2 > Load Balancers > Target Groups > Targets tab
   # Both targets should show "healthy"
   ```

### Security Validation

```bash
# Verify EBS encryption
terraform show | grep -A 5 "root_block_device"

# Verify IMDSv2 enforcement
terraform show | grep -A 3 "metadata_options"

# Verify least-privilege IAM
terraform show | grep -A 10 "aws_iam_policy.ec2_session_manager"
```

## 🔒 Security

### Security Controls Implemented

#### ✅ Critical Priority (P0)

1. **IAM Least Privilege** *(Finding #1)*
   - Custom IAM policy with minimal Session Manager permissions
   - No generic AWS managed policies (e.g., CloudWatchAgentServerPolicy)
   - See: `data.aws_iam_policy_document.ec2_session_manager`

#### ✅ High Priority (P1)

2. **EBS Encryption** *(Finding #2)*
   - All EBS volumes encrypted with AWS managed keys
   - Configuration: `root_block_device.encrypted = true`

3. **IMDSv2 Enforcement** *(Finding #3)*
   - Instance metadata v2 required (no v1 fallback)
   - Configuration: `metadata_options.http_tokens = "required"`

4. **Excessive EC2 Egress** *(Finding #4)*
   - HTTP/HTTPS egress allowed for package updates
   - Alternative: VPC endpoints ($14/month for 3 endpoints)
   - Justification: Cost optimization for dev environment

#### ✅ Medium Priority (P2)

5. **HTTPS-Only Access**
   - Post-quantum TLS policy: `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09`
   - HTTP to HTTPS redirect (HTTP 301)

6. **Network Segmentation**
   - ALB security group: Internet → ALB (443, 80)
   - EC2 security group: ALB → EC2 (80 only)
   - No direct internet access to EC2 instances

### Security Group Rules

**ALB Security Group**
- Ingress: 0.0.0.0/0 → 443 (HTTPS)
- Ingress: 0.0.0.0/0 → 80 (HTTP redirect)
- Egress: ALB → EC2 SG:80 (HTTP to targets)

**EC2 Security Group**
- Ingress: ALB SG → 80 (HTTP from ALB only)
- Egress: 0.0.0.0/0 → 443 (HTTPS for AWS APIs)
- Egress: 0.0.0.0/0 → 80 (HTTP for package repos)

### IAM Permissions (Least Privilege)

The custom IAM policy grants ONLY:
```
ssm:UpdateInstanceInformation
ssm:ListAssociations
ssm:DescribeInstanceInformation
ssmmessages:CreateControlChannel
ssmmessages:CreateDataChannel
ssmmessages:OpenControlChannel
ssmmessages:OpenDataChannel
ec2messages:AcknowledgeMessage
ec2messages:GetEndpoint
ec2messages:GetMessages
ec2messages:SendReply
```

**Why these permissions?**
- Required for Session Manager shell access
- No S3, CloudWatch Logs, or other unnecessary permissions
- Follows AWS best practice for Session Manager

### VPC Endpoint Alternative

To eliminate internet egress (Finding #4), add VPC endpoints:
- com.amazonaws.ap-southeast-1.ssm ($7/month)
- com.amazonaws.ap-southeast-1.ssmmessages ($7/month)
- com.amazonaws.ap-southeast-1.ec2messages ($7/month)

**Total: $14/month** - Not implemented for cost optimization in dev

## 💰 Cost Estimation

### Monthly Cost Breakdown (ap-southeast-1)

| Resource | Quantity | Unit Cost | Monthly Cost |
|----------|----------|-----------|--------------|
| t3.micro instances | 2 | $0.0104/hour | ~$15.12 |
| Application Load Balancer | 1 | ~$16/month | ~$16.00 |
| EBS volumes (8 GB gp3) | 2 | $0.08/GB-month | ~$1.28 |
| Data transfer out | <1 GB | First 1GB free | $0.00 |
| **Total Estimate** | | | **~$31-34/month** |

### Cost Optimization

- ✅ Using t3.micro (cheapest burstable instance)
- ✅ Small EBS volumes (8 GB minimum)
- ✅ No VPC endpoints (saves $14/month)
- ✅ No NAT Gateway (uses default VPC)
- ✅ No CloudWatch Logs (saves $0.50/GB)

### Cost Monitoring

Enable cost tracking tags:
```bash
aws ce get-tags --time-period Start=2025-01-01,End=2025-02-01 \
  --tag-key Project --tag-key Environment
```

Track costs by:
- Tag: `Project=ec2-alb-nginx`
- Tag: `Environment=dev`
- Tag: `ManagedBy=terraform`

## 🐛 Troubleshooting

### Common Issues

#### Issue: ACM Certificate ARN Invalid

**Error**: `"certificate_arn" (...) is an invalid ARN`

**Solution**:
1. Generate certificate: `./setup-acm-cert.sh`
2. Update `sandbox.auto.tfvars` with returned ARN
3. Re-run `terraform plan`

#### Issue: Target Instances Unhealthy

**Symptoms**: ALB returns 503 errors

**Diagnosis**:
```bash
# Check target health in AWS Console
# EC2 > Target Groups > [target-group] > Targets

# Check Nginx status via Session Manager
# Connect to instance and run:
systemctl status nginx
curl http://localhost/
```

**Solutions**:
- Wait 2-4 minutes for health checks to pass
- Verify security group allows ALB → EC2:80
- Check user data execution: `cat /var/log/user-data-status.log`

#### Issue: Cannot Connect to HTTPS Endpoint

**Symptoms**: Connection timeout or SSL errors

**Diagnosis**:
```bash
# Check ALB status
terraform output alb_dns_name
nslookup [alb-dns-name]

# Verify listener configuration
terraform state show module.alb
```

**Solutions**:
- Verify ACM certificate is valid and not expired
- Check ALB security group allows 443 from 0.0.0.0/0
- Ensure ALB is in "active" state (takes 3-5 minutes)

#### Issue: Terraform Validation Fails

**Error**: Various validation errors

**Solution**:
```bash
# Re-initialize modules
rm -rf .terraform/
terraform init

# Re-validate
terraform validate
terraform fmt -recursive
```

### Debug Logs

Enable debug logging:
```bash
export TF_LOG=DEBUG
terraform plan 2>&1 | tee debug.log
```

### Getting Help

1. Check CloudWatch Logs (if configured)
2. Use Session Manager to access instances
3. Review `/var/log/user-data-status.log` on EC2 instances
4. Check ALB access logs (if enabled)

## 📚 Additional Documentation

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Amazon Linux 2023 Documentation](https://docs.aws.amazon.com/linux/al2023/)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

## 📝 License

This infrastructure code is for demonstration and development purposes.

## 👥 Maintainers

- Feature: ec2-alb-nginx-gh29
- Managed by: Terraform
- HCP Terraform Workspace: sandbox_workspace
- Organization: ravi-panchal-org

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.30.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb_security_group"></a> [alb\_security\_group](#module\_alb\_security\_group) | app.terraform.io/ravi-panchal-org/security-group/aws | 5.3.1 |
| <a name="module_ec2_instance_1"></a> [ec2\_instance\_1](#module\_ec2\_instance\_1) | app.terraform.io/ravi-panchal-org/ec2-instance/aws | 6.1.4 |
| <a name="module_ec2_instance_2"></a> [ec2\_instance\_2](#module\_ec2\_instance\_2) | app.terraform.io/ravi-panchal-org/ec2-instance/aws | 6.1.4 |
| <a name="module_ec2_security_group"></a> [ec2\_security\_group](#module\_ec2\_security\_group) | app.terraform.io/ravi-panchal-org/security-group/aws | 5.3.1 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.ec2_session_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ec2_session_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.nginx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.instance_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_lb_target_group_attachment.instance_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_ami.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_iam_policy_document.ec2_session_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ssm_parameter.al2023_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ARN of the ACM certificate for ALB HTTPS listener. Must be a valid ACM certificate in the same region. | `string` | n/a | yes |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags to apply to all resources for cost tracking, ownership, and management. | `map(string)` | <pre>{<br/>  "Environment": "development",<br/>  "ManagedBy": "terraform",<br/>  "Project": "ec2-alb-nginx"<br/>}</pre> | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name for resource tagging and naming. Allowed values: dev, staging, prod. | `string` | `"dev"` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Number of EC2 instances to deploy across availability zones. Minimum 2 required for high availability. | `number` | `2` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for Nginx web servers. Default t3.micro is cost-optimized for development ($0.0104/hour, ~$15/month for 2 instances). | `string` | `"t3.micro"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for infrastructure deployment. Must be in Singapore (ap-southeast-*) region for compliance. | `string` | `"ap-southeast-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ALB resource ARN |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | ALB DNS endpoint for HTTPS access |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group ID for Application Load Balancer |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Route53 hosted zone ID for ALB |
| <a name="output_deployment_summary"></a> [deployment\_summary](#output\_deployment\_summary) | Summary of deployed infrastructure |
| <a name="output_ec2_availability_zones"></a> [ec2\_availability\_zones](#output\_ec2\_availability\_zones) | Availability zones where instances are deployed |
| <a name="output_ec2_instance_ids"></a> [ec2\_instance\_ids](#output\_ec2\_instance\_ids) | EC2 instance IDs for Nginx servers |
| <a name="output_ec2_instance_private_ips"></a> [ec2\_instance\_private\_ips](#output\_ec2\_instance\_private\_ips) | Private IP addresses of EC2 instances |
| <a name="output_ec2_security_group_id"></a> [ec2\_security\_group\_id](#output\_ec2\_security\_group\_id) | Security group ID for EC2 instances |
| <a name="output_https_endpoint"></a> [https\_endpoint](#output\_https\_endpoint) | Full HTTPS URL for accessing the application |
| <a name="output_iam_instance_profile_arn"></a> [iam\_instance\_profile\_arn](#output\_iam\_instance\_profile\_arn) | IAM instance profile ARN for EC2 instances |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | IAM role ARN for EC2 instances |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | Target group ARN for EC2 instances |
| <a name="output_target_health_check_path"></a> [target\_health\_check\_path](#output\_target\_health\_check\_path) | Health check path configured for target group |
<!-- END_TF_DOCS -->
