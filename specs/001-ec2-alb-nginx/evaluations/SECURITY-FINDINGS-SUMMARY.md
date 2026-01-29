# Security Findings - Quick Reference

**Infrastructure**: EC2 ALB Nginx Development Environment  
**Date**: 2025-01-29  
**Overall Risk**: MEDIUM (acceptable for dev with mitigations)

---

## Critical Priority Actions

### 🔴 P0-1: Self-Signed TLS Certificate (CRITICAL)
- **Risk**: Man-in-the-middle attacks, compliance violations
- **Fix**: Replace with ACM certificate using DNS validation
- **Effort**: 2-3 hours
- **Code Location**: `specs/001-ec2-alb-nginx/plan.md:142-172`

### 🟠 P1-1: Unrestricted Public Access (HIGH)
- **Risk**: DDoS, brute-force attacks, unnecessary exposure
- **Fix**: Implement IP allowlist (replace 0.0.0.0/0)
- **Effort**: 30 minutes
- **Code Location**: `specs/001-ec2-alb-nginx/plan.md:489-504`

---

## Medium Priority Enhancements

### 🟡 P2-1: Missing ALB Access Logs
- **Fix**: Enable logging to S3 with 30-day lifecycle
- **Cost**: ~$1-2/month
- **Effort**: 15-20 minutes

### 🟡 P2-2: EC2 Public IPs
- **Fix**: Remove public IPs + deploy VPC endpoints OR enforce IMDSv2
- **Cost**: $22/month (VPC endpoints) or $0 (IMDSv2 only)
- **Effort**: 1-2 hours (endpoints) or 15 min (IMDSv2)

### 🟡 P2-3: Default VPC Usage
- **Status**: ACCEPTED for development
- **Future**: Migrate to dedicated VPC for production
- **Effort**: N/A (documentation only for dev)

---

## Low Priority Improvements

### 🔵 P3-1: CloudWatch Alarms
- **Fix**: Add alarms for unhealthy targets, 5xx errors, status checks
- **Effort**: 30 minutes

### 🔵 P3-2: Tag Enforcement
- **Fix**: Add Terraform validation for required tags
- **Effort**: 20 minutes

---

## Security Strengths to Maintain

✅ IAM least privilege (AmazonSSMManagedInstanceCore)  
✅ Network segmentation (EC2 only from ALB)  
✅ No SSH access (Systems Manager only)  
✅ HTTP→HTTPS redirect enforced  
✅ Multi-AZ deployment

---

## Quick Action Checklist

**Before Deployment:**
- [ ] Replace self-signed cert with ACM certificate
- [ ] Add IP allowlist to ALB security group
- [ ] Enable ALB access logs to S3

**Within Current Sprint:**
- [ ] Remove EC2 public IPs or enforce IMDSv2
- [ ] Configure CloudWatch alarms
- [ ] Enable tag validation

**Backlog:**
- [ ] Plan dedicated VPC for production
- [ ] Evaluate AWS WAF for production
- [ ] Implement GuardDuty

---

For detailed findings with code examples and citations, see:
**aws-security-review.md** in this directory.
