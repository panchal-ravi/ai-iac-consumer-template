# =============================================================================
# Main Infrastructure Configuration
# Feature: 002-ec2-alb-nginx - EC2 Infrastructure with ALB and Nginx
# Purpose: Deploy highly available web infrastructure with HTTPS load balancing
# =============================================================================

# =============================================================================
# Data Sources for VPC Discovery (T017-T019)
# =============================================================================

# T017: Discover default VPC
data "aws_vpc" "default" {
  default = true
}

# T018: Discover subnets in the default VPC filtered by availability zones
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = local.availability_zones
  }
}

# T019: Create a map of individual subnets by availability zone
data "aws_subnet" "az" {
  for_each = toset(local.availability_zones)

  vpc_id            = data.aws_vpc.default.id
  availability_zone = each.key

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# =============================================================================
# TLS Certificate Resources
# =============================================================================
# Will be populated in Phase 3: User Story 1

# =============================================================================
# Security Groups
# =============================================================================
# Will be populated in Phase 3: User Story 1

# =============================================================================
# EC2 Instances
# =============================================================================
# Will be populated in Phase 3: User Story 1

# =============================================================================
# Application Load Balancer
# =============================================================================
# Will be populated in Phase 3: User Story 1

# =============================================================================
# Target Group and Attachments
# =============================================================================
# Will be populated in Phase 3: User Story 1

# =============================================================================
# Security Groups (T026-T031)
# =============================================================================

# T026: ALB Security Group
module "alb_security_group" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "5.3.1"

  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  # T027: HTTPS ingress from internet
  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS from internet (FR-009)"
    }
  ]

  # T030: Egress to EC2 instances (will reference EC2 SG - circular dependency resolution)
  # Note: egress_with_source_security_group_id added after EC2 SG creation
  egress_rules = [] # Will be configured separately to avoid circular dependency

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb-sg"
      Type = "alb"
    }
  )
}

# T028: EC2 Security Group
module "ec2_security_group" {
  source  = "app.terraform.io/ravi-panchal-org/security-group/aws"
  version = "5.3.1"

  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 web server instances"
  vpc_id      = data.aws_vpc.default.id

  # T029: HTTP ingress from ALB only
  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_security_group.security_group_id
      description              = "HTTP from ALB only (FR-011)"
    }
  ]

  # T031: All outbound traffic for system updates
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
      description = "Outbound for system updates"
    }
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ec2-sg"
      Type = "ec2"
    }
  )
}

# T030: ALB egress rule to EC2 instances (resolves circular dependency)
resource "aws_security_group_rule" "alb_to_ec2" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.ec2_security_group.security_group_id
  security_group_id        = module.alb_security_group.security_group_id
  description              = "HTTP to EC2 instances (FR-010)"
}


# =============================================================================
# EC2 Instances (T033-T034)
# =============================================================================

# T033-T034: EC2 instance modules using for_each for each availability zone
module "ec2_instance" {
  source   = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version  = "6.1.4"
  for_each = toset(local.availability_zones)

  # Instance configuration
  name          = "${var.project_name}-${each.key}"
  instance_type = var.instance_type

  # Placement
  availability_zone = each.key
  subnet_id         = data.aws_subnet.az[each.key].id

  # Security and networking
  vpc_security_group_ids      = [module.ec2_security_group.security_group_id]
  associate_public_ip_address = true

  # User data for Nginx installation
  user_data                   = local.user_data
  user_data_replace_on_change = true

  # IAM instance profile
  create_iam_instance_profile = true
  iam_role_name               = "${var.project_name}-ec2-role-${each.key}"
  iam_role_description        = "IAM role for EC2 instance in ${each.key}"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # EBS volumes
  enable_volume_tags = true
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  # Monitoring
  monitoring = false

  # Tags
  tags = merge(
    local.common_tags,
    {
      Name             = "${var.project_name}-${each.key}"
      AvailabilityZone = each.key
      Role             = "web-server"
    }
  )
}


# =============================================================================
# Application Load Balancer (T035-T040)
# =============================================================================

# T035-T036: Application Load Balancer
module "alb" {
  source  = "app.terraform.io/ravi-panchal-org/alb/aws"
  version = "10.2.0"

  # ALB configuration
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = false

  # Network placement (T036)
  vpc_id          = data.aws_vpc.default.id
  subnets         = data.aws_subnets.default.ids
  security_groups = [module.alb_security_group.security_group_id]

  # ALB settings
  enable_deletion_protection = false
  enable_http2               = true
  idle_timeout               = 60

  # T037-T038: Target group configuration
  target_groups = {
    default = {
      name                 = "${var.project_name}-tg"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 30
      create_attachment    = false # Attachments managed separately

      # T038: Health check configuration
      health_check = {
        enabled             = true
        path                = "/"
        protocol            = "HTTP"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        interval            = 30
        matcher             = "200"
      }
    }
  }

  # T039: HTTPS listener configuration
  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      certificate_arn = aws_acm_certificate.self_signed.arn

      forward = {
        target_group_key = "default"
      }
    }
  }

  # Tags
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb"
      Type = "application-load-balancer"
    }
  )
}

# =============================================================================
# Target Group Attachments (T040)
# =============================================================================

# T040: Attach EC2 instances to target group
resource "aws_lb_target_group_attachment" "ec2" {
  for_each = module.ec2_instance

  target_group_arn = module.alb.target_groups["default"].arn
  target_id        = each.value.id
  port             = 80
}
