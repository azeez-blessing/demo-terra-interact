# Enterprise AWS Infrastructure with Terraform

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-blue)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Provider-orange)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A comprehensive, enterprise-ready Terraform project for deploying secure AWS infrastructure with best practices for compliance, monitoring, and high availability.

## 🏗️ Architecture Overview

This project creates a complete enterprise AWS infrastructure including:

- **Multi-tier VPC** with public, private, and database subnets across multiple AZs
- **Secure EC2 instances** with IAM roles, encryption, and monitoring
- **Security groups and NACLs** for defense in depth
- **KMS encryption** for data at rest
- **CloudTrail auditing** and VPC Flow Logs
- **CloudWatch monitoring** with alerting and dashboards
- **Auto Scaling** and Load Balancing (production)
- **Automated backups** and disaster recovery

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Environment Configuration](#environment-configuration)
- [Security Features](#security-features)
- [Monitoring and Logging](#monitoring-and-logging)
- [Deployment Guide](#deployment-guide)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🔧 Prerequisites

Before deploying this infrastructure, ensure you have:

### Required Tools
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- An AWS account with administrative privileges

### AWS Prerequisites
- EC2 Key Pair for instance access
- S3 bucket for Terraform state (recommended)
- DynamoDB table for state locking (recommended)

### Required AWS Permissions
The deployment requires the following AWS services permissions:
- EC2 (instances, VPC, security groups)
- IAM (roles, policies, instance profiles)
- CloudWatch (logs, metrics, alarms)
- KMS (key management)
- S3 (buckets, objects)
- CloudTrail (logging)
- Systems Manager (session manager)

## 🚀 Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd env-proj

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your configuration
nano terraform.tfvars
```

### 2. Configure Backend (Recommended)

```bash
# Edit backend.tf and uncomment the S3 backend configuration
# Replace placeholders with your S3 bucket and DynamoDB table
```

### 3. Deploy Development Environment

```bash
cd env/dev1

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 4. Access Your Infrastructure

```bash
# Connect via AWS Systems Manager (no SSH key required)
aws ssm start-session --target <instance-id>

# Or via SSH (if key pair configured)
ssh -i ~/.ssh/your-key.pem ec2-user@<private-ip>
```

## 📁 Project Structure

```
env-proj/
├───01-application
│   ├───ec2
│   ├───iam
│   ├───monitoring
│   ├───network
│   └───security
├───02-mod-base
│   ├───dev1
│   │   └───.terraform
│   │       ├───modules
│   │       └───providers
│   │           └───registry.terraform.io
│   │               └───hashicorp
│   │                   ├───archive
│   │                   │   └───2.7.1
│   │                   │       └───windows_386
│   │                   ├───aws
│   │                   │   └───5.100.0
│   │                   │       └───windows_386
│   │                   └───random
│   │                       └───3.7.2
│   │                           └───windows_386
│   ├───dev2.qa1
│   └───prod
└───datalow
    └───.terraform
        └───providers
            └───registry.terraform.io
                └───hashicorp
                    ├───archive
                    │   └───2.7.1
                    │       └───windows_386
                    └───aws
                        └───5.100.0
                            └───windows_386
```

## 🌍 Environment Configuration

### Development (dev1)
- **Purpose**: Development and testing
- **Instance Type**: t3.small
- **Features**: Single NAT Gateway, basic monitoring, 7-day log retention
- **Cost**: Optimized for low cost

### Staging (dev2.qa1)
- **Purpose**: Pre-production testing
- **Instance Type**: t3.medium
- **Features**: Multi-AZ deployment, enhanced monitoring, 30-day retention
- **Cost**: Balanced cost and availability

### Production (prod)
- **Purpose**: Production workloads
- **Instance Type**: m5.large with Auto Scaling
- **Features**: High availability, comprehensive monitoring, 90-day retention
- **Cost**: Optimized for availability and performance

## 🔒 Security Features

### Network Security
- **VPC Isolation**: Dedicated VPC with private subnets
- **Security Groups**: Application-specific traffic rules
- **NACLs**: Additional network-level protection
- **NAT Gateways**: Secure outbound internet access

### Data Protection
- **EBS Encryption**: All volumes encrypted at rest
- **KMS Integration**: Customer-managed encryption keys
- **S3 Encryption**: Encrypted storage for logs and backups

### Access Control
- **IAM Roles**: Least privilege access principles
- **Instance Profiles**: Secure AWS API access
- **Systems Manager**: Session Manager for secure access
- **CloudTrail**: Complete API audit logging

### Compliance
- **SOC 2 Ready**: Configurations support SOC 2 compliance
- **GDPR Considerations**: Data encryption and audit trails
- **HIPAA Compatible**: Enhanced security configurations available

## 📊 Monitoring and Logging

### CloudWatch Integration
- **Custom Dashboards**: Pre-configured monitoring dashboards
- **Automated Alarms**: CPU, memory, disk, and network monitoring
- **Log Aggregation**: Centralized application and system logs
- **Custom Metrics**: Application-specific monitoring

### Alerting
- **Email Notifications**: SNS-based alert delivery
- **Slack Integration**: Optional Slack webhook notifications
- **Escalation Policies**: Multi-tier alerting strategies

### Audit and Compliance
- **CloudTrail**: All API calls logged
- **VPC Flow Logs**: Network traffic monitoring
- **Access Logging**: Application load balancer logs
- **Retention Policies**: Configurable log retention

## 🚀 Deployment Guide

### Step 1: Prepare Your Environment

```bash
# Set up AWS credentials
aws configure

# Verify access
aws sts get-caller-identity
```

### Step 2: Configure Variables

Edit `terraform.tfvars`:

```hcl
# Basic Configuration
project_name = "your-app-name"
aws_region   = "us-west-2"
environment  = "dev"

# Security
key_name = "your-ec2-key-pair"
allowed_cidr_blocks = ["YOUR.IP.ADDR/32"]

# Monitoring
notification_email = "admin@yourcompany.com"
```

### Step 3: Initialize and Deploy

```bash
# Navigate to your environment
cd env/dev1

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply configuration
terraform apply tfplan
```

### Step 4: Verify Deployment

```bash
# Check infrastructure
terraform output

# Connect to instance
aws ssm start-session --target $(terraform output -raw instance_id)

# View monitoring dashboard
echo $(terraform output -raw cloudwatch_dashboard_url)
```

## 🔧 Best Practices

### State Management
- Use S3 backend with versioning enabled
- Implement state locking with DynamoDB
- Separate state files per environment

### Security
- Never commit `terraform.tfvars` to version control
- Use AWS Secrets Manager for sensitive data
- Regularly rotate access keys and certificates
- Enable MFA for AWS accounts

### Code Organization
- Keep modules small and focused
- Use consistent naming conventions
- Implement proper tagging strategies
- Document all custom configurations

### Deployment
- Always run `terraform plan` before `apply`
- Use workspaces for environment isolation
- Implement CI/CD pipelines for production
- Test in lower environments first

## 🛠️ Troubleshooting

### Common Issues

#### 1. Permission Denied Errors
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify IAM permissions
aws iam get-user
```

#### 2. State Lock Issues
```bash
# Force unlock if necessary (use with caution)
terraform force-unlock <lock-id>
```

#### 3. Resource Conflicts
```bash
# Import existing resources
terraform import aws_instance.example i-1234567890abcdef0

# Or remove from state
terraform state rm aws_instance.example
```

#### 4. Module Path Issues
```bash
# Verify module sources
terraform get -update
```

### Debugging

Enable Terraform debug logging:
```bash
export TF_LOG=DEBUG
terraform plan
```

Check AWS CloudTrail for API errors:
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/cloudtrail/
```

## 📈 Scaling and Customization

### Adding New Environments
1. Copy an existing environment folder
2. Modify the configuration variables
3. Update the backend key path
4. Deploy with `terraform apply`

### Custom Modules
1. Create new module in `application/` directory
2. Follow the existing module structure
3. Add proper variable validation
4. Include comprehensive outputs

### Extending Functionality
- Add application-specific security groups
- Implement custom CloudWatch metrics
- Integrate with external monitoring tools
- Add compliance-specific configurations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

### Coding Standards
- Use consistent formatting (`terraform fmt`)
- Validate syntax (`terraform validate`)
- Follow naming conventions
- Add comments for complex logic

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the DevOps team
- Check AWS documentation for service-specific issues

## 🔄 Changelog

### Version 1.0.0
- Initial enterprise infrastructure setup
- Multi-environment support
- Security and compliance features
- Comprehensive monitoring
- Auto Scaling capabilities

---

**⚠️ Important Security Notice**: This infrastructure includes enterprise security features but should be reviewed by your security team before production deployment. Ensure all configurations meet your organization's security requirements.