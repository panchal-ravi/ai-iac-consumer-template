# Feature Specification: Public EC2 Instance for Development Environment

**Feature Branch**: `001-public-ec2-dev`  
**Created**: 2025-06-15  
**Status**: Draft  
**Input**: User description: "Provision a public EC2 instance in AWS for development environment with SSH password authentication, public internet access, and cost-optimized configuration"

**Project Context**:
- HCP Terraform Organization: ravi-panchal-org
- HCP Terraform Project: Default Project
- Workspace: sandbox_workspace
- GitHub Issue: #12
- Target Region: ap-southeast-1 (Singapore)
- Environment: Development
- Monthly Budget: $50

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Initial Instance Provisioning (Priority: P1)

As a developer, I need to provision a new EC2 instance in the ap-southeast-1 region so that I can deploy and test my development application in an isolated AWS environment.

**Why this priority**: This is the core functionality - without the ability to create the instance, no other features matter. This delivers immediate value by providing a working compute resource.

**Independent Test**: Can be fully tested by executing the infrastructure provisioning workflow and verifying the instance is created with correct specifications (t3.micro, ap-southeast-1, public IP assigned). Delivers a running, accessible EC2 instance.

**Acceptance Scenarios**:

1. **Given** HCP Terraform workspace is configured with AWS credentials, **When** infrastructure is provisioned, **Then** a t3.micro EC2 instance is created in ap-southeast-1 region
2. **Given** the instance is created, **When** checking the instance details, **Then** a public IP address is assigned and visible
3. **Given** the instance is created, **When** checking the storage configuration, **Then** an 8 GB GP3 root volume is attached
4. **Given** the instance is created, **When** checking the AMI, **Then** Amazon Linux 2023 (latest version) is used
5. **Given** the instance is created, **When** checking the network configuration, **Then** the instance is deployed in the default VPC

---

### User Story 2 - SSH Password Authentication Setup (Priority: P2)

As a developer, I need to connect to the EC2 instance using SSH with username and password (not key pairs) so that I can access the instance without managing SSH key files across multiple team members.

**Why this priority**: SSH access is essential for managing and using the instance, but the instance must exist first (depends on P1). This enables the primary use case of the development environment.

**Independent Test**: Can be tested independently by attempting to SSH to the provisioned instance using username/password credentials. Delivers ability to interactively access and manage the instance.

**Acceptance Scenarios**:

1. **Given** the EC2 instance is running, **When** SSH password authentication is configured, **Then** users can connect using username and password
2. **Given** the instance is configured, **When** attempting SSH connection with valid credentials, **Then** connection is successful without requiring SSH key files
3. **Given** the password is generated, **When** storing the password, **Then** it is securely stored in AWS Secrets Manager
4. **Given** credentials are stored in Secrets Manager, **When** retrieving the password, **Then** authorized users can access it through the Secrets Manager interface

---

### User Story 3 - Network Security Configuration (Priority: P3)

As a developer, I need the EC2 instance to have a security group that allows SSH access from the internet so that team members can connect from various locations without VPN configuration.

**Why this priority**: While important for accessibility, basic network connectivity might work with default settings. This priority allows explicit control over network access rules, which is valuable but not blocking initial provisioning and access.

**Independent Test**: Can be tested by verifying security group rules allow inbound SSH (port 22) from 0.0.0.0/0 and attempting connection from external IP addresses. Delivers flexible access from any location.

**Acceptance Scenarios**:

1. **Given** the EC2 instance is created, **When** security group is configured, **Then** inbound rule allows SSH (port 22) from 0.0.0.0/0
2. **Given** the security group is attached, **When** attempting SSH from any internet IP address, **Then** connection is not blocked by security group rules
3. **Given** the security group rules are active, **When** checking outbound rules, **Then** all outbound traffic is allowed (for package updates and external connectivity)

---

### User Story 4 - Cost and Monitoring Configuration (Priority: P4)

As a development team lead, I need the infrastructure to be cost-optimized with basic monitoring and resource tagging so that I can track expenses and ensure we stay within the $50 monthly budget.

**Why this priority**: Cost optimization and monitoring are important for operational management but don't block the ability to create and use the instance. This is enhancement-level functionality.

**Independent Test**: Can be tested by verifying resource tags are applied, CloudWatch basic monitoring is enabled, and reviewing cost projections. Delivers cost visibility and tracking capabilities.

**Acceptance Scenarios**:

