# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# Security group for Application Load Balancer
module "alb_security_group" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer - HTTPS ingress only"
  vpc_id      = data.aws_vpc.default.id

  # HTTPS ingress from internet
  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from internet"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  # Allow all outbound traffic (required for health checks to EC2 instances)
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = local.common_tags
}

# Security group for EC2 instances
module "ec2_security_group" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for EC2 instances - HTTP from ALB only"
  vpc_id      = data.aws_vpc.default.id

  # HTTP ingress from ALB security group only
  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP from ALB"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]

  # Outbound HTTP/HTTPS for package installation (Nginx)
  egress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP for package downloads"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS for package downloads"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = local.common_tags
}

# ==============================================================================
# APPLICATION LOAD BALANCER
# ==============================================================================

module "alb" {
  source  = "app.terraform.io/ravi-panchal-org/alb/aws"
  version = "~> 9.0"

  name               = "${local.name_prefix}-alb"
  load_balancer_type = "application"
  vpc_id             = data.aws_vpc.default.id
  subnets            = local.selected_subnet_ids
  security_groups    = [module.alb_security_group.security_group_id]

  # Target group for EC2 instances
  target_groups = {
    ec2_nginx = {
      name_prefix      = "nginx-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"

      health_check = {
        enabled             = true
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        interval            = var.health_check_interval
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200"
      }

      # Instance attachment is handled separately below
      create_attachment = false
    }
  }

  # HTTPS listener with ACM certificate
  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = local.certificate_arn
      ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"

      forward = {
        target_group_key = "ec2_nginx"
      }
    }
  }

  tags = local.common_tags
}

# ==============================================================================
# EC2 INSTANCES WITH NGINX
# ==============================================================================

# User data script for Nginx installation
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system packages
    apt-get update -y
    apt-get upgrade -y

    # Install Nginx
    apt-get install -y nginx

    # Create custom HTML page with hostname
    cat > /var/www/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>EC2 Instance</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                text-align: center;
                padding: 50px;
                background-color: #f0f0f0;
            }
            .container {
                background-color: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                max-width: 600px;
                margin: 0 auto;
            }
            h1 { color: #333; }
            .hostname { color: #0066cc; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Welcome to Nginx on EC2!</h1>
            <p>This instance is running Nginx and is managed by Terraform.</p>
            <p>Hostname: <span class="hostname">$(hostname)</span></p>
            <p>Environment: ${var.environment}</p>
        </div>
    </body>
    </html>
    HTML

    # Ensure Nginx is running and enabled
    systemctl enable nginx
    systemctl restart nginx

    # Configure basic logging
    echo "Nginx installation completed at $(date)" >> /var/log/user-data.log
    EOF
}

# EC2 instance in first availability zone
module "ec2_instance_az1" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 5.0"

  name                   = "${local.name_prefix}-az1"
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = local.selected_subnet_ids[0]
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]
  user_data_base64       = base64encode(local.user_data)

  # Enable detailed monitoring
  monitoring = true

  # Root volume configuration
  root_block_device = [
    {
      volume_type           = "gp3"
      volume_size           = 8
      delete_on_termination = true
      encrypted             = true
    }
  ]

  tags = merge(
    local.common_tags,
    {
      Name             = "${local.name_prefix}-az1"
      AvailabilityZone = data.aws_availability_zones.available.names[0]
    }
  )
}

# EC2 instance in second availability zone
module "ec2_instance_az2" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 5.0"

  name                   = "${local.name_prefix}-az2"
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = local.selected_subnet_ids[1]
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]
  user_data_base64       = base64encode(local.user_data)

  # Enable detailed monitoring
  monitoring = true

  # Root volume configuration
  root_block_device = [
    {
      volume_type           = "gp3"
      volume_size           = 8
      delete_on_termination = true
      encrypted             = true
    }
  ]

  tags = merge(
    local.common_tags,
    {
      Name             = "${local.name_prefix}-az2"
      AvailabilityZone = data.aws_availability_zones.available.names[1]
    }
  )
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# TARGET GROUP ATTACHMENTS
# ==============================================================================

# Attach EC2 instance in AZ1 to target group
resource "aws_lb_target_group_attachment" "az1" {
  target_group_arn = module.alb.target_groups["ec2_nginx"].arn
  target_id        = module.ec2_instance_az1.id
  port             = 80
}

# Attach EC2 instance in AZ2 to target group
resource "aws_lb_target_group_attachment" "az2" {
  target_group_arn = module.alb.target_groups["ec2_nginx"].arn
  target_id        = module.ec2_instance_az2.id
  port             = 80
}
