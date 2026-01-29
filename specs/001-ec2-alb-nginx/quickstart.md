# Quick Start Guide: EC2 ALB Nginx Deployment

**Feature**: EC2 ALB Nginx Development Environment  
**Branch**: `001-ec2-alb-nginx`  
**Estimated Time**: 20-30 minutes  
**Last Updated**: 2025-01-29

---

## Prerequisites

### Required Tools

- **AWS CLI** v2.x or later
- **Terraform** >= 1.5.7
- **OpenSSL** (for certificate generation)
- **jq** (for JSON parsing, optional but recommended)
- **git** (for version control)

### AWS Requirements

- AWS account with permissions to create:
  - EC2 instances
  - Application Load Balancers
  - Security groups
  - IAM roles and instance profiles
  - ACM certificates (import)
- Default VPC in `ap-southeast-1` region with at least 2 subnets
- HCP Terraform organization: `ravi-panchal-org`

### Verify Prerequisites

```bash
# Check AWS CLI
aws --version
# Expected: aws-cli/2.x.x or later

# Check Terraform
terraform version
# Expected: Terraform v1.5.7 or later

# Check OpenSSL
openssl version
# Expected: OpenSSL 1.1.1 or later

# Verify AWS credentials
aws sts get-caller-identity
# Should return your AWS account information

# Verify default VPC exists
aws ec2 describe-vpcs --region ap-southeast-1 \
  --filters "Name=is-default,Values=true" \
  --query 'Vpcs[0].VpcId' --output text
# Should return: vpc-xxxxxxxxxxxxxxxxx
```

---

## Step 1: Generate SSL/TLS Certificate

### 1.1 Generate Self-Signed Certificate

```bash
# Create temporary directory for certificates
mkdir -p ~/ec2-alb-nginx-certs
cd ~/ec2-alb-nginx-certs

# Generate self-signed certificate (365 days validity)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout alb-private-key.pem \
  -out alb-certificate.pem \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=Development/CN=*.elb.amazonaws.com"

# Verify certificate was created
ls -lh alb-*.pem
```

**Expected Output**:
```
-rw-r--r-- 1 user user 1.7K Jan 29 10:00 alb-certificate.pem
-rw-r--r-- 1 user user 1.7K Jan 29 10:00 alb-private-key.pem
```

### 1.2 Import Certificate to AWS ACM

```bash
# Import certificate to ACM in ap-southeast-1 region
ACM_CERT_ARN=$(aws acm import-certificate \
  --certificate fileb://alb-certificate.pem \
  --private-key fileb://alb-private-key.pem \
  --region ap-southeast-1 \
  --tags Key=Environment,Value=development Key=Project,Value=ec2-alb-nginx-demo \
  --query 'CertificateArn' \
  --output text)

echo "Certificate ARN: ${ACM_CERT_ARN}"

# Save certificate ARN for later use
echo ${ACM_CERT_ARN} > cert-arn.txt
```

**Expected Output**:
```
Certificate ARN: arn:aws:acm:ap-southeast-1:123456789012:certificate/abcd1234-5678-90ef-ghij-klmnopqrstuv
```

### 1.3 Verify Certificate Import

```bash
# List certificates
aws acm list-certificates --region ap-southeast-1 \
  --query 'CertificateSummaryList[?DomainName==`*.elb.amazonaws.com`]' \
  --output table

# View certificate details
aws acm describe-certificate \
  --certificate-arn ${ACM_CERT_ARN} \
  --region ap-southeast-1
```

---

## Step 2: Clone Repository and Switch to Feature Branch

```bash
# Clone the repository
git clone https://github.com/panchal-ravi/ai-iac-consumer-template.git
cd ai-iac-consumer-template

# Checkout the feature branch
git checkout 001-ec2-alb-nginx

# Verify branch
git branch --show-current
# Expected: 001-ec2-alb-nginx
```

---

## Step 3: Configure Terraform Variables

### 3.1 Create Variable Values File

