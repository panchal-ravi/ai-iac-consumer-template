# Data Sources
# Feature: 003-ec2-alb-nginx
# Purpose: Query existing AWS resources (VPC, subnets, AMI)

# Query default VPC in the region
data "aws_vpc" "default" {
  default = true
}

# Query all subnets in the default VPC
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

# Get detailed information about each subnet
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}
