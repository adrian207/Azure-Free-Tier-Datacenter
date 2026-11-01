# FreeIPA Authentication Branch

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Branch:** `freeipa-authentication`  
**Purpose:** Enterprise Identity Management with FreeIPA

---

## Branch Overview

This branch implements **Option B** from the authentication analysis: **FreeIPA-based centralized authentication**.

FreeIPA provides a complete enterprise identity management solution including:
- LDAP directory service
- Kerberos authentication
- Integrated DNS
- Certificate Authority (PKI)
- Web-based management UI
- Linux integration via SSSD
- Windows integration via LDAP

## When to Use This Branch

Choose this branch if you want to:
- 📚 **Learn enterprise identity management** concepts
- 🏢 **Simulate traditional enterprise** infrastructure
- 🔐 **Practice with Kerberos** and LDAP
- 📜 **Manage certificates** with integrated PKI
- 🎓 **Educational purposes** - understanding enterprise IAM

## When to Use Master Branch Instead

Use master branch (Azure AD) if you want:
- ☁️ Simpler, cloud-native authentication
- 💰 Zero additional infrastructure
- 🚀 Faster deployment (3-4 hours vs 6-8 hours)
- 🔄 Better Azure integration
- 🏃 Production-ready solution with less complexity

---

## What's Different in This Branch

### Added Files

**Ansible Playbooks:**
- `ansible/playbooks/07-install-freeipa-server.yml` - FreeIPA server installation
- `ansible/playbooks/08-enroll-freeipa-clients.yml` - Client enrollment

**Scripts:**
- `scripts/06-configure-freeipa.sh` - Automated FreeIPA setup

**Documentation:**
- `docs/FreeIPA-Windows-Integration.md` - Windows LDAP authentication guide

### Removed/Replaced

- Azure AD playbooks (`05-configure-azure-ad-*`) not present
- Azure AD scripts (`05-configure-azure-ad.sh`) not present
- Guacamole Azure AD SAML guide not relevant

---

## Deployment Instructions

### Prerequisites

- All VMs deployed (scripts 01-04 completed)
- Ansible configured on bastion host
- **Note:** FreeIPA requires ~2GB RAM; B1s VMs (1GB) may struggle

### Step 1: Install FreeIPA Server

```bash
cd ~/azure-free-tier-datacenter
./scripts/06-configure-freeipa.sh
```

This will:
1. Install FreeIPA server on `vm-linuxapp`
2. Configure domain: `datacenter.local`
3. Set up integrated DNS and PKI
4. Enroll all Linux clients
5. Save credentials to `freeipa-credentials.txt`

**Time:** ~30-45 minutes (includes installation and client enrollment)

### Step 2: Access Web UI

```bash
# Get server IP from output
https://<freeipa-server-ip>/ipa/ui

# Login:
Username: admin
Password: (from freeipa-credentials.txt)
```

### Step 3: Create Users

```bash
# SSH to any enrolled client
ssh azureuser@<bastion-ip>

# Get Kerberos ticket
kinit admin

# Create user
ipa user-add jdoe --first=John --last=Doe --password

# Add to group
ipa group-add developers
ipa group-add-member developers --users=jdoe
```

### Step 4: Configure Windows (Optional)

Follow: `docs/FreeIPA-Windows-Integration.md`

---

## Architecture

```
FreeIPA Server (vm-linuxapp)
    ├── LDAP Directory (port 389/636)
    ├── Kerberos KDC (port 88)
    ├── DNS Server (port 53)
    ├── Web UI (port 443)
    └── Certificate Authority
        
Enrolled Clients:
    ├── vm-bastion (Linux)
    ├── vm-linuxproxy (Linux)
    └── vm-linuxapp (Linux)
    
Windows Integration (optional):
    └── vm-winweb (via LDAP + pGina)
```

---

## Features

### ✅ What Works

