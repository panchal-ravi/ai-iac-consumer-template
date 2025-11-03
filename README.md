# Web Application Infrastructure with High Availability

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Provider%205.x-FF9900?logo=amazon-aws)](https://aws.amazon.com/)

Highly available web application infrastructure on AWS using Terraform and HCP Terraform.

## Overview

This Terraform configuration deploys a production-ready, highly available web application infrastructure on AWS with the following features:

- **High Availability**: Multi-AZ deployment across 2 Availability Zones
- **Auto-Scaling**: Dynamic scaling based on CPU utilization (2-6 instances)
- **Load Balancing**: Application Load Balancer with HTTPS termination
- **Security**: SSL/TLS encryption, security groups following least-privilege principles
- **Monitoring**: CloudWatch metrics and ALB health checks
- **Cost-Optimized**: t3.micro instances with intelligent auto-scaling

## Architecture

```
Internet → Route53 → ALB (HTTPS) → EC2 Instances (2 AZs) → S3 (Static Content)
```

## Features

### User Story 1: Access Web Application (MVP)
✅ Application Load Balancer with HTTPS
✅ Automatic HTTP to HTTPS redirect
✅ SSL/TLS certificate via ACM

### User Story 2: Continuous Availability
✅ Multi-AZ deployment (2 AZs)
✅ Auto failover and health checks
✅ 99.9% uptime target

### User Story 3: Scalable Performance
✅ Auto-scaling (2-6 instances)
✅ Target tracking (50% CPU)
✅ Handles 200% traffic spikes

## Prerequisites

- **HCP Terraform**: Organization `hashi-demos-apj`
- **AWS Account**: With appropriate permissions
- **Domain Name**: For SSL certificate
- **Terraform**: >= 1.0

## Quick Start

### 1. Configure Workspace Variables

Set these in HCP Terraform workspace:

| Variable | Value | Description |
|----------|-------|-------------|
| `environment` | `sandbox` | Deployment environment |
| `region` | `us-east-1` | AWS region |
| `domain_name` | `web.simon-lynch.sbx.hashidemos.io` | Application domain |

### 2. Deploy

```bash
git push origin 001-ec2-alb-webapp
```

### 3. Validate

```bash
terraform output alb_dns_name
curl -I https://<alb-dns-name>
```

## Module Dependencies

| Module | Version | Source |
|--------|---------|--------|
| VPC | ~> 6.5.0 | `app.terraform.io/hashi-demos-apj/vpc/aws` |
| ALB | ~> 9.0 | `terraform-aws-modules/alb/aws` |
| ASG | ~> 7.0 | `terraform-aws-modules/autoscaling/aws` |

## Cost Estimate

~$100-120/month (2x t3.micro, ALB, 2x NAT Gateway)

## Documentation

- [Quickstart Guide](specs/001-ec2-alb-webapp/quickstart.md)
- [Architecture Plan](specs/001-ec2-alb-webapp/plan.md)
- [Implementation Tasks](specs/001-ec2-alb-webapp/tasks.md)

---

🤖 **Generated with** [Claude Code](https://claude.com/claude-code)

**Co-Authored-By**: Claude <noreply@anthropic.com>
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb"></a> [alb](#module\_alb) | terraform-aws-modules/alb/aws | ~> 9.0 |
| <a name="module_asg"></a> [asg](#module\_asg) | terraform-aws-modules/autoscaling/aws | ~> 7.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | app.terraform.io/hashi-demos-apj/vpc/aws | ~> 6.5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_iam_instance_profile.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.s3_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.static_content](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.static_content](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.static_content](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.static_content](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.static_content](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.static_content](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [random_id.bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_ssm_parameter.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_ssm_parameter"></a> [ami\_ssm\_parameter](#input\_ami\_ssm\_parameter) | SSM parameter path for AMI ID (Amazon Linux 2023) | `string` | `"/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"` | no |
| <a name="input_asg_desired_capacity"></a> [asg\_desired\_capacity](#input\_asg\_desired\_capacity) | Desired number of instances in Auto Scaling Group | `number` | `2` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | Maximum number of instances in Auto Scaling Group | `number` | `6` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | Minimum number of instances in Auto Scaling Group | `number` | `2` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones for subnet distribution | `list(string)` | <pre>[<br/>  "us-east-1a",<br/>  "us-east-1b"<br/>]</pre> | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_cpu_target_value"></a> [cpu\_target\_value](#input\_cpu\_target\_value) | Target CPU utilization percentage for auto-scaling policy | `number` | `50` | no |
| <a name="input_deregistration_delay"></a> [deregistration\_delay](#input\_deregistration\_delay) | Time (seconds) for connection draining before deregistering target | `number` | `30` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Primary domain name for the web application (ACM certificate) | `string` | n/a | yes |
| <a name="input_enable_s3_versioning"></a> [enable\_s3\_versioning](#input\_enable\_s3\_versioning) | Enable versioning for S3 static content bucket | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, prod, sandbox) | `string` | n/a | yes |
| <a name="input_health_check_healthy_threshold"></a> [health\_check\_healthy\_threshold](#input\_health\_check\_healthy\_threshold) | Number of consecutive successful health checks before marking target healthy | `number` | `2` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | Health check interval in seconds | `number` | `30` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Health check path for ALB target group | `string` | `"/"` | no |
| <a name="input_health_check_timeout"></a> [health\_check\_timeout](#input\_health\_check\_timeout) | Health check timeout in seconds | `number` | `5` | no |
| <a name="input_health_check_unhealthy_threshold"></a> [health\_check\_unhealthy\_threshold](#input\_health\_check\_unhealthy\_threshold) | Number of consecutive failed health checks before marking target unhealthy | `number` | `2` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for web application servers | `string` | `"t3.micro"` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | List of CIDR blocks for private subnets (EC2 instance placement) | `list(string)` | <pre>[<br/>  "10.0.11.0/24",<br/>  "10.0.12.0/24"<br/>]</pre> | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | List of CIDR blocks for public subnets (ALB placement) | `list(string)` | <pre>[<br/>  "10.0.1.0/24",<br/>  "10.0.2.0/24"<br/>]</pre> | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for infrastructure deployment | `string` | `"us-east-1"` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 hosted zone ID for DNS validation and A record creation | `string` | `""` | no |
| <a name="input_s3_bucket_prefix"></a> [s3\_bucket\_prefix](#input\_s3\_bucket\_prefix) | Prefix for S3 bucket name (random suffix added for global uniqueness) | `string` | `"webapp-static-content"` | no |
| <a name="input_scale_in_cooldown"></a> [scale\_in\_cooldown](#input\_scale\_in\_cooldown) | Cooldown period (seconds) after scale-in activity | `number` | `300` | no |
| <a name="input_scale_out_cooldown"></a> [scale\_out\_cooldown](#input\_scale\_out\_cooldown) | Cooldown period (seconds) after scale-out activity | `number` | `300` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | The ARN of the ACM certificate |
| <a name="output_acm_certificate_domain_validation_options"></a> [acm\_certificate\_domain\_validation\_options](#output\_acm\_certificate\_domain\_validation\_options) | Domain validation options for manual DNS configuration (if Route53 not used) |
| <a name="output_acm_certificate_status"></a> [acm\_certificate\_status](#output\_acm\_certificate\_status) | The status of the ACM certificate |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | The ARN of the Application Load Balancer |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | The DNS name of the Application Load Balancer |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | The Route53 zone ID of the Application Load Balancer |
| <a name="output_application_url_http"></a> [application\_url\_http](#output\_application\_url\_http) | HTTP URL to access the application (will redirect to HTTPS) |
| <a name="output_application_url_https"></a> [application\_url\_https](#output\_application\_url\_https) | HTTPS URL to access the application |
| <a name="output_autoscaling_group_arn"></a> [autoscaling\_group\_arn](#output\_autoscaling\_group\_arn) | The ARN of the Auto Scaling Group |
| <a name="output_autoscaling_group_id"></a> [autoscaling\_group\_id](#output\_autoscaling\_group\_id) | The ID of the Auto Scaling Group |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | The name of the Auto Scaling Group |
| <a name="output_custom_domain_url"></a> [custom\_domain\_url](#output\_custom\_domain\_url) | Custom domain URL (if configured) |
| <a name="output_iam_instance_profile_arn"></a> [iam\_instance\_profile\_arn](#output\_iam\_instance\_profile\_arn) | The ARN of the IAM instance profile |
| <a name="output_iam_instance_profile_name"></a> [iam\_instance\_profile\_name](#output\_iam\_instance\_profile\_name) | The name of the IAM instance profile |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The ARN of the IAM role for EC2 instances |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role for EC2 instances |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | The ARN of the KMS key for S3 encryption |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | The ID of the KMS key for S3 encryption |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | The ID of the launch template |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | List of NAT Gateway IDs |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | List of IDs of private subnets |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | List of IDs of public subnets |
| <a name="output_quick_reference"></a> [quick\_reference](#output\_quick\_reference) | Quick reference guide for deployment validation |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | The ARN of the S3 bucket for static content |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | The ID (name) of the S3 bucket for static content |
| <a name="output_s3_logs_bucket_id"></a> [s3\_logs\_bucket\_id](#output\_s3\_logs\_bucket\_id) | The ID (name) of the S3 bucket for access logs |
| <a name="output_target_group_arns"></a> [target\_group\_arns](#output\_target\_group\_arns) | ARNs of the target groups |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | The CIDR block of the VPC |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
