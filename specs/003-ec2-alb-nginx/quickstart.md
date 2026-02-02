# Quickstart Guide: EC2 Instance with ALB and Nginx

**Feature**: EC2 ALB Nginx Infrastructure  
**Branch**: `003-ec2-alb-nginx`  
**Deployment Target**: HCP Terraform Cloud  
**Estimated Time**: 15-20 minutes

---

## Prerequisites

### Required Tools

- **Terraform CLI** (v1.6.0+)
  ```bash
  terraform version
  ```

- **AWS CLI** (v2.x)
  ```bash
  aws --version
  ```

- **Git**
  ```bash
  git --version
  ```

### Required Access

- ✅ HCP Terraform Cloud account
- ✅ Access to `ravi-panchal-org` organization
- ✅ Access to `sandbox_workspace` workspace
- ✅ AWS credentials configured in workspace (or IAM role)
- ✅ AWS permissions:
  - EC2: `ec2:*` (instances, security groups, subnets, VPCs)
  - ELB: `elasticloadbalancing:*` (ALBs, target groups, listeners)
  - ACM: `acm:*` (certificate import)
  - IAM: `iam:PassRole` (if EC2 instances need IAM roles)

### Required Knowledge

- Basic Terraform concepts (modules, resources, outputs)
- AWS networking fundamentals (VPCs, subnets, security groups)
- HTTPS/TLS certificate basics
- Basic Linux command line

---

## Quick Start (5 Minutes)

### 1. Clone Repository

```bash
# Clone the repository
git clone <repository-url>
cd <repository-name>

# Checkout feature branch
git checkout 003-ec2-alb-nginx
```

### 2. Configure Terraform Backend

**Option A: Using HCP Terraform Cloud (Recommended)**

The configuration is pre-configured for HCP Terraform:

```hcl
# backend.tf
terraform {
  cloud {
    organization = "ravi-panchal-org"
    workspaces {
      name = "sandbox_workspace"
    }
  }
}
```

**Option B: Using Local State (Development Only)**

If testing locally:

```bash
# Remove cloud backend configuration
rm backend.tf

# Initialize with local state
terraform init
```

### 3. Authenticate to HCP Terraform

```bash
# Login to Terraform Cloud
terraform login

# Follow the prompts to generate and save an API token
```

### 4. Initialize Terraform

```bash
# Initialize Terraform (downloads providers and modules)
terraform init
```

Expected output:
```
Initializing Terraform Cloud...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Finding hashicorp/tls versions matching "~> 4.0"...
Terraform has been successfully initialized!
```

### 5. Deploy Infrastructure

```bash
# Preview changes
terraform plan

# Apply changes (approve when prompted)
terraform apply

# Or auto-approve for CI/CD
terraform apply -auto-approve
```

**Deployment Time**: 5-8 minutes

### 6. Access Your Application

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTPS connectivity (expect certificate warning)
curl -k https://$ALB_DNS

# Or open in browser
echo "https://$ALB_DNS"
```

---

## Detailed Deployment Steps

### Step 1: Review Configuration

#### Required Variables

The configuration uses sensible defaults. Review `variables.tf`:

```hcl
# Default values (can be overridden)
aws_region              = "ap-southeast-1"
project_name            = "web-demo"
environment             = "development"
domain_name             = "web.demo.com"
instance_type           = "t3.micro"
instance_count_per_az   = 1
certificate_validity_days = 90
```

#### Override Variables (Optional)

**Option A: Using `terraform.tfvars`**

```hcl
# terraform.tfvars
instance_type             = "t2.micro"  # If t3.micro unavailable
certificate_validity_days = 180         # Longer validity
```

**Option B: Using Environment Variables**

```bash
export TF_VAR_instance_type="t2.micro"
export TF_VAR_certificate_validity_days=180
```

**Option C: Using HCP Terraform Workspace Variables**

In HCP Terraform UI:
1. Navigate to workspace `sandbox_workspace`
2. Go to Variables section
3. Add Terraform variables:
   - `instance_type` = `t2.micro`
   - `certificate_validity_days` = `180`

---

### Step 2: Validate Configuration

```bash
# Validate Terraform syntax
terraform validate

# Format Terraform files
terraform fmt -recursive

# Check for security issues (optional)
tfsec .
```

Expected output:
```
Success! The configuration is valid.
```

---

### Step 3: Plan Infrastructure Changes

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review plan details
terraform show tfplan
```