- ✅ **Centralized user management**
- ✅ **Linux SSH authentication** via SSSD
- ✅ **Sudo access control** via FreeIPA sudo rules
- ✅ **Integrated PKI** - issue and manage certificates
- ✅ **Kerberos SSO** between enrolled servers
- ✅ **Web-based management** UI
- ✅ **Automatic home directory** creation
- ✅ **Password policies** and expiration
- ✅ **LDAP for Windows** (with pGina)

### ⚠️ Limitations

- ⚠️ **Resource intensive** - May strain B1s VMs
- ⚠️ **Windows integration complex** - Requires pGina or similar
- ⚠️ **No native AD features** - Not a full AD replacement
- ⚠️ **On-premises only** - No cloud sync like Azure AD
- ⚠️ **More maintenance** - Server needs backup and monitoring

---

## Common Operations

### Create New User

```bash
kinit admin
ipa user-add username --first=First --last=Last --password
```

### Grant Sudo Access

```bash
ipa sudorule-add admin-sudo
ipa sudorule-add-user --groups=admins admin-sudo  
ipa sudorule-add-allow-command --sudocmds=ALL admin-sudo
```

### Issue Certificate

```bash
# Generate CSR
openssl req -new -newkey rsa:2048 -nodes \
  -keyout server.key -out server.csr

# Request certificate from FreeIPA
ipa cert-request server.csr --principal=host/server.datacenter.local

# Retrieve certificate
ipa cert-show <serial-number> --out=server.crt
```

### Manage Groups

```bash
# Create group
ipa group-add developers --desc="Development Team"

# Add members
ipa group-add-member developers --users=user1,user2

# Nested groups
ipa group-add-member admins --groups=developers
```

---

## Troubleshooting

### FreeIPA Server Issues

```bash
# Check status
sudo ipactl status

# Restart services
sudo ipactl restart

# View logs
sudo journalctl -u ipa -f
```

### Client Authentication Fails

```bash
# Check SSSD
sudo systemctl status sssd
sudo tail -f /var/log/sssd/*.log

# Test Kerberos
kinit username@DATACENTER.LOCAL
klist

# Test LDAP
ldapsearch -x -H ldap://freeipa-server \
  -b "cn=users,cn=accounts,dc=datacenter,dc=local"
```

### Web UI Not Accessible

```bash
# Check firewall
sudo firewall-cmd --list-all

# Verify Apache
sudo systemctl status httpd

# Check certificates
sudo ipa-server-certinstall --check
```

---

## Comparison with Master Branch

| Feature | FreeIPA (This Branch) | Azure AD (Master) |
|---------|----------------------|-------------------|
| **Infrastructure** | Requires VM | Cloud-based, no VM |
| **Setup Time** | 6-8 hours | 3-4 hours |
| **Complexity** | High | Moderate |
| **Learning Value** | ⭐⭐⭐⭐⭐ Enterprise IAM | ⭐⭐⭐ Modern cloud auth |
| **Linux Integration** | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐ Good |
| **Windows Integration** | ⭐⭐ Requires pGina | ⭐⭐⭐⭐⭐ Native |
| **PKI** | ⭐⭐⭐⭐⭐ Integrated | ⭐⭐⭐ Key Vault |
| **Cost** | $0 (uses existing VM) | $0 |
| **Production Ready** | ⭐⭐⭐ Good for on-prem | ⭐⭐⭐⭐⭐ Excellent |

---

## Switching Back to Master

To switch back to Azure AD implementation:

```bash
git checkout master
```

No conflicts - branches are independent.

---

## Contributing

When contributing to this branch:
1. Keep FreeIPA-specific features separate from master
2. Document Windows integration workarounds
3. Note resource usage and B1s VM performance
4. Update this README with findings

---

## References

- [FreeIPA Official Documentation](https://www.freeipa.org/page/Documentation)
- [SSSD Documentation](https://sssd.io/)
- [Kerberos Documentation](https://web.mit.edu/kerberos/)
- [Dogtag PKI](https://www.dogtagpki.org/)

---

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Repository:** https://github.com/adrian207/Azure-Free-Tier-Datacenter  
**Main Branch:** [master](../../tree/master) - Azure AD implementation  
**This Branch:** freeipa-authentication - FreeIPA implementation  
**License:** MIT

