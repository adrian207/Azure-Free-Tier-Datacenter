# Azure Free Tier Datacenter

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Version:** 1.0  
**Last Updated:** October 17, 2025  
**License:** MIT

---

A complete, production-ready Azure datacenter environment designed to run entirely within the Azure free tier. Perfect for development, testing, learning, and small-scale production workloads.

## 🏗️ Architecture Overview

This deployment creates a secure, multi-server environment with:

- **4 Virtual Machines**: Bastion host, Windows web server, Linux proxy, Linux app server
- **Hub-and-Spoke Network**: Fully isolated VNet with 5 subnets
- **Azure SQL Database**: Standard tier for application data
- **Azure Key Vault**: Centralized secrets management
- **Azure Files**: Shared storage across all VMs
- **Azure Monitor**: Comprehensive monitoring and alerting
- **Apache Guacamole**: Web-based remote access to all servers
- **Ansible**: Automated configuration management and patching

### Network Topology

```
Internet
    │
    ├─── NSG (Restricted) ─── Bastion Host (10.10.1.0/24)
    │                            │ Apache Guacamole
    │                            │ Ansible Control Node
    │
    └─── VNet (10.10.0.0/16)
            │
            ├─── Management Subnet (10.10.1.0/24)
            ├─── Web Subnet (10.10.2.0/24)
            │      ├─── Windows Web Server
            │      └─── Linux Proxy Server
            ├─── App Subnet (10.10.3.0/24)
            │      └─── Linux App Server
            ├─── Database Subnet (10.10.4.0/24)
            │      └─── Azure SQL Database
            └─── Storage Subnet (10.10.5.0/24)
                   └─── Azure Files (Private Endpoint)
```

## 📋 Prerequisites

Before deploying, ensure you have:

1. **Azure Account** with an active subscription
2. **Azure CLI** installed and configured
   ```bash
   az --version
   az login
   ```
3. **SSH Key Pair** for Linux VM access
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   ```
4. **Permissions**: Contributor or Owner role on the subscription
5. **Public IP Address**: Your office/home IP for secure access

## 🚀 Quick Start Deployment

### Step 1: Clone and Setup

```bash
# Clone this repository
git clone <repository-url>
cd azure-free-tier-datacenter

