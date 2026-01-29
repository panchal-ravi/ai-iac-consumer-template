# Target Group & Health Check Configuration Contract

**Version**: 1.0  
**Last Updated**: 2025-01-29

---

## Target Group Contract

### Purpose
Logical grouping of EC2 instances for load distribution with automated health monitoring per FR-010 and FR-017.

### Configuration Specification

```yaml
target_group:
  name: "{environment}-ec2-tg"
  port: 80
  protocol: "HTTP"
  target_type: "instance"
  vpc_id: "${data.aws_vpc.default.id}"
  
  connection_termination: false
  deregistration_delay: 300  # seconds
  
  stickiness:
    enabled: false  # Not required for stateless static content
    type: null
    
  health_check:
    enabled: true
    interval: 30                    # FR-018: 30 seconds
    path: "/"
    port: "traffic-port"            # Use target port (80)
    protocol: "HTTP"
    timeout: 5
    healthy_threshold: 2            # 2 consecutive successes
    unhealthy_threshold: 2          # 2 consecutive failures
    matcher: "200"                  # HTTP 200 OK
```

### HCL Implementation

```hcl
target_groups = {
  ec2_instances = {
    name        = "${var.environment}-ec2-tg"
    port        = 80
    protocol    = "HTTP"
    target_type = "instance"
    vpc_id      = data.aws_vpc.default.id
    
    health_check = {
      enabled             = true
      healthy_threshold   = 2
      interval            = 30
      matcher             = "200"
      path                = "/"
      port                = "traffic-port"
      protocol            = "HTTP"
      timeout             = 5
      unhealthy_threshold = 2
    }
    
    # Instances attached separately
    create_attachment = false
  }
}
```

---

## Health Check Contract

### Health Check Endpoint

**Endpoint**: `GET /`  
**Expected Response**:
```http
HTTP/1.1 200 OK
Server: nginx/1.24.0
Content-Type: text/html; charset=utf-8
Content-Length: 512

<!DOCTYPE html>
<html>
<head>
    <title>EC2 ALB Nginx Demo</title>
</head>
<body>
    <h1>🚀 EC2 ALB Nginx Development Environment</h1>
    <div class="info">
        <p><strong>Instance ID:</strong> i-0123456789abcdef0</p>
        <p><strong>Availability Zone:</strong> ap-southeast-1a</p>
    </div>
</body>
</html>
```

### Health Check Behavior

**Health Check Request** (sent by ALB every 30 seconds):
```http
GET / HTTP/1.1
Host: <instance-private-ip>:80
User-Agent: ELB-HealthChecker/2.0
Connection: Keep-Alive
```

**Healthy Response Criteria**:
- HTTP status code: `200`
- Response time: < 5 seconds
- Response contains valid HTML content

**Unhealthy Response Scenarios**:
- HTTP status code: `4xx` or `5xx`
- Response time: > 5 seconds (timeout)
- Connection refused (Nginx not running)
- No response received

### State Transitions

```
┌─────────────────────────────────────────────────────┐
│  Instance Registration                              │
│  Initial State: "initial"                           │
│  Status: No traffic sent to instance                │
└────────────────┬────────────────────────────────────┘
                 │
                 │ Wait interval (30s)
                 ↓
┌─────────────────────────────────────────────────────┐
│  Health Check #1                                    │
│  Status: First check performed                      │
└────────────────┬────────────────────────────────────┘
                 │
                 │ 200 OK received
                 ↓
┌─────────────────────────────────────────────────────┐
│  Health Check #2                                    │
│  Status: Second consecutive success                 │
└────────────────┬────────────────────────────────────┘
                 │
                 │ healthy_threshold met (2)
                 ↓
┌─────────────────────────────────────────────────────┐
│  Healthy State                                      │
│  Status: Receiving traffic from ALB                 │
│  Continuous checks every 30s                        │
└────────────────┬────────────────────────────────────┘
                 │
                 │ Check fails (5xx, timeout, etc.)
                 ↓
┌─────────────────────────────────────────────────────┐
│  First Failure                                      │
│  Status: Still receiving traffic (1 failure only)   │
└────────────────┬────────────────────────────────────┘
                 │
                 │ Second consecutive failure
                 ↓
┌─────────────────────────────────────────────────────┐
│  Unhealthy State                                    │
│  Status: Removed from rotation per FR-019           │
│  Continuous checks every 30s                        │
└────────────────┬────────────────────────────────────┘
                 │
                 │ 200 OK received (recovery)
                 ↓
         (Return to "Health Check #1" state)
```

