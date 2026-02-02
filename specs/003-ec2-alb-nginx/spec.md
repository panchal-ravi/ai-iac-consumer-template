# Feature Specification: EC2 Instance with ALB and Nginx

**Feature Branch**: `003-ec2-alb-nginx`  
**Created**: 2025-01-21  
**Status**: Draft  
**GitHub Issue**: #39  
**Input**: Provision EC2 instances with ALB and Nginx across 2 AZs in ap-southeast-1 with HTTPS using self-signed certificates, configure security groups, and integrate with HCP Terraform workspace

## Overview

This feature delivers a development environment consisting of EC2 instances running Nginx web servers behind an Application Load Balancer (ALB) with HTTPS support. The infrastructure spans two availability zones in the ap-southeast-1 region for basic redundancy, uses self-signed certificates for testing HTTPS connectivity, and is deployed through HCP Terraform for infrastructure lifecycle management.

**Target Environment**: Development (cost-optimized)  
**Primary Use Case**: Testing web application deployment patterns with load balancing and HTTPS  
**Deployment Method**: HCP Terraform Cloud (Organization: ravi-panchal-org, Workspace: sandbox_workspace)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Access Web Content via HTTPS (Priority: P1)

A developer or tester needs to verify that web content is accessible through a secure HTTPS endpoint to validate the basic infrastructure setup and certificate configuration.

**Why this priority**: This represents the core value of the infrastructure - providing secure web access. Without this working, no other testing scenarios can proceed.

**Independent Test**: Can be fully tested by navigating to https://web.demo.com in a browser (with certificate warning acceptance) and verifying the Nginx welcome page loads successfully.

**Acceptance Scenarios**:

1. **Given** DNS is configured to point to the ALB, **When** user navigates to https://web.demo.com, **Then** browser establishes HTTPS connection (with self-signed certificate warning) and displays the Nginx test page
2. **Given** ALB is provisioned with HTTPS listener, **When** user attempts HTTP connection on port 80, **Then** connection is refused (only HTTPS/443 is enabled)
3. **Given** static content is deployed on both EC2 instances, **When** multiple requests are made to https://web.demo.com, **Then** requests are distributed across instances demonstrating load balancing

---

### User Story 2 - Infrastructure Provisioning via HCP Terraform (Priority: P1)

An infrastructure engineer needs to provision the entire stack using HCP Terraform to ensure infrastructure-as-code practices and enable repeatable deployments.

**Why this priority**: This is the deployment mechanism that makes the infrastructure maintainable and reproducible. Critical for the infrastructure lifecycle.

**Independent Test**: Can be fully tested by triggering a Terraform plan/apply in the sandbox_workspace and verifying all resources are created successfully with proper tagging.

**Acceptance Scenarios**:

1. **Given** Terraform configuration is committed to repository, **When** plan is executed in HCP Terraform workspace, **Then** plan shows creation of ALB, target group, listeners, EC2 instances, security groups, and ACM certificate with no errors
2. **Given** infrastructure is provisioned, **When** viewing resources in AWS console, **Then** all resources show consistent tags including environment=development and project identifier
3. **Given** infrastructure exists, **When** Terraform destroy is executed, **Then** all resources are cleanly removed without orphaned resources

---

### User Story 3 - Verify Security Group Isolation (Priority: P2)

A security engineer needs to verify that EC2 instances only accept traffic from the ALB and the ALB only accepts HTTPS traffic from the internet to ensure proper network segmentation.

**Why this priority**: Security validation is important but secondary to basic functionality. This ensures the infrastructure follows security best practices.

**Independent Test**: Can be tested by attempting direct connections to EC2 instances (should fail) and attempting HTTP connections to ALB (should fail), while HTTPS through ALB succeeds.

**Acceptance Scenarios**:

1. **Given** EC2 instances are running, **When** attempting direct HTTPS connection to EC2 instance public IP, **Then** connection is refused or times out
2. **Given** ALB security group is configured, **When** attempting HTTP connection to ALB on port 80, **Then** connection is refused
3. **Given** ALB is forwarding to targets, **When** checking security group rules, **Then** EC2 security group only allows ingress from ALB security group on port 443

---

### User Story 4 - Monitor Instance Health and Availability (Priority: P3)

An operations engineer needs to verify that the ALB health checks correctly identify healthy instances and route traffic only to available instances.

