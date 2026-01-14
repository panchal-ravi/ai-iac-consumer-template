# User Data Script Contract

**Feature**: Public EC2 Development Instance  
**Version**: 1.0.0  
**Date**: 2025-01-17

## Purpose

This contract defines the user data script executed at EC2 instance launch. The script configures password-based SSH authentication, creates the devuser account, and sets up the CloudWatch Logs agent for system log streaming.

## Script Specification

### Execution Context

- **Trigger**: Executed once at first instance boot
- **Runtime**: Bash shell (`#!/bin/bash`)
- **User**: `root` (user data scripts run as root by default)
- **Working Directory**: `/root`
- **Environment**: Amazon Linux 2023, pre-installed packages available
- **Timeout**: No explicit timeout (should complete within 5 minutes per spec)

### Prerequisites

The following must be true before script execution:

- EC2 instance has reached 'running' state
- CloudWatch Logs log group `/aws/ec2/sandbox_public_ec2_dev` exists
- IAM instance profile attached with CloudWatchAgentServerPolicy
- Network connectivity to AWS APIs (CloudWatch Logs, SSM)
- CloudWatch agent package pre-installed on Amazon Linux 2023

## Script Contract

### Inputs

**Environment Variables** (injected by Terraform via templatefile):

```hcl
{
  PASSWORD = random_password.devuser.result  # 16-char generated password
}
```

**Template Syntax**:
```bash
echo "devuser:${PASSWORD}" | chpasswd
```

### Outputs

**Exit Codes**:
- `0`: Success (all operations completed)
- `non-zero`: Failure (script will continue due to `|| true` on non-critical commands)

**Log Files**:
- `/var/log/user-data.log`: Combined stdout/stderr from user data execution
- `/var/log/cloud-init-output.log`: Cloud-init wrapper logs (system-managed)

**System Changes**:
- User account `devuser` created in `/home/devuser`
- `/etc/ssh/sshd_config` modified to enable password authentication
- `/opt/aws/amazon-cloudwatch-agent/etc/config.json` created
- CloudWatch agent service started and enabled

**CloudWatch Integration**:
- Log stream created: `{instance_id}` within log group `/aws/ec2/sandbox_public_ec2_dev`
- System logs from `/var/log/messages` streamed to CloudWatch

### Functional Requirements

#### FR-1: Error Handling and Logging

**Requirement**: Script must capture all output for troubleshooting

**Implementation**:
```bash
#!/bin/bash
set -e  # Exit on error (unless || true is used)
exec > >(tee /var/log/user-data.log) 2>&1  # Redirect stdout/stderr to log file
```

**Validation**:
- Log file `/var/log/user-data.log` exists after execution
- Contains timestamps and all command output
- Readable by root user only (permissions 600)

---

#### FR-2: Create devuser Account

**Requirement**: System must create a user account named `devuser` with home directory and bash shell

**Implementation**:
```bash
# Create user with home directory and bash shell
useradd -m -s /bin/bash devuser || true
```

**Idempotency**:
- `|| true` prevents script failure if user already exists
- Re-running script will not recreate user (idempotent)

**Validation**:
- User exists: `id devuser` returns success
- Home directory exists: `/home/devuser` directory present
- Shell configured: `getent passwd devuser | cut -d: -f7` returns `/bin/bash`

---

#### FR-3: Set devuser Password

**Requirement**: System must set the devuser password to the generated value from Terraform

**Implementation**:
```bash
# Set password from Terraform variable
echo "devuser:${PASSWORD}" | chpasswd
```

**Security Considerations**:
- Password passed via template interpolation (not visible in process list)
- `chpasswd` is idempotent (can be re-run safely)
- Password not logged in plaintext

**Validation**:
- Password authentication succeeds: `ssh devuser@localhost` with password succeeds
- Shadow file updated: `sudo grep devuser /etc/shadow` shows encrypted password

---

#### FR-4: Enable SSH Password Authentication

**Requirement**: SSH daemon must accept password-based authentication