### Detection Times

**Failure Detection**:
```
Time to detect failure = unhealthy_threshold × interval
                       = 2 × 30 seconds
                       = 60 seconds
```

**Recovery Detection**:
```
Time to recover = healthy_threshold × interval
                = 2 × 30 seconds
                = 60 seconds
```

**Total Downtime** (if instance fails and recovers):
```
Minimum downtime = detection_time
                 = 60 seconds (FR-005 compliant)

Maximum downtime = detection_time + recovery_time
                 = 60 + 60 = 120 seconds
```

---

## Target Registration Contract

### EC2 Instance Attachment

**Terraform Resource**:
```hcl
resource "aws_lb_target_group_attachment" "ec2_az_a" {
  target_group_arn = module.alb.target_group_arns["ec2_instances"]
  target_id        = module.ec2_instance["az_a"].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_az_b" {
  target_group_arn = module.alb.target_group_arns["ec2_instances"]
  target_id        = module.ec2_instance["az_b"].id
  port             = 80
}
```

### Target Health States

**Possible States**:
- `initial`: Target registration in progress
- `healthy`: Passing health checks, receiving traffic
- `unhealthy`: Failing health checks, not receiving traffic
- `unused`: Target not registered or deregistered
- `draining`: Deregistration in progress (300s delay)

### AWS CLI Verification

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region ap-southeast-1

# Expected output:
{
  "TargetHealthDescriptions": [
    {
      "Target": {
        "Id": "i-0123456789abcdef0",
        "Port": 80
      },
      "HealthCheckPort": "80",
      "TargetHealth": {
        "State": "healthy",
        "Reason": null,
        "Description": null
      }
    },
    {
      "Target": {
        "Id": "i-0fedcba9876543210",
        "Port": 80
      },
      "HealthCheckPort": "80",
      "TargetHealth": {
        "State": "healthy",
        "Reason": null,
        "Description": null
      }
    }
  ]
}
```

---

## Load Balancing Algorithm

### Algorithm Configuration

**Type**: `round_robin` (default)

**Behavior**:
1. Request 1 → Instance in ap-southeast-1a
2. Request 2 → Instance in ap-southeast-1b
3. Request 3 → Instance in ap-southeast-1a
4. Request 4 → Instance in ap-southeast-1b
5. (Continues cycling through healthy instances)

**Alternative** (not used): `least_outstanding_requests`

### Cross-Zone Load Balancing

**Status**: Enabled by default for Application Load Balancers

**Behavior**:
- Requests distributed evenly across all availability zones
- Each healthy instance receives equal share of traffic
- No additional charges for cross-zone load balancing with ALB

---

## Security Requirements

### Network Access Control

**EC2 Security Group Rule** (required for health checks):
```yaml
security_group_ingress_rule:
  name: "http_from_alb"
  from_port: 80
  to_port: 80
  protocol: tcp
  source_security_group_id: ${alb_security_group_id}
  description: "Allow HTTP from ALB for traffic and health checks per FR-009"
```

**Validation**:
- Health checks must originate from ALB security group
- EC2 instances must allow traffic from ALB on port 80
- No public internet access to EC2 instances on port 80

---

## Monitoring & CloudWatch Metrics

### Target Group Metrics

```yaml
cloudwatch_metrics:
  target_metrics:
    - HealthyHostCount
      description: "Number of healthy targets"
      expected_value: 2
      alarm_threshold: "< 1"
      
    - UnHealthyHostCount
      description: "Number of unhealthy targets"
      expected_value: 0
      alarm_threshold: "> 0 for 5 minutes"
      
    - TargetResponseTime
      description: "Average response time from targets"
      expected_value: "< 100ms for static content"
      alarm_threshold: "> 1000ms"
      
    - RequestCountPerTarget
      description: "Average requests per target"
      use_case: "Monitor load distribution"
      
    - HTTPCode_Target_2XX_Count
      description: "Successful responses from targets"
      expected: "100% of requests (for healthy instances)"
      
    - HTTPCode_Target_5XX_Count
      description: "Server error responses from targets"
      expected: 0
      alarm_threshold: "> 5 per 5 minutes"
