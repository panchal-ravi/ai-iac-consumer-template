# Feature Specification: EC2 ALB Nginx Development Environment

**Feature Branch**: `001-ec2-alb-nginx`  
**Created**: 2025-01-29  
**Status**: Draft  
**Input**: User description: "Deploy a development environment for testing EC2 instances with Application Load Balancer. Serve basic static content via Nginx over HTTPS. Support minimal cost for development/testing purposes. Enable rapid prototyping and testing across multiple availability zones."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Access Application via HTTPS (Priority: P1)

As a developer, I need to access a web application through a secure HTTPS endpoint so that I can test application behavior in a production-like environment with proper security controls.

**Why this priority**: This is the core functionality - without a working HTTPS endpoint with load balancing, the entire infrastructure serves no purpose. This delivers immediate value for development testing.

**Independent Test**: Can be fully tested by navigating to the ALB DNS name via HTTPS in a browser and verifying that a basic web page loads, delivering a working secure web endpoint.

**Acceptance Scenarios**:

1. **Given** the infrastructure is deployed, **When** a user navigates to the ALB HTTPS endpoint, **Then** they see a static HTML page served from an EC2 instance
2. **Given** a user attempts HTTP access, **When** they navigate to the ALB HTTP endpoint, **Then** they are automatically redirected to HTTPS
3. **Given** multiple requests are made, **When** the ALB distributes traffic, **Then** requests are served from EC2 instances in different availability zones

---

### User Story 2 - Instance Health Monitoring (Priority: P2)

As a developer, I need the load balancer to automatically detect unhealthy instances and stop routing traffic to them so that my application remains available even when individual instances fail.

**Why this priority**: Health checking ensures reliability and demonstrates proper production patterns. While not required for basic functionality, it's essential for testing failure scenarios.

**Independent Test**: Can be tested by stopping Nginx on one EC2 instance and verifying that the ALB marks it unhealthy and routes all traffic to the healthy instance, proving resilience.

**Acceptance Scenarios**:

1. **Given** all instances are running, **When** the health check endpoint is queried, **Then** all instances report healthy status
2. **Given** one instance becomes unhealthy, **When** the ALB performs health checks, **Then** traffic is routed only to healthy instances
3. **Given** an unhealthy instance recovers, **When** health checks pass, **Then** the instance is automatically added back to the rotation

---

### User Story 3 - Secure Instance Access (Priority: P3)

As a developer, I need to access EC2 instances for troubleshooting without using SSH keys so that I can debug issues while maintaining security best practices.

**Why this priority**: While important for operational needs, the application can function without direct instance access. This enables debugging but isn't required for basic operation.

**Independent Test**: Can be tested by using AWS Systems Manager Session Manager to connect to an instance, execute commands, and view logs without requiring SSH keys or security group rules.

**Acceptance Scenarios**:

1. **Given** an EC2 instance is running, **When** a developer uses Systems Manager Session Manager, **Then** they can establish a secure shell session
2. **Given** a session is established, **When** the developer runs commands, **Then** they can view logs and troubleshoot issues
3. **Given** no SSH keys are configured, **When** attempting traditional SSH, **Then** access is denied

---

### Edge Cases

- What happens when both availability zones experience simultaneous failures?
- How does the system handle an SSL certificate that expires or is invalid?
- What occurs when all EC2 instances fail health checks simultaneously?
- How does the system behave when the target group has no healthy instances?
- What happens if the user data script fails during instance initialization?
- How are costs controlled if instances are accidentally left running?
- What occurs when the default VPC is missing or has insufficient subnets?

## Requirements *(mandatory)*

### Functional Requirements

#### Infrastructure Components

- **FR-001**: System MUST deploy exactly 2 EC2 instances across 2 different availability zones in ap-southeast-1 region
- **FR-002**: System MUST use t3.micro or t3.small instance types for cost optimization
- **FR-003**: System MUST deploy an internet-facing Application Load Balancer with both HTTP and HTTPS listeners
- **FR-004**: System MUST automatically install and configure Nginx web server on each EC2 instance via user data
- **FR-005**: System MUST serve a static HTML page that identifies which availability zone the serving instance is located in

