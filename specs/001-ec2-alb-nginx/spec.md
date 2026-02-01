# Feature Specification: AWS EC2 Infrastructure with Application Load Balancer and Nginx

**Feature Branch**: `001-ec2-alb-nginx`  
**Created**: 2025-01-10  
**Status**: Draft  
**Input**: User description: "Provision EC2 instances with Application Load Balancer and Nginx in AWS ap-southeast-1 region"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Basic Infrastructure (Priority: P1)

A DevOps engineer needs to provision a highly available web infrastructure in AWS ap-southeast-1 region using the existing default VPC. The infrastructure should include compute resources distributed across multiple availability zones to ensure fault tolerance.

**Why this priority**: This is the foundation of the entire infrastructure. Without compute and networking resources, no other components can function. This delivers the core infrastructure value.

**Independent Test**: Can be fully tested by provisioning the EC2 instances and verifying they are running in different availability zones within the default VPC. Delivers testable infrastructure that can be SSH-accessed and validated independently.

**Acceptance Scenarios**:

1. **Given** AWS credentials with appropriate permissions, **When** infrastructure is provisioned, **Then** two t3.micro EC2 instances are created in different availability zones
2. **Given** the default VPC exists in ap-southeast-1, **When** infrastructure is deployed, **Then** EC2 instances use existing default subnets in separate availability zones
3. **Given** EC2 instances are running, **When** checking instance metadata, **Then** each instance is located in a different availability zone (ap-southeast-1a, ap-southeast-1b, or ap-southeast-1c)

---

### User Story 2 - Configure Web Server with HTTPS (Priority: P1)

A DevOps engineer needs to install and configure Nginx web server on the EC2 instances to serve a basic static HTML test page. The web server must support HTTPS using a self-signed TLS certificate for the domain "web.demo.com".

**Why this priority**: This is essential functionality that makes the infrastructure actually serve content. Without the web server, the infrastructure has no practical use. The HTTPS requirement is part of the core security posture.

**Independent Test**: Can be tested independently by accessing any EC2 instance directly and verifying Nginx serves the test page with the self-signed certificate. Delivers a working web server that can be validated without the load balancer.

**Acceptance Scenarios**:

1. **Given** EC2 instances are running, **When** Nginx is installed and configured, **Then** Nginx service is active and listening on port 80
2. **Given** a self-signed TLS certificate for "web.demo.com" is generated, **When** accessing the web server, **Then** the certificate is valid for the specified domain
3. **Given** Nginx is configured with a test page, **When** making an HTTP request to any instance, **Then** a basic static HTML page is returned with HTTP 200 status
4. **Given** the TLS certificate is configured, **When** the certificate details are inspected, **Then** it shows "web.demo.com" as the Common Name or Subject Alternative Name

---

### User Story 3 - Import Certificate to AWS Certificate Manager (Priority: P1)

A DevOps engineer needs to import the self-signed TLS certificate into AWS Certificate Manager (ACM) so it can be used by the Application Load Balancer for HTTPS termination. Since this is a self-signed certificate for development purposes, no domain validation is required.

**Why this priority**: This is a prerequisite for the load balancer to terminate HTTPS connections. Without the certificate in ACM, the ALB cannot be configured with HTTPS listener. This bridges the web server and load balancer components.

**Independent Test**: Can be tested by verifying the certificate appears in ACM console and contains the correct domain name and validity period. Delivers a certificate resource that can be referenced by other AWS services.

**Acceptance Scenarios**:

1. **Given** a self-signed TLS certificate and private key exist, **When** importing to ACM, **Then** the certificate is successfully stored in ACM for the ap-southeast-1 region
2. **Given** the certificate is imported, **When** viewing certificate details in ACM, **Then** it shows "web.demo.com" as the domain name
3. **Given** the certificate is in ACM, **When** querying the certificate ARN, **Then** the ARN can be retrieved and used for ALB configuration
4. **Given** this is a self-signed certificate, **When** imported to ACM, **Then** no domain validation checks are performed or required

