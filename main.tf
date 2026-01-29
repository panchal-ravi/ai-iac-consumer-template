# ==============================================================================
# Data Sources
# ==============================================================================

# Default VPC Data Source
# FR-004: Use existing default VPC in ap-southeast-1 region
data "aws_vpc" "default" {
  default = true
}

# Default Subnets Data Source
# FR-006: Deploy instances in ap-southeast-1a and ap-southeast-1b
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["${var.region}a", "${var.region}b"]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Retrieve individual subnet details for each AZ
data "aws_subnet" "az_a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["${var.region}a"]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_subnet" "az_b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["${var.region}b"]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# ==============================================================================
# Module: Application Load Balancer (ALB)
# ==============================================================================
# FR-003: Internet-facing Application Load Balancer
# FR-008: ALB accepts HTTP and HTTPS traffic from the internet
# FR-011: HTTP requests redirect to HTTPS
# FR-012: HTTPS listener uses ACM certificate

module "alb" {
  source  = "app.terraform.io/ravi-panchal-org/alb/aws"
  version = "10.2.0"

  name             = "${var.environment}-alb-nginx"
  vpc_id           = data.aws_vpc.default.id
  subnets          = [data.aws_subnet.az_a.id, data.aws_subnet.az_b.id]
  internal         = false
  default_port     = 80
  default_protocol = "HTTP"

  # Security Group Configuration
  # FR-008: ALB accepts HTTP (80) and HTTPS (443) from internet (0.0.0.0/0)
  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow HTTP traffic from internet"
    }
    https = {
      from_port   = 80
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow HTTPS traffic from internet"
    }
  }

  # Target Group Configuration
  # FR-005: ALB routes traffic to EC2 instances in target group
  # FR-015: Health checks on HTTP endpoint every 30 seconds
  target_groups = {
    ec2-instances = {
      name     = "${var.environment}-tg-nginx"
      port     = 80
      protocol = "HTTP"

      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }

      deregistration_delay              = 60
      load_balancing_algorithm_type     = "round_robin"
      load_balancing_cross_zone_enabled = "use_load_balancer_configuration"
    }
  }

  # Listener Configuration
  # FR-011: HTTP listener redirects to HTTPS
  # FR-012: HTTPS listener forwards to target group with ACM certificate
  listeners = {
    # HTTP Listener - Redirects to HTTPS
    http = {
      port     = 80
      protocol = "HTTP"

      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # HTTPS Listener - Forwards to target group
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.acm_certificate_arn
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      forward = {
        target_group_key = "ec2-instances"
      }
    }
  }

  tags = local.common_tags
}

# ==============================================================================
# Module: EC2 Instances
# ==============================================================================
# FR-002: 2x t3.micro instances (one per AZ)
# FR-007: Instances in ap-southeast-1a and ap-southeast-1b
# FR-009: EC2 security group accepts HTTP only from ALB
# FR-010: Instances run Nginx serving static HTML
# FR-013: IAM role with AmazonSSMManagedInstanceCore
# FR-014: No SSH key pairs configured

# EC2 Instance in ap-southeast-1a
module "ec2_instance_az_a" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "6.1.4"

  name                        = "${var.environment}-ec2-nginx-${var.region}a"
  ami_ssm_parameter           = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type               = var.instance_type
  availability_zone           = "${var.region}a"
  subnet_id                   = data.aws_subnet.az_a.id
  associate_public_ip_address = true # Option C: Public IPs enabled per user decision
  key_name                    = null # FR-014: No SSH keys

  # User Data Script
  # FR-010: Install and configure Nginx with static HTML
  user_data                   = local.user_data_script
  user_data_replace_on_change = true

  # IAM Instance Profile
  # FR-013: Systems Manager Session Manager access
  create_iam_instance_profile = true
  iam_role_name               = "${var.environment}-ec2-ssm-role-az-a"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Security Group Configuration
  # FR-009: Accept HTTP traffic only from ALB security group
  create_security_group = true
  security_group_name   = "${var.environment}-ec2-sg-az-a"
  security_group_vpc_id = data.aws_vpc.default.id
  security_group_ingress_rules = {
    http_from_alb = {
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.alb.security_group_id
      description                  = "Allow HTTP traffic from ALB only"
    }
  }

  # Root Volume Configuration
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(
    local.common_tags,
    {
      Name             = "${var.environment}-ec2-nginx-${var.region}a"
      AvailabilityZone = "${var.region}a"
    }
  )
}

# EC2 Instance in ap-southeast-1b
module "ec2_instance_az_b" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "6.1.4"

  name                        = "${var.environment}-ec2-nginx-${var.region}b"
  ami_ssm_parameter           = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type               = var.instance_type
  availability_zone           = "${var.region}b"
  subnet_id                   = data.aws_subnet.az_b.id
  associate_public_ip_address = true # Option C: Public IPs enabled per user decision
  key_name                    = null # FR-014: No SSH keys

  # User Data Script
  # FR-010: Install and configure Nginx with static HTML
  user_data                   = local.user_data_script
  user_data_replace_on_change = true

  # IAM Instance Profile
  # FR-013: Systems Manager Session Manager access
  create_iam_instance_profile = true
  iam_role_name               = "${var.environment}-ec2-ssm-role-az-b"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Security Group Configuration
  # FR-009: Accept HTTP traffic only from ALB security group
  create_security_group = true
  security_group_name   = "${var.environment}-ec2-sg-az-b"
  security_group_vpc_id = data.aws_vpc.default.id
  security_group_ingress_rules = {
    http_from_alb = {
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.alb.security_group_id
      description                  = "Allow HTTP traffic from ALB only"
    }
  }

  # Root Volume Configuration
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(
    local.common_tags,
    {
      Name             = "${var.environment}-ec2-nginx-${var.region}b"
      AvailabilityZone = "${var.region}b"
    }
  )
}

# ==============================================================================
# Resource: Target Group Attachments
# ==============================================================================
# FR-005: Register EC2 instances with ALB target group

resource "aws_lb_target_group_attachment" "ec2_az_a" {
  target_group_arn = module.alb.target_groups["ec2-instances"].arn
  target_id        = module.ec2_instance_az_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_az_b" {
  target_group_arn = module.alb.target_groups["ec2-instances"].arn
  target_id        = module.ec2_instance_az_b.id
  port             = 80
}