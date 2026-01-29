# ALB HTTPS Listener Contract
# Maps to: FR-004 (HTTPS listener), FR-005 (HTTPS-only enforcement)
# Reference: research.md Decision 1 (SSL/TLS Certificate Strategy)

listener "https" {
  port     = 443
  protocol = "HTTPS"
  
  # Post-quantum TLS policy (recommended by AWS as of 2025)
  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  
  # Certificate from AWS Certificate Manager
  # Populated via data source lookup or variable
  certificate_arn = "<from data.aws_acm_certificate or var.certificate_arn>"
  
  default_action {
    type             = "forward"
    target_group_arn = "<target_group_arn>"
  }
}

# HTTP Redirect Listener (enforces HTTPS-only)
# Optional but recommended for user experience
listener "http_redirect" {
  port     = 80
  protocol = "HTTP"
  
  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"  # Permanent redirect
    }
  }
}

# Implementation Notes:
# 1. ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09 supports:
#    - TLS 1.3 (modern, high performance)
#    - TLS 1.2 (backward compatibility)
#    - Post-quantum key exchange (future-proof)
#
# 2. Certificate ARN options:
#    a) ACM-managed certificate (recommended):
#       data "aws_acm_certificate" "alb_cert" {
#         domain      = var.certificate_domain
#         statuses    = ["ISSUED"]
#         most_recent = true
#       }
#    b) Self-signed imported certificate (dev only):
#       aws acm import-certificate --certificate file://cert.pem
#
# 3. HTTP redirect is optional:
#    - Include if user experience requires graceful HTTP→HTTPS
#    - Omit if strict HTTPS-only enforcement preferred
#    - Adds negligible cost (~$0/month)
#
# 4. Validation:
#    - Test HTTPS: curl -k https://<alb-dns-name>
#    - Test redirect: curl -I http://<alb-dns-name>
