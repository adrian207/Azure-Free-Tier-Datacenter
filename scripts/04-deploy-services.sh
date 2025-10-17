#!/bin/bash
# Azure Free Tier Datacenter - Services Deployment Script
# Version: 1.0
# Purpose: Deploy Azure SQL Database and Azure Monitor alerting

set -e  # Exit on error

echo "=========================================="
echo "Azure Free Tier Datacenter Deployment"
echo "Part 4: Azure SQL & Monitoring"
echo "=========================================="
echo ""

# Load configuration
if [ ! -f .azure-config ]; then
    echo "Error: .azure-config not found. Run previous scripts first."
    exit 1
fi

source .azure-config

# Prompt for SQL admin password
echo "Enter a strong password for the SQL Server admin account:"
echo "(Must be 8-128 characters, contain uppercase, lowercase, and number)"
read -sp "SQL Password: " SQL_PASSWORD
echo ""
read -sp "Confirm Password: " SQL_PASSWORD_CONFIRM
echo ""

if [ "$SQL_PASSWORD" != "$SQL_PASSWORD_CONFIRM" ]; then
    echo "Error: Passwords do not match"
    exit 1
fi

if [ -z "$SQL_PASSWORD" ]; then
    echo "Error: Password cannot be empty"
    exit 1
fi

# Prompt for alert email
echo ""
echo "Enter email address for Azure Monitor alerts:"
read -p "Email: " ALERT_EMAIL

if [ -z "$ALERT_EMAIL" ]; then
    echo "Error: Email address is required"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Alert Email: $ALERT_EMAIL"
echo ""

# Step 1: Create SQL Server
echo "Step 1: Creating Azure SQL Server..."
SQL_SERVER_NAME="sql-server-dev-wus2-$(openssl rand -hex 4)"

az sql server create \
  --name "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$REGION" \
  --admin-user sqladmin \
  --admin-password "$SQL_PASSWORD" \
  --output table

echo "✓ SQL Server created: $SQL_SERVER_NAME"
echo ""

# Configure firewall to allow Azure services
echo "Configuring SQL Server firewall..."
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER_NAME" \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0 \
  --output table

# Allow access from VNet
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER_NAME" \
  --name AllowVNet \
  --start-ip-address 10.10.0.0 \
  --end-ip-address 10.10.255.255 \
  --output table

echo "✓ SQL Server firewall configured"
echo ""

# Step 2: Create SQL Database
echo "Step 2: Creating SQL Database..."
SQL_DB_NAME="sql-maindb-dev-westus2-001"

az sql db create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER_NAME" \
  --name "$SQL_DB_NAME" \
  --edition Basic \
  --capacity 5 \
  --zone-redundant false \
  --backup-storage-redundancy Local \
  --output table

echo "✓ SQL Database created: $SQL_DB_NAME"
echo ""

# Store SQL credentials in Key Vault
echo "Step 3: Storing SQL credentials in Key Vault..."
az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "sql-server-name" \
  --value "$SQL_SERVER_NAME.database.windows.net" \
  --output table

az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "sql-admin-username" \
  --value "sqladmin" \
  --output table

az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "sql-admin-password" \
  --value "$SQL_PASSWORD" \
  --output table

az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "sql-database-name" \
  --value "$SQL_DB_NAME" \
  --output table

# Create connection string
CONNECTION_STRING="Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=$SQL_DB_NAME;Persist Security Info=False;User ID=sqladmin;Password=$SQL_PASSWORD;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "sql-connection-string" \
  --value "$CONNECTION_STRING" \
  --output table

echo "✓ SQL credentials stored in Key Vault"
echo ""

# Step 4: Create Action Group for Alerts
echo "Step 4: Creating Azure Monitor Action Group..."
ACTION_GROUP_NAME="ag-datacenter-alerts"

az monitor action-group create \
  --name "$ACTION_GROUP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --short-name "DCAlerts" \
  --output table

# Add email receiver to action group
az monitor action-group update \
  --name "$ACTION_GROUP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --add-action email admin "$ALERT_EMAIL" \
  --output table

echo "✓ Action Group created: $ACTION_GROUP_NAME"
echo ""

