# Public EC2 Instance with Password Authentication

**Feature**: 001-public-ec2-password-auth  
**Status**: ✅ Implementation Complete - Ready for Sandbox Testing  
**Environment**: Development/Sandbox  
**Region**: ap-southeast-1 (Singapore)

## ⚠️ Security Warning

**THIS IS A DEVELOPMENT-ONLY CONFIGURATION**

This infrastructure uses password authentication for SSH access, which violates AWS security best practices.

**Security Risks**:
- Password authentication is less secure than SSH key-based authentication
- SSH access allowed from 0.0.0.0/0 (any IP address)
- No MFA or additional security layers

**DO NOT USE IN PRODUCTION**

---

## Overview

This Terraform configuration provisions a public-facing EC2 instance in AWS with SSH password authentication enabled.

**Infrastructure Components**:
- **EC2 Instance**: t3.micro running Ubuntu 22.04 LTS
- **Networking**: VPC with public subnet and Elastic IP
- **Security**: Security group allowing SSH (port 22)
- **Authentication**: Password-based SSH for user `devuser`
- **Monitoring**: CloudWatch logging for SSH events
- **IAM**: Instance profile with CloudWatch permissions

---

## Prerequisites

1. **HCP Terraform**
   - Organization: `ravi-panchal-org`
   - Workspace: `sandbox_public_ec2_dev`

2. **AWS Account**
   - Credentials configured in workspace
   - Permissions: EC2, VPC, IAM, CloudWatch

3. **Terraform** >= 1.5.0

---

## Quick Start

```bash
# Initialize
terraform init

# Validate
terraform validate

# Plan (sandbox testing - DO NOT apply yet)
terraform plan -out=plan.tfplan

# Get outputs after apply
terraform output instance_public_ip
terraform output ssh_command
terraform output -json instance_password | jq -r '.[]'
```

---

## Connecting

```bash
# Get credentials
PUBLIC_IP=$(terraform output -raw instance_public_ip)
PASSWORD=$(terraform output -json instance_password | jq -r '.[]')

# Connect
ssh devuser@$PUBLIC_IP
# Enter password when prompted
```

---

## Cost Estimation

**~$8-10/month**
- EC2 t3.micro: ~$7.50
- EBS GP3 8GB: ~$0.80
- CloudWatch Logs: ~$0.50

---

## CloudWatch Logs

- **Log Group**: `/aws/ec2/ssh-auth`
- **Stream**: `{instance_id}`
- **Retention**: 7 days

```bash
# View logs
aws logs tail /aws/ec2/ssh-auth --follow
```

---

## Cleanup

```bash
terraform destroy
```

---

**Last Updated**: 2025-01-21  
**Specification**: `/specs/001-public-ec2-password-auth/`

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.28.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ec2_instance"></a> [ec2\_instance](#module\_ec2\_instance) | app.terraform.io/ravi-panchal-org/ec2-instance/aws | ~> 6.1.4 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | app.terraform.io/ravi-panchal-org/vpc/aws | ~> 6.5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.ssh_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eip.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.ec2_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ec2_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [random_password.instance_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_ami.ubuntu_22_04](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region where resources will be created | `string` | `"ap-southeast-1"` | no |
| <a name="input_cloudwatch_log_retention_days"></a> [cloudwatch\_log\_retention\_days](#input\_cloudwatch\_log\_retention\_days) | Number of days to retain CloudWatch logs | `number` | `7` | no |
| <a name="input_enable_http"></a> [enable\_http](#input\_enable\_http) | Enable HTTP access (port 80) | `bool` | `false` | no |
| <a name="input_enable_https"></a> [enable\_https](#input\_enable\_https) | Enable HTTPS access (port 443) | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, prod) | `string` | `"dev"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type | `string` | `"t3.micro"` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Size of the root EBS volume in GB | `number` | `8` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zone"></a> [availability\_zone](#output\_availability\_zone) | Availability zone where instance is running |
| <a name="output_cloudwatch_log_group"></a> [cloudwatch\_log\_group](#output\_cloudwatch\_log\_group) | CloudWatch log group name for SSH logs |
| <a name="output_cloudwatch_log_stream"></a> [cloudwatch\_log\_stream](#output\_cloudwatch\_log\_stream) | CloudWatch log stream pattern |
| <a name="output_connection_instructions"></a> [connection\_instructions](#output\_connection\_instructions) | Instructions for connecting to the instance |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the EC2 instance |
| <a name="output_instance_password"></a> [instance\_password](#output\_instance\_password) | Generated password for SSH authentication (sensitive) |
| <a name="output_instance_private_ip"></a> [instance\_private\_ip](#output\_instance\_private\_ip) | Private IP address of the instance |
| <a name="output_instance_public_ip"></a> [instance\_public\_ip](#output\_instance\_public\_ip) | Elastic IP address of the instance |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | SSH command to connect (requires password from workspace) |
| <a name="output_ssh_username"></a> [ssh\_username](#output\_ssh\_username) | SSH username for connecting |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | ID of the subnet |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
<!-- END_TF_DOCS -->
