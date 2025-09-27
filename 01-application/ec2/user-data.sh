#!/bin/bash

# Enable logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

# Update system
yum update -y

# Install required packages
yum install -y \
    amazon-cloudwatch-agent \
    amazon-ssm-agent \
    awscli \
    wget \
    curl \
    unzip \
    htop \
    tree \
    nano \
    git

# Start and enable SSM agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Configure CloudWatch agent (if enabled)
%{ if cloudwatch_config != "" ~}
# Create CloudWatch agent configuration
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
${cloudwatch_config}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Enable CloudWatch agent to start on boot
systemctl enable amazon-cloudwatch-agent
%{ endif ~}

# Set hostname
hostnamectl set-hostname "${project_name}-${environment}-${instance_name}"

# Create application user
useradd -m -s /bin/bash appuser
usermod -aG wheel appuser

# Create application directories
mkdir -p /opt/app/{bin,config,logs,data}
chown -R appuser:appuser /opt/app

# Set up log rotation for application logs
cat > /etc/logrotate.d/app << 'EOF'
/opt/app/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    su appuser appuser
}
EOF

# Configure security settings
# Disable root login
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Configure firewall (basic setup)
systemctl start firewalld
systemctl enable firewalld

# Allow SSH
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Set up automatic security updates
yum install -y yum-cron
systemctl enable yum-cron
systemctl start yum-cron

# Configure yum-cron for security updates only
sed -i 's/update_cmd = default/update_cmd = security/' /etc/yum/yum-cron.conf
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf

# Install and configure fail2ban
yum install -y epel-release
yum install -y fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
maxretry = 3
EOF

systemctl enable fail2ban
systemctl start fail2ban

# Configure system limits
cat >> /etc/security/limits.conf << 'EOF'
# Application user limits
appuser soft nofile 65536
appuser hard nofile 65536
appuser soft nproc 4096
appuser hard nproc 4096
EOF

# Set timezone
timedatectl set-timezone UTC

# Configure NTP
yum install -y chrony
systemctl enable chronyd
systemctl start chronyd

# Create startup script for applications
cat > /opt/app/bin/startup.sh << 'EOF'
#!/bin/bash
# Application startup script
echo "Starting application services..."
# Add your application startup commands here

# Log startup
echo "$(date): Application startup completed" >> /opt/app/logs/startup.log
EOF

chmod +x /opt/app/bin/startup.sh
chown appuser:appuser /opt/app/bin/startup.sh

# Create systemd service for application startup
cat > /etc/systemd/system/app-startup.service << 'EOF'
[Unit]
Description=Application Startup Service
After=network.target

[Service]
Type=oneshot
User=appuser
ExecStart=/opt/app/bin/startup.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable app-startup.service

# Signal that user data script is complete
/opt/aws/bin/cfn-signal -e $? --stack ${project_name}-${environment} --resource EC2Instance --region ${region} || true

# Log completion
echo "$(date): User data script completed successfully" >> /var/log/user-data.log