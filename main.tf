# EC2 Development Instance Infrastructure
# Feature: 001-ec2-dev-instance
# Constitution 3.1: Resource organization in main.tf

# ==============================================================================
# DATA SOURCES - Lookup existing AWS resources
# ==============================================================================

# FR-001: Default VPC discovery in us-east-1
# Requirement: Instance must be deployed in default VPC
data "aws_vpc" "default" {
  default = true
}

# FR-002: Public subnet discovery for instance placement
# Filter: Subnets with map-public-ip-on-launch enabled
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# FR-003: Latest Amazon Linux 2023 AMI lookup
# Benefit: Automatic security updates through AWS-managed releases
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# IAM RESOURCES - Session Manager emergency access
# ==============================================================================

# FR-007a: IAM role for EC2 instance with SSM access
# Purpose: Enable Session Manager for emergency access and password setup
resource "aws_iam_role" "ec2_ssm_role" {
  name        = local.iam_role_name
  description = "IAM role for EC2 instance with Session Manager access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(
    local.common_tags,
    {
      Name = local.iam_role_name
    }
  )
}

# FR-007a: Attach AWS managed policy for SSM functionality
# Policy: AmazonSSMManagedInstanceCore (includes CloudWatch Logs permissions)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# FR-007a: Instance profile for attaching IAM role to EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.iam_role_name}-profile"
  role = aws_iam_role.ec2_ssm_role.name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.iam_role_name}-profile"
    }
  )
}

# ==============================================================================
# MONITORING RESOURCES - CloudWatch Logs
# ==============================================================================

# FR-020: CloudWatch Logs group for SSH authentication events
# FR-025: 7-day retention for cost optimization in development
resource "aws_cloudwatch_log_group" "ssh_auth_logs" {
  name              = "/aws/ec2/dev-instance/ssh-auth"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name    = "ssh-authentication-logs"
      Purpose = "ssh-auth-monitoring"
    }
  )
}

# ==============================================================================
# SECURITY GROUP - SSH access control
# ==============================================================================

# FR-004: Security group allowing SSH ingress from 0.0.0.0/0
# RISK-001: Public SSH access (HIGH severity) - Accepted for development
resource "aws_security_group" "ec2_dev_ssh" {
  name        = local.security_group_name
  description = "Allow SSH access to development instance (public)"
  vpc_id      = data.aws_vpc.default.id

  # FR-004: SSH ingress from configurable CIDR blocks
  ingress {
    description = "SSH from anywhere (development only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr_blocks
  }

  # FR-004: Allow all outbound traffic for package installation
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name         = local.security_group_name
      PublicAccess = "true"
    }
  )
}

# ==============================================================================
# EC2 INSTANCE - Development instance with password SSH access
# ==============================================================================

# FR-001: t3.micro instance with Amazon Linux 2023
# US1: Deploy running EC2 instance with public IP for development environment
resource "aws_instance" "dev" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.public.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_dev_ssh.id]

  # FR-031: User-data script for SSH configuration and security hardening
  # Will be populated in Phases 4-6 (User Stories 2-4)
  user_data = base64encode(local.user_data_script)

  # FR-018: Root EBS volume configuration
  # Security review: EBS encryption enabled
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      local.common_tags,
      {
        Name = "${local.instance_name}-root-volume"
      }
    )
  }

  # FR-024: CloudWatch basic monitoring (5-minute intervals)
  # Cost optimization: Detailed monitoring disabled by default
  monitoring = var.enable_monitoring

  # FR-005: Required tags for compliance and tracking
  tags = merge(
    local.common_tags,
    var.additional_tags,
    {
      Name         = local.instance_name
      PublicAccess = "true"
    }
  )

  # Ensure IAM and CloudWatch resources exist before instance creation
  depends_on = [
    aws_iam_instance_profile.ec2_profile,
    aws_cloudwatch_log_group.ssh_auth_logs
  ]
}

# ==============================================================================
# ELASTIC IP - Consistent public IP across reboots
# ==============================================================================

# FR-002: Elastic IP for stable SSH access
# Benefit: IP address remains consistent across instance stops/starts
resource "aws_eip" "dev_instance" {
  domain   = "vpc"
  instance = aws_instance.dev.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.instance_name}-eip"
    }
  )

  # Prevent IP address changes during updates
  lifecycle {
    create_before_destroy = true
  }
}
