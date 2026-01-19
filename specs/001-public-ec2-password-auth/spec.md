# Feature Specification: Public EC2 Instance with Password Authentication

**Feature Branch**: `001-public-ec2-password-auth`  
**Created**: 2025-01-21  
**Status**: Draft  
**Input**: User description: "Provision a public EC2 instance with username/password authentication in AWS ap-southeast-1"

## Clarifications

### Session 2025-01-21

- Q: Password Generation Strategy - How should the password be generated and initially set? → A: Generate using Terraform random_password resource (20 chars, alphanumeric + special) stored as sensitive variable
- Q: AMI Selection Strategy - Which AMI should be used (Amazon Linux 2023 or Ubuntu 22.04 LTS)? → A: Ubuntu 22.04 LTS using latest AMI lookup (filter: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*)
- Q: CloudWatch Logging Scope - What is the implementation approach for SSH authentication logging? → A: CloudWatch Agent shipping /var/log/auth.log to CloudWatch Logs group /aws/ec2/ssh-auth
- Q: VPC Strategy - Should we require default VPC or create custom VPC if missing? → A: Use default VPC if exists, create minimal custom VPC with public subnet and IGW if default missing
- Q: User-data Script Error Handling - How should user-data script failures be detected and handled? → A: Log to /var/log/user-data.log and CloudWatch, fail with clear error codes, manual recovery required

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Instance Provisioning (Priority: P1)

A developer needs to quickly provision a public-facing development server in AWS that can be accessed from anywhere using simple username/password authentication instead of managing SSH keys.

**Why this priority**: This is the core functionality - without a running, accessible instance, no other features matter. It represents the minimal viable infrastructure.

**Independent Test**: Can be fully tested by provisioning the instance and verifying that it's running and has a public IP address assigned. Delivers a functional compute resource in the cloud.

**Acceptance Scenarios**:

1. **Given** no existing EC2 infrastructure, **When** provisioning request is initiated, **Then** a t3.micro instance is created in ap-southeast-1 with a public IP address
2. **Given** instance is provisioned, **When** checking instance state, **Then** instance shows as "running" within 5 minutes
3. **Given** instance is running, **When** attempting to reach the public IP, **Then** the network is reachable and port 22 is open

---

### User Story 2 - Password-Based SSH Access (Priority: P1)

A developer needs to connect to the provisioned instance using SSH with username and password credentials, without requiring SSH key pair management.

**Why this priority**: Core requirement that enables the primary use case. Without password authentication working, the instance cannot be accessed as specified.

**Independent Test**: Can be tested by attempting to SSH to the instance using `ssh devuser@<public-ip>` and providing the configured password. Delivers immediate access capability.

**Acceptance Scenarios**:

1. **Given** instance is running, **When** connecting via SSH with username "devuser" and the configured password, **Then** authentication succeeds and shell access is granted
2. **Given** valid credentials provided, **When** SSH connection is established, **Then** user lands in a working shell environment with standard Linux utilities available
3. **Given** incorrect password provided, **When** attempting to authenticate, **Then** access is denied and connection fails with authentication error

---

### User Story 3 - Secure Credential Management (Priority: P2)

Operations team needs assurance that the instance password is stored securely and not exposed in plain text in infrastructure code or configuration management systems.

**Why this priority**: Security requirement that must be in place before production use, but doesn't block initial development testing.

**Independent Test**: Can be tested by inspecting the infrastructure configuration to verify password is stored as a sensitive variable and checking that it's not visible in logs or state files. Delivers security compliance.

**Acceptance Scenarios**:

1. **Given** infrastructure is provisioned, **When** reviewing the configuration, **Then** password is stored in HCP Terraform as a sensitive variable marked "sensitive"
2. **Given** password is stored securely, **When** accessing infrastructure state or logs, **Then** password value is redacted and not visible in plain text
3. **Given** password needs to be retrieved, **When** authorized user accesses HCP Terraform workspace variables, **Then** password can be securely retrieved

---