**Implementation**:
```bash
# Enable password authentication in SSH config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Ensure no conflicting settings
grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config || \
  echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
```

**Validation**:
- SSH config contains: `PasswordAuthentication yes` (uncommented)
- SSH config validation: `sshd -t` returns success
- SSH daemon reloads configuration without errors

---

#### FR-5: Restart SSH Service

**Requirement**: SSH daemon must reload configuration to apply password authentication changes

**Implementation**:
```bash
# Restart SSH daemon to apply configuration changes
systemctl restart sshd
```

**Validation**:
- SSH service is active: `systemctl is-active sshd` returns `active`
- SSH service accepts connections: `nc -zv localhost 22` succeeds
- Password authentication enabled: `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no devuser@localhost` prompts for password

---

#### FR-6: Configure CloudWatch Agent

**Requirement**: CloudWatch agent must be configured to stream `/var/log/messages` to CloudWatch Logs

**Implementation**:
```bash
# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/sandbox_public_ec2_dev",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF
```

**Configuration Details**:
- `file_path`: System log file to monitor
- `log_group_name`: Target CloudWatch log group (must pre-exist)
- `log_stream_name`: `{instance_id}` is auto-replaced by agent with EC2 instance ID

**Validation**:
- Config file exists: `/opt/aws/amazon-cloudwatch-agent/etc/config.json`
- Config is valid JSON: `jq . /opt/aws/amazon-cloudwatch-agent/etc/config.json`
- Log group exists in CloudWatch: `aws logs describe-log-groups --log-group-name-prefix /aws/ec2/sandbox_public_ec2_dev`

---

#### FR-7: Start CloudWatch Agent

**Requirement**: CloudWatch agent must start and begin streaming logs to CloudWatch

**Implementation**:
```bash
# Start CloudWatch agent with configuration
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

**Command Flags**:
- `-a fetch-config`: Load configuration from file
- `-m ec2`: Run in EC2 mode
- `-s`: Start the agent
- `-c file:/path`: Configuration file path

**Validation**:
- Agent is running: `systemctl is-active amazon-cloudwatch-agent` returns `active`
- Agent has no errors: Check `/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log`
- Logs streaming: Verify log stream `{instance_id}` exists in CloudWatch log group
- Logs visible: `aws logs tail /aws/ec2/sandbox_public_ec2_dev --follow` shows recent messages

---

## Complete User Data Script

```bash
#!/bin/bash
# User Data Script for Public EC2 Development Instance
# Purpose: Configure password authentication and CloudWatch Logs agent
# FR-001, FR-010: Enable SSH password auth and create devuser
# FR-012: Integrate with CloudWatch Logs

set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting user data script execution ==="
echo "Timestamp: $(date)"

# FR-001, FR-002: Create devuser account
echo "Creating devuser account..."
useradd -m -s /bin/bash devuser || true

# FR-003: Set devuser password from Terraform
echo "Setting devuser password..."
echo "devuser:${PASSWORD}" | chpasswd

# FR-004: Enable SSH password authentication
echo "Configuring SSH password authentication..."
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config || \
  echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

# FR-005: Restart SSH daemon
echo "Restarting SSH daemon..."
systemctl restart sshd

# FR-006: Configure CloudWatch agent
echo "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/sandbox_public_ec2_dev",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# FR-007: Start CloudWatch agent
echo "Starting CloudWatch agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "=== User data script completed successfully ==="
echo "Timestamp: $(date)"
echo "SSH access: ssh devuser@$(ec2-metadata --public-ipv4 | cut -d' ' -f2)"
echo "CloudWatch Logs: aws logs tail /aws/ec2/sandbox_public_ec2_dev --follow"
```

## Terraform Integration

### User Data Template

**File**: `user_data.sh.tftpl`

```bash
#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting user data script execution ==="

useradd -m -s /bin/bash devuser || true
echo "devuser:${password}" | chpasswd

sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config || \
  echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

systemctl restart sshd

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/sandbox_public_ec2_dev",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "=== User data script completed successfully ==="
```

### Terraform Module Configuration

```hcl
# main.tf