#### Network Configuration

- **FR-006**: System MUST use the existing default VPC via data source lookup (no new VPC creation)
- **FR-007**: System MUST deploy resources across default subnets in ap-southeast-1a and ap-southeast-1b availability zones
- **FR-008**: System MUST create a security group for the ALB allowing inbound traffic on ports 80 and 443 from the internet (0.0.0.0/0)
- **FR-009**: System MUST create a security group for EC2 instances allowing inbound traffic on port 80 only from the ALB security group
- **FR-010**: System MUST configure the ALB with a target group that registers both EC2 instances

#### Security Requirements

- **FR-011**: System MUST enforce HTTPS by redirecting all HTTP (port 80) traffic to HTTPS (port 443)
- **FR-012**: System MUST configure an SSL/TLS certificate for the HTTPS listener
- **FR-013**: System MUST assign an IAM role to EC2 instances with permissions for AWS Systems Manager Session Manager access
- **FR-014**: EC2 instances MUST NOT have SSH key pairs configured
- **FR-015**: EC2 instances MUST NOT allow direct SSH access via security group rules
- **FR-016**: All resources MUST be tagged with Environment, Project, ManagedBy, Terraform, CostCenter, and Purpose tags

#### Health Monitoring

- **FR-017**: System MUST configure target group health checks on HTTP port 80 targeting the root path (/) or /health
- **FR-018**: Health check interval MUST be set to 30 seconds
- **FR-019**: System MUST automatically remove unhealthy instances from the load balancer rotation
- **FR-020**: System MUST support basic CloudWatch metrics for EC2 instances and ALB

#### Cost Optimization

- **FR-021**: Infrastructure MUST target monthly operating costs between $50-100 USD
- **FR-022**: System MUST use free tier eligible resources where possible
- **FR-023**: System MUST NOT deploy a NAT Gateway
- **FR-024**: System MUST use on-demand instances (spot instances are optional for future enhancement)

### Key Entities

- **EC2 Instance**: Compute resource running Nginx web server, deployed in a specific availability zone, registered with target group for health monitoring
- **Application Load Balancer**: Internet-facing load balancer distributing HTTPS traffic across EC2 instances in multiple availability zones
- **Target Group**: Logical grouping of EC2 instances with health check configuration for the ALB
- **Security Group (ALB)**: Network access control allowing public HTTP/HTTPS traffic to the load balancer
- **Security Group (EC2)**: Network access control allowing HTTP traffic only from the ALB security group
- **IAM Role**: Identity granting EC2 instances permissions for Systems Manager access without SSH keys
- **SSL/TLS Certificate**: Security credential enabling HTTPS encryption for the ALB listener
- **Static Content**: HTML page displaying availability zone information for testing traffic distribution

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can access the application via HTTPS within 5 seconds of entering the ALB DNS name in a browser
- **SC-002**: The ALB distributes traffic across instances in at least 2 availability zones as verified by the displayed AZ identifier
- **SC-003**: HTTP requests are automatically redirected to HTTPS with zero manual intervention required
- **SC-004**: When one EC2 instance is stopped, the application remains accessible with zero downtime
- **SC-005**: Health checks detect instance failures within 60 seconds and remove unhealthy instances from rotation
- **SC-006**: Developers can establish a Systems Manager session to any EC2 instance within 30 seconds without SSH keys
- **SC-007**: Monthly infrastructure costs remain below $100 USD based on AWS pricing calculator estimates
- **SC-008**: All infrastructure components deploy successfully via Terraform with zero manual configuration steps
- **SC-009**: The static HTML page loads within 2 seconds and correctly identifies the serving instance's availability zone
- **SC-010**: All security controls pass validation with no CRITICAL findings from security scanning tools

## Assumptions *(mandatory)*

