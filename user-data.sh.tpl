#!/bin/bash
# User-data script for Public EC2 Instance with Password Authentication
# Feature: 001-public-ec2-password-auth
# Execution log: /var/log/user-data.log

# Redirect all output to log file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

set -e

echo "========================================="
echo "Starting user-data script execution"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="

# =============================================================================
# Step 1: Update system packages
# =============================================================================
echo "[STEP 1] Updating system packages..."
apt-get update -y
apt-get upgrade -y
echo "[STEP 1] ✓ System packages updated"

# =============================================================================
# Step 2: Create devuser account
# =============================================================================
echo "[STEP 2] Creating devuser account..."
if useradd -m -s /bin/bash devuser; then
    echo "[STEP 2] ✓ devuser account created"
else
    echo "[STEP 2] ✗ ERROR: Failed to create devuser (exit code: $?)"
    exit 1
fi

# =============================================================================
# Step 3: Set password for devuser
# =============================================================================
echo "[STEP 3] Setting password for devuser..."
if echo "devuser:${devuser_password}" | chpasswd; then
    echo "[STEP 3] ✓ Password set successfully"
else
    echo "[STEP 3] ✗ ERROR: Failed to set password (exit code: $?)"
    exit 2
fi

# =============================================================================
# Step 4: Add devuser to sudo group
# =============================================================================
echo "[STEP 4] Adding devuser to sudo group..."
if usermod -aG sudo devuser; then
    echo "[STEP 4] ✓ devuser added to sudo group"
else
    echo "[STEP 4] ✗ ERROR: Failed to add to sudo group (exit code: $?)"
    exit 3
fi

# =============================================================================
# Step 5: Configure sudo access
# =============================================================================
echo "[STEP 5] Configuring sudo access..."
echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
chmod 0440 /etc/sudoers.d/devuser
echo "[STEP 5] ✓ Sudo access configured"

# =============================================================================
# Step 6: Configure SSH for password authentication
# =============================================================================
echo "[STEP 6] Configuring SSH for password authentication..."

# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Enable password authentication
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config

# Restart SSH service
if systemctl restart sshd; then
    echo "[STEP 6] ✓ SSH configured and restarted"
else
    echo "[STEP 6] ✗ ERROR: Failed to restart SSH (exit code: $?)"
    exit 4
fi

# =============================================================================
# Step 7: Install CloudWatch Agent
# =============================================================================
echo "[STEP 7] Installing CloudWatch Agent..."

# Download CloudWatch Agent
wget -q https://s3.${aws_region}.amazonaws.com/amazoncloudwatch-agent-${aws_region}/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb

if dpkg -i -E /tmp/amazon-cloudwatch-agent.deb; then
    echo "[STEP 7] ✓ CloudWatch Agent installed"
else
    echo "[STEP 7] ✗ ERROR: Failed to install CloudWatch Agent (exit code: $?)"
    exit 5
fi

# =============================================================================
# Step 8: Configure CloudWatch Agent
# =============================================================================
echo "[STEP 8] Configuring CloudWatch Agent..."

# Get instance ID
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)

# Create CloudWatch Agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "$INSTANCE_ID",
            "timezone": "UTC",
            "timestamp_format": "%b %d %H:%M:%S"
          }
        ]
      }
    }
  }
}
EOF

echo "[STEP 8] ✓ CloudWatch Agent configured"

# =============================================================================
# Step 9: Start CloudWatch Agent
# =============================================================================
echo "[STEP 9] Starting CloudWatch Agent..."

if /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json; then
    echo "[STEP 9] ✓ CloudWatch Agent started"
else
    echo "[STEP 9] ✗ ERROR: Failed to start CloudWatch Agent (exit code: $?)"
    exit 6
fi

# =============================================================================
# Step 10: Verify CloudWatch Agent status
# =============================================================================
echo "[STEP 10] Verifying CloudWatch Agent status..."
sleep 5

if systemctl is-active --quiet amazon-cloudwatch-agent; then
    echo "[STEP 10] ✓ CloudWatch Agent is running"
else
    echo "[STEP 10] ⚠ WARNING: CloudWatch Agent may not be running properly"
fi

# =============================================================================
# Completion
# =============================================================================
echo "========================================="
echo "User-data script completed successfully"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""
echo "Instance is ready for SSH access:"
echo "  Username: devuser"
echo "  Authentication: Password (retrieve from HCP Terraform workspace)"
echo "  CloudWatch Logs: ${log_group_name}"
echo ""
echo "⚠ SECURITY WARNING: This instance uses password authentication for development only."
echo ""