**Why this priority**: Important for understanding production-readiness but not critical for initial development testing. Demonstrates high availability patterns.

**Independent Test**: Can be tested by stopping Nginx on one instance and verifying traffic continues to flow through the healthy instance.

**Acceptance Scenarios**:

1. **Given** both EC2 instances are running Nginx, **When** viewing ALB target group health, **Then** both instances show as healthy
2. **Given** Nginx is stopped on one instance, **When** health check interval passes, **Then** affected instance shows as unhealthy and receives no traffic
3. **Given** one instance is unhealthy, **When** accessing https://web.demo.com, **Then** requests are served only by the healthy instance with no user-facing errors

---

### Edge Cases

- What happens when both EC2 instances fail health checks simultaneously? (ALB should return 503 Service Unavailable)
- What happens when attempting to access the infrastructure before DNS propagation completes? (Connection will fail with DNS resolution error)
- What happens when ACM certificate import fails during provisioning? (Terraform apply should fail with clear error message before creating ALB listener)
- What happens when attempting to provision in a region without existing default VPC? (Terraform should fail during plan phase with data source error)
- What happens when selected instance type (t3.micro or t2.micro) is not available in an AZ? (Terraform should fail during apply with capacity error)
- What happens when traffic exceeds t2/t3.micro capacity? (CPU throttling may occur; acceptable for development environment)

## Requirements *(mandatory)*

### Functional Requirements

#### Infrastructure Components

- **FR-001**: System MUST provision EC2 instances in exactly 2 availability zones within ap-southeast-1 region
- **FR-002**: System MUST use existing default VPC and subnets via data sources (no new VPC creation)
- **FR-003**: System MUST provision t3.micro or t2.micro instance types for cost optimization
- **FR-004**: System MUST deploy Application Load Balancer with public internet access
- **FR-005**: System MUST configure ALB with HTTPS listener on port 443 only (no HTTP listener)
- **FR-006**: System MUST distribute EC2 instances across 2 AZs with one instance per AZ minimum

#### Certificate Management

- **FR-007**: System MUST generate self-signed TLS certificate for domain "web.demo.com" using Terraform TLS provider
- **FR-008**: System MUST import generated certificate into AWS Certificate Manager (ACM)
- **FR-009**: Certificate MUST have minimum validity of 90 days
- **FR-010**: ALB HTTPS listener MUST use imported ACM certificate

#### Web Server Configuration

- **FR-011**: System MUST install and configure Nginx web server on all EC2 instances
- **FR-012**: Nginx MUST serve basic static content page for testing purposes
- **FR-013**: Nginx MUST listen on port 443 for HTTPS traffic
- **FR-014**: Static content page MUST display identifiable information (e.g., hostname or instance ID) to verify load balancing

#### Security Configuration

- **FR-015**: ALB security group MUST allow inbound HTTPS traffic (port 443) from 0.0.0.0/0 (internet)
- **FR-016**: ALB security group MUST allow all outbound traffic to EC2 security group
- **FR-017**: EC2 security group MUST allow inbound HTTPS traffic (port 443) ONLY from ALB security group
- **FR-018**: EC2 security group MUST allow outbound traffic for package installation and updates
- **FR-019**: System MUST NOT expose SSH (port 22) to public internet

#### Load Balancing and Health Checks

- **FR-020**: ALB MUST distribute incoming HTTPS requests across healthy EC2 instances
- **FR-021**: System MUST configure target group with appropriate health check settings (path, interval, timeout, threshold)
- **FR-022**: Health checks MUST verify Nginx availability on port 443
- **FR-023**: ALB MUST automatically route traffic away from unhealthy instances

#### Resource Management

- **FR-024**: All resources MUST be tagged with consistent naming convention including environment=development
- **FR-025**: All resources MUST include tags for cost tracking and resource identification
- **FR-026**: Resource naming MUST follow convention: [project]-[environment]-[resource-type]-[identifier]
- **FR-027**: System MUST provision infrastructure through HCP Terraform workspace: sandbox_workspace in organization: ravi-panchal-org

#### Deployment and Configuration

- **FR-028**: System MUST bootstrap EC2 instances with user data script to install and configure Nginx
- **FR-029**: User data script MUST complete successfully before instance is marked as healthy
- **FR-030**: All infrastructure resources MUST be defined as Terraform code (infrastructure-as-code)

### Key Entities

