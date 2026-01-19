# Quick Start: Connecting to Your EC2 Instance

## Overview

This guide provides step-by-step instructions for connecting to your public EC2 instance using SSH with password authentication.

## Prerequisites

- EC2 instance has been provisioned and is running
- You have access to HCP Terraform workspace: `sandbox_public_ec2_dev`
- SSH client installed on your local machine (Linux/Mac: built-in, Windows: OpenSSH or PuTTY)

## Step 1: Get the Instance Public IP

### Via AWS Console:
1. Log in to AWS Console
2. Navigate to EC2 → Instances
3. Find instance with tag matching this feature
4. Copy the **Public IPv4 address** or **Elastic IP**

### Via AWS CLI:
```bash
aws ec2 describe-instances \
  --region ap-southeast-1 \
  --filters "Name=tag:Feature,Values=public-ec2-password-auth" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text
```

## Step 2: Retrieve the Password

### Via HCP Terraform UI:
1. Log in to [HCP Terraform](https://app.terraform.io)
2. Navigate to organization: `ravi-panchal-org`
3. Open workspace: `sandbox_public_ec2_dev`
4. Go to Variables section
5. Find the sensitive variable `instance_password` (or similar name)
6. Click "Show" to reveal the password

### Security Note:
⚠️ Never share or commit the password to version control. Treat it as a secret.

## Step 3: Connect via SSH

### Command Format:
```bash
ssh devuser@<PUBLIC_IP_ADDRESS>
```

### Example:
```bash
ssh devuser@13.250.123.45
```

### First-Time Connection:
When connecting for the first time, you'll see a host key verification prompt:

```
The authenticity of host '13.250.123.45 (13.250.123.45)' can't be established.
ECDSA key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter.

### Enter Password:
When prompted, paste the password retrieved from HCP Terraform:

```
devuser@13.250.123.45's password: [paste password here]
```

**Note**: The password won't be visible as you type - this is normal for security.

## Step 4: Verify Connection

Once connected, you should see a welcome message and command prompt:

```
Welcome to Ubuntu 22.04.3 LTS (GNU/Linux 5.15.0-1045-aws x86_64)
...
devuser@ip-172-31-xx-xx:~$
```

Verify you're connected:

```bash
whoami      # Should show: devuser
hostname    # Shows instance hostname
pwd         # Shows current directory: /home/devuser
```

## Troubleshooting

### Connection Refused
**Symptom**: `ssh: connect to host <IP> port 22: Connection refused`

**Solutions**:
1. Verify instance is running (check AWS Console)
2. Check security group allows SSH from your IP
3. Verify the IP address is correct (use Elastic IP, not dynamic IP)

### Permission Denied
**Symptom**: `Permission denied, please try again.`

**Solutions**:
1. Verify you're using username `devuser` (not `ubuntu`, `ec2-user`, or `root`)
2. Double-check password from HCP Terraform (no extra spaces)
3. Ensure password hasn't been rotated without updating credentials

### Timeout
**Symptom**: `ssh: connect to host <IP> port 22: Connection timed out`

**Solutions**:
1. Check your internet connectivity
2. Verify security group allows SSH (port 22) from `0.0.0.0/0` or your specific IP
3. Confirm instance is in a public subnet with Internet Gateway attached
4. Check Network ACLs aren't blocking traffic

### Host Key Changed Warning
**Symptom**: `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`

**Cause**: Instance was recreated with same IP but different host key

**Solution**:
```bash
ssh-keygen -R <PUBLIC_IP_ADDRESS>
```

Then reconnect with `ssh devuser@<PUBLIC_IP>`

## Advanced Options

### Using SSH with Custom Port (if configured)
```bash
ssh -p <PORT_NUMBER> devuser@<PUBLIC_IP_ADDRESS>
```

### SSH with Verbose Output (debugging)
```bash
ssh -v devuser@<PUBLIC_IP_ADDRESS>
```

### Keep-Alive for Long Sessions
Add to `~/.ssh/config`:

```
Host <PUBLIC_IP_ADDRESS>
    User devuser
    ServerAliveInterval 60
    ServerAliveCountMax 10
```

## Security Reminders

⚠️ **Important Security Notes**:

1. **Password Security**: This instance uses password authentication for development convenience. This is NOT recommended for production.

2. **Open SSH Access**: Security group allows SSH from anywhere (0.0.0.0/0). For production, restrict to specific IPs or VPN.

3. **Password Rotation**: Change the password periodically and update in HCP Terraform.

4. **Monitor Access**: Check CloudWatch Logs for unauthorized access attempts:
   ```bash
   # On the instance
   sudo tail -f /var/log/auth.log    # Ubuntu
   sudo tail -f /var/log/secure       # Amazon Linux
   ```

5. **Development Only**: This configuration is for development/sandbox environments only.

## Cost Management

**Estimated Monthly Cost**: $10-15 USD

To avoid unexpected charges:
- Stop the instance when not in use (Elastic IP charges still apply)
- Terminate the instance and release Elastic IP when done with development
- Monitor AWS Cost Explorer regularly

## Need Help?

If you continue experiencing issues:

1. Check CloudWatch Logs for SSH auth failures
2. Verify all infrastructure was provisioned correctly via HCP Terraform
3. Review security group rules in AWS Console
4. Ensure VPC/subnet/Internet Gateway configuration is correct
5. Contact your cloud administrator or DevOps team

## Quick Reference

| Item | Value |
|------|-------|
| Username | devuser |
| SSH Port | 22 |
| Region | ap-southeast-1 (Singapore) |
| Instance Type | t3.micro |
| OS Options | Amazon Linux 2023 or Ubuntu 22.04 LTS |
| HCP Terraform Org | ravi-panchal-org |
| HCP Terraform Workspace | sandbox_public_ec2_dev |
| Password Location | HCP Terraform workspace sensitive variable |

---

**Last Updated**: 2025-01-21  
**Feature Branch**: 001-public-ec2-password-auth
