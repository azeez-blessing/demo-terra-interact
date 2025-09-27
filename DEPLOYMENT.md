# Deployment Guide - Enterprise AWS Infrastructure

This guide provides step-by-step instructions for deploying the enterprise AWS infrastructure across different environments.

## Prerequisites Checklist

Before deploying, ensure you have completed all prerequisites:

- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] AWS account with appropriate permissions
- [ ] EC2 Key Pair created in your target region
- [ ] S3 bucket for Terraform state (optional but recommended)
- [ ] DynamoDB table for state locking (optional but recommended)

## Environment Setup

### 1. AWS Credentials Configuration

```bash
# Configure AWS CLI with your credentials
aws configure

# Verify your identity
aws sts get-caller-identity

# Verify you can access EC2
aws ec2 describe-regions
```

### 2. Create EC2 Key Pair

```bash
# Create a new key pair
aws ec2 create-key-pair \
    --key-name enterprise-app-key \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/enterprise-app-key.pem

# Set proper permissions
chmod 400 ~/.ssh/enterprise-app-key.pem
```

### 3. Setup Terraform Backend (Recommended)

```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket-$(date +%s)

# Create DynamoDB table for locking
aws dynamodb create-table \
    --table-name terraform-state-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

## Development Environment Deployment

### Step 1: Configure Development Environment

```bash
cd env/dev1

# Copy and edit the variables file
cp ../../terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
project_name = "my-enterprise-app"
aws_region   = "us-west-2"
environment  = "dev"
key_name     = "enterprise-app-key"
notification_email = "admin@yourcompany.com"
allowed_cidr_blocks = ["YOUR.IP.ADDRESS/32"]
```

### Step 2: Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Step 3: Verify Development Deployment

```bash
# Get instance information
terraform output

# Connect via Systems Manager
aws ssm start-session --target $(terraform output -raw instance_id)

# Or via SSH
ssh -i ~/.ssh/enterprise-app-key.pem ec2-user@$(terraform output -raw instance_private_ip)
```

## Staging Environment Deployment

### Step 1: Configure Staging Environment

```bash
cd ../dev2.qa1

# Copy configuration from dev
cp ../dev1/terraform.tfvars .
```

Edit `terraform.tfvars` for staging:
```hcl
project_name = "my-enterprise-app"
aws_region   = "us-west-2"
environment  = "staging"
key_name     = "enterprise-app-key"
notification_email = "admin@yourcompany.com"
allowed_cidr_blocks = ["10.0.0.0/16"]
```

### Step 2: Deploy Staging

```bash
# Initialize Terraform
terraform init

# Plan with staging configuration
terraform plan

# Apply staging environment
terraform apply
```

## Production Environment Deployment

### Step 1: Configure Production Environment

```bash
cd ../prod

# Create production-specific configuration
cp ../dev1/terraform.tfvars .
```

Edit `terraform.tfvars` for production:
```hcl
project_name = "my-enterprise-app"
aws_region   = "us-west-2"
environment  = "prod"
key_name     = "enterprise-app-key"
notification_email = "admin@yourcompany.com"
slack_webhook_url = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
allowed_cidr_blocks = ["10.0.0.0/8"]

# Auto Scaling configuration
min_size = 2
max_size = 10
desired_capacity = 3
```

### Step 2: Deploy Production

```bash
# Initialize Terraform
terraform init

# Plan production deployment
terraform plan

# Apply production environment
terraform apply
```

### Step 3: Verify Production Deployment

```bash
# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $(terraform output -raw auto_scaling_group_name)

# Check Load Balancer
aws elbv2 describe-load-balancers \
    --names $(terraform output -raw load_balancer_dns_name)

# Test application endpoint
curl http://$(terraform output -raw load_balancer_dns_name)
```

## Post-Deployment Configuration

### 1. Configure Monitoring

```bash
# View CloudWatch dashboard
echo "Dashboard URL: $(terraform output -raw cloudwatch_dashboard_url)"

# Test SNS notifications
aws sns publish \
    --topic-arn $(terraform output -raw sns_topic_arn) \
    --message "Test notification from $(terraform output -raw environment) environment"
```

### 2. Setup Backup Verification

```bash
# Check backup vault
aws backup list-backup-vaults

# Verify backup plan
aws backup list-backup-plans
```

### 3. Security Verification

```bash
# Verify CloudTrail is logging
aws cloudtrail describe-trails

# Check VPC Flow Logs
aws ec2 describe-flow-logs

# Verify KMS key
aws kms list-keys
```

## Environment Management

### Updating Environments

```bash
# Check for updates
terraform plan

# Apply updates
terraform apply

# Verify changes
terraform show
```

### Destroying Environments

```bash
# Destroy development environment
cd env/dev1
terraform destroy

# Destroy staging environment
cd ../dev2.qa1
terraform destroy

# Destroy production environment (use with extreme caution)
cd ../prod
terraform destroy
```

## Troubleshooting

### Common Deployment Issues

#### 1. Insufficient Permissions

```bash
# Check your permissions
aws iam get-user
aws iam list-attached-user-policies --user-name YOUR_USERNAME
```

#### 2. Resource Limits

```bash
# Check EC2 limits
aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-1216C47A

# Check VPC limits
aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-F678F1CE
```

#### 3. Networking Issues

```bash
# Verify VPC configuration
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*enterprise-app*"

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*enterprise-app*"
```

### Recovery Procedures

#### State Recovery

```bash
# If state is corrupted, restore from S3 versioning
aws s3api list-object-versions \
    --bucket your-terraform-state-bucket \
    --prefix env/dev/terraform.tfstate

# Restore specific version
aws s3api get-object \
    --bucket your-terraform-state-bucket \
    --key env/dev/terraform.tfstate \
    --version-id VERSION_ID \
    terraform.tfstate
```

#### Resource Recovery

```bash
# Import existing resources to state
terraform import aws_instance.web_server i-1234567890abcdef0

# Remove resources from state without destroying
terraform state rm aws_instance.web_server
```

## Best Practices for Production

### 1. Deployment Strategy

- Deploy to development first
- Test thoroughly in staging
- Use blue-green deployment for production
- Implement proper rollback procedures

### 2. Monitoring

- Set up comprehensive alerting
- Monitor application metrics
- Track infrastructure costs
- Review security logs regularly

### 3. Backup and Disaster Recovery

- Test backup restoration procedures
- Document recovery processes
- Maintain off-site backups
- Regular disaster recovery drills

### 4. Security

- Regular security assessments
- Keep instances patched
- Rotate access keys regularly
- Monitor for unusual activities

## Next Steps

After successful deployment:

1. **Application Deployment**: Deploy your application code to the instances
2. **SSL Configuration**: Set up SSL certificates for HTTPS
3. **Domain Configuration**: Configure Route 53 for custom domains
4. **Performance Tuning**: Optimize based on your workload
5. **Cost Optimization**: Review and optimize costs regularly

## Support

For deployment issues:
- Check the troubleshooting section
- Review AWS CloudTrail logs
- Contact your DevOps team
- Refer to AWS documentation

Remember to follow your organization's change management processes for production deployments.