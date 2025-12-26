name: "🤖 Agent-Driven Infrastructure Provisioning"
description: "Template for AI agents to gather requirements for provisioning infrastructure using HCP Terraform following spec-driven workflow"
title: "[AGENT PROVISION] "
labels: ["agent-driven", "terraform", "infrastructure", "provisioning"]
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        # AI Agent Infrastructure Provisioning
        
        This template is designed for AI agents to systematically gather all required information 
        for provisioning infrastructure using HCP Terraform following the Speckit spec-driven workflow.
        
        **Agent Workflow Phases:**
        - **Phase 0**: Environment validation (`.specify/scripts/bash/validate-env.sh`)
        - **Phase 1**: Specification (`/speckit.specify` → `/speckit.clarify` → `/speckit.checklist`)
        - **Phase 2**: Planning (`/speckit.plan` → `/review-aws-security` → `/review-code-quality`  )
        - **Phase 3**: Implementation (`/speckit.tasks` → `/speckit.analyze` → `/speckit.implement`)
        - **Phase 4**: Deployment (`terraform init/plan/appl
        - **Phase 5**: Reporting (`/report-tf-deployment` → cleanup)
        - **Phase 6**: Pull Request (`gh pr create` with summary and link to issue)

  # ============================================================================
  # HCP Terraform Configuration (REQUIRED)
  # ============================================================================
  
  - type: markdown
    attributes:
      value: |
        ---
        ## 🏢 HCP Terraform Configuration
        
        **REQUIRED for workspace creation and deployment**

  - type: input
    id: hcp_org
    attributes:
      label: "HCP Terraform Organization"
      description: "Organization name in HCP Terraform (REQUIRED)"
      placeholder: "e.g., ravi-panchal-org, hashi-demos-apj, my-company-org"
    validations:
      required: true

  - type: input
    id: hcp_project
    attributes:
      label: "HCP Terraform Project"
      description: "Project name in HCP Terraform (REQUIRED)"
      placeholder: "e.g., Default Project, sandbox, production, platform-services"
    validations:
      required: true

  - type: input
    id: workspace_name
    attributes:
      label: "Workspace Name"
      description: "HCP Terraform workspace name. Pattern: sandbox_<REPO_NAME> for testing, <env>_<project_name> for production"
      placeholder: "e.g., sandbox_ec2_instance, dev_customer_portal, prod_payment_gateway"
    validations:
      required: true

  - type: dropdown
    id: terraform_version
    attributes:
      label: "Terraform Version"
      description: "Terraform version for the workspace (recommend latest stable)"
      options:
        - "Latest (recommended)"
        - "1.10.x"
        - "1.9.x"
        - "1.8.x"
        - "1.7.x"
        - "Other (specify in Additional Context)"
      default: 0
    validations:
      required: true

  # ============================================================================
  # Project Information
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 📦 Project Information

  - type: input
    id: project_name
    attributes:
      label: "Project/Application Name"
      description: "Name of the project or application this infrastructure supports"
      placeholder: "e.g., customer-portal, payment-gateway, analytics-platform, api-backend"
    validations:
      required: true

  - type: textarea
    id: business_requirements
    attributes:
      label: "Business Requirements & Use Case"
      description: "Business problem, expected outcomes, and success criteria"
      placeholder: |
        Example:
        - Deploy a development environment for testing new microservices
        - Support up to 1000 concurrent users
        - Enable rapid prototyping with minimal cost
        - Success: Developers can deploy and test code within 5 minutes
    validations:
      required: true

  # ============================================================================
  # Cloud Infrastructure Details
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## ☁️ Cloud Infrastructure Details

  - type: dropdown
    id: cloud_provider
    attributes:
      label: "Cloud Provider"
      description: "Primary cloud provider for this deployment"
      options:
        - AWS
        - Azure
        - GCP
        - Multi-cloud
        - Other
    validations:
      required: true

  - type: input
    id: cloud_region
    attributes:
      label: "Primary Cloud Region"
      description: "Primary region/location for deployment"
      placeholder: "e.g., us-east-1, ap-southeast-1, eastus, us-central1, eu-west-1"
    validations:
      required: true

  - type: textarea
    id: additional_regions
    attributes:
      label: "Additional Regions (Multi-Region)"
      description: "List additional regions if this is a multi-region deployment"
      placeholder: |
        Example:
        - us-west-2 (secondary/failover)
        - eu-west-1 (DR)
        - ap-southeast-1 (edge location)

  - type: dropdown
    id: environment
    attributes:
      label: "Environment"
      description: "Target environment for this infrastructure"
      options:
        - development
        - sandbox
        - test
        - staging
        - production
        - dr (disaster recovery)
      default: 1
    validations:
      required: true

  - type: textarea
    id: cloud_account_details
    attributes:
      label: "Cloud Account/Subscription Details"
      description: "Cloud account information (ID, subscription, project)"
      placeholder: |
        Example (AWS):
        - AWS Account ID: 123456789012
        - Account Name: dev-account
        
        Example (Azure):
        - Subscription ID: sub-dev-12345
        - Subscription Name: Development
        
        Example (GCP):
        - Project ID: my-project-dev-123
        - Project Name: Dev Environment

  # ============================================================================
  # Infrastructure Components
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 🏗️ Infrastructure Components to Provision

  - type: textarea
    id: infrastructure_components
    attributes:
      label: "Infrastructure Components"
      description: "Detailed list of infrastructure resources to provision"
      placeholder: |
        Example:
        - EC2 instance (t3.medium) accessible via SSH
        - VPC with public/private subnets (10.0.0.0/16)
        - Security group allowing SSH from specific IP
        - RDS PostgreSQL database (Multi-AZ, db.t3.medium)
        - Application Load Balancer with HTTPS listener
        - S3 bucket for application storage and logs
        - CloudFront distribution for static assets
        - Route53 DNS records (app.example.com)
        - Auto-scaling group (min: 2, max: 10)
        - CloudWatch dashboards and alarms
    validations:
      required: true

  - type: textarea
    id: existing_infrastructure
    attributes:
      label: "Existing Infrastructure to Reference"
      description: "Existing resources to integrate with (will use Terraform data sources)"
      placeholder: |
        Example:
        - Use existing default VPC (data source)
        - Existing KMS key: alias/shared-app-key or arn:aws:kms:...
        - Corporate DNS zone: company.internal (Route53 zone ID)
        - Shared security group: sg-12345678
        - Existing IAM role: arn:aws:iam::123456789012:role/app-role
        - Shared Transit Gateway: tgw-0123456789abcdef

  # ============================================================================
  # Terraform Module Strategy
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 📚 Terraform Module Strategy
        
        **Agent will search HCP Terraform private registry first using MCP tools**

  - type: dropdown
    id: module_preference
    attributes:
      label: "Module Source Preference"
      description: "Where should the agent look for Terraform modules?"
      options:
        - "Private Registry Only (recommended - most secure)"
        - "Private Registry First, Public if Approved by User"
        - "Public Registry Allowed"
      default: 0
    validations:
      required: true

  - type: textarea
    id: known_private_modules
    attributes:
      label: "Known Private Modules (Optional)"
      description: "If you know specific private modules to use, list them (agent will search registry regardless)"
      placeholder: |
        Example:
        - app.terraform.io/ravi-panchal-org/vpc/aws
        - app.terraform.io/ravi-panchal-org/ec2-instance/aws
        - app.terraform.io/ravi-panchal-org/security-group/aws
        - app.terraform.io/my-org/rds/aws
        
        Note: Agent will use MCP search_private_modules to discover available modules

  # ============================================================================
  # Security & Compliance
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 🔒 Security & Compliance Requirements

  - type: checkboxes
    id: security_requirements
    attributes:
      label: "Security Controls"
      description: "Select all security requirements that apply"
      options:
        - label: "Encryption at rest using KMS/customer-managed keys"
        - label: "Encryption in transit (TLS/SSL, HTTPS only)"
        - label: "Network isolation (private subnets, security groups, NACLs)"
        - label: "IAM least privilege access (no wildcard permissions)"
        - label: "Secrets management (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault)"
        - label: "Audit logging and monitoring (CloudTrail, CloudWatch, Azure Monitor)"
        - label: "Backup and disaster recovery enabled"
        - label: "Public access blocking (no public IPs unless required)"
        - label: "VPC Flow Logs / Network Security Group logs"
        - label: "WAF/DDoS protection (CloudFront, WAF, Azure DDoS)"
        - label: "Certificate management (ACM, Let's Encrypt)"
        - label: "MFA required for sensitive operations"

  - type: textarea
    id: compliance_standards
    attributes:
      label: "Compliance Standards & Frameworks"
      description: "List compliance frameworks this deployment must meet"
      placeholder: |
        Example:
        - SOC 2 Type II
        - PCI DSS Level 1
        - HIPAA
        - GDPR (EU data residency)
        - ISO 27001
        - CIS AWS Foundations Benchmark Level 2
        - Company Security Policy v2.3
        - FedRAMP Moderate

  - type: textarea
    id: specific_security_requirements
    attributes:
      label: "Specific Security Requirements"
      description: "Detailed security configurations and constraints"
      placeholder: |
        Example:
        - SSH access using username/password (no key pairs)
        - Allow SSH only from IP: 203.0.113.0/24
        - All S3 buckets must block public access
        - Database backups encrypted with specific KMS key
        - All resources must be tagged with SecurityClassification
        - No cross-region data transfer allowed
        - Session timeout: 15 minutes for admin console

  # ============================================================================
  # Configuration Parameters
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## ⚙️ Configuration Parameters

  - type: textarea
    id: configuration_values
    attributes:
      label: "Key Configuration Values"
      description: "Important configuration parameters (agent will prompt for missing required values)"
      placeholder: |
        Example:
        - Instance type: t3.medium (2 vCPU, 4 GB RAM)
        - VPC CIDR: 10.0.0.0/16
        - Public subnet CIDRs: 10.0.1.0/24, 10.0.2.0/24
        - Private subnet CIDRs: 10.0.10.0/24, 10.0.11.0/24
        - Database storage: 100 GB
        - Database engine version: PostgreSQL 15.4
        - Auto-scaling: min=2, max=10, desired=3
        - Backup retention: 7 days
        - SSH port: 22
        - Application port: 8080
        - SSL/TLS certificate: *.example.com
        - Session affinity: enabled (sticky sessions)

  - type: textarea
    id: resource_tags
    attributes:
      label: "Resource Tagging Strategy"
      description: "Required tags for all provisioned resources (for cost tracking, compliance, automation)"
      placeholder: |
        Example:
        - Environment: {{ environment }}
        - Project: {{ project_name }}
        - ManagedBy: terraform
        - Owner: platform-team@company.com
        - CostCenter: CC-12345
        - BusinessUnit: Engineering
        - Application: customer-portal
        - Terraform: true
        - BackupPolicy: daily
        - DataClassification: confidential
        - ComplianceFramework: soc2

  # ============================================================================
  # Cost Optimization
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 💰 Cost Optimization & Budget

  - type: dropdown
    id: cost_optimization
    attributes:
      label: "Cost Optimization Priority"
      description: "How should the agent optimize for cost?"
      options:
        - "Minimal cost (use smallest viable resources, spot instances where possible)"
        - "Balanced (cost vs. performance/reliability)"
        - "Performance prioritized (cost secondary concern)"
        - "No specific constraints (agent decides based on requirements)"
      default: 0

  - type: input
    id: monthly_budget
    attributes:
      label: "Monthly Budget (USD)"
      description: "Estimated or maximum monthly budget (optional but helps agent make informed decisions)"
      placeholder: "e.g., 500, 1000, 5000, 25000"

  - type: textarea
    id: cost_constraints
    attributes:
      label: "Cost Constraints & Optimization"
      description: "Specific cost optimization requirements or constraints"
      placeholder: |
        Example:
        - Monthly budget: $500 for dev, $5000 for prod
        - Use Reserved Instances for predictable workloads
        - Enable S3 Intelligent-Tiering
        - Use Spot instances for batch processing (non-critical)
        - Auto-shutdown dev resources outside business hours (9 AM - 6 PM weekdays)
        - Cost anomaly alerts at 20% variance
        - Use GP3 instead of GP2 for EBS volumes
        - Lifecycle policies: 90 days to Glacier, 365 days delete

  # ============================================================================
  # Network & Connectivity
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 🌐 Network & Connectivity Requirements

  - type: checkboxes
    id: network_requirements
    attributes:
      label: "Network Features"
      description: "Select all networking features needed"
      options:
        - label: "Public internet access required (Internet Gateway)"
        - label: "Private networking only (no public IPs)"
        - label: "NAT Gateway for outbound traffic from private subnets"
        - label: "VPN connectivity to on-premises network"
        - label: "VPC peering with other VPCs"
        - label: "PrivateLink / Private endpoints for AWS services"
        - label: "Direct Connect / ExpressRoute / Cloud Interconnect"
        - label: "Custom DNS configuration (Route53, Azure DNS)"
        - label: "Transit Gateway / VNet peering hub"
        - label: "Load balancer (Application/Network/Classic)"
        - label: "VPC Flow Logs / NSG Flow Logs enabled"
        - label: "IPv6 support required"

  - type: textarea
    id: network_details
    attributes:
      label: "Network Configuration Details"
      description: "Specific network requirements, CIDR blocks, connectivity details"
      placeholder: |
        Example:
        - VPC CIDR: 10.0.0.0/16
        - Public subnets: 10.0.1.0/24 (AZ-a), 10.0.2.0/24 (AZ-b)
        - Private subnets: 10.0.10.0/24 (AZ-a), 10.0.11.0/24 (AZ-b)
        - Allow SSH from IP: 203.0.113.0/24 (office network)
        - Allow HTTPS from: 0.0.0.0/0 (public internet)
        - VPN to on-premises: 192.168.0.0/16
        - Peering with VPC vpc-12345678 (shared services)
        - Internal DNS domain: internal.company.com
        - PrivateLink endpoints: S3, ECR, SecretsManager
        - Load balancer idle timeout: 60 seconds
        - Enable cross-zone load balancing

  # ============================================================================
  # Monitoring, Logging & Observability
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 📊 Monitoring, Logging & Observability

  - type: textarea
    id: monitoring_requirements
    attributes:
      label: "Monitoring & Alerting"
      description: "Monitoring, logging, and alerting requirements"
      placeholder: |
        Example:
        - CloudWatch dashboards for CPU, memory, disk, network
        - CloudWatch Logs for application and system logs
        - Log retention: 90 days (CloudWatch), 1 year (S3 archive)
        - Metrics: CPU > 80%, Memory > 85%, Disk > 90%
        - SNS alerts for high CPU/memory usage
        - PagerDuty integration for critical alerts
        - Slack notifications for deployment status
        - Application performance monitoring (APM): Datadog/New Relic
        - Distributed tracing: AWS X-Ray
        - Custom metrics: API latency, error rates, throughput

  - type: textarea
    id: backup_dr_requirements
    attributes:
      label: "Backup & Disaster Recovery"
      description: "Backup, snapshot, and disaster recovery requirements"
      placeholder: |
        Example:
        - RDS automated backups: daily at 3 AM UTC
        - Backup retention: 7 days (RDS), 30 days (EBS snapshots)
        - S3 bucket versioning enabled
        - Cross-region replication to us-west-2 (DR region)
        - EBS volume snapshots: daily
        - RTO: 4 hours (time to recover)
        - RPO: 1 hour (acceptable data loss)
        - DR testing: quarterly
        - Backup encryption: KMS key alias/backup-key

  # ============================================================================
  # Agent Workflow Configuration
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 🤖 Agent Workflow Configuration
        
        **Spec-Driven Development with GitHub Speckit**
        
        The agent will follow a structured workflow:
        1. **validate-env.sh** - Verify prerequisites and credentials
        2. **/speckit.specify** - Generate feature specification (spec.md)
        3. **/speckit.clarify** - Resolve underspecified areas
        4. **/speckit.checklist** - Validate requirements quality
        5. **/speckit.plan** - Create implementation plan (plan.md, data-model.md)
        6. **/review-aws-security** - Review and approve Terraform design
        7. **/review-code-quality** - Review and approve code quality
        8. **/speckit.tasks** - Generate dependency-ordered tasks (tasks.md)
        9. **/speckit.analyze** - Cross-artifact consistency analysis
        10. **/speckit.implement** - Execute implementation with testing
        11. **Deploy** - Terraform init/plan/apply via CLI (NOT MCP)
        12. **/report-tf-deployment** - Generate deployment report
        13. **Cleanup** - Optionally destroy resources (requires approval)
        14. **Create PR** - Create pull request with summary linking to this issue

  - type: checkboxes
    id: workflow_preferences
    attributes:
      label: "Workflow Execution Preferences"
      description: "How should the agent execute the workflow?"
      options:
        - label: "✅ Create new Git branch for this work"
        - label: "✅ Follow complete Speckit workflow (all phases)"
        - label: "✅ Make best-practice decisions independently (fully autonomous)"
        - label: "✅ Use spec-quality-judge subagent to evaluate specifications"
        - label: "✅ Use code-quality-judge subagent to evaluate Terraform code"
        - label: "✅ Use aws-security-advisor subagent for security validation"
        - label: "✅ Run automated testing in sandbox workspace (init/plan only)"
        - label: "✅ Commit changes after each major phase completion"
        - label: "✅ Update GitHub issue with progress comments"
        - label: "✅ Generate comprehensive deployment report"
        - label: "✅ Create pull request for review after completion"
        - label: "⚠️ Deploy to production (apply) - requires explicit approval"
        - label: "🗑️ Keep sandbox resources after validation (default: destroy)"

  - type: dropdown
    id: agent_autonomy
    attributes:
      label: "Agent Autonomy Level"
      description: "How autonomous should the agent be in making decisions?"
      options:
        - "🤖 Fully Autonomous (make all decisions, resolve issues independently, no prompts)"
        - "🤝 Semi-Autonomous (ask for approval on major decisions like module choices)"
        - "💬 Interactive (prompt frequently for guidance and confirmations)"
      default: 0
    validations:
      required: true

  - type: checkboxes
    id: speckit_phases
    attributes:
      label: "Speckit Workflow Phases to Execute"
      description: "Select which phases the agent should execute (recommended: all phases for production)"
      options:
        - label: "Phase 0: Environment Validation & Setup (validate-env.sh)"
        - label: "Phase 1: Specification (specify → clarify → checklist)"
        - label: "Phase 2: Planning (plan → review-tf-design)"
        - label: "Phase 3: Implementation (tasks → analyze → implement)"
        - label: "Phase 4: Deployment (terraform init/plan/apply)"
        - label: "Phase 5: Reporting & Cleanup (report → destroy if approved)"
        - label: "Phase 6: Pull Request Creation (create PR with summary and link to issue)"

  # ============================================================================
  # Additional Context & Success Criteria
  # ============================================================================

  - type: markdown
    attributes:
      value: |
        ---
        ## 📄 Additional Information

  - type: textarea
    id: additional_context
    attributes:
      label: "Additional Context & Special Requirements"
      description: "Any other information, constraints, dependencies, or special requirements"
      placeholder: |
        Example:
        - This replaces an existing manual CloudFormation deployment
        - Integration with existing CI/CD pipeline (GitHub Actions)
        - Must complete within 2 weeks for product launch
        - Part of larger migration project (phase 2 of 4)
        - Must follow company-specific architectural patterns
        - Team training required after deployment
        - Handoff to operations team after go-live
        - Dependencies: Auth service must be deployed first
        - Cannot use certain instance types (licensing restrictions)
        - Must use specific AMI: ami-0123456789abcdef (hardened)
        - Deployment window: Saturdays 2 AM - 6 AM UTC only

  - type: textarea
    id: success_criteria
    attributes:
      label: "Success Criteria & Acceptance"
      description: "How will we know this provisioning is successful? What are the acceptance criteria?"
      placeholder: |
        Example:
        - ✅ Infrastructure deployed and accessible via HTTPS
        - ✅ All security controls validated (encryption, network isolation, IAM)
        - ✅ Passes automated testing (terraform validate, plan, Sentinel policies)
        - ✅ Code quality score > 80% (code-quality-judge)
        - ✅ Specification quality score > 80% (spec-quality-judge)
        - ✅ Security scan passes with no CRITICAL/HIGH findings
        - ✅ Documentation generated (README, architecture diagram)
        - ✅ Team can successfully deploy application to infrastructure
        - ✅ Monitoring dashboards and alerts configured
        - ✅ Backup and DR tested successfully
        - ✅ Costs within budget ($500/month target)
        - ✅ All Terraform code committed to feature branch
        - ✅ Pull request created for review

  - type: textarea
    id: constraints_limitations
    attributes:
      label: "Known Constraints or Limitations"
      description: "Technical, organizational, or timeline constraints"
      placeholder: |
        Example:
        - Cannot modify existing VPC configuration (shared with other teams)
        - Limited to specific AWS services by company policy
        - Cannot use GPU instances (cost constraint)
        - Must use specific Terraform provider versions
        - No direct internet access from private subnets (compliance)
        - Deployment must not disrupt existing production services
        - Cannot deploy on Fridays (change freeze)
        - Limited AWS service quota: EC2 instances (50), EIP (5)
        - Must use company-approved base AMIs only
        - No Terraform workspaces - use separate workspace per environment