locals {
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    password = random_password.devuser.result
  })
}

module "ec2_instance" {
  source = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"

  user_data = local.user_data
  user_data_replace_on_change = false  # Don't recreate instance on user data changes
  
  # Other configuration...
}
```

## Testing and Validation

### Unit Tests

```bash
# Test 1: Verify devuser exists
id devuser || exit 1

# Test 2: Verify devuser has home directory
[ -d /home/devuser ] || exit 1

# Test 3: Verify SSH password authentication is enabled
grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config || exit 1

# Test 4: Verify SSH daemon is running
systemctl is-active --quiet sshd || exit 1

# Test 5: Verify CloudWatch agent is running
systemctl is-active --quiet amazon-cloudwatch-agent || exit 1

# Test 6: Verify CloudWatch config exists
[ -f /opt/aws/amazon-cloudwatch-agent/etc/config.json ] || exit 1

# Test 7: Verify user data log exists
[ -f /var/log/user-data.log ] || exit 1
```

### Integration Tests

```bash
# Test 1: SSH connection with password
sshpass -p "${SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no devuser@${INSTANCE_IP} 'echo success'

# Test 2: CloudWatch log stream exists
aws logs describe-log-streams \
  --log-group-name /aws/ec2/sandbox_public_ec2_dev \
  --log-stream-name-prefix ${INSTANCE_ID} \
  --query 'logStreams[0].logStreamName' \
  --output text

# Test 3: Recent logs are being streamed
aws logs get-log-events \
  --log-group-name /aws/ec2/sandbox_public_ec2_dev \
  --log-stream-name ${INSTANCE_ID} \
  --limit 10
```

## Error Scenarios and Recovery

### Scenario 1: User Data Script Fails

**Symptoms**:
- SSH password authentication doesn't work
- CloudWatch logs not appearing
- User data log shows errors

**Diagnosis**:
```bash
# Check user data log
ssh -i keypair.pem ec2-user@${INSTANCE_IP} 'sudo cat /var/log/user-data.log'

# Check cloud-init logs
ssh -i keypair.pem ec2-user@${INSTANCE_IP} 'sudo cat /var/log/cloud-init-output.log'
```

**Recovery**:
1. Access instance via AWS Systems Manager Session Manager
2. Manually run failed commands from user data script
3. Verify each step with unit tests above

### Scenario 2: CloudWatch Agent Fails to Start

**Symptoms**:
- No log stream created in CloudWatch
- Agent status shows inactive

**Diagnosis**:
```bash
# Check agent status
systemctl status amazon-cloudwatch-agent

# Check agent logs
cat /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

**Recovery**:
```bash
# Restart agent manually
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

### Scenario 3: SSH Daemon Won't Restart

**Symptoms**:
- `systemctl restart sshd` fails
- SSH connections drop and don't recover

**Diagnosis**:
```bash
# Validate SSH config syntax
sshd -t

# Check SSH daemon logs
journalctl -u sshd -n 50
```

**Recovery**:
1. Access via AWS Systems Manager Session Manager
2. Fix sshd_config syntax errors
3. Restart SSH daemon: `systemctl restart sshd`

## Security Considerations

### Password Handling

- Password never logged in plaintext
- Password passed via Terraform variable (not command line)
- User data script redacts password from process list (echo via pipe to chpasswd)
- Development environment only (not production-grade)

### SSH Configuration

- Password authentication enabled for development convenience
- Production environments should use key-based authentication
- Consider IP whitelisting for production (not 0.0.0.0/0)

### IAM Permissions

- Instance profile limited to CloudWatchAgentServerPolicy
- Least privilege: Only log/metric permissions, no data access
- No credentials stored on instance

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-17 | Initial contract definition |

## Related Contracts

- [terraform-outputs-contract.md](./terraform-outputs-contract.md) - Terraform outputs including password
- [cloudwatch-logs-contract.md](./cloudwatch-logs-contract.md) - CloudWatch Logs integration contract
