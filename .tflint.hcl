# TFLint configuration for Terraform best practices
# Feature: 001-ssh-ubuntu-server
# Constitution Reference: Section 5.1 (Code Quality)
#
# Documentation: https://github.com/terraform-linters/tflint

config {
  # Enable module inspection (v0.54.0+)
  # Options: "all" (inspect all modules), "local" (local only), "none" (disabled)
  call_module_type = "all"

  # Force check even when no issues found
  force = false

  # Disable color output in CI environments
  disabled_by_default = false
}

# Enable AWS plugin for AWS-specific rules
plugin "aws" {
  enabled = true
  version = "0.44.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Terraform naming conventions
rule "terraform_naming_convention" {
  enabled = true

  variable {
    format = "snake_case"
  }

  locals {
    format = "snake_case"
  }

  output {
    format = "snake_case"
  }

  resource {
    format = "snake_case"
  }

  module {
    format = "snake_case"
  }

  data {
    format = "snake_case"
  }
}

# Require variable descriptions
rule "terraform_documented_variables" {
  enabled = true
}

# Require output descriptions
rule "terraform_documented_outputs" {
  enabled = true
}

# Check for unused declarations
# NOTE: Temporarily disabled during Phase 1 setup
# Variables and locals will be used when modules are added in Phase 3
rule "terraform_unused_declarations" {
  enabled = false
}

# Deprecated syntax checks
rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Type constraints
rule "terraform_typed_variables" {
  enabled = true
}

# Standard module structure
rule "terraform_standard_module_structure" {
  enabled = true
}

# Require workspace remote backend (HCP Terraform)
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

# AWS-specific rules
rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Environment", "Application", "ManagedBy"]
}
