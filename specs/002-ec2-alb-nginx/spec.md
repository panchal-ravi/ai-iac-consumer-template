# Feature Specification: EC2 Infrastructure with ALB and Nginx

**Feature Branch**: `002-ec2-alb-nginx`  
**Created**: 2025-02-01  
**Status**: Draft  
**Input**: User description: "EC2 Instance with ALB and Nginx - Provision EC2 instances across 2 AZs in ap-southeast-1 with Application Load Balancer, HTTPS support using self-signed TLS certificate, Nginx web server, and comprehensive security controls"  
**GitHub Issue**: #37

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Access Secure Web Application (Priority: P1)

As an infrastructure operator, I need to deploy a highly available web infrastructure accessible via HTTPS so that I can serve web content securely across multiple availability zones.

**Why this priority**: This is the core value proposition - establishing secure, encrypted access to the web infrastructure. Without this, the feature delivers no value.

**Independent Test**: Can be fully tested by accessing the load balancer DNS name via HTTPS in a browser and verifying the connection is secure (certificate present, though self-signed) and content is served. Delivers immediate value as a working, secure web endpoint.

**Acceptance Scenarios**:

1. **Given** the infrastructure is deployed, **When** I access the ALB DNS name using HTTPS protocol, **Then** the connection establishes successfully with TLS encryption
2. **Given** I access the application via HTTPS, **When** the page loads, **Then** I see the test page content served by Nginx
3. **Given** the ALB is configured, **When** I attempt to access via HTTP, **Then** the connection is rejected or redirected to HTTPS

---

### User Story 2 - Verify High Availability Configuration (Priority: P2)

As a DevOps engineer, I need to verify that instances are distributed across multiple availability zones so that the application remains available even if one availability zone experiences issues.

**Why this priority**: High availability is a key architectural requirement but secondary to basic functionality. The infrastructure can function with one AZ but is more resilient with two.

**Independent Test**: Can be tested by checking EC2 console to confirm instances are in different AZs (ap-southeast-1a and ap-southeast-1b), then simulating failure of one instance and verifying the ALB continues serving traffic from the remaining instance.

**Acceptance Scenarios**:

1. **Given** the infrastructure is deployed, **When** I check the EC2 instance locations, **Then** I see instances distributed across ap-southeast-1a and ap-southeast-1b
2. **Given** both instances are running, **When** one instance becomes unhealthy, **Then** the ALB automatically routes traffic only to the healthy instance
3. **Given** an instance is terminated, **When** I access the application, **Then** there is no service interruption

---

### User Story 3 - Validate Security Controls (Priority: P2)

As a security engineer, I need to validate that all security controls are properly configured so that the infrastructure meets encryption and network isolation requirements.

**Why this priority**: Security validation is critical but depends on the infrastructure existing first. Can be independently tested once deployed.

**Independent Test**: Can be tested by running security validation checks: verify TLS certificate in ACM, test security group rules block unauthorized access, confirm IAM roles follow least privilege, and validate no HTTP-only access is possible.

**Acceptance Scenarios**:

1. **Given** the infrastructure is deployed, **When** I check AWS Certificate Manager, **Then** I see the self-signed certificate for web.demo.com imported and available
2. **Given** security groups are configured, **When** I attempt to access EC2 instances directly (not via ALB), **Then** the connection is blocked
3. **Given** the ALB is configured, **When** I inspect the listener configuration, **Then** only HTTPS (port 443) is enabled
4. **Given** IAM roles are configured, **When** I review permissions, **Then** each role has only the minimum required permissions

---

### User Story 4 - Deploy with Cost Optimization (Priority: P3)

As a project manager, I need the infrastructure to use cost-effective instance types and configurations so that development environment costs remain minimal.

**Why this priority**: Cost optimization is important for ongoing operations but not essential for initial functionality. Can be verified and adjusted post-deployment.

**Independent Test**: Can be tested by reviewing the deployed infrastructure configuration, checking instance types are t3.micro or similar, verifying no unnecessary resources were created, and monitoring AWS Cost Explorer for the first billing cycle.

**Acceptance Scenarios**:

1. **Given** the infrastructure is deployed, **When** I check the EC2 instance types, **Then** I see cost-effective instance types suitable for development (t3.micro, t3.small, or t2.micro)
2. **Given** the infrastructure is running, **When** I review the resource inventory, **Then** no unnecessary resources (extra EIPs, NAT gateways, etc.) are present
3. **Given** the infrastructure uses the default VPC, **When** I verify the network configuration, **Then** no new VPC resources were created unnecessarily

