#!/bin/bash
# Nginx Bootstrap Script
# Feature: 003-ec2-alb-nginx
# Purpose: Install and configure Nginx on EC2 instances
# Template Variables: domain_name, environment

set -e  # Exit on error
set -x  # Enable debug output

# ============================================================================
# SYSTEM UPDATE AND NGINX INSTALLATION
# ============================================================================

echo "Starting Nginx installation and configuration..."

# Update system packages
yum update -y

# Install Nginx from amazon-linux-extras
amazon-linux-extras install nginx1 -y

# ============================================================================
# EXTRACT INSTANCE METADATA
# ============================================================================

echo "Extracting instance metadata..."

# Get instance ID, availability zone, and private IP
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
PRIVATE_IP=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)

echo "Instance ID: $INSTANCE_ID"
echo "Availability Zone: $AVAILABILITY_ZONE"
echo "Private IP: $PRIVATE_IP"

# ============================================================================
# GENERATE CUSTOM INDEX PAGE
# ============================================================================

echo "Creating custom index page..."

cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Server - ${domain_name}</title>
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
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #007bff;
            padding-bottom: 10px;
        }
        .metadata {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .metadata-item {
            margin: 10px 0;
            font-size: 16px;
        }
        .label {
            font-weight: bold;
            color: #555;
        }
        .value {
            color: #007bff;
            font-family: 'Courier New', monospace;
        }
        .footer {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            color: #6c757d;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to ${domain_name}</h1>
        <p>This is a development environment running Nginx on Amazon EC2.</p>
        
        <div class="metadata">
            <h2>Instance Information</h2>
            <div class="metadata-item">
                <span class="label">Instance ID:</span>
                <span class="value">INSTANCE_ID_PLACEHOLDER</span>
            </div>
            <div class="metadata-item">
                <span class="label">Availability Zone:</span>
                <span class="value">AVAILABILITY_ZONE_PLACEHOLDER</span>
            </div>
            <div class="metadata-item">
                <span class="label">Private IP:</span>
                <span class="value">PRIVATE_IP_PLACEHOLDER</span>
            </div>
            <div class="metadata-item">
                <span class="label">Environment:</span>
                <span class="value">${environment}</span>
            </div>
        </div>

        <div class="footer">
            <p><strong>Feature:</strong> 003-ec2-alb-nginx</p>
            <p><strong>Managed By:</strong> Terraform</p>
            <p>This infrastructure is deployed using HCP Terraform Cloud.</p>
        </div>
    </div>
</body>
</html>
EOF

# Replace placeholders with actual values
sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /usr/share/nginx/html/index.html
sed -i "s/AVAILABILITY_ZONE_PLACEHOLDER/$AVAILABILITY_ZONE/g" /usr/share/nginx/html/index.html
sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/g" /usr/share/nginx/html/index.html

# ============================================================================
# CONFIGURE NGINX
# ============================================================================

echo "Configuring Nginx..."

# Create custom Nginx configuration
cat > /etc/nginx/conf.d/webapp.conf <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${domain_name};

    # Root directory for static content
    root /usr/share/nginx/html;
    index index.html;

    # Main application endpoint
    location / {
        try_files $uri $uri/ =404;
    }

    # Health check endpoint for ALB
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Nginx status endpoint (optional, for monitoring)
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 172.31.0.0/16;  # VPC CIDR (adjust if using custom VPC)
        deny all;
    }
}
EOF

# Remove default Nginx configuration to avoid conflicts
rm -f /etc/nginx/conf.d/default.conf

# Test Nginx configuration
nginx -t

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

echo "Starting and enabling Nginx service..."

# Start Nginx
systemctl start nginx

# Enable Nginx to start on boot
systemctl enable nginx

# Stop and disable firewalld (security groups handle firewall rules)
if systemctl is-active --quiet firewalld; then
    systemctl stop firewalld
    systemctl disable firewalld
fi

# ============================================================================
# VERIFICATION
# ============================================================================

echo "Verifying Nginx installation..."

# Check Nginx service status
systemctl status nginx

# Test health endpoint
sleep 2
curl -f http://localhost/health || { echo "Health check failed!"; exit 1; }

# Test main endpoint
curl -f http://localhost/ || { echo "Main endpoint failed!"; exit 1; }

echo "Nginx installation and configuration completed successfully!"

# Log completion
echo "Bootstrap completed at: $(date)" >> /var/log/bootstrap-completed.log

exit 0
