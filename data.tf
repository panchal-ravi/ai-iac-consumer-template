# ==============================================================================
# Data Sources
# ==============================================================================
# Feature: EC2 Instance with ALB and Nginx Infrastructure
# Data sources for VPC, subnets, AMI, and availability zones

# ------------------------------------------------------------------------------
# VPC and Network Discovery
# ------------------------------------------------------------------------------
# T008: Lookup default VPC
data "aws_vpc" "default" {
  default = true
}

# T009: Lookup default VPC subnets across all availability zones
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

# T011: Get availability zones in ap-southeast-1
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "region-name"
    values = [var.region]
  }
}

# ------------------------------------------------------------------------------
# AMI Discovery
# ------------------------------------------------------------------------------
# T010: Lookup latest Amazon Linux 2023 AMI via SSM parameter
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Extract AMI ID from SSM parameter
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.al2023_ami.value]
  }
}

# ------------------------------------------------------------------------------
# IAM Policy Documents
# ------------------------------------------------------------------------------
# T018: IAM policy document for EC2 Session Manager (least privilege)
# Addresses aws-security-review.md Finding #1: Missing IAM Least Privilege Implementation
data "aws_iam_policy_document" "ec2_session_manager" {
  # Allow EC2 instances to communicate with Systems Manager
  statement {
    sid    = "SessionManagerCore"
    effect = "Allow"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssm:ListAssociations",
      "ssm:DescribeInstanceInformation",
    ]
    resources = ["*"]
  }

  # Allow SSM messages for session manager
  statement {
    sid    = "SessionManagerMessages"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }

  # Allow EC2 messages for command execution
  statement {
    sid    = "EC2Messages"
    effect = "Allow"
    actions = [
      "ec2messages:AcknowledgeMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply",
    ]
    resources = ["*"]
  }
}
