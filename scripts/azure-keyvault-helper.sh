#!/bin/bash
# Azure Key Vault Helper Script
# Utilities for working with secrets in Azure Key Vault

# Load configuration
if [ -f .azure-config ]; then
    source .azure-config
else
    echo "Error: .azure-config not found"
    exit 1
fi

# Function to retrieve a secret
get_secret() {
    local secret_name=$1
    if [ -z "$secret_name" ]; then
        echo "Usage: $0 get <secret-name>"
        exit 1
    fi
    
    echo "Retrieving secret: $secret_name"
    az keyvault secret show \
        --vault-name "$KEY_VAULT_NAME" \
        --name "$secret_name" \
        --query value \
        --output tsv
}

# Function to set a secret
set_secret() {
    local secret_name=$1
    local secret_value=$2
    
    if [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
        echo "Usage: $0 set <secret-name> <secret-value>"
        exit 1
    fi
    
    echo "Setting secret: $secret_name"
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "$secret_name" \
        --value "$secret_value" \
        --output table
}

# Function to list all secrets
list_secrets() {
    echo "Listing all secrets in Key Vault: $KEY_VAULT_NAME"
    az keyvault secret list \
        --vault-name "$KEY_VAULT_NAME" \
        --query "[].{Name:name, Enabled:attributes.enabled, Updated:attributes.updated}" \
        --output table
}

# Function to delete a secret
delete_secret() {
    local secret_name=$1
    
    if [ -z "$secret_name" ]; then
        echo "Usage: $0 delete <secret-name>"
        exit 1
    fi
    
    read -p "Are you sure you want to delete secret '$secret_name'? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting secret: $secret_name"
        az keyvault secret delete \
            --vault-name "$KEY_VAULT_NAME" \
            --name "$secret_name"
        echo "✓ Secret deleted"
    else
        echo "Cancelled"
    fi
}

# Function to export secrets to environment file
export_secrets() {
    echo "Exporting secrets to ~/.azure-env"
    
    cat > ~/.azure-env << EOF
# Azure Environment Variables
# Generated: $(date)
# Source this file: source ~/.azure-env

export KEY_VAULT_NAME="$KEY_VAULT_NAME"
export STORAGE_ACCOUNT_NAME="$STORAGE_ACCOUNT_NAME"
export AZURE_STORAGE_KEY="$(get_secret storage-account-key)"
export WINDOWS_PASSWORD="$(get_secret windows-admin-password)"
export SQL_SERVER_NAME="$(get_secret sql-server-name)"
export SQL_ADMIN_USERNAME="$(get_secret sql-admin-username)"
export SQL_ADMIN_PASSWORD="$(get_secret sql-admin-password)"
export SQL_DATABASE_NAME="$(get_secret sql-database-name)"
EOF
    
    chmod 600 ~/.azure-env
    echo "✓ Secrets exported to ~/.azure-env"
    echo ""
    echo "To load these variables:"
    echo "  source ~/.azure-env"
}

# Main script logic
case "$1" in
    get)
        get_secret "$2"
        ;;
    set)
        set_secret "$2" "$3"
        ;;
    list)
        list_secrets
        ;;
    delete)
        delete_secret "$2"
        ;;
    export)
        export_secrets
        ;;
    *)
        echo "Azure Key Vault Helper Script"
        echo ""
        echo "Usage: $0 <command> [arguments]"
        echo ""
        echo "Commands:"
        echo "  get <secret-name>              Get a secret value"
        echo "  set <secret-name> <value>      Set a secret"
        echo "  list                           List all secrets"
        echo "  delete <secret-name>           Delete a secret"
        echo "  export                         Export secrets to ~/.azure-env"
        echo ""
        echo "Examples:"
        echo "  $0 get sql-admin-password"
        echo "  $0 list"
        echo "  $0 export"
        exit 1
        ;;
esac