# Get Action Group ID for alert rules
ACTION_GROUP_ID=$(az monitor action-group show \
  --name "$ACTION_GROUP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  --output tsv)

# Step 5: Create Metric Alert Rules
echo "Step 5: Creating Metric Alert Rules..."

# Alert for Bastion Host - High CPU
az monitor metrics alert create \
  --name "alert-bastion-high-cpu" \
  --resource-group "$RESOURCE_GROUP" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/vm-bastion-dev-westus2-001" \
  --condition "avg Percentage CPU > 90" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "$ACTION_GROUP_ID" \
  --description "Alert when Bastion host CPU exceeds 90%" \
  --severity 2 \
  --output table

echo "✓ Bastion CPU alert created"

# Alert for Windows Server - High CPU
az monitor metrics alert create \
  --name "alert-winweb-high-cpu" \
  --resource-group "$RESOURCE_GROUP" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/vm-winweb-dev-westus2-001" \
  --condition "avg Percentage CPU > 90" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "$ACTION_GROUP_ID" \
  --description "Alert when Windows web server CPU exceeds 90%" \
  --severity 2 \
  --output table

echo "✓ Windows web server CPU alert created"

# Alert for Linux Proxy - High CPU
az monitor metrics alert create \
  --name "alert-linuxproxy-high-cpu" \
  --resource-group "$RESOURCE_GROUP" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/vm-linuxproxy-dev-westus2-001" \
  --condition "avg Percentage CPU > 90" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "$ACTION_GROUP_ID" \
  --description "Alert when Linux proxy CPU exceeds 90%" \
  --severity 2 \
  --output table

echo "✓ Linux proxy CPU alert created"

# Alert for Linux App - High CPU
az monitor metrics alert create \
  --name "alert-linuxapp-high-cpu" \
  --resource-group "$RESOURCE_GROUP" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/vm-linuxapp-dev-westus2-001" \
  --condition "avg Percentage CPU > 90" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "$ACTION_GROUP_ID" \
  --description "Alert when Linux app server CPU exceeds 90%" \
  --severity 2 \
  --output table

echo "✓ Linux app server CPU alert created"

# Alert for SQL Database - High DTU
az monitor metrics alert create \
  --name "alert-sql-high-dtu" \
  --resource-group "$RESOURCE_GROUP" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Sql/servers/$SQL_SERVER_NAME/databases/$SQL_DB_NAME" \
  --condition "avg dtu_consumption_percent > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "$ACTION_GROUP_ID" \
  --description "Alert when SQL Database DTU exceeds 80%" \
  --severity 2 \
  --output table

echo "✓ SQL Database DTU alert created"
echo ""

# Step 6: Enable VM Insights (optional, may incur costs)
echo "Step 6: Enabling basic monitoring for VMs..."
echo "Note: Full VM Insights may incur additional costs. Using basic platform metrics only."
echo "✓ Using default platform metrics (free tier)"
echo ""

# Save configuration
cat >> .azure-config <<EOF
SQL_SERVER_NAME=$SQL_SERVER_NAME
SQL_DB_NAME=$SQL_DB_NAME
ACTION_GROUP_NAME=$ACTION_GROUP_NAME
ALERT_EMAIL=$ALERT_EMAIL
EOF

# Create SQL connection info file
cat > sql-connection-info.txt <<EOF
========================================
Azure SQL Database - Connection Information
========================================

SQL Server: $SQL_SERVER_NAME.database.windows.net
Database: $SQL_DB_NAME
Username: sqladmin
Password: (stored in Key Vault: sql-admin-password)

Connection String (from Key Vault):
Secret Name: sql-connection-string

Test Connection:
sqlcmd -S $SQL_SERVER_NAME.database.windows.net -d $SQL_DB_NAME -U sqladmin -P '<password>'

========================================
EOF

echo "=========================================="
echo "Services Deployment Complete!"
echo "=========================================="
echo ""
echo "SQL Database Information:"
cat sql-connection-info.txt
echo ""
echo "Azure Monitor:"
echo "  Action Group: $ACTION_GROUP_NAME"
echo "  Alert Email: $ALERT_EMAIL"
echo "  Metric Alerts: 5 rules created"
echo ""
echo "Connection info saved to: sql-connection-info.txt"
echo ""
echo "Next Steps:"
echo "1. Configure Guacamole on bastion host"
echo "2. Run Ansible playbooks for server configuration"
echo "3. Mount Azure Files share on all VMs"
echo ""
echo "IMPORTANT: Remember to add SendGrid API key to Key Vault:"
echo "  az keyvault secret set --vault-name $KEY_VAULT_NAME --name sendgrid-api-key --value '<YOUR_API_KEY>'"
echo ""

