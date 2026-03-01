# Quick Start Guide: EC2 ALB Nginx Infrastructure

**Feature**: AWS EC2 Infrastructure with Application Load Balancer and Nginx  
**Branch**: `001-ec2-alb-nginx`  
**Date**: 2025-01-13

---

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **HCP Terraform Access**
   - Organization: `ravi-panchal-org`
   - Project: `Default Project`
   - Workspace: `sandbox_workspace`
   - Valid authentication token

2. **AWS Credentials**
   - Configured in HCP Terraform workspace variables
   - Permissions for EC2, VPC, ELB, ACM
   - Region: ap-southeast-1

3. **Default VPC Exists**
   ```bash
   aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region ap-southeast-1
   ```

4. **Local Tools**
   - Terraform CLI >= 1.7.0
   - AWS CLI v2
   - curl or similar HTTP client

---

## Deployment Steps

### Step 1: Clone and Navigate

```bash
# Clone the repository (if not already done)
git clone <repository-url>
cd <repository-name>

# Checkout feature branch
git checkout 001-ec2-alb-nginx
```

### Step 2: Configure HCP Terraform

```bash
# Login to HCP Terraform
terraform login

# Initialize Terraform (connects to remote backend)
terraform init
```

Expected output:
```
Initializing modules...
Initializing the backend...
Successfully configured the backend "remote"!
```

### Step 3: Review the Plan

```bash
# Generate execution plan
terraform plan

# Review planned changes:
# - 2 EC2 instances (t3.micro)
# - 1 Application Load Balancer
# - 2 Security Groups
# - 1 ACM Certificate (self-signed)
# - 1 Target Group
# - TLS resources
```

### Step 4: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply

# Confirm with 'yes' when prompted
# Deployment takes approximately 5-8 minutes
```

### Step 5: Retrieve Outputs

```bash
# Get the ALB endpoint
terraform output alb_endpoint

# Example output:
# "https://ec2-nginx-alb-1234567890.ap-southeast-1.elb.amazonaws.com"

# Get all outputs in JSON format
terraform output -json
```

---

## Testing the Deployment

### Test 1: Access the Web Application

```bash
# Get the endpoint
ALB_ENDPOINT=$(terraform output -raw alb_endpoint)

# Access via curl (ignore self-signed cert warning)
curl -k $ALB_ENDPOINT

