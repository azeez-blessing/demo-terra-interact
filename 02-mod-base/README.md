# Enterprise Base Module Usage Guide

## Overview

The `mod-base` module has been converted into a reusable Terraform module that can be consumed by all environment configurations. This follows DRY (Don't Repeat Yourself) principles and ensures consistent infrastructure across environments.

## Two Usage Patterns

### Pattern 1: Direct Module Usage (Original)
Deploy directly from the `mod-base` directory with terraform.tfvars files.

### Pattern 2: Module Consumption (New - Recommended)
Use the base module from environment-specific configurations in the `env/` directories.

## Module Structure

```
mod-base/
├── man.tf         # Main module configuration
├── variables.tf   # Input variables for the module
└── outputs.tf     # Output values from the module
```

## Environment Configurations (New Pattern)

Each environment now uses the base module with environment-specific parameters:

```
env/
├── dev1/
│   ├── main-new.tf    # Uses mod-base module
│   └── variable.tf    # Environment-specific variables
├── dev2.qa1/
│   ├── main-new.tf    # Uses mod-base module
│   └── variables.tf   # Environment-specific variables
└── prod/
    ├── main-new.tf    # Uses mod-base module
    └── variables.tf   # Environment-specific variables
```

## How to Use (New Modular Approach)

### 1. Development Environment (dev1)
```bash
cd env/dev1
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply
```

**Configuration:**
- Single EC2 instance (no auto-scaling)
- Basic monitoring
- Development-sized resources

### 2. QA Environment (dev2.qa1)
```bash
cd env/dev2.qa1
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply
```

**Configuration:**
- Auto Scaling enabled (1-3 instances)
- Enhanced monitoring
- QA-appropriate resources

### 3. Production Environment (prod)
```bash
cd env/prod
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply
```

**Configuration:**
- Auto Scaling enabled (2-10 instances)
- Full monitoring and alerting
- Production-grade resources

## Quick Start Examples

### 1. Development Environment

```bash
cd mod-base

# Create terraform.tfvars
cat > terraform.tfvars << EOF
environment = "dev"
project_name = "my-app"
aws_region = "us-west-2"
key_name = "my-ec2-key"
notification_email = "admin@company.com"
instance_count = 1
enable_auto_scaling = false
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

### 2. Staging Environment

```bash
cd mod-base

# Create terraform.tfvars for staging
cat > terraform.tfvars << EOF
environment = "staging"
project_name = "my-app"
aws_region = "us-west-2"
key_name = "my-ec2-key"
notification_email = "admin@company.com"
instance_count = 2
enable_auto_scaling = false
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

### 3. Production Environment with Auto Scaling

```bash
cd mod-base

# Create terraform.tfvars for production
cat > terraform.tfvars << EOF
environment = "prod"
project_name = "my-app"
aws_region = "us-west-2"
key_name = "my-ec2-key"
notification_email = "admin@company.com"
enable_auto_scaling = true
min_size = 2
max_size = 10
desired_capacity = 3
allowed_cidr_blocks = ["10.0.0.0/8"]
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

## Environment-Specific Configurations

### Development (dev)
- **Instance Type**: t3.small
- **Storage**: 20GB GP3
- **Network**: 2 AZs, single NAT Gateway
- **Monitoring**: Basic (7-day retention)
- **Backup**: Disabled
- **Auto Scaling**: Disabled by default

### Staging (staging)
- **Instance Type**: t3.medium
- **Storage**: 30GB GP3
- **Network**: 2 AZs, single NAT Gateway
- **Monitoring**: Enhanced (30-day retention)
- **Backup**: 14-day retention
- **Auto Scaling**: Optional

### Production (prod)
- **Instance Type**: m5.large
- **Storage**: 50GB GP3
- **Network**: 3 AZs, multiple NAT Gateways
- **Monitoring**: Comprehensive (90-day retention)
- **Backup**: 30-day retention
- **Auto Scaling**: Recommended

## Available Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `environment` | Environment (dev/staging/prod) | string | - | Yes |
| `project_name` | Project name | string | "enterprise-app" | No |
| `aws_region` | AWS region | string | "us-west-2" | No |
| `key_name` | EC2 key pair name | string | null | No |
| `notification_email` | Email for alerts | string | "" | No |
| `allowed_cidr_blocks` | Allowed IP ranges | list(string) | ["10.0.0.0/16"] | No |
| `instance_count` | Number of instances | number | 1 | No |
| `enable_auto_scaling` | Enable Auto Scaling | bool | false | No |
| `min_size` | ASG minimum size | number | 1 | No |
| `max_size` | ASG maximum size | number | 5 | No |
| `desired_capacity` | ASG desired capacity | number | 2 | No |

## Complete terraform.tfvars Example

```hcl
# Basic Configuration
environment = "prod"
project_name = "enterprise-app"
aws_region = "us-west-2"

# Security Configuration
key_name = "my-ec2-key-pair"
allowed_cidr_blocks = [
  "10.0.0.0/8",     # Private networks
  "203.0.113.0/24"  # Your office IP range
]

# Instance Configuration
instance_count = 3                # Only used when auto_scaling is false
enable_auto_scaling = true        # Enable for production

# Auto Scaling Configuration (when enabled)
min_size = 2
max_size = 10
desired_capacity = 3

# Monitoring Configuration
notification_email = "admin@yourcompany.com"
```

## Deployment Commands

### Initialize and Deploy
```bash
# Navigate to the base module
cd mod-base

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply configuration
terraform apply tfplan
```

### Verify Deployment
```bash
# Check outputs
terraform output

# Connect to instance via SSM
aws ssm start-session --target $(terraform output -json instance_ids | jq -r '.[0]')

# View monitoring dashboard
echo $(terraform output -raw cloudwatch_dashboard_url)
```

### Clean Up
```bash
# Destroy infrastructure
terraform destroy
```

## Advanced Usage

### Using Workspaces for Environment Isolation

```bash
# Create workspaces for each environment
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch to environment
terraform workspace select dev

# Deploy to current workspace
terraform apply
```

### Custom Backend Configuration

Create a `backend.tf` file:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "base-module/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}
```

### Environment-Specific tfvars Files

```bash
# Create environment-specific files
terraform.tfvars.dev
terraform.tfvars.staging
terraform.tfvars.prod

# Deploy with specific file
terraform apply -var-file="terraform.tfvars.prod"
```

## Outputs Reference

After deployment, you can access these outputs:

```bash
# Get VPC ID
terraform output vpc_id

# Get instance IDs
terraform output instance_ids

# Get SSH commands
terraform output ssh_connection_commands

# Get SSM commands
terraform output ssm_connection_commands

# Get dashboard URL
terraform output cloudwatch_dashboard_url
```

## Security Features Included

- **Network Security**: VPC with private subnets, security groups, NACLs
- **Data Encryption**: KMS-encrypted EBS volumes and S3 buckets
- **Access Control**: IAM roles with least privilege
- **Monitoring**: CloudWatch logs, metrics, and alarms
- **Audit Trail**: CloudTrail logging and VPC Flow Logs
- **Secure Access**: Systems Manager Session Manager

## Troubleshooting

### Common Issues

1. **Permission Errors**
   ```bash
   aws sts get-caller-identity
   aws iam get-user
   ```

2. **Resource Limits**
   ```bash
   aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
   ```

3. **Module Path Issues**
   ```bash
   terraform get -update
   ```

### Debug Mode
```bash
export TF_LOG=DEBUG
terraform plan
```

This base module provides a complete enterprise infrastructure solution that automatically configures itself based on the environment, making it easy to maintain consistency across dev, staging, and production while optimizing for cost and requirements specific to each environment.