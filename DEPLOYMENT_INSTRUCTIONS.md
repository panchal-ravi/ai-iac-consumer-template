# Deployment Instructions - EC2 ALB Nginx Infrastructure

## ✅ Phase 1 & 2: Setup and Foundational - COMPLETE

All Terraform configuration files have been created and validated successfully:

- ✅ **providers.tf**: AWS provider configured for ap-southeast-1
- ✅ **versions.tf**: Terraform >= 1.5.7, AWS provider >= 6.0
- ✅ **main.tf**: ALB and EC2 modules configured with data sources
- ✅ **variables.tf**: All input variables defined with validation
- ✅ **outputs.tf**: Output definitions for ALB DNS, instance IDs, etc.
- ✅ **locals.tf**: Common tags and user data script
- ✅ **override.tf**: HCP Terraform backend configured
- ✅ **sandbox.auto.tfvars**: Development environment values
- ✅ **README.md**: Project documentation

### Terraform Validation Status

```bash
$ terraform init
✅ HCP Terraform has been successfully initialized!
✅ Modules downloaded: ALB v10.2.0, EC2 v6.1.4
✅ AWS Provider v6.30.0 installed

$ terraform validate
✅ Success! The configuration is valid.
```

### HCP Terraform Workspace

- ✅ **Organization**: ravi-panchal-org
- ✅ **Workspace**: sandbox_ec2_ai-iac-consumer-template
- ✅ **Project**: Default Project
- ✅ **Auto-apply**: Disabled (manual approval required)
- ✅ **Execution mode**: Remote

---

## 🚨 NEXT STEPS: Deploy Infrastructure

### Step 1: Generate and Import ACM Certificate

Since AWS CLI is not available in the current environment, you need to generate and import the ACM certificate manually:

```bash
# 1. Generate self-signed certificate locally
mkdir -p ~/ec2-alb-nginx-certs && cd ~/ec2-alb-nginx-certs

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout alb-private-key.pem \
  -out alb-certificate.pem \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=Development/CN=*.elb.amazonaws.com"

# 2. Import certificate to ACM in ap-southeast-1 region
ACM_CERT_ARN=$(aws acm import-certificate \
  --certificate fileb://alb-certificate.pem \
  --private-key fileb://alb-private-key.pem \
  --region ap-southeast-1 \
  --tags Key=Environment,Value=development Key=Project,Value=ec2-alb-nginx-demo \
  --query 'CertificateArn' \
  --output text)

echo "Certificate ARN: ${ACM_CERT_ARN}"

# 3. Save the certificate ARN
echo "${ACM_CERT_ARN}" > cert-arn.txt
```

### Step 2: Update Configuration with Certificate ARN

```bash
# Update sandbox.auto.tfvars with the actual certificate ARN
sed -i "s|REPLACE_WITH_YOUR_ACM_CERTIFICATE_ARN|${ACM_CERT_ARN}|g" sandbox.auto.tfvars

# Verify the update
grep acm_certificate_arn sandbox.auto.tfvars
```

### Step 3: Set Terraform Cloud Variables (Alternative Method)

If you prefer to use HCP Terraform workspace variables instead of updating the .tfvars file:

