# Target Group Contract
# Maps to: FR-008 (health checks), FR-009 (unhealthy instance removal), FR-017 (route to healthy only)
# Reference: research.md Decision 4 (Health Check Configuration)

target_group "nginx_instances" {
  target_type = "instance"
  port        = 80        # Nginx listens on HTTP (ALB terminates SSL)
  protocol    = "HTTP"
  vpc_id      = "<default_vpc_id>"
  
  # Conservative health check parameters for stability
  # MTTD (Mean Time to Detection): 60-90 seconds
  health_check {
    enabled             = true
    healthy_threshold   = 2      # 2 consecutive successes → healthy
    unhealthy_threshold = 2      # 2 consecutive failures → unhealthy
    interval            = 30     # Check every 30 seconds
    timeout             = 5      # 5 second response timeout
    path                = "/"    # Nginx default page
    protocol            = "HTTP" # HTTP health check (not HTTPS)
    matcher             = "200"  # HTTP 200 OK expected
  }
  
  # Deregistration delay: Wait before removing target from rotation
  deregistration_delay = 30  # 30 seconds (allows in-flight requests to complete)
  
  # Stickiness: Not required for static content
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }
  
  # Slow start: Gradually increase traffic to new targets
  # Not critical for static content, but good practice
  slow_start = 0  # Disabled (optional: set to 30-60 for gradual ramp)
}

# Target Attachments
# Populated dynamically via Terraform for_each or count
targets = [
  {
    id   = "<ec2_instance_1_id>"  # Instance in AZ A
    port = 80
  },
  {
    id   = "<ec2_instance_2_id>"  # Instance in AZ B
    port = 80
  }
]

# Implementation Notes:
# 1. Health Check Interval (30s):
#    - Balances fast detection (MTTD ~60s) with reduced instance overhead
#    - AWS recommendation: 10-300s (30s is moderate)
#    - Prevents false positives from transient network issues
#
# 2. Healthy/Unhealthy Threshold (2/2):
#    - 2 consecutive checks required to change state
#    - Fast recovery: Instances return to service after 60s (2 × 30s)
#    - Fast failure: Unhealthy detected after 60s
#    - Prevents flapping from single packet loss
#
# 3. Timeout (5s):
#    - Static content response typically <10ms
#    - 5s provides 500× margin for network latency
#    - Nginx can handle burst CPU without false negatives
#
# 4. Health Check Path ("/"):
#    - Nginx default page created by user_data script
#    - No custom /health endpoint required (simplicity)
#    - Enhanced HTML includes instance metadata for debugging
#
# 5. Deregistration Delay (30s):
#    - Allows in-flight requests to complete before removal
#    - AWS recommendation: 30-300s (30s is aggressive for fast recovery)
#    - Trade-off: Shorter = faster failover, longer = graceful shutdown
#
# 6. Stickiness (disabled):
#    - Not required: Static content is identical across instances
#    - If enabled: Session affinity can help with dynamic content
#    - Cost: $0 impact (stickiness is free)
#
# 7. Slow Start (disabled):
#    - Not critical: Static content doesn't benefit from gradual ramp
#    - If enabled: Useful for applications with cache warming
#
# 8. Terraform Implementation:
#    resource "aws_lb_target_group" "nginx" {
#      name     = "ec2-alb-nginx-tg"
#      port     = 80
#      protocol = "HTTP"
#      vpc_id   = data.aws_vpc.default.id
#      
#      health_check {
#        enabled             = true
#        healthy_threshold   = 2
#        unhealthy_threshold = 2
#        interval            = 30
#        timeout             = 5
#        path                = "/"
#        protocol            = "HTTP"
#        matcher             = "200"
#      }
#      
#      deregistration_delay = 30
#      
#      stickiness {
#        type    = "lb_cookie"
#        enabled = false
#      }
#    }
#    
#    resource "aws_lb_target_group_attachment" "instance" {
#      for_each = module.ec2_instance
#      
#      target_group_arn = aws_lb_target_group.nginx.arn
#      target_id        = each.value.id
#      port             = 80
#    }
#
# 9. Validation:
#    - Check target health:
#      aws elbv2 describe-target-health --target-group-arn <tg-arn>
#    - Expected: Both targets show "healthy" state
#    - Troubleshooting unhealthy:
#      a) Check security group: ALB SG → EC2 SG on port 80
#      b) Verify Nginx running: systemctl status nginx
#      c) Test health check locally: curl http://<instance-private-ip>/
