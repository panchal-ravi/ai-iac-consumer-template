# Example: EC2 Instance with ALB and Nginx

## Infrastructure Requirements

Provision using Terraform:
- EC2 instances across 2 AZs
- create basic static content page for testing
- HTTPS and Nginx
- Self-signed certificate for domain "web.demo.com"
- Import certificate into AWS ACM, no domain validation required 
- ALB (Application Load Balancer)
- AWS Region: `ap-southeast-1`
- Use existing default VPC
- enviromnment development minimal cost
- Use existing default VPC always

## HCP Terraform Configuration

- **Organization**: `ravi-panchal-org`
- **Project**: `Default Project`
- **Workspace**: `sandbox_ec2<GITHUB_REPO_NAME>`

## Workflow Instructions

- Use terraform-consumer-design skill to plan, design and create tasks based on infrastructure requirements. 
- Prompt user to review and approve the design (human-in-the-loop) before proceeding to the implementation stage.
- Upon approval, use terraform-consumer-implemet skill to provision infrastructure based on the approved design.
