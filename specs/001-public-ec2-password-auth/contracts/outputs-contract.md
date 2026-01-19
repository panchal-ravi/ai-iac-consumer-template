# Terraform Output Contracts

**Feature**: Public EC2 Instance with Password Authentication  
**Purpose**: Define all output values exposed after infrastructure provisioning  

---

## Public Outputs

### 1. Instance Information

```hcl
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2_instance.id
}

output "instance_public_ip" {
  description = "Elastic IP address of the instance"
  value       = module.ec2_instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = module.ec2_instance.private_ip
}

output "availability_zone" {
  description = "Availability zone where instance is running"
  value       = module.ec2_instance.availability_zone
}
```

### 2. Network Information

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = local.subnet_id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.ec2_instance.security_group_id
}
```

### 3. CloudWatch Logging

```hcl
output "cloudwatch_log_group" {
  description = "CloudWatch log group name for SSH logs"
  value       = module.cloudwatch_logs.log_group_name
}

output "cloudwatch_log_stream" {
  description = "CloudWatch log stream pattern"
  value       = "{instance_id}"
}
```

### 4. Connection Information

```hcl
output "ssh_username" {
  description = "SSH username for connecting"
  value       = "devuser"
}

output "ssh_command" {
  description = "SSH command to connect (requires password from workspace)"
  value       = "ssh devuser@${module.ec2_instance.public_ip}"
}
```

---

## Sensitive Outputs

### 1. Instance Password

```hcl
output "instance_password" {
  description = "Generated password for SSH authentication (sensitive)"
  value       = random_password.instance_password.result
  sensitive   = true
}
```

**Retrieval**: Access via HCP Terraform workspace variables UI or CLI.

---

## Connection Instructions Output

```hcl
output "connection_instructions" {
  description = "Instructions for connecting to the instance"
  value       = <<-EOT
    SSH Access:
      Command: ssh devuser@${module.ec2_instance.public_ip}
      Credentials: Retrieve from HCP Terraform workspace sensitive outputs (instance_password)
    
    CloudWatch Logs:
      Log Group: ${module.cloudwatch_logs.log_group_name}
      Console: https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-1#logsV2:log-groups/log-group/${urlencode(module.cloudwatch_logs.log_group_name)}
    
    Security Warning: This instance uses password authentication for development only.
  EOT
}
```

---

## Output Usage Examples

### Accessing Outputs

```bash
# Get instance public IP
terraform output instance_public_ip

# Get password (sensitive)
terraform output -json instance_password | jq -r '.[]'

# Get full connection instructions
terraform output connection_instructions
```

### Using Outputs in Scripts

```bash
#!/bin/bash
INSTANCE_IP=$(terraform output -raw instance_public_ip)
PASSWORD=$(terraform output -json instance_password | jq -r '.[]')

# Connect via SSH (for automation only)
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no devuser@$INSTANCE_IP
```

---

**Contract Enforcement**: All outputs follow Terraform naming conventions and include proper descriptions.