---

### Edge Cases

- What happens when both EC2 instances fail simultaneously? (ALB should return 503 Service Unavailable)
- How does the system handle certificate expiration? (Self-signed certificates don't auto-renew; manual regeneration required)
- What happens if the default VPC doesn't exist in ap-southeast-1? (Deployment should fail with clear error message)
- How does the system handle reaching EC2 instance limits in the region? (Deployment should fail with quota error)
- What happens when one AZ is unavailable during deployment? (Deployment should complete in the available AZ, with warning about reduced redundancy)
- How does the ALB behave when all target instances are unhealthy? (Returns 503 and stops routing traffic)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provision EC2 instances in exactly 2 different availability zones within the ap-southeast-1 region
- **FR-002**: System MUST create an Application Load Balancer that distributes traffic across all healthy EC2 instances
- **FR-003**: System MUST generate a self-signed TLS certificate for the domain "web.demo.com" using the Terraform TLS provider
- **FR-004**: System MUST import the generated TLS certificate into AWS Certificate Manager without requiring domain validation
- **FR-005**: System MUST configure the ALB with an HTTPS listener (port 443) using the imported certificate
- **FR-006**: System MUST install and configure Nginx web server on all EC2 instances
- **FR-007**: System MUST create a basic static test page served by Nginx for validation purposes
- **FR-008**: System MUST use the existing default VPC in ap-southeast-1 region (via Terraform data source)
- **FR-009**: System MUST configure security groups that allow HTTPS traffic (port 443) to the ALB
- **FR-010**: System MUST configure security groups that allow traffic from ALB to EC2 instances on Nginx port (80 or 443)
- **FR-011**: System MUST block direct public access to EC2 instances (only ALB can communicate with instances)
- **FR-012**: System MUST use IAM roles with least privilege access for EC2 instances
- **FR-013**: System MUST configure the ALB health check to verify Nginx availability
- **FR-014**: System MUST use cost-effective instance types appropriate for development environment
- **FR-015**: System MUST tag all resources with environment tag "development"
- **FR-016**: Infrastructure code MUST pass Terraform validation (terraform validate)
- **FR-017**: Infrastructure code MUST be deployable to HCP Terraform workspace "sandbox_ec2_workspace" in organization "ravi-panchal-org"

### Key Entities

- **EC2 Instance**: Compute resource running Nginx web server; deployed across 2 availability zones; configured with security groups restricting access to ALB only; runs user data script to install and configure Nginx

- **Application Load Balancer (ALB)**: Layer 7 load balancer; distributes HTTPS traffic across healthy EC2 instances; configured with HTTPS listener on port 443; performs health checks on target instances; provides single entry point for users

- **TLS Certificate**: Self-signed certificate for domain "web.demo.com"; generated by Terraform TLS provider; imported into AWS Certificate Manager; used by ALB for HTTPS termination

- **Security Group (ALB)**: Network access control for load balancer; allows inbound HTTPS (port 443) from internet; allows outbound to EC2 instances on Nginx port

- **Security Group (EC2)**: Network access control for instances; allows inbound traffic only from ALB security group; blocks direct internet access; allows outbound for instance updates and external communication

- **Target Group**: Logical grouping of EC2 instances; attached to ALB; defines health check parameters; routes traffic to healthy instances only

- **Default VPC**: Existing AWS VPC infrastructure; sourced via Terraform data source; provides subnets across availability zones; no new VPC creation required

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Infrastructure is accessible via HTTPS through the ALB DNS name within 60 seconds of deployment completion
- **SC-002**: Nginx test page loads successfully via HTTPS with valid TLS handshake (even though certificate is self-signed)
- **SC-003**: Application remains available when one EC2 instance is terminated or becomes unhealthy (zero downtime during single-instance failure)
- **SC-004**: No direct HTTP traffic is accepted by the infrastructure (100% HTTPS enforcement)
- **SC-005**: All Terraform code passes validation checks (terraform validate exits with code 0)
- **SC-006**: Security group rules prevent direct SSH access to EC2 instances from the public internet (verified by attempting connection)
- **SC-007**: Infrastructure cost remains under $50/month for the development environment (verified via AWS Cost Explorer projection)
- **SC-008**: ALB health checks show all instances as healthy within 5 minutes of deployment
- **SC-009**: Certificate is successfully visible in AWS Certificate Manager console
- **SC-010**: Both EC2 instances are confirmed running in different availability zones (ap-southeast-1a and ap-southeast-1b)
