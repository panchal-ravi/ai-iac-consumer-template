# Terraform Outputs Contract

**Feature**: AWS EC2 Infrastructure with Application Load Balancer and Nginx  
**Date**: 2025-01-13

---

## Output Interface

This document defines the "API contract" for the Terraform module outputs.

### Primary Access Point

```hcl
output "alb_endpoint" {
  value = "https://${module.alb.dns_name}"
}
```

### Key Outputs

- `alb_endpoint`: HTTPS URL for web access
- `ec2_instance_ids`: List of instance IDs  
- `alb_dns_name`: Load balancer DNS
- `security_group_ids`: ALB and EC2 security groups
- `acm_certificate_arn`: Certificate ARN

## Contract Guarantees

1. HTTPS endpoint returns HTTP 200 for healthy backends
2. Multi-AZ deployment for high availability
3. Self-signed certificate valid for 5 years
4. Health checks detect failures within 60 seconds

**Contract Version**: 1.0 ✅