```

### Health Check Logs

**CloudWatch Log Group** (optional):
```
/aws/elasticloadbalancing/app/<alb-name>/<alb-id>
```

**Log Entry Example**:
```json
{
  "type": "https",
  "time": "2025-01-29T10:30:00.123456Z",
  "elb": "app/dev-alb-nginx/1234567890abcdef",
  "target_ip": "10.0.1.100",
  "target_port": 80,
  "target_status_code": 200,
  "target_processing_time": 0.012,
  "health_check_result": "healthy"
}
```

---

## Testing & Validation

### Manual Health Check Simulation

```bash
# Simulate health check from ALB to EC2 instance
curl -i http://<instance-private-ip>:80/

# Expected response:
HTTP/1.1 200 OK
Server: nginx/1.24.0
Content-Type: text/html
Content-Length: 512

[HTML content...]
```

### Failure Scenario Testing

**Test 1: Stop Nginx Service**
```bash
# On EC2 instance (via Session Manager)
sudo systemctl stop nginx

# Expected result after 60 seconds:
# - Target marked "unhealthy"
# - No traffic sent to this instance
# - All traffic routed to healthy instance
```

**Test 2: Return Non-200 Status**
```bash
# Modify Nginx to return 503
sudo rm /usr/share/nginx/html/index.html

# Expected result after 60 seconds:
# - Health checks receive 403 or 404
# - Target marked "unhealthy"
# - Instance removed from rotation
```

**Test 3: Slow Response (Timeout)**
```bash
# Add delay to Nginx response (not recommended for production)
# This requires custom Nginx configuration

# Expected result:
# - Health check times out after 5 seconds
# - After 2 consecutive timeouts (60s), target marked "unhealthy"
```

### Automated Validation Tests

```bash
# Test 1: Verify both instances are healthy
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' \
  --output json | jq 'length'
# Expected: 2

# Test 2: Verify load distribution
for i in {1..10}; do
  curl -s https://<alb-dns>/ | grep "Availability Zone"
done
# Expected: Mix of ap-southeast-1a and ap-southeast-1b

# Test 3: Verify health check endpoint
curl -i http://<instance-ip>/ | head -1
# Expected: HTTP/1.1 200 OK
```

---

## Compliance Requirements

### Specification Mapping

- **FR-010**: Target group registers both EC2 instances ✅
- **FR-017**: Health checks configured on HTTP port 80 ✅
- **FR-018**: Health check interval set to 30 seconds ✅
- **FR-019**: Unhealthy instances automatically removed ✅

### Validation Checklist

- [ ] Target group created with correct VPC
- [ ] Both EC2 instances registered to target group
- [ ] Health check path returns HTTP 200
- [ ] Health check interval is 30 seconds
- [ ] Healthy threshold is 2 (60 seconds to healthy)
- [ ] Unhealthy threshold is 2 (60 seconds to unhealthy)
- [ ] Timeout is 5 seconds
- [ ] Matcher is "200" HTTP status
- [ ] EC2 security group allows ALB health checks
- [ ] No public access to EC2 instances on port 80

---

## Troubleshooting Guide

### Common Issues

**Issue 1: All targets unhealthy**
```
Symptom: ALB returns 503 Service Unavailable
```
**Diagnosis**:
1. Check EC2 instance state: `aws ec2 describe-instances`
2. Verify Nginx is running: `sudo systemctl status nginx`
3. Test health check endpoint: `curl http://<instance-ip>/`
4. Check security group rules: Verify ALB → EC2 port 80 allowed

**Issue 2: One target unhealthy**
```
Symptom: Traffic only routed to one instance
```
**Diagnosis**:
1. Check target health: `aws elbv2 describe-target-health`
2. Review health check reason: Look for timeout, connection refused, or HTTP error
3. Verify Nginx configuration on unhealthy instance
4. Check instance system logs: `sudo journalctl -u nginx`

**Issue 3: Health checks timing out**
```
Symptom: Target health shows "Target.Timeout"
```
**Diagnosis**:
1. Verify Nginx response time: `curl -w "%{time_total}\n" http://<instance-ip>/`
2. Check if response time < 5 seconds (timeout threshold)
3. Review Nginx performance: `nginx -t` and check for misconfigurations
4. Verify network connectivity between ALB and EC2 subnets

**Issue 4: Intermittent unhealthy status**
```
Symptom: Target flaps between healthy and unhealthy
```
**Diagnosis**:
1. Check EC2 instance CPU/memory usage
2. Review Nginx error logs: `sudo tail -f /var/log/nginx/error.log`
3. Verify user data script completed successfully
4. Check for resource constraints (disk space, memory)

---

**End of Target Group & Health Check Configuration Contract**
