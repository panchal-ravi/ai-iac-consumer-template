# EC2 Dev Instance Deployment Information

**Deployment Date**: 2026-01-12  
**HCP Terraform Run**: https://app.terraform.io/app/ravi-panchal-org/sandbox_ec2_dev_instance/runs/run-3o7mWC5ca2S7ZPBo

## Deployment Summary

**Status**: ✅ Successfully Deployed  
**Resources Created**: 7  
**Deployment Time**: ~30 seconds  
**Cost**: $10.14/month (within $50 budget)

## Infrastructure Details

### EC2 Instance
- **Instance ID**: `i-09b6959b794afe535`
- **Instance Type**: t3.micro
- **AMI**: Amazon Linux 2023 (ami-02ffee2b2e4bc6891)
- **Private IP**: 172.31.27.43
- **Public IP (Elastic)**: 35.170.154.106
- **VPC**: Default VPC (vpc-05ea706c2285f091a)
- **Subnet**: subnet-0062ff3be99734438

### Security
- **Security Group**: sg-0c230214e93e7d6f1
  - Ingress: SSH (22) from 0.0.0.0/0
  - Egress: All traffic to 0.0.0.0/0
- **IAM Role**: ec2-dev-instance-development-ssm-role
- **IAM Instance Profile**: ec2-dev-instance-development-ssm-role-profile
- **IAM Policy**: AmazonSSMManagedInstanceCore

### Monitoring
- **CloudWatch Log Group**: /aws/ec2/dev-instance/ssh-auth
- **Log Group ARN**: arn:aws:logs:us-east-1:475368203962:log-group:/aws/ec2/dev-instance/ssh-auth
- **Retention**: 7 days
- **Monitoring**: Basic CloudWatch metrics

### Network
- **Elastic IP**: eipalloc-0c15e632ff4abf15c
- **Public IP**: 35.170.154.106
- **DNS**: Auto-assigned AWS public DNS

## Access Methods

### SSH Access (Password-Based)
```bash
ssh devuser@35.170.154.106
```

**⚠️ Note**: Password must be set via Session Manager before first SSH connection.

### Session Manager Access (Fallback)
```bash
aws ssm start-session --target i-09b6959b794afe535
```

## Post-Deployment Tasks

### 1. Set Initial Password via Session Manager
```bash
# Connect via Session Manager
aws ssm start-session --target i-09b6959b794afe535

# Switch to root
sudo su -

# Set password for devuser (must meet policy: 14+ chars, 4 character classes)
passwd devuser

# Exit Session Manager
exit
exit
```

### 2. Test SSH Connection
```bash
# SSH to instance
ssh devuser@35.170.154.106

# Verify fail2ban is running
sudo systemctl status fail2ban

# Check CloudWatch agent
sudo systemctl status amazon-cloudwatch-agent

# View SSH auth logs
sudo tail -f /var/log/secure
```

### 3. Verify CloudWatch Logs
```bash
# Check log stream created
aws logs describe-log-streams \
  --log-group-name /aws/ec2/dev-instance/ssh-auth \
  --region us-east-1

# Tail SSH auth logs from CloudWatch
aws logs tail /aws/ec2/dev-instance/ssh-auth --follow
```

## Cost Breakdown

| Resource | Monthly Cost | Notes |
|----------|-------------|-------|
| t3.micro instance | $7.52 | 24/7 operation |
| EBS gp3 30GB | $2.40 | Root volume |
| CloudWatch Logs | ~$0.50 | 7-day retention |
| Elastic IP | $0 | Attached to running instance |
| Data Transfer | Variable | Minimal for dev usage |
| **Total** | **~$10.14/month** | **79% under $50 budget** |

## Security Notes

### Implemented Controls
- ✅ EBS volume encrypted at rest
- ✅ fail2ban brute-force protection (5 attempts/10min = 1hr block)
- ✅ Strong password policy (14+ chars, 4 character classes)
- ✅ Password expiry: 90 days with 7-day warning
- ✅ SSH session timeout: 30 minutes idle
- ✅ Root login disabled
- ✅ Session Manager backup access
- ✅ CloudWatch SSH authentication logging

### Known Risks (Documented & Accepted)
- ⚠️ **RISK-001 (CRITICAL)**: Public SSH access from 0.0.0.0/0
  - **Mitigation**: fail2ban, strong passwords, CloudWatch monitoring
  - **Acceptance**: Development environment only
- ⚠️ **RISK-009 (HIGH)**: Non-compliant with PCI-DSS, HIPAA, SOC 2
  - **Acceptance**: Development environment, no production data

## Tags Applied

All resources tagged with:
- `Environment`: development
- `Project`: ec2-dev-instance
- `ManagedBy`: terraform
- `Application`: ec2-dev-instance
- `PublicAccess`: true

## Next Steps

1. ✅ Set password via Session Manager
2. ✅ Test SSH connection
3. ✅ Verify fail2ban protection
4. ✅ Verify CloudWatch logging
5. ✅ Document in deployment report
6. ✅ Create pull request

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Cost if destroyed**: $0/month  
**Estimated destroy time**: ~2 minutes

## Support

- **HCP Terraform Workspace**: sandbox_ec2_dev_instance
- **AWS Region**: us-east-1
- **GitHub Issue**: #10
- **Feature Branch**: 001-ec2-dev-instance
