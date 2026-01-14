# ============================================================================
# Public EC2 Development Instance with Password Authentication
# Feature: 001-public-ec2-dev
# GitHub Issue: #15
# ============================================================================

# ============================================================================
# Phase 2: Foundational Resources (Blocking Prerequisites)
# ============================================================================

# FR-012: CloudWatch Log Group for system logs
module "cloudwatch_log_group" {
  source  = "app.terraform.io/ravi-panchal-org/cloudwatch/aws//modules/log-group"
  version = "5.7.2"

  create            = true
  name              = "/aws/ec2/sandbox_public_ec2_dev"
  retention_in_days = 0    # Never expire (default)
  kms_key_id        = null # Use default encryption

  tags = var.tags
}

# FR-009: Generate random password for devuser (16 characters minimum)
resource "random_password" "devuser" {
  length  = var.password_length
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# FR-005: Discover existing default VPC
data "aws_vpc" "default" {
  default = true
}

# FR-005: Discover default subnets in the VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ============================================================================
# Phase 3: User Story 1 - Provision Public Development Instance (MVP)
# ============================================================================

# FR-010: Local variables for user data template
locals {
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    password = random_password.devuser.result
  })
}

# FR-001, FR-002, FR-003, FR-004: EC2 Instance with all configurations
module "ec2_instance" {
  source  = "app.terraform.io/ravi-panchal-org/ec2-instance/aws"
  version = "6.1.4"

  # Instance configuration
  name              = "sandbox-public-ec2-dev"
  instance_type     = var.instance_type
  ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

  # Network configuration
  subnet_id = element(data.aws_subnets.default.ids, 0)

  # FR-003: Root volume configuration
  root_block_device = {
    type                  = "gp3"
    size                  = 8
    encrypted             = true
    delete_on_termination = true
  }

  # FR-011: Monitoring configuration (basic, not detailed)
  monitoring = false

  # FR-021: Termination protection (disabled for easy cleanup)
  disable_api_termination = false

  # ============================================================================
  # Phase 4: User Story 2 - SSH Access with Password Authentication
  # ============================================================================

  # FR-010: User data script with password injection
  user_data                   = local.user_data
  user_data_replace_on_change = false

  # ============================================================================
  # Phase 5: User Story 3 - Network Security Configuration
  # ============================================================================

  # FR-006: Security group configuration
  create_security_group      = true
  security_group_name        = "sandbox-public-ec2-dev-sg"
  security_group_description = "Security group for public EC2 development instance - allows SSH from anywhere"
  security_group_vpc_id      = data.aws_vpc.default.id

  security_group_ingress_rules = {
    ssh = {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow SSH from anywhere"
    }
  }

  # ============================================================================
  # Phase 6: User Story 4 - Cost-Optimized Monitoring
  # ============================================================================

  # FR-019: IAM instance profile for CloudWatch Logs
  create_iam_instance_profile = true
  iam_role_name               = "sandbox-public-ec2-dev-role"
  iam_role_description        = "IAM role for EC2 development instance with CloudWatch Logs access"

  iam_role_policies = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  # FR-016: Resource tags (Phase 7: User Story 5)
  tags = merge(var.tags, {
    Name = "sandbox-public-ec2-dev"
  })

  # Ensure CloudWatch log group exists before launching instance
  depends_on = [module.cloudwatch_log_group]
}