1. **Given** the instance is provisioned, **When** checking CloudWatch, **Then** basic monitoring metrics (CPU, network, disk) are collected
2. **Given** the instance is running, **When** checking resource tags, **Then** tags include Environment=development, ManagedBy=Terraform, CostCenter and Project identifiers
3. **Given** the infrastructure is deployed, **When** reviewing AWS cost explorer, **Then** resources are identifiable by tags for cost tracking
4. **Given** instance type is t3.micro with 8GB storage, **When** calculating monthly cost, **Then** estimated cost is well under $50/month budget

---

### Edge Cases

- **What happens when the default VPC does not exist in ap-southeast-1?** The provisioning should fail with a clear error message indicating that a default VPC must be configured in the target region.

- **How does the system handle AWS Secrets Manager secret already existing?** If a secret with the same name already exists, the provisioning should either update the existing secret or fail with a clear error, depending on configuration.

- **What happens when AWS API rate limits are hit during provisioning?** The infrastructure provisioning should implement retry logic with exponential backoff as per AWS best practices.

- **How does the system handle instance type availability issues in ap-southeast-1?** If t3.micro is not available in the specific availability zone, the provisioning should either retry in another AZ or fail with a descriptive error.

- **What happens when the Amazon Linux 2023 AMI ID changes?** The infrastructure should use a dynamic AMI lookup (latest Amazon Linux 2023) rather than hardcoded AMI IDs to avoid failures.

- **How does the system handle password complexity requirements?** Generated passwords must meet AWS/Linux password complexity requirements (minimum length, special characters) to ensure SSH authentication can be configured successfully.

- **What happens when the monthly budget ($50) is exceeded?** While outside the scope of this infrastructure provisioning, monitoring should make costs visible. Consider AWS Budgets alerts as a separate operational concern.

## Requirements *(mandatory)*

### Functional Requirements

**Infrastructure Provisioning**:

- **FR-001**: System MUST provision an EC2 instance in the ap-southeast-1 (Singapore) AWS region
- **FR-002**: System MUST use t3.micro instance type for cost optimization
- **FR-003**: System MUST assign a public IP address to the EC2 instance
- **FR-004**: System MUST deploy the instance in the default VPC of ap-southeast-1 region
- **FR-005**: System MUST use the latest Amazon Linux 2023 AMI available in ap-southeast-1
- **FR-006**: System MUST attach an 8 GB GP3 root volume to the instance
- **FR-007**: System MUST provision all resources through HCP Terraform workspace "sandbox_workspace"

**Authentication & Access**:

- **FR-008**: System MUST configure SSH access using username and password authentication (NOT SSH key pairs)
- **FR-009**: System MUST generate a secure random password meeting Linux password complexity requirements
- **FR-010**: System MUST store the generated SSH password in AWS Secrets Manager
- **FR-011**: System MUST configure the EC2 instance to allow password-based SSH authentication
- **FR-012**: System MUST disable SSH key-pair requirement for SSH access

**Network Security**:

- **FR-013**: System MUST create a security group allowing inbound SSH traffic (port 22) from any internet source (0.0.0.0/0)
- **FR-014**: System MUST allow all outbound traffic from the instance for package updates and external connectivity
- **FR-015**: System MUST attach the SSH security group to the EC2 instance

**Monitoring & Cost Management**:

- **FR-016**: System MUST enable basic CloudWatch monitoring for the EC2 instance
- **FR-017**: System MUST apply resource tags to all created resources including: Environment=development, ManagedBy=Terraform, Project, CostCenter
- **FR-018**: Infrastructure cost MUST remain under $50 per month based on t3.micro pricing and 8GB GP3 storage

**Module Strategy**:

- **FR-019**: System MUST search HCP Terraform private registry (ravi-panchal-org) for available EC2 modules before using public modules
- **FR-020**: System MUST prefer private registry modules for provisioning when available
- **FR-021**: System MUST document any fallback to public Terraform Registry modules with justification

**Operational Requirements**:

- **FR-022**: System MUST output the instance's public IP address after provisioning
- **FR-023**: System MUST output the AWS Secrets Manager secret ARN containing the SSH password
- **FR-024**: System MUST support idempotent infrastructure updates (re-running should not cause errors)
- **FR-025**: System MUST link infrastructure changes to GitHub Issue #12 for tracking

### Key Entities

- **EC2 Instance**: Represents the virtual machine compute resource
  - Attributes: instance type (t3.micro), region (ap-southeast-1), public IP, AMI (Amazon Linux 2023), state (running/stopped)
  - Relationships: belongs to security group, attached to root volume, deployed in default VPC, associated with SSH credentials

