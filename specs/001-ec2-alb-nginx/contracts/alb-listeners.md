# ALB Listener Configuration Contract

**Version**: 1.0  
**Last Updated**: 2025-01-29

---

## HTTP Listener Contract

### Purpose
Redirects all HTTP traffic to HTTPS to enforce secure communication per FR-011.

### Configuration Specification

```yaml
listener:
  name: "http_redirect"
  port: 80
  protocol: "HTTP"
  
  default_action:
    type: "redirect"
    redirect:
      port: "443"
      protocol: "HTTPS"
      status_code: "HTTP_301"  # Permanent redirect
      
  # No target group attachment (redirect only)
  forward_to: null
```

### HCL Implementation

```hcl
listeners = {
  http = {
    port     = 80
    protocol = "HTTP"
    redirect = {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

### Expected Behavior

**Request**:
```http
GET http://dev-alb-nginx-123456789.ap-southeast-1.elb.amazonaws.com/
Host: dev-alb-nginx-123456789.ap-southeast-1.elb.amazonaws.com
User-Agent: Mozilla/5.0
```

**Response**:
```http
HTTP/1.1 301 Moved Permanently
Location: https://dev-alb-nginx-123456789.ap-southeast-1.elb.amazonaws.com/
Content-Length: 0
```

### Validation Tests

- [ ] HTTP request returns 301 status code
- [ ] Location header points to HTTPS equivalent
- [ ] No unencrypted content served on port 80
- [ ] Redirect preserves URL path and query parameters

---

## HTTPS Listener Contract

### Purpose
Terminates SSL/TLS connections and forwards decrypted traffic to target group per FR-003.

### Configuration Specification

```yaml
listener:
  name: "https_forward"
  port: 443
  protocol: "HTTPS"
  
  ssl_policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn: "${var.acm_certificate_arn}"
  
  default_action:
    type: "forward"
    forward:
      target_group_key: "ec2_instances"
      
  # Mutual TLS authentication: disabled (not required for dev)
  mutual_authentication: null
```

### HCL Implementation

```hcl
listeners = {
  https = {
    port            = 443
    protocol        = "HTTPS"
    certificate_arn = var.acm_certificate_arn
    forward = {
      target_group_key = "ec2_instances"
    }
  }
}
```

### Certificate Requirements

**Certificate Specification**:
- Type: X.509 certificate (self-signed)
- Key Algorithm: RSA 2048-bit
- Validity: 365 days
- Domain: `*.elb.amazonaws.com` (wildcard)
- Issuer: Self (development only)

**Certificate Import**:
```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout alb-private-key.pem \
  -out alb-certificate.pem \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=Development/CN=*.elb.amazonaws.com"

# Import to ACM
aws acm import-certificate \
  --certificate fileb://alb-certificate.pem \
  --private-key fileb://alb-private-key.pem \
  --region ap-southeast-1
```

### Expected Behavior

**Request**:
```http
GET https://dev-alb-nginx-123456789.ap-southeast-1.elb.amazonaws.com/
Host: dev-alb-nginx-123456789.ap-southeast-1.elb.amazonaws.com
User-Agent: Mozilla/5.0
```

**Response**:
```http
HTTP/2 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 512
Server: nginx/1.24.0

<!DOCTYPE html>
<html>
<head><title>EC2 ALB Nginx Demo</title></head>
<body>
  <h1>🚀 EC2 ALB Nginx Development Environment</h1>
  <p>Instance ID: i-0123456789abcdef0</p>
  <p>Availability Zone: ap-southeast-1a</p>
