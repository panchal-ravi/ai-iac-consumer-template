# Sandbox Environment Configuration
# Feature: 003-ec2-alb-nginx
# HCP Terraform Workspace: sandbox_workspace

# Project Configuration
project_name = "ec2-alb-nginx"
environment  = "development"

# AWS Configuration
aws_region = "ap-southeast-1"

# Network Configuration (uses existing default VPC)
# VPC and subnet IDs will be discovered dynamically via data sources

# Certificate Configuration
domain_name               = "web.demo.com"
certificate_validity_days = 90

# EC2 Configuration
instance_type  = "t3.micro"
instance_count = 2

# ALB Configuration
alb_internal      = false
health_check_path = "/health"
