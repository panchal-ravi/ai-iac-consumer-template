# Example: EC2 Instance with ALB and Nginx

## Infrastructure Requirements

Provision using Terraform:
- EC2 instances across 2 AZs
- HTTPS and Nginx
- Self-signed certificate for domain "web.demo.com"
- Import certificate into AWS ACM, no domain validation required 
- ALB (Application Load Balancer)
- AWS Region: `ap-southeast-1`
- Use existing default VPC
- enviromnment development minimal cost

## HCP Terraform Configuration

- **Organization**: `ravi-panchal-org`
- **Project**: `Default Project`
- **Workspace**: `sandbox_ec2<GITHUB_REPO_NAME>`
