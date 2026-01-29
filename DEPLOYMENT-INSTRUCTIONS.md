# 🚀 Deployment Instructions: EC2 ALB Nginx Infrastructure

**Status**: ✅ Code Complete - Ready for Plan (pending ACM certificate)  
**Feature**: ec2-alb-nginx-gh29  
**Workspace**: sandbox_workspace  
**Organization**: ravi-panchal-org

---

## ⚠️ IMPORTANT: Test Environment Only

**DO NOT RUN `terraform apply` in sandbox_workspace**

This workspace is for testing terraform init/validate/plan only.

---

## 📋 Pre-Deployment Checklist

- [X] Feature branch checked out: `feature/ec2-alb-nginx-gh29`
- [X] Terraform initialized with HCP Terraform backend
- [X] Configuration validated successfully
- [X] All Terraform files formatted
- [X] Private registry modules downloaded (v6.1.4, v10.2.0, v5.3.1)
- [ ] ACM certificate ARN configured in sandbox.auto.tfvars

---

## 🔐 Step 1: Setup ACM Certificate

### Option A: Generate Self-Signed Certificate (Development)

```bash
# Run the automated setup script
./setup-acm-cert.sh

# Script will:
# 1. Generate self-signed certificate
# 2. Import to ACM in ap-southeast-1
# 3. Display Certificate ARN
# 4. Clean up temporary files
```

### Option B: Use Existing ACM Certificate

```bash
# List existing certificates
aws acm list-certificates --region ap-southeast-1

# Copy the CertificateArn from output
```

### Step 1.1: Update Configuration

Edit `sandbox.auto.tfvars` and replace:

```hcl
# FROM:
acm_certificate_arn = "REPLACE_WITH_YOUR_ACM_CERTIFICATE_ARN"

# TO:
acm_certificate_arn = "arn:aws:acm:ap-southeast-1:ACCOUNT_ID:certificate/CERT_ID"
```

---

## 📝 Step 2: Create Terraform Plan

```bash
# Create execution plan
terraform plan -out=tfplan

# Expected output:
# Plan: 15 to add, 0 to change, 0 to destroy
```

### What Gets Created

The plan will show:

**IAM Resources (4)**:
- aws_iam_policy.ec2_session_manager
- aws_iam_role.ec2_instance
- aws_iam_role_policy_attachment.ec2_session_manager
- aws_iam_instance_profile.ec2_instance

**Security Groups (2 modules)**:
- module.alb_security_group
- module.ec2_security_group

**EC2 Instances (2 modules)**:
- module.ec2_instance_1
- module.ec2_instance_2

**Load Balancer (1 module + 2 attachments)**:
- module.alb (includes ALB, target group, listeners)
- aws_lb_target_group_attachment.instance_1
- aws_lb_target_group_attachment.instance_2

**Total**: ~15 resources

---

## 🔍 Step 3: Review Plan Output

### Verify Security Settings

```bash
# Check EBS encryption
terraform show tfplan | grep -A 5 "root_block_device"
# Expected: encrypted = true

# Check IMDSv2 enforcement
terraform show tfplan | grep -A 3 "metadata_options"
# Expected: http_tokens = "required"

# Check IAM policy
terraform show tfplan | grep -A 20 "aws_iam_policy.ec2_session_manager"
# Expected: Only Session Manager permissions
```

### Verify Network Configuration

```bash
# Check security groups
terraform show tfplan | grep -A 10 "module.alb_security_group"
terraform show tfplan | grep -A 10 "module.ec2_security_group"

# Check multi-AZ deployment
terraform output ec2_availability_zones
# Expected: 2 different AZs
```

### Verify Cost Estimation

```bash
# Check instance types
terraform show tfplan | grep "instance_type"
# Expected: t3.micro

# Count instances
terraform show tfplan | grep "module.ec2_instance" | wc -l
# Expected: 2
```

---

## 💰 Step 4: Cost Review

**Estimated Monthly Cost**: $31-34/month

| Resource | Quantity | Monthly Cost |
|----------|----------|--------------|
| t3.micro instances | 2 | $15.12 |
| Application Load Balancer | 1 | $16.00 |
| EBS volumes (8GB gp3) | 2 | $1.28 |
| **Total** | | **$31-34** |

**Budget Approval Required**: Yes (for production)

---

## ⚠️ Step 5: Apply Changes (PRODUCTION ONLY)

**🛑 STOP: Do NOT run this in sandbox_workspace**

For production deployment only:

```bash
# Apply the plan
terraform apply tfplan

# Wait for completion (15-22 minutes)
# - EC2 provisioning: 2-3 minutes
# - Nginx installation: 3-5 minutes per instance
# - ALB provisioning: 3-5 minutes
# - Health checks: 2-4 minutes
```

