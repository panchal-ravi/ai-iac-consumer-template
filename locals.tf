# Local values for common configuration

locals {
  # Certificate ARN - use provided value or discovered certificate
  certificate_arn = var.certificate_arn != null ? var.certificate_arn : (
    length(data.aws_acm_certificate.existing) > 0 ? data.aws_acm_certificate.existing[0].arn : null
  )

  # Common resource naming convention
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags applied to all resources
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "EC2 with ALB and Nginx"
      Project     = var.project_name
    }
  )

  # Select two subnets from different availability zones
  # This ensures high availability by spreading across AZs
  selected_subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)
}
