# EC2 Instance with ALB and Nginx Infrastructure

This Terraform configuration deploys a development environment with EC2 instances running Nginx web servers behind an Application Load Balancer (ALB) with HTTPS support.

## Overview

- **Feature Branch**: `003-ec2-alb-nginx`
- **GitHub Issue**: [#39](https://github.com/org/repo/issues/39)
- **HCP Terraform Workspace**: `sandbox_workspace`
- **AWS Region**: `ap-southeast-1`

## Architecture

```
Internet (HTTPS:443)
    ↓
Application Load Balancer (HTTPS:443)
    ↓ [SSL/TLS Termination]
    ↓ (HTTP:80)
EC2 Instances (HTTP:80 - Nginx)
    ↓
Distributed across 2 Availability Zones
```

## Quick Start

### Prerequisites

- Terraform CLI v1.6.0+
- AWS credentials configured
- Access to HCP Terraform organization: `ravi-panchal-org`

### Deployment

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Get ALB DNS name
terraform output alb_dns_name
```

### Access Application

```bash
# Test HTTPS connectivity (expect certificate warning - self-signed)
ALB_DNS=$(terraform output -raw alb_dns_name)
curl -k https://$ALB_DNS
```

## Configuration

### Default Values

- **AWS Region**: `ap-southeast-1`
- **Project Name**: `web-demo`
- **Environment**: `development`
- **Instance Type**: `t3.micro`
- **Instances per AZ**: `1`
- **Certificate Validity**: `90 days`

### Customization

Override defaults using `terraform.tfvars`:

```hcl
instance_type             = "t2.micro"
certificate_validity_days = 180
domain_name              = "my-app.example.com"
```

## Infrastructure Components

- **2 EC2 Instances**: One per availability zone running Nginx
- **1 Application Load Balancer**: Internet-facing with HTTPS listener
- **2 Security Groups**: ALB and EC2 with proper isolation
- **1 Self-Signed Certificate**: Imported to AWS Certificate Manager
- **1 Target Group**: With health checks on `/health` endpoint

## Estimated Cost

Approximately **$40-60/month** for development environment:
- 2 × t3.micro instances: ~$17/month each
- 1 × ALB: ~$16/month
- Data transfer: ~$7/month (light usage)

## Testing

```bash
# Test load balancing (should show both instances)
for i in {1..20}; do
  curl -sk https://$(terraform output -raw alb_dns_name) | grep "Instance ID"
done | sort | uniq -c

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-southeast-1
```

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

## Documentation

For detailed deployment instructions, see:
- **Quickstart Guide**: `/specs/003-ec2-alb-nginx/quickstart.md`
- **Implementation Plan**: `/specs/003-ec2-alb-nginx/plan.md`
- **Architecture Research**: `/specs/003-ec2-alb-nginx/research.md`

## Security Considerations

⚠️ **Development Environment Only**
- Uses self-signed certificates (browser warnings expected)
- Private keys stored in Terraform state (encrypted in HCP Terraform)
- Not suitable for production workloads

✅ **Security Features**
- EC2 instances not directly accessible from internet
- Security group isolation (ALB → EC2 only)
- HTTPS-only access (no HTTP listener)

## Troubleshooting

### Instances showing unhealthy
```bash
# Check cloud-init logs on instance
sudo cat /var/log/cloud-init-output.log

# Verify Nginx is running
sudo systemctl status nginx
```

### Cannot access ALB
```bash
# Check ALB state
aws elbv2 describe-load-balancers \
  --names web-demo-development-alb \
  --query 'LoadBalancers[0].State'
```

## Support

- **GitHub Issues**: [Create an issue](https://github.com/org/repo/issues)
- **Documentation**: See `/specs/003-ec2-alb-nginx/` directory

---

**Status**: Implementation in progress  
**Last Updated**: 2025-01-21

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.30.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb"></a> [alb](#module\_alb) | app.terraform.io/ravi-panchal-org/alb/aws | ~> 10.2.0 |
| <a name="module_ec2_instances"></a> [ec2\_instances](#module\_ec2\_instances) | app.terraform.io/ravi-panchal-org/ec2-instance/aws | ~> 6.1.4 |
| <a name="module_security_group_alb"></a> [security\_group\_alb](#module\_security\_group\_alb) | app.terraform.io/ravi-panchal-org/security-group/aws | ~> 5.3.1 |
| <a name="module_security_group_ec2"></a> [security\_group\_ec2](#module\_security\_group\_ec2) | app.terraform.io/ravi-panchal-org/security-group/aws | ~> 5.3.1 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [tls_private_key.web](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.web](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_subnet.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for resource deployment | `string` | `"ap-southeast-1"` | no |
| <a name="input_certificate_validity_days"></a> [certificate\_validity\_days](#input\_certificate\_validity\_days) | Validity period for self-signed certificate in days | `number` | `90` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for TLS certificate and application access | `string` | `"web.demo.com"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (development, staging, production) | `string` | `"development"` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | Interval between health checks in seconds | `number` | `30` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | HTTP path for ALB health checks | `string` | `"/health"` | no |
| <a name="input_instance_count_per_az"></a> [instance\_count\_per\_az](#input\_instance\_count\_per\_az) | Number of EC2 instances to create per availability zone | `number` | `1` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for web servers | `string` | `"t3.micro"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project identifier for resource naming | `string` | `"web-demo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_url"></a> [access\_url](#output\_access\_url) | URL to access the application (using custom domain) |
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | ARN of the ACM certificate imported from self-signed certificate |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer |
| <a name="output_alb_direct_url"></a> [alb\_direct\_url](#output\_alb\_direct\_url) | Direct URL to access the application via ALB DNS |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer |
| <a name="output_alb_id"></a> [alb\_id](#output\_alb\_id) | ID of the Application Load Balancer |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | ID of the ALB security group |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Route 53 zone ID of the Application Load Balancer |
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | List of availability zones used for infrastructure deployment |
| <a name="output_certificate_domain"></a> [certificate\_domain](#output\_certificate\_domain) | Domain name associated with the certificate |
| <a name="output_certificate_validity_end"></a> [certificate\_validity\_end](#output\_certificate\_validity\_end) | Certificate expiration date |
| <a name="output_deployment_timestamp"></a> [deployment\_timestamp](#output\_deployment\_timestamp) | Timestamp when the infrastructure was deployed |
| <a name="output_ec2_instance_availability_zones"></a> [ec2\_instance\_availability\_zones](#output\_ec2\_instance\_availability\_zones) | Map of instance names to availability zones |
| <a name="output_ec2_instance_ids"></a> [ec2\_instance\_ids](#output\_ec2\_instance\_ids) | List of EC2 instance IDs |
| <a name="output_ec2_instance_private_ips"></a> [ec2\_instance\_private\_ips](#output\_ec2\_instance\_private\_ips) | List of EC2 instance private IP addresses |
| <a name="output_ec2_security_group_id"></a> [ec2\_security\_group\_id](#output\_ec2\_security\_group\_id) | ID of the EC2 security group |
| <a name="output_https_listener_arn"></a> [https\_listener\_arn](#output\_https\_listener\_arn) | ARN of the HTTPS listener |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | List of subnet IDs used for infrastructure deployment |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the target group |
| <a name="output_terraform_workspace"></a> [terraform\_workspace](#output\_terraform\_workspace) | Terraform workspace used for deployment |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the default VPC |
<!-- END_TF_DOCS -->
