#!/bin/bash
################################################################################
# Azure Free Tier Datacenter - Deploy Monitoring Dashboard
#
# Author: Adrian Johnson <adrian207@gmail.com>
# Version: 1.0
# Date: October 17, 2025
# Purpose: Deploy Azure Monitor dashboard for unified monitoring
#
# Copyright (c) 2025 Adrian Johnson
# Licensed under MIT License
################################################################################

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

validate_config
check_azure_cli
source .azure-config

print_info "Deploying Azure Monitor Dashboard..."
echo ""

# Deploy dashboard template
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file templates/azure-monitor-dashboard.json \
    --parameters \
        dashboardName="Azure-Datacenter-Dashboard" \
        resourceGroup="$RESOURCE_GROUP" \
    --output table

if [ $? -eq 0 ]; then
    print_success "Dashboard deployed successfully"
    echo ""
    echo "Access dashboard:"
    echo "  https://portal.azure.com/#dashboard"
    echo ""
else
    print_error "Dashboard deployment failed"
    exit 1
fi