- **EC2 Instance**: Compute resource running Amazon Linux 2 or Ubuntu, configured with Nginx web server, deployed across 2 AZs, tagged with environment and cost tracking metadata
- **Application Load Balancer**: Layer 7 load balancer with internet-facing scheme, HTTPS listener on port 443, distributing traffic to EC2 target group
- **Target Group**: Collection of EC2 instances registered as ALB targets, configured with HTTPS health checks on port 443
- **Security Group (ALB)**: Network firewall rules allowing inbound HTTPS from internet and outbound HTTPS to EC2 instances
- **Security Group (EC2)**: Network firewall rules allowing inbound HTTPS only from ALB security group
- **TLS Certificate**: Self-signed certificate for web.demo.com with private key, generated by Terraform TLS provider
- **ACM Certificate**: AWS-managed certificate imported from generated self-signed certificate, attached to ALB HTTPS listener
- **VPC and Subnets**: Existing default VPC infrastructure queried via data sources, providing network foundation

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Infrastructure provisioning completes successfully in HCP Terraform workspace within 10 minutes
- **SC-002**: HTTPS requests to ALB endpoint return 200 OK response from Nginx within 500ms
- **SC-003**: All EC2 instances pass ALB health checks within 2 minutes of Nginx service starting
- **SC-004**: Load balancer distributes traffic across both instances (verified by 20 consecutive requests showing responses from both instances)
- **SC-005**: Direct connection attempts to EC2 instance ports (bypassing ALB) fail or timeout within 5 seconds
- **SC-006**: HTTP connection attempts to ALB on port 80 are refused (only HTTPS/443 allowed)
- **SC-007**: Terraform plan shows zero changes when re-applied after initial successful deployment (infrastructure idempotency)
- **SC-008**: All provisioned resources display consistent tags with environment=development and cost tracking identifiers
- **SC-009**: Infrastructure destruction via Terraform destroy completes successfully within 5 minutes with no orphaned resources
- **SC-010**: When one EC2 instance is stopped, remaining instance continues serving traffic with 100% success rate for HTTPS requests

### Out of Scope

The following items are explicitly excluded from this feature:

- **Production-grade infrastructure**: This is a development environment with single-instance-per-AZ configuration, not suitable for production workloads
- **Auto-scaling**: No auto-scaling groups or dynamic capacity management
- **Domain registration and DNS management**: DNS configuration for web.demo.com is assumed to be handled externally
- **Valid SSL/TLS certificates**: Using self-signed certificates only; no Let's Encrypt or commercial certificate integration
- **WAF (Web Application Firewall)**: No application-layer security beyond basic security groups
- **CloudWatch monitoring and alerting**: Basic health checks only; no comprehensive monitoring dashboards or alerts
- **Backup and disaster recovery**: No automated backups or cross-region replication
- **VPC creation**: Uses existing default VPC; no custom VPC, subnet, or network topology design
- **Database integration**: No RDS or database components
- **Custom application deployment**: Static Nginx content only; no application code or CI/CD pipeline
- **SSH access configuration**: No bastion hosts or SSH key management (instances may have SSH disabled)
- **Cost optimization beyond instance type**: No reserved instances, savings plans, or advanced cost management
- **Compliance requirements**: No specific compliance framework adherence (HIPAA, PCI-DSS, etc.)
- **Multi-region deployment**: Single region (ap-southeast-1) only
- **HTTP to HTTPS redirect**: No automatic redirection from port 80 to 443
- **Advanced ALB features**: No path-based or host-based routing, sticky sessions, or WebSocket support
- **Instance monitoring agents**: No CloudWatch agent or custom metrics collection

### Assumptions

- Default VPC exists in ap-southeast-1 region with at least 2 public subnets in different AZs
- HCP Terraform workspace (sandbox_workspace) is pre-configured with valid AWS credentials and permissions
- AWS account has sufficient service quotas for required resources (ALB, EC2 instances, security groups)
- DNS for web.demo.com will be manually configured to point to ALB DNS name (not managed by Terraform)
- Users accessing https://web.demo.com will manually accept self-signed certificate warnings in browsers
- Internet Gateway is attached to default VPC for public internet access
- Selected availability zones support t3.micro or t2.micro instance types
- Latest Amazon Linux 2 or Ubuntu AMI includes package managers (yum/apt) for Nginx installation
- Terraform state is managed in HCP Terraform Cloud (not local state)
