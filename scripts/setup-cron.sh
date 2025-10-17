#!/bin/bash
# Setup Cron Jobs for Automated Maintenance
# Run this script on the bastion host after Ansible is configured

set -e

echo "=========================================="
echo "Setting Up Automated Maintenance Jobs"
echo "=========================================="
echo ""

# Check if running on bastion
if [ "$(hostname)" != "vm-bastion-dev-westus2-001" ]; then
    echo "Warning: This script should be run on the bastion host"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create Ansible log directory
echo "Creating log directories..."
sudo mkdir -p /var/log/ansible
sudo chown azureuser:azureuser /var/log/ansible
echo "✓ Log directories created"
echo ""

# Load environment variables
if [ -f ~/.azure-env ]; then
    source ~/.azure-env
else
    echo "Warning: ~/.azure-env not found. Cron jobs may fail without environment variables."
fi

# Create cron job for monthly system updates
echo "Setting up monthly system update cron job..."
CRON_UPDATE="0 22 * * 2 [ \$(date +\%d) -ge 8 ] && [ \$(date +\%d) -le 14 ] && cd /home/azureuser/ansible && /usr/bin/ansible-playbook playbooks/master-update.yml >> /var/log/ansible/cron-update.log 2>&1"

# Add to crontab if not already present
(crontab -l 2>/dev/null | grep -v "master-update.yml"; echo "$CRON_UPDATE") | crontab -
echo "✓ Monthly update cron job added (2nd Tuesday of month at 10 PM)"
echo ""

# Create cron job for daily health checks
echo "Setting up daily health check cron job..."
cat > /home/azureuser/daily-health-check.sh << 'EOF'
#!/bin/bash
# Daily Health Check Script

LOG_FILE="/var/log/ansible/health-check-$(date +%Y%m%d).log"

echo "========================================" >> $LOG_FILE
echo "Health Check: $(date)" >> $LOG_FILE
echo "========================================" >> $LOG_FILE

# Check disk space
echo "Disk Space:" >> $LOG_FILE
df -h / >> $LOG_FILE 2>&1

# Check memory
echo "" >> $LOG_FILE
echo "Memory Usage:" >> $LOG_FILE
free -h >> $LOG_FILE 2>&1

# Check if Azure Files is mounted
echo "" >> $LOG_FILE
echo "Azure Files Mount Status:" >> $LOG_FILE
if mountpoint -q /mnt/shared 2>/dev/null; then
    echo "✓ Azure Files is mounted" >> $LOG_FILE
else
    echo "✗ Azure Files is NOT mounted" >> $LOG_FILE
fi

# Check Docker containers (Guacamole)
echo "" >> $LOG_FILE
echo "Docker Container Status:" >> $LOG_FILE
docker ps --format "table {{.Names}}\t{{.Status}}" >> $LOG_FILE 2>&1

# Check critical services
echo "" >> $LOG_FILE
echo "Service Status:" >> $LOG_FILE
systemctl is-active --quiet sshd && echo "✓ SSH is running" >> $LOG_FILE || echo "✗ SSH is down" >> $LOG_FILE
systemctl is-active --quiet docker && echo "✓ Docker is running" >> $LOG_FILE || echo "✗ Docker is down" >> $LOG_FILE

echo "" >> $LOG_FILE
EOF

chmod +x /home/azureuser/daily-health-check.sh

CRON_HEALTH="0 8 * * * /home/azureuser/daily-health-check.sh"
(crontab -l 2>/dev/null | grep -v "daily-health-check.sh"; echo "$CRON_HEALTH") | crontab -
echo "✓ Daily health check cron job added (8 AM daily)"
echo ""

# Create cron job for log rotation
echo "Setting up log rotation..."
sudo tee /etc/logrotate.d/ansible > /dev/null << EOF
/var/log/ansible/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 azureuser azureuser
}
EOF
echo "✓ Log rotation configured"
echo ""

# Display current crontab
echo "Current cron jobs:"
crontab -l
echo ""

echo "=========================================="
echo "Automated Maintenance Setup Complete!"
echo "=========================================="
echo ""
echo "Cron Jobs Configured:"
echo "1. System Updates: 2nd Tuesday of each month at 10:00 PM"
echo "2. Health Checks: Daily at 8:00 AM"
echo ""
echo "Log Locations:"
echo "  Update logs: /var/log/ansible/cron-update.log"
echo "  Health checks: /var/log/ansible/health-check-YYYYMMDD.log"
echo "  Ansible logs: /var/log/ansible/ansible.log"
echo ""
echo "To manually run maintenance:"
echo "  cd ~/ansible && ansible-playbook playbooks/master-update.yml"
echo ""

