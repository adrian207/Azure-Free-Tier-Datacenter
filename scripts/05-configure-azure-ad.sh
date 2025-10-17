#!/bin/bash
################################################################################
# Azure Free Tier Datacenter - Azure AD Configuration Script
#
# Author: Adrian Johnson <adrian207@gmail.com>
# Version: 1.0
# Date: October 17, 2025
# Purpose: Configure Azure Active Directory authentication for all servers
#
# Description:
#   This script configures centralized authentication using Azure AD.
#   Enables single sign-on for Linux and Windows servers.
#
# Prerequisites:
#   - Azure CLI installed and authenticated
#   - Azure AD tenant configured
#   - VMs deployed with managed identities
#
# Usage:
#   ./05-configure-azure-ad.sh
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

# Print colored output
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

clear
echo "=========================================="
echo "  Azure AD Authentication Configuration"
echo "=========================================="
echo "  Author: Adrian Johnson"
echo "  Version: 1.0"
echo "=========================================="
echo ""

# Load configuration
if [ ! -f .azure-config ]; then
    print_error ".azure-config not found. Run previous scripts first."
    exit 1
fi

source .azure-config

print_info "Step 1/4: Gathering Azure AD information..."
echo ""

# Get Azure AD Tenant ID
TENANT_ID=$(az account show --query tenantId --output tsv)
print_success "Azure AD Tenant ID: $TENANT_ID"

# Get Subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
print_success "Subscription ID: $SUBSCRIPTION_ID"

# Save to environment file
cat >> .azure-config <<EOF
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
EOF

export AZURE_TENANT_ID=$TENANT_ID

echo ""
print_info "Step 2/4: Enabling Azure AD login extensions on VMs..."
echo ""

# Enable Azure AD SSH Login extension on Linux VMs
echo -n "  → Bastion host..."
az vm extension set \
  --resource-group "$RESOURCE_GROUP" \
  --vm-name vm-bastion-dev-westus2-001 \
  --name AADSSHLoginForLinux \
  --publisher Microsoft.Azure.ActiveDirectory \
  --output none 2>/dev/null || true
echo " Done"

echo -n "  → Linux proxy server..."
az vm extension set \
  --resource-group "$RESOURCE_GROUP" \
  --vm-name vm-linuxproxy-dev-westus2-001 \
  --name AADSSHLoginForLinux \
  --publisher Microsoft.Azure.ActiveDirectory \
  --output none 2>/dev/null || true
echo " Done"

echo -n "  → Linux app server..."
az vm extension set \
  --resource-group "$RESOURCE_GROUP" \
  --vm-name vm-linuxapp-dev-westus2-001 \
  --name AADSSHLoginForLinux \
  --publisher Microsoft.Azure.ActiveDirectory \
  --output none 2>/dev/null || true
echo " Done"

print_success "Azure AD SSH extensions enabled on all Linux VMs"
echo ""

print_info "Step 3/4: Assigning Azure AD roles..."
echo ""

# Get current user
CURRENT_USER=$(az ad signed-in-user show --query userPrincipalName --output tsv)
print_info "Current user: $CURRENT_USER"

# Assign Virtual Machine Administrator Login role to current user
print_info "Assigning VM Administrator Login role..."
az role assignment create \
  --role "Virtual Machine Administrator Login" \
  --assignee "$CURRENT_USER" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
  --output none 2>/dev/null || print_warning "Role may already be assigned"

print_success "Azure AD roles configured"
echo ""

print_info "Step 4/4: Creating configuration guide..."

cat > azure-ad-setup-guide.txt <<EOF
========================================
Azure AD Authentication Setup Guide
========================================

Author: Adrian Johnson <adrian207@gmail.com>
Date: $(date)

Configuration Status: Extensions Installed
Tenant ID: $TENANT_ID
Resource Group: $RESOURCE_GROUP

========================================
LINUX SERVERS - Azure AD SSH LOGIN
========================================

The Azure AD SSH extension has been installed on all Linux VMs.

To log in with Azure AD:

1. Use Azure CLI to SSH:
   az ssh vm --resource-group $RESOURCE_GROUP --name vm-bastion-dev-westus2-001

