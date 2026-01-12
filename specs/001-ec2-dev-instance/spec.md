# Feature Specification: Public EC2 Development Instance with Password-Based SSH

**Feature Branch**: `001-ec2-dev-instance`  
**Created**: 2025-06-15  
**Status**: Draft  
**Input**: User description: "Create a feature specification for provisioning a public EC2 instance with username/password SSH authentication for development environment."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Infrastructure Deployment (Priority: P1)

As a DevOps engineer, I need to provision a public EC2 instance through HCP Terraform so that I can establish a development environment quickly without manual AWS Console operations.

**Why this priority**: This is the foundation of the entire feature - without the deployed infrastructure, no other functionality is possible. This represents the minimum viable deployment.

**Independent Test**: Can be fully tested by running Terraform apply through HCP Terraform and verifying the instance appears in AWS Console with correct tags and network configuration. Delivers a running EC2 instance with public IP address.

**Acceptance Scenarios**:

1. **Given** HCP Terraform workspace is configured with AWS credentials, **When** Terraform plan is executed, **Then** plan shows creation of EC2 instance, security group, and elastic IP with no errors
2. **Given** Terraform apply completes successfully, **When** checking AWS Console, **Then** t3.micro instance exists in us-east-1 with status "running" and all required tags
3. **Given** infrastructure is deployed, **When** checking network configuration, **Then** instance has elastic IP attached and is in default VPC public subnet
4. **Given** deployment completes, **When** checking HCP Terraform workspace, **Then** state shows successful apply with output values for instance ID and public IP

---

### User Story 2 - SSH Access Configuration (Priority: P2)

As a developer, I need to connect to the EC2 instance using SSH with username 'devuser' and a password so that I can access the development environment without managing SSH key pairs.

**Why this priority**: This enables actual usage of the infrastructure. Without SSH access, the instance is not usable for development work.

**Independent Test**: Can be tested by attempting SSH connection from any workstation using `ssh devuser@<elastic-ip>` with password authentication. Delivers a fully accessible development environment.

**Acceptance Scenarios**:

1. **Given** EC2 instance is running, **When** attempting SSH connection using `devuser` username and correct password, **Then** connection succeeds and user gains shell access
2. **Given** SSH service is configured, **When** checking security group rules, **Then** inbound rule allows TCP port 22 from 0.0.0.0/0
3. **Given** password authentication is enabled, **When** entering incorrect password 3 times, **Then** connection attempt fails and event is logged
4. **Given** user has SSH access, **When** idle session exceeds 30 minutes, **Then** session automatically disconnects

---

### User Story 3 - Security Hardening (Priority: P3)

As a security-conscious developer, I need the instance to enforce strong password policies and automatic brute-force protection so that the development environment maintains basic security standards despite public exposure.

**Why this priority**: Adds security layers that protect against common attacks. Can be implemented after basic access is working, as it enhances rather than enables core functionality.

**Independent Test**: Can be tested by attempting SSH login with weak passwords (should be rejected), attempting multiple failed logins (should trigger fail2ban), and verifying password complexity requirements. Delivers hardened security posture.

**Acceptance Scenarios**:

1. **Given** initial setup wizard runs, **When** attempting to set devuser password with less than 14 characters, **Then** password is rejected with clear error message
2. **Given** devuser password meets requirements, **When** attempting to set password without special characters, **Then** password is rejected per strong password policy
3. **Given** fail2ban is active, **When** 5 failed SSH login attempts occur within 10 minutes from same IP, **Then** that IP is blocked for 1 hour
4. **Given** fail2ban blocks an IP, **When** checking logs, **Then** blocking event is recorded with timestamp, IP address, and reason

---

### User Story 4 - Monitoring and Observability (Priority: P4)

As a DevOps engineer, I need to monitor SSH authentication attempts and basic instance metrics so that I can detect unauthorized access attempts and track resource utilization.

**Why this priority**: Important for operational awareness but not required for basic functionality. Can be added after core access is working.