1. Go to: https://app.terraform.io/app/ravi-panchal-org/workspaces/sandbox_ec2_ai-iac-consumer-template/variables
2. Add workspace variable:
   - **Key**: `acm_certificate_arn`
   - **Value**: Your ACM certificate ARN
   - **Category**: Terraform variable
   - **Sensitive**: No (it's not sensitive, just an ARN)

### Step 4: Run Terraform Plan

```bash
cd /workspace

# Generate execution plan
terraform plan -out=tfplan

# Review the plan output:
# Expected resources to be created:
#   - 2 EC2 instances (ap-southeast-1a and ap-southeast-1b)
#   - 1 Application Load Balancer (internet-facing)
#   - 2 Security Groups (ALB and EC2)
#   - 2 IAM Roles (for Systems Manager access)
#   - 1 Target Group
#   - 2 Listeners (HTTP redirect and HTTPS forward)
#   - 2 Target Group Attachments
#   - Data sources for VPC and subnets
#
# Total: Approximately 15-20 resources
```

### Step 5: Apply the Configuration

```bash
# Apply the planned changes
terraform apply tfplan

# Deployment takes approximately 3-5 minutes:
#   1. Security groups created
#   2. IAM roles and instance profiles created
#   3. ALB provisioned (2-3 minutes)
#   4. EC2 instances launched (1-2 minutes)
#   5. User data script installs Nginx (~30-60 seconds)
#   6. Health checks start (~60 seconds)
```

### Step 6: Retrieve Outputs and Validate

```bash
# Get ALB DNS name
terraform output -raw alb_dns_name

# Get instance IDs
terraform output -json instance_ids

# Test HTTPS endpoint (ignore certificate warning for self-signed cert)
ALB_DNS=$(terraform output -raw alb_dns_name)
curl -k https://${ALB_DNS}/

# Test HTTP redirect
curl -I http://${ALB_DNS}/
# Expected: HTTP/1.1 301 Moved Permanently

# Test multi-AZ distribution
for i in {1..10}; do
  curl -k -s https://${ALB_DNS}/ | grep "Availability Zone"
done
# Expected: Mix of ap-southeast-1a and ap-southeast-1b
```

---

## 📊 Expected Monthly Cost

**Estimated cost for 24/7 operation in ap-southeast-1:**

| Component | Monthly Cost |
|-----------|--------------|
| 2x t3.micro EC2 | ~$15.12 |
| Application Load Balancer | ~$18.40 |
| ALB LCU (minimal) | ~$1.46 |
| Data Transfer (minimal) | ~$1.20 |
| **Total** | **~$36-48/month** ✅ |

**Cost Optimization:**
- Stop instances when not in use: Saves ~70% on EC2 costs
- Destroy infrastructure after testing: Zero ongoing charges
- No NAT Gateway = $32/month saved
- No CloudWatch Logs = $5-10/month saved

---

## 🧪 Testing and Validation

See [specs/001-ec2-alb-nginx/quickstart.md](specs/001-ec2-alb-nginx/quickstart.md) for comprehensive testing procedures including:

- ✅ HTTPS endpoint access
- ✅ HTTP to HTTPS redirect
- ✅ Multi-AZ load balancing
- ✅ Health check behavior
- ✅ Systems Manager Session Manager access
- ✅ Security validation (no SSH)

---

## 🔧 Troubleshooting

### Issue: Certificate Import Failed

**Solution**: Ensure OpenSSL command syntax is correct and certificate files have proper permissions.

### Issue: Default VPC Not Found

**Solution**: Check if default VPC exists in ap-southeast-1:
```bash
aws ec2 describe-vpcs --region ap-southeast-1 --filters "Name=is-default,Values=true"
```

### Issue: Terraform Plan Fails with Variable Error

**Solution**: Ensure `acm_certificate_arn` is set either in:
1. `sandbox.auto.tfvars` file, OR
2. HCP Terraform workspace variables

---

## 📚 Additional Documentation

- **[Quick Start Guide](specs/001-ec2-alb-nginx/quickstart.md)**: Detailed deployment steps
- **[Specification](specs/001-ec2-alb-nginx/spec.md)**: Feature requirements
- **[Implementation Plan](specs/001-ec2-alb-nginx/plan.md)**: Technical design
- **[Tasks](specs/001-ec2-alb-nginx/tasks.md)**: Implementation task breakdown

---

## 🎯 Implementation Status

### ✅ Completed

- [X] Phase 1: Setup (T001-T006)
  - Certificate generation documented
  - AWS prerequisites documented
  - Private registry modules validated
  - Terraform project structure created
  - HCP Terraform backend configured

- [X] Phase 2: Foundational (T007-T016)
  - AWS provider configured
  - Version constraints defined
  - Data sources created (VPC, subnets)
  - Local values defined (tags, user data)
  - Variables and outputs defined
  - Configuration validated

- [X] Phase 3: User Story 1 - Configuration (T017-T028)
  - ALB module configured with listeners and target groups
  - EC2 modules configured for both AZs
  - Target group attachments configured
  - Security groups configured
  - IAM roles configured

### ⏳ Pending (Requires Manual Steps)

- [ ] **T001 (Manual)**: Import ACM certificate using AWS CLI
- [ ] **T002 (Manual)**: Verify default VPC exists
- [ ] **T029**: Run terraform plan
- [ ] **T030**: Apply terraform configuration (requires user approval)
- [ ] **T031-T035**: Deployment validation and testing

---

**Generated**: 2025-01-29  
**Status**: Ready for deployment  
**Next Action**: Import ACM certificate and update configuration
