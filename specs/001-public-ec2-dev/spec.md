# Feature Specification: Public EC2 Instance with Password Authentication

**Feature Branch**: `001-public-ec2-dev`  
**Created**: 2025-01-17  
**Status**: Draft  
**Input**: User description: "Create a feature specification for provisioning a public EC2 instance with username/password authentication for development environment."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision Public Development Instance (Priority: P1)

A developer needs to quickly spin up a publicly accessible EC2 instance in AWS for development and testing purposes. They need to provision an instance through HCP Terraform that is immediately accessible via SSH using username/password authentication without managing SSH key pairs.

**Why this priority**: Core functionality - without a running instance, no other features matter. This delivers the fundamental value proposition of having a development environment.

**Independent Test**: Can be fully tested by triggering the Terraform deployment and verifying the instance is running with a public IP address assigned. Delivers an accessible compute resource.

**Acceptance Scenarios**:

1. **Given** valid HCP Terraform credentials and AWS provider configuration, **When** the developer triggers the Terraform deployment, **Then** an EC2 t3.micro instance is provisioned in ap-southeast-1 region
2. **Given** the instance is provisioned, **When** the deployment completes, **Then** a public IP address is automatically assigned to the instance
3. **Given** the instance is running, **When** the developer retrieves the outputs, **Then** the public IP address is displayed for SSH access
4. **Given** the default VPC exists in the region, **When** the Terraform applies, **Then** the instance uses the existing default VPC and subnet without creating new network resources

---

### User Story 2 - SSH Access with Username/Password (Priority: P1)

A developer needs to connect to the development instance using SSH with username/password credentials instead of managing SSH key files. They receive secure credentials after provisioning and can immediately connect using standard SSH tools.

**Why this priority**: Equal to P1 because password authentication is explicitly required and an inaccessible instance has no value. This is part of the MVP that makes the instance usable.

**Independent Test**: Can be tested by attempting SSH connection using the username "devuser" and the generated password from Terraform outputs. Delivers immediate access without key management.

**Acceptance Scenarios**:

1. **Given** the instance is running and user data script has completed, **When** the developer attempts SSH with username "devuser" and the generated password, **Then** SSH connection succeeds and grants shell access
2. **Given** password authentication is configured, **When** the developer tries to connect using SSH keys only, **Then** key-based authentication is disabled and password is required
3. **Given** the deployment completes, **When** the developer retrieves Terraform outputs, **Then** a secure password is generated and displayed as a sensitive output value
4. **Given** SSH service is running, **When** connection attempts are made, **Then** SSH operates on standard port 22

---

### User Story 3 - Network Security Configuration (Priority: P2)

A developer needs the instance to be accessible from the internet while maintaining basic security controls. The instance should allow SSH traffic from any source IP but restrict other protocols to minimize attack surface.

**Why this priority**: Important for security and accessibility, but the instance can technically function without perfect security rules (can be refined post-deployment). Still critical for production-like development.

**Independent Test**: Can be tested by verifying security group rules allow SSH from 0.0.0.0/0 and attempting connections from different network locations. Can also test that non-SSH ports are blocked.

**Acceptance Scenarios**:

1. **Given** the security group is created, **When** the rules are applied, **Then** inbound SSH traffic on port 22 is allowed from 0.0.0.0/0 (any source IP)
2. **Given** the security group is attached, **When** the developer attempts SSH from various public IP addresses, **Then** all connection attempts can reach port 22
3. **Given** the security group is configured, **When** traffic on non-SSH ports is attempted, **Then** the traffic is blocked by default
4. **Given** the instance is running, **When** the security group is queried, **Then** only SSH (port 22) rules are explicitly defined for ingress

---

### User Story 4 - Cost-Optimized Monitoring (Priority: P3)

A developer needs basic visibility into instance operations while keeping costs under the $50/month budget. The instance should have CloudWatch integration for basic logging without expensive detailed monitoring.

**Why this priority**: Nice to have for operational visibility, but not required for the instance to function. Can be added or enhanced after proving core functionality works.

**Independent Test**: Can be tested by verifying CloudWatch Logs are enabled and basic metrics are being collected without detailed monitoring enabled. Delivers operational visibility within budget.

**Acceptance Scenarios**:

1. **Given** the instance is running, **When** CloudWatch is queried, **Then** basic instance metrics are available (CPU, network, disk)
2. **Given** detailed monitoring costs extra, **When** the instance monitoring configuration is checked, **Then** detailed monitoring is disabled
3. **Given** CloudWatch Logs are enabled, **When** the instance generates system logs, **Then** logs are streamed to CloudWatch Logs service
4. **Given** the monthly budget is $50, **When** the instance runs for a full month, **Then** total costs remain under the budget threshold

