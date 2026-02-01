# Quickstart Guide: EC2 Infrastructure with ALB and Nginx

**Feature**: 002-ec2-alb-nginx  
**Date**: 2025-02-01  
**Estimated Time**: 15 minutes

## Prerequisites

### Required Tools
- Terraform >= 1.5.7
- AWS CLI v2
- Git
- curl (for testing)
- HCP Terraform account with access to `ravi-panchal-org` organization

### Required Access
- HCP Terraform workspace: `sandbox_workspace`
- AWS credentials (pre-configured in HCP Terraform workspace variable sets)
- Git repository: `https://github.com/panchal-ravi/ai-iac-consumer-template.git`

### Verify Environment
```bash
# Check Terraform version
terraform version
# Expected: >= 1.5.7

# Check AWS CLI
aws --version
# Expected: aws-cli/2.x

# Check git
git --version

# Verify HCP Terraform login
terraform login
```

---

## Step 1: Clone Repository and Checkout Feature Branch

```bash
# Clone repository
git clone https://github.com/panchal-ravi/ai-iac-consumer-template.git
cd ai-iac-consumer-template

# Checkout feature branch
git checkout 002-ec2-alb-nginx

# Verify branch
git branch --show-current
# Expected: 002-ec2-alb-nginx
```

---

## Step 2: Review Configuration Files

### Check Terraform Backend Configuration
```bash
cat override.tf
```

**Expected**:
- Organization: `ravi-panchal-org`
- Workspace: `sandbox_workspace`
- Execution mode: Remote

### Check Variable Values
```bash
cat sandbox.auto.tfvars
```

**Key Variables**:
- `project_name = "nginx-alb"`
- `environment = "development"`
- `region = "ap-southeast-1"`
- `availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]`
- `domain_name = "web.demo.com"`
- `instance_type = "t3a.micro"`

---

## Step 3: Initialize Terraform

```bash
# Initialize Terraform (downloads providers and modules)
terraform init

# Expected output:
# - AWS provider downloaded
# - TLS provider downloaded
# - Private modules initialized from ravi-panchal-org registry
# - Backend configured successfully
```

**Troubleshooting**:
- If module download fails: Verify access to HCP Terraform organization
- If backend fails: Check `override.tf` configuration and HCP Terraform login

---

## Step 4: Validate Configuration

```bash
# Format check
terraform fmt -check

# Validate syntax
terraform validate

# Run TFLint (if available)
tflint --init
tflint

# Expected: All checks pass
```

---

## Step 5: Review Deployment Plan

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review changes
# Expected resources:
# - 2 EC2 instances (t3a.micro)
# - 1 Application Load Balancer
# - 1 Target Group
# - 3 Security Groups (ALB, EC2, default)
# - 1 ACM Certificate (self-signed)
# - TLS private key and certificate resources
# - Data sources (VPC, subnets)
```

**Key Points to Verify**:
- ✅ 2 EC2 instances planned
- ✅ Instances in different availability zones (ap-southeast-1a, ap-southeast-1b)
- ✅ ALB with HTTPS listener on port 443
- ✅ No HTTP listener (HTTPS-only)
- ✅ Security groups configured correctly

---

## Step 6: Deploy Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# Deployment time: 5-10 minutes
# Watch for:
# - EC2 instances launching
# - ALB creation and configuration
# - Target health checks
```

**Deployment Progress**:
1. Data sources: VPC and subnet discovery (< 10 seconds)
2. Certificate generation: TLS key and cert creation (< 30 seconds)
3. Security groups: ALB and EC2 security groups (< 1 minute)
4. EC2 instances: Launch and Nginx installation (2-3 minutes)
5. Load balancer: ALB, target group, listeners (2-3 minutes)
6. Health checks: Instances marked healthy (1-2 minutes)

---

## Step 7: Verify Deployment

### Get ALB DNS Name
```bash
# Retrieve ALB DNS name
terraform output alb_dns_name

# Example output:
# nginx-alb-1234567890.ap-southeast-1.elb.amazonaws.com
```

### Test HTTPS Access
```bash
# Test HTTPS endpoint (accept self-signed certificate)
ALB_DNS=$(terraform output -raw alb_dns_name)
curl -k https://$ALB_DNS

# Expected: Nginx test page HTML
# Should include:
# - "Welcome to EC2 ALB Nginx Demo"
# - Instance ID
# - Availability Zone
```

