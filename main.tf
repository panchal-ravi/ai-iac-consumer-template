# ============================================================================
# Web Application Infrastructure with High Availability
# ============================================================================
# This Terraform configuration deploys a highly available web application
# infrastructure on AWS using:
# - VPC with public/private subnets across 2 AZs
# - Application Load Balancer (ALB) with HTTPS
# - Auto Scaling Group with EC2 instances
# - S3 bucket for static content
# - ACM certificate for SSL/TLS
# ============================================================================

# ============================================================================
# Random ID for globally unique S3 bucket name
# ============================================================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ============================================================================
# IAM Role for EC2 Instances
# ============================================================================

resource "aws_iam_role" "ec2" {
  name_prefix = "${var.environment}-webapp-ec2-role-"
  description = "IAM role for EC2 instances to access AWS services (S3, SSM)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.environment}-webapp-ec2-role"
  })
}

# ============================================================================
# IAM Instance Profile for EC2 Instances
# ============================================================================

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${var.environment}-webapp-ec2-profile-"
  role        = aws_iam_role.ec2.name

  tags = var.common_tags
}

# ============================================================================
# IAM Policy Attachment - Session Manager Access
# ============================================================================

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ============================================================================
# KMS Key for S3 Bucket Encryption
# ============================================================================

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-webapp-s3-kms-key"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.environment}-webapp-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# ============================================================================
# S3 Bucket for Static Web Content
# ============================================================================

resource "aws_s3_bucket" "static_content" {
  bucket = "${var.s3_bucket_prefix}-${random_id.bucket_suffix.hex}"

  tags = merge(var.common_tags, {
    Name    = "${var.environment}-webapp-static-content"
    Purpose = "Static web content storage"
  })
}

# S3 Bucket for Access Logs
resource "aws_s3_bucket" "logs" {
  bucket = "${var.s3_bucket_prefix}-logs-${random_id.bucket_suffix.hex}"

  tags = merge(var.common_tags, {
    Name    = "${var.environment}-webapp-logs"
    Purpose = "S3 access logs"
  })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# S3 Bucket Logging Configuration
resource "aws_s3_bucket_logging" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

# ============================================================================
# S3 Bucket Versioning
# ============================================================================

resource "aws_s3_bucket_versioning" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Disabled"
  }
}

# ============================================================================
# S3 Bucket Encryption (Customer-Managed KMS Key)
# ============================================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# ============================================================================
# S3 Bucket Public Access Block
# ============================================================================

resource "aws_s3_bucket_public_access_block" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# IAM Inline Policy - S3 Read Access with KMS
# ============================================================================

resource "aws_iam_role_policy" "s3_read" {
  name_prefix = "${var.environment}-webapp-s3-read-"
  role        = aws_iam_role.ec2.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.static_content.arn,
          "${aws_s3_bucket.static_content.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.s3.arn]
      }
    ]
  })
}

# ============================================================================
# S3 Bucket Policy - Allow EC2 IAM Role Access
# ============================================================================

resource "aws_s3_bucket_policy" "static_content" {
  bucket = aws_s3_bucket.static_content.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEC2RoleAccess"
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.ec2.arn
      }
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.static_content.arn,
        "${aws_s3_bucket.static_content.arn}/*"
      ]
    }]
  })
}

# ============================================================================
# USER STORY 1: Access Web Application
# ============================================================================

# ============================================================================
# VPC Module - Network Foundation
# ============================================================================

module "vpc" {
  source  = "app.terraform.io/hashi-demos-apj/vpc/aws"
  version = "~> 6.5.0"

  name = "${var.environment}-webapp-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  # Enable NAT Gateway for private subnet internet access
  enable_nat_gateway     = true
  one_nat_gateway_per_az = true # HA: One NAT Gateway per AZ

  # Enable DNS support for private DNS hostnames
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-webapp-vpc"
  })
}

# ============================================================================
# Security Groups
# ============================================================================

