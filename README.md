# EC2 ALB Nginx Development Environment

**Infrastructure as Code** project for deploying a highly available web application using AWS Application Load Balancer and EC2 instances running Nginx across multiple availability zones.

## 🚀 Quick Start

See the complete deployment guide: [specs/001-ec2-alb-nginx/quickstart.md](specs/001-ec2-alb-nginx/quickstart.md)

## 📋 Overview

This project deploys a cost-optimized development environment with the following components:

- **Application Load Balancer (ALB)**: Internet-facing load balancer with HTTPS support
- **EC2 Instances**: 2x t3.micro instances running Nginx (one per availability zone)
- **Security**: HTTPS with ACM certificate, Systems Manager Session Manager access (no SSH)
- **High Availability**: Multi-AZ deployment with automatic health checks and failover
- **Cost**: Estimated $36-48/month for 24/7 operation

## 🏗️ Architecture

```
┌────────────────────────────────────────────┐
│         VPC (Default - ap-southeast-1)     │
│  ┌──────────────────────────────────────┐ │
│  │  Application Load Balancer (Public)  │ │
│  │  ├─ HTTP Listener (80) → Redirect    │ │
│  │  └─ HTTPS Listener (443) → Forward   │ │
│  └──────────────┬───────────────────────┘ │
│                 │                          │
│         ┌───────▼──────────┐              │
│         │  Target Group    │              │
│         │  - Health Checks │              │
│         └───────┬──────────┘              │
│                 │                          │
│      ┌──────────┴──────────┐              │
│      │                     │              │
│  ┌───▼─────────┐  ┌────────▼────┐        │
│  │ EC2 (1a)    │  │ EC2 (1b)    │        │
│  │ - Nginx     │  │ - Nginx     │        │
│  │ - Public IP │  │ - Public IP │        │
│  │ - SSM Agent │  │ - SSM Agent │        │
│  └─────────────┘  └─────────────┘        │
└────────────────────────────────────────────┘
```

## 📁 Project Structure

```
.
├── main.tf              # Module instantiations (ALB, EC2, data sources)
├── variables.tf         # Input variable declarations
├── outputs.tf           # Output definitions (ALB DNS, instance IDs)
├── locals.tf            # Local values (tags, user data script)
├── providers.tf         # AWS provider configuration
├── versions.tf          # Terraform and provider version constraints
├── override.tf          # HCP Terraform backend configuration
├── sandbox.auto.tfvars  # Development environment variable values
├── README.md            # This file
└── specs/001-ec2-alb-nginx/
    ├── spec.md          # Feature specification
    ├── plan.md          # Implementation plan
    ├── tasks.md         # Task breakdown
    ├── quickstart.md    # Deployment guide
    ├── data-model.md    # Infrastructure entities
    └── contracts/       # API/interface definitions
```

## 🔧 Prerequisites

- **AWS Account** with appropriate permissions
- **Terraform** >= 1.5.7
- **AWS CLI** v2.x or later
- **OpenSSL** (for certificate generation)
- **HCP Terraform Account** (organization: `ravi-panchal-org`)

## 📝 Configuration

### Required Variables

Update `sandbox.auto.tfvars` with your values:

```hcl
region              = "ap-southeast-1"
environment         = "dev"
instance_type       = "t3.micro"
acm_certificate_arn = "arn:aws:acm:ap-southeast-1:ACCOUNT_ID:certificate/CERT_ID"
```

### HCP Terraform Workspace

Configured in `override.tf`:
- **Organization**: `ravi-panchal-org`
- **Workspace**: `sandbox_ec2_ai-iac-consumer-template`
- **Project**: `Default Project`

## 🚢 Deployment Steps