**Expected Resources** (approximately):
- 2 EC2 instances
- 1 Application Load Balancer
- 1 Target Group
- 2 Security Groups
- 1 ACM Certificate
- 1 TLS Private Key
- 1 TLS Certificate
- 1 HTTPS Listener
- Various data sources

**Estimated Cost** (ap-southeast-1):
- 2 × t3.micro instances: ~$0.023/hour × 2 = $0.046/hour
- 1 × ALB: ~$0.025/hour
- Data transfer: Variable (estimated $0.01/hour for light testing)
- **Total**: ~$0.08/hour (~$60/month)

---

### Step 4: Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# Or apply directly with approval
terraform apply
```

**Deployment Phases**:
1. **Phase 1 (0-30s)**: Data source queries (VPC, subnets)
2. **Phase 2 (30-90s)**: Security groups, TLS certificate, ACM import
3. **Phase 3 (90-180s)**: ALB creation
4. **Phase 4 (180-360s)**: EC2 instances launch, user data execution
5. **Phase 5 (360-480s)**: Health checks pass, targets registered

**Total Time**: 5-8 minutes

---

### Step 5: Verify Deployment

#### Check Terraform Outputs

```bash
# Display all outputs
terraform output

# Display specific outputs
terraform output alb_dns_name
terraform output ec2_instance_ids
terraform output alb_direct_url
```

#### Verify AWS Resources

```bash
# List EC2 instances
aws ec2 describe-instances \
  --region ap-southeast-1 \
  --filters "Name=tag:Project,Values=web-demo" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress,AvailabilityZone]' \
  --output table

# Check ALB status
aws elbv2 describe-load-balancers \
  --region ap-southeast-1 \
  --names web-demo-development-alb

# Check target group health
TG_ARN=$(terraform output -raw target_group_arn)
aws elbv2 describe-target-health \
  --region ap-southeast-1 \
  --target-group-arn $TG_ARN
```

#### Test Connectivity

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTPS endpoint (expect certificate warning)
curl -k https://$ALB_DNS

# Test with verbose output
curl -kv https://$ALB_DNS

# Test health endpoint directly on instances (should fail - security group blocks)
INSTANCE_IP=$(terraform output -json ec2_instance_private_ips | jq -r '.[0]')
curl --connect-timeout 5 http://$INSTANCE_IP/health  # Should timeout
```

Expected response:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Web Server</title>
</head>
<body>
    <h1>Welcome to web.demo.com</h1>
    <p><strong>Instance ID:</strong> i-0123456789abcdef0</p>
    <p><strong>Availability Zone:</strong> ap-southeast-1a</p>
    <p><strong>Environment:</strong> Development</p>
</body>
</html>
```

---

### Step 6: Configure DNS (Optional)

The self-signed certificate is issued for `web.demo.com`. To access via custom domain:

#### Option A: Route 53 (if you own the domain)

```bash
# Get ALB DNS name and zone ID
ALB_DNS=$(terraform output -raw alb_dns_name)
ALB_ZONE=$(terraform output -raw alb_zone_id)

# Create Route 53 alias record
aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "web.demo.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'$ALB_ZONE'",
          "DNSName": "'$ALB_DNS'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

#### Option B: Local Hosts File (Development/Testing)

**macOS/Linux**:
```bash
# Get ALB IP address (approximate - ALB has multiple IPs)
ALB_IP=$(dig +short $(terraform output -raw alb_dns_name) | head -n 1)

# Add to /etc/hosts
echo "$ALB_IP web.demo.com" | sudo tee -a /etc/hosts

# Test
curl -k https://web.demo.com
```

**Windows**:
```powershell
# Run as Administrator
# Get ALB IP
$ALB_IP = (Resolve-DnsName (terraform output -raw alb_dns_name))[0].IPAddress

# Add to hosts file
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "$ALB_IP web.demo.com"
```

---

## Testing Guide

### 1. Load Balancing Test

Verify traffic is distributed across both instances:

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)

# Make 20 requests and extract instance IDs
for i in {1..20}; do
  curl -sk https://$ALB_DNS | grep "Instance ID" | cut -d ":" -f 2
done | sort | uniq -c
```

Expected output (approximately):
```
  10 i-0123456789abcdef0
  10 i-0123456789abcdef1
