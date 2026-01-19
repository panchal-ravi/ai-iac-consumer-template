# Backend configuration for HCP Terraform
# Feature: 001-public-ec2-password-auth
# Organization: ravi-panchal-org
# Workspace: sandbox_public_ec2_dev

terraform {
  cloud {
    organization = "ravi-panchal-org"

    workspaces {
      name = "sandbox_public_ec2_dev"
    }
  }
}