---

### User Story 5 - Resource Tagging and Identification (Priority: P3)

Operations teams need to identify and categorize the development instance using AWS tags for cost allocation, automation, and governance purposes.

**Why this priority**: Important for operational maturity and cost tracking, but doesn't affect core functionality. Tags can be added or modified after deployment.

**Independent Test**: Can be tested by querying the instance tags through AWS API and verifying all required tags are present with correct values.

**Acceptance Scenarios**:

1. **Given** the instance is provisioned, **When** tags are applied, **Then** the following tags are set: Environment=development, Project=public-ec2-dev, ManagedBy=terraform, Purpose=development-testing, Terraform=true, Agent=copilot-terraform-agent
2. **Given** tags are applied, **When** AWS Cost Explorer is queried, **Then** instance costs can be filtered and allocated by tag values
3. **Given** automation systems scan for managed resources, **When** they query for Terraform=true tag, **Then** this instance is included in the results

---

### Edge Cases

- What happens when the default VPC doesn't exist in ap-southeast-1 region? System should fail with clear error indicating manual VPC creation is required.
- What happens when the t3.micro instance type is not available in the selected availability zone? System should fail Terraform validation with availability zone error.
- What happens when the user data script fails to configure password authentication? SSH access will fail; the instance remains accessible via AWS Systems Manager Session Manager as a recovery path.
- What happens when AWS API rate limits are hit during provisioning? Terraform will retry with exponential backoff up to its configured timeout.
- What happens when the generated password doesn't meet SSH password complexity requirements? The user data script enforces password acceptance regardless of complexity (root can set any password).
- What happens when multiple concurrent Terraform runs target the same workspace? HCP Terraform's run queue serializes executions automatically.
- What happens when the monthly cost exceeds $50? AWS continues service but costs exceed budget; monitoring alerts should be configured separately.
- What happens when the latest Amazon Linux 2023 AMI ID changes? Terraform data source automatically fetches the current latest AMI on each run.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provision a single EC2 instance of type t3.micro in the ap-southeast-1 AWS region
- **FR-002**: System MUST use the latest Amazon Linux 2023 AMI automatically discovered via data source
- **FR-003**: System MUST attach an 8 GB GP3 root volume to the instance
- **FR-004**: System MUST automatically assign a public IP address to the instance at launch
- **FR-005**: System MUST use the existing default VPC and default subnet in ap-southeast-1 via data sources
- **FR-006**: System MUST create a security group allowing inbound SSH traffic on port 22 from 0.0.0.0/0
- **FR-007**: System MUST disable SSH key-based authentication and enable username/password authentication
- **FR-008**: System MUST create a user account named "devuser" on the instance
- **FR-009**: System MUST generate a secure random password for the devuser account
- **FR-010**: System MUST configure the instance via user data script to enable password authentication
- **FR-011**: System MUST integrate with CloudWatch for basic monitoring (detailed monitoring disabled)
- **FR-012**: System MUST enable CloudWatch Logs for system logging
- **FR-013**: System MUST output the instance's public IP address as a non-sensitive output
- **FR-014**: System MUST output the generated password as a sensitive output value
- **FR-015**: System MUST output the username ("devuser") as a non-sensitive output
- **FR-016**: System MUST apply the following tags to the instance: Environment=development, Project=public-ec2-dev, ManagedBy=terraform, Purpose=development-testing, Terraform=true, Agent=copilot-terraform-agent
- **FR-017**: System MUST use the HCP Terraform workspace "sandbox_public_ec2_dev" in organization "ravi-panchal-org"
- **FR-018**: System MUST assign the workspace to the "Default Project" in HCP Terraform
- **FR-019**: System MUST configure IAM permissions following least privilege principle for the instance profile
- **FR-020**: System MUST ensure total monthly operating cost remains under $50

### Key Entities

