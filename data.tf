# Data sources for existing AWS infrastructure

# Query the default VPC in the configured region
data "aws_vpc" "default" {
  default = true
}

# Query all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Query availability zones for the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Query ACM certificate for HTTPS listener
# This will search for an issued certificate matching the domain
data "aws_acm_certificate" "existing" {
  count    = var.certificate_arn == null ? 1 : 0
  statuses = ["ISSUED"]
  # If specific domain is needed, uncomment and configure:
  # domain   = "*.example.com"
  most_recent = true
}
