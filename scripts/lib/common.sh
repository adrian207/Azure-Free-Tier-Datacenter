#!/bin/bash
################################################################################
# Common Functions Library
#
# Author: Adrian Johnson <adrian207@gmail.com>
# Version: 1.0
# Date: October 17, 2025
# Purpose: Shared functions for all deployment scripts
#
# Description:
#   Common utilities, error handling, retry logic, and helper functions
#   used across all deployment scripts. Source this file in other scripts.
#
# Usage:
#   source scripts/lib/common.sh
#
# Copyright (c) 2025 Adrian Johnson
# Licensed under MIT License
################################################################################

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Error codes
readonly ERR_MISSING_CONFIG=10
readonly ERR_MISSING_DEPENDENCY=11
readonly ERR_AZURE_CLI_FAILED=12
readonly ERR_INVALID_INPUT=13
readonly ERR_RESOURCE_EXISTS=14

# Print colored output functions
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_step() { echo -e "${CYAN}▶ $1${NC}"; }

# Progress bar function
show_progress() {
    local duration=$1
    local message=$2
    echo -n "$message"
    for ((i=0; i<duration; i++)); do
        echo -n "."
        sleep 1
    done
    echo " Done"
}

# Retry function with exponential backoff
# Usage: retry_with_backoff <max_attempts> <command> [args...]
retry_with_backoff() {
    local max_attempts=$1
    shift
    local attempt=1
    local delay=2
    
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            print_warning "Attempt $attempt failed. Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
            attempt=$((attempt + 1))
        else
            print_error "Command failed after $max_attempts attempts"
            return 1
        fi
    done
}

# Validate configuration file exists
validate_config() {
    local config_file=${1:-.azure-config}
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        print_info "Run previous deployment scripts first"
        exit $ERR_MISSING_CONFIG
    fi
}

# Check if Azure CLI is installed and authenticated
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found"
        print_info "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit $ERR_MISSING_DEPENDENCY
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not authenticated to Azure"
        print_info "Run: az login"
        exit $ERR_AZURE_CLI_FAILED
    fi
    
    print_success "Azure CLI authenticated"
}

# Validate password complexity
validate_password() {
    local password=$1
    local min_length=${2:-12}
    
    # Check length
    if [ ${#password} -lt $min_length ]; then
        print_error "Password must be at least $min_length characters"
        return 1
    fi
    
    # Check for uppercase
    if ! [[ "$password" =~ [A-Z] ]]; then
        print_error "Password must contain at least one uppercase letter"
        return 1
    fi
    
    # Check for lowercase
    if ! [[ "$password" =~ [a-z] ]]; then
        print_error "Password must contain at least one lowercase letter"
        return 1
    fi
    
    # Check for digit
    if ! [[ "$password" =~ [0-9] ]]; then
        print_error "Password must contain at least one digit"
        return 1
    fi
    
    # Check for special character
    if ! [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        print_error "Password must contain at least one special character"
        return 1
    fi
    
    return 0
}

# Securely read password
read_password() {
    local prompt=$1
    local varname=$2
    local password=""
    local password_confirm=""
    
    while true; do
        read -rsp "$prompt: " password
        echo ""
        read -rsp "Confirm password: " password_confirm
        echo ""
        
        if [ "$password" != "$password_confirm" ]; then
            print_error "Passwords do not match. Try again."
            continue
        fi
        
        if validate_password "$password"; then
            eval "$varname='$password'"
            return 0
        fi
        
        print_warning "Please try again with a stronger password"
    done
}

# Securely store password in Key Vault
store_password_in_keyvault() {
    local vault_name=$1
    local secret_name=$2
    local password=$3
    
    print_step "Storing password in Key Vault..."
    
    retry_with_backoff 3 az keyvault secret set \
        --vault-name "$vault_name" \
        --name "$secret_name" \
        --value "$password" \
        --output none
    
    if [ $? -eq 0 ]; then
        print_success "Password stored securely in Key Vault: $secret_name"
        return 0
    else
        print_error "Failed to store password in Key Vault"
        return 1
    fi
}

# Retrieve password from Key Vault
get_password_from_keyvault() {
    local vault_name=$1
    local secret_name=$2
    
    az keyvault secret show \
        --vault-name "$vault_name" \
        --name "$secret_name" \
        --query value \
        --output tsv 2>/dev/null
}

# Wait for Azure resource to be ready
wait_for_resource() {
    local resource_group=$1
    local resource_name=$2
    local resource_type=$3
    local max_wait=${4:-300}  # 5 minutes default
    local elapsed=0
    
    print_step "Waiting for $resource_type: $resource_name..."
    
    while [ $elapsed -lt $max_wait ]; do
        if az resource show \
            --resource-group "$resource_group" \
            --name "$resource_name" \
            --resource-type "$resource_type" \
            --query "provisioningState" \
            --output tsv 2>/dev/null | grep -q "Succeeded"; then
            print_success "$resource_name is ready"
            return 0
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        echo -n "."
    done
    
    echo ""
    print_error "Timeout waiting for $resource_name"
    return 1
}

# Check if resource exists
resource_exists() {
    local resource_group=$1
    local resource_name=$2
    local resource_type=$3
    
    az resource show \
        --resource-group "$resource_group" \
        --name "$resource_name" \
        --resource-type "$resource_type" \
        &>/dev/null
    
    return $?
}

# Create resource with retry
create_resource_with_retry() {
    local description=$1
    shift
    
    print_step "$description..."
    
    if retry_with_backoff 3 "$@"; then
        print_success "$description completed"
        return 0
    else
        print_error "$description failed"
        return 1
    fi
}

# Parallel execution helper
run_parallel() {
    local pids=()
    
    # Execute all commands in background
    for cmd in "$@"; do
        eval "$cmd" &
        pids+=($!)
    done
    
    # Wait for all to complete
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            failed=1
        fi
    done
    
    return $failed
}

# Log to file and console
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="${LOG_FILE:-deployment.log}"
    
    # Create log directory if needed
    mkdir -p "$(dirname "$log_file")"
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$log_file"
    
    # Also print to console based on level
    case "$level" in
        ERROR)
            print_error "$message"
            ;;
        WARNING)
            print_warning "$message"
            ;;
        INFO)
            print_info "$message"
            ;;
        SUCCESS)
            print_success "$message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Cleanup function for trap
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        print_error "Script failed with exit code: $exit_code"
        log ERROR "Script terminated with errors"
    fi
    
    # Add any cleanup tasks here
    
    exit $exit_code
}

# Set up error handling
set -eE  # Exit on error, inherit ERR trap
set -o pipefail  # Catch errors in pipes
trap cleanup ERR EXIT

# Export functions for subshells
export -f print_success print_error print_info print_warning print_step
export -f retry_with_backoff validate_password log

print_info "Common library loaded successfully"

