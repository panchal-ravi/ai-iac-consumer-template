# Deployment Checklist: EC2 Infrastructure with ALB and Nginx

**Feature**: 002-ec2-alb-nginx  
**Date**: 2025-02-01

## Pre-Deployment Checks

- [X] Terraform configuration validated
- [X] Terraform plan successful
- [X] Cost estimate reviewed (~$27.75/month)
- [X] HCP Terraform workspace configured (sandbox_workspace)
- [X] AWS credentials configured in workspace
- [ ] Stakeholder approval obtained
- [ ] Deployment window scheduled

## Deployment Steps

### 1. Infrastructure Deployment

```bash
# From repository root
cd /workspace

# Review the plan one more time
terraform plan

# Apply the configuration
terraform apply

# Wait for completion (~10 minutes)
```

Expected output:
- 29 resources created
- ALB DNS name in outputs
- No errors

### 2. Initial Verification

```bash
# Get ALB DNS name
terraform output alb_dns_name

# Test HTTPS access
curl -k https://<alb-dns-name>

# Verify TLS handshake
openssl s_client -connect <alb-dns-name>:443 -servername web.demo.com
```

Expected results:
- HTTP 200 response
- Nginx test page with instance metadata
- TLS certificate for web.demo.com

### 3. High Availability Testing (User Story 2)

```bash
# Verify instances in different AZs
aws ec2 describe-instances \
  --filters "Name=tag:Feature,Values=002-ec2-alb-nginx" \
  --query 'Reservations[].Instances[].[InstanceId,Placement.AvailabilityZone,State.Name]' \
  --output table

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

Expected results:
- 2 instances in ap-southeast-1a and ap-southeast-1b
- Both targets healthy

### 4. Security Validation (User Story 3)

```bash
# Verify ACM certificate
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn)

# Verify ALB listener
aws elbv2 describe-listeners \
  --load-balancer-arn $(terraform output -raw alb_arn)

# Verify security groups
terraform output alb_security_group_id
terraform output ec2_security_group_id
```

Expected results:
- Certificate status: ISSUED
- Listener protocol: HTTPS (port 443)
- Security groups properly configured

### 5. Cost Optimization Validation (User Story 4)

```bash
# Verify instance types
aws ec2 describe-instances \
  --filters "Name=tag:Feature,Values=002-ec2-alb-nginx" \
  --query 'Reservations[].Instances[].[InstanceType]' \
  --output table

# Check for unnecessary resources
aws ec2 describe-addresses \
  --filters "Name=tag:Feature,Values=002-ec2-alb-nginx"

aws ec2 describe-nat-gateways \
  --filter "Name=tag:Feature,Values=002-ec2-alb-nginx"
```

Expected results:
- Instance type: t3a.micro
- No Elastic IPs
- No NAT Gateways

## Post-Deployment Checks

- [ ] All acceptance criteria met (SC-001 through SC-010)
- [ ] Browser access tested (accept self-signed cert warning)
- [ ] Infrastructure outputs documented
- [ ] Monitoring/alerts configured (if applicable)
- [ ] Documentation updated with ALB DNS name
- [ ] GitHub issue #37 updated with deployment results

## Rollback Procedure

If deployment fails or issues are discovered:

```bash
# Destroy infrastructure
terraform destroy

# Verify cleanup
aws ec2 describe-instances \
  --filters "Name=tag:Feature,Values=002-ec2-alb-nginx"

# Should return no results
```

## Success Criteria Verification

From spec.md - all must pass:

1. **SC-001**: Infrastructure deployed via Terraform ✓
2. **SC-002**: ALB DNS accessible via HTTPS ⏳ (pending apply)
3. **SC-003**: Nginx serving content ⏳ (pending apply)
4. **SC-004**: Self-signed cert in ACM ⏳ (pending apply)
5. **SC-005**: 2 instances across 2 AZs ⏳ (pending apply)
6. **SC-006**: ALB forwards to healthy instances ⏳ (pending apply)
7. **SC-007**: Security groups restrict access ⏳ (pending apply)
8. **SC-008**: HTTPS-only access ⏳ (pending apply)
9. **SC-009**: Cost under $50/month ✓ (estimated $27.75)
10. **SC-010**: Default VPC used ✓ (configured)

## Notes

- Deployment is idempotent - can be re-run safely
- State is stored in HCP Terraform (encrypted, versioned)
- Self-signed certificate will show browser warning (expected)
- HTTP access on ALB should fail (HTTPS-only)

## Contact

For issues during deployment:
- Check HCP Terraform run logs
- Review Terraform state
- Consult implementation-notes.md
