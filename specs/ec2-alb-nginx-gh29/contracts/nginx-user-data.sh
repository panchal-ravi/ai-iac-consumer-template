#!/bin/bash
# Nginx Installation and Configuration Script
# Maps to: FR-006 (install Nginx), FR-007 (serve static content)
# Reference: research.md Decision 5 (Nginx Installation & Configuration)
#
# This script is executed via EC2 user_data during first boot
# Logs: /var/log/cloud-init-output.log
# Status: /var/log/user-data-status.log

set -e  # Exit immediately on any error
set -o pipefail  # Fail pipe if any command fails

# Function: Log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/user-data-status.log
}

log "=========================================="
log "Starting Nginx installation and configuration"
log "=========================================="

# Update system packages
log "Updating system packages with dnf..."
if dnf update -y; then
    log "✅ System packages updated successfully"
else
    log "❌ Failed to update system packages"
    exit 1
fi

# Install Nginx
log "Installing Nginx web server..."
if dnf install -y nginx; then
    log "✅ Nginx installed successfully"
else
    log "❌ Failed to install Nginx"
    exit 1
fi

# Fetch instance metadata for dynamic content
log "Fetching instance metadata..."
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
LOCAL_IPV4=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)
INSTANCE_TYPE=$(ec2-metadata --instance-type | cut -d " " -f 2)
AMI_ID=$(ec2-metadata --ami-id | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')

log "Instance details:"
log "  - Instance ID: $INSTANCE_ID"
log "  - Availability Zone: $AVAILABILITY_ZONE"
log "  - Private IP: $LOCAL_IPV4"
log "  - Instance Type: $INSTANCE_TYPE"

# Create enhanced static content with instance metadata
log "Creating enhanced static HTML content..."
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 ALB Nginx Infrastructure</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 800px;
            width: 100%;
            padding: 40px;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        .info-box {
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 25px;
            border-left: 5px solid #667eea;
        }
        .info-box h2 {
            color: #333;
            margin-bottom: 15px;
            font-size: 1.5em;
        }
        .info-item {
            display: flex;
            margin-bottom: 10px;
            padding: 8px 0;
            border-bottom: 1px solid rgba(0,0,0,0.1);
        }
        .info-item:last-child {
            border-bottom: none;
        }
        .info-label {
            font-weight: 600;
            color: #555;
            min-width: 180px;
        }
        .info-value {
            color: #333;
            font-family: 'Courier New', monospace;
            word-break: break-all;
        }
        .status {
            background: #d4edda;
            color: #155724;
            padding: 15px;
            border-radius: 8px;
            border: 1px solid #c3e6cb;
            margin-top: 20px;
            font-weight: 600;
            text-align: center;
        }
        .architecture {
            background: #fff3cd;
            padding: 20px;
            border-radius: 10px;
            margin-top: 25px;
            border-left: 5px solid #ffc107;
        }
        .architecture h3 {
            color: #333;
            margin-bottom: 10px;
        }
        .architecture ul {
            margin-left: 20px;
        }
        .architecture li {
            margin-bottom: 5px;
            color: #666;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #999;
            font-size: 0.9em;
        }
        @media (max-width: 600px) {
            h1 {
                font-size: 1.8em;
            }
            .container {
                padding: 20px;
            }
            .info-item {
                flex-direction: column;
            }
            .info-label {
                margin-bottom: 5px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 EC2 ALB Nginx Infrastructure</h1>
        <p class="subtitle">High-Availability Web Deployment across Multiple Availability Zones</p>
        
        <div class="info-box">
            <h2>📍 Instance Information</h2>
            <div class="info-item">
                <span class="info-label">Instance ID:</span>
                <span class="info-value">$INSTANCE_ID</span>
            </div>
            <div class="info-item">
                <span class="info-label">Availability Zone:</span>
                <span class="info-value">$AVAILABILITY_ZONE</span>
            </div>
            <div class="info-item">
                <span class="info-label">Region:</span>
                <span class="info-value">$REGION</span>
            </div>
            <div class="info-item">
                <span class="info-label">Private IPv4:</span>
                <span class="info-value">$LOCAL_IPV4</span>
            </div>
            <div class="info-item">
                <span class="info-label">Instance Type:</span>
                <span class="info-value">$INSTANCE_TYPE</span>
            </div>
            <div class="info-item">
                <span class="info-label">AMI ID:</span>
                <span class="info-value">$AMI_ID</span>
            </div>
        </div>
        
        <div class="architecture">
            <h3>🏗️ Architecture Highlights</h3>
            <ul>
                <li><strong>Load Balancing:</strong> Application Load Balancer with HTTPS</li>
                <li><strong>High Availability:</strong> Multi-AZ deployment (2 availability zones)</li>
                <li><strong>Security:</strong> HTTPS-only access, least-privilege security groups</li>
                <li><strong>Infrastructure-as-Code:</strong> Terraform with private registry modules</li>
                <li><strong>Web Server:</strong> Nginx on Amazon Linux 2023</li>
            </ul>
        </div>
        
        <div class="status">
            ✅ Nginx is running successfully and serving this page
        </div>
        
        <div class="footer">
            <p>Deployed via Terraform | Managed by HCP Terraform</p>
            <p>© 2025 EC2 ALB Nginx Infrastructure | Development Environment</p>
        </div>
    </div>
</body>
</html>
EOF

if [ -f /usr/share/nginx/html/index.html ]; then
    log "✅ Static HTML content created successfully"
else
    log "❌ Failed to create static HTML content"
    exit 1
fi

# Configure Nginx (default configuration is sufficient)
log "Verifying Nginx configuration..."
if nginx -t; then
    log "✅ Nginx configuration is valid"
else
    log "❌ Nginx configuration test failed"
    exit 1
fi

# Start Nginx service
log "Starting Nginx service..."
if systemctl start nginx; then
    log "✅ Nginx service started successfully"
else
    log "❌ Failed to start Nginx service"
    exit 1
fi

# Enable Nginx to start on boot
log "Enabling Nginx service for auto-start on boot..."
if systemctl enable nginx; then
    log "✅ Nginx service enabled for auto-start"
else
    log "❌ Failed to enable Nginx service"
    exit 1
fi

# Verify Nginx is running
log "Verifying Nginx service status..."
if systemctl is-active --quiet nginx; then
    log "✅ Nginx is active and running"
else
    log "❌ Nginx service is not active"
    exit 1
fi

# Test local HTTP response
log "Testing local HTTP response..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    log "✅ Nginx responding to HTTP requests on port 80"
else
    log "❌ Nginx not responding correctly to HTTP requests"
    exit 1
fi

# Display Nginx version
NGINX_VERSION=$(nginx -v 2>&1 | cut -d '/' -f 2)
log "Nginx version: $NGINX_VERSION"

# Final success message
log "=========================================="
log "✅ Nginx installation and configuration completed successfully"
log "Instance is ready to serve traffic via Application Load Balancer"
log "=========================================="

# Write success marker for external validation
echo "SUCCESS" > /var/log/nginx-install-status
echo "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/nginx-install-status

exit 0