---

### User Story 4 - Deploy Application Load Balancer with HTTPS (Priority: P2)

A DevOps engineer needs to create an Application Load Balancer that accepts HTTPS traffic on port 443 and routes it to the backend EC2 instances using HTTP on port 80. The ALB should use the certificate from ACM for TLS termination.

**Why this priority**: This provides the production-like entry point for external traffic with TLS termination at the load balancer layer. This is the standard architecture pattern for secure web applications but can be tested after the backend is proven functional.

**Independent Test**: Can be tested by accessing the ALB's DNS endpoint over HTTPS and verifying it returns the test page from the backend instances. Delivers a fully functional load balancer that can be validated independently of health checks and target groups.

**Acceptance Scenarios**:

1. **Given** EC2 instances and ACM certificate exist, **When** ALB is created, **Then** the ALB is internet-facing and provisioned across multiple availability zones
2. **Given** the ALB is created, **When** configuring the HTTPS listener, **Then** it listens on port 443 and uses the certificate from ACM
3. **Given** the HTTPS listener is configured, **When** making an HTTPS request to the ALB DNS name, **Then** TLS termination occurs at the ALB using the "web.demo.com" certificate
4. **Given** the ALB listener is configured, **When** traffic is routed to backend, **Then** the ALB communicates with EC2 instances using HTTP on port 80

---

### User Story 5 - Configure Health Checks and Target Group (Priority: P2)

A DevOps engineer needs to configure a target group with health checks to monitor the availability of the backend EC2 instances. The ALB should automatically route traffic only to healthy instances.

**Why this priority**: This adds reliability and fault tolerance to the infrastructure. While important for production operations, the basic routing can function without sophisticated health checking. This can be validated after basic ALB routing works.

**Independent Test**: Can be tested by stopping Nginx on one instance and verifying the ALB only routes traffic to the healthy instance. Delivers observable fault tolerance that can be validated through controlled failure scenarios.

**Acceptance Scenarios**:

1. **Given** EC2 instances are running Nginx, **When** a target group is created, **Then** both instances are registered as targets
2. **Given** health checks are configured, **When** Nginx is running on an instance, **Then** the health check reports the target as healthy
3. **Given** health checks are configured, **When** Nginx is stopped on an instance, **Then** the health check reports the target as unhealthy and ALB stops routing traffic to it
4. **Given** multiple targets exist, **When** the ALB receives requests, **Then** traffic is distributed among healthy targets only
5. **Given** health checks are running, **When** checking target group status, **Then** each target shows its current health status (healthy/unhealthy)

---

### User Story 6 - Configure Security Groups (Priority: P1)

A DevOps engineer needs to configure network security groups to control traffic flow between the internet, ALB, and EC2 instances. The security posture should allow HTTPS from internet to ALB, HTTP from ALB to EC2, and block all other unnecessary traffic.

**Why this priority**: Security is a critical requirement that must be implemented from the start. Without proper security groups, the infrastructure is either non-functional (overly restrictive) or insecure (overly permissive). This is foundational to the security architecture.

**Independent Test**: Can be tested by verifying firewall rules using AWS console and testing connectivity from different sources (internet to ALB, ALB to instances, direct attempts to instances). Delivers measurable security controls that can be validated through connection attempts.

**Acceptance Scenarios**:

1. **Given** an ALB security group exists, **When** configured, **Then** it allows inbound HTTPS traffic on port 443 from the internet (0.0.0.0/0)
2. **Given** an EC2 security group exists, **When** configured, **Then** it allows inbound HTTP traffic on port 80 only from the ALB security group
3. **Given** security groups are configured, **When** attempting direct internet access to EC2 instances on port 80, **Then** the connection is blocked
4. **Given** security groups are configured, **When** ALB sends HTTP requests to EC2 instances, **Then** the connection is allowed through the security group rules
5. **Given** security groups are applied, **When** reviewing outbound rules, **Then** instances can make necessary outbound connections for updates and dependencies

