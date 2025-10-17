#!/bin/bash
# Azure Free Tier Datacenter - VM Deployment Script
# Version: 1.0
# Purpose: Deploy all 4 virtual machines with managed identities

set -e  # Exit on error

echo "=========================================="
echo "Azure Free Tier Datacenter Deployment"
echo "Part 3: Virtual Machines"
echo "=========================================="
echo ""

# Load configuration
if [ ! -f .azure-config ]; then
    echo "Error: .azure-config not found. Run previous scripts first."
    exit 1
fi

source .azure-config

# Check for SSH key
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Error: SSH public key not found at $SSH_KEY_PATH"
    echo "Please generate an SSH key pair first:"
    echo "  ssh-keygen -t rsa -b 4096"
    exit 1
fi

# Prompt for Windows admin password
echo "Enter a strong password for the Windows Server admin account:"
echo "(Must be 12-72 characters, contain uppercase, lowercase, number, and special character)"
read -sp "Password: " WIN_PASSWORD
echo ""
read -sp "Confirm Password: " WIN_PASSWORD_CONFIRM
echo ""

if [ "$WIN_PASSWORD" != "$WIN_PASSWORD_CONFIRM" ]; then
    echo "Error: Passwords do not match"
    exit 1
fi

if [ -z "$WIN_PASSWORD" ]; then
    echo "Error: Password cannot be empty"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  VNet: $VNET_NAME"
echo "  SSH Key: $SSH_KEY_PATH"
echo ""

# Step 1: Deploy Bastion Host
echo "Step 1: Deploying Bastion Host (vm-bastion-dev-westus2-001)..."
echo "This may take several minutes..."

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-bastion-dev-westus2-001 \
  --location "$REGION" \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --vnet-name "$VNET_NAME" \
  --subnet snet-management \
  --admin-username azureuser \
  --ssh-key-values "@$SSH_KEY_PATH" \
  --public-ip-address vm-bastion-pip \
  --public-ip-sku Standard \
  --assign-identity \
  --output table

BASTION_PUBLIC_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-bastion-dev-westus2-001 \
  --show-details \
  --query publicIps \
  --output tsv)

BASTION_PRIVATE_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-bastion-dev-westus2-001 \
  --show-details \
  --query privateIps \
  --output tsv)

echo "✓ Bastion Host deployed"
echo "  Public IP: $BASTION_PUBLIC_IP"
echo "  Private IP: $BASTION_PRIVATE_IP"
echo ""

# Step 2: Deploy Windows Web Server
echo "Step 2: Deploying Windows Web Server (vm-winweb-dev-westus2-001)..."
echo "This may take several minutes..."

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-winweb-dev-westus2-001 \
  --location "$REGION" \
  --image Win2022Datacenter \
  --size Standard_B1s \
  --vnet-name "$VNET_NAME" \
  --subnet snet-web \
  --admin-username azureuser \
  --admin-password "$WIN_PASSWORD" \
  --public-ip-address "" \
  --assign-identity \
  --output table

WINWEB_PRIVATE_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-winweb-dev-westus2-001 \
  --show-details \
  --query privateIps \
  --output tsv)

echo "✓ Windows Web Server deployed"
echo "  Private IP: $WINWEB_PRIVATE_IP"
echo ""

# Step 3: Deploy Linux Proxy Server
echo "Step 3: Deploying Linux Proxy Server (vm-linuxproxy-dev-westus2-001)..."
echo "This may take several minutes..."

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-linuxproxy-dev-westus2-001 \
  --location "$REGION" \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --vnet-name "$VNET_NAME" \
  --subnet snet-web \
  --admin-username azureuser \
  --ssh-key-values "@$SSH_KEY_PATH" \
  --public-ip-address "" \
  --assign-identity \
  --output table

LINUXPROXY_PRIVATE_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-linuxproxy-dev-westus2-001 \
  --show-details \
  --query privateIps \
  --output tsv)

echo "✓ Linux Proxy Server deployed"
echo "  Private IP: $LINUXPROXY_PRIVATE_IP"
echo ""

# Step 4: Deploy Linux Application Server
echo "Step 4: Deploying Linux Application Server (vm-linuxapp-dev-westus2-001)..."
echo "This may take several minutes..."

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-linuxapp-dev-westus2-001 \
  --location "$REGION" \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --vnet-name "$VNET_NAME" \
  --subnet snet-app \
  --admin-username azureuser \
  --ssh-key-values "@$SSH_KEY_PATH" \
  --public-ip-address "" \
  --assign-identity \
  --output table

