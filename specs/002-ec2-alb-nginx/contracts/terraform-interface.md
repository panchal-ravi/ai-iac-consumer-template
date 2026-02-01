# Terraform Module Interface Contract

**Feature**: 002-ec2-alb-nginx  
**Date**: 2025-02-01  
**Type**: Infrastructure Interface Definition

## Overview

This contract defines the interface for the EC2 ALB Nginx infrastructure module, including required inputs, generated outputs, and behavioral guarantees.

---

## Module Inputs (variables.tf)

### Required Variables

#### region
- **Type**: `string`
- **Description**: AWS region for resource deployment
- **Validation**: Must be valid AWS region code
- **Example**: `"ap-southeast-1"`
- **FR Reference**: Implicit (all resources in same region)

#### project_name
- **Type**: `string`
- **Description**: Project name prefix for all resources
- **Validation**: Alphanumeric and hyphens only, 3-32 characters
- **Example**: `"nginx-alb"`
- **FR Reference**: FR-015 (resource naming)

#### environment
- **Type**: `string`
- **Description**: Deployment environment identifier
- **Validation**: Must be one of: `["development", "staging", "production"]`
- **Example**: `"development"`
- **FR Reference**: FR-015 (tagging requirement)

#### availability_zones
- **Type**: `list(string)`
- **Description**: List of availability zones for EC2 instance distribution
- **Validation**: 
  - Exactly 2 availability zones required
  - Must be valid AZs in specified region
  - Must be different AZs
- **Example**: `["ap-southeast-1a", "ap-southeast-1b"]`
- **FR Reference**: FR-001 (2 AZs required)

#### domain_name
- **Type**: `string`
- **Description**: Domain name for self-signed TLS certificate
- **Validation**: Valid domain name format
- **Example**: `"web.demo.com"`
- **FR Reference**: FR-003 (certificate domain)

### Optional Variables with Defaults

#### instance_type
- **Type**: `string`
- **Description**: EC2 instance type for Nginx servers
- **Default**: `"t3a.micro"`
- **Validation**: Valid EC2 instance type
- **FR Reference**: FR-014 (cost-effective instances)

---

## Module Outputs (outputs.tf)

### Load Balancer Outputs

#### alb_dns_name
- **Type**: `string`
- **Description**: DNS name of the Application Load Balancer
- **Usage**: Access point for HTTPS traffic
- **Example**: `"nginx-alb-123456789.ap-southeast-1.elb.amazonaws.com"`
- **FR Reference**: SC-001 (access via ALB DNS)

#### ec2_instance_ids
- **Type**: `list(string)`
- **Description**: List of EC2 instance IDs
- **Usage**: Instance management, monitoring, SSH access
- **FR Reference**: SC-010 (instance identification)

---

## Behavioral Contract

### Deployment Guarantees

1. **Availability Zone Distribution** (FR-001)
   - MUST create exactly 2 EC2 instances
   - MUST distribute instances across 2 different availability zones

2. **HTTPS Access** (FR-003, FR-005, FR-009)
   - MUST configure ALB with HTTPS listener on port 443
   - MUST use provided self-signed certificate
   - MUST allow inbound traffic from 0.0.0.0/0 on port 443
   - MUST NOT configure HTTP listener

3. **Security Isolation** (FR-011)
   - MUST configure security groups to block direct public access to EC2 instances
   - MUST allow traffic only from ALB to EC2 instances on port 80

4. **High Availability** (SC-003)
   - MUST maintain service availability if one instance fails
   - MUST continue serving traffic from remaining healthy instance

---

**Contract Complete**: Interface documented. See full contract for complete details.
