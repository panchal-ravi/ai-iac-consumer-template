# ==============================================================================
# Main Infrastructure Configuration
# ==============================================================================
# Feature: EC2 Instance with ALB and Nginx Infrastructure
# This file contains all infrastructure resources for the EC2 ALB Nginx deployment

# ==============================================================================
# 1. IAM ROLES AND POLICIES (User Story 1: Security & IAM)
# ==============================================================================
# Addresses aws-security-review.md Finding #1: Missing IAM Least Privilege Implementation

# T019: Create custom IAM policy for EC2 Session Manager with least privilege
resource "aws_iam_policy" "ec2_session_manager" {
  name        = "${local.name_prefix}-session-manager-policy-${var.environment}"
  description = "Least privilege IAM policy for EC2 Session Manager access (no CloudWatch logs to reduce costs)"
  policy      = data.aws_iam_policy_document.ec2_session_manager.json

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-session-manager-policy"
      Purpose = "EC2 Session Manager least privilege access"
    }
  )
}

# T020: Create IAM role for EC2 instances
resource "aws_iam_role" "ec2_instance" {
  name        = "${local.name_prefix}-ec2-role-${var.environment}"
  description = "IAM role for EC2 instances with Session Manager access only"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-ec2-role"
      Purpose = "EC2 instance role for Session Manager"
    }
  )
}

# T021: Attach custom IAM policy to IAM role
resource "aws_iam_role_policy_attachment" "ec2_session_manager" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = aws_iam_policy.ec2_session_manager.arn
}

# T022: Create IAM instance profile for EC2 attachment
resource "aws_iam_instance_profile" "ec2_instance" {
  name = "${local.name_prefix}-ec2-profile-${var.environment}"
  role = aws_iam_role.ec2_instance.name

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-ec2-instance-profile"
      Purpose = "EC2 instance profile for Session Manager"
    }
  )
}

# ==============================================================================
# 2. SECURITY GROUPS (User Stories 1 & 2: Network Security)
# ==============================================================================

# ------------------------------------------------------------------------------
# 2A. ALB Security Group (Created First - EC2 SG references it)
# ------------------------------------------------------------------------------
# T041: Create ALB security group module call
module "alb_security_group" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "5.3.1"

  name        = "${local.name_prefix}-alb-sg-${var.environment}"
  description = "Security group for Application Load Balancer - allows HTTPS and HTTP from internet"
  vpc_id      = data.aws_vpc.default.id

  # T042-T043: Ingress rules for HTTPS and HTTP
  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS from internet for public access"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP from internet for redirect to HTTPS"
    }
  ]

  # T044: Egress rule to EC2 security group on port 80
  egress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP to EC2 instances via security group reference"
      source_security_group_id = module.ec2_security_group.security_group_id
    }
  ]

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-alb-sg"
      Purpose = "ALB security group"
    }
  )
}

# ------------------------------------------------------------------------------
# 2B. EC2 Instance Security Group
# ------------------------------------------------------------------------------
# T023: Create EC2 security group module call
module "ec2_security_group" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "5.3.1"

  name        = "${local.name_prefix}-ec2-sg-${var.environment}"
  description = "Security group for EC2 Nginx instances - allows HTTP from ALB only"
  vpc_id      = data.aws_vpc.default.id

  # T024: Ingress rule - HTTP port 80 from ALB security group
  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP from ALB security group only"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]

  # T025 & T026: Egress rules for package updates and AWS APIs
  egress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS for package updates and AWS API access"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP for Amazon Linux package repositories"
    }
  ]

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-ec2-sg"
      Purpose = "EC2 instance security group"
    }
  )
}

# ==============================================================================
# 3. EC2 INSTANCES (User Story 1: Web Infrastructure)
# ==============================================================================

# T028-T033: First EC2 instance in availability zone A
module "ec2_instance_1" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "6.1.4"

  name          = "${local.name_prefix}-instance-1-${var.environment}"
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = tolist(data.aws_subnets.default.ids)[0]

  # T027: User data script for Nginx installation
  user_data                   = file("${path.module}/user-data-nginx.sh")
  user_data_replace_on_change = true

  # T032: Attach IAM instance profile for Session Manager
  iam_instance_profile = aws_iam_instance_profile.ec2_instance.name

  # Security group attachment
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]

  # T030: Enable EBS encryption (addresses security finding #2)
  root_block_device = {
    encrypted             = true
    type                  = "gp3"
    size                  = 8
    kms_key_id            = null
    delete_on_termination = true
  }

  # T031: Enforce IMDSv2 (addresses security finding #3)
  metadata_options = {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  # T033: Apply common tags and Name tag
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-instance-1-${var.environment}"
      AZ   = tolist(data.aws_availability_zones.available.names)[0]
    }
  )
}

# T034: Second EC2 instance in availability zone B
module "ec2_instance_2" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "6.1.4"

  name          = "${local.name_prefix}-instance-2-${var.environment}"
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = tolist(data.aws_subnets.default.ids)[1]

  user_data                   = file("${path.module}/user-data-nginx.sh")
  user_data_replace_on_change = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance.name
  vpc_security_group_ids      = [module.ec2_security_group.security_group_id]

  # Enable EBS encryption
  root_block_device = {
    encrypted             = true
    type                  = "gp3"
    size                  = 8
    kms_key_id            = null
    delete_on_termination = true
  }

  # Enforce IMDSv2
  metadata_options = {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-instance-2-${var.environment}"
      AZ   = tolist(data.aws_availability_zones.available.names)[1]
    }
  )
}

# ==============================================================================
# 4. APPLICATION LOAD BALANCER (User Story 2 & 3)
# ==============================================================================

# T045-T050: Create ALB module call with HTTPS and HTTP listeners

# ==============================================================================
# 5. TARGET GROUP ATTACHMENTS (User Story 3)
# ==============================================================================

# T059: Register first EC2 instance to target group
resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.nginx.arn
  target_id        = module.ec2_instance_1.id
  port             = 80
}

# T060: Register second EC2 instance to target group
resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.nginx.arn
  target_id        = module.ec2_instance_2.id
  port             = 80
}

# ==============================================================================
# Application Load Balancer Resources
# ==============================================================================
# Maps to: FR-003 (ALB), FR-004 (HTTPS), FR-005 (HTTPS-only)

# T055-T058: Target group configuration
resource "aws_lb_target_group" "nginx" {
  name     = "${local.name_prefix}-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-target-group"
      Purpose = "nginx-target-group"
    }
  )
}

# T045-T046: Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb-${var.environment}"
  internal           = false #tfsec:ignore:aws-elb-alb-not-public - Internet-facing ALB is required for public access
  load_balancer_type = "application"
  security_groups    = [module.alb_security_group.security_group_id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false
  enable_http2               = true
  drop_invalid_header_fields = true

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-alb"
      Purpose     = "application-load-balancer"
      Environment = var.environment
    }
  )
}

# T047-T048: HTTPS listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-https-listener"
      Purpose = "https-listener"
    }
  )
}

# T049: HTTP listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-http-redirect-listener"
      Purpose = "http-redirect"
    }
  )
}