1. The AWS account has a default VPC present in the ap-southeast-1 region
2. The default VPC has at least 2 subnets in different availability zones (ap-southeast-1a and ap-southeast-1b)
3. The AWS account has sufficient quota for 2 t3.micro/t3.small EC2 instances
4. SSL/TLS certificate will use a self-signed certificate or AWS Certificate Manager for testing purposes
5. HCP Terraform workspace is configured with valid AWS credentials with permissions to create EC2, ALB, IAM, and security group resources
6. The development environment does not require custom domain names or Route 53 DNS configuration
7. Basic internet connectivity is available for instances to download Nginx packages during initialization
8. ALB access logs are optional and will be enabled only if cost-effective for the development environment
9. The environment is intended for short-term testing and will be destroyed after validation to minimize costs
10. Systems Manager endpoints are available in the ap-southeast-1 region for Session Manager access

## Constraints *(mandatory)*

1. **Infrastructure**: Must use existing default VPC only - no new VPC creation permitted
2. **Cost**: Monthly costs must not exceed $100 USD - requires smallest viable instance types
3. **Security**: No SSH keys or direct SSH access allowed - Systems Manager only
4. **Region**: All resources must be deployed in ap-southeast-1 region exclusively
5. **Environment**: Development/testing environment only - not suitable for production workloads
6. **Availability Zones**: Must deploy across exactly 2 AZs (ap-southeast-1a and ap-southeast-1b)
7. **Instance Count**: Must deploy exactly 2 EC2 instances (one per AZ)
8. **Access Pattern**: Public access only via ALB - EC2 instances should not have direct public IPs if possible

## Dependencies *(mandatory)*

1. AWS account with default VPC configured in ap-southeast-1 region
2. HCP Terraform organization (ravi-panchal-org) with workspace configured
3. AWS credentials configured in HCP Terraform with appropriate IAM permissions
4. Terraform provider for AWS (hashicorp/aws)
5. Internet connectivity for EC2 instances to install Nginx packages
6. AWS Systems Manager service availability in ap-southeast-1 region
7. SSL/TLS certificate source (AWS Certificate Manager or self-signed)

## Out of Scope *(mandatory)*

1. Custom VPC creation with private subnets and NAT Gateways
2. Production-grade high availability with 3+ availability zones
3. Auto-scaling based on load or metrics
4. Custom domain names and Route 53 DNS configuration
5. CloudWatch Logs aggregation and centralized logging
6. ALB access logs (marked as optional, may be excluded for cost)
7. Spot instance configuration (on-demand instances only initially)
8. Database integration or persistent data storage
9. CI/CD pipeline integration
10. Container orchestration (ECS/EKS)
11. CloudFront CDN distribution
12. WAF (Web Application Firewall) rules
13. Backup and disaster recovery procedures
14. Multi-region deployment
15. Actual production deployment (terraform apply) - requires explicit user approval

## Risks *(optional)*

### Technical Risks

- **Risk**: Default VPC may not exist or may have insufficient subnets across required AZs
  - **Mitigation**: Validate VPC and subnet availability via Terraform data sources; fail fast with clear error messages

- **Risk**: User data script failure could result in EC2 instances without Nginx installed
  - **Mitigation**: Include error handling in user data; verify installation via health checks

- **Risk**: Self-signed SSL certificates will trigger browser warnings
  - **Mitigation**: Document expected browser warnings; provide option for ACM certificate if custom domain available

### Cost Risks

- **Risk**: Resources left running beyond testing period could exceed budget
  - **Mitigation**: Implement automatic tagging; document teardown procedures; automated destroy after validation

- **Risk**: Data transfer costs could exceed estimates with high-volume testing
  - **Mitigation**: Monitor CloudWatch billing alerts; limit testing scope; destroy resources promptly

### Security Risks

- **Risk**: Public ALB with self-signed certificate may be vulnerable to man-in-the-middle attacks
  - **Mitigation**: Acceptable for development environment; document limitations; recommend ACM for any production use

- **Risk**: Security group misconfiguration could expose EC2 instances directly to internet
  - **Mitigation**: Use security group dependencies; validate ingress rules allow only ALB traffic

## Configuration Values *(mandatory)*

