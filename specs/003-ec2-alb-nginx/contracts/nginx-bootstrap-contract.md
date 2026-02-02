# Nginx Bootstrap Script Contract

**Purpose**: Define the user data script interface and behavior for EC2 instance bootstrapping  
**Language**: Bash  
**Execution Context**: EC2 instance launch (runs as root)

---

## Script Interface

### Input Parameters (Template Variables)

```hcl
templatefile("user-data/nginx-bootstrap.sh", {
  domain_name = string  # Domain name for Nginx configuration (e.g., "web.demo.com")
  environment = string  # Environment name for display (e.g., "development")
})
```

### Expected Behavior

1. **System Update**: Update package repositories and installed packages
2. **Nginx Installation**: Install Nginx web server from official repositories
3. **Content Creation**: Generate custom index.html with instance metadata
4. **Configuration**: Configure Nginx virtual host for domain
5. **Health Endpoint**: Create /health endpoint for ALB health checks
6. **Service Management**: Start and enable Nginx service
7. **Firewall**: Disable firewall (security managed by security groups)

---

## Script Specification

### Exit Codes

- `0`: Success (all operations completed)
- `1`: General error
- `2`: Package installation failed
- `3`: Service start failed

### Execution Time

- **Expected**: 30-90 seconds
- **Maximum**: 180 seconds (3 minutes)
- **Timeout Handling**: EC2 user data timeout is 5 minutes by default

### Logging

- Standard output: Logged to `/var/log/cloud-init-output.log`
- Standard error: Logged to `/var/log/cloud-init-output.log`
- Nginx error logs: `/var/log/nginx/error.log`
- Nginx access logs: `/var/log/nginx/access.log`

---

## File Outputs

### 1. Index Page: `/usr/share/nginx/html/index.html`

**Content Type**: HTML  
**Permissions**: 644 (readable by all)  
**Owner**: nginx:nginx

**Required Elements**:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Web Server</title>
</head>
<body>
    <h1>Welcome to ${domain_name}</h1>
    <p><strong>Instance ID:</strong> ${INSTANCE_ID}</p>
    <p><strong>Availability Zone:</strong> ${AVAILABILITY_ZONE}</p>
    <p><strong>Environment:</strong> ${environment}</p>
    <p><strong>Private IP:</strong> ${PRIVATE_IP}</p>
    <p><strong>Server Time:</strong> ${TIMESTAMP}</p>
</body>
</html>
```

**Validation**:
- Must return HTTP 200 when accessed
- Must display actual instance metadata (not placeholders)
- Must be valid HTML

---

### 2. Nginx Configuration: `/etc/nginx/conf.d/webapp.conf`

**Content Type**: Nginx configuration  
**Permissions**: 644  
**Owner**: root:root

**Required Directives**:
```nginx
server {
    listen 80;
    server_name ${domain_name};
    
    # Root directory
    root /usr/share/nginx/html;
    index index.html;
    
    # Main application endpoint
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Health check endpoint (no logging)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Nginx status endpoint (for monitoring)
    location /nginx_status {
        stub_status on;
        access_log off;
    }
}
```

**Validation**:
- Configuration must pass `nginx -t` test
- Port 80 must be listening after service start
- `/health` must return 200 status code
- `/` must serve index.html
- `/nginx_status` must return Nginx status page

---

### 3. Health Check Response: `/health`

**Content Type**: text/plain  
**HTTP Status**: 200 OK  
**Content-Length**: 8 bytes  

**Response Body**:
```
healthy
```

**Headers**:
```
HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 8
Connection: keep-alive
```

**Validation**:
- Must respond within 1 second
- Must always return 200 (no conditional logic)
- Must not log to access.log (performance optimization)

---

## EC2 Metadata Access

### Required Metadata Endpoints

```bash
# Instance ID
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
# Alternative: curl -s http://169.254.169.254/latest/meta-data/instance-id

# Availability Zone
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
# Alternative: curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone

# Private IP
PRIVATE_IP=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)
# Alternative: curl -s http://169.254.169.254/latest/meta-data/local-ipv4

# Public IP (if assigned)
PUBLIC_IP=$(ec2-metadata --public-ipv4 | cut -d " " -f 2)
# Alternative: curl -s http://169.254.169.254/latest/meta-data/public-ipv4
```

### Metadata Service Requirements

- **Version**: IMDSv2 preferred (token-based)
- **Timeout**: 1 second per request
- **Retry**: 3 attempts with exponential backoff
- **Error Handling**: Graceful fallback to "N/A" if metadata unavailable

---

## Script Template

### Template File Path
```
user-data/nginx-bootstrap.sh
```

### Template Syntax
```bash
#!/bin/bash
# EC2 User Data Script: Nginx Bootstrap
# Purpose: Install and configure Nginx web server for ${domain_name}
# Environment: ${environment}

set -e  # Exit on error
set -x  # Enable debug output

# Template variables
DOMAIN_NAME="${domain_name}"
ENVIRONMENT="${environment}"

# ... (rest of script)
```

---

## Package Dependencies

### Amazon Linux 2023
```bash
yum update -y
yum install -y nginx
```

### Ubuntu 22.04 (Alternative)
```bash
apt-get update -y
apt-get install -y nginx
```

**Expected Nginx Version**: Latest stable from repository (1.20+)

---

## Service Management

### Systemd Commands

```bash
# Start Nginx
systemctl start nginx

# Enable Nginx to start on boot
systemctl enable nginx

# Verify Nginx is running
systemctl is-active nginx

# Check Nginx status
systemctl status nginx
```

### Expected Service State

```
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
   Active: active (running)
   Main PID: 1234 (nginx)
   Status: "Configuration reloaded"
```

---

## Error Handling

### Package Installation Failure

```bash
if ! yum install -y nginx; then
    echo "ERROR: Failed to install Nginx" >&2
    exit 2
fi
```

### Service Start Failure

```bash
if ! systemctl start nginx; then
    echo "ERROR: Failed to start Nginx service" >&2
    journalctl -xe -u nginx  # Log debug information
    exit 3
fi
```

### Configuration Test Failure

```bash
if ! nginx -t; then
    echo "ERROR: Nginx configuration test failed" >&2
    cat /etc/nginx/conf.d/webapp.conf  # Show problematic configuration
    exit 4
fi
```

---

## Verification Tests

### 1. Nginx Service Check
```bash
# Test command
systemctl is-active nginx

# Expected output
active
```

### 2. Port Listening Check
```bash
# Test command
ss -tlnp | grep :80

# Expected output
LISTEN    0    128    0.0.0.0:80    0.0.0.0:*    users:(("nginx",pid=1234,fd=6))
```

### 3. Health Endpoint Check
```bash
# Test command
curl -s -o /dev/null -w "%{http_code}" http://localhost/health

# Expected output
200
```

### 4. Index Page Check
```bash
# Test command
curl -s http://localhost/ | grep "Instance ID"

# Expected output
<p><strong>Instance ID:</strong> i-0123456789abcdef0</p>
```

### 5. Configuration Validation
```bash
# Test command
nginx -t

# Expected output
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

---

## Security Considerations

### 1. No Credentials in Script
- ✅ No hardcoded passwords, tokens, or keys
- ✅ No sensitive environment variables
- ✅ AWS credentials managed by IAM instance profile (if needed)

### 2. Minimal Permissions
- ✅ Nginx runs as unprivileged user (nginx)
- ✅ Web content readable by all, writable by root only
- ✅ Configuration files readable by all, writable by root only

### 3. Firewall Management
- ✅ Disable OS firewall (security managed by AWS Security Groups)
- ✅ No iptables rules required
- ✅ All network access control via VPC security groups

### 4. Package Verification
- ✅ Install from official OS repositories only
- ✅ No untrusted third-party repositories
- ✅ GPG signature verification enabled by default

---

## Performance Requirements

### Execution Time Breakdown

| Phase | Expected Time | Maximum Time |
|-------|---------------|--------------|
| System update | 10-30 seconds | 60 seconds |
| Nginx installation | 5-15 seconds | 30 seconds |
| Configuration | 1-5 seconds | 10 seconds |
| Service start | 1-3 seconds | 5 seconds |
| Verification | 1-2 seconds | 5 seconds |
| **Total** | **18-55 seconds** | **110 seconds** |

### Resource Usage

- **CPU**: < 50% during installation
- **Memory**: < 100 MB
- **Disk**: < 50 MB for Nginx and dependencies
- **Network**: < 10 MB download for packages

---

## Idempotency

### Re-run Behavior

The script should be idempotent where possible:

```bash
# Good: Idempotent package installation
yum install -y nginx  # No-op if already installed

# Good: Idempotent service enable
systemctl enable nginx  # No-op if already enabled

# Good: Idempotent file creation (overwrite)
cat > /etc/nginx/conf.d/webapp.conf <<EOF
...
EOF

# Good: Idempotent service restart
systemctl restart nginx  # Always safe
```

### Non-Idempotent Operations

- File appends (use `>` instead of `>>`)
- Conditional logic based on previous state
- Database migrations (not applicable here)

---

## Testing Strategy

### 1. Syntax Validation
```bash
bash -n nginx-bootstrap.sh
```

### 2. ShellCheck Linting
```bash
shellcheck nginx-bootstrap.sh
```

### 3. Local Testing (with Docker)
```bash
docker run -it --rm amazonlinux:2023 bash
# Paste script content and execute
```

### 4. EC2 Testing
```bash
# Launch test instance
aws ec2 run-instances \
  --image-id ami-xxx \
  --instance-type t3.micro \
  --user-data file://nginx-bootstrap.sh

# Wait for instance to be ready
aws ec2 wait instance-running --instance-ids i-xxx

# Verify health endpoint
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids i-xxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
curl http://$PUBLIC_IP/health
```

---

## Contract Validation Checklist

- [ ] Script runs without errors on Amazon Linux 2023
- [ ] Script runs without errors on Ubuntu 22.04 (optional)
- [ ] Nginx service starts successfully
- [ ] Nginx service is enabled on boot
- [ ] Port 80 is listening
- [ ] `/health` endpoint returns 200 status
- [ ] `/` endpoint serves custom index.html
- [ ] Index page displays actual instance metadata
- [ ] Configuration passes `nginx -t` validation
- [ ] Total execution time < 3 minutes
- [ ] Script passes ShellCheck with no errors
- [ ] Script is idempotent (can be run multiple times safely)
- [ ] No credentials or secrets in script
- [ ] Error handling for common failure scenarios
- [ ] Logging to cloud-init-output.log

---

## Integration Points

### Terraform Integration
```hcl
resource "aws_instance" "web" {
  user_data = templatefile("${path.module}/user-data/nginx-bootstrap.sh", {
    domain_name = var.domain_name
    environment = var.environment
  })
  
  user_data_replace_on_change = true  # Force replacement if user data changes
}
```

### ALB Health Check Integration
```hcl
health_check = {
  enabled             = true
  protocol            = "HTTP"
  port                = 80
  path                = "/health"
  interval            = 30
  timeout             = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
  matcher             = "200"
}
```

---

## Contract Summary

This contract defines:
- ✅ **Clear input/output interface** for user data script
- ✅ **Expected behavior and timing** for each phase
- ✅ **File outputs and permissions** for all generated files
- ✅ **Error handling** for common failure scenarios
- ✅ **Verification tests** for automated validation
- ✅ **Performance requirements** and resource limits
- ✅ **Security considerations** for production use
- ✅ **Integration points** with Terraform and ALB

**Status**: ✅ Ready for implementation  
**Next**: Create quickstart documentation
