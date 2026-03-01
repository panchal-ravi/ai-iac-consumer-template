# EC2 ALB Nginx Infrastructure

Production-ready Terraform configuration for deploying a highly available web infrastructure in AWS with EC2 instances running Nginx behind an Application Load Balancer with HTTPS termination.

## 🏗️ Architecture

```
Internet
   ↓ HTTPS (443)
┌──────────────────────────┐
│ Application Load Balancer│ ← ALB Security Group (HTTPS:443 from 0.0.0.0/0)
│ (internet-facing)        │
│ + TLS Termination        │
│ + ACM Certificate        │
└──────────┬───────────────┘
           │ HTTP (80)
           ↓
    ┌──────────────┐
    │ Target Group │
    │ Health Check │
    └──────┬───────┘
           │
    ┌──────┴───────┐
    ↓              ↓
┌─────────┐   ┌─────────┐
│ EC2 (1) │   │ EC2 (2) │ ← EC2 Security Group (HTTP:80 from ALB only)
│ Nginx   │   │ Nginx   │
│ AZ-1a   │   │ AZ-1b   │
└─────────┘   └─────────┘
```

## ✨ Features

- **High Availability**: Multi-AZ deployment with automatic failover
- **Secure by Default**: HTTPS termination, least-privilege security groups, IMDSv2 enforced
- **Private Registry Modules**: Uses organizational approved modules from `ravi-panchal-org`
- **Self-Signed TLS**: Automatic certificate generation and ACM import
- **Health Checks**: Automatic instance health monitoring with 60-second detection
- **Cost Optimized**: Under $50/month (estimated $38.67/month)
- **Production Ready**: Based on AWS Well-Architected Framework

## 📋 Prerequisites

1. **HCP Terraform Access**
   - Organization: `ravi-panchal-org`
   - Workspace: `sandbox_workspace`
   - Valid authentication token

2. **AWS Credentials**
   - Configured in HCP Terraform workspace variables:
     - `AWS_ACCESS_KEY_ID` (sensitive)
     - `AWS_SECRET_ACCESS_KEY` (sensitive)
   - Required permissions: EC2, VPC, ELB, ACM

3. **Default VPC**
   - Must exist in ap-southeast-1 region
   - Verify: `aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region ap-southeast-1`

4. **Local Tools**
   - Terraform CLI >= 1.7.0
   - AWS CLI v2
   - curl or similar HTTP client

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
cd terraform/
```

### 2. Initialize Terraform

```bash
# Login to HCP Terraform
terraform login

# Initialize (connects to remote backend)
terraform init
```

Expected output:
```
Initializing modules...
Initializing the backend...
Successfully configured the backend "remote"!
```

### 3. Review Configuration

```bash
# Validate configuration
terraform validate

# Review planned changes
terraform plan
```

### 4. Deploy Infrastructure

```bash
# Apply configuration
terraform apply

# Confirm with 'yes' when prompted
# Deployment takes approximately 5-8 minutes
```

### 5. Access Your Application

```bash
# Get the ALB endpoint
terraform output alb_endpoint

# Test the endpoint (self-signed cert warning expected)
curl -k $(terraform output -raw alb_endpoint)
```

## 📊 Outputs

| Output | Description |
|--------|-------------|
| `alb_endpoint` | HTTPS URL for accessing the application |
| `alb_dns_name` | Load balancer DNS name |
| `ec2_instance_ids` | List of EC2 instance IDs |
| `ec2_availability_zones` | AZs where instances are deployed |
| `acm_certificate_arn` | ACM certificate ARN |
| `verification_commands` | Commands to verify deployment |

View all outputs:
```bash
terraform output
```

## 🔧 Configuration

### Input Variables

Configuration is done via `sandbox.auto.tfvars` (automatically loaded):

```hcl
# AWS Configuration
region      = "ap-southeast-1"
environment = "development"

# EC2 Configuration
instance_type  = "t3.micro"
instance_count = 2

# Certificate Configuration
certificate_domain = "web.demo.com"

# Health Check Configuration
health_check_interval = 30
healthy_threshold     = 2
```

### Customization

To customize values, edit `sandbox.auto.tfvars` or pass variables:

```bash
terraform apply -var="instance_type=t3.small"
```

## 🧪 Testing and Validation

### 1. Test HTTPS Endpoint

```bash
# Test with curl (ignore self-signed cert warning)
curl -k https://<alb-dns-name>