- **Security Group**: Represents network access control for the EC2 instance
  - Attributes: inbound rules (SSH port 22 from 0.0.0.0/0), outbound rules (all traffic allowed)
  - Relationships: attached to EC2 instance, belongs to default VPC

- **Root Volume**: Represents the storage attached to the EC2 instance
  - Attributes: size (8 GB), type (GP3), encryption status
  - Relationships: attached to EC2 instance as root device

- **SSH Credentials**: Represents authentication information for instance access
  - Attributes: username (ec2-user), password (securely generated), SSH port (22)
  - Relationships: stored in AWS Secrets Manager secret, used for EC2 instance authentication

- **Secrets Manager Secret**: Represents secure storage for sensitive data
  - Attributes: secret name, secret value (SSH password), ARN, region
  - Relationships: contains SSH credentials for EC2 instance

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Infrastructure provisioning completes successfully within 5 minutes from HCP Terraform workspace execution
- **SC-002**: EC2 instance is accessible via SSH using username/password authentication within 2 minutes of provisioning completion
- **SC-003**: Developers can connect to the instance from any internet location without VPN or network restrictions
- **SC-004**: Instance public IP address is visible and documented in Terraform outputs immediately after provisioning
- **SC-005**: SSH password is retrievable from AWS Secrets Manager by authorized users within 30 seconds
- **SC-006**: Monthly infrastructure cost remains under $50 based on t3.micro compute ($7.30/month) and 8GB GP3 storage ($0.80/month) = ~$8.10/month
- **SC-007**: Basic CloudWatch metrics (CPU utilization, network in/out, disk read/write) are visible within 5 minutes of instance creation
- **SC-008**: All provisioned resources are tagged correctly for cost tracking and resource management
- **SC-009**: Infrastructure changes are reflected in GitHub Issue #12 within 1 hour of deployment
- **SC-010**: 100% of provisioning attempts using available private registry modules succeed without requiring public module fallback (target metric)

### Deployment Success Indicators

- **SC-011**: Zero manual configuration steps required after Terraform provisioning completes
- **SC-012**: Instance passes SSH connectivity test from at least 2 different external IP addresses within 5 minutes of provisioning
- **SC-013**: Secrets Manager secret is created with appropriate IAM permissions allowing authorized team members to retrieve the password
- **SC-014**: Infrastructure can be destroyed and re-provisioned idempotently without errors or resource conflicts

## Assumptions & Constraints

### Assumptions

1. **AWS Account Access**: HCP Terraform workspace has valid AWS credentials with permissions to create EC2 instances, security groups, and Secrets Manager secrets in ap-southeast-1 region
2. **Default VPC Exists**: The ap-southeast-1 region has a default VPC configured with at least one subnet
3. **AWS Service Quotas**: The AWS account has not reached service quotas for EC2 instances, security groups, or Secrets Manager secrets in ap-southeast-1
4. **HCP Terraform Configuration**: The sandbox_workspace is properly configured and linked to the GitHub repository for this project
5. **Amazon Linux 2023 Availability**: Amazon Linux 2023 AMI is available and maintained in ap-southeast-1 region
6. **Development Environment**: This is explicitly a development/testing environment where relaxed security posture (public SSH, password auth) is acceptable trade-off for ease of access
7. **Cost Estimation**: Monthly cost calculations assume 24/7 instance uptime (~730 hours/month) and minimal data transfer
8. **Team Access**: Team members requiring SSH access have appropriate AWS IAM permissions to read from Secrets Manager
9. **Password Management**: Initial password rotation and management process will be handled manually; automated rotation is not in scope

### Constraints

1. **Region Lock**: Infrastructure must be deployed in ap-southeast-1; no multi-region support
2. **Instance Type**: Must use t3.micro for cost optimization; no flexibility for larger instance types
3. **Budget Limit**: Hard constraint of $50 monthly budget
4. **VPC Requirement**: Must use default VPC (no custom VPC creation or configuration)
5. **Security Trade-off**: SSH access from 0.0.0.0/0 is required despite security best practices recommending restricted IP ranges (development environment exception)
6. **Authentication Method**: Password authentication is mandatory instead of more secure SSH key pairs (business requirement for ease of use)
7. **Single Instance**: Feature provisions one instance only; no high availability or multi-instance patterns
8. **HCP Terraform Dependency**: All infrastructure changes must go through HCP Terraform; no manual AWS console changes
9. **Module Strategy**: Must prioritize private registry modules over public modules; public module usage requires approval

