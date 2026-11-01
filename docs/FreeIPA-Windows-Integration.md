## FreeIPA Windows Server Integration

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 17, 2025  
**Version:** 1.0  
**Branch:** freeipa-authentication

---

## Overview

This guide configures Windows Server 2022 to authenticate against FreeIPA using LDAP. Users can log in to Windows with their FreeIPA credentials.

## Prerequisites

- FreeIPA server installed and running
- Windows Server 2022 deployed
- Network connectivity between Windows and FreeIPA server
- FreeIPA CA certificate

## Part 1: Prepare FreeIPA Server

### Step 1: Create Windows-Compatible Users

On the FreeIPA server or any enrolled client:

```bash
# Get Kerberos ticket
kinit admin

# Create user with Windows-compatible attributes
ipa user-add wuser --first=Windows --last=User \
  --password-expiration="2099-12-31 23:59:59Z" \
  --shell=/bin/bash

# Set initial password (user will be prompted to change)
ipa passwd wuser

# Add to Windows access group
ipa group-add windows-users --desc="Windows Server Access"
ipa group-add-member windows-users --users=wuser
```

### Step 2: Export CA Certificate

```bash
# Download CA certificate
curl -k https://your-freeipa-server/ipa/config/ca.crt -o freeipa-ca.crt

# Copy to Windows server
scp freeipa-ca.crt azureuser@windows-server-ip:C:\\Temp\\
```

---

## Part 2: Configure Windows Server

### Step 1: Install CA Certificate

On Windows Server:

```powershell
# Import FreeIPA CA certificate to Trusted Root
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$cert.Import("C:\Temp\freeipa-ca.crt")

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    "Root","LocalMachine")
$store.Open("ReadWrite")
$store.Add($cert)
$store.Close()

Write-Host "FreeIPA CA certificate installed" -ForegroundColor Green
```

### Step 2: Configure LDAP Authentication

```powershell
# Install RSAT AD DS Tools
Install-WindowsFeature RSAT-AD-Tools

# Configure LDAP provider
$ldapServer = "10.10.3.4"  # Your FreeIPA server IP
$baseDN = "dc=datacenter,dc=local"
$bindDN = "uid=admin,cn=users,cn=accounts,dc=datacenter,dc=local"
$bindPassword = "your-admin-password"

# Test LDAP connectivity
$ldapTest = [ADSI]"LDAP://$ldapServer/$baseDN"
$ldapTest.Path
```

### Step 3: Configure LSA (Local Security Authority)

Download and install **pGina** (open-source LDAP authentication plugin for Windows):

```powershell
# Download pGina
Invoke-WebRequest -Uri "https://github.com/pgina/pgina/releases/latest/download/pGina-setup.exe" `
  -OutFile "C:\Temp\pGina-setup.exe"

# Install silently
Start-Process "C:\Temp\pGina-setup.exe" -ArgumentList "/S" -Wait

Write-Host "pGina installed - Configure via pGina Configuration Tool" -ForegroundColor Yellow
```

### Step 4: Configure pGina LDAP Plugin

1. Launch **pGina Configuration** from Start Menu

2. Navigate to **Plugin Selection** tab
   - Enable: **LDAP Authentication**
   - Enable: **LDAP Authorization**
   - Enable: **Local Machine**

3. Configure **LDAP Authentication**:
   - **LDAP Host**: `10.10.3.4` (FreeIPA server)
   - **LDAP Port**: `636` (LDAPS) or `389` (LDAP)
   - **Use SSL**: ✓ (recommended)
   - **Base DN**: `cn=users,cn=accounts,dc=datacenter,dc=local`
   - **Search DN**: `uid=admin,cn=users,cn=accounts,dc=datacenter,dc=local`
   - **Search Password**: (FreeIPA admin password)
   - **Search Filter**: `(uid=%u)`

4. Configure **LDAP Authorization**:
   - **Authorization Rule**: `memberOf=cn=windows-users,cn=groups,cn=accounts,dc=datacenter,dc=local`

5. Click **Apply** and **Save**

### Step 5: Test Authentication

```powershell
# Test LDAP bind
$username = "wuser"
$password = "user-password"

$ldap = New-Object DirectoryServices.DirectoryEntry(
    "LDAP://$ldapServer/$baseDN",
    "uid=$username,cn=users,cn=accounts,$baseDN",
    $password
)