```bash
# Create sandbox.auto.tfvars file
cat > sandbox.auto.tfvars <<'EOF'
# Environment Configuration
environment = "dev"

# Region Configuration
region = "ap-southeast-1"

# EC2 Instance Configuration
instance_type = "t3.micro"

# ACM Certificate ARN (replace with your certificate ARN)
acm_certificate_arn = "REPLACE_WITH_YOUR_CERT_ARN"

# Resource Tagging
common_tags = {
  Environment  = "development"
  Project      = "ec2-alb-nginx-demo"
  ManagedBy    = "terraform"
  Terraform    = "true"
  CostCenter   = "development"
  Purpose      = "testing"
}
EOF

# Replace placeholder with actual certificate ARN
sed -i "s|REPLACE_WITH_YOUR_CERT_ARN|${ACM_CERT_ARN}|g" sandbox.auto.tfvars

# Verify configuration
cat sandbox.auto.tfvars
```

### 3.2 Review Main Configuration (Optional)

```bash
# View main Terraform configuration
cat main.tf

# View variable definitions
cat variables.tf

# View outputs
cat outputs.tf
```

---

## Step 4: Initialize Terraform

```bash
# Initialize Terraform (downloads modules and providers)
terraform init

# Expected output includes:
# - Initializing modules...
# - Initializing the backend...
# - Initializing provider plugins...
# - Terraform has been successfully initialized!
```

**Troubleshooting**:
- If module download fails, verify HCP Terraform credentials are configured
- If backend initialization fails, check `override.tf` for correct organization and workspace names

---

## Step 5: Validate Configuration

```bash
# Validate Terraform syntax
terraform validate

# Expected output:
# Success! The configuration is valid.

# Format code (optional)
terraform fmt -recursive

# Check for formatting issues
terraform fmt -check
```

---

## Step 6: Preview Infrastructure Changes

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review planned changes:
# - Should show creation of ~15-20 resources
# - 2 EC2 instances
# - 1 Application Load Balancer
# - 2 Security Groups
# - 2 IAM Roles
# - Target Groups and Listeners
# - Target Group Attachments
```

**Review Checklist**:
- [ ] 2 EC2 instances in different availability zones
- [ ] 1 internet-facing Application Load Balancer
- [ ] HTTP listener configured with redirect to HTTPS
- [ ] HTTPS listener configured with ACM certificate
- [ ] Security groups configured correctly (ALB → EC2)
- [ ] IAM roles with AmazonSSMManagedInstanceCore policy

---

## Step 7: Deploy Infrastructure

```bash
# Apply the plan (creates actual resources)
terraform apply tfplan

# Deployment takes approximately 3-5 minutes
# Expected output:
# Apply complete! Resources: X added, 0 changed, 0 destroyed.
```

**What Happens During Deployment**:
1. Security groups are created
2. IAM roles and instance profiles are created
3. ALB is provisioned (2-3 minutes)
4. EC2 instances are launched (1-2 minutes)
5. User data script installs Nginx (~30-60 seconds)
6. Health checks start and instances become healthy (~60 seconds)

---

## Step 8: Retrieve Deployment Outputs

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "ALB DNS Name: ${ALB_DNS}"

# Get instance IDs
INSTANCE_ID_AZ_A=$(terraform output -json instance_ids | jq -r '.az_a')
INSTANCE_ID_AZ_B=$(terraform output -json instance_ids | jq -r '.az_b')
echo "Instance ID (AZ-A): ${INSTANCE_ID_AZ_A}"
echo "Instance ID (AZ-B): ${INSTANCE_ID_AZ_B}"

# Get target group ARN
TG_ARN=$(terraform output -raw target_group_arn)
echo "Target Group ARN: ${TG_ARN}"

# Save outputs to file for easy reference
terraform output > deployment-outputs.txt
```

---

## Step 9: Verify Deployment

### 9.1 Check Target Health

```bash
# Verify both instances are healthy
aws elbv2 describe-target-health \
  --target-group-arn ${TG_ARN} \
  --region ap-southeast-1

# Expected: Both targets with State="healthy"
```

**Wait for Health Checks**: It may take 60-90 seconds after deployment for instances to become healthy.

### 9.2 Test HTTPS Connectivity

```bash
# Test HTTPS endpoint (ignore certificate warning)
curl -k https://${ALB_DNS}/

# Expected: HTML page with instance information
```

**Browser Test**:
1. Open browser and navigate to: `https://<ALB_DNS>`
2. Accept browser warning (self-signed certificate)
3. Verify page loads with instance information