## Security Considerations

### Known Security Trade-offs

This is a **development environment** with intentionally relaxed security for ease of access. The following security trade-offs are explicitly accepted:

1. **Public SSH Access (0.0.0.0/0)**: SSH port 22 is open to the entire internet
   - **Risk**: Increased attack surface for brute-force attacks
   - **Mitigation**: Strong password requirements, monitoring via CloudWatch, consider fail2ban or rate limiting in future iterations
   - **Accepted Because**: Development team works from various locations/IP addresses without VPN

2. **Password Authentication**: Using username/password instead of SSH key pairs
   - **Risk**: Passwords can be compromised through various attack vectors (shoulder surfing, insecure transmission, weak passwords)
   - **Mitigation**: Strong randomly-generated passwords stored in Secrets Manager, password rotation capability
   - **Accepted Because**: Easier for team collaboration and avoids SSH key management complexity in dev environment

3. **Public IP Address**: Instance is directly accessible from internet
   - **Risk**: Instance is exposed to internet-based threats
   - **Mitigation**: Security group controls, CloudWatch monitoring, minimal software installation
   - **Accepted Because**: Required for remote access; acceptable for non-production environment

### Security Controls Implemented

1. **Secrets Manager Storage**: SSH password stored encrypted in AWS Secrets Manager (not in Terraform state or code)
2. **Strong Password Generation**: Passwords generated using cryptographically secure random generation
3. **IAM Permissions**: Access to Secrets Manager secrets controlled via IAM policies
4. **Resource Tagging**: All resources tagged for tracking and audit purposes
5. **CloudWatch Monitoring**: Basic monitoring enabled for anomaly detection
6. **Principle of Least Privilege**: Only required ports (SSH 22) are exposed

### Future Security Enhancements (Out of Scope)

- Implement SSH key-based authentication for production environments
- Add AWS Session Manager for SSH access (eliminates need for public IP)
- Implement IP allowlisting when team network topology is stable
- Add automated password rotation policies
- Implement AWS Systems Manager for patch management
- Add GuardDuty or similar threat detection services
- Implement VPC with private subnets and bastion host pattern for production

## Dependencies

### External Dependencies

1. **AWS Services**:
   - EC2 service availability in ap-southeast-1
   - Secrets Manager service availability in ap-southeast-1
   - CloudWatch service availability in ap-southeast-1
   - Default VPC pre-configured in ap-southeast-1

2. **HCP Terraform**:
   - HCP Terraform account and organization (ravi-panchal-org)
   - Workspace "sandbox_workspace" configured and operational
   - AWS provider credentials configured in workspace
   - Terraform Cloud API access for automation

3. **GitHub Integration**:
   - GitHub repository connected to HCP Terraform workspace
   - GitHub Issue #12 exists and is accessible
   - VCS-driven workflow or API-driven workflow configured

4. **Terraform Registry**:
   - HCP Terraform private registry (ravi-panchal-org) accessible
   - Terraform Public Registry accessible as fallback
   - Network connectivity to download modules and providers

### Internal Dependencies

1. **IAM Permissions**: AWS credentials must have permissions for:
   - `ec2:RunInstances`, `ec2:DescribeInstances`, `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress`
   - `secretsmanager:CreateSecret`, `secretsmanager:PutSecretValue`, `secretsmanager:DescribeSecret`
   - `cloudwatch:PutMetricAlarm` (if setting up alarms)
   - `ec2:CreateTags` for resource tagging

2. **Terraform State**: Terraform state must be stored in HCP Terraform workspace (not local)

3. **Module Availability**: Depends on availability of EC2-related modules in private registry or public registry

### Dependency Risks

- **AWS Service Outages**: If AWS services in ap-southeast-1 are unavailable, provisioning will fail
- **HCP Terraform Downtime**: Cannot provision or update infrastructure during HCP Terraform platform outages
- **Module Changes**: Breaking changes in upstream modules (private or public) could impact infrastructure updates
- **AMI Deprecation**: Amazon Linux 2023 AMI IDs change; must use dynamic lookup to avoid failures

## Out of Scope

The following items are explicitly **not included** in this feature:

### Infrastructure Components