# ALB Security Group - Allow HTTP/HTTPS from Internet
resource "aws_security_group" "alb" {
  name_prefix = "${var.environment}-webapp-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  # Inbound Rules
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rules
  egress {
    description     = "HTTP to EC2 instances"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-webapp-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Security Group - Allow traffic from ALB only
resource "aws_security_group" "ec2" {
  name_prefix = "${var.environment}-webapp-ec2-"
  description = "Security group for EC2 instances in Auto Scaling Group"
  vpc_id      = module.vpc.vpc_id

  # Inbound Rules
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound Rules
  egress {
    description = "HTTPS to Internet for S3 and package updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP to Internet for package downloads"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-webapp-ec2-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# ACM Certificate for SSL/TLS
# ============================================================================

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-webapp-certificate"
  })
}

# Route53 DNS Validation Records (if Route53 zone ID provided)
resource "aws_route53_record" "cert_validation" {
  for_each = var.route53_zone_id != "" ? {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = var.route53_zone_id != "" ? [for record in aws_route53_record.cert_validation : record.fqdn] : null

  timeouts {
    create = "30m"
  }
}

# ============================================================================
# Application Load Balancer (ALB)
# ============================================================================

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name               = "${var.environment}-webapp-alb"
  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Security Group
  security_groups = [aws_security_group.alb.id]

  # Cross-zone load balancing for even distribution
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false # Sandbox environment

  # Target Groups
  target_groups = {
    webapp_tg = {
      name_prefix = "webapp-"
      protocol    = "HTTP"
      port        = 80
      target_type = "instance"

      deregistration_delay = var.deregistration_delay

      health_check = {
        enabled             = true
        interval            = var.health_check_interval
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = var.health_check_timeout
        healthy_threshold   = var.health_check_healthy_threshold
        unhealthy_threshold = var.health_check_unhealthy_threshold
        matcher             = "200-299"
      }

      tags = {
        Name = "${var.environment}-webapp-target-group"
      }
    }
  }

  # HTTP Listener - Redirect to HTTPS
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "webapp_tg"
      }

      rules = {
        redirect_to_https = {
          priority = 1

          actions = [{
            type = "redirect"
            redirect = {
              port        = "443"
              protocol    = "HTTPS"
              status_code = "HTTP_301"
            }
          }]

          conditions = [{
            path_pattern = {
              values = ["/*"]
            }
          }]
        }
      }
    }

    # HTTPS Listener
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate_validation.main.certificate_arn
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      forward = {
        target_group_key = "webapp_tg"
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-webapp-alb"
  })
}

# ============================================================================
# User Data Script for EC2 Instances
# ============================================================================

locals {
  user_data = <<-EOF
#!/bin/bash
set -e

# Update system packages
yum update -y

# Install Nginx
yum install -y nginx

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Create health check endpoint
echo "OK" > /usr/share/nginx/html/health

# Sync static content from S3 (if available)
aws s3 sync s3://${aws_s3_bucket.static_content.id}/ /usr/share/nginx/html/ || true

# Reload Nginx to apply changes
systemctl reload nginx

# Log completion
echo "User data script completed successfully" >> /var/log/user-data.log
EOF
}

# ============================================================================
# Auto Scaling Group with EC2 Instances
# ============================================================================

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 7.0"

  name = "${var.environment}-webapp-asg"

  # Auto Scaling Group Configuration
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_cooldown          = var.scale_in_cooldown
  termination_policies      = ["OldestInstance"]

  # Launch Template Configuration
  create_launch_template = true
  update_default_version = true

  image_id      = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = var.instance_type

  user_data = base64encode(local.user_data)

  iam_instance_profile_arn = aws_iam_instance_profile.ec2.arn

  security_groups = [aws_security_group.ec2.id]

  # Block Device Mapping
  block_device_mappings = [
    {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 8
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
      }
    }
  ]

  # Metadata Options (IMDSv2)
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  # Enable detailed CloudWatch monitoring
  enable_monitoring = true

  # Target Group Attachment
  target_group_arns = [module.alb.target_groups["webapp_tg"].arn]

  # Target Tracking Scaling Policy
  scaling_policies = {
    cpu_target_tracking = {
      policy_type = "TargetTrackingScaling"
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = var.cpu_target_value
      }
      estimated_instance_warmup = 300
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-webapp-instance"
  })
}

# ============================================================================
# Data Source: Amazon Linux 2023 AMI
# ============================================================================

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = var.ami_ssm_parameter
}