**Independent Test**: Can be tested by generating SSH login attempts (successful and failed) and verifying they appear in CloudWatch Logs within 5 minutes. Delivers operational visibility.

**Acceptance Scenarios**:

1. **Given** CloudWatch agent is installed, **When** SSH authentication succeeds, **Then** event appears in CloudWatch Logs within 2 minutes with username and source IP
2. **Given** CloudWatch agent is installed, **When** SSH authentication fails, **Then** event appears in CloudWatch Logs within 2 minutes with attempted username and source IP
3. **Given** instance is running, **When** checking CloudWatch metrics, **Then** basic monitoring metrics (CPU, network, disk) are visible with 5-minute granularity
4. **Given** 7 days have passed since log creation, **When** checking CloudWatch Logs retention, **Then** logs older than 7 days are automatically purged

---

### Edge Cases

- What happens when the devuser password expires or needs rotation? (Assumption: SSH access remains available through serial console or AWS Systems Manager Session Manager for emergency password reset)
- How does the system handle simultaneous SSH sessions from multiple IPs? (Assumption: Multiple concurrent sessions are allowed, limited only by instance resources)
- What happens if fail2ban blocks the legitimate user's IP address? (Assumption: User can use AWS Systems Manager Session Manager as fallback access method)
- How does the instance behave during AWS maintenance windows? (Assumption: Instance may reboot during maintenance; elastic IP persists and SSH access resumes automatically)
- What happens when the t3.micro instance exhausts CPU credits? (Assumption: Performance degrades to baseline, but SSH access remains available)
- How is the initial devuser password set securely during provisioning? (Assumption: Password is generated using Terraform random_password resource and stored as sensitive output, communicated via secure channel)

## Requirements *(mandatory)*

### Functional Requirements

#### Infrastructure Provisioning

- **FR-001**: System MUST deploy EC2 instance as t3.micro instance type in us-east-1 region using default VPC
- **FR-002**: System MUST attach elastic IP address to EC2 instance to ensure consistent public IP across reboots
- **FR-003**: System MUST place instance in public subnet within default VPC to enable direct internet connectivity
- **FR-004**: System MUST create security group allowing inbound TCP traffic on port 22 from 0.0.0.0/0
- **FR-005**: System MUST apply resource tags: Environment=development, Project=ec2-dev-instance, ManagedBy=terraform, PublicAccess=true
- **FR-006**: System MUST provision infrastructure through HCP Terraform workspace "sandbox_ec2_dev_instance" in project "Default Project" under organization "ravi-panchal-org"

#### SSH Access Configuration

- **FR-007**: System MUST create user account named 'devuser' with sudo privileges on the EC2 instance
- **FR-008**: System MUST enable SSH password authentication on port 22
- **FR-009**: System MUST disable SSH key-based authentication to enforce password-only access
- **FR-010**: System MUST configure SSH service to automatically start on instance boot
- **FR-011**: System MUST set SSH session idle timeout to 30 minutes with automatic disconnection

#### Security Requirements

- **FR-012**: System MUST enforce strong password policy requiring minimum 14 characters for devuser account
- **FR-013**: System MUST enforce password complexity requiring combination of uppercase, lowercase, numbers, and special characters
- **FR-014**: System MUST install and configure fail2ban to monitor SSH authentication attempts
- **FR-015**: System MUST configure fail2ban to block IP addresses after 5 failed login attempts within 10 minutes for 1 hour duration
- **FR-016**: System MUST log all SSH authentication attempts (successful and failed) to system authentication logs
- **FR-017**: System MUST configure password expiry policy requiring password rotation every 90 days

#### Monitoring and Logging

- **FR-018**: System MUST enable CloudWatch basic monitoring with 5-minute metric intervals
- **FR-019**: System MUST stream SSH authentication logs to CloudWatch Logs
- **FR-020**: System MUST configure CloudWatch Logs retention period to 7 days for cost optimization
- **FR-021**: System MUST collect basic instance metrics including CPU utilization, network traffic, and disk I/O

#### Cost Management