1. **Generate SSL Certificate**
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout alb-private-key.pem -out alb-certificate.pem \
     -subj "/C=SG/ST=Singapore/L=Singapore/O=Development/CN=*.elb.amazonaws.com"
   
   aws acm import-certificate \
     --certificate fileb://alb-certificate.pem \
     --private-key fileb://alb-private-key.pem \
     --region ap-southeast-1
   ```

2. **Update Configuration**
   ```bash
   # Update sandbox.auto.tfvars with your ACM certificate ARN
   vi sandbox.auto.tfvars
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   terraform validate
   ```

4. **Deploy Infrastructure**
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

5. **Access Application**
   ```bash
   ALB_DNS=$(terraform output -raw alb_dns_name)
   echo "Access via: https://${ALB_DNS}/"
   ```

## 🔍 Testing & Validation

### Test HTTPS Endpoint
```bash
curl -k https://$(terraform output -raw alb_dns_name)/
```

### Test HTTP Redirect
```bash
curl -I http://$(terraform output -raw alb_dns_name)/
# Expected: 301 redirect to HTTPS
```

### Test Multi-AZ Load Balancing
```bash
for i in {1..10}; do
  curl -k -s https://$(terraform output -raw alb_dns_name)/ | grep "Availability Zone"
done
# Expected: Mix of responses from ap-southeast-1a and ap-southeast-1b
```

### Connect via Systems Manager
```bash
# Get instance IDs
INSTANCE_A=$(terraform output -json instance_ids | jq -r '.az_a')
INSTANCE_B=$(terraform output -json instance_ids | jq -r '.az_b')

# Connect to instance
aws ssm start-session --target ${INSTANCE_A} --region ap-southeast-1
```

## 💰 Cost Estimate

**Monthly cost for 24/7 operation in ap-southeast-1:**

| Component | Quantity | Unit Cost | Monthly Cost |
|-----------|----------|-----------|--------------|
| EC2 t3.micro | 2 | $0.0104/hour | ~$15.12 |
| Application Load Balancer | 1 | $0.0252/hour | ~$18.40 |
| ALB LCU (minimal) | 0.25 | $0.008/LCU-hour | ~$1.46 |
| Data Transfer | 10 GB | $0.12/GB | ~$1.20 |
| **Total** | | | **~$36-48/month** |

**Cost Optimization:**
- Stop EC2 instances when not in use: Saves ~70% on instance costs
- Destroy entire stack after testing: Zero ongoing charges
- No NAT Gateway: Saves ~$32/month
- No CloudWatch Logs: Saves ~$5-10/month

## 🧹 Cleanup

```bash
# Destroy all infrastructure
terraform destroy -auto-approve

# Delete ACM certificate
aws acm delete-certificate --certificate-arn ${ACM_CERT_ARN} --region ap-southeast-1

# Remove local files
rm -f tfplan *.pem cert-arn.txt
```

## 📚 Documentation

- **[Specification](specs/001-ec2-alb-nginx/spec.md)**: Feature requirements and success criteria
- **[Quick Start Guide](specs/001-ec2-alb-nginx/quickstart.md)**: Detailed deployment instructions
- **[Implementation Plan](specs/001-ec2-alb-nginx/plan.md)**: Technical design and architecture
- **[Tasks](specs/001-ec2-alb-nginx/tasks.md)**: Implementation task breakdown
- **[Data Model](specs/001-ec2-alb-nginx/data-model.md)**: Infrastructure entities and relationships

## 🔐 Security Features

- ✅ HTTPS-only access with TLS 1.3 support
- ✅ Systems Manager Session Manager (no SSH keys required)
- ✅ Security groups with least-privilege access
- ✅ IAM roles with managed policies only
- ✅ Encrypted EBS volumes
- ✅ No hardcoded credentials

## 🎯 Key Features

- **High Availability**: Multi-AZ deployment with automatic failover
- **Auto-Healing**: Health checks detect failures within 60 seconds
- **Secure Access**: Session Manager for troubleshooting (no SSH)
- **Cost-Optimized**: t3.micro instances, minimal data transfer
- **Production-Ready Patterns**: Load balancing, health checks, encryption

## 📄 License

This project is part of the AI IaC Consumer Template repository.

## 🤝 Contributing

This infrastructure is managed through Terraform Cloud with automated planning and manual approval for applies.

## 📞 Support

For issues or questions:
1. Check the [Quick Start Guide](specs/001-ec2-alb-nginx/quickstart.md) troubleshooting section
2. Review the [Specification](specs/001-ec2-alb-nginx/spec.md) for requirements
3. Consult the [Implementation Plan](specs/001-ec2-alb-nginx/plan.md) for technical details

---

**Generated**: 2025-01-29  
**Terraform**: >= 1.5.7  
**AWS Provider**: >= 6.0  
**Target Region**: ap-southeast-1 (Singapore)
