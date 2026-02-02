# Main Terraform Configuration
# Feature: 003-ec2-alb-nginx
# Purpose: Root module that composes infrastructure components

# ============================================================================
# FILE ORGANIZATION
# ============================================================================
# This file contains module instantiations in the following order:
#
# 1. TLS Certificate Generation (tls_private_key, tls_self_signed_cert)
# 2. ACM Certificate Import (aws_acm_certificate)
# 3. Security Groups (module.security_group_alb, module.security_group_ec2)
# 4. EC2 Instances (module.ec2_instances)
# 5. Application Load Balancer (module.alb)
#
# All module sources use the HCP Terraform private registry:
#   app.terraform.io/ravi-panchal-org/<module-name>/aws
# ============================================================================

# ============================================================================
# TLS CERTIFICATE GENERATION
# ============================================================================

# Generate RSA private key for self-signed certificate
resource "tls_private_key" "web" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate self-signed certificate
resource "tls_self_signed_cert" "web" {
  private_key_pem = tls_private_key.web.private_key_pem

  subject {
    common_name  = var.domain_name
    organization = "Development"
  }

  # Certificate validity from variable (90 days default)
  validity_period_hours = var.certificate_validity_days * 24

  # Early renewal 30 days before expiry
  early_renewal_hours = 720

  # Certificate is not a CA certificate
  is_ca_certificate = false

  # Allowed uses for the certificate
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  # DNS names covered by this certificate
  dns_names = [var.domain_name]
}

# Import certificate into AWS Certificate Manager
resource "aws_acm_certificate" "web" {
  private_key      = tls_private_key.web.private_key_pem
  certificate_body = tls_self_signed_cert.web.cert_pem

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name   = "${var.project_name}-${var.environment}-cert"
    Domain = var.domain_name
  })
}

# ============================================================================
# SECURITY GROUPS
# ============================================================================

# Security group for Application Load Balancer
module "security_group_alb" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "~> 5.3.1"

  name        = "${var.project_name}-${var.environment}-sg-alb"
  description = "Security group for ALB - allows HTTPS from internet"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule: Allow HTTPS from internet
  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow HTTPS from internet"
    }
  ]

  # Egress rule: Allow HTTP to EC2 security group (will be added after EC2 SG exists)
  # Note: This creates a computed egress rule
  computed_egress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.security_group_ec2.security_group_id
      description              = "Allow HTTP to EC2 instances"
    }
  ]
  number_of_computed_egress_with_source_security_group_id = 1

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-sg-alb"
    Purpose = "alb"
  })
}

# Security group for EC2 instances
module "security_group_ec2" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "~> 5.3.1"

  name        = "${var.project_name}-${var.environment}-sg-ec2"
  description = "Security group for EC2 instances - allows HTTP from ALB only"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule: Allow HTTP from ALB security group (will be added after ALB SG exists)
  # Note: This creates a computed ingress rule
  computed_ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.security_group_alb.security_group_id
      description              = "Allow HTTP from ALB only"
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  # Egress rule: Allow all outbound traffic for package installation
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  ]

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-sg-ec2"
    Purpose = "ec2"
  })
}

# ============================================================================
# EC2 INSTANCES
# ============================================================================

# Create EC2 instances across selected availability zones
module "ec2_instances" {
  source   = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version  = "~> 6.1.4"
  for_each = local.instance_configs

  name          = each.value.name
  instance_type = var.instance_type

  # Use latest Amazon Linux 2023 AMI via SSM parameter
  ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

  # Network configuration
  subnet_id              = each.value.subnet_id
  vpc_security_group_ids = [module.security_group_ec2.security_group_id]

  # Disable module's internal security group creation
  create_security_group = false

  # User data for Nginx bootstrap
  user_data = local.nginx_user_data

  # Root volume configuration
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(local.common_tags, {
    Name             = each.value.name
    AvailabilityZone = each.value.az
    ResourceType     = "compute"
  })
}

# ============================================================================
# APPLICATION LOAD BALANCER
# ============================================================================

module "alb" {
  source  = "app.terraform.io/ravi-panchal-org/alb/aws"
  version = "~> 10.2.0"

  name               = "${var.project_name}-${var.environment}-alb"
  load_balancer_type = "application"
  internal           = false

  # Network configuration
  vpc_id  = data.aws_vpc.default.id
  subnets = local.selected_subnet_ids

  # Security groups
  security_groups = [module.security_group_alb.security_group_id]

  # Enable deletion protection for production (disabled for development)
  enable_deletion_protection = false

  # Target groups configuration
  target_groups = {
    ec2-nginx = {
      name              = "${var.project_name}-${var.environment}-tg"
      backend_protocol  = "HTTP"
      backend_port      = 80
      target_type       = "instance"
      create_attachment = false # We'll use additional_target_group_attachments instead

      # Health check configuration
      health_check = {
        enabled             = true
        interval            = var.health_check_interval
        path                = var.health_check_path
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  }

  # Register EC2 instances as targets
  additional_target_group_attachments = {
    for k, instance in module.ec2_instances : k => {
      target_group_key = "ec2-nginx"
      target_id        = instance.id
      port             = 80
    }
  }

  # HTTPS listener configuration
  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate.web.arn
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      # Default action: Forward to target group
      forward = {
        target_group_key = "ec2-nginx"
      }
    }
  }

  tags = merge(local.common_tags, {
    Name         = "${var.project_name}-${var.environment}-alb"
    ResourceType = "load-balancer"
    Scheme       = "internet-facing"
  })
}
