#!/bin/bash
################################################################################
# Azure Free Tier Datacenter - Deployment Tests
#
# Author: Adrian Johnson <adrian207@gmail.com>
# Version: 1.0
# Date: October 17, 2025
# Purpose: Automated testing for deployment validation
#
# Description:
#   Comprehensive test suite for validating Azure infrastructure deployment.
#   Tests resources, connectivity, security, and configuration.
#
# Usage:
#   ./tests/test-deployment.sh
#
# Copyright (c) 2025 Adrian Johnson
# Licensed under MIT License
################################################################################

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/common.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result functions
test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    print_success "PASS: $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    print_error "FAIL: $1"
}

run_test() {
    local test_name=$1
    shift
    TESTS_RUN=$((TESTS_RUN + 1))
    
    print_step "Testing: $test_name"
    
    if "$@"; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name"
        return 1
    fi
}

# Test: Configuration file exists
test_config_exists() {
    [ -f .azure-config ]
}

# Test: Azure CLI is installed
test_azure_cli_installed() {
    command -v az &> /dev/null
}

# Test: Authenticated to Azure
test_azure_authenticated() {
    az account show &> /dev/null
}

# Test: Resource group exists
test_resource_group_exists() {
    source .azure-config
    az group show --name "$RESOURCE_GROUP" &> /dev/null
}

# Test: Virtual Network exists
test_vnet_exists() {
    source .azure-config
    az network vnet show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VNET_NAME" &> /dev/null
}

# Test: All subnets exist
test_subnets_exist() {
    source .azure-config
    local subnets=("snet-management" "snet-web" "snet-app" "snet-database" "snet-storage")
    
    for subnet in "${subnets[@]}"; do
        if ! az network vnet subnet show \
            --resource-group "$RESOURCE_GROUP" \
            --vnet-name "$VNET_NAME" \
            --name "$subnet" &> /dev/null; then
            return 1
        fi
    done
    return 0
}

# Test: Key Vault exists
test_keyvault_exists() {
    source .azure-config
    az keyvault show --name "$KEY_VAULT_NAME" &> /dev/null
}

# Test: Storage Account exists
test_storage_exists() {
    source .azure-config
    az storage account show \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" &> /dev/null
}

# Test: NSGs exist and have rules
test_nsgs_exist() {
    source .azure-config
    
    # Check management NSG
    if ! az network nsg show \
        --resource-group "$RESOURCE_GROUP" \
        --name nsg-management &> /dev/null; then
        return 1
    fi
    
    # Check internal NSG
    if ! az network nsg show \
        --resource-group "$RESOURCE_GROUP" \
        --name nsg-internal &> /dev/null; then
        return 1
    fi
    
    # Check that management NSG has rules
    local rule_count=$(az network nsg rule list \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name nsg-management \
        --query "length(@)" \
        --output tsv)
    
    [ "$rule_count" -gt 0 ]
}

# Test: VMs exist
test_vms_exist() {
    source .azure-config
    local vms=("vm-bastion-dev-westus2-001" "vm-winweb-dev-westus2-001" "vm-linuxproxy-dev-westus2-001" "vm-linuxapp-dev-westus2-001")
    
    for vm in "${vms[@]}"; do
        if ! az vm show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$vm" &> /dev/null; then
            echo "VM not found: $vm"
            return 1
        fi
    done
    return 0
}