# Expected: HTTP 200 with HTML test page
```

### 2. Verify TLS Certificate

```bash
# Check certificate details
openssl s_client -connect <alb-dns-name>:443 -servername web.demo.com

# Verify certificate domain: CN=web.demo.com
```

### 3. Check Target Health

```bash
# Get target group ARN
TG_ARN=$(terraform output -raw target_group_arn)

# Check health status
aws elbv2 describe-target-health --target-group-arn $TG_ARN --region ap-southeast-1

# Expected: Both targets show "healthy" state
```

### 4. Test High Availability

```bash
# Stop Nginx on one instance to simulate failure
INSTANCE_ID=$(terraform output -json ec2_instance_ids | jq -r '.[0]')
aws ec2 send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo systemctl stop nginx"]' \
  --region ap-southeast-1

# Wait 60 seconds for health check to detect failure
sleep 60

# Verify ALB continues serving traffic
curl -k https://<alb-dns-name>

# Expected: HTTP 200 (from healthy instance)
```

### 5. Verify Security

```bash
# Test direct EC2 access (should be blocked)
EC2_IP=$(terraform output -json ec2_instance_public_ips | jq -r '.[0]')
curl http://$EC2_IP --max-time 10

# Expected: Connection timeout or connection refused
```

## 📁 File Structure

```
terraform/
├── main.tf                # Main infrastructure configuration
├── variables.tf           # Input variable definitions
├── outputs.tf             # Output value definitions
├── providers.tf           # AWS and TLS provider configuration
├── versions.tf            # Terraform and provider version constraints
├── sandbox.auto.tfvars    # Environment-specific variable values
├── user-data.sh           # EC2 user data script (Nginx installation)
└── README.md              # This file
```

## 🔒 Security Features

- **Network Security**: Least-privilege security groups with source SG references
- **TLS Encryption**: HTTPS termination at ALB with TLS 1.3 support
- **IMDSv2**: Instance metadata v2 enforced on all EC2 instances
- **EBS Encryption**: Root volumes encrypted at rest
- **No Public SSH**: Instances have no SSH keys (use SSM Session Manager if needed)
- **Credential Management**: No hardcoded credentials (HCP Terraform workspace variables)

## 💰 Cost Estimation

| Component | Unit Cost | Quantity | Monthly Cost |
|-----------|-----------|----------|--------------|
| EC2 t3.micro | $7.30 | 2 | $14.60 |
| EBS GP3 8GB | $0.80 | 2 | $1.60 |
| ALB | $22.27 | 1 | $22.27 |
| ALB LCU-hours | $0.008 | ~10 | $0.08 |
| Data transfer | $0.12/GB | ~1 GB | $0.12 |
| **TOTAL** | | | **$38.67** |

**Budget Compliance**: ✅ $38.67 < $50 (23% under budget)

## 🛠️ Troubleshooting

### Issue: terraform init fails with authentication error

**Solution**: Login to HCP Terraform
```bash
terraform login
```

### Issue: Default VPC not found

**Solution**: Create default VPC
```bash
aws ec2 create-default-vpc --region ap-southeast-1
```

### Issue: Target health checks failing

**Possible causes**:
1. Nginx not running: Check user data execution logs
   ```bash
   aws ec2 get-console-output --instance-id <instance-id> --region ap-southeast-1
   ```

2. Security group misconfiguration: Verify rules
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id> --region ap-southeast-1
   ```

3. Network connectivity: Check subnet routing tables

### Issue: Browser shows certificate warning