### User Story 4 - Network Security Configuration (Priority: P2)

Security team needs to verify that appropriate network controls are in place, allowing SSH access while preventing unauthorized access to other services.

**Why this priority**: Essential for meeting baseline security requirements, but can be configured after initial instance provisioning.

**Independent Test**: Can be tested by attempting connections to various ports and verifying only intended ports (22, optionally 80/443) are accessible. Delivers network security posture.

**Acceptance Scenarios**:

1. **Given** instance is running, **When** attempting SSH connection from any internet IP, **Then** connection is allowed to port 22
2. **Given** security group is configured, **When** attempting connection to unauthorized ports, **Then** connection is blocked by security group rules
3. **Given** optional web access is enabled, **When** attempting HTTP/HTTPS connections, **Then** ports 80 and 443 are accessible

---

### User Story 5 - Stable Public Access (Priority: P2)

Developer needs a stable public IP address that doesn't change when the instance is stopped and started, enabling consistent access and DNS configuration.

**Why this priority**: Improves usability and enables integration with other systems, but instance can function with dynamic public IP initially.

**Independent Test**: Can be tested by stopping and starting the instance and verifying the public IP remains the same. Delivers consistent connectivity.

**Acceptance Scenarios**:

1. **Given** instance is provisioned with Elastic IP, **When** instance is stopped and started, **Then** the public IP address remains unchanged
2. **Given** Elastic IP is assigned, **When** checking instance properties, **Then** the Elastic IP is properly associated with the instance
3. **Given** Elastic IP exists, **When** instance is terminated, **Then** Elastic IP is released back to the pool

---

### User Story 6 - Access Monitoring and Logging (Priority: P3)

Security team needs visibility into SSH authentication attempts to detect potential unauthorized access attempts or security incidents.

**Why this priority**: Important for security monitoring and compliance, but not required for basic functionality. Can be added after core features are working.

**Independent Test**: Can be tested by making several SSH connection attempts (successful and failed) and verifying logs are captured in CloudWatch. Delivers audit capability.

**Acceptance Scenarios**:

1. **Given** CloudWatch logging is configured, **When** SSH authentication attempts occur, **Then** authentication events are logged to CloudWatch
2. **Given** authentication logs exist, **When** reviewing CloudWatch logs, **Then** logs include timestamp, source IP, username, and authentication result
3. **Given** failed authentication occurs, **When** checking logs, **Then** failed attempt is recorded with details for security review

---

### Edge Cases