---

## ✅ Step 6: Post-Deployment Validation

### Capture Outputs

```bash
# Save all outputs
terraform output -json > outputs.json

# Display key outputs
terraform output https_endpoint
terraform output alb_dns_name
terraform output ec2_instance_ids
```

### Test HTTPS Access

```bash
# Get HTTPS endpoint
HTTPS_URL=$(terraform output -raw https_endpoint)

# Test HTTPS connection
curl -I $HTTPS_URL
# Expected: HTTP/2 200

# View content
curl $HTTPS_URL
# Expected: HTML page with instance metadata
```

### Test HTTP Redirect

```bash
# Get ALB DNS
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTP redirect
curl -I http://$ALB_DNS
# Expected: HTTP/1.1 301 Moved Permanently
# Location: https://...
```

### Verify Load Distribution

```bash
# Send multiple requests
for i in {1..10}; do
  curl -s $HTTPS_URL | grep "Instance ID"
done

# Expected: Should see both instance IDs rotating
```

### Check Target Health

```bash
# Via AWS Console:
# EC2 > Target Groups > ec2-alb-nginx-tg-dev > Targets tab
# Expected: Both targets "healthy"

# Via Terraform output:
terraform output target_group_arn
```

---

## 🔧 Troubleshooting

### Issue: ACM Certificate Invalid

**Error**: `"certificate_arn" (...) is an invalid ARN`

**Solution**:
1. Verify certificate ARN format: `arn:aws:acm:REGION:ACCOUNT:certificate/ID`
2. Ensure certificate is in ap-southeast-1 region
3. Check certificate status is "Issued" (not "Pending")

### Issue: Targets Unhealthy

**Symptoms**: ALB returns 503 errors

**Diagnosis**:
```bash
# Connect via Session Manager
aws ssm start-session --target i-INSTANCE_ID --region ap-southeast-1

# Check Nginx status
systemctl status nginx

# Check user data logs
cat /var/log/user-data-status.log

# Test local connection
curl http://localhost/
```

**Solutions**:
- Wait 2-4 minutes for initial health checks
- Verify security group allows ALB → EC2:80
- Check Nginx is running: `systemctl restart nginx`

### Issue: Terraform Plan Fails

**Error**: Various validation errors

**Solution**:
```bash
# Re-initialize
rm -rf .terraform/
terraform init

# Re-validate
terraform validate
terraform fmt -recursive
```

---

## 📊 Monitoring Setup (Optional)

### Enable CloudWatch Metrics

1. ALB Metrics (automatic):
   - RequestCount
   - TargetResponseTime
   - HTTPCode_Target_2XX_Count
   - UnHealthyHostCount

2. EC2 Metrics (basic, automatic):
   - CPUUtilization
   - NetworkIn/NetworkOut
   - DiskReadOps/DiskWriteOps

### Enable Access Logs

Update `main.tf` and add to ALB module:

```hcl
access_logs = {
  bucket  = "your-log-bucket"
  enabled = true
  prefix  = "alb-logs"
}
```

---

## 🧹 Cleanup (Test Environment)

To destroy all resources:

```bash
# Create destroy plan
terraform plan -destroy -out=destroy.tfplan

# Review destroy plan
terraform show destroy.tfplan

# Execute destroy (⚠️ CAUTION)
terraform apply destroy.tfplan

# Delete ACM certificate
aws acm delete-certificate \
  --certificate-arn arn:aws:acm:... \
  --region ap-southeast-1
```

**Estimated Time**: 5-10 minutes

---

## 📚 Additional Resources

- [README.md](./README.md) - Full documentation
- [IMPLEMENTATION-SUMMARY.md](./IMPLEMENTATION-SUMMARY.md) - Implementation details
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## ✅ Deployment Checklist

- [ ] ACM certificate created and ARN configured
- [ ] Terraform plan created and reviewed
- [ ] Security settings verified (EBS encryption, IMDSv2, IAM)
- [ ] Cost estimation reviewed and approved
- [ ] Terraform apply executed (production only)
- [ ] HTTPS endpoint tested successfully
- [ ] HTTP redirect verified
- [ ] Target health confirmed (both healthy)
- [ ] Load distribution validated
- [ ] Outputs captured and documented

---

## 📞 Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review [README.md](./README.md) guide
3. Consult [Implementation Summary](./IMPLEMENTATION-SUMMARY.md)

---

**Last Updated**: 2025-01-29  
**Version**: 1.0.0  
**Status**: Ready for Plan (pending ACM certificate)