# Make scripts executable
chmod +x scripts/*.sh
```

### Step 2: Deploy Foundation Resources

```bash
# Deploy Resource Group, VNet, Key Vault, Storage
./scripts/01-deploy-foundation.sh
```

This creates:
- Resource Group
- Virtual Network with 5 subnets
- Azure Key Vault
- Storage Account with Azure Files share
- Private endpoint for storage

### Step 3: Configure Security

```bash
# Deploy Network Security Groups
./scripts/02-deploy-security.sh
```

You'll be prompted for your public IP address. Find it at [whatismyipaddress.com](https://whatismyipaddress.com/)

### Step 4: Deploy Virtual Machines

```bash
# Deploy all 4 VMs
./scripts/03-deploy-vms.sh
```

This deploys:
- Bastion host (Ubuntu 22.04)
- Windows Server 2022 (web tier)
- Linux proxy server (Ubuntu 22.04)
- Linux app server (Ubuntu 22.04)

All VMs are configured with managed identities and Key Vault access.

### Step 5: Deploy Services

```bash
# Deploy SQL Database and Azure Monitor
./scripts/04-deploy-services.sh
```

This configures:
- Azure SQL Database (Basic tier)
- Azure Monitor with metric alerts
- Action groups for email notifications

### Step 6: Configure Bastion Host

SSH into the bastion host and set up Guacamole:

```bash
# Get bastion IP from vm-connection-info.txt
ssh azureuser@<BASTION_PUBLIC_IP>

# Transfer and run setup script
scp docker/guacamole-compose.yml azureuser@<BASTION_IP>:~/
scp docker/guacamole-setup.sh azureuser@<BASTION_IP>:~/
ssh azureuser@<BASTION_IP>

sudo bash guacamole-setup.sh
```

### Step 7: Configure Ansible

```bash
# Still on bastion host
cd ~
mkdir ansible
cd ansible

# Copy Ansible configuration
# Transfer files from local: ansible/ansible.cfg, inventory/, playbooks/

# Update inventory with actual IP addresses
vim inventory/hosts.ini

# Export environment variables from Key Vault
cd ~/scripts
./azure-keyvault-helper.sh export
source ~/.azure-env

# Run initial configuration
ansible-playbook playbooks/03-configure-servers.yml
ansible-playbook playbooks/02-mount-azure-files.yml
```

### Step 8: Setup Automated Maintenance

```bash
# On bastion host
./scripts/setup-cron.sh
```

This configures:
- Monthly OS patching (2nd Tuesday at 10 PM)
- Daily health checks (8 AM)
- Log rotation

## 📁 Project Structure

```
azure-free-tier-datacenter/
├── README.md                          # This file
├── .gitignore                         # Git ignore rules
│
├── scripts/                           # Deployment scripts
│   ├── 01-deploy-foundation.sh       # VNet, Key Vault, Storage
│   ├── 02-deploy-security.sh         # NSGs and firewall rules
│   ├── 03-deploy-vms.sh              # Virtual machines
│   ├── 04-deploy-services.sh         # SQL Database, monitoring
│   ├── setup-cron.sh                 # Automated maintenance
│   ├── backup-config.sh              # Configuration backup
│   ├── azure-keyvault-helper.sh      # Key Vault utilities
│   └── cleanup.sh                    # Decommission resources
│
├── docker/                            # Docker configurations
│   ├── guacamole-compose.yml         # Guacamole Docker Compose
│   └── guacamole-setup.sh            # Guacamole installation
│
├── ansible/                           # Ansible automation
│   ├── ansible.cfg                   # Ansible configuration
│   ├── inventory/                    # Inventory files
│   │   ├── hosts.ini                 # Host definitions
│   │   └── group_vars/
│   │       └── all.yml               # Global variables
│   └── playbooks/                    # Ansible playbooks
│       ├── 01-system-update.yml      # OS patching
│       ├── 02-mount-azure-files.yml  # Mount shared storage
│       ├── 03-configure-servers.yml  # Initial configuration
│       ├── 04-install-monitoring-agents.yml
│       └── master-update.yml         # Master maintenance playbook
│
└── docs/                              # Documentation
    ├── Azure Free Tier Data Center - Technical Specification.txt
    ├── Azure Sandbox - Implementation Guide.txt
    ├── Azure Sandbox - User Onboarding Guide.txt
    └── Azure Sandbox - Operations & Maintenance Manual.txt
```

## 🔐 Security Features

### Network Security
- **No direct internet access** to internal servers
- **NSG rules** restrict access to bastion from specific IP only
- **Private endpoints** for Azure services
- **Subnet isolation** with security groups

### Access Management
- **SSH key-only** authentication for Linux
- **Managed identities** for Azure service access
- **Azure Key Vault** for all secrets and credentials
- **Guacamole** for centralized, audited access

### Monitoring & Alerting
- **Azure Monitor** for all resources
- **Metric alerts** for CPU, memory, DTU
- **Email notifications** via Action Groups
- **Daily health checks** via cron

## 🛠️ Common Operations

### Access Servers via Guacamole

1. Navigate to: `http://<BASTION_PUBLIC_IP>:8080/guacamole`
2. Login with credentials (default: `guacadmin/guacadmin` - **change immediately!**)
3. Click on any server connection to access

### Run Manual System Updates

```bash
ssh azureuser@<BASTION_IP>
cd ~/ansible
ansible-playbook playbooks/master-update.yml
```

### Retrieve Secrets from Key Vault

```bash
# Using helper script
./scripts/azure-keyvault-helper.sh get sql-admin-password

# Using Azure CLI directly
az keyvault secret show --vault-name <VAULT_NAME> --name <SECRET_NAME> --query value -o tsv
```

### Create Configuration Backup

```bash
# On bastion host
./scripts/backup-config.sh
```

Backups are stored in Azure Files at `/mnt/shared/backups/`

### Check Resource Costs

```bash
# View current month costs
az consumption usage list --output table

# Set up budget alert
az consumption budget create \
  --budget-name "monthly-budget" \
  --amount 50 \
  --time-grain Monthly \
  --resource-group rg-datacenter-dev-westus2-001
```

### View Monitoring Alerts

```bash
# List all alerts
az monitor metrics alert list \
  --resource-group rg-datacenter-dev-westus2-001 \
  --output table

# Check alert status
az monitor metrics alert show \
  --name alert-bastion-high-cpu \
  --resource-group rg-datacenter-dev-westus2-001
```

## 📊 Resource Specifications

| Resource | Type | Size/Tier | Free Tier Eligible | Monthly Cost Estimate |
|----------|------|-----------|-------------------|----------------------|
| Resource Group | Management | N/A | ✅ Free | $0.00 |
| Virtual Network | Networking | N/A | ✅ Free | $0.00 |
| 4x VMs | Compute | Standard_B1s | ⚠️ 750hrs/month free | $0-15.00 |
| Azure SQL | Database | Basic (5 DTU) | ❌ Paid | ~$5.00 |
| Key Vault | Security | Standard | ⚠️ Limited free | $0-1.00 |
| Storage Account | Storage | Standard LRS | ⚠️ 5GB free | $0-2.00 |
| Azure Monitor | Monitoring | Basic metrics | ⚠️ Limited free | $0-3.00 |
| **TOTAL** | | | | **$5-26/month** |

> [Inference based on Azure pricing] Costs vary based on usage. With careful management, can run for ~$10-15/month.

## 🔧 Troubleshooting

### Cannot SSH to Bastion

1. Verify your IP is allowed in NSG:
   ```bash
   az network nsg rule list --resource-group rg-datacenter-dev-westus2-001 --nsg-name nsg-management --output table
   ```
2. Update NSG rule if IP changed:
   ```bash
   az network nsg rule update --resource-group rg-datacenter-dev-westus2-001 --nsg-name nsg-management --name AllowSSHFromOffice --source-address-prefixes <NEW_IP>
   ```

### Guacamole Not Accessible

```bash
# Check Docker container status
docker ps

# View logs
cd /opt/guacamole
docker-compose logs -f

# Restart services
docker-compose restart
```

### Azure Files Not Mounting

```bash
# Check if mounted
mountpoint /mnt/shared

# Remount manually
sudo mount -a

# Re-run Ansible playbook
cd ~/ansible
ansible-playbook playbooks/02-mount-azure-files.yml
```

### Ansible Playbook Fails

```bash
# Test connectivity
ansible all -m ping

# Run with verbose output
ansible-playbook playbooks/03-configure-servers.yml -vvv

# Check Windows WinRM connectivity
ansible windows_servers -m win_ping
```

## 🗑️ Decommissioning

To completely remove all resources and stop all billing:

```bash
# Run cleanup script
./scripts/cleanup.sh
```

This will:
1. Create a final backup (optional)
2. Stop all Docker containers
3. Delete the entire resource group
4. Stop all billing

**Warning**: This action is irreversible!

## 📚 Additional Resources

- [Azure Free Tier Documentation](https://azure.microsoft.com/free/)
- [Apache Guacamole Documentation](https://guacamole.apache.org/doc/gug/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)

## 🏗️ DNS Configuration

### Why Hosts.ini Instead of CoreDNS?

This project uses Ansible's inventory file (`hosts.ini`) with static IP addresses rather than a dedicated DNS server like CoreDNS. This decision is intentional and appropriate for this environment:

**Advantages of hosts.ini for this scale:**
- Azure VNet already provides automatic DNS resolution for VM hostnames
- Direct IP addressing in Ansible is simpler and more reliable for 4 servers
- No additional VM resources required for DNS infrastructure
- Easier troubleshooting and maintenance
- Zero DNS propagation delays

**When to consider CoreDNS:**
- Environments with 20+ servers requiring service discovery
- Microservices architectures with dynamic scaling
- Multi-region deployments requiring custom DNS resolution
- Kubernetes clusters (where CoreDNS is standard)

For this 4-server datacenter, the hosts.ini approach provides optimal simplicity and reliability.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

**Project Maintainer:** Adrian Johnson <adrian207@gmail.com>

## 📄 License

This project is provided under the MIT License.

Copyright (c) 2025 Adrian Johnson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## ⚠️ Disclaimer

[Unverified] This architecture is designed for development and testing environments. For production workloads, additional security hardening, backup strategies, high-availability configurations, and compliance controls should be implemented according to your organization's requirements.

---

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Repository:** https://github.com/adrian207/Azure-Free-Tier-Datacenter  
**Built with ❤️ for the Azure community**