- What happens when the instance type t3.micro is not available in ap-southeast-1? → Terraform will fail with clear error; manual intervention required to select alternative instance type
- How does the system handle password rotation or expiration? → Manual password rotation only; update random_password resource and re-apply Terraform
- What happens if the Elastic IP quota is exceeded? → Terraform will fail with quota error; request quota increase or release unused Elastic IPs
- How does the system behave if the default VPC doesn't exist in ap-southeast-1? → System automatically creates custom VPC (10.0.0.0/16) with public subnet, IGW, and route table
- What happens when multiple concurrent SSH sessions are attempted? → SSH server allows multiple sessions by default; limited only by instance CPU/memory capacity
- How does the system handle instance failure or unexpected termination? → No automatic recovery; Elastic IP remains allocated for reassignment; manual re-provisioning required
- What happens if the user-data script fails to enable password authentication? → Script logs errors to /var/log/user-data.log and CloudWatch Logs with exit codes; manual troubleshooting required; SSH access will fail until resolved
- How are conflicting security group rules handled? → Terraform manages security group declaratively; any conflicts are resolved by Terraform state management

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provision a t3.micro EC2 instance in the ap-southeast-1 AWS region
- **FR-002**: System MUST assign a public IP address to the instance for internet accessibility
- **FR-003**: System MUST configure the instance with 1 vCPU and 1 GB RAM (t3.micro specifications)
- **FR-004**: System MUST use Ubuntu 22.04 LTS as the operating system (AMI filter: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*, most recent)
- **FR-005**: System MUST attach a root EBS volume between 8-20 GB of GP3 storage type
- **FR-006**: System MUST enable SSH password authentication for username "devuser"
- **FR-007**: System MUST configure SSH daemon to allow PasswordAuthentication (modify sshd_config)
- **FR-008**: System MUST generate a secure password using Terraform random_password resource with 20 characters (uppercase, lowercase, numbers, special characters) and store it in HCP Terraform workspace as a sensitive variable
- **FR-009**: System MUST use default VPC in ap-southeast-1 if available; if default VPC does not exist, system MUST create a custom VPC with CIDR 10.0.0.0/16, single public subnet (10.0.1.0/24) in first available AZ, internet gateway, and appropriate route table
- **FR-010**: System MUST configure security group allowing SSH (port 22) inbound from 0.0.0.0/0
- **FR-011**: System MUST optionally allow HTTP (port 80) and HTTPS (port 443) inbound traffic if web server functionality is needed
- **FR-012**: System MUST allocate and associate an Elastic IP address for stable public access
- **FR-013**: System MUST execute user-data script on instance launch to: (1) create devuser account, (2) set generated password, (3) modify /etc/ssh/sshd_config to enable PasswordAuthentication, (4) restart sshd service, (5) install and configure CloudWatch Agent, (6) log execution to /var/log/user-data.log with error codes for debugging
- **FR-014**: System MUST enforce password complexity requirements: minimum 20 characters including uppercase letters, lowercase letters, numbers, and special characters (enforced via Terraform random_password resource configuration)
- **FR-015**: System MUST install and configure CloudWatch Agent via user-data script to ship SSH authentication logs from /var/log/auth.log to CloudWatch Logs group "/aws/ec2/ssh-auth" with log stream named by instance ID
- **FR-016**: System MUST be managed via HCP Terraform organization "ravi-panchal-org"
- **FR-017**: System MUST deploy to HCP Terraform project "Default Project"
- **FR-018**: System MUST use HCP Terraform workspace "sandbox_public_ec2_dev"
- **FR-019**: System MUST pass all infrastructure validation checks before applying
- **FR-020**: System MUST provide clear connection instructions including public IP, username, and password retrieval method
- **FR-021**: System MUST grant EC2 instance IAM permissions to write to CloudWatch Logs (via instance profile with CloudWatchAgentServerPolicy)
- **FR-022**: System MUST create CloudWatch Logs group "/aws/ec2/ssh-auth" with appropriate retention policy (7 days minimum for development)
- **FR-023**: System MUST template user-data script to receive generated password as a variable for secure password configuration

### Key Entities

- **EC2 Instance**: A virtual compute server running in AWS, configured with t3.micro instance type, public IP address, and password authentication enabled. Key attributes include instance ID, public IP, private IP, instance state, and AMI ID.

- **Security Group**: A virtual firewall controlling inbound and outbound traffic to the instance. Key attributes include group ID, inbound rules (port 22 from 0.0.0.0/0, optionally ports 80/443), and outbound rules (typically allow all).

- **Elastic IP**: A static public IPv4 address allocated to the AWS account and associated with the instance. Key attributes include allocation ID, association ID, and public IP address value.

- **VPC/Subnet**: A virtual network environment hosting the instance. May use default VPC or custom VPC with public subnet. Key attributes include VPC ID, subnet ID, internet gateway, and route table configuration.

- **EBS Volume**: A persistent block storage volume attached to the instance as root device. Key attributes include volume ID, size (8-20 GB), volume type (GP3), and attachment state.

- **User Credentials**: Authentication credentials for SSH access. Key attributes include username (devuser), password (generated by Terraform random_password resource with 20 characters), password stored as sensitive output, and authentication method (password-based).

- **CloudWatch Logs Configuration**: Logging infrastructure for SSH authentication monitoring. Key attributes include log group name (/aws/ec2/ssh-auth), log stream (instance ID), CloudWatch Agent configuration file, and IAM permissions (CloudWatchAgentServerPolicy).

