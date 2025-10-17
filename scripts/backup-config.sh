#!/bin/bash
# Backup Configuration Script
# Creates backups of critical configuration files and uploads to Azure Files

set -e

echo "=========================================="
echo "Azure Datacenter Configuration Backup"
echo "=========================================="
echo ""

# Configuration
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/azure-datacenter-backup-$BACKUP_DATE"
AZURE_FILES_MOUNT="/mnt/shared"
BACKUP_DESTINATION="$AZURE_FILES_MOUNT/backups"

# Create backup directory
echo "Creating backup directory..."
mkdir -p "$BACKUP_DIR"/{ansible,docker,scripts,system}
echo "✓ Backup directory created: $BACKUP_DIR"
echo ""

# Backup Ansible configuration
echo "Backing up Ansible configuration..."
if [ -d ~/ansible ]; then
    cp -r ~/ansible/* "$BACKUP_DIR/ansible/" 2>/dev/null || true
    echo "✓ Ansible files backed up"
else
    echo "⚠ Ansible directory not found"
fi

# Backup Docker configuration
echo "Backing up Docker configuration..."
if [ -d /opt/guacamole ]; then
    sudo cp -r /opt/guacamole/docker-compose.yml "$BACKUP_DIR/docker/" 2>/dev/null || true
    echo "✓ Docker files backed up"
else
    echo "⚠ Guacamole directory not found"
fi

# Backup system configuration
echo "Backing up system configuration..."
sudo cp /etc/fstab "$BACKUP_DIR/system/" 2>/dev/null || true
sudo cp /etc/ssh/sshd_config "$BACKUP_DIR/system/" 2>/dev/null || true
sudo cp -r /etc/cron.d "$BACKUP_DIR/system/" 2>/dev/null || true
crontab -l > "$BACKUP_DIR/system/crontab.txt" 2>/dev/null || true
echo "✓ System files backed up"
echo ""

# Backup deployment scripts
echo "Backing up deployment scripts..."
if [ -d ~/scripts ]; then
    cp -r ~/scripts/* "$BACKUP_DIR/scripts/" 2>/dev/null || true
    echo "✓ Scripts backed up"
fi

# Create archive
echo "Creating compressed archive..."
cd /tmp
tar -czf "azure-datacenter-backup-$BACKUP_DATE.tar.gz" "azure-datacenter-backup-$BACKUP_DATE"
BACKUP_ARCHIVE="/tmp/azure-datacenter-backup-$BACKUP_DATE.tar.gz"
BACKUP_SIZE=$(du -h "$BACKUP_ARCHIVE" | cut -f1)
echo "✓ Archive created: $BACKUP_SIZE"
echo ""

# Upload to Azure Files
echo "Uploading to Azure Files..."
if mountpoint -q "$AZURE_FILES_MOUNT"; then
    mkdir -p "$BACKUP_DESTINATION"
    cp "$BACKUP_ARCHIVE" "$BACKUP_DESTINATION/"
    echo "✓ Backup uploaded to Azure Files: $BACKUP_DESTINATION/"
    
    # Clean up old backups (keep last 10)
    cd "$BACKUP_DESTINATION"
    ls -t azure-datacenter-backup-*.tar.gz | tail -n +11 | xargs -r rm
    echo "✓ Old backups cleaned up (keeping last 10)"
else
    echo "✗ Azure Files not mounted. Backup saved locally only."
    echo "  Location: $BACKUP_ARCHIVE"
fi
echo ""

# Clean up local backup directory
rm -rf "$BACKUP_DIR"
echo "✓ Temporary files cleaned up"
echo ""

echo "=========================================="
echo "Backup Complete!"
echo "=========================================="
echo ""
echo "Backup Details:"
echo "  Filename: azure-datacenter-backup-$BACKUP_DATE.tar.gz"
echo "  Size: $BACKUP_SIZE"
echo "  Location: $BACKUP_DESTINATION/"
echo ""
echo "To restore from backup:"
echo "  tar -xzf azure-datacenter-backup-$BACKUP_DATE.tar.gz"
echo ""