- **FR-022**: System MUST use t3.micro instance type to maintain estimated monthly cost around $7/month for compute
- **FR-023**: System MUST use elastic IP which incurs no charge while attached to running instance
- **FR-024**: System MUST optimize CloudWatch costs by using 5-minute basic monitoring instead of 1-minute detailed monitoring
- **FR-025**: System MUST limit CloudWatch Logs retention to 7 days to control storage costs

### Key Entities

- **EC2 Instance**: Represents the virtual machine resource running in AWS with specifications (t3.micro, us-east-1), network configuration (public subnet, elastic IP), and lifecycle state (running/stopped). Contains operating system, SSH service, user accounts, and monitoring agents.

- **Security Group**: Represents network firewall rules controlling inbound and outbound traffic to the EC2 instance. Contains rules defining allowed protocols (TCP), ports (22), and source IP ranges (0.0.0.0/0 for SSH).

- **User Account (devuser)**: Represents the operating system user account with attributes including username ('devuser'), password (encrypted, meeting complexity requirements), sudo privileges, and password expiry date (90 days from creation).

- **Elastic IP**: Represents the static public IPv4 address resource allocated to AWS account and associated with the EC2 instance network interface. Ensures consistent public IP across instance reboots.

- **CloudWatch Log Stream**: Represents the continuous stream of SSH authentication events including timestamp, source IP, username, and authentication result (success/failure). Organized under log group with 7-day retention policy.

- **HCP Terraform Workspace**: Represents the remote execution environment containing Terraform state, variables (AWS credentials, region configuration), and execution history. Links to AWS provider and manages infrastructure lifecycle.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Infrastructure deployment completes within 5 minutes from Terraform apply initiation to instance reaching "running" state
- **SC-002**: SSH connection establishment succeeds within 10 seconds of entering correct credentials from any internet-connected workstation
- **SC-003**: Failed SSH authentication attempts are blocked after 5 failed attempts within 10 minutes, preventing brute-force attacks
- **SC-004**: SSH authentication events appear in CloudWatch Logs within 2 minutes of occurrence for real-time monitoring
- **SC-005**: Monthly AWS costs remain within $50 budget with t3.micro instance running 24/7 (estimated $7-10/month for compute, $1-2/month for CloudWatch)
- **SC-006**: System maintains 99% SSH availability during business hours (9 AM - 5 PM EST, Monday-Friday) for development access
- **SC-007**: Password complexity requirements reject 100% of password attempts that don't meet minimum 14 character and complexity criteria
- **SC-008**: SSH session timeout occurs within 60 seconds after 30 minutes of idle time (allowing grace period for TCP termination)
- **SC-009**: CloudWatch Logs storage remains under 1 GB per month with 7-day retention, minimizing storage costs
- **SC-010**: Zero manual AWS Console operations required after initial HCP Terraform workspace configuration for complete deployment

## Assumptions *(mandatory)*

### Infrastructure Assumptions

- **A-001**: Default VPC exists in us-east-1 region with at least one public subnet available for instance placement
- **A-002**: HCP Terraform workspace has valid AWS credentials configured with permissions to create EC2 instances, security groups, elastic IPs, and CloudWatch resources
- **A-003**: AWS account has available elastic IP quota (default limit is 5 per region)
- **A-004**: AWS account is not restricted by Organizations SCPs that would block public instance deployment or password-based SSH
- **A-005**: Instance will use latest Amazon Linux 2023 AMI available in us-east-1 region
- **A-006**: Public subnet has automatic public IP assignment disabled (relying on elastic IP for public connectivity)

### Security Assumptions

- **A-007**: Public SSH access with password authentication is acceptable risk posture for development environment, not production
- **A-008**: Initial devuser password will be generated securely during provisioning and communicated out-of-band (not stored in plain text in Terraform state)
- **A-009**: AWS Systems Manager Session Manager serves as emergency fallback access if SSH is locked out
- **A-010**: Fail2ban persistent blocking is not required - 1 hour block duration sufficient for development use case
- **A-011**: Single sudo user account (devuser) is sufficient for development workload - no additional users required
- **A-012**: Password rotation can be performed manually every 90 days (automated rotation not required for development environment)