- **IAM Instance Profile**: IAM role attached to the EC2 instance granting permissions for CloudWatch Logs. Key attributes include role name, attached policy (CloudWatchAgentServerPolicy), and instance profile association.

- **HCP Terraform Workspace**: The infrastructure management workspace in HCP Terraform. Key attributes include organization name (ravi-panchal-org), project name (Default Project), workspace name (sandbox_public_ec2_dev), and workspace variables.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can connect to the instance via SSH using password authentication within 2 minutes of receiving connection instructions
- **SC-002**: Instance remains continuously accessible for SSH connections with 99% uptime during development period
- **SC-003**: Infrastructure provisioning completes successfully within 10 minutes from initiation
- **SC-004**: SSH authentication attempts are logged to CloudWatch within 5 minutes of occurrence
- **SC-005**: Instance password retrieval from HCP Terraform requires proper authentication and authorization
- **SC-006**: All infrastructure validation checks pass on first attempt with zero configuration errors
- **SC-007**: Monthly infrastructure cost remains under $20 USD (target: $10-15 for t3.micro)
- **SC-008**: Instance public IP address remains stable across stop/start cycles (Elastic IP functionality)
- **SC-009**: 100% of authorized SSH connection attempts succeed with correct credentials
- **SC-010**: 100% of unauthorized SSH connection attempts (wrong password) are denied
- **SC-011**: Security group configuration prevents access to all non-authorized ports (verified by port scan)
- **SC-012**: Documentation enables any developer to connect to the instance without additional support

## Constraints & Assumptions *(optional - include if applicable)*

### Constraints

- **C-001**: Must deploy to AWS region ap-southeast-1 (Singapore) as specified
- **C-002**: Must use HCP Terraform organization "ravi-panchal-org" and workspace "sandbox_public_ec2_dev"
- **C-003**: Must use t3.micro instance type for cost optimization ($10-15/month target)
- **C-004**: Password authentication is NOT AWS best practice - accepted for development environment only
- **C-005**: Security group allows SSH from 0.0.0.0/0 (any IP) - accepted for development convenience with documented security risk
- **C-006**: Must use GP3 EBS volume type for cost efficiency
- **C-007**: No NAT Gateway or Application Load Balancer to minimize costs
- **C-008**: Limited to AWS services and features available in ap-southeast-1 region

### Assumptions

- **A-001**: Default VPC exists in ap-southeast-1 region OR system will automatically create custom VPC if default is missing
- **A-002**: AWS account has sufficient service quotas for EC2 instances, Elastic IPs, and VPC resources
- **A-003**: User has valid AWS credentials configured with appropriate permissions (EC2, VPC, CloudWatch)
- **A-004**: HCP Terraform workspace "sandbox_public_ec2_dev" already exists or will be created as part of setup
- **A-005**: This is a development/sandbox environment - security controls are relaxed compared to production standards
- **A-006**: Instance will run continuously (not start/stop frequently) to minimize Elastic IP association delays
- **A-007**: Password will be rotated manually - no automated rotation mechanism required for development environment
- **A-008**: CloudWatch Logs log group "/aws/ec2/ssh-auth" will retain logs for minimum 7 days (configurable via Terraform)
- **A-009**: Instance requires internet egress for package updates and management (implicit in public subnet design)
- **A-010**: User accepts the security risks of password authentication and open SSH access for development purposes

## Security & Compliance *(optional - include for security-sensitive features)*

### Security Considerations

- **SEC-001**: Password authentication over SSH is less secure than SSH key-based authentication - this is explicitly acknowledged as a development-only configuration
- **SEC-002**: SSH access allowed from 0.0.0.0/0 creates exposure to brute-force attacks - mitigated by CloudWatch logging and strong password requirements
- **SEC-003**: Password stored as sensitive variable in HCP Terraform - must ensure HCP Terraform workspace access is properly controlled
- **SEC-004**: No automatic password rotation mechanism - password must be manually updated if compromised
- **SEC-005**: No fail2ban or intrusion detection configured - authentication failures are logged but not automatically blocked
- **SEC-006**: Root volume is not encrypted by default - may be enabled if required by security policy
- **SEC-007**: No host-based firewall (iptables/firewalld) configured beyond security group rules
- **SEC-008**: CloudWatch logs must be protected with appropriate IAM policies to prevent tampering

