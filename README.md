# Azure-Free-Tier-Datacenter

Bash scripts (Azure CLI) and Ansible playbooks that build a small, segmented "datacenter" in Azure using free-tier-sized VMs: a Linux bastion with Apache Guacamole, a Windows web server, a Linux proxy and a Linux application server, with Key Vault, Azure Files, Azure SQL, alerts, Entra ID sign-in and optional FreeIPA. It is a sandbox for practising hybrid administration on a small budget.

## What it builds

Run in order, each script adds a layer and records names and IPs in `.azure-config` for the next one:

| Script | Creates |
|---|---|
| `scripts/01-deploy-foundation.sh` | Resource group, VNet with five subnets, Key Vault, storage account with an Azure Files share and private endpoint |
| `scripts/02-deploy-security.sh` | NSGs for the subnets and their rules |
| `scripts/03-deploy-vms.sh` | Four `Standard_B1s` VMs in parallel: `vm-bastion` (Ubuntu 22.04, the only public IP), `vm-winweb` (Windows Server 2022), `vm-linuxproxy` and `vm-linuxapp` (Ubuntu 22.04), all with managed identities and Key Vault read access. The Windows password goes to Key Vault |
| `scripts/04-deploy-services.sh` | Azure SQL server and a Basic-tier database, an action group, and CPU/DTU alerts for every VM and the database |
| `scripts/05-configure-azure-ad.sh` | Entra ID SSH sign-in (`AADSSHLoginForLinux`) on the Linux VMs and the *Virtual Machine Administrator Login* role |
| `scripts/06-configure-freeipa.sh` | Optional FreeIPA server on `vm-linuxapp` for central Linux identity |
| `scripts/07-configure-log-analytics.sh` | Log Analytics workspace and monitoring agents on the VMs |
| `scripts/deploy-dashboard.sh` | Azure Monitor dashboard from `templates/azure-monitor-dashboard.json` |

On the bastion:

- **Guacamole** (`docker/guacamole-compose.yml`, `docker/guacamole-setup.sh`) for browser-based RDP and SSH to the private VMs
- **Ansible** (`ansible/`) for configuration: system updates, mounting the Azure Files share (`/mnt/shared` on Linux, `Z:` on Windows), server configuration, monitoring agents, Entra ID sign-in on Linux and Windows, and FreeIPA server and clients
- **Maintenance**: `scripts/setup-cron.sh` schedules `master-update.yml` monthly (second Tuesday, 22:00); `scripts/backup-config.sh` copies configuration files to Azure Files

`scripts/azure-keyvault-helper.sh` reads and writes secrets; `scripts/cleanup.sh` deletes the resource group.

## Requirements

- An Azure subscription and the Azure CLI, signed in (`az login`)
- Bash, OpenSSL and an SSH key at `~/.ssh/id_rsa.pub`
- On the bastion, for configuration: Ansible with the collections in `ansible/requirements.yml` (`ansible-galaxy collection install -r ansible/requirements.yml`) and Docker for Guacamole

## Quick start

```bash
git clone https://github.com/adrian207/Azure-Free-Tier-Datacenter.git
cd Azure-Free-Tier-Datacenter

./scripts/01-deploy-foundation.sh
./scripts/02-deploy-security.sh
./scripts/03-deploy-vms.sh          # prompts for the Windows admin password
./scripts/04-deploy-services.sh
./scripts/05-configure-azure-ad.sh
./scripts/07-configure-log-analytics.sh   # optional
cat vm-connection-info.txt
```

Then SSH to the bastion, copy the repository there, set up Guacamole and run the playbooks, for example:

```bash
cd ansible
ansible-playbook playbooks/master-update.yml
ansible-playbook playbooks/02-mount-azure-files.yml
```

[DEPLOY.md](DEPLOY.md) has the full sequence with timings. `tests/test-deployment.sh` checks a finished deployment and `tests/test-backup.sh` checks the backup script.

## Repository layout

```
scripts/        Deployment stages 01-07, helpers, maintenance; lib/common.sh has shared functions
ansible/        Inventory (hosts.ini, group_vars) and playbooks 01-08
docker/         Guacamole with PostgreSQL
templates/      Azure Monitor dashboard
tests/          Deployment and backup checks
docs/           Specification, implementation, operations and onboarding guides; FreeIPA and SAML notes
```

## Cost

The Azure free account includes 750 hours a month of `B1s` VMs for the first 12 months for new customers ([Azure free account](https://azure.microsoft.com/en-us/free/virtual-machines)). That covers about one VM running all month; four running continuously use roughly four times that, so stop the VMs you aren't using. Azure SQL Basic, public IPs, the private endpoint, storage and Log Analytics ingestion may also be billed. Check current pricing for your region.

## Status and limitations

- The scripts and playbooks pass syntax checks (`bash -n`, shellcheck, `ansible-playbook --syntax-check`). `03-deploy-vms.sh` was tested against a stand-in for the Azure CLI, not a live subscription.
- `07-configure-log-analytics.sh` installs the Log Analytics agent (`MicrosoftMonitoringAgent` / `OmsAgentForLinux`), which Microsoft retired on 31 August 2024. Use the Azure Monitor Agent with a data collection rule for new deployments.
- `ansible/inventory/hosts.ini` lists fixed private IPs; check them against `vm-connection-info.txt` after deployment.
- A `B1s` VM has 1 GB of memory, which is tight for Windows Server and FreeIPA.

## License

MIT. See [LICENSE](LICENSE).

## Author

Adrian Johnson · [github.com/adrian207](https://github.com/adrian207)
