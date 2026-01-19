#!/bin/bash
# Setup script for HCP Terraform workspace variables

set -e

echo "========================================="
echo "EC2 Instance Workspace Setup"
echo "========================================="
echo ""

# Prompt for required values
read -p "Enter VPC ID (e.g., vpc-xxxxx): " VPC_ID
read -p "Enter Subnet ID (e.g., subnet-xxxxx): " SUBNET_ID
read -p "Enter admin username [devadmin]: " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-devadmin}
read -sp "Enter admin password (min 12 chars): " ADMIN_PASSWORD
echo ""

# Validate inputs
if [ -z "$VPC_ID" ] || [ -z "$SUBNET_ID" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "Error: All fields are required!"
    exit 1
fi

if [ ${#ADMIN_PASSWORD} -lt 12 ]; then
    echo "Error: Password must be at least 12 characters!"
    exit 1
fi

echo ""
echo "Setting up workspace variables..."
echo ""

# Set variables using gh CLI
gh copilot terraform-mcp-server create_workspace_variable \
  --terraform_org_name ravi-panchal-org \
  --workspace_name sandbox_public_ec2_dev \
  --key vpc_id \
  --value "$VPC_ID" \
  --category terraform

gh copilot terraform-mcp-server create_workspace_variable \
  --terraform_org_name ravi-panchal-org \
  --workspace_name sandbox_public_ec2_dev \
  --key subnet_id \
  --value "$SUBNET_ID" \
  --category terraform

gh copilot terraform-mcp-server create_workspace_variable \
  --terraform_org_name ravi-panchal-org \
  --workspace_name sandbox_public_ec2_dev \
  --key admin_username \
  --value "$ADMIN_USERNAME" \
  --category terraform \
  --sensitive true

gh copilot terraform-mcp-server create_workspace_variable \
  --terraform_org_name ravi-panchal-org \
  --workspace_name sandbox_public_ec2_dev \
  --key admin_password \
  --value "$ADMIN_PASSWORD" \
  --category terraform \
  --sensitive true

echo ""
echo "✅ Workspace variables configured successfully!"
echo ""
echo "Next steps:"
echo "1. Run: terraform init"
echo "2. Run: terraform plan"
echo "3. Run: terraform apply"
echo ""
