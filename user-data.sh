#!/bin/bash
# EC2 User Data Script for Nginx Installation on Amazon Linux 2023
# This script is idempotent and can be safely run multiple times
# Purpose: Install and configure Nginx web server with a static HTML test page

set -euo pipefail

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/user-data.log
}

log "Starting EC2 instance initialization for Nginx web server"

# Update system packages (idempotent)
log "Updating system packages..."
dnf update -y

# Install Nginx (idempotent - dnf will skip if already installed)
log "Installing Nginx web server..."
dnf install -y nginx

# Fetch instance metadata (IMDSv2)
log "Fetching instance metadata..."
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
AVAILABILITY_ZONE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "unknown")
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "unknown")
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "N/A")
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")

# Create static HTML page with instance metadata
log "Creating static HTML test page..."
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Demo - Nginx on AWS</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #ffffff;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            border: 1px solid rgba(255, 255, 255, 0.18);
            max-width: 600px;
            text-align: center;
        }
        h1 {
            margin: 0 0 10px 0;
            font-size: 2.5em;
            font-weight: 700;
        }
        .subtitle {
            font-size: 1.2em;
            margin-bottom: 30px;
            opacity: 0.9;
        }
        .metadata {
            background: rgba(0, 0, 0, 0.2);
            border-radius: 10px;
            padding: 20px;
            margin-top: 20px;
            text-align: left;
        }
        .metadata-item {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        .metadata-item:last-child {
            border-bottom: none;
        }
        .label {
            font-weight: 600;
            opacity: 0.8;
        }
        .value {
            font-family: 'Courier New', monospace;
            font-weight: 700;
        }
        .status {
            display: inline-block;
            background: #10b981;
            color: white;
            padding: 8px 20px;
            border-radius: 20px;
            font-weight: 600;
            margin-top: 20px;
        }
        .footer {
            margin-top: 30px;
            font-size: 0.9em;
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Web Demo</h1>
        <div class="subtitle">Nginx on AWS</div>
        <div class="status">✓ Service Healthy</div>
        
        <div class="metadata">
            <div class="metadata-item">
                <span class="label">Instance ID:</span>
                <span class="value">$INSTANCE_ID</span>
            </div>
            <div class="metadata-item">
                <span class="label">Availability Zone:</span>
                <span class="value">$AVAILABILITY_ZONE</span>
            </div>
            <div class="metadata-item">
                <span class="label">Instance Type:</span>
                <span class="value">$INSTANCE_TYPE</span>
            </div>
            <div class="metadata-item">
                <span class="label">Private IP:</span>
                <span class="value">$PRIVATE_IP</span>
            </div>
            <div class="metadata-item">
                <span class="label">Public IP:</span>
                <span class="value">$PUBLIC_IP</span>
            </div>
        </div>
        
        <div class="footer">
            Deployed via Terraform • HCP Terraform<br>
            High Availability Architecture • ap-southeast-1
        </div>
    </div>
</body>
</html>
EOF

# Configure Nginx (idempotent)
log "Configuring Nginx..."

# Backup original config if not already backed up
if [ ! -f /etc/nginx/nginx.conf.backup ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
fi

# Ensure Nginx is configured to serve on port 80
# The default configuration should work, but we'll verify
cat > /etc/nginx/conf.d/health-check.conf <<EOF
# Health check endpoint configuration
server {
    listen 80 default_server;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Main location - serves the test page
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Health check endpoint (same as root for simplicity)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Server status stub for monitoring
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

# Set correct permissions
log "Setting file permissions..."
chmod 644 /usr/share/nginx/html/index.html
chmod 644 /etc/nginx/conf.d/health-check.conf

# Enable Nginx service to start on boot (idempotent)
log "Enabling Nginx service..."
systemctl enable nginx

# Start Nginx service (idempotent - will not fail if already running)
log "Starting Nginx service..."
systemctl start nginx

# Verify Nginx is running
if systemctl is-active --quiet nginx; then
    log "✓ Nginx service is running successfully"
else
    log "✗ ERROR: Nginx service failed to start"
    systemctl status nginx
    exit 1
fi

# Verify health check endpoint
log "Verifying health check endpoint..."
sleep 2
if curl -sf http://localhost/ > /dev/null; then
    log "✓ Health check endpoint (/) is responding"
else
    log "✗ WARNING: Health check endpoint not responding"
fi

# Display service status
log "Nginx service status:"
systemctl status nginx --no-pager

log "EC2 instance initialization completed successfully"
log "Instance $INSTANCE_ID is ready to serve traffic in $AVAILABILITY_ZONE"

# Create a marker file to indicate successful initialization
touch /var/log/user-data-success
echo "$(date '+%Y-%m-%d %H:%M:%S')" > /var/log/user-data-success

exit 0