### Operational Assumptions

- **A-013**: Instance will run 24/7 for development availability - no auto-stop/start scheduling implemented
- **A-014**: Basic CloudWatch monitoring (5-minute intervals) provides sufficient observability for development use case
- **A-015**: 7-day log retention balances operational visibility with cost optimization needs
- **A-016**: Instance backup/disaster recovery not required for development environment (can be rebuilt from Terraform)
- **A-017**: Manual security patching is acceptable - automated patching not implemented initially

### Cost Assumptions

- **A-018**: t3.micro instance running 24/7 costs approximately $7.50/month based on on-demand pricing
- **A-019**: Elastic IP costs $0/month while attached to running instance
- **A-020**: CloudWatch Logs ingestion costs approximately $0.50/GB with expected 100-200 MB/month from SSH logs
- **A-021**: CloudWatch basic monitoring is included at no additional cost (detailed monitoring would add ~$2/month)
- **A-022**: Data transfer costs minimal for SSH traffic (<1 GB/month expected)

### Technical Assumptions

- **A-023**: T3.micro unlimited mode not required - baseline CPU performance (10% utilization) sufficient for development SSH access and light workloads
- **A-024**: Default 8 GB root volume sufficient for operating system, tools, and development files
- **A-025**: IPv4-only connectivity sufficient - IPv6 not required
- **A-026**: Single availability zone deployment acceptable for development (no high availability requirements)
- **A-027**: SSH connection quality acceptable over public internet without VPN or Direct Connect

## Dependencies *(include if applicable)*

### External Dependencies

- **D-001**: AWS Account must be active and in good standing with payment method configured
- **D-002**: HCP Terraform organization "ravi-panchal-org" must exist with active subscription
- **D-003**: AWS provider version >= 5.0 required for Terraform configuration compatibility
- **D-004**: Internet connectivity required for SSH access from development workstations
- **D-005**: CloudWatch Logs agent compatible with Amazon Linux 2023 operating system

### Configuration Dependencies

- **D-006**: AWS access key ID and secret access key must be configured in HCP Terraform workspace as sensitive variables
- **D-007**: AWS region "us-east-1" must be specified in Terraform provider configuration
- **D-008**: SSH client software required on developer workstations (OpenSSH, PuTTY, or equivalent)
- **D-009**: Terraform version >= 1.5.0 required for HCP Terraform integration features

### Workflow Dependencies

- **D-010**: HCP Terraform workspace must be configured for remote execution (not local execution mode)
- **D-011**: Version control system (Git) required for managing Terraform configuration files
- **D-012**: Initial password generation requires secure communication channel (not email) for password delivery to authorized users

## Out of Scope *(include if applicable)*

### Explicitly Excluded

- **OOS-001**: SSH key-based authentication - only password authentication is implemented
- **OOS-002**: Multi-factor authentication (MFA) for SSH access - not required for development environment
- **OOS-003**: Private VPC deployment with bastion host or VPN access - instance must be publicly accessible
- **OOS-004**: High availability configuration with multiple instances across availability zones
- **OOS-005**: Auto-scaling capabilities - single fixed-size instance only
- **OOS-006**: Load balancer or DNS configuration - direct IP access only
- **OOS-007**: Automated backup and disaster recovery procedures - instance can be rebuilt from code
- **OOS-008**: Custom AMI creation with pre-installed tools - use standard Amazon Linux 2023 AMI
- **OOS-009**: Integration with corporate identity providers (LDAP, Active Directory, Okta)
- **OOS-010**: Detailed CloudWatch monitoring with 1-minute intervals - basic 5-minute monitoring only
- **OOS-011**: CloudWatch alarms and SNS notifications for monitoring events
- **OOS-012**: AWS Config rules or Security Hub integration for compliance scanning
- **OOS-013**: Automated security patching through AWS Systems Manager Patch Manager
- **OOS-014**: Instance scheduler for automatic start/stop to reduce costs
- **OOS-015**: Additional user accounts beyond devuser - single-user configuration only
- **OOS-016**: Custom port configuration - SSH remains on standard port 22
- **OOS-017**: Geographic IP restrictions beyond 0.0.0.0/0 - open public access required
- **OOS-018**: Web-based SSH access through AWS Systems Manager Session Manager GUI
- **OOS-019**: Integration with HashiCorp Vault for secrets management
- **OOS-020**: Terraform modules for reusability - inline configuration acceptable for single instance

