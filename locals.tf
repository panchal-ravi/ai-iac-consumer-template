# Local values and data sources
# Feature: 001-public-ec2-password-auth

# Data source: Ubuntu 22.04 LTS AMI (latest)
data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
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

# Data source: Check for default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source: Get default VPC subnets (if default VPC exists)
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

# Data source: Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Local computed values
locals {
  # AMI ID for Ubuntu 22.04 LTS
  ami_id = data.aws_ami.ubuntu_22_04.id

  # VPC selection: use default if exists, otherwise will create custom
  use_default_vpc = try(data.aws_vpc.default.id != "", false)
  vpc_id          = local.use_default_vpc ? data.aws_vpc.default.id : null

  # Subnet selection: use first default subnet if available
  subnet_id = local.use_default_vpc && length(data.aws_subnets.default.ids) > 0 ? data.aws_subnets.default.ids[0] : null

  # First availability zone for custom VPC subnet
  first_az = data.aws_availability_zones.available.names[0]

  # Common tags
  common_tags = {
    Feature     = "001-public-ec2-password-auth"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