---

### Edge Cases

- What happens when one availability zone becomes unavailable? (System should continue operating with instances in remaining zones)
- How does the system handle when both EC2 instances are unhealthy? (ALB should return 503 Service Unavailable errors)
- What happens if the certificate expires? (HTTPS connections will fail with certificate validation errors; monitoring should alert before expiration)
- How does the system behave during EC2 instance maintenance or reboots? (ALB should mark instance as unhealthy and route traffic to healthy instances)
- What happens when the default VPC or subnets are not available in ap-southeast-1? (Infrastructure provisioning should fail with clear error message)
- How does the system handle SSL/TLS protocol version mismatches? (ALB should use modern TLS protocols by default; clients with outdated protocols may fail to connect)
- What happens if an instance runs out of disk space or memory? (Health checks should fail, causing ALB to stop routing traffic to that instance)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provision exactly two t3.micro EC2 instances in the AWS ap-southeast-1 region
- **FR-002**: System MUST place each EC2 instance in a different availability zone within ap-southeast-1 for high availability
- **FR-003**: System MUST use the existing default VPC and its default subnets in ap-southeast-1 for all resources
- **FR-004**: System MUST install and configure Nginx web server on each EC2 instance
- **FR-005**: System MUST configure Nginx to serve HTTP traffic on port 80
- **FR-006**: System MUST generate a self-signed TLS certificate for the domain "web.demo.com" using the Terraform TLS provider
- **FR-007**: System MUST import the self-signed certificate into AWS Certificate Manager (ACM) in ap-southeast-1 region
- **FR-008**: System MUST create an internet-facing Application Load Balancer across multiple availability zones
- **FR-009**: System MUST configure ALB with an HTTPS listener on port 443 using the ACM certificate
- **FR-010**: System MUST configure ALB to perform TLS termination, then forward traffic to backend instances via HTTP on port 80
- **FR-011**: System MUST create a target group with both EC2 instances registered as targets
- **FR-012**: System MUST configure health checks on the target group to monitor instance availability
- **FR-013**: System MUST deploy a basic static HTML test page on each EC2 instance for verification
- **FR-014**: System MUST create a security group for the ALB that allows inbound HTTPS traffic (port 443) from the internet
- **FR-015**: System MUST create a security group for EC2 instances that allows inbound HTTP traffic (port 80) only from the ALB security group
- **FR-016**: System MUST block direct internet access to EC2 instances on port 80
- **FR-017**: Infrastructure MUST be provisioned using Terraform with state managed in HCP Terraform (organization: ravi-panchal-org)
- **FR-018**: Infrastructure MUST use the workspace "sandbox_workspace" in the "Default Project" within HCP Terraform
- **FR-019**: System SHOULD search private Terraform registry first for required modules, then fall back to public registry with user approval
- **FR-020**: System MUST use the latest version of Terraform available in HCP Terraform
- **FR-021**: System MUST follow AWS security best practices including least privilege IAM policies for any required roles
- **FR-022**: System MUST configure appropriate resource tags for cost tracking and management
- **FR-023**: Self-signed certificate MUST NOT require domain validation or DNS configuration
- **FR-024**: Infrastructure MUST be optimized for development environment use cases with minimal cost considerations
- **FR-025**: All security group rules MUST follow the principle of least privilege, allowing only necessary traffic
- **FR-026**: Health checks MUST use HTTP protocol to verify instance health on port 80
- **FR-027**: Target group MUST distribute traffic among healthy instances only

### Key Entities

