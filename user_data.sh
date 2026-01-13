#!/bin/bash
# ============================================================================
# User Data Script: Enable SSH Password Authentication
# Feature: 001-public-ec2-dev
# FR-008, FR-011, FR-012: Configure SSH password authentication
# ============================================================================

set -e  # Exit on error
set -x  # Debug output

# Log output to file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user data script execution..."
echo "Timestamp: $(date)"

# Variables passed from Terraform
SECRET_ARN="${secret_arn}"
AWS_REGION="${region}"

# Function to retrieve password from Secrets Manager
retrieve_password() {
    local max_attempts=5
    local attempt=1
    
    echo "Retrieving SSH password from Secrets Manager..."
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts"
        
        # Use IMDSv2 token for enhanced security
        TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
            -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
        
        # Retrieve password using AWS CLI
        PASSWORD=$(aws secretsmanager get-secret-value \
            --secret-id "$SECRET_ARN" \
            --region "$AWS_REGION" \
            --query SecretString \
            --output text 2>/dev/null)
        
        if [ -n "$PASSWORD" ]; then
            echo "Password retrieved successfully"
            echo "$PASSWORD"
            return 0
        fi
        
        echo "Failed to retrieve password, waiting 5 seconds..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: Failed to retrieve password after $max_attempts attempts"
    return 1
}

# Main execution
main() {
    echo "=== Configuring SSH Password Authentication ==="
    
    # Update system packages (optional, but recommended)
    echo "Updating system packages..."
    dnf update -y || true
    
    # Install AWS CLI if not present (usually pre-installed on Amazon Linux 2023)
    if ! command -v aws &> /dev/null; then
        echo "Installing AWS CLI..."
        dnf install -y aws-cli
    fi
    
    # Retrieve password from Secrets Manager
    SSH_PASSWORD=$(retrieve_password)
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to retrieve password from Secrets Manager"
        exit 1
    fi
    
    # Configure SSH daemon to allow password authentication
    echo "Configuring SSH daemon..."
    
    # Backup original sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Enable password authentication
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    
    # Ensure password authentication is explicitly enabled
    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    fi
    
    # Enable ChallengeResponseAuthentication for password prompts
    sed -i 's/^ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    
    if ! grep -q "^ChallengeResponseAuthentication" /etc/ssh/sshd_config; then
        echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
    fi
    
    # Set password for ec2-user
    echo "Setting password for ec2-user..."
    echo "ec2-user:$SSH_PASSWORD" | chpasswd
    
    if [ $? -eq 0 ]; then
        echo "Password set successfully for ec2-user"
    else
        echo "ERROR: Failed to set password for ec2-user"
        exit 1
    fi
    
    # Restart SSH daemon to apply changes
    echo "Restarting SSH daemon..."
    systemctl restart sshd
    
    if [ $? -eq 0 ]; then
        echo "SSH daemon restarted successfully"
    else
        echo "ERROR: Failed to restart SSH daemon"
        exit 1
    fi
    
    # Verify SSH configuration
    echo "Verifying SSH configuration..."
    grep "^PasswordAuthentication" /etc/ssh/sshd_config
    systemctl status sshd --no-pager
    
    echo "=== User data script completed successfully ==="
    echo "SSH password authentication is now enabled"
    echo "Timestamp: $(date)"
}

# Execute main function
main

# Signal success
exit 0
