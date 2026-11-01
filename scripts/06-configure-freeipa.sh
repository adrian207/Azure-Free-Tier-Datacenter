#!/bin/bash
################################################################################
# Azure Free Tier Datacenter - FreeIPA Configuration Script
#
# Author: Adrian Johnson <adrian207@gmail.com>
# Version: 1.0
# Date: October 17, 2025
# Purpose: Configure FreeIPA identity management for centralized authentication
#
# Description:
#   This script deploys FreeIPA server for enterprise identity management.
#   Provides LDAP, Kerberos, integrated DNS, and Certificate Authority (PKI).
#   Enrolls all Linux servers as clients.
#
# Prerequisites:
#   - All VMs deployed and accessible
#   - Ansible configured
#   - At least 2GB RAM on app server (monitor B1s resources)
#
# Usage:
#   ./06-configure-freeipa.sh
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
echo "  FreeIPA Identity Management Setup"
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

print_warning "RESOURCE WARNING: FreeIPA requires ~2GB RAM"
print_warning "B1s VMs (1GB RAM) may struggle with FreeIPA server"
print_info "Consider monitoring resources during installation"
echo ""

read -p "Continue with FreeIPA installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

print_info "Step 1/4: Preparing for FreeIPA server installation..."
echo ""

# Check if we're running from bastion
if [ "$(hostname)" == "vm-bastion-dev-westus2-001" ]; then
    print_info "Running from bastion host"
else
    print_warning "This script should ideally run from the bastion host"
    print_info "Continuing anyway..."
fi

# Verify Ansible is available
if ! command -v ansible &> /dev/null; then
    print_error "Ansible not found. Please install Ansible first."
    exit 1
fi

print_success "Ansible found: $(ansible --version | head -n1)"
echo ""

print_info "Step 2/4: Installing FreeIPA server on vm-linuxapp..."
print_warning "This may take 15-30 minutes..."
echo ""

cd ~/ansible 2>/dev/null || cd ../ansible

# Run FreeIPA server installation playbook
ansible-playbook playbooks/07-install-freeipa-server.yml

print_success "FreeIPA server installation complete"
echo ""

# Get FreeIPA server IP
FREEIPA_SERVER="$LINUXAPP_PRIVATE_IP"

print_info "Step 3/4: Retrieving FreeIPA credentials..."
echo ""

# SSH to server and get credentials
print_info "Retrieving admin password from server..."
FREEIPA_ADMIN_PASSWORD=$(ssh -o StrictHostKeyChecking=no azureuser@$FREEIPA_SERVER \
  "sudo grep 'Admin Password:' /root/freeipa-credentials.txt | cut -d':' -f2 | tr -d ' '")

if [ -z "$FREEIPA_ADMIN_PASSWORD" ]; then
    print_error "Failed to retrieve FreeIPA admin password"
    print_info "Manually retrieve from: $FREEIPA_SERVER:/root/freeipa-credentials.txt"
    exit 1
fi

print_success "FreeIPA admin password retrieved"
echo ""

# Export for Ansible
export FREEIPA_SERVER=$FREEIPA_SERVER
export FREEIPA_ADMIN_PASSWORD=$FREEIPA_ADMIN_PASSWORD

print_info "Step 4/4: Enrolling client servers..."
echo ""

# Run client enrollment playbook
ansible-playbook playbooks/08-enroll-freeipa-clients.yml \
  --extra-vars "freeipa_server=$FREEIPA_SERVER freeipa_admin_password=$FREEIPA_ADMIN_PASSWORD"

print_success "Client enrollment complete"
echo ""

# Create local credentials file
cat > freeipa-credentials.txt <<EOF
========================================
FreeIPA Identity Management
========================================

Server: $FREEIPA_SERVER
Web UI: https://$FREEIPA_SERVER/ipa/ui

Admin Username: admin
Admin Password: $FREEIPA_ADMIN_PASSWORD

Domain: datacenter.local
Realm: DATACENTER.LOCAL

========================================
CLIENT USAGE
========================================

1. Create User:
   ipa user-add jsmith --first=John --last=Smith --password

2. Create Group:
   ipa group-add developers --desc="Development Team"

3. Add User to Group:
   ipa group-add-member developers --users=jsmith

4. Grant Sudo Access:
   ipa sudorule-add dev-sudo
   ipa sudorule-add-user --groups=developers dev-sudo
   ipa sudorule-add-allow-command --sudocmds=ALL dev-sudo

5. Test Login (from any enrolled client):
   ssh jsmith@vm-bastion.datacenter.local

6. Get Kerberos Ticket:
   kinit jsmith@DATACENTER.LOCAL

========================================
CERTIFICATE AUTHORITY
========================================

FreeIPA includes integrated PKI (Dogtag):

1. Request Certificate:
   ipa cert-request cert.csr --principal=host/server.datacenter.local

2. List Certificates:
   ipa cert-find

3. Revoke Certificate:
   ipa cert-revoke <serial-number>

CA Certificate: https://$FREEIPA_SERVER/ipa/config/ca.crt

========================================
WINDOWS INTEGRATION
========================================

Configure Windows to use FreeIPA for LDAP auth:

1. LDAP Server: ldap://$FREEIPA_SERVER
2. Base DN: dc=datacenter,dc=local
3. Bind DN: uid=admin,cn=users,cn=accounts,dc=datacenter,dc=local
4. Bind Password: (see above)

See: docs/FreeIPA-Windows-Integration.md

========================================
TROUBLESHOOTING
========================================

Web UI not accessible:
  - Check firewall: sudo firewall-cmd --list-all
  - Restart services: sudo ipactl restart

Client can't authenticate:
  - Check DNS: dig datacenter.local @$FREEIPA_SERVER
  - Test LDAP: ldapsearch -x -H ldap://$FREEIPA_SERVER -b dc=datacenter,dc=local
  - Check SSSD: sudo systemctl status sssd

========================================
KEEP THIS FILE SECURE!
========================================
EOF

chmod 600 freeipa-credentials.txt

echo "=========================================="
echo "  ✓ FreeIPA Setup Complete!"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  • FreeIPA Server: $FREEIPA_SERVER"
echo "  • Web UI: https://$FREEIPA_SERVER/ipa/ui"
echo "  • Username: admin"
echo "  • Password: (see freeipa-credentials.txt)"
echo ""
echo "Enrolled Clients:"
echo "  • vm-bastion"
echo "  • vm-linuxproxy"
echo "  • vm-linuxapp"
echo ""
echo "Next Steps:"
echo "  1. Access web UI: https://$FREEIPA_SERVER/ipa/ui"
echo "  2. Create user accounts"
echo "  3. Configure sudo rules"
echo "  4. Set up Windows LDAP integration"
echo ""
echo "Credentials saved to: freeipa-credentials.txt"
echo ""
print_warning "IMPORTANT: Backup freeipa-credentials.txt securely!"
echo ""