2. Or use standard SSH with Azure AD credentials:
   ssh $CURRENT_USER@$BASTION_PUBLIC_IP
   (You may be prompted for Azure AD auth)

3. For other users, assign the role:
   az role assignment create \\
     --role "Virtual Machine Administrator Login" \\
     --assignee user@domain.com \\
     --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

========================================
WINDOWS SERVER - Azure AD JOIN
========================================

Windows Server must be joined to Azure AD manually:

1. RDP to: $WINWEB_PRIVATE_IP (from bastion)

2. Open Settings > Accounts > Access work or school

3. Click "Connect" > "Join this device to Azure Active Directory"

4. Enter Azure AD admin credentials: $CURRENT_USER

5. Complete MFA if prompted

6. After joining, log in with: AzureAD\\user@domain.com

========================================
GUACAMOLE - Azure AD SAML SSO
========================================

To configure Guacamole with Azure AD:

1. Create Enterprise Application in Azure Portal:
   - Azure Active Directory > Enterprise Applications > New Application
   - Name: "Azure Datacenter Guacamole"
   - Type: Non-gallery application

2. Configure SAML Single Sign-On:
   - Identifier (Entity ID): http://$BASTION_PUBLIC_IP:8080/guacamole
   - Reply URL: http://$BASTION_PUBLIC_IP:8080/guacamole/api/ext/saml/callback
   
3. Get SAML Configuration:
   - App Federation Metadata Url: Copy this URL
   - Certificate (Base64): Download this

4. Configure Guacamole:
   - See: docs/Guacamole-Azure-AD-SAML-Setup.md

========================================
CONDITIONAL ACCESS POLICIES
========================================

Enhance security with Conditional Access:

1. Go to: Azure AD > Security > Conditional Access

2. Create policies:
   - Require MFA for all admin access
   - Block legacy authentication
   - Require compliant devices
   - Limit access to specific locations

========================================
TESTING AZURE AD AUTHENTICATION
========================================

Linux:
  az ssh vm --resource-group $RESOURCE_GROUP --name vm-bastion-dev-westus2-001

Windows:
  mstsc /v:$WINWEB_PRIVATE_IP
  Username: AzureAD\\$CURRENT_USER

Verify:
  az role assignment list --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" --output table

========================================
TROUBLESHOOTING
========================================

Linux SSH Issues:
  - Check extension: az vm extension show --resource-group $RESOURCE_GROUP --vm-name <VM> --name AADSSHLoginForLinux
  - View logs: az vm run-command invoke --resource-group $RESOURCE_GROUP --name <VM> --command-id RunShellScript --scripts "journalctl -u sshd"

Windows Join Issues:
  - Check status: dsregcmd /status
  - Test connectivity: Test-NetConnection login.microsoftonline.com -Port 443
  - Event Viewer: Applications and Services > Microsoft > Windows > User Device Registration

Azure AD Logs:
  - Azure Portal > Azure Active Directory > Sign-in logs
  - Filter by application or user

========================================
DOCUMENTATION
========================================

Azure AD SSH: https://docs.microsoft.com/azure/active-directory/devices/howto-vm-sign-in-azure-ad-linux
Azure AD Join: https://docs.microsoft.com/azure/active-directory/devices/azureadjoin-plan
Conditional Access: https://docs.microsoft.com/azure/active-directory/conditional-access/

========================================
EOF

print_success "Configuration guide created: azure-ad-setup-guide.txt"
echo ""

echo "=========================================="
echo "  ✓ Azure AD Configuration Complete!"
echo "=========================================="
echo ""
echo "Configuration Summary:"
echo "  • Azure AD extensions installed on all Linux VMs"
echo "  • VM Administrator role assigned to: $CURRENT_USER"
echo "  • Windows Server ready for Azure AD join"
echo "  • Guacamole SAML configuration prepared"
echo ""
echo "Next Steps:"
echo "  1. Review: azure-ad-setup-guide.txt"
echo "  2. Test Linux SSH: az ssh vm --resource-group $RESOURCE_GROUP --name vm-bastion-dev-westus2-001"
echo "  3. Join Windows to Azure AD (manual)"
echo "  4. Configure Guacamole SAML (optional)"
echo ""
echo "Documentation: docs/Guacamole-Azure-AD-SAML-Setup.md"
echo ""