### 9.3 Test HTTP to HTTPS Redirect

```bash
# Test HTTP redirect
curl -I http://${ALB_DNS}/

# Expected output:
# HTTP/1.1 301 Moved Permanently
# Location: https://<ALB_DNS>/
```

### 9.4 Test Multi-AZ Load Balancing

```bash
# Make multiple requests to see load distribution
for i in {1..10}; do
  curl -k -s https://${ALB_DNS}/ | grep "Availability Zone"
done

# Expected: Mix of responses from ap-southeast-1a and ap-southeast-1b
```

---

## Step 10: Test Systems Manager Access

### 10.1 Connect to Instance via Session Manager

```bash
# Connect to first instance
aws ssm start-session --target ${INSTANCE_ID_AZ_A}

# Once connected, run commands:
# whoami              # Should show: ssm-user
# systemctl status nginx
# curl localhost
# exit
```

### 10.2 Verify SSH is Disabled

```bash
# Verify instance has no SSH key pair
aws ec2 describe-instances \
  --instance-ids ${INSTANCE_ID_AZ_A} \
  --region ap-southeast-1 \
  --query 'Reservations[0].Instances[0].KeyName'

# Expected: null or empty (no SSH key)

# Verify no SSH security group rule
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*ec2-sg*" \
  --region ap-southeast-1 \
  --query 'SecurityGroups[].IpPermissions[?FromPort==`22`]'

# Expected: [] (empty array, no SSH rules)
```

---

## Step 11: Test Health Check Behavior (Optional)

### 11.1 Simulate Instance Failure

```bash
# Connect to one instance
aws ssm start-session --target ${INSTANCE_ID_AZ_A}

# Stop Nginx service
sudo systemctl stop nginx

# Exit session
exit

# Wait 60 seconds for health checks to detect failure
sleep 60

# Verify instance is marked unhealthy
aws elbv2 describe-target-health \
  --target-group-arn ${TG_ARN} \
  --region ap-southeast-1

# Expected: One target "unhealthy", one target "healthy"
```

### 11.2 Verify Traffic Routes to Healthy Instance Only

```bash
# Make multiple requests (should all go to healthy instance)
for i in {1..10}; do
  curl -k -s https://${ALB_DNS}/ | grep "Availability Zone"
done

# Expected: All responses from the same AZ (healthy instance only)
```

### 11.3 Recover Failed Instance

```bash
# Reconnect to failed instance
aws ssm start-session --target ${INSTANCE_ID_AZ_A}

# Start Nginx service
sudo systemctl start nginx

# Verify service is running
systemctl status nginx

# Exit session
exit

# Wait 60 seconds for health checks to detect recovery
sleep 60

# Verify both instances are healthy again
aws elbv2 describe-target-health \
  --target-group-arn ${TG_ARN} \
  --region ap-southeast-1

# Expected: Both targets "healthy"
```

---

## Step 12: Monitor and Observe

### 12.1 View CloudWatch Metrics

```bash
# Open AWS Console CloudWatch
# Navigate to: CloudWatch > All metrics > ApplicationELB
# Select your ALB and view metrics:
#   - RequestCount
#   - TargetResponseTime
#   - HealthyHostCount
#   - UnHealthyHostCount
```

### 12.2 View EC2 Instance Logs

```bash
# Connect to instance
aws ssm start-session --target ${INSTANCE_ID_AZ_A}

# View user data execution log
sudo cat /var/log/user-data-installation.log

# View Nginx access logs
sudo tail -f /var/log/nginx/access.log

# View Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Exit session
exit
```

---

## Step 13: Cost Monitoring

### 13.1 Check Estimated Monthly Cost

```bash
# Use AWS Cost Explorer or Pricing Calculator
# Expected monthly cost (24/7 operation):
#   - EC2 (2x t3.micro): ~$15/month
#   - ALB: ~$20-25/month
#   - Data transfer: ~$2-5/month
#   - Total: ~$37-45/month
```

### 13.2 Stop Instances to Save Costs (Optional)

```bash
# Stop EC2 instances when not in use
aws ec2 stop-instances \
  --instance-ids ${INSTANCE_ID_AZ_A} ${INSTANCE_ID_AZ_B} \
  --region ap-southeast-1

# Note: ALB charges continue even when instances are stopped
# To fully stop costs, destroy infrastructure (Step 14)
```

