#!/bin/bash
# ==============================================================================
# EC2 User Data Script - Nginx Installation and Configuration
# ==============================================================================
# This script runs at instance launch to install and configure Nginx web server
# with a test HTML page showing instance metadata.
# ==============================================================================

set -e  # Exit on any error

# Log all output to file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Starting Nginx installation and configuration"
echo "=========================================="

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install Nginx
echo "Installing Nginx..."
dnf install -y nginx

# Enable Nginx to start on boot
echo "Enabling Nginx service..."
systemctl enable nginx

# Get instance metadata
echo "Fetching instance metadata..."
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
INSTANCE_TYPE=$(ec2-metadata --instance-type | cut -d " " -f 2)
LOCAL_IPV4=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)
PUBLIC_IPV4=$(ec2-metadata --public-ipv4 | cut -d " " -f 2 || echo "N/A")

# Create HTML test page
echo "Creating test HTML page..."
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 ALB Nginx Test Page</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #232f3e;
            border-bottom: 3px solid #ff9900;
            padding-bottom: 10px;
        }
        .metadata {
            background-color: #f8f9fa;
            padding: 15px;
            border-left: 4px solid #007bff;
            margin: 20px 0;
        }
        .metadata-item {
            margin: 10px 0;
            font-family: monospace;
        }
        .label {
            font-weight: bold;
            color: #495057;
        }
        .value {
            color: #007bff;
        }
        .success {
            color: #28a745;
            font-size: 1.2em;
            text-align: center;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 EC2 ALB Nginx Infrastructure</h1>
        <p class="success">✅ Nginx is running successfully!</p>
        
        <h2>Instance Metadata</h2>
        <div class="metadata">
            <div class="metadata-item">
                <span class="label">Instance ID:</span>
                <span class="value">${INSTANCE_ID}</span>
            </div>
            <div class="metadata-item">
                <span class="label">Availability Zone:</span>
                <span class="value">${AVAILABILITY_ZONE}</span>
            </div>
            <div class="metadata-item">
                <span class="label">Instance Type:</span>
                <span class="value">${INSTANCE_TYPE}</span>
            </div>
            <div class="metadata-item">
                <span class="label">Private IP:</span>
                <span class="value">${LOCAL_IPV4}</span>
            </div>
            <div class="metadata-item">
                <span class="label">Public IP:</span>
                <span class="value">${PUBLIC_IPV4}</span>
            </div>
        </div>

        <h2>Infrastructure Details</h2>
        <ul>
            <li>Load Balancer: Application Load Balancer (ALB)</li>
            <li>Protocol: HTTPS → HTTP (TLS termination at ALB)</li>
            <li>High Availability: Multi-AZ deployment</li>
            <li>Health Checks: Enabled with automatic failover</li>
        </ul>

        <p style="text-align: center; color: #6c757d; margin-top: 30px;">
            <small>Deployed via Terraform | Managed by HCP Terraform</small>
        </p>
    </div>
</body>
</html>
EOF

# Set proper permissions
chmod 644 /usr/share/nginx/html/index.html

# Start Nginx service
echo "Starting Nginx service..."
systemctl start nginx

# Verify Nginx is running
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx is running successfully!"
else
    echo "❌ Failed to start Nginx"
    exit 1
fi

# Display final status
echo "=========================================="
echo "✅ User data script completed successfully"
echo "=========================================="
echo "Instance ID: ${INSTANCE_ID}"
echo "Availability Zone: ${AVAILABILITY_ZONE}"
echo "Nginx Status: $(systemctl is-active nginx)"
echo "=========================================="
