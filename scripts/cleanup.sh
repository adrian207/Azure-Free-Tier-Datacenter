#!/bin/bash
# Cleanup and Decommission Script
# WARNING: This will delete ALL resources in the resource group

set -e

echo "=========================================="
echo "Azure Free Tier Datacenter - CLEANUP"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This script will DELETE all resources!"
echo ""

# Load configuration
if [ -f .azure-config ]; then
    source .azure-config
else
    echo "Error: .azure-config not found"
    exit 1
fi

echo "Resource Group to delete: $RESOURCE_GROUP"
echo ""

# Confirm deletion
read -p "Type 'DELETE' to confirm deletion: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
read -p "Are you absolutely sure? This cannot be undone! (yes/NO): " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup process..."
echo ""

# Optional: Create final backup
read -p "Create a final backup before deletion? (Y/n): " CREATE_BACKUP
if [[ ! $CREATE_BACKUP =~ ^[Nn]$ ]]; then
    echo "Creating final backup..."
    if [ -f ./backup-config.sh ]; then
        bash ./backup-config.sh
    fi
fi

# Stop Docker containers on bastion (if running locally)
echo "Stopping Docker containers..."
if command -v docker &> /dev/null; then
    cd /opt/guacamole 2>/dev/null && docker-compose down || true
fi
echo "✓ Docker containers stopped"
echo ""

# Delete the entire resource group
echo "Deleting resource group: $RESOURCE_GROUP"
echo "This may take 5-10 minutes..."
az group delete \
    --name "$RESOURCE_GROUP" \
    --yes \
    --no-wait

echo "✓ Deletion initiated"
echo ""

# Monitor deletion status
echo "Monitoring deletion status..."
echo "You can safely cancel this with Ctrl+C - deletion will continue in background"
echo ""

while az group exists --name "$RESOURCE_GROUP" 2>/dev/null | grep -q "true"; do
    echo "  $(date '+%H:%M:%S') - Still deleting..."
    sleep 30
done

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "All resources have been deleted."
echo "Billing has stopped for all Azure services."
echo ""
echo "To verify deletion:"
echo "  az group exists --name $RESOURCE_GROUP"
echo "  (should return: false)"
echo ""
echo "Configuration files have been preserved locally."
echo "To deploy again, run the deployment scripts."
echo ""