---

## Step 14: Cleanup (Destroy Infrastructure)

### 14.1 Destroy Terraform Resources

```bash
# Destroy all resources created by Terraform
terraform destroy -auto-approve

# Confirmation: Type 'yes' when prompted
# Destruction takes approximately 3-5 minutes
```

### 14.2 Delete ACM Certificate

```bash
# Delete imported certificate
aws acm delete-certificate \
  --certificate-arn ${ACM_CERT_ARN} \
  --region ap-southeast-1

# Verify deletion
aws acm list-certificates --region ap-southeast-1
```

### 14.3 Clean Up Local Files

```bash
# Remove Terraform state files
rm -f tfplan terraform.tfstate terraform.tfstate.backup

# Remove certificate files
rm -rf ~/ec2-alb-nginx-certs

# Remove outputs file
rm -f deployment-outputs.txt
```

---

## Troubleshooting Guide

### Issue 1: Certificate Import Failed

**Symptom**: `aws acm import-certificate` returns error

**Solutions**:
```bash
# Verify OpenSSL files exist and have correct permissions
ls -l alb-*.pem

# Regenerate certificate with correct syntax
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout alb-private-key.pem \
  -out alb-certificate.pem \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=Development/CN=*.elb.amazonaws.com"

# Retry import
```

### Issue 2: Default VPC Not Found

**Symptom**: Terraform plan fails with "No default VPC found"

**Solutions**:
```bash
# Check if default VPC exists
aws ec2 describe-vpcs --region ap-southeast-1 \
  --filters "Name=is-default,Values=true"

# If no default VPC, create one (AWS CLI v2):
aws ec2 create-default-vpc --region ap-southeast-1

# Or contact AWS support to restore default VPC
```

### Issue 3: Instances Not Becoming Healthy

**Symptom**: Instances remain in "initial" or "unhealthy" state

**Solutions**:
```bash
# Connect to instance and check Nginx status
aws ssm start-session --target <instance-id>
sudo systemctl status nginx

# View user data execution log
sudo cat /var/log/user-data-installation.log

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <ec2-security-group-id> \
  --region ap-southeast-1

# Verify health check endpoint locally
curl http://localhost/
```

### Issue 4: 503 Service Unavailable Error

**Symptom**: Browser shows "503 Service Unavailable" when accessing ALB

**Solutions**:
```bash
# Verify target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region ap-southeast-1

# If all unhealthy, wait 2-3 minutes for health checks
# If still unhealthy, check instance logs (see Issue 3)

# Verify instances are running
aws ec2 describe-instance-status \
  --instance-ids <instance-id-1> <instance-id-2> \
  --region ap-southeast-1
```

### Issue 5: Session Manager Connection Failed

**Symptom**: Cannot connect to instance via Session Manager

**Solutions**:
```bash
# Verify IAM role is attached to instance
aws ec2 describe-instances \
  --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Verify SSM agent is running (wait 2-3 minutes after launch)
# Retry connection after waiting

# Check if instance is registered with Systems Manager
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=<instance-id>" \
  --region ap-southeast-1
```

---

## Success Criteria Validation

Use this checklist to confirm successful deployment:

- [ ] Both EC2 instances are running
- [ ] Both instances show "healthy" in target group
- [ ] HTTPS endpoint loads successfully (with certificate warning)
- [ ] HTTP endpoint redirects to HTTPS (301 status)
- [ ] Page displays correct instance ID and availability zone
- [ ] Multiple requests show traffic distributed across both AZs
- [ ] Systems Manager Session Manager can connect to both instances
- [ ] No SSH access is possible (no keys, no security group rules)
- [ ] All resources are tagged correctly
- [ ] Monthly cost estimate is under $50 (based on AWS Pricing Calculator)

---

## Additional Resources

### AWS Documentation
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [EC2 User Data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [AWS Certificate Manager](https://docs.aws.amazon.com/acm/)

### Terraform Documentation
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs)

### Project Files
- [Specification](./spec.md)
- [Implementation Plan](./plan.md)
- [Data Model](./data-model.md)
- [Contracts](./contracts/)

---

**End of Quick Start Guide**