### Verify Certificate
```bash
# Check TLS handshake
openssl s_client -connect $ALB_DNS:443 -servername web.demo.com

# Expected:
# - Certificate for CN=web.demo.com
# - Self-signed certificate warning (expected)
# - Successful TLS handshake
```

### Check Instance Health
```bash
# Get target group ARN
TG_ARN=$(terraform output -raw target_group_arn)

# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Expected: 2 targets with "State": "healthy"
```

### Verify Instance Distribution
```bash
# Get instance IDs
terraform output ec2_instance_ids

# Check availability zones
aws ec2 describe-instances \
  --filters "Name=tag:Feature,Values=002-ec2-alb-nginx" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,Placement.AvailabilityZone]' \
  --output table

# Expected:
# Instance 1: ap-southeast-1a, running
# Instance 2: ap-southeast-1b, running
```

### Browser Testing
```bash
# Open in browser
echo "Open this URL in your browser:"
echo "https://$ALB_DNS"

# Steps:
# 1. Navigate to URL
# 2. Accept self-signed certificate warning (click "Advanced" → "Proceed")
# 3. Verify test page loads
# 4. Refresh multiple times to see load balancing (instance ID changes)
```

---

## Step 8: Test High Availability

### Terminate One Instance
```bash
# Get instance IDs
INSTANCES=($(terraform output -json ec2_instance_ids | jq -r '.[]'))
INSTANCE_1=${INSTANCES[0]}

# Terminate first instance
aws ec2 terminate-instances --instance-ids $INSTANCE_1

# Wait for termination
aws ec2 wait instance-terminated --instance-ids $INSTANCE_1
```

### Verify Service Continuity
```bash
# Test HTTPS access (should still work)
for i in {1..10}; do
  curl -k -s -o /dev/null -w "Request $i: %{http_code}\n" https://$ALB_DNS
  sleep 2
done

# Expected: All requests return 200 (Success)
# Demonstrates: Zero downtime with single instance failure (SC-003)
```

### Check Target Health
```bash
# Verify one target healthy, one unhealthy
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Expected:
# - 1 target: "State": "healthy"
# - 1 target: "State": "unhealthy" or "unused"
```

---

## Step 9: Verify Success Criteria

### Checklist (from spec.md)

- [ ] **SC-001**: Infrastructure accessible via HTTPS within 60 seconds of deployment
  ```bash
  curl -k -I https://$ALB_DNS
  # Expected: HTTP/2 200
  ```

- [ ] **SC-002**: Nginx test page loads with valid TLS handshake
  ```bash
  curl -k https://$ALB_DNS | grep "Welcome to EC2 ALB Nginx Demo"
  # Expected: Match found
  ```

- [ ] **SC-003**: Service available with one instance terminated (tested in Step 8)
  
- [ ] **SC-004**: No direct HTTP traffic accepted
  ```bash
  curl -I http://$ALB_DNS
  # Expected: Connection refused or timeout
  ```

- [ ] **SC-005**: Terraform validation passes
  ```bash
  terraform validate
  # Expected: Success! The configuration is valid.
  ```

- [ ] **SC-006**: Cannot SSH to instances directly
  ```bash
  # Get instance public IP
  INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_1 \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  
  # Try SSH (should fail)
  ssh -o ConnectTimeout=5 ec2-user@$INSTANCE_IP
  # Expected: Connection timeout (no SSH access)
  ```

- [ ] **SC-007**: Cost under $50/month
  ```bash
  # Check AWS Cost Explorer or run cost estimate
  # Expected monthly cost: ~$30-35
  # - 2 × t3a.micro: ~$13.54
  # - 1 × ALB: ~$16.20
  # - EBS volumes: ~$0.20
  # - Data transfer: minimal
  ```

- [ ] **SC-008**: Instances healthy within 5 minutes
  ```bash
  # Already verified in Step 7
  ```

- [ ] **SC-009**: Certificate visible in ACM
  ```bash
  # Get certificate ARN
  CERT_ARN=$(terraform output -raw acm_certificate_arn)
  
  # Check certificate in ACM
  aws acm describe-certificate --certificate-arn $CERT_ARN
  # Expected: Status = ISSUED
  ```

- [ ] **SC-010**: Instances in different AZs
  ```bash
  # Already verified in Step 7
  ```

---

## Step 10: Cost Monitoring

### Set Up Budget Alert (Optional)
```bash
# Create AWS Budget for this feature
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "ec2-alb-nginx-dev",
    "BudgetLimit": {
      "Amount": "50",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {
      "TagKeyValue": ["user:Feature$002-ec2-alb-nginx"]
    }
  }'
```