**Expected behavior**: Self-signed certificates always show warnings. For production:
- Use a valid domain with DNS validation
- Obtain certificate from a trusted CA (Let's Encrypt, commercial CA)

## 🧹 Cleanup

To destroy all resources:

```bash
# Preview resources to be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Confirm with 'yes' when prompted
```

⚠️ **Warning**: This will permanently delete all resources. Ensure you have backups of any important data.

## 📚 Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)

## 🤝 Support

For issues or questions:
1. Check [troubleshooting section](#-troubleshooting)
2. Review [HCP Terraform logs](https://app.terraform.io/app/ravi-panchal-org/workspaces/sandbox_workspace/runs)
3. Contact the DevOps team

## 📝 License

Managed by: **devops-team**  
Project: **ec2-alb-nginx**  
Environment: **development**

---

**Last Updated**: 2025-02-01  
**Terraform Version**: >= 1.7.0  
**AWS Provider Version**: ~> 5.0

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.30.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ec2_instance"></a> [ec2\_instance](#module\_ec2\_instance) | app.terraform.io/ravi-panchal-org/ec2-instance/aws | 6.1.4 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.self_signed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_lb.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_egress_http_to_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_ingress_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ec2_egress_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ec2_egress_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ec2_ingress_http_from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [tls_private_key.main](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.main](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_ssm_parameter.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones for deployment | `list(string)` | <pre>[<br/>  "ap-southeast-1a",<br/>  "ap-southeast-1b"<br/>]</pre> | no |
| <a name="input_certificate_domain"></a> [certificate\_domain](#input\_certificate\_domain) | Domain name for the self-signed TLS certificate | `string` | `"web.demo.com"` | no |
| <a name="input_certificate_validity_hours"></a> [certificate\_validity\_hours](#input\_certificate\_validity\_hours) | Validity period for self-signed certificate in hours | `number` | `43800` | no |
| <a name="input_cost_center"></a> [cost\_center](#input\_cost\_center) | Cost center for billing allocation | `string` | `""` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name for resource tagging | `string` | `"development"` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | Target group health check interval in seconds | `number` | `30` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Target group health check path | `string` | `"/"` | no |
| <a name="input_health_check_timeout"></a> [health\_check\_timeout](#input\_health\_check\_timeout) | Target group health check timeout in seconds | `number` | `5` | no |
| <a name="input_healthy_threshold"></a> [healthy\_threshold](#input\_healthy\_threshold) | Number of consecutive successful health checks before marking target as healthy | `number` | `2` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Number of EC2 instances to create (must be exactly 2 for this design) | `number` | `2` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for web servers | `string` | `"t3.micro"` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner or team responsible for the infrastructure | `string` | `"devops-team"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name for resource naming and tagging | `string` | `"ec2-alb-nginx"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for infrastructure deployment | `string` | `"ap-southeast-1"` | no |
| <a name="input_unhealthy_threshold"></a> [unhealthy\_threshold](#input\_unhealthy\_threshold) | Number of consecutive failed health checks before marking target as unhealthy | `number` | `2` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | ARN of the imported ACM certificate |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer |
| <a name="output_alb_endpoint"></a> [alb\_endpoint](#output\_alb\_endpoint) | HTTPS URL for accessing the web application through the load balancer |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group ID for the Application Load Balancer |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Zone ID of the Application Load Balancer |
| <a name="output_certificate_domain"></a> [certificate\_domain](#output\_certificate\_domain) | Domain name on the certificate |
| <a name="output_certificate_expiry"></a> [certificate\_expiry](#output\_certificate\_expiry) | Certificate expiration date |
| <a name="output_certificate_subject"></a> [certificate\_subject](#output\_certificate\_subject) | Certificate subject distinguished name |
| <a name="output_ec2_availability_zones"></a> [ec2\_availability\_zones](#output\_ec2\_availability\_zones) | Availability zones where EC2 instances are deployed |
| <a name="output_ec2_instance_ids"></a> [ec2\_instance\_ids](#output\_ec2\_instance\_ids) | List of EC2 instance IDs |
| <a name="output_ec2_instance_private_ips"></a> [ec2\_instance\_private\_ips](#output\_ec2\_instance\_private\_ips) | List of EC2 instance private IP addresses |
| <a name="output_ec2_instance_public_ips"></a> [ec2\_instance\_public\_ips](#output\_ec2\_instance\_public\_ips) | List of EC2 instance public IP addresses (if assigned) |
| <a name="output_ec2_security_group_id"></a> [ec2\_security\_group\_id](#output\_ec2\_security\_group\_id) | Security group ID for EC2 instances |
| <a name="output_health_check_configuration"></a> [health\_check\_configuration](#output\_health\_check\_configuration) | Target group health check configuration |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | List of subnet IDs used for deployment |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the target group |
| <a name="output_target_group_name"></a> [target\_group\_name](#output\_target\_group\_name) | Name of the target group |
| <a name="output_target_group_targets"></a> [target\_group\_targets](#output\_target\_group\_targets) | List of registered target instance IDs |
| <a name="output_verification_commands"></a> [verification\_commands](#output\_verification\_commands) | Commands to verify deployment |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC used for deployment |
<!-- END_TF_DOCS -->