- **EC2 Instance**: The virtual machine resource representing the development server; includes compute, storage, networking configuration, and public IP assignment
- **Security Group**: Firewall rules controlling network access; defines allowed SSH traffic from any source IP on port 22
- **User Credentials**: The authentication information for SSH access; includes username ("devuser") and randomly generated password
- **Default VPC**: The existing default virtual private cloud in ap-southeast-1; provides network isolation and internet gateway access
- **Default Subnet**: The existing default subnet within the default VPC; provides IP address allocation and availability zone placement
- **AMI Data Source**: The query mechanism to discover the latest Amazon Linux 2023 AMI ID; automatically updates when new AMIs are released
- **User Data Script**: The initialization script executed at instance launch; configures password authentication and creates user account
- **CloudWatch Logs**: The centralized logging destination; receives system logs from the instance for monitoring and troubleshooting
- **HCP Terraform Workspace**: The execution environment for Terraform runs; stores state, variables, and manages infrastructure lifecycle

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Infrastructure provisioning completes within 5 minutes from Terraform apply to SSH-accessible instance
- **SC-002**: SSH connection succeeds within 30 seconds of providing username and password credentials
- **SC-003**: Instance is accessible from any public IP address on port 22 with 100% connectivity success rate
- **SC-004**: Total monthly AWS infrastructure cost remains under $50 (measured via AWS Cost Explorer)
- **SC-005**: Instance uptime meets 99% availability (measured via CloudWatch metrics over 30-day period)
- **SC-006**: Password authentication works on first attempt without requiring SSH key files (100% success rate for valid credentials)
- **SC-007**: Terraform deployment passes with zero errors and all resources reach "created" status
- **SC-008**: All required resource tags are present and accurate on deployed instance (100% tag compliance)
- **SC-009**: Generated password is marked as sensitive in Terraform outputs and not displayed in logs
- **SC-010**: CloudWatch receives system logs within 5 minutes of instance launch
- **SC-011**: Code quality score exceeds 80% when evaluated by automated quality checks
- **SC-012**: Security group contains exactly one inbound rule (SSH on port 22) and no unnecessary permissions

## Assumptions *(mandatory)*

- Default VPC exists in the ap-southeast-1 region (standard for AWS accounts)
- HCP Terraform organization "ravi-panchal-org" exists and has valid AWS credentials configured
- "Default Project" exists in the HCP Terraform organization
- AWS account has quota available for at least one t3.micro instance in ap-southeast-1
- Network connectivity from developer's location to AWS ap-southeast-1 is available
- SSH client is available on the developer's machine for testing connectivity
- AWS credentials have permissions to create EC2 instances, security groups, and query VPC resources
- CloudWatch service is enabled in the AWS account
- Amazon Linux 2023 AMI is available in the ap-southeast-1 region
- Password authentication via SSH is acceptable for development environment (not production)
- Monthly budget tracking and alerting is configured separately from this infrastructure
- Instance state is ephemeral for development purposes (no backup/disaster recovery required)

## Dependencies *(mandatory)*

- **Existing Default VPC**: Instance deployment requires the default VPC to exist in ap-southeast-1; if not present, deployment will fail
- **HCP Terraform Workspace**: The "sandbox_public_ec2_dev" workspace must be created in "ravi-panchal-org" organization before deployment
- **AWS Provider Credentials**: Valid AWS credentials with EC2, VPC, and CloudWatch permissions must be configured in the HCP Terraform workspace
- **Amazon Linux 2023 AMI**: The latest AMI must be available in ap-southeast-1 region (queried via data source)
- **Internet Gateway**: Default VPC must have an attached internet gateway for public IP routing (standard for default VPCs)
- **AWS Service Quotas**: EC2 instance quota for t3.micro must have available capacity
- **Route Table**: Default VPC's route table must have a route to the internet gateway for outbound connectivity

## Out of Scope *(mandatory)*

- **Elastic IP addresses**: Using static Elastic IPs instead of dynamic public IPs
- **Custom VPC creation**: Creating new VPCs, subnets, or network infrastructure
- **High availability**: Multi-AZ deployment, load balancing, or failover configurations
- **Auto-scaling**: Automatically scaling the instance count based on load
- **Backup and disaster recovery**: Automated snapshots, AMI creation, or cross-region replication
- **Domain names**: DNS configuration, Route53 records, or custom hostnames
- **SSL/TLS certificates**: HTTPS configuration or certificate management
- **Application deployment**: Installing or configuring specific development tools or applications beyond OS-level setup
- **VPN or private access**: VPC peering, VPN connections, or AWS Direct Connect
- **Multi-user access**: Creating multiple user accounts or implementing user management systems
- **Custom AMI creation**: Building custom AMIs or maintaining AMI pipelines
- **Instance resizing**: Procedures for changing instance types after deployment
- **Monitoring alerts**: CloudWatch alarms, SNS notifications, or alerting integrations
- **Cost allocation reports**: Detailed cost breakdown reporting or billing integrations beyond tagging
- **Compliance scanning**: Automated compliance checks, vulnerability scanning, or security audits
- **Password rotation**: Automated password rotation or secrets management integration
- **Session recording**: SSH session logging or audit trail recording
- **Instance termination protection**: Safeguards against accidental instance termination
- **Production hardening**: CIS benchmarks, security hardening, or production-grade security configurations
