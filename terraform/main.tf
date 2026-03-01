# ==============================================================================
# MAIN TERRAFORM CONFIGURATION
# AWS EC2 Infrastructure with Application Load Balancer and Nginx
# ==============================================================================

# ==============================================================================
# DATA SOURCES - Foundation Resources
# ==============================================================================

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Availability Zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Default Subnets filtered by specified AZs
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }

  filter {
    name   = "availability-zone"
    values = var.availability_zones
  }
}

# Latest Amazon Linux 2023 AMI using SSM parameter
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ==============================================================================
# TLS CERTIFICATE GENERATION
# ==============================================================================

# Private Key for Self-Signed Certificate
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Self-Signed TLS Certificate
resource "tls_self_signed_cert" "main" {
  private_key_pem = tls_private_key.main.private_key_pem

  subject {
    common_name  = var.certificate_domain
    organization = var.project_name
  }

  validity_period_hours = var.certificate_validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [
    var.certificate_domain,
    "*.${var.certificate_domain}",
  ]
}

# Import Certificate to AWS Certificate Manager
resource "aws_acm_certificate" "self_signed" {
  private_key      = tls_private_key.main.private_key_pem
  certificate_body = tls_self_signed_cert.main.cert_pem

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# ALB Security Group - Allow HTTPS from Internet
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Security group for Application Load Balancer - Allow HTTPS from internet"
  vpc_id      = data.aws_vpc.default.id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ALB Security Group Ingress Rules
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# ALB Security Group Egress Rules
resource "aws_security_group_rule" "alb_egress_http_to_ec2" {
  type                     = "egress"
  description              = "HTTP to EC2 instances"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.alb.id
}

# EC2 Security Group - Allow HTTP from ALB only
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-ec2-"
  description = "Security group for EC2 instances - Allow HTTP from ALB only"
  vpc_id      = data.aws_vpc.default.id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# EC2 Security Group Ingress Rules
resource "aws_security_group_rule" "ec2_ingress_http_from_alb" {
  type                     = "ingress"
  description              = "HTTP from ALB"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ec2.id
}

# EC2 Security Group Egress Rules
resource "aws_security_group_rule" "ec2_egress_https" {
  type              = "egress"
  description       = "HTTPS for package updates"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "ec2_egress_http" {
  type              = "egress"
  description       = "HTTP for package updates"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
}

# ==============================================================================
# EC2 INSTANCES - Using Private Registry Module
# ==============================================================================

module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "6.1.4"

  count = var.instance_count

  name = "${var.project_name}-instance-${count.index + 1}"

  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type          = var.instance_type
  subnet_id              = element(data.aws_subnets.default.ids, count.index)
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # User data script for Nginx installation
  user_data = file("${path.module}/user-data.sh")

  # Enable IMDSv2 (Instance Metadata Service v2)
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Root block device configuration
  root_block_device = {
    type                  = "gp3"
    size                  = 8
    delete_on_termination = true
    encrypted             = true
  }

  # Enable detailed monitoring
  monitoring = false # Disabled for cost optimization in dev

  tags = {
    Name             = "${var.project_name}-instance-${count.index + 1}"
    AvailabilityZone = element(var.availability_zones, count.index)
  }
}

# ==============================================================================
# LOAD BALANCER - Target Group
# ==============================================================================

resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-target-group"
  }
}

# Target Group Attachments - Register EC2 Instances
resource "aws_lb_target_group_attachment" "instances" {
  count = var.instance_count

  target_group_arn = aws_lb_target_group.main.arn
  target_id        = module.ec2_instance[count.index].id
  port             = 80
}

# ==============================================================================
# APPLICATION LOAD BALANCER
# ==============================================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# ALB HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.self_signed.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name = "${var.project_name}-https-listener"
  }
}