### Monitor Costs
```bash
# View costs for this feature (after 24 hours)
aws ce get-cost-and-usage \
  --time-period Start=2025-02-01,End=2025-02-02 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --filter '{
    "Tags": {
      "Key": "Feature",
      "Values": ["002-ec2-alb-nginx"]
    }
  }'
```

---

## Cleanup (Optional)

### Destroy Infrastructure
```bash
# Preview destruction plan
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm with: yes

# Destruction time: 3-5 minutes
```

**Resources Destroyed**:
- Application Load Balancer
- Target Group and listeners
- EC2 instances
- Security groups
- ACM certificate
- TLS certificate resources

**Not Destroyed** (by design):
- Default VPC (pre-existing)
- Subnets (pre-existing)
- IAM roles (if managed externally)

---

## Troubleshooting

### Issue: Deployment Fails at EC2 Launch

**Symptom**: `Error launching instances: InsufficientInstanceCapacity`

**Solution**: 
- Try different availability zones
- Use alternative instance type (t3.micro instead of t3a.micro)

### Issue: Health Checks Failing

**Symptom**: Targets marked unhealthy, ALB returns 503

**Possible Causes**:
1. Nginx not started: Check user data execution
   ```bash
   aws ssm start-session --target $INSTANCE_ID
   systemctl status nginx
   ```

2. Security group misconfigured: Verify ALB can reach instances on port 80
   ```bash
   # Check security group rules
   aws ec2 describe-security-groups \
     --group-ids $(terraform output -raw ec2_security_group_id)
   ```

3. Health check path incorrect: Verify `/` returns HTTP 200
   ```bash
   # SSH to instance and test locally
   curl http://localhost/
   ```

### Issue: Cannot Access ALB via HTTPS

**Symptom**: Connection timeout or refused

**Possible Causes**:
1. ALB not fully provisioned: Wait 2-3 minutes after apply
2. Security group blocks port 443: Check ALB security group ingress rules
3. Certificate not attached: Verify certificate ARN in listener

**Solution**:
```bash
# Check ALB state
aws elbv2 describe-load-balancers \
  --load-balancer-arns $(terraform output -raw alb_arn) \
  --query 'LoadBalancers[0].State'

# Expected: "State": {"Code": "active"}
```

### Issue: Terraform State Lock

**Symptom**: `Error acquiring the state lock`

**Solution**:
```bash
# Check HCP Terraform workspace for active runs
# Cancel stale run via HCP Terraform UI
# Or force-unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

---

## Next Steps

### Production Readiness
- [ ] Replace self-signed certificate with valid certificate (Let's Encrypt or ACM DNS validation)
- [ ] Enable ALB access logs for monitoring
- [ ] Set up CloudWatch alarms for health checks and 5xx errors
- [ ] Enable Auto Scaling for dynamic capacity
- [ ] Implement blue-green deployment strategy
- [ ] Add AWS WAF for application firewall
- [ ] Configure VPC Flow Logs for network monitoring
- [ ] Set up SSM Session Manager for secure instance access

### Cost Optimization
- [ ] Consider Reserved Instances for long-term deployments
- [ ] Review CloudWatch retention policies
- [ ] Optimize ALB idle timeout for your workload
- [ ] Enable S3 lifecycle policies for ALB logs

### Monitoring & Operations
- [ ] Set up CloudWatch dashboard for key metrics
- [ ] Configure SNS notifications for alarms
- [ ] Implement log aggregation (CloudWatch Logs Insights)
- [ ] Document runbook for common operational tasks

---

## Resources

- **Specification**: [spec.md](./spec.md)
- **Architecture Design**: [data-model.md](./data-model.md)
- **Research & Decisions**: [research.md](./research.md)
- **Terraform Docs**: [terraform.io/docs](https://www.terraform.io/docs)
- **AWS ALB Docs**: [AWS Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- **Nginx Docs**: [nginx.org/en/docs](https://nginx.org/en/docs/)

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Terraform plan output for errors
3. Check HCP Terraform run logs
4. Consult AWS CloudWatch logs
5. Contact DevOps team with:
   - Feature: 002-ec2-alb-nginx
   - Branch: 002-ec2-alb-nginx
   - Error messages and logs

---

**Quickstart Complete**: Infrastructure deployed and validated. You now have a working HTTPS web application with high availability! 🎉