- **EC2 Instance**: Virtual compute resource running Nginx web server; attributes include instance type (t3.micro), availability zone placement, security group membership, and network interface configuration
- **Application Load Balancer**: Layer 7 load balancer that distributes HTTPS traffic across instances; attributes include DNS name, availability zones, listener configuration (port 443 HTTPS), and associated security groups
- **Target Group**: Logical grouping of EC2 instances for load balancing; attributes include health check configuration (protocol HTTP, port 80, path), registered targets, and health status of each target
- **TLS Certificate**: Self-signed X.509 certificate for "web.demo.com"; attributes include private key, public certificate, expiration date, and ACM ARN after import
- **Security Group (ALB)**: Network firewall rules for load balancer; attributes include inbound rule allowing HTTPS (443) from internet, outbound rules for forwarding to instances
- **Security Group (EC2)**: Network firewall rules for instances; attributes include inbound rule allowing HTTP (80) from ALB security group only, outbound rules for internet access
- **VPC and Subnets**: Existing default network infrastructure in ap-southeast-1; attributes include CIDR blocks, availability zone mappings, and internet gateway configuration
- **Static HTML Page**: Simple test web page served by Nginx; attributes include file path, content, and MIME type

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Infrastructure provisioning completes successfully within 10 minutes from Terraform apply
- **SC-002**: HTTPS requests to the ALB endpoint return the test HTML page with HTTP 200 status within 2 seconds
- **SC-003**: System maintains 100% availability when one EC2 instance is unhealthy or unavailable
- **SC-004**: ALB successfully performs TLS termination using the self-signed certificate for "web.demo.com"
- **SC-005**: Direct HTTP requests to EC2 instances from the internet are blocked (connection refused or timeout)
- **SC-006**: Health checks detect unhealthy instances within 30 seconds of failure and stop routing traffic to them
- **SC-007**: Infrastructure costs remain under $50 per month for continuous operation (development environment optimization)
- **SC-008**: All security group rules can be audited and verified to follow least privilege principle
- **SC-009**: Terraform state is successfully stored and managed in HCP Terraform workspace without conflicts
- **SC-010**: Infrastructure can be destroyed and reprovisioned without manual intervention or configuration drift
- **SC-011**: Certificate validation in browser shows correct domain "web.demo.com" when accessing ALB endpoint (with expected self-signed warnings)
- **SC-012**: 100% of requests to healthy instances receive successful responses through the ALB
- **SC-013**: System distributes traffic evenly across healthy instances under normal conditions

## Assumptions *(mandatory)*

- AWS credentials with sufficient permissions (EC2, VPC, ACM, ELB, IAM read access) are configured in HCP Terraform workspace
- Default VPC exists in ap-southeast-1 region and has not been deleted or heavily modified
- At least two availability zones are available in ap-southeast-1 with default subnets
- HCP Terraform organization "ravi-panchal-org" exists and user has access
- Workspace "sandbox_workspace" exists within "Default Project" or can be created
- Internet gateway is attached to the default VPC for outbound connectivity
- AWS region ap-southeast-1 supports t3.micro instance type
- Terraform TLS provider is available and can generate RSA or ECDSA keys
- ACM in ap-southeast-1 can import self-signed certificates without validation
- Users understand self-signed certificates will show browser warnings
- Development environment implies no strict SLA or production-level logging requirements
- Basic static HTML content is sufficient for testing (no dynamic content or databases required)
- SSH access to EC2 instances is not required for this feature (can be added separately if needed)
- Nginx is installed via user data script or configuration management during instance bootstrap
- Health check endpoint will be the root path "/" on port 80
- Standard AWS service quotas are sufficient (at least 2 EC2 instances, 1 ALB, etc.)
- Cost optimization focuses on instance type selection (t3.micro) rather than reserved instances or savings plans
- Users accept that self-signed certificates are not suitable for production use

## Dependencies *(mandatory)*

- AWS account with active subscription
- HCP Terraform account with organization "ravi-panchal-org" configured
- Terraform TLS provider for certificate generation
- Terraform AWS provider for resource provisioning
- Default VPC must exist in ap-southeast-1 region (AWS creates this by default for new accounts)
- Availability zones in ap-southeast-1 must be operational
- Required Terraform modules must be available in private or public registry
- AWS service quotas must allow creation of: 2 EC2 instances, 1 Application Load Balancer, 1 target group, multiple security groups
- Internet connectivity from HCP Terraform to AWS API endpoints
- User approval process for falling back to public Terraform registry modules

