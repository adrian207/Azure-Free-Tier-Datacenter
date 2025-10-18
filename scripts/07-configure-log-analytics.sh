#!/bin/bash
################################################################################
# Azure Free Tier Datacenter - Configure Log Analytics
#
# Author: Adrian Johnson <adrian207@gmail.com>
# Version: 1.0
# Date: October 17, 2025
# Purpose: Configure centralized logging with Azure Log Analytics
#
# Description:
#   Creates Log Analytics workspace and configures all VMs to send logs.
#   Provides unified log aggregation and query interface.
#
# Copyright (c) 2025 Adrian Johnson
# Licensed under MIT License
################################################################################

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

export LOG_FILE="logs/07-configure-log-analytics.log"
mkdir -p logs

clear
echo "=========================================="
echo "  Azure Log Analytics Configuration"
echo "=========================================="
echo "  Author: Adrian Johnson"
echo "  Version: 1.0"
echo "=========================================="
echo ""

validate_config
check_azure_cli
source .azure-config

LOG_ANALYTICS_NAME="law-datacenter-dev-wus2-$(openssl rand -hex 4)"

print_step "Step 1/4: Creating Log Analytics Workspace..."
echo ""

# Create Log Analytics workspace
create_resource_with_retry "Create Log Analytics Workspace" \
    az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --location "$REGION" \
    --output none

if [ $? -ne 0 ]; then
    print_error "Failed to create Log Analytics workspace"
    exit $ERR_AZURE_CLI_FAILED
fi

echo ""
print_success "Log Analytics Workspace created: $LOG_ANALYTICS_NAME"

# Get workspace ID and key
WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --query customerId \
    --output tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_ANALYTICS_NAME" \
    --query primarySharedKey \
    --output tsv)

# Store in Key Vault
print_step "Step 2/4: Storing Log Analytics credentials in Key Vault..."
echo ""

store_password_in_keyvault "$KEY_VAULT_NAME" "log-analytics-workspace-id" "$WORKSPACE_ID"
store_password_in_keyvault "$KEY_VAULT_NAME" "log-analytics-workspace-key" "$WORKSPACE_KEY"

echo ""

# Install Log Analytics agent on all VMs
print_step "Step 3/4: Installing Log Analytics agents on VMs..."
echo ""

install_agent() {
    local vm_name=$1
    local is_windows=$2
    
    print_info "Installing on $vm_name..."
    
    if [ "$is_windows" = "true" ]; then
        # Windows agent
        retry_with_backoff 3 az vm extension set \
            --resource-group "$RESOURCE_GROUP" \
            --vm-name "$vm_name" \
            --name MicrosoftMonitoringAgent \
            --publisher Microsoft.EnterpriseCloud.Monitoring \
            --settings "{\"workspaceId\":\"$WORKSPACE_ID\"}" \
            --protected-settings "{\"workspaceKey\":\"$WORKSPACE_KEY\"}" \
            --output none
    else
        # Linux agent (OMS Agent)
        retry_with_backoff 3 az vm extension set \
            --resource-group "$RESOURCE_GROUP" \
            --vm-name "$vm_name" \
            --name OmsAgentForLinux \
            --publisher Microsoft.EnterpriseCloud.Monitoring \
            --settings "{\"workspaceId\":\"$WORKSPACE_ID\"}" \
            --protected-settings "{\"workspaceKey\":\"$WORKSPACE_KEY\"}" \
            --output none
    fi
    
    if [ $? -eq 0 ]; then
        echo "  ✓ $vm_name configured"
    else
        echo "  ✗ $vm_name failed"
        return 1
    fi
}

# Install on all VMs in parallel
install_agent "vm-bastion-dev-westus2-001" "false" &
PID1=$!

install_agent "vm-winweb-dev-westus2-001" "true" &
PID2=$!

install_agent "vm-linuxproxy-dev-westus2-001" "false" &
PID3=$!

install_agent "vm-linuxapp-dev-westus2-001" "false" &
PID4=$!

# Wait for all installations
wait $PID1 $PID2 $PID3 $PID4

echo ""
print_success "All agents installed"

# Configure data collection
print_step "Step 4/4: Configuring data collection..."
echo ""

# Enable solution for VMs
az monitor log-analytics solution create \
    --resource-group "$RESOURCE_GROUP" \
    --solution-type "ContainerInsights" \
    --workspace "$LOG_ANALYTICS_NAME" \
    --output none 2>/dev/null || true

