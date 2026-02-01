# =============================================================================
# TLS Certificate Configuration
# Feature: 002-ec2-alb-nginx - EC2 Infrastructure with ALB and Nginx
# Purpose: Generate self-signed TLS certificate and import to AWS ACM
# =============================================================================

# T023: Create TLS private key for self-signed certificate
resource "tls_private_key" "self_signed" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# T024: Create self-signed certificate
resource "tls_self_signed_cert" "self_signed" {
  private_key_pem = tls_private_key.self_signed.private_key_pem

  subject {
    common_name  = var.domain_name
    organization = "Demo Organization"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# T025: Import self-signed certificate to AWS Certificate Manager
resource "aws_acm_certificate" "self_signed" {
  private_key      = tls_private_key.self_signed.private_key_pem
  certificate_body = tls_self_signed_cert.self_signed.cert_pem

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-tls-certificate"
      Description = "Self-signed TLS certificate for ${var.domain_name}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
