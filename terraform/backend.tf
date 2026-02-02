# HCP Terraform Cloud Backend Configuration
# Feature: 003-ec2-alb-nginx
# Purpose: Configure remote state management in HCP Terraform Cloud

terraform {
  cloud {
    organization = "ravi-panchal-org"

    workspaces {
      name = "sandbox_workspace"
    }
  }
}
