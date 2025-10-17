#!/bin/bash
################################################################################
# Azure Free Tier Datacenter - Foundation Deployment Script
#
# Author: Adrian Johnson <adrian207@gmail.com>
# Version: 1.0
# Date: October 17, 2025
# Purpose: Deploy foundational resources (Resource Group, VNet, Subnets, 
#          Key Vault, Storage Account)
#
# Description:
#   This script creates the core infrastructure components for the Azure
#   Free Tier Datacenter including networking, key vault for secrets
#   management, and shared storage with private endpoint.
#
# Prerequisites:
#   - Azure CLI installed and authenticated
#   - Contributor or Owner permissions on Azure subscription
#
# Usage:
#   ./01-deploy-foundation.sh
#
# Copyright (c) 2025 Adrian Johnson
# Licensed under MIT License
################################################################################

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress bar function
show_progress() {
    local duration=$1
    local msg=$2
    echo -n "$msg"
    for ((i=0; i<duration; i++)); do
        echo -n "."
        sleep 1
    done
    echo ""
}

# Print colored output
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

clear
echo "=========================================="
echo "  Azure Free Tier Datacenter Deployment"
echo "  Part 1: Foundation Resources"
echo "=========================================="
echo "  Author: Adrian Johnson"
echo "  Version: 1.0"
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

print_success "Configuration saved to .azure-config"
echo ""

# Step 1: Create Resource Group
print_info "Step 1/5: Creating Resource Group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$REGION" \
  --output table

print_success "Resource Group created: $RESOURCE_GROUP"
echo ""

# Step 2: Deploy Key Vault
print_info "Step 2/5: Creating Key Vault (this may take a minute)..."
az keyvault create \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$REGION" \
  --enable-rbac-authorization false \
  --output table

print_success "Key Vault created: $KEY_VAULT_NAME"
echo ""

# Step 3: Deploy VNet and Subnets
print_info "Step 3/5: Creating Virtual Network and Subnets..."
echo -n "  → Creating VNet..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefixes 10.10.0.0/16 \
  --output none
echo " Done"

echo -n "  → Creating 5 subnets"
# Management Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-management \
  --address-prefixes 10.10.1.0/24 \
  --output none
echo -n "."

# Web Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-web \
  --address-prefixes 10.10.2.0/24 \
  --output none
echo -n "."

# App Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-app \
  --address-prefixes 10.10.3.0/24 \
  --output none
echo -n "."

# Database Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-database \
  --address-prefixes 10.10.4.0/24 \
  --output none
echo -n "."

# Storage Subnet
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-storage \
  --address-prefixes 10.10.5.0/24 \
  --output none
echo " Done"

print_success "VNet and all 5 subnets created"
echo ""

# Step 4: Deploy Storage Account and File Share
print_info "Step 4/5: Creating Storage Account and File Share..."
echo -n "  → Creating Storage Account (this may take a minute)..."
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$REGION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --output none
echo " Done"

echo -n "  → Creating File Share (5 GiB)..."
az storage share create \
  --name "$FILE_SHARE_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --quota 5 \
  --output none
echo " Done"

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
  --output none

print_success "Storage Account and File Share created"
print_success "Credentials stored in Key Vault"
echo ""

# Step 5: Create Private Endpoint for Storage (optional for free tier)
print_info "Step 5/5: Configuring Storage Private Endpoint..."
STORAGE_ID=$(az storage account show \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'id' \
  --output tsv)

echo -n "  → Creating private endpoint..."
az network private-endpoint create \
  --name "pe-storage-dev-westus2-001" \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --subnet snet-storage \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id file \
  --connection-name "pe-storage-connection" \
  --output none
echo " Done"

print_success "Storage Private Endpoint configured"
echo ""

echo "=========================================="
echo "  ✓ Foundation Deployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Manually deploy SendGrid from Azure Marketplace (Free tier)"
echo "2. Store SendGrid API key in Key Vault:"
echo "   az keyvault secret set --vault-name $KEY_VAULT_NAME --name sendgrid-api-key --value '<YOUR_API_KEY>'"
echo "3. Run scripts/02-deploy-security.sh to configure NSGs"
echo ""
echo "Configuration saved to: .azure-config"