### Risk Acceptance

This infrastructure is designed for a **development/sandbox environment** and does **NOT** meet production security standards. The following risks are explicitly accepted:

- **RISK-001**: Password authentication is less secure than key-based authentication - accepted for development convenience
- **RISK-002**: Open SSH access (0.0.0.0/0) increases attack surface - accepted for flexible development access
- **RISK-003**: Single instance has no redundancy or high availability - accepted for development use case
- **RISK-004**: No automated security patching or compliance scanning - manual management required
- **RISK-005**: No network segmentation or private subnet isolation - all traffic is public

**For production use**, the following security enhancements would be required:
- Switch to SSH key-based authentication
- Restrict SSH access to specific IP ranges or VPN
- Implement fail2ban or AWS Systems Manager Session Manager
- Enable EBS encryption
- Add automated security patching
- Implement network segmentation with private subnets
- Add intrusion detection and automated response
- Implement automated password rotation via AWS Secrets Manager

## Dependencies *(optional - include if feature requires external systems)*

### External Dependencies

- **DEP-001**: AWS account with active subscription and billing configured
- **DEP-002**: HCP Terraform account with "ravi-panchal-org" organization configured
- **DEP-003**: AWS IAM credentials or role with permissions for EC2, VPC, CloudWatch, and IAM operations
- **DEP-004**: Internet connectivity for initial provisioning and ongoing instance management
- **DEP-005**: AWS region ap-southeast-1 operational and accepting new resource requests

### Infrastructure Dependencies

- **DEP-006**: Default VPC in ap-southeast-1 OR ability to create custom VPC (10.0.0.0/16 CIDR available)
- **DEP-007**: Available Elastic IP quota in AWS account (minimum 1 available)
- **DEP-008**: Available t3.micro instance capacity in ap-southeast-1 availability zones
- **DEP-009**: CloudWatch Logs service enabled and operational in ap-southeast-1
- **DEP-010**: IAM permissions to create instance profiles and roles for CloudWatch Agent
- **DEP-011**: Ubuntu 22.04 LTS AMI available in ap-southeast-1 region

### No Internal System Dependencies

This feature does not depend on any existing internal systems, applications, or services. It is a standalone infrastructure provisioning feature.

## Out of Scope *(optional but recommended)*

The following items are explicitly **NOT** included in this feature:

- **OOS-001**: Automated password rotation or integration with AWS Secrets Manager rotation
- **OOS-002**: High availability or multi-AZ deployment
- **OOS-003**: Auto-scaling or load balancing capabilities
- **OOS-004**: Automated backup and disaster recovery mechanisms
- **OOS-005**: VPN or bastion host configuration for secure access
- **OOS-006**: Application deployment or web server configuration (beyond OS installation)
- **OOS-007**: Monitoring alerts or automated incident response beyond basic logging
- **OOS-008**: Cost optimization beyond using t3.micro and GP3 volumes
- **OOS-009**: Compliance scanning or security hardening beyond basic configuration
- **OOS-010**: IPv6 support or dual-stack networking
- **OOS-011**: Custom AMI creation or golden image management
- **OOS-012**: Integration with centralized authentication systems (LDAP, Active Directory)
- **OOS-013**: Automated certificate management for HTTPS
- **OOS-014**: Container runtime or orchestration platform installation
- **OOS-015**: Network ACLs or additional network security layers

## Documentation Requirements *(optional but recommended)*

### Required Documentation