# Save configuration
cat >> .azure-config <<EOF
LOG_ANALYTICS_NAME=$LOG_ANALYTICS_NAME
LOG_ANALYTICS_WORKSPACE_ID=$WORKSPACE_ID
EOF

# Create query examples file
cat > log-analytics-queries.kql <<EOF
// Azure Log Analytics - Sample Queries
// Author: Adrian Johnson <adrian207@gmail.com>

// ============================================
// Security Queries
// ============================================

// Failed SSH login attempts (last 24 hours)
Syslog
| where TimeGenerated > ago(24h)
| where Facility == "auth" or Facility == "authpriv"
| where SyslogMessage contains "Failed password"
| project TimeGenerated, Computer, SyslogMessage
| order by TimeGenerated desc

// Sudo command execution
Syslog
| where TimeGenerated > ago(24h)
| where Facility == "authpriv"
| where SyslogMessage contains "sudo"
| project TimeGenerated, Computer, SyslogMessage

// Windows Security Events - Failed logons
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4625  // Failed logon
| summarize Count=count() by Computer, Account
| order by Count desc

// ============================================
// Performance Queries
// ============================================

// CPU usage over time (all VMs)
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor"
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| render timechart

// Memory usage (Linux VMs)
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Memory"
| where CounterName == "Available MBytes"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| render timechart

// Disk space alerts
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Logical Disk"
| where CounterName == "% Free Space"
| where CounterValue < 20  // Less than 20% free
| project TimeGenerated, Computer, InstanceName, CounterValue
| order by CounterValue asc

// ============================================
// Application Queries
// ============================================

// All log entries from specific VM
Syslog
| where Computer == "vm-bastion-dev-westus2-001"
| where TimeGenerated > ago(1h)
| project TimeGenerated, Facility, SeverityLevel, SyslogMessage
| order by TimeGenerated desc

// Error and Warning messages (all VMs)
Syslog
| where TimeGenerated > ago(24h)
| where SeverityLevel in ("err", "error", "warn", "warning")
| summarize Count=count() by Computer, Facility, SeverityLevel
| order by Count desc

// ============================================
// Network Queries
// ============================================

// Network connections summary
VMConnection
| where TimeGenerated > ago(1h)
| summarize Connections=count() by Computer, Direction
| order by Connections desc

// ============================================
// Custom Alerts
// ============================================

// High CPU sustained over 5 minutes
Perf
| where TimeGenerated > ago(10m)
| where ObjectName == "Processor"
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| where avg_CounterValue > 80

// Multiple failed login attempts
Syslog
| where TimeGenerated > ago(15m)
| where Facility == "auth"
| where SyslogMessage contains "Failed password"
| summarize FailedAttempts=count() by Computer, bin(TimeGenerated, 5m)
| where FailedAttempts > 5

// ============================================
// Usage Tips
// ============================================

// 1. Access Log Analytics:
//    Azure Portal > Log Analytics workspaces > $LOG_ANALYTICS_NAME > Logs

// 2. Time ranges can be adjusted: ago(1h), ago(24h), ago(7d)

// 3. Export results: Click "Export" button in query interface

// 4. Create alerts: Click "New alert rule" from query results

// 5. Pin queries: Save frequently used queries to dashboard
EOF

chmod 644 log-analytics-queries.kql

echo ""
echo "=========================================="
echo "  ✓ Log Analytics Configuration Complete!"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Workspace: $LOG_ANALYTICS_NAME"
echo "  Workspace ID: $WORKSPACE_ID"
echo "  Location: $REGION"
echo ""
echo "Configured VMs:"
echo "  • vm-bastion-dev-westus2-001 (Linux)"
echo "  • vm-winweb-dev-westus2-001 (Windows)"
echo "  • vm-linuxproxy-dev-westus2-001 (Linux)"
echo "  • vm-linuxapp-dev-westus2-001 (Linux)"
echo ""
echo "Access Log Analytics:"
echo "  1. Azure Portal > Log Analytics workspaces"
echo "  2. Select: $LOG_ANALYTICS_NAME"
echo "  3. Click 'Logs' in left menu"
echo ""
echo "Sample Queries:"
echo "  See: log-analytics-queries.kql"
echo ""
print_info "Note: It may take 5-10 minutes for first logs to appear"
echo ""

log SUCCESS "Log Analytics configuration completed successfully"