</body>
</html>
```

### Validation Tests

- [ ] HTTPS request succeeds with 200 status code
- [ ] SSL handshake completes (with browser warning for self-signed cert)
- [ ] Certificate is properly attached to listener
- [ ] TLS 1.2 or 1.3 is used for encryption
- [ ] Response contains HTML content from Nginx

### Browser Certificate Warning Handling

**Expected Browser Behavior**:
- Chrome: "Your connection is not private" (NET::ERR_CERT_AUTHORITY_INVALID)
- Firefox: "Warning: Potential Security Risk Ahead"
- Safari: "This Connection Is Not Private"

**User Action Required**:
1. Click "Advanced" or "Show Details"
2. Click "Proceed to [site] (unsafe)" or "Visit this website"
3. Page loads normally after acceptance

**Note**: This is acceptable for development environment. For production, use a certificate from a trusted CA or AWS Certificate Manager with domain validation.

---

## Listener Security Configuration

### SSL/TLS Policy

**Policy Name**: `ELBSecurityPolicy-TLS13-1-2-2021-06`

**Supported Protocols**:
- TLS 1.3 (preferred)
- TLS 1.2 (fallback)

**Supported Ciphers** (in order of preference):
```
TLS13-AES-128-GCM-SHA256
TLS13-AES-256-GCM-SHA384
ECDHE-RSA-AES128-GCM-SHA256
ECDHE-RSA-AES256-GCM-SHA384
```

**Rationale**: Modern TLS policy balancing security and compatibility for development environment.

### Security Group Integration

**ALB Security Group Ingress**:
```yaml
ingress_rules:
  http:
    from_port: 80
    to_port: 80
    protocol: tcp
    cidr_ipv4: 0.0.0.0/0
    description: "Allow HTTP from internet for redirect"
    
  https:
    from_port: 443
    to_port: 443
    protocol: tcp
    cidr_ipv4: 0.0.0.0/0
    description: "Allow HTTPS from internet"
```

---

## Monitoring & Metrics

### CloudWatch Metrics

**Listener-Level Metrics**:
- `ActiveConnectionCount`: Number of active connections
- `NewConnectionCount`: Number of new connections per minute
- `ProcessedBytes`: Total bytes processed
- `RequestCount`: Number of requests processed
- `HTTPCode_ELB_4XX_Count`: Client error responses
- `HTTPCode_ELB_5XX_Count`: Server error responses

**Target-Level Metrics**:
- `HealthyHostCount`: Number of healthy targets
- `UnHealthyHostCount`: Number of unhealthy targets
- `TargetResponseTime`: Response time from targets
- `HTTPCode_Target_2XX_Count`: Successful responses from targets

### Alerting Thresholds (Optional for Development)

```yaml
alerts:
  high_5xx_rate:
    metric: HTTPCode_ELB_5XX_Count
    threshold: "> 10 per 5 minutes"
    action: "Investigate ALB or target issues"
    
  no_healthy_targets:
    metric: HealthyHostCount
    threshold: "< 1"
    action: "Critical: No healthy instances available"
```

---

## Compliance Requirements

### Specification Mapping

- **FR-003**: ALB must have HTTP (80) and HTTPS (443) listeners ✅
- **FR-011**: HTTP must redirect to HTTPS (301 redirect) ✅
- **FR-012**: HTTPS listener must use SSL/TLS certificate ✅

### Security Validation

- [ ] No unencrypted traffic forwarded to targets
- [ ] Certificate matches ALB DNS name pattern
- [ ] TLS version meets minimum requirements (TLS 1.2+)
- [ ] HTTP redirect preserves request context

---

## Troubleshooting Guide

### Common Issues

**Issue 1: Certificate not found**
```
Error: Certificate ARN is invalid or does not exist
```
**Solution**: Verify certificate is imported to ACM in ap-southeast-1 region

**Issue 2: Browser warns about certificate**
```
Warning: NET::ERR_CERT_AUTHORITY_INVALID
```
**Solution**: Expected for self-signed certificates, click "Proceed" to continue

**Issue 3: HTTP not redirecting**
```
HTTP request returns 502 or connection timeout
```
**Solution**: Verify HTTP listener has redirect action configured, not forward action

**Issue 4: Target group has no healthy targets**
```
HTTP 503 Service Unavailable
```
**Solution**: Check EC2 instance health, Nginx status, security group rules

---

**End of ALB Listener Configuration Contract**