LINUXAPP_PRIVATE_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-linuxapp-dev-westus2-001 \
  --show-details \
  --query privateIps \
  --output tsv)

echo "✓ Linux Application Server deployed"
echo "  Private IP: $LINUXAPP_PRIVATE_IP"
echo ""

# Step 5: Grant Key Vault Access to VM Managed Identities
echo "Step 5: Granting Key Vault access to VM Managed Identities..."

# Get managed identity principal IDs
BASTION_IDENTITY=$(az vm identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-bastion-dev-westus2-001 \
  --query principalId \
  --output tsv)

WINWEB_IDENTITY=$(az vm identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-winweb-dev-westus2-001 \
  --query principalId \
  --output tsv)

LINUXPROXY_IDENTITY=$(az vm identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-linuxproxy-dev-westus2-001 \
  --query principalId \
  --output tsv)

LINUXAPP_IDENTITY=$(az vm identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name vm-linuxapp-dev-westus2-001 \
  --query principalId \
  --output tsv)

# Grant Key Vault access policies
az keyvault set-policy \
  --name "$KEY_VAULT_NAME" \
  --object-id "$BASTION_IDENTITY" \
  --secret-permissions get list \
  --output table

az keyvault set-policy \
  --name "$KEY_VAULT_NAME" \
  --object-id "$WINWEB_IDENTITY" \
  --secret-permissions get list \
  --output table

az keyvault set-policy \
  --name "$KEY_VAULT_NAME" \
  --object-id "$LINUXPROXY_IDENTITY" \
  --secret-permissions get list \
  --output table

az keyvault set-policy \
  --name "$KEY_VAULT_NAME" \
  --object-id "$LINUXAPP_IDENTITY" \
  --secret-permissions get list \
  --output table

echo "✓ Key Vault access policies configured"
echo ""

# Store Windows password in Key Vault
echo "Step 6: Storing Windows credentials in Key Vault..."
az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "windows-admin-password" \
  --value "$WIN_PASSWORD" \
  --output table

echo "✓ Windows credentials stored securely"
echo ""

# Save VM information
cat >> .azure-config <<EOF
BASTION_PUBLIC_IP=$BASTION_PUBLIC_IP
BASTION_PRIVATE_IP=$BASTION_PRIVATE_IP
WINWEB_PRIVATE_IP=$WINWEB_PRIVATE_IP
LINUXPROXY_PRIVATE_IP=$LINUXPROXY_PRIVATE_IP
LINUXAPP_PRIVATE_IP=$LINUXAPP_PRIVATE_IP
EOF

# Create connection info file
cat > vm-connection-info.txt <<EOF
========================================
Azure Free Tier Datacenter - VM Connection Information
========================================

Bastion Host (vm-bastion-dev-westus2-001)
  Public IP: $BASTION_PUBLIC_IP
  Private IP: $BASTION_PRIVATE_IP
  SSH: ssh azureuser@$BASTION_PUBLIC_IP
  
Windows Web Server (vm-winweb-dev-westus2-001)
  Private IP: $WINWEB_PRIVATE_IP
  Username: azureuser
  Password: (stored in Key Vault: windows-admin-password)
  Access: Via Guacamole on bastion host
  
Linux Proxy Server (vm-linuxproxy-dev-westus2-001)
  Private IP: $LINUXPROXY_PRIVATE_IP
  SSH: ssh azureuser@$LINUXPROXY_PRIVATE_IP (from bastion)
  
Linux Application Server (vm-linuxapp-dev-westus2-001)
  Private IP: $LINUXAPP_PRIVATE_IP
  SSH: ssh azureuser@$LINUXAPP_PRIVATE_IP (from bastion)

========================================
Key Vault: $KEY_VAULT_NAME
Storage Account: $STORAGE_ACCOUNT_NAME
========================================
EOF

echo "=========================================="
echo "Virtual Machines Deployment Complete!"
echo "=========================================="
echo ""
echo "VM Information:"
cat vm-connection-info.txt
echo ""
echo "Connection info saved to: vm-connection-info.txt"
echo ""
echo "Next Steps:"
echo "1. SSH to bastion: ssh azureuser@$BASTION_PUBLIC_IP"
echo "2. Run scripts/04-deploy-services.sh to deploy SQL Database and monitoring"
echo "3. Setup Guacamole using docker/guacamole-compose.yml"
echo ""