- **DOC-001**: Connection instructions including exact SSH command format
- **DOC-002**: Steps to retrieve instance public IP address from AWS console or CLI
- **DOC-003**: Steps to retrieve password from HCP Terraform workspace variables
- **DOC-004**: Initial setup guide for first-time access
- **DOC-005**: Security warnings and risk acceptance acknowledgment
- **DOC-006**: Cost estimation and monitoring guidance
- **DOC-007**: Troubleshooting guide for common connection issues
- **DOC-008**: Instructions for accessing CloudWatch logs
- **DOC-009**: Emergency procedures for instance termination if compromised
- **DOC-010**: Resource cleanup instructions to avoid ongoing charges

### Documentation Format

- Documentation must be provided in markdown format
- Must include example commands with placeholder values clearly marked
- Must include screenshots or example output where helpful
- Must be suitable for users with basic Linux and AWS knowledge

## Non-Functional Requirements *(optional - include if relevant)*

### Performance

- **NFR-001**: Instance provisioning must complete within 10 minutes
- **NFR-002**: SSH connection establishment must complete within 30 seconds
- **NFR-003**: Instance boot time must be under 2 minutes
- **NFR-004**: CloudWatch log delivery latency must be under 5 minutes

### Reliability

- **NFR-005**: Instance must maintain 99% uptime during planned development periods
- **NFR-006**: Elastic IP association must persist across instance restarts
- **NFR-007**: Password authentication must succeed on first attempt with correct credentials

### Usability

- **NFR-008**: Connection instructions must be understandable by developers with basic Linux knowledge
- **NFR-009**: Password retrieval process must require no more than 3 steps
- **NFR-010**: Instance access must not require VPN or additional network configuration

### Maintainability

- **NFR-011**: Infrastructure code must pass Terraform validation and formatting checks
- **NFR-012**: Security group rules must be clearly documented and auditable
- **NFR-013**: Infrastructure must be reproducible by re-running Terraform apply

### Cost

- **NFR-014**: Monthly infrastructure cost must remain under $20 USD
- **NFR-015**: No hidden costs beyond instance, storage, and Elastic IP charges
- **NFR-016**: Cost estimate must be documented and verifiable

## Glossary *(optional - include for domain-specific terms)*

- **EC2 (Elastic Compute Cloud)**: AWS service providing scalable virtual servers
- **t3.micro**: EC2 instance type with 2 vCPUs and 1 GB RAM, part of burstable performance instance family
- **Elastic IP**: Static public IPv4 address that can be associated with AWS resources
- **Security Group**: Virtual firewall controlling inbound and outbound traffic to AWS resources
- **VPC (Virtual Private Cloud)**: Isolated virtual network in AWS cloud
- **Public Subnet**: Subnet with route to internet gateway, allowing direct internet access
- **Internet Gateway**: VPC component enabling internet connectivity
- **GP3**: General Purpose SSD EBS volume type (3rd generation)
- **SSH (Secure Shell)**: Network protocol for secure remote access to systems
- **user-data**: Script executed automatically when EC2 instance launches
- **sshd_config**: SSH daemon configuration file controlling authentication and access settings
- **CloudWatch**: AWS monitoring and logging service
- **HCP Terraform**: HashiCorp Cloud Platform managed Terraform service
- **Sensitive Variable**: Variable marked as sensitive in Terraform, redacted from logs and UI
- **ap-southeast-1**: AWS region identifier for Singapore
- **AMI (Amazon Machine Image)**: Template for EC2 instance root volume
- **Amazon Linux 2023**: AWS-optimized Linux distribution
- **Ubuntu 22.04 LTS**: Long-term support version of Ubuntu Linux
- **Password Authentication**: SSH authentication method using username and password (vs. key-based)
- **Brute-force Attack**: Repeated authentication attempts to guess credentials
- **random_password**: Terraform resource that generates cryptographically secure random passwords
- **CloudWatch Agent**: AWS agent software installed on EC2 instances to collect logs and metrics
- **IAM Instance Profile**: Container for IAM role that provides credentials to applications running on EC2 instance
- **/var/log/auth.log**: Ubuntu system log file containing authentication events including SSH login attempts
- **user-data script**: Bash script executed during EC2 instance first boot for initial configuration
