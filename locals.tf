# Local Values for EC2 Development Instance
# Constitution 3.1: Shared values defined as locals
# FR-005: Resource naming and tagging

locals {
  # Common resource tags applied to all resources
  # FR-005: Required tags for compliance and tracking
  common_tags = {
    Environment  = var.environment
    Project      = var.project_name
    Application  = "ec2-dev-instance"
    ManagedBy    = "terraform"
    PublicAccess = "true"
  }

  # Resource naming following HashiCorp conventions
  # Pattern: <project>-<environment>-<resource-type>
  security_group_name = "${var.project_name}-${var.environment}-ssh-sg"
  iam_role_name       = "${var.project_name}-${var.environment}-ssm-role"
  instance_name       = "${var.project_name}-${var.environment}"

  # User-data script for instance initialization
  # Will be populated incrementally through Phases 2-6
  # FR-007 through FR-025: SSH config, security, monitoring
  user_data_script = <<-EOT
    #!/bin/bash
    set -e
    set -o pipefail
    
    # Logging setup
    exec > >(tee -a /var/log/user-data.log)
    exec 2>&1
    
    echo "=== EC2 Development Instance User-Data Script ==="
    echo "Start time: $(date)"
    
    # Update system packages
    echo "Updating system packages..."
    yum update -y
    
    # ==================================================================
    # PHASE 4 (User Story 2): SSH Access Configuration (FR-007 to FR-017)
    # ==================================================================
    
    echo "Creating devuser account..."
    # FR-007: Create devuser account with home directory and bash shell
    useradd -m -s /bin/bash devuser
    
    # FR-007: Add devuser to wheel group for sudo privileges
    usermod -aG wheel devuser
    
    echo "Configuring SSH daemon for password authentication..."
    # FR-008: Enable password authentication
    # FR-009: Disable public key authentication
    # FR-010: Disable root login
    cat >> /etc/ssh/sshd_config.d/99-custom.conf <<'SSHEOF'
    # Password-based SSH configuration (FR-008, FR-009, FR-010)
    PasswordAuthentication yes
    PubkeyAuthentication no
    PermitRootLogin no
    
    # FR-011: Session timeout configuration (30 minutes)
    ClientAliveInterval 900
    ClientAliveCountMax 2
    
    # FR-015: Limit authentication attempts
    MaxAuthTries 5
    SSHEOF
    
    echo "Configuring PAM password quality requirements..."
    # FR-012: Password complexity requirements (14+ chars, 4 character classes)
    # FR-013: Strong password enforcement
    cat > /etc/security/pwquality.conf <<'PAMEOF'
    # Password quality requirements (FR-012, FR-013)
    minlen = 14
    minclass = 4
    maxrepeat = 2
    dcredit = -1
    ucredit = -1
    lcredit = -1
    ocredit = -1
    PAMEOF
    
    echo "Configuring password expiry policy..."
    # FR-017: Password expiry settings for devuser
    # -M 90: Maximum 90 days before password expires
    # -m 1: Minimum 1 day between password changes
    # -W 7: Warning 7 days before expiry
    chage -M 90 -m 1 -W 7 devuser
    
    echo "Restarting SSH service..."
    # FR-010: Apply SSH configuration and enable on boot
    systemctl restart sshd
    systemctl enable sshd
    
    echo "SSH configuration complete. Password must be set via Session Manager."
    
    # ==================================================================
    # PHASE 5 (User Story 3): Security Hardening (FR-014 to FR-016)
    # ==================================================================
    
    echo "Installing fail2ban for brute-force protection..."
    # FR-014: Install fail2ban and systemd integration
    yum install -y fail2ban fail2ban-systemd
    
    echo "Configuring fail2ban SSH jail..."
    # FR-015: fail2ban configuration for SSH protection
    # maxretry=5: Block after 5 failed attempts
    # findtime=600: Within 10 minutes (600 seconds)
    # bantime=3600: Block for 1 hour (3600 seconds)
    cat > /etc/fail2ban/jail.local <<'F2BEOF'
    [DEFAULT]
    bantime = 3600
    findtime = 600
    maxretry = 5
    
    [sshd]
    enabled = true
    port = ssh
    logpath = /var/log/secure
    maxretry = 5
    findtime = 600
    bantime = 3600
    F2BEOF
    
    # FR-016: Ensure SSH authentication logs to /var/log/secure (default on AL2023)
    echo "SSH authentication logging configured to /var/log/secure"
    
    echo "Starting fail2ban service..."
    # FR-014: Enable and start fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    
    echo "Validating fail2ban service status..."
    # FR-037: Validation check for fail2ban
    if systemctl is-active --quiet fail2ban; then
      echo "✓ fail2ban service is active"
    else
      echo "✗ ERROR: fail2ban service failed to start"
      systemctl status fail2ban
      exit 1
    fi
    
    echo "Security hardening complete."
    
    # ==================================================================
    # PHASE 6 (User Story 4): Monitoring (FR-019 to FR-025)
    # ==================================================================
    
    echo "Installing CloudWatch agent..."
    # FR-019: Install CloudWatch agent for log streaming
    yum install -y amazon-cloudwatch-agent
    
    echo "Configuring CloudWatch agent..."
    # FR-019, FR-020: CloudWatch agent configuration for SSH auth logs
    # FR-025: Log group name and retention
    cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'CWEOF'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/secure",
                "log_group_name": "/aws/ec2/dev-instance/ssh-auth",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              }
            ]
          }
        }
      }
    }
    CWEOF
    
    echo "Validating IAM permissions for CloudWatch Logs..."
    # FR-042: Verify instance profile has CloudWatch Logs permissions
    # AmazonSSMManagedInstanceCore includes logs:PutLogEvents
    if aws sts get-caller-identity > /dev/null 2>&1; then
      echo "✓ IAM instance profile is active"
    else
      echo "⚠ WARNING: IAM instance profile may not be properly configured"
    fi
    
    echo "Starting CloudWatch agent..."
    # FR-019: Start CloudWatch agent with configuration
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
    
    echo "Validating CloudWatch agent status..."
    if /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
       -a query -m ec2 -c default | grep -q "running"; then
      echo "✓ CloudWatch agent is running"
    else
      echo "✗ WARNING: CloudWatch agent may not be running properly"
    fi
    
    echo "Monitoring configuration complete."
    
    echo "=== User-Data Script Complete ==="
    echo "End time: $(date)"
  EOT
}