## Out of Scope *(mandatory)*

- Domain name registration or DNS configuration (using self-signed cert only)
- Domain validation for certificates (self-signed, no validation needed)
- Auto-scaling of EC2 instances based on load
- CloudWatch alarms and monitoring dashboards
- Centralized logging (CloudWatch Logs, ELK stack, etc.)
- Backup and disaster recovery procedures
- Database provisioning or data persistence layer
- Content Delivery Network (CDN) or CloudFront integration
- WAF (Web Application Firewall) rules
- SSH bastion host or remote access configuration
- Configuration management tools (Ansible, Chef, Puppet)
- Container orchestration (ECS, EKS, Kubernetes)
- CI/CD pipeline integration
- Blue-green or canary deployment strategies
- Production-grade monitoring and alerting
- Compliance certifications (PCI-DSS, HIPAA, SOC2, etc.)
- Multi-region deployment or global load balancing
- VPN or private connectivity options
- Custom VPC creation (using existing default VPC)
- IPv6 support
- Detailed cost allocation tags or FinOps reporting
- Performance testing or load testing
- Security scanning or vulnerability assessments
- Secrets management (AWS Secrets Manager, HashiCorp Vault)
- IAM role creation for EC2 instances (unless specifically required for functionality)
- Route53 hosted zone or DNS records

## Constraints *(mandatory)*