```

### 2. Health Check Test

Verify health checks are working:

```bash
TG_ARN=$(terraform output -raw target_group_arn)

# Check target health
aws elbv2 describe-target-health \
  --region ap-southeast-1 \
  --target-group-arn $TG_ARN \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

Expected output:
```
-------------------------------------
|      DescribeTargetHealth        |
+--------------------+--------------+
| i-0123456789abcdef0 | healthy    |
| i-0123456789abcdef1 | healthy    |
+--------------------+--------------+
```

### 3. Failover Test

Simulate instance failure:

```bash
# Get first instance ID
INSTANCE_ID=$(terraform output -json ec2_instance_ids | jq -r '.[0]')

# Stop the instance
aws ec2 stop-instances --region ap-southeast-1 --instance-ids $INSTANCE_ID

# Wait for health check to detect failure (60 seconds)
sleep 70

# Verify traffic still flows (should only hit healthy instance)
for i in {1..10}; do
  curl -sk https://$(terraform output -raw alb_dns_name) | grep "Instance ID"
done

# Start the instance again
aws ec2 start-instances --region ap-southeast-1 --instance-ids $INSTANCE_ID
```

### 4. Security Test

Verify security group isolation:

```bash
# Try to access EC2 instance directly (should fail)
INSTANCE_IP=$(terraform output -json ec2_instance_private_ips | jq -r '.[]' | head -n 1)

# This should timeout (not reachable from internet)
curl --connect-timeout 5 http://$INSTANCE_IP

# Verify ALB only accepts HTTPS (443), not HTTP (80)
curl --connect-timeout 5 http://$(terraform output -raw alb_dns_name)
```

Expected: Both requests should fail/timeout.

### 5. Certificate Test

Verify certificate details:

```bash
# Get certificate information
ALB_DNS=$(terraform output -raw alb_dns_name)

# Display certificate details
openssl s_client -connect $ALB_DNS:443 -showcerts </dev/null 2>/dev/null | \
  openssl x509 -noout -text | grep -A 2 "Subject:"

# Check certificate expiration
terraform output certificate_validity_end
```

---

## Troubleshooting

### Issue: EC2 Instances Not Healthy

**Symptoms**: Targets show "unhealthy" status in target group

**Diagnostic Steps**:
```bash
# Check target health details
TG_ARN=$(terraform output -raw target_group_arn)
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# SSH to instance (if SSH access configured)
INSTANCE_ID=$(terraform output -json ec2_instance_ids | jq -r '.[0]')
aws ssm start-session --target $INSTANCE_ID  # If SSM agent installed

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log

# Check Nginx status
sudo systemctl status nginx

# Test health endpoint locally
curl http://localhost/health
```

**Common Causes**:
- User data script failed → Check `/var/log/cloud-init-output.log`
- Nginx not running → `sudo systemctl start nginx`
- Security group misconfiguration → Verify ALB can reach EC2 on port 80
- Health check path incorrect → Verify `/health` returns 200

---

### Issue: Cannot Access ALB

**Symptoms**: Connection timeout or refused when accessing ALB DNS

**Diagnostic Steps**:
```bash
# Check ALB state
aws elbv2 describe-load-balancers \
  --names web-demo-development-alb \
  --query 'LoadBalancers[0].State'

# Check ALB security group
ALB_SG=$(terraform output -raw alb_security_group_id)
aws ec2 describe-security-groups --group-ids $ALB_SG

# Test DNS resolution
dig $(terraform output -raw alb_dns_name)
```

**Common Causes**:
- ALB still provisioning → Wait 2-3 minutes
- Security group blocking 443 → Verify ingress rule allows 0.0.0.0/0
- No healthy targets → Check target health (see previous section)

---

### Issue: Certificate Errors

**Symptoms**: Browser shows certificate errors beyond expected self-signed warning

**Diagnostic Steps**:
```bash
# Check ACM certificate status
CERT_ARN=$(terraform output -raw acm_certificate_arn)
aws acm describe-certificate --certificate-arn $CERT_ARN

# Check certificate expiration
terraform output certificate_validity_end

# Verify certificate domain
openssl s_client -connect $(terraform output -raw alb_dns_name):443 -showcerts </dev/null 2>/dev/null | \
  openssl x509 -noout -text | grep "Subject:"
```