# Test: VMs have managed identities
test_vms_have_identities() {
    source .azure-config
    local vms=("vm-bastion-dev-westus2-001" "vm-winweb-dev-westus2-001" "vm-linuxproxy-dev-westus2-001" "vm-linuxapp-dev-westus2-001")
    
    for vm in "${vms[@]}"; do
        local identity=$(az vm identity show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$vm" \
            --query principalId \
            --output tsv 2>/dev/null)
        
        if [ -z "$identity" ]; then
            echo "VM has no managed identity: $vm"
            return 1
        fi
    done
    return 0
}

# Test: Bastion has public IP
test_bastion_has_public_ip() {
    source .azure-config
    
    local public_ip=$(az vm show \
        --resource-group "$RESOURCE_GROUP" \
        --name vm-bastion-dev-westus2-001 \
        --show-details \
        --query publicIps \
        --output tsv)
    
    [ -n "$public_ip" ]
}

# Test: Internal VMs have NO public IPs
test_internal_vms_no_public_ip() {
    source .azure-config
    local vms=("vm-winweb-dev-westus2-001" "vm-linuxproxy-dev-westus2-001" "vm-linuxapp-dev-westus2-001")
    
    for vm in "${vms[@]}"; do
        local public_ip=$(az vm show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$vm" \
            --show-details \
            --query publicIps \
            --output tsv)
        
        if [ -n "$public_ip" ]; then
            echo "VM should not have public IP: $vm"
            return 1
        fi
    done
    return 0
}

# Test: Key Vault has required secrets
test_keyvault_has_secrets() {
    source .azure-config
    local required_secrets=("storage-account-key" "windows-admin-password")
    
    for secret in "${required_secrets[@]}"; do
        if ! az keyvault secret show \
            --vault-name "$KEY_VAULT_NAME" \
            --name "$secret" &> /dev/null; then
            echo "Secret not found: $secret"
            return 1
        fi
    done
    return 0
}

# Test: SQL Database exists (if deployed)
test_sql_database_exists() {
    source .azure-config
    
    if [ -z "$SQL_SERVER_NAME" ]; then
        print_warning "SQL Server not deployed yet, skipping"
        return 0
    fi
    
    az sql db show \
        --resource-group "$RESOURCE_GROUP" \
        --server "$SQL_SERVER_NAME" \
        --name "$SQL_DB_NAME" &> /dev/null
}

# Test: SSH connectivity to bastion
test_ssh_connectivity() {
    source .azure-config
    
    if [ -z "$BASTION_PUBLIC_IP" ]; then
        print_warning "Bastion IP not configured, skipping"
        return 0
    fi
    
    ssh -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        azureuser@"$BASTION_PUBLIC_IP" \
        "exit" &> /dev/null
}

# Main test execution
main() {
    clear
    echo "=========================================="
    echo "  Azure Datacenter - Deployment Tests"
    echo "=========================================="
    echo "  Author: Adrian Johnson"
    echo "  Date: $(date)"
    echo "=========================================="
    echo ""
    
    # Prerequisites tests
    print_info "Running prerequisite tests..."
    echo ""
    run_test "Configuration file exists" test_config_exists
    run_test "Azure CLI installed" test_azure_cli_installed
    run_test "Azure authenticated" test_azure_authenticated
    echo ""
    
    # Infrastructure tests
    print_info "Running infrastructure tests..."
    echo ""
    run_test "Resource group exists" test_resource_group_exists
    run_test "Virtual Network exists" test_vnet_exists
    run_test "All subnets exist" test_subnets_exist
    run_test "Key Vault exists" test_keyvault_exists
    run_test "Storage Account exists" test_storage_exists
    run_test "NSGs exist with rules" test_nsgs_exist
    echo ""
    
    # VM tests
    print_info "Running VM tests..."
    echo ""
    run_test "All VMs exist" test_vms_exist
    run_test "VMs have managed identities" test_vms_have_identities
    run_test "Bastion has public IP" test_bastion_has_public_ip
    run_test "Internal VMs have NO public IPs" test_internal_vms_no_public_ip
    echo ""
    
    # Security tests
    print_info "Running security tests..."
    echo ""
    run_test "Key Vault has required secrets" test_keyvault_has_secrets
    echo ""
    
    # Optional component tests
    print_info "Running optional component tests..."
    echo ""
    run_test "SQL Database exists (if deployed)" test_sql_database_exists
    run_test "SSH connectivity to bastion" test_ssh_connectivity
    echo ""
    
    # Test summary
    echo "=========================================="
    echo "  Test Summary"
    echo "=========================================="
    echo "  Total Tests: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "=========================================="
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "$TESTS_FAILED test(s) failed"
        return 1
    fi
}

# Run tests
main
exit $?

