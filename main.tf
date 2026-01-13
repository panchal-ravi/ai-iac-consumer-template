# ============================================================================
# Main Terraform Configuration: Public EC2 Development Instance
# Feature: 001-public-ec2-dev
# Specification: specs/001-public-ec2-dev/spec.md
# ============================================================================

# ----------------------------------------------------------------------------
# Data Sources: Lookup existing AWS resources
# ----------------------------------------------------------------------------

# FR-004: Lookup default VPC in ap-southeast-1 region
data "aws_vpc" "default" {
  default = true
}

# FR-004: Lookup default subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# FR-005: Lookup latest Amazon Linux 2023 AMI
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

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ----------------------------------------------------------------------------
# Security: Password Generation and Secrets Management
# ----------------------------------------------------------------------------

# FR-009: Generate secure random password for SSH authentication
resource "random_password" "ssh_password" {
  length  = var.ssh_password_length
  special = true
  upper   = true
  lower   = true
  numeric = true

  # Ensure all character classes are included
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  min_special = 1
}

# FR-010: Store SSH password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "ssh_password" {
  name        = local.secret_name
  description = "SSH password for EC2 instance ${local.name_prefix}"

  recovery_window_in_days = 7

  tags = local.common_tags
}

# FR-010: Store the password value in the secret
resource "aws_secretsmanager_secret_version" "ssh_password" {
  secret_id     = aws_secretsmanager_secret.ssh_password.id
  secret_string = random_password.ssh_password.result
}

# ----------------------------------------------------------------------------
# IAM: Instance Profile for Secrets Manager Access
# ----------------------------------------------------------------------------

# IAM role for EC2 instance to access Secrets Manager
resource "aws_iam_role" "instance_role" {
  name = local.instance_role_name

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

  tags = local.common_tags
}

# IAM policy to allow EC2 instance to retrieve SSH password from Secrets Manager
resource "aws_iam_role_policy" "secrets_access" {
  name = "${local.instance_role_name}-secrets-policy"
  role = aws_iam_role.instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = aws_secretsmanager_secret.ssh_password.arn
    }]
  })
}

# IAM instance profile to attach the role to EC2 instance
resource "aws_iam_instance_profile" "instance_profile" {
  name = local.instance_profile_name
  role = aws_iam_role.instance_role.name

  tags = local.common_tags
}

# ----------------------------------------------------------------------------
# Network Security: Security Group Configuration
# ----------------------------------------------------------------------------

# FR-013: Create security group with SSH access from internet
resource "aws_security_group" "ssh" {
  name        = local.sg_ssh_name
  description = "Allow SSH access from anywhere (development only - FR-013)"
  vpc_id      = data.aws_vpc.default.id

  tags = merge(
    local.common_tags,
    {
      Name = local.sg_ssh_name
    }
  )
}

# FR-013: Allow inbound SSH traffic from anywhere (0.0.0.0/0)
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ssh.id

  description = "SSH from anywhere (development only)"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = local.common_tags
}

# FR-014: Allow all outbound traffic for package updates and external connectivity
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.ssh.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = local.common_tags
}

# ----------------------------------------------------------------------------
# Compute: EC2 Instance Configuration
# ----------------------------------------------------------------------------

# FR-001 through FR-007, FR-011, FR-012, FR-015, FR-016, FR-017
resource "aws_instance" "dev_ec2" {
  # FR-005: Use latest Amazon Linux 2023 AMI
  ami = data.aws_ami.amazon_linux_2023.id

  # FR-002: Use t3.micro instance type for cost optimization
  instance_type = var.instance_type

  # FR-004: Deploy in default VPC subnet
  subnet_id = data.aws_subnets.default.ids[0]

  # FR-015: Attach SSH security group
  vpc_security_group_ids = [aws_security_group.ssh.id]

  # FR-003: Assign public IP address
  associate_public_ip_address = true

  # Attach IAM instance profile for Secrets Manager access
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  # FR-016: Enable basic monitoring only (5-minute intervals)
  # FR-016a: Detailed monitoring explicitly disabled
  monitoring = var.enable_detailed_monitoring

  # FR-006: Configure root volume (8 GB GP3, delete on termination)
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = false # Can be enabled for additional security

    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-root-volume"
      }
    )
  }

  # FR-008, FR-011, FR-012: User data script to enable SSH password authentication
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    secret_arn = aws_secretsmanager_secret.ssh_password.arn
    region     = var.region
  }))

  # Replace instance if user data changes
  user_data_replace_on_change = true

  # FR-017: Apply common tags
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-instance"
    }
  )

  # Ensure IAM role and secret are created before instance
  depends_on = [
    aws_iam_role_policy.secrets_access,
    aws_secretsmanager_secret_version.ssh_password
  ]
}
