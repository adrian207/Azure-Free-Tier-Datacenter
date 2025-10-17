#!/bin/bash
# Azure Free Tier Datacenter - Security Deployment Script
# Version: 1.0
# Purpose: Deploy Network Security Groups and security rules

set -e  # Exit on error

echo "=========================================="
echo "Azure Free Tier Datacenter Deployment"
echo "Part 2: Network Security Groups"
echo "=========================================="
echo ""

# Load configuration
if [ ! -f .azure-config ]; then
    echo "Error: .azure-config not found. Run 01-deploy-foundation.sh first."
    exit 1
fi

source .azure-config

# Prompt for office public IP
echo "Enter your office/home public IP address for secure access:"
echo "(Find it at: https://whatismyipaddress.com/)"
read -p "Public IP: " OFFICE_PUBLIC_IP

if [ -z "$OFFICE_PUBLIC_IP" ]; then
    echo "Error: Public IP is required"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Allowed IP: $OFFICE_PUBLIC_IP"
echo ""

# Step 1: Create Management NSG
echo "Step 1: Creating Management NSG..."
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name nsg-management \
  --location "$REGION" \
  --output table

echo "✓ Management NSG created"
echo ""

# Add rules to Management NSG
echo "Adding rules to Management NSG..."

# Allow HTTPS from office IP
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-management \
  --name AllowHTTPSFromOffice \
  --priority 100 \
  --source-address-prefixes "$OFFICE_PUBLIC_IP" \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 443 \
  --access Allow \
  --protocol Tcp \
  --description "Allow HTTPS from office IP" \
  --output table

# Allow SSH from office IP
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-management \
  --name AllowSSHFromOffice \
  --priority 110 \
  --source-address-prefixes "$OFFICE_PUBLIC_IP" \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --description "Allow SSH from office IP" \
  --output table

# Allow HTTP from office IP (for Guacamole if needed)
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-management \
  --name AllowHTTPFromOffice \
  --priority 120 \
  --source-address-prefixes "$OFFICE_PUBLIC_IP" \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 80 8080 \
  --access Allow \
  --protocol Tcp \
  --description "Allow HTTP from office IP for Guacamole" \
  --output table

# Deny all other inbound traffic
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-management \
  --name DenyAllInbound \
  --priority 4096 \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges '*' \
  --access Deny \
  --protocol '*' \
  --description "Deny all other inbound traffic" \
  --output table

echo "✓ Management NSG rules configured"
echo ""

# Step 2: Create Internal NSG
echo "Step 2: Creating Internal NSG..."
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name nsg-internal \
  --location "$REGION" \
  --output table

echo "✓ Internal NSG created"
echo ""

# Add rules to Internal NSG
echo "Adding rules to Internal NSG..."

# Allow SSH from management subnet
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-internal \
  --name AllowSSHFromManagement \
  --priority 100 \
  --source-address-prefixes 10.10.1.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp \
  --description "Allow SSH from management subnet" \
  --output table

# Allow RDP from management subnet
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-internal \
  --name AllowRDPFromManagement \
  --priority 110 \
  --source-address-prefixes 10.10.1.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 3389 \
  --access Allow \
  --protocol Tcp \
  --description "Allow RDP from management subnet" \
  --output table

# Allow WinRM from management subnet (for Ansible)
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-internal \
  --name AllowWinRMFromManagement \
  --priority 120 \
  --source-address-prefixes 10.10.1.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 5985 5986 \
  --access Allow \
  --protocol Tcp \
  --description "Allow WinRM from management subnet" \
  --output table

# Allow HTTP/HTTPS for internal web traffic
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-internal \
  --name AllowWebTrafficInternal \
  --priority 130 \
  --source-address-prefixes 10.10.0.0/16 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 80 443 8080 \
  --access Allow \
  --protocol Tcp \
  --description "Allow web traffic within VNet" \
  --output table

# Allow SQL traffic from app subnet
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-internal \
  --name AllowSQLFromAppSubnet \
  --priority 140 \
  --source-address-prefixes 10.10.3.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 1433 \
  --access Allow \
  --protocol Tcp \
  --description "Allow SQL from app subnet" \
  --output table

# Allow all internal VNet traffic
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-internal \
  --name AllowVnetInbound \
  --priority 150 \
  --source-address-prefixes 10.10.0.0/16 \
  --source-port-ranges '*' \
  --destination-address-prefixes 10.10.0.0/16 \
  --destination-port-ranges '*' \
  --access Allow \
  --protocol '*' \
  --description "Allow all internal VNet traffic" \
  --output table

# Deny all inbound Internet traffic
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name nsg-internal \
  --name DenyInternetInbound \
  --priority 4096 \
  --source-address-prefixes Internet \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges '*' \
  --access Deny \
  --protocol '*' \
  --description "Deny all inbound Internet traffic" \
  --output table

echo "✓ Internal NSG rules configured"
echo ""

# Step 3: Associate NSGs with Subnets
echo "Step 3: Associating NSGs with Subnets..."

# Associate Management NSG with management subnet
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-management \
  --network-security-group nsg-management \
  --output table

echo "✓ Management NSG associated with snet-management"

# Associate Internal NSG with web subnet
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-web \
  --network-security-group nsg-internal \
  --output table

echo "✓ Internal NSG associated with snet-web"

# Associate Internal NSG with app subnet
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-app \
  --network-security-group nsg-internal \
  --output table

echo "✓ Internal NSG associated with snet-app"

# Associate Internal NSG with database subnet
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-database \
  --network-security-group nsg-internal \
  --output table

echo "✓ Internal NSG associated with snet-database"

# Associate Internal NSG with storage subnet
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-storage \
  --network-security-group nsg-internal \
  --output table

echo "✓ Internal NSG associated with snet-storage"
echo ""

# Save the office IP for reference
echo "OFFICE_PUBLIC_IP=$OFFICE_PUBLIC_IP" >> .azure-config

echo "=========================================="
echo "Security Configuration Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Run scripts/03-deploy-vms.sh to deploy virtual machines"
echo ""