**Common Causes**:
- Certificate expired → Re-apply Terraform to generate new certificate
- Domain mismatch → Verify accessing correct domain
- Certificate not attached to listener → Check ALB listener configuration

---

### Issue: Terraform Apply Fails

**Common Errors and Solutions**:

#### Error: "Timeout waiting for target to be healthy"
```
Solution: Instances may take longer to bootstrap. Wait additional 2-3 minutes, 
then re-run terraform apply.
```

#### Error: "InsufficientInstanceCapacity"
```
Solution: t3.micro unavailable in selected AZ. 
Override: terraform apply -var="instance_type=t2.micro"
```

#### Error: "Security group circular dependency"
```
Solution: This is expected and handled automatically by Terraform. 
Re-run terraform apply.
```

#### Error: "Default VPC not found"
```
Solution: Create default VPC or modify data sources to use custom VPC.
aws ec2 create-default-vpc --region ap-southeast-1
```

---

## Cleanup

### Destroy Infrastructure

```bash
# Preview resources to be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Or auto-approve for CI/CD
terraform destroy -auto-approve
```

**Destruction Time**: 3-5 minutes

**Cost After Cleanup**: $0 (all resources removed)

### Verify Cleanup

```bash
# Check for remaining EC2 instances
aws ec2 describe-instances \
  --region ap-southeast-1 \
  --filters "Name=tag:Project,Values=web-demo" \
  --query 'Reservations[*].Instances[*].InstanceId'

# Check for remaining ALBs
aws elbv2 describe-load-balancers \
  --region ap-southeast-1 \
  --query 'LoadBalancers[?LoadBalancerName==`web-demo-development-alb`]'

# Check for remaining security groups
aws ec2 describe-security-groups \
  --region ap-southeast-1 \
  --filters "Name=tag:Project,Values=web-demo"
```

Expected: Empty lists (no resources found)

---

## Advanced Usage

### Custom Domain with Valid Certificate

To use a valid Let's Encrypt certificate:

1. **Obtain certificate via Certbot**:
   ```bash
   certbot certonly --manual --preferred-challenges dns -d web.demo.com
   ```

2. **Import to ACM**:
   ```bash
   aws acm import-certificate \
     --certificate fileb:///path/to/certificate.pem \
     --private-key fileb:///path/to/private-key.pem \
     --certificate-chain fileb:///path/to/chain.pem \
     --region ap-southeast-1
   ```

3. **Update Terraform**:
   ```hcl
   # Comment out TLS provider resources
   # resource "tls_private_key" "web" { ... }
   # resource "tls_self_signed_cert" "web" { ... }
   
   # Use existing ACM certificate
   data "aws_acm_certificate" "web" {
     domain   = "web.demo.com"
     statuses = ["ISSUED"]
   }
   ```

### Multi-Environment Deployment

Use Terraform workspaces or separate directories:

```bash
# Create staging environment
terraform workspace new staging
terraform apply -var="environment=staging"

# Switch to production
terraform workspace new production
terraform apply -var="environment=production" -var="instance_type=t3.small"
```

### Auto Scaling (Future Enhancement)

To add auto-scaling:

1. Replace individual `ec2_instances` modules with `aws_autoscaling_group`
2. Configure scaling policies based on CPU or request count
3. Update target group to use auto-scaling group

---

## Next Steps

1. ✅ **Deploy infrastructure** using this guide
2. ✅ **Verify connectivity** and health checks
3. ✅ **Test load balancing** behavior
4. ✅ **Configure DNS** for custom domain
5. ⏭️ **Customize application** (replace Nginx with your app)
6. ⏭️ **Add monitoring** (CloudWatch, alerting)
7. ⏭️ **Implement CI/CD** for automated deployments

---

## Resources

### Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [HCP Terraform Cloud](https://developer.hashicorp.com/terraform/cloud-docs)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Nginx Documentation](https://nginx.org/en/docs/)

### Support
- GitHub Issues: [Create an issue](https://github.com/org/repo/issues)
- Terraform Forum: [discuss.hashicorp.com](https://discuss.hashicorp.com/)
- AWS Support: [AWS Console](https://console.aws.amazon.com/support/)

### Related Guides
- `research.md`: Architecture decisions and module analysis
- `data-model.md`: Entity relationships and data structures
- `contracts/`: API and interface specifications

---

**Guide Version**: 1.0  
**Last Updated**: 2025-01-21  
**Status**: ✅ Ready for use
