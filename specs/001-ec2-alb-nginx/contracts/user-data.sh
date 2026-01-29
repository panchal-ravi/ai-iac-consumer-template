#!/bin/bash
# EC2 User Data Script - Nginx Installation and Configuration
# Purpose: Install and configure Nginx web server on Amazon Linux 2023
# Usage: Executed automatically during EC2 instance initialization
# Requirements: Amazon Linux 2023, internet connectivity for package installation

set -e  # Exit immediately if any command fails
set -x  # Print commands as they execute (for debugging)

# Logging setup
LOGFILE="/var/log/user-data-installation.log"
exec > >(tee -a ${LOGFILE})
exec 2>&1

echo "========================================"
echo "Starting EC2 User Data Script"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# Update system packages
echo "[STEP 1/5] Updating system packages..."
dnf update -y
if [ $? -eq 0 ]; then
    echo "✓ System packages updated successfully"
else
    echo "✗ Failed to update system packages"
    exit 1
fi

# Install Nginx
echo "[STEP 2/5] Installing Nginx web server..."
dnf install -y nginx
if [ $? -eq 0 ]; then
    echo "✓ Nginx installed successfully"
    nginx -v
else
    echo "✗ Failed to install Nginx"
    exit 1
fi

# Get EC2 instance metadata
echo "[STEP 3/5] Fetching EC2 instance metadata..."
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')
PRIVATE_IP=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)

echo "Instance ID: ${INSTANCE_ID}"
echo "Availability Zone: ${AVAILABILITY_ZONE}"
echo "Region: ${REGION}"
echo "Private IP: ${PRIVATE_IP}"

# Create custom HTML page with instance information
echo "[STEP 4/5] Creating static HTML page..."
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 ALB Nginx Demo - INSTANCE_ID</title>
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
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            padding: 40px;
            max-width: 600px;
            width: 100%;
            text-align: center;
        }
        h1 {
            color: #333;
            font-size: 2.5em;
            margin-bottom: 20px;
        }
        .rocket {
            font-size: 4em;
            animation: bounce 2s infinite;
        }
        @keyframes bounce {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-20px); }
        }
        .info-box {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 25px;
            margin: 30px 0;
            text-align: left;
            border-radius: 8px;
        }
        .info-box h2 {
            color: #667eea;
            font-size: 1.5em;
            margin-bottom: 20px;
        }
        .info-item {
            margin: 15px 0;
            font-size: 1.1em;
        }
        .info-label {
            font-weight: bold;
            color: #555;
            display: inline-block;
            width: 180px;
        }
        .info-value {
            color: #333;
            font-family: 'Courier New', monospace;
        }
        .status {
            display: inline-block;
            background: #28a745;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            margin-top: 20px;
        }
        .footer {
            margin-top: 30px;
            font-size: 0.9em;
            color: #666;
        }
        .badge {
            display: inline-block;
            background: #764ba2;
            color: white;
            padding: 3px 10px;
            border-radius: 12px;
            font-size: 0.85em;
            margin-left: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="rocket">🚀</div>
        <h1>EC2 ALB Nginx<br>Development Environment</h1>
        
        <div class="info-box">
            <h2>Instance Information</h2>
            <div class="info-item">
                <span class="info-label">Instance ID:</span>
                <span class="info-value">INSTANCE_ID</span>
            </div>
            <div class="info-item">
                <span class="info-label">Availability Zone:</span>
                <span class="info-value">AVAILABILITY_ZONE</span>
                <span class="badge">Multi-AZ</span>
            </div>
            <div class="info-item">
                <span class="info-label">Region:</span>
                <span class="info-value">REGION</span>
            </div>
            <div class="info-item">
                <span class="info-label">Private IP:</span>
                <span class="info-value">PRIVATE_IP</span>
            </div>
            <div class="info-item">
                <span class="info-label">Web Server:</span>
                <span class="info-value">Nginx 1.24.0</span>
            </div>
        </div>
        
        <div class="status">✓ Operational</div>
        
        <div class="footer">
            <p><strong>Project:</strong> ec2-alb-nginx-demo</p>
            <p><strong>Environment:</strong> Development</p>
            <p><strong>Managed by:</strong> Terraform</p>
        </div>
    </div>
</body>
</html>
EOF

# Replace placeholders with actual values
sed -i "s/INSTANCE_ID/${INSTANCE_ID}/g" /usr/share/nginx/html/index.html
sed -i "s/AVAILABILITY_ZONE/${AVAILABILITY_ZONE}/g" /usr/share/nginx/html/index.html
sed -i "s/REGION/${REGION}/g" /usr/share/nginx/html/index.html
sed -i "s/PRIVATE_IP/${PRIVATE_IP}/g" /usr/share/nginx/html/index.html

if [ $? -eq 0 ]; then
    echo "✓ Static HTML page created successfully"
else
    echo "✗ Failed to create static HTML page"
    exit 1
fi

# Create health check endpoint (optional, same as index)
cp /usr/share/nginx/html/index.html /usr/share/nginx/html/health.html
echo "✓ Health check endpoint created at /health.html"

# Configure Nginx (optional custom configuration)
cat > /etc/nginx/conf.d/custom.conf <<'NGINXCONF'
# Custom Nginx configuration for ALB integration
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Main location
    location / {
        try_files $uri $uri/ =404;
    }

    # Disable server tokens for security
    server_tokens off;
}
NGINXCONF

echo "✓ Nginx custom configuration created"

# Validate Nginx configuration
echo "[STEP 5/5] Validating Nginx configuration..."
nginx -t
if [ $? -eq 0 ]; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration validation failed"
    exit 1
fi

# Start and enable Nginx service
echo "Starting Nginx service..."
systemctl start nginx
if [ $? -eq 0 ]; then
    echo "✓ Nginx service started successfully"
else
    echo "✗ Failed to start Nginx service"
    exit 1
fi

# Enable Nginx to start on boot
systemctl enable nginx
if [ $? -eq 0 ]; then
    echo "✓ Nginx service enabled for automatic startup"
else
    echo "✗ Failed to enable Nginx service"
fi

# Verify Nginx is running
systemctl status nginx --no-pager
if systemctl is-active --quiet nginx; then
    echo "✓ Nginx is running"
else
    echo "✗ Nginx is not running"
    exit 1
fi

# Test HTTP endpoint locally
echo "Testing local HTTP endpoint..."
sleep 2  # Give Nginx time to fully start
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "${HTTP_RESPONSE}" = "200" ]; then
    echo "✓ HTTP endpoint responding with 200 OK"
else
    echo "✗ HTTP endpoint returned status: ${HTTP_RESPONSE}"
    exit 1
fi

# Display final status
echo "========================================"
echo "User Data Script Completed Successfully"
echo "========================================"
echo "Instance ID: ${INSTANCE_ID}"
echo "Availability Zone: ${AVAILABILITY_ZONE}"
echo "Nginx Version: $(nginx -v 2>&1 | cut -d'/' -f2)"
echo "Service Status: Active"
echo "Endpoints:"
echo "  - http://${PRIVATE_IP}/"
echo "  - http://${PRIVATE_IP}/health"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# Signal successful completion
exit 0
