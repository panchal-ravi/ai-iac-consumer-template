# Public EC2 Instance with Password Authentication
# Feature: 001-public-ec2-password-auth
# Constitution: Module-first architecture using private registry modules

# =============================================================================
# Phase 2: Foundational Resources
# =============================================================================

# Random password generation (20 characters with complexity requirements)
resource "random_password" "instance_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# CloudWatch Log Group for SSH authentication logs
resource "aws_cloudwatch_log_group" "ssh_auth" {
  name              = "/aws/ec2/ssh-auth"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(local.common_tags, {
    Name = "ssh-auth-logs"
  })
}

# IAM Role for EC2 instance (CloudWatch Agent permissions)
resource "aws_iam_role" "ec2_cloudwatch" {
  name = "ec2-cloudwatch-agent-role-${var.environment}"

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

  tags = merge(local.common_tags, {
    Name = "ec2-cloudwatch-agent-role"
  })
}

# Attach AWS managed CloudWatch Agent policy
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_cloudwatch" {
  name = "ec2-cloudwatch-profile-${var.environment}"
  role = aws_iam_role.ec2_cloudwatch.name

  tags = merge(local.common_tags, {
    Name = "ec2-cloudwatch-profile"
  })
}

# =============================================================================
# Phase 3: VPC Configuration (User Story 1)
# =============================================================================

# Custom VPC (only created if default VPC doesn't exist)
module "vpc" {
  source  = "app.terraform.io/ravi-panchal-org/vpc/aws"
  version = "~> 6.5.0"

  count = local.use_default_vpc ? 0 : 1

  name = "custom-vpc-${var.environment}"
  cidr = "10.0.0.0/16"

  azs             = [local.first_az]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = []

  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "custom-vpc-${var.environment}"
  })
}

# =============================================================================
# Phase 3 & 4: EC2 Instance with Security Group (User Story 1 & 2)
# =============================================================================

# Security Group
resource "aws_security_group" "ec2_instance" {
  name        = "public-ec2-password-auth-${var.environment}"
  description = "Security group for public EC2 instance with password authentication"
  vpc_id      = local.use_default_vpc ? local.vpc_id : module.vpc[0].vpc_id

  # SSH access (required)
  ingress {
    description = "SSH access for development"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access (optional)
  dynamic "ingress" {
    for_each = var.enable_http ? [1] : []
    content {
      description = "HTTP web traffic"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # HTTPS access (optional)
  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      description = "HTTPS web traffic"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Allow all egress (required for updates and CloudWatch)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "public-ec2-password-auth-sg"
  })
}

# EC2 Instance Module
module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "~> 6.1.4"

  name          = "public-ec2-password-auth-${var.environment}"
  ami           = local.ami_id
  instance_type = var.instance_type

  # Network configuration
  subnet_id                   = local.use_default_vpc ? local.subnet_id : module.vpc[0].public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2_instance.id]
  associate_public_ip_address = true

  # IAM instance profile for CloudWatch
  iam_instance_profile = aws_iam_instance_profile.ec2_cloudwatch.name

  # User data script for password authentication setup
  user_data = base64encode(templatefile("${path.module}/user-data.sh.tpl", {
    devuser_password = random_password.instance_password.result
    log_group_name   = aws_cloudwatch_log_group.ssh_auth.name
    aws_region       = var.aws_region
  }))

  # Root volume configuration
  root_block_device = {
    type                  = "gp3"
    size                  = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  # Enhanced monitoring
  monitoring = true

  # Metadata options for security
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "public-ec2-password-auth"
  })
}

# =============================================================================
# Phase 5: Elastic IP (User Story 5)
# =============================================================================

# Elastic IP allocation
resource "aws_eip" "instance" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "public-ec2-password-auth-eip"
  })
}

# Elastic IP association
resource "aws_eip_association" "instance" {
  instance_id   = module.ec2_instance.id
  allocation_id = aws_eip.instance.id
}