try {
    $ldap.RefreshCache()
    Write-Host "Authentication successful!" -ForegroundColor Green
} catch {
    Write-Host "Authentication failed: $_" -ForegroundColor Red
}
```

---

## Part 3: Alternative - Active Directory Trust (Advanced)

[Unverified] FreeIPA can establish a trust with Active Directory if you have an AD domain, but this requires additional AD infrastructure which breaks free tier compliance.

### When to Use AD Trust:
- Existing Active Directory domain
- Need seamless Windows integration
- Willing to pay for additional AD infrastructure

### Setup:
```bash
# On FreeIPA server
ipa-adtrust-install --netbios-name=DATACENTER
```

---

## Part 4: LDAP-Based RDP Access

### Create LDAP Group for RDP Access

On FreeIPA:

```bash
ipa group-add rdp-users --desc="RDP Access to Windows Servers"
ipa group-add-member rdp-users --users=wuser
```

### Configure Windows Local Groups

On Windows Server:

```powershell
# Add LDAP users to Remote Desktop Users group
# This requires pGina or third-party LDAP integration
# Users authenticated via pGina will have access based on pGina authorization rules
```

---

## Part 5: Advanced Configuration

### Password Synchronization

Configure FreeIPA to allow password changes from Windows:

```bash
# On FreeIPA server
ipa pwpolicy-mod --lockouttime=5
```

### Kerberos Integration (Optional)

Windows can use FreeIPA for Kerberos authentication:

1. Copy `/etc/krb5.conf` from FreeIPA server to Windows: `C:\Windows\krb5.ini`

2. Modify krb5.ini for Windows:
```ini
[libdefaults]
    default_realm = DATACENTER.LOCAL
    dns_lookup_realm = false
    dns_lookup_kdc = true

[realms]
    DATACENTER.LOCAL = {
        kdc = 10.10.3.4
        admin_server = 10.10.3.4
    }

[domain_realm]
    .datacenter.local = DATACENTER.LOCAL
    datacenter.local = DATACENTER.LOCAL
```

3. Test Kerberos:
```powershell
# Install MIT Kerberos for Windows
# Then test:
kinit wuser@DATACENTER.LOCAL
klist
```

---

## Troubleshooting

### LDAP Connection Fails

```powershell
# Test LDAP connectivity
Test-NetConnection -ComputerName 10.10.3.4 -Port 389
Test-NetConnection -ComputerName 10.10.3.4 -Port 636

# Test with ldp.exe (Windows LDAP client)
ldp.exe
# Connection > Connect > 10.10.3.4:389
# Connection > Bind > Enter credentials
```

### Certificate Errors

```powershell
# Verify CA certificate is installed
Get-ChildItem Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "*IPA*"}

# Re-import if needed
certutil -addstore "Root" "C:\Temp\freeipa-ca.crt"
```

### pGina Not Working

```powershell
# Check pGina service
Get-Service pgina

# View pGina logs
Get-Content "C:\Program Files\pGina\log\pGina.log" -Tail 50

# Test pGina in simulation mode
# Launch pGina Configuration > Simulation tab
```

### User Cannot Log In

1. Verify user exists in FreeIPA:
```bash
ipa user-show wuser
```

2. Check group membership:
```bash
ipa group-show windows-users
```

3. Test LDAP query from Windows:
```powershell
$searcher = New-Object DirectoryServices.DirectorySearcher
$searcher.SearchRoot = "LDAP://10.10.3.4/cn=users,cn=accounts,dc=datacenter,dc=local"
$searcher.Filter = "(uid=wuser)"
$result = $searcher.FindOne()
$result.Properties
```

---

## Limitations

1. **No Group Policy**: LDAP auth doesn't provide GPO support
   - Consider using local group policies
   - Or use third-party tools for central policy management

2. **No Windows Domain Features**: This is LDAP authentication only
   - No domain trusts
   - No domain-level features
   - Best for simple authentication scenarios

3. **Third-Party Tools**: pGina or similar required
   - Native Windows LDAP auth is limited
   - Commercial alternatives: Centrify, Powerbroker

---

## Alternative Solutions

### Option 1: Azure AD Join (Recommended for Cloud)
See master branch for Azure AD integration (simpler, cloud-native)

### Option 2: Samba AD (FreeIPA Alternative)
- FreeIPA + Samba provides fuller Windows integration
- More complex setup
- Better for Windows-heavy environments

### Option 3: OpenLDAP + pGina
- Simpler than FreeIPA
- Less features but easier Windows integration

---

## References

- [FreeIPA Documentation](https://www.freeipa.org/page/Documentation)
- [pGina LDAP Plugin](https://github.com/pgina/pgina/wiki/LDAP-Plugin-Documentation)
- [Windows LDAP Client](https://docs.microsoft.com/windows/win32/ad/lightweight-directory-access-protocol-ldap-api)

---

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Project:** Azure Free Tier Datacenter  
**Branch:** freeipa-authentication  
**License:** MIT

