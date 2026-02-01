# =============================================================================
# Local Values
# Feature: 002-ec2-alb-nginx - EC2 Infrastructure with ALB and Nginx
# Purpose: Define computed values and common configurations
# =============================================================================

locals {
  # T015: Common tags for all resources
  common_tags = {
    Environment      = var.environment
    ManagedBy        = "Terraform"
    Terraform        = "true"
    Project          = var.project_name
    Application      = "ec2-nginx-alb"
    Feature          = "002-ec2-alb-nginx"
    Workspace        = "sandbox_workspace"
    Organization     = "ravi-panchal-org"
    CostCenter       = "engineering"
    CostOptimization = "minimal"
    Compliance       = "standard"
    SecurityLevel    = "confidential"
  }

  # T016: Availability zones list
  availability_zones = var.availability_zones

  # T032: User data script for Nginx installation
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system packages
    yum update -y
    
    # Install Nginx
    amazon-linux-extras install nginx1 -y || yum install nginx -y
    
    # Get instance metadata
    INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
    AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
    INSTANCE_TYPE=$(ec2-metadata --instance-type | cut -d " " -f 2)
    LOCAL_IPV4=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)
    
    # Create custom test page with instance metadata
    cat > /usr/share/nginx/html/index.html <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>EC2 Nginx ALB Demo</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
            .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            h1 { color: #232F3E; }
            .info { background: #EBF5FB; padding: 15px; border-radius: 4px; margin: 10px 0; }
            .label { font-weight: bold; color: #1976D2; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 EC2 Nginx ALB Demo - Success!</h1>
            <p>This page is served by Nginx running on Amazon Linux 2.</p>
            
            <div class="info">
                <p><span class="label">Instance ID:</span> $INSTANCE_ID</p>
                <p><span class="label">Availability Zone:</span> $AVAILABILITY_ZONE</p>
                <p><span class="label">Instance Type:</span> $INSTANCE_TYPE</p>
                <p><span class="label">Private IP:</span> $LOCAL_IPV4</p>
                <p><span class="label">Feature:</span> 002-ec2-alb-nginx</p>
            </div>
            
            <p><strong>✓ HTTPS Encryption:</strong> Traffic secured via Application Load Balancer</p>
            <p><strong>✓ High Availability:</strong> Deployed across multiple availability zones</p>
            <p><strong>✓ Infrastructure as Code:</strong> Provisioned with Terraform</p>
        </div>
    </body>
    </html>
    HTML
    
    # Enable and start Nginx
    systemctl enable nginx
    systemctl start nginx
    
    # Verify Nginx is running
    systemctl status nginx
    
    echo "Nginx installation complete on instance $INSTANCE_ID"
  EOF
}
