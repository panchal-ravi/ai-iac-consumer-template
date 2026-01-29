# Security Group Rules Contract
# Maps to: FR-010 (least privilege), FR-016 (ALB-EC2 communication), SEC09-BP02 (encryption in transit)
# Reference: research.md Decision 6 (Security Group Rule Design)

# ALB Security Group
# Purpose: Control inbound public traffic and outbound to EC2 instances
security_group "alb" {
  name        = "ec2-alb-nginx-alb-sg"
  description = "Security group for Application Load Balancer - HTTPS only from internet"
  vpc_id      = "<default_vpc_id>"
  
  ingress_rules = {
    https_from_internet = {
      description = "HTTPS from internet (public access)"
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"  # Public internet - required for internet-facing ALB
    }
    
    # Optional: HTTP listener for redirect to HTTPS
    http_redirect = {
      description = "HTTP redirect to HTTPS (optional - improves UX)"
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"  # Public internet
    }
  }
  
  egress_rules = {
    # Least privilege: Only allow traffic to EC2 instances, not entire VPC
    to_ec2_instances = {
      description                  = "Forward HTTPS traffic to EC2 Nginx instances"
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      referenced_security_group_id = "<ec2_security_group_id>"  # Security group reference (dynamic)
    }
  }
}

# EC2 Security Group
# Purpose: Zero-trust isolation - only allow traffic from ALB, block direct internet access
security_group "ec2_instances" {
  name        = "ec2-alb-nginx-instance-sg"
  description = "Security group for EC2 instances running Nginx - ALB traffic only"
  vpc_id      = "<default_vpc_id>"
  
  ingress_rules = {
    # Least privilege: Only allow traffic from ALB, not public internet
    http_from_alb = {
      description                  = "HTTP from ALB only (zero-trust isolation)"
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      referenced_security_group_id = "<alb_security_group_id>"  # Security group reference (dynamic)
    }
  }
  
  egress_rules = {
    # Required for operations: Package updates, CloudWatch metrics
    # Alternative: Use VPC endpoints to restrict to AWS services (adds $14/month cost)
    https_outbound = {
      description = "HTTPS for yum/dnf updates and AWS services (CloudWatch, Systems Manager)"
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"  # Internet access for package repos and AWS APIs
    }
    
    http_outbound = {
      description = "HTTP for package repositories (Amazon Linux repos use HTTP mirrors)"
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"  # Required for yum/dnf updates
    }
  }
}

