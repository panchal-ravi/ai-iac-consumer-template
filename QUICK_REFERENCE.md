# Quick Reference: Supporting Files

## Files Created

### 1. user-data.sh
**Location**: `/workspace/user-data.sh`  
**Purpose**: EC2 initialization script for Nginx installation  
**Usage**: Referenced in EC2 module via `user_data = file("${path.root}/user-data.sh")`

**Key Features**:
- ✅ Idempotent (safe to run multiple times)
- ✅ Amazon Linux 2023 compatible
- ✅ Installs and configures Nginx
- ✅ Creates modern HTML test page with instance metadata
- ✅ Health check endpoint at root path `/`
- ✅ Comprehensive logging to `/var/log/user-data.log`

**Testing the Script Locally** (optional):
```bash
# Syntax check
bash -n user-data.sh

# Dry-run on Amazon Linux 2023 instance
sudo bash -x user-data.sh
```

---

### 2. IMPLEMENTATION.md
**Location**: `/workspace/IMPLEMENTATION.md`  
**Purpose**: Comprehensive implementation documentation  
**Sections**:
- Design decisions & rationale
- Module selection (EC2, ALB, Security Groups)
- Security posture (development environment)
- Testing procedures & validation
- Known limitations & production fixes
- Cost breakdown ($32.94/month)
- Troubleshooting guide

**When to Use**:
- Review before starting implementation
- Reference during development
- Share with team for knowledge transfer
- Update after deployment with actual results

---

### 3. .gitignore
**Location**: `/workspace/.gitignore`  
**Status**: ✅ Already exists and is comprehensive  
**No changes needed** - All required Terraform patterns already present

**Patterns Covered**:
- `.terraform/` directory
- `*.tfstate` and backups
- `*.tfvars` (excludes `*.auto.tfvars` for environment configs)
- `override.tf` files
- `crash.log` files
- Sensitive files (`.env`, secrets, credentials)

**Note**: `.terraform.lock.hcl` is **NOT** excluded (correct behavior - should be committed)

---

## Integration with Terraform

### Referencing user-data.sh

In your `main.tf` file, reference the user data script in EC2 module calls:

```hcl
module "ec2_instance_1" {
  source  = "ravi-panchal-org/ec2-instance/aws"
  version = "6.1.4"
  
  # ... other configuration ...
  
  user_data                  = file("${path.root}/user-data.sh")
  user_data_replace_on_change = true
  
  # ... remaining configuration ...
}
```

**Important Notes**:
- Use `file()` function to read the script content
- Use `${path.root}` to reference the repository root
- Set `user_data_replace_on_change = true` if you want instances to be replaced when the script changes
- The script will run once at instance launch

---

## HTML Test Page Preview

The user-data script creates a beautiful HTML page accessible via the ALB:

**URL**: `https://<alb-dns-name>/`

**Page Content**:
```
🚀 Web Demo - Nginx on AWS
✓ Service Healthy

Instance Metadata:
- Instance ID: i-xxxxx
- Availability Zone: ap-southeast-1a/1b
- Instance Type: t3.micro
- Private IP: 10.x.x.x
- Public IP: x.x.x.x
```

**Design**: Modern glassmorphism with gradient background

---

## Health Check Endpoints

The Nginx server provides multiple endpoints:

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `GET /` | Main test page | HTML page with metadata |
| `GET /health` | Health check (for ALB) | "healthy" (text/plain) |
| `GET /nginx_status` | Nginx stats | Status page (localhost only) |

**ALB Health Check Configuration**:
- Path: `/`
- Protocol: HTTP
- Port: 80
- Expected: 200 OK

---

## Verification Commands

### After Deployment

**1. Check HTTPS Endpoint**:
```bash
curl -k https://<alb-dns-name>/
# Should return HTML page with "Web Demo - Nginx on AWS"
```

**2. Verify TLS Certificate**:
```bash
openssl s_client -connect <alb-dns>:443 -servername web.demo.com
# Should show certificate with CN=web.demo.com
```

**3. Check Target Health**:
```bash
aws elbv2 describe-target-health \
  --target-group-arn <arn> \
  --region ap-southeast-1
# Both targets should show "healthy"
```

**4. Verify Direct EC2 Access is Blocked**:
```bash
curl --max-time 10 http://<ec2-public-ip>
# Should timeout or refuse connection
```

**5. Check User Data Logs on EC2**:
```bash
# Connect via AWS Systems Manager Session Manager or EC2 Instance Connect
sudo cat /var/log/user-data.log
# Should show successful Nginx installation

# Check if initialization completed
cat /var/log/user-data-success
# Should show completion timestamp
```

---

## Troubleshooting

### Issue: Nginx Not Running

**Check**:
```bash
# On EC2 instance
sudo systemctl status nginx
sudo journalctl -u nginx -n 50
```

**Fix**:
```bash
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Issue: Health Checks Failing

**Check**:
```bash
# On EC2 instance
curl http://localhost/
# Should return HTML page

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <sg-id> \
  --region ap-southeast-1
```

**Fix**:
- Verify Nginx is running
- Check security group allows ALB → EC2 on port 80
- Verify health check path `/` is accessible

### Issue: User Data Script Failed

**Check**:
```bash
# On EC2 instance
sudo cat /var/log/user-data.log
# Look for error messages

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log
```

**Fix**:
- Review error messages in logs
- Manually run commands from user-data.sh
- Check for network connectivity issues (dnf update)

---

## Cost Breakdown

**Monthly Estimate**: $32.94 (34% under $50 budget)

| Resource | Quantity | Monthly Cost |
|----------|----------|--------------|
| EC2 t3.micro | 2 | $15.18 |
| Application Load Balancer | 1 | $16.20 |
| EBS GP3 (8 GB) | 2 | $0.16 |
| Data Transfer | 10 GB | $1.20 |
| ALB Data Processing | 25 GB | $0.20 |
| **Total** | | **$32.94** |

---

## Next Steps

1. ✅ **Supporting files created** (user-data.sh, IMPLEMENTATION.md)
2. ✅ **.gitignore verified** (comprehensive, no changes needed)
3. → **Begin Terraform implementation** (follow tasks.md)
4. → **Reference user-data.sh in EC2 modules** (Tasks T015, T019)
5. → **Deploy infrastructure** (terraform apply)
6. → **Validate deployment** (follow quickstart.md)
7. → **Update IMPLEMENTATION.md** with actual results

---

## Related Documentation

- **Specification**: `/workspace/specs/001-ec2-alb-nginx/spec.md`
- **Implementation Plan**: `/workspace/specs/001-ec2-alb-nginx/plan.md`
- **Research Notes**: `/workspace/specs/001-ec2-alb-nginx/research.md`
- **Task List**: `/workspace/specs/001-ec2-alb-nginx/tasks.md`
- **Quick Start**: `/workspace/specs/001-ec2-alb-nginx/quickstart.md`
- **API Contracts**: `/workspace/specs/001-ec2-alb-nginx/contracts/`

---

**Last Updated**: 2025-02-01  
**Status**: Ready for Implementation ✅