# Or open in browser (accept certificate warning)
echo $ALB_ENDPOINT
```

**Expected Result**: HTML page showing instance ID and availability zone

**Browser Warnings**: 
- Chrome: Click "Advanced" → "Proceed to site (unsafe)"
- Firefox: Click "Advanced" → "Accept the Risk and Continue"
- This is expected for self-signed certificates

### Test 2: Verify Certificate

```bash
# Extract ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Check certificate details
openssl s_client -connect $ALB_DNS:443 -servername web.demo.com | grep -A 5 "subject="
```

**Expected Result**:
```
subject=CN = web.demo.com, O = Development, OU = Engineering, C = SG
```

### Test 3: Check Target Health

```bash
# Get target group ARN from Terraform state
TG_ARN=$(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.alb") | .resources[] | select(.type=="aws_lb_target_group") | .values.arn')

# Check target health status
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region ap-southeast-1
```

**Expected Result**: Both targets show state="healthy"

### Test 4: Verify Multi-AZ Deployment

```bash
# Get instance availability zones
terraform output -json ec2_instance_availability_zones

# Should show two different AZs:
# ["ap-southeast-1a", "ap-southeast-1b"]
```

### Test 5: Security Group Validation

```bash
# Try to access EC2 instance directly (should fail)
EC2_IP=$(terraform output -json ec2_instance_public_ips | jq -r '.[0]')
curl http://$EC2_IP --max-time 5

# Expected: Connection timeout (blocked by security group)
```

### Test 6: Failover Test (Optional)

```bash
# Get first instance ID
INSTANCE_ID=$(terraform output -json ec2_instance_ids | jq -r '.[0]')

# Stop Nginx on the instance (requires SSM Session Manager)
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo systemctl stop nginx"]' \
  --region ap-southeast-1

# Wait 60 seconds for health check to detect failure
sleep 60

# Verify ALB still serves traffic from healthy instance
for i in {1..10}; do curl -k $ALB_ENDPOINT; sleep 1; done

# Restart Nginx
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo systemctl start nginx"]' \
  --region ap-southeast-1
```

---

## Monitoring

### CloudWatch Metrics

Access CloudWatch dashboard:
```bash
# Open CloudWatch in browser
echo "https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-1"
```

**Key Metrics to Monitor**:
- ALB: `HTTPCode_Target_2XX_Count`, `TargetResponseTime`
- Target Group: `HealthyHostCount`, `UnHealthyHostCount`
- EC2: `CPUUtilization`, `NetworkIn`, `NetworkOut`

### Health Check Status

```bash
# Continuous health monitoring (refresh every 30 seconds)
watch -n 30 "aws elbv2 describe-target-health --target-group-arn $TG_ARN --region ap-southeast-1"
```

---

## Troubleshooting

### Issue: Terraform init fails

**Symptom**: "Error: Failed to get existing workspaces"

**Solution**:
```bash
# Re-authenticate with HCP Terraform
terraform logout
terraform login

# Verify credentials
terraform init
```

### Issue: Default VPC not found

**Symptom**: "Error: no matching VPC found"

**Solution**:
```bash
# Check if default VPC exists
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region ap-southeast-1

# If not found, create default VPC
aws ec2 create-default-vpc --region ap-southeast-1
```

### Issue: Health checks failing

**Symptom**: Targets show "unhealthy" status

**Solution**:
```bash
# SSH to instance (if key pair configured) or use Session Manager
# Check Nginx status
sudo systemctl status nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart Nginx if needed
sudo systemctl restart nginx
```

### Issue: Certificate warnings persist

**Symptom**: Browser shows "NET::ERR_CERT_AUTHORITY_INVALID"

**Solution**: This is expected behavior for self-signed certificates. For development testing:
- Accept the certificate warning in browser
- Use `curl -k` flag to ignore certificate validation
- For production, replace with CA-signed certificate

### Issue: 503 Service Unavailable

**Symptom**: ALB returns 503 errors

**Possible Causes**:
1. Both instances unhealthy - check Nginx status
2. Target group not registered - verify target registration
3. Security group blocking traffic - check EC2 security group rules

**Debug Commands**:
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN --region ap-southeast-1

# Check security group rules
EC2_SG=$(terraform output -raw ec2_security_group_id)
aws ec2 describe-security-groups --group-ids $EC2_SG --region ap-southeast-1
```

---

## Cost Management

### Estimated Monthly Costs

| Component | Cost |
|-----------|------|
| 2x t3.micro instances | $14.60 |
| 2x EBS GP3 volumes (8GB) | $1.60 |
| Application Load Balancer | $22.27 |
| Data transfer (minimal) | $0.20 |
| **Total** | **~$38.67/month** |

### Cost Optimization Tips

1. **Stop instances during off-hours** (if not needed 24/7):
   ```bash
   aws ec2 stop-instances --instance-ids $(terraform output -json ec2_instance_ids | jq -r '.[]')
   ```

2. **Monitor usage**:
   ```bash
   # Set up billing alert in AWS Budgets
   aws budgets create-budget --account-id <account-id> --budget file://budget.json
   ```

---

## Cleanup

### Destroy Infrastructure

```bash
# Destroy all resources
terraform destroy

# Confirm with 'yes' when prompted
# Destruction takes approximately 3-5 minutes
```

### Verify Cleanup

```bash
# Check no instances remain
aws ec2 describe-instances --filters "Name=tag:Project,Values=ec2-alb-nginx" --region ap-southeast-1

# Check no load balancers remain
aws elbv2 describe-load-balancers --region ap-southeast-1 | grep ec2-nginx-alb

# Check no certificates remain
aws acm list-certificates --region ap-southeast-1 | grep web.demo.com
```

---

## Next Steps

### Production Readiness

To make this infrastructure production-ready, consider:

1. **Certificate**: Replace self-signed with CA-signed certificate
2. **Monitoring**: Add CloudWatch alarms and SNS notifications
3. **Logging**: Enable ALB access logs to S3
4. **Auto Scaling**: Implement Auto Scaling Group
5. **Backup**: Configure automated backups
6. **WAF**: Add AWS WAF for web application firewall
7. **DNS**: Configure Route53 with custom domain

### Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [Private Module Registry](https://app.terraform.io/ravi-panchal-org/registry/modules/private)

---

## Support

For issues or questions:
1. Check research.md for architectural decisions
2. Review data-model.md for resource relationships
3. Consult Terraform documentation
4. Reach out to platform team for module-specific questions

---

**Quick Start Guide Complete** ✅  
**Estimated Time to Deploy**: 15 minutes  
**Difficulty Level**: Beginner