### Future Considerations

- **FC-001**: Migration to SSH key-based authentication for improved security posture
- **FC-002**: Implementation of IP allowlist restricting SSH access to known office/VPN IPs
- **FC-003**: Upgrade to larger instance type if development workload requires more resources
- **FC-004**: Addition of AWS Systems Manager Session Manager for browser-based access
- **FC-005**: Integration with centralized logging system (ELK stack, Splunk) if multi-instance deployment grows

## Risk Assessment *(include if applicable)*

### Security Risks

- **RISK-001**: **High Severity** - Public SSH with password authentication exposes instance to brute-force attacks
  - **Mitigation**: Fail2ban blocks IPs after 5 failed attempts; strong password policy (14+ chars); acceptable for development environment only
  - **Residual Risk**: Sophisticated distributed attacks may still succeed; recommend monitoring CloudWatch Logs for unusual patterns

- **RISK-002**: **Medium Severity** - Single sudo user account creates privileged access concentration
  - **Mitigation**: Strong password requirements and session timeouts reduce credential compromise impact
  - **Residual Risk**: Compromised credentials grant full instance control; recommend regular password rotation every 90 days

- **RISK-003**: **Medium Severity** - Public security group (0.0.0.0/0) increases attack surface
  - **Mitigation**: Only SSH port 22 exposed; fail2ban provides brute-force protection
  - **Residual Risk**: SSH vulnerabilities could be exploited; recommend keeping OS and SSH packages updated

### Operational Risks

- **RISK-004**: **Low Severity** - Manual password management may lead to expired or forgotten credentials
  - **Mitigation**: Password expiry set to 90 days with advance notification; AWS Systems Manager Session Manager available as fallback access
  - **Residual Risk**: User lockout if both SSH and Session Manager fail; AWS Console serial console provides emergency access

- **RISK-005**: **Low Severity** - Single instance deployment has no redundancy
  - **Mitigation**: Acceptable for development environment; Terraform code enables rapid rebuild (5 minutes)
  - **Residual Risk**: Instance failure causes complete service outage; not acceptable for production workloads

- **RISK-006**: **Low Severity** - T3 micro instance may experience CPU throttling after credit exhaustion
  - **Mitigation**: Baseline 10% CPU performance sufficient for SSH and light development tasks
  - **Residual Risk**: CPU-intensive workloads may experience significant slowdowns; monitor CPU credit balance in CloudWatch

### Cost Risks

- **RISK-007**: **Low Severity** - Unexpected data transfer costs if instance is compromised and used for data exfiltration
  - **Mitigation**: CloudWatch monitoring tracks network metrics; monthly cost monitoring through AWS Budgets
  - **Residual Risk**: Large-scale data transfer could exceed $50 budget; recommend setting up AWS Budget alert at $40 threshold

- **RISK-008**: **Low Severity** - Elastic IP charges if instance is stopped ($0.01/hour = ~$7/month)
  - **Mitigation**: Instance configured to run 24/7; document warning about stopping instance
  - **Residual Risk**: Accidental instance stop incurs unexpected costs; recommend CloudWatch alarm for instance state changes

### Compliance Risks

- **RISK-009**: **High Severity** - Configuration violates standard security best practices and most compliance frameworks (PCI-DSS, HIPAA, SOC 2)
  - **Mitigation**: Instance explicitly tagged with "Environment=development" and "PublicAccess=true" for audit trail; documentation clearly states development-only usage
  - **Residual Risk**: Cannot be used for production workloads or sensitive data; requires architecture redesign for compliance needs