- Custom VPC creation or configuration (using default VPC only)
- Load balancers or auto-scaling groups
- Multi-instance deployments or high availability patterns
- Additional AWS services (RDS, S3, Lambda, etc.)
- Custom networking (NAT gateways, VPC peering, Transit Gateway)
- Backup and disaster recovery solutions
- Multi-region deployment

### Security & Compliance

- SSH key-based authentication (using password auth only)
- IP allowlisting or VPN requirements
- AWS WAF or Shield for DDoS protection
- GuardDuty, Security Hub, or AWS Config
- Compliance frameworks (SOC2, HIPAA, PCI-DSS)
- Automated security patching
- Intrusion detection/prevention systems

### Monitoring & Operations

- Advanced CloudWatch dashboards or custom metrics
- Log aggregation or centralized logging (CloudWatch Logs, ELK stack)
- APM or distributed tracing
- Alerting and on-call rotation setup
- Automated password rotation
- Backup automation
- Automated instance scheduling (start/stop on schedule)

### Cost Management

- AWS Cost Anomaly Detection
- AWS Budgets alerts (though recommended as future enhancement)
- Reserved Instance or Savings Plan purchases
- Cost optimization recommendations

### Application Deployment

- Application code deployment or configuration
- Software installation beyond base Amazon Linux 2023
- Database setup or configuration
- Web server or application server setup
- SSL/TLS certificate management
- Domain name or DNS configuration

### Development Workflow

- CI/CD pipeline configuration beyond basic HCP Terraform integration
- Automated testing frameworks
- Pre-commit hooks or code quality gates
- Infrastructure testing (Terratest, kitchen-terraform)

## Acceptance Checklist

This feature is considered **complete** when all of the following are verified:

### Provisioning & Infrastructure

- [ ] EC2 t3.micro instance successfully created in ap-southeast-1 region
- [ ] Instance is running and passes AWS status checks
- [ ] Public IP address is assigned and visible
- [ ] Amazon Linux 2023 AMI is used (verified via instance details)
- [ ] 8 GB GP3 root volume is attached and available
- [ ] Instance is deployed in default VPC
- [ ] All resources created through HCP Terraform workspace "sandbox_workspace"

### Authentication & Access

- [ ] SSH password authentication is enabled on the instance
- [ ] Secure random password is generated meeting complexity requirements
- [ ] Password is stored in AWS Secrets Manager
- [ ] Secrets Manager secret ARN is available in Terraform outputs
- [ ] SSH connection succeeds using username (ec2-user) and password
- [ ] SSH connection works from at least 2 different external IP addresses

### Network & Security

- [ ] Security group created with name indicating purpose (e.g., "dev-ec2-ssh-sg")
- [ ] Inbound rule allows TCP port 22 from 0.0.0.0/0
- [ ] Outbound rule allows all traffic
- [ ] Security group is attached to EC2 instance
- [ ] Instance is reachable via SSH from internet

### Monitoring & Tagging

- [ ] Basic CloudWatch monitoring is enabled
- [ ] CloudWatch metrics visible for: CPU utilization, network in/out, disk I/O
- [ ] Resource tags applied: Environment=development, ManagedBy=Terraform
- [ ] Resource tags include Project and CostCenter identifiers
- [ ] Tags are visible in AWS Cost Explorer

### Outputs & Documentation

- [ ] Terraform outputs include: instance public IP, instance ID, security group ID, Secrets Manager secret ARN
- [ ] Infrastructure provisioning completes in under 5 minutes
- [ ] Changes linked to GitHub Issue #12
- [ ] Estimated monthly cost is under $50 (documented in planning phase)

### Module Strategy

- [ ] HCP Terraform private registry (ravi-panchal-org) searched for EC2 modules
- [ ] Private modules used if available, or fallback to public modules documented
- [ ] Module selection rationale documented in plan.md

### Idempotency & State Management

- [ ] Re-running `terraform apply` with no changes results in "No changes" output
- [ ] Infrastructure can be destroyed cleanly with `terraform destroy`
- [ ] Terraform state stored in HCP Terraform workspace (not local)
- [ ] No sensitive data (passwords) stored in Terraform state files

### Cost Validation

- [ ] Estimated monthly cost calculated: t3.micro (~$7.30) + 8GB GP3 (~$0.80) = ~$8.10/month
- [ ] Cost is documented and under $50 budget
- [ ] Cost tags enable tracking in AWS Cost Explorer

---

**Definition of Done**: All items in the Acceptance Checklist are verified and checked off. The feature is ready for production use when SSH access works reliably, costs are tracked, and infrastructure is fully managed through HCP Terraform.
