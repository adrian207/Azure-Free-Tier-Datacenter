#!/bin/bash
# Azure Free Tier Datacenter - Foundation Deployment Script
# Version: 1.0
# Purpose: Deploy foundational resources (Resource Group, VNet, Subnets, Key Vault, Storage)

set -e  # Exit on error

echo "=========================================="
echo "Azure Free Tier Datacenter Deployment"
echo "Part 1: Foundation Resources"
echo "=========================================="
echo ""

# Configuration Variables
RESOURCE_GROUP="rg-datacenter-dev-westus2-001"
REGION="westus2"
VNET_NAME="vnet-datacenter-dev-westus2-001"
KEY_VAULT_NAME="kv-secrets-dev-wus2-$(openssl rand -hex 4)"
STORAGE_ACCOUNT_NAME="stfilesdevwus2$(openssl rand -hex 4)"
FILE_SHARE_NAME="fs-shared-data"

echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Region: $REGION"
echo "  VNet Name: $VNET_NAME"
echo "  Key Vault: $KEY_VAULT_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo ""

# Save configuration to file for use by other scripts
cat > .azure-config <<EOF
RESOURCE_GROUP=$RESOURCE_GROUP
REGION=$REGION
VNET_NAME=$VNET_NAME
KEY_VAULT_NAME=$KEY_VAULT_NAME
STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME
FILE_SHARE_NAME=$FILE_SHARE_NAME
EOF

echo "✓ Configuration saved to .azure-config"
echo ""

# Step 1: Create Resource Group
echo "Step 1: Creating Resource Group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$REGION" \
  --output table

echo "✓ Resource Group created"
echo ""

# Step 2: Deploy Key Vault
echo "Step 2: Creating Key Vault..."
az keyvault create \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$REGION" \
  --enable-rbac-authorization false \
  --output table

echo "✓ Key Vault created: $KEY_VAULT_NAME"
echo ""

# Step 3: Deploy VNet and Subnets
echo "Step 3: Creating Virtual Network..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefixes 10.10.0.0/16 \
  --output table

echo "✓ VNet created"
echo ""

echo "Creating Subnets..."
# Management Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-management \
  --address-prefixes 10.10.1.0/24 \
  --output table

# Web Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-web \
  --address-prefixes 10.10.2.0/24 \
  --output table

# App Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-app \
  --address-prefixes 10.10.3.0/24 \
  --output table

# Database Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-database \
  --address-prefixes 10.10.4.0/24 \
  --output table

# Storage Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-storage \
  --address-prefixes 10.10.5.0/24 \
  --output table

echo "✓ All subnets created"
echo ""

# Step 4: Deploy Storage Account and File Share
echo "Step 4: Creating Storage Account..."
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$REGION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --output table

echo "✓ Storage Account created: $STORAGE_ACCOUNT_NAME"
echo ""

echo "Creating File Share..."
az storage share create \
  --name "$FILE_SHARE_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --quota 5 \
  --output table

# Store storage account key in Key Vault
STORAGE_KEY=$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --query '[0].value' \
  --output tsv)

az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "storage-account-key" \
  --value "$STORAGE_KEY" \
  --output table

echo "✓ File Share created and credentials stored in Key Vault"
echo ""

# Step 5: Create Private Endpoint for Storage (optional for free tier)
echo "Step 5: Configuring Storage Private Endpoint..."
STORAGE_ID=$(az storage account show \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'id' \
  --output tsv)

az network private-endpoint create \
  --name "pe-storage-dev-westus2-001" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --subnet snet-storage \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id file \
  --connection-name "pe-storage-connection" \
  --output table

echo "✓ Storage Private Endpoint configured"
echo ""

echo "=========================================="
echo "Foundation Deployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Manually deploy SendGrid from Azure Marketplace (Free tier)"
echo "2. Store SendGrid API key in Key Vault:"
echo "   az keyvault secret set --vault-name $KEY_VAULT_NAME --name sendgrid-api-key --value '<YOUR_API_KEY>'"
echo "3. Run scripts/02-deploy-security.sh to configure NSGs"
echo ""
echo "Configuration saved to: .azure-config"