- MUST use AWS region ap-southeast-1 exclusively
- MUST use t3.micro instance type (no larger instance types)
- MUST use existing default VPC and subnets (cannot create custom VPC)
- MUST use exactly 2 EC2 instances (no more, no fewer)
- MUST place instances in exactly 2 different availability zones
- MUST use self-signed certificate (not CA-signed or Let's Encrypt)
- MUST use domain name "web.demo.com" for certificate
- MUST use HCP Terraform organization "ravi-panchal-org"
- MUST use workspace "sandbox_workspace" in "Default Project"
- MUST terminate TLS at ALB level (not at instance level)
- MUST allow ONLY HTTPS (port 443) on ALB from internet
- MUST use HTTP (port 80) between ALB and EC2 instances
- MUST prioritize minimal cost for development environment
- MUST NOT expose EC2 instances directly to internet on port 80
- MUST NOT require domain validation or DNS ownership verification
- MUST use Terraform as the exclusive infrastructure-as-code tool
- MUST search private registry before public registry for modules
- MUST obtain user approval before using public registry modules
- Certificate generation MUST use Terraform TLS provider (not external tools)
- Cannot modify or replace default VPC infrastructure
- Infrastructure must be reproducible through Terraform (no manual AWS console changes)
- Security groups must follow AWS security best practices
- Resources must support teardown without data loss concerns (stateless)

## Risks *(mandatory)*

| Risk | Impact | Mitigation |
|------|--------|------------|
| Default VPC does not exist or has been deleted in ap-southeast-1 | High - Infrastructure cannot be provisioned | Document requirement to check VPC existence before provisioning; provide error handling and clear error messages |
| Only one availability zone available in ap-southeast-1 | Medium - Reduces high availability benefits | Check AZ availability during planning; document fallback to single-AZ deployment if necessary |
| t3.micro instance type unavailable or restricted in region | Medium - Cannot provision requested instance type | Validate instance type availability in pre-flight checks; document alternative instance types |
| Self-signed certificate causes browser warnings and user confusion | Low - Expected behavior for self-signed certs | Document expected warnings; provide instructions for accepting certificate in browsers for testing |
| Certificate expiration after default validity period | Medium - HTTPS will fail when cert expires | Document certificate rotation procedures; consider setting longer validity period (e.g., 5 years for dev) |
| AWS service quotas insufficient for required resources | Medium - Provisioning will fail | Check service quotas before provisioning; document how to request quota increases |
| Cost exceeds expected $50/month due to data transfer or other charges | Medium - Budget overrun | Monitor costs weekly; document estimated costs for different usage patterns; set up billing alerts |
| Health checks fail intermittently due to instance resource constraints | Medium - Unnecessary failovers and traffic disruption | Tune health check thresholds; monitor instance CPU and memory utilization |
| Both EC2 instances become unhealthy simultaneously | High - Complete service outage | Document monitoring procedures; consider adding more instances if reliability requirements increase |
| HCP Terraform workspace lacks necessary AWS credentials or permissions | High - Cannot provision any infrastructure | Validate credentials and permissions before starting; document required IAM permissions |
| Private registry modules incompatible with public registry fallback | Medium - Delays provisioning workflow | Test module compatibility during planning phase; document required module versions |
| Network ACLs on default VPC block required traffic | Medium - Services cannot communicate | Document default VPC network ACL requirements; provide troubleshooting steps |
| Instance user data script fails to install Nginx properly | High - Web server unavailable | Implement retry logic in user data; add validation checks; document manual installation steps |
| Regional service outage in ap-southeast-1 | High - Cannot provision or access infrastructure | Document that this is accepted risk for development; no multi-region failover planned |
| Terraform state corruption or conflicts in HCP Terraform | High - Cannot manage infrastructure | Use HCP Terraform state locking; avoid concurrent applies; document state recovery procedures |

## Notes *(optional)*

### Development Environment Considerations

This infrastructure is explicitly designed for development and testing purposes. The use of self-signed certificates, minimal redundancy (2 instances), and cost optimization (t3.micro) reflect this intent. For production use, the following enhancements would be recommended:

- CA-signed certificates with proper domain validation
- Auto-scaling groups with minimum 3 instances across 3 availability zones  
- Larger instance types based on load testing
- CloudWatch monitoring and alerting
- Centralized logging
- WAF and DDoS protection
- Backup and disaster recovery procedures

### Certificate Management

The self-signed certificate will display browser warnings (NET::ERR_CERT_AUTHORITY_INVALID or similar). This is expected behavior and does not indicate a problem with the infrastructure. For testing purposes:

- Chrome: Click "Advanced" → "Proceed to [site] (unsafe)"
- Firefox: Click "Advanced" → "Accept the Risk and Continue"
- Safari: Click "Show Details" → "visit this website"

### Module Strategy Details

The requirement to search private registry first supports organizational reuse and standardization. If suitable modules exist in the private registry, they should be used to ensure consistency with organizational standards. Fallback to public registry requires approval to ensure:

- Module security has been reviewed
- Module licensing is acceptable
- Module maintenance and support is adequate
- Module aligns with organizational standards

### Resource Tagging Strategy

All provisioned resources should include standard tags for management and cost allocation:

- Environment: "development"
- Project: "ec2-alb-nginx"
- ManagedBy: "terraform"
- Owner: [team or individual]
- CostCenter: [if applicable]

### Testing Recommendations

To validate the infrastructure after provisioning:

1. Verify EC2 instances are running in different AZs
2. Access ALB DNS name via HTTPS in browser (accept certificate warning)
3. Confirm test HTML page loads successfully
4. Check target group shows both instances as healthy
5. Stop Nginx on one instance and verify ALB continues serving traffic
6. Verify direct HTTP access to instances is blocked from internet
7. Review security group rules in AWS console
8. Check Terraform state in HCP Terraform workspace

### Potential Future Enhancements

While out of scope for this feature, the following enhancements could be considered in future iterations:

- Custom domain with Route53 and CA-signed certificate
- Auto-scaling based on CPU or request metrics
- CloudWatch dashboard for monitoring
- S3 bucket for access logs
- WAF rules for common web attacks
- Container-based deployment (ECS/EKS) instead of VMs
- Blue-green deployment capability
- Database layer (RDS) for stateful data
- ElastiCache for session management
- CloudFront CDN for global distribution