### Resource Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| AWS Region | ap-southeast-1 | Primary region for deployment as specified |
| Environment | development | Non-production testing environment |
| Instance Type | t3.micro or t3.small | Cost-optimized, free-tier eligible options |
| Instance Count | 2 | One instance per availability zone |
| Availability Zones | ap-southeast-1a, ap-southeast-1b | Multi-AZ deployment for testing failover |
| VPC | Default VPC (data source) | Use existing infrastructure, no new VPC |

### Network Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| ALB Scheme | internet-facing | Public access required for testing |
| ALB Listeners | HTTP (80), HTTPS (443) | Standard web ports with redirect |
| Target Group Port | 80 | Nginx default HTTP port |
| Health Check Path | / or /health | Simple availability check |
| Health Check Interval | 30 seconds | Balance between detection speed and cost |
| Health Check Timeout | 5 seconds | Adequate for simple response |
| Healthy Threshold | 2 | Two consecutive successes to mark healthy |
| Unhealthy Threshold | 2 | Two consecutive failures to mark unhealthy |

### Security Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| ALB Security Group Ingress | 0.0.0.0/0 on ports 80, 443 | Public web access |
| EC2 Security Group Ingress | ALB security group on port 80 | Restrict to ALB traffic only |
| SSH Access | Disabled (no keys, no security group rules) | Use Systems Manager instead |
| IAM Policy | AmazonSSMManagedInstanceCore | Minimal permissions for Session Manager |

### Tagging Strategy

| Tag Key | Tag Value | Purpose |
|---------|-----------|---------|
| Environment | development | Identify environment type |
| Project | ec2-alb-nginx-demo | Associate with project |
| ManagedBy | terraform | Indicate infrastructure as code |
| Terraform | true | Flag for IaC management |
| CostCenter | development | Track cost allocation |
| Purpose | testing | Document intended use |

### Cost Targets

| Component | Estimated Monthly Cost | Notes |
|-----------|----------------------|-------|
| EC2 Instances (2x t3.micro) | $15-20 | 24/7 operation |
| Application Load Balancer | $20-25 | Base hourly + LCU charges |
| Data Transfer | $5-10 | Minimal test traffic |
| Systems Manager | $0 | No additional charges |
| **Total Estimated** | **$50-100** | Within budget target |

## Validation Criteria *(mandatory)*

### Pre-Deployment Validation

1. Terraform configuration passes `terraform validate`
2. Terraform plan completes without errors
3. All required variables are defined with appropriate defaults or descriptions
4. Security scanning identifies no CRITICAL severity findings
5. Code quality assessment scores above 70% for development standards

### Post-Deployment Validation

1. Both EC2 instances are running and pass health checks
2. ALB DNS name resolves and responds to HTTPS requests
3. HTTP requests redirect to HTTPS automatically
4. Static HTML page displays correct availability zone information
5. Traffic distributes across both availability zones
6. Systems Manager Session Manager can connect to both instances
7. No SSH access is possible via security groups or key pairs
8. All resources are tagged correctly according to tagging strategy
9. CloudWatch metrics are available for EC2 and ALB resources
10. Infrastructure can be destroyed cleanly without manual intervention

### Security Validation

1. Security group rules allow only specified ports and sources
2. EC2 instances have no public IP addresses or have restricted access
3. IAM role follows least privilege principle
4. SSL/TLS certificate is properly configured on HTTPS listener
5. HTTP to HTTPS redirect functions correctly
6. No wildcard permissions in IAM policies
7. All resources deployed in specified region only

### Cost Validation

1. AWS pricing calculator estimate is below $100/month
2. All instances use t3.micro or t3.small types only
3. No NAT Gateway or other expensive resources deployed
4. Resources can be destroyed to stop ongoing charges

## Notes *(optional)*

- This is the first infrastructure deployment using this workflow
- Focus remains on simplicity and cost optimization for development testing
- The specification intentionally excludes production-grade features like auto-scaling, multi-region, and advanced monitoring to keep costs minimal
- SSL/TLS certificate implementation (self-signed vs ACM) can be determined during planning phase based on available tooling
- If default VPC is missing, this specification becomes invalid and requires user consultation
- Terraform module selection will prioritize private registry first, then fall back to public registry with user approval
- All implementation decisions should favor cost reduction while maintaining security best practices