# Implementation Notes:
# 
# 1. Security Group Referencing (Best Practice):
#    - ALB egress references EC2 security group ID (not CIDR blocks)
#    - EC2 ingress references ALB security group ID (not CIDR blocks)
#    - Dynamic: Works even if instance IPs change
#    - Stateful: Return traffic automatically allowed (TCP connection tracking)
#
# 2. ALB Ingress (0.0.0.0/0:443):
#    - Required for internet-facing ALB
#    - TLS encryption protects data in transit (SEC09-BP02)
#    - Standard pattern for public web services
#    - Optional: Add AWS WAF for additional protection (out of scope for dev)
#
# 3. ALB Egress (SG Reference):
#    - Least privilege: Only EC2 instances, not entire VPC CIDR
#    - Port 80: Nginx listens on HTTP (ALB terminates SSL)
#    - Alternative: Use HTTPS for ALB→EC2 if end-to-end encryption required (adds complexity)
#
# 4. EC2 Ingress (SG Reference):
#    - Zero-trust: EC2 instances NOT directly accessible from internet
#    - Only ALB can reach EC2 instances
#    - Port 80: Nginx HTTP (encryption handled by ALB)
#
# 5. EC2 Egress (Internet Access):
#    - Required for:
#      a) yum/dnf package updates (http/https)
#      b) CloudWatch metrics/logs (https)
#      c) Systems Manager (Session Manager) (https)
#    - Cost-optimized: Uses internet gateway (free) vs VPC endpoints ($14/month)
#    - Trade-off: Internet egress allowed but necessary for operations
#    - Enhancement: Restrict to AWS IP ranges (complex, not cost-effective)
#
# 6. VPC Endpoint Enhancement (Optional - Not Implemented for Cost):
#    If budget allows, replace internet egress with VPC endpoints:
#    
#    resource "aws_vpc_endpoint" "s3" {
#      vpc_id       = data.aws_vpc.default.id
#      service_name = "com.amazonaws.ap-southeast-1.s3"
#      # Gateway endpoint - FREE
#    }
#    
#    resource "aws_vpc_endpoint" "logs" {
#      vpc_id              = data.aws_vpc.default.id
#      service_name        = "com.amazonaws.ap-southeast-1.logs"
#      vpc_endpoint_type   = "Interface"
#      security_group_ids  = [aws_security_group.ec2_sg.id]
#      # Interface endpoint - $0.01/hour = $7.20/month per AZ
#    }
#    
#    Total cost: $14.40/month (2 AZ) - 43% increase in infrastructure cost
#    Trade-off: Highest security vs development budget constraints
#
# 7. Terraform Implementation:
#    module "alb_security_group" {
#      source = "app.terraform.io/ravi-panchal-org/security-group/aws"
#      version = "~> 5.3.1"
#      
#      name        = "ec2-alb-nginx-alb-sg"
#      description = "Security group for Application Load Balancer"
#      vpc_id      = data.aws_vpc.default.id
#      
#      ingress_rules = {
#        https_from_internet = {
#          description = "HTTPS from internet"
#          from_port   = 443
#          to_port     = 443
#          ip_protocol = "tcp"
#          cidr_ipv4   = "0.0.0.0/0"
#        }
#      }
#      
#      egress_rules = {
#        to_ec2_instances = {
#          description                  = "Forward to EC2 instances"
#          from_port                    = 80
#          to_port                      = 80
#          ip_protocol                  = "tcp"
#          referenced_security_group_id = module.ec2_security_group.security_group_id
#        }
#      }
#    }
#    
#    module "ec2_security_group" {
#      source = "app.terraform.io/ravi-panchal-org/security-group/aws"
#      version = "~> 5.3.1"
#      
#      name        = "ec2-alb-nginx-instance-sg"
#      description = "Security group for EC2 instances running Nginx"
#      vpc_id      = data.aws_vpc.default.id
#      
#      ingress_rules = {
#        http_from_alb = {
#          description                  = "HTTP from ALB only"
#          from_port                    = 80
#          to_port                      = 80
#          ip_protocol                  = "tcp"
#          referenced_security_group_id = module.alb_security_group.security_group_id
#        }
#      }
#      
#      egress_rules = {
#        https_outbound = {
#          description = "HTTPS for updates and AWS services"
#          from_port   = 443
#          to_port     = 443
#          ip_protocol = "tcp"
#          cidr_ipv4   = "0.0.0.0/0"
#        }
#        http_outbound = {
#          description = "HTTP for package repositories"
#          from_port   = 80
#          to_port     = 80
#          ip_protocol = "tcp"
#          cidr_ipv4   = "0.0.0.0/0"
#        }
#      }
#    }
#
# 8. Validation Tests:
#    # Test 1: Public HTTPS access (should succeed)
#    curl -k https://<alb-dns-name>
#    # Expected: HTTP 200, HTML content
#    
#    # Test 2: Direct EC2 HTTP access from internet (should fail - timeout)
#    curl --max-time 10 http://<ec2-public-ip>
#    # Expected: Connection timeout (no route to host)
#    
#    # Test 3: ALB to EC2 HTTP (internal - verified via health checks)
#    aws elbv2 describe-target-health --target-group-arn <tg-arn>
#    # Expected: Both targets "healthy" (proves ALB→EC2 communication)
#    
#    # Test 4: EC2 outbound HTTPS (should succeed)
#    aws ssm start-session --target <instance-id>
#    curl -I https://aws.amazon.com
#    # Expected: HTTP 200 (proves internet egress)
#
# 9. Security Compliance:
#    ✅ Zero-trust network isolation (EC2 not internet-accessible)
#    ✅ Least-privilege access (security group references, not broad CIDR)
#    ✅ Encryption in transit (HTTPS ALB → Internet, HTTP ALB → EC2 acceptable)
#    ✅ No unrestricted ingress to EC2 (ALB only)
#    ⚠️ EC2 internet egress allowed (necessary for operations, cost-optimized)
#
# 10. Cost Impact:
#     Security groups: $0 (free)
#     VPC endpoints (if implemented): $14.40/month
#
# 11. Future Enhancements (Post-MVP):
#     - VPC endpoints for AWS services (eliminate internet egress)
#     - AWS WAF on ALB (protect against common web attacks)
#     - AWS Network Firewall (advanced threat protection)
#     - GuardDuty (threat detection and continuous monitoring)
