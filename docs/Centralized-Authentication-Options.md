# Centralized Authentication & PKI Options Analysis

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 17, 2025  
**Version:** 1.0

---

## Executive Summary

This document analyzes centralized authentication and PKI infrastructure options for the Azure Free Tier Datacenter. It evaluates solutions based on cost (free tier compliance), complexity, security, and enterprise readiness.

## Current Authentication Model

**Current State:**
- Linux servers: SSH key-based authentication
- Windows servers: Local user accounts
- Guacamole: Local user database
- **Limitations:** No centralized identity management, manual user provisioning, no unified access control

## Centralized Authentication Options

### Option 1: Azure Active Directory (Azure AD) - **RECOMMENDED for Cloud-First**

**Description:**  
Integrate all servers with Azure AD for centralized identity management.

**Implementation:**
- Linux: Azure AD authentication via `aad-auth` module
- Windows: Azure AD Domain Join
- Guacamole: Azure AD SAML integration
- MFA support built-in

**Pros:**
- ✅ **FREE** - Azure AD Free tier included with subscription
- ✅ Cloud-native, no additional infrastructure
- ✅ Modern authentication (OAuth 2.0, SAML)
- ✅ Built-in MFA and Conditional Access
- ✅ Integrates with Microsoft ecosystem
- ✅ Automatic sync with O365 if used
- ✅ No additional VM required

**Cons:**
- ⚠️ Requires internet connectivity for authentication
- ⚠️ Learning curve if unfamiliar with Azure AD
- ⚠️ Limited Linux integration (improving)

**Free Tier Impact:** ✅ **NONE** - Stays within free tier

**Complexity:** 🟡 **MODERATE** (2-3 hours setup)

**Recommendation:** ⭐ **Best for cloud-first organizations**

---

### Option 2: FreeIPA - **RECOMMENDED for Enterprise Simulation**

**Description:**  
Open-source identity management solution providing LDAP, Kerberos, DNS, and integrated PKI.

**Implementation:**
- Deploy FreeIPA server on existing Linux VM (vm-linuxapp or dedicated)
- Linux clients: Integrate via SSSD
- Windows clients: Integrate as AD trust or LDAP
- Includes Certificate Authority (PKI)

**Pros:**
- ✅ **FREE** - Open source
- ✅ Enterprise-grade authentication
- ✅ Integrated PKI (no separate CA needed)
- ✅ LDAP + Kerberos + DNS + CA in one solution
- ✅ Web-based management interface
- ✅ Excellent Linux integration via SSSD
- ✅ Role-based access control (RBAC)
- ✅ Service accounts and keytabs

**Cons:**
- ⚠️ Requires dedicated VM or resource sharing
- ⚠️ More complex than Azure AD
- ⚠️ Windows integration requires additional configuration
- ⚠️ On-premises only (no cloud sync)

**Free Tier Impact:** ⚠️ **MINIMAL** - Can run on existing B1s VM, but may need to monitor resources

**Complexity:** 🔴 **HIGH** (4-6 hours setup)

**Recommendation:** ⭐ **Best for learning enterprise identity management**

---

### Option 3: Active Directory + SSSD - **TRADITIONAL ENTERPRISE**

**Description:**  
Windows Active Directory Domain Services with Linux integration via SSSD.

**Implementation:**
- Promote Windows Server to Domain Controller
- Linux clients: Domain-join via SSSD + Realmd
- Native Windows integration

**Pros:**
- ✅ Industry standard for enterprises
- ✅ Best Windows integration
- ✅ Familiar to most IT professionals
- ✅ Group Policy for Windows management
- ✅ Native LDAP and Kerberos

**Cons:**
- ❌ **NOT FREE TIER FRIENDLY** - AD requires more resources
- ❌ Windows Server 2022 has higher resource requirements
- ❌ Standard_B1s may struggle with AD DS
- ⚠️ Would need to upgrade VM size (cost increase)
- ⚠️ Linux integration more complex than native solutions
- ⚠️ Separate PKI setup required (AD CS)

**Free Tier Impact:** ❌ **SIGNIFICANT** - Likely requires larger VM size

**Complexity:** 🟡 **MODERATE** (3-4 hours if familiar with AD)

**Recommendation:** ⚠️ **NOT RECOMMENDED** for free tier (cost implications)

---

### Option 4: OpenLDAP + SSSD - **LIGHTWEIGHT**

**Description:**  
Basic LDAP directory service for centralized authentication.

**Implementation:**
- OpenLDAP server on Linux VM
- Linux clients: SSSD + LDAP
- Windows clients: LDAP authentication (limited)

**Pros:**
- ✅ **FREE** and lightweight
- ✅ Low resource usage
- ✅ Simple directory service
- ✅ Well-documented
- ✅ Good Linux integration

**Cons:**
- ⚠️ No integrated PKI
- ⚠️ No Kerberos (less secure)
- ⚠️ No web UI (command-line management)
- ⚠️ Limited Windows integration
- ⚠️ Manual certificate management

**Free Tier Impact:** ✅ **NONE**

**Complexity:** 🟢 **LOW** (2-3 hours)

**Recommendation:** 🔵 **Good for simple LDAP needs**

---

### Option 5: Keycloak - **MODERN IAM**

**Description:**  
Modern Identity and Access Management with OAuth 2.0, OpenID Connect, SAML support.

**Implementation:**
- Keycloak server (Docker on bastion or dedicated VM)
- Applications: OAuth/OIDC integration
- Guacamole: SAML/OIDC integration

**Pros:**
- ✅ **FREE** and open source
- ✅ Modern protocols (OAuth 2.0, OIDC)
- ✅ Excellent web application integration
- ✅ Built-in user federation (LDAP, AD)
- ✅ Social login support
- ✅ Web-based admin console

**Cons:**
- ⚠️ Requires Java/Docker
- ⚠️ Better for web apps than OS-level auth
- ⚠️ Linux/Windows OS integration requires additional work
- ⚠️ Not designed for traditional SSH/RDP auth

**Free Tier Impact:** ✅ **MINIMAL** - Can run in Docker on bastion

**Complexity:** 🟡 **MODERATE** (3-4 hours)

**Recommendation:** 🔵 **Good for web application SSO**

---

## PKI (Public Key Infrastructure) Analysis

### Do You Need a PKI Server?

**Use Cases for PKI:**
1. **Internal service certificates** (HTTPS for Guacamole, internal APIs)
2. **Client certificate authentication** (mutual TLS)
3. **Code signing** (if developing applications)
4. **Email encryption** (S/MIME)
5. **VPN certificates** (if adding VPN)

**For Your 4-Server Environment:**

[Professional Assessment] A **dedicated PKI server is likely OVERKILL** for this scale. Here are better alternatives:

### PKI Option 1: Azure Key Vault Certificates - **RECOMMENDED**

**Description:** Use Azure Key Vault as your certificate authority.

**Pros:**
- ✅ Already part of your infrastructure
- ✅ Integration with Azure services
- ✅ Automatic renewal support
- ✅ Secure storage and rotation
- ✅ API-based certificate management

**Cons:**
- ⚠️ Limited to Azure ecosystem
- ⚠️ Cost for certificate operations (minimal at this scale)

**Free Tier Impact:** ⚠️ **MINIMAL** - First 10 certificate operations/month free

**Recommendation:** ⭐ **Best for Azure-native certificates**

---

### PKI Option 2: Let's Encrypt - **FOR PUBLIC CERTIFICATES**

**Description:** Free, automated certificate authority for public-facing services.

**Pros:**
- ✅ **COMPLETELY FREE**
- ✅ Automated renewal (Certbot)
- ✅ Widely trusted
- ✅ Perfect for Guacamole HTTPS

**Cons:**
- ⚠️ Only for public-facing services
- ⚠️ Requires domain name
- ⚠️ Not suitable for internal certificates

**Recommendation:** ⭐ **Best for external HTTPS**

---

### PKI Option 3: FreeIPA Integrated PKI

**Description:** FreeIPA includes Dogtag Certificate System.

**Pros:**
- ✅ Integrated with authentication
- ✅ Automatic certificate management
- ✅ Host and service certificates
- ✅ Certificate-based authentication

**Cons:**
- ⚠️ Only worth it if implementing FreeIPA for authentication

**Recommendation:** ⭐ **Best if using FreeIPA for auth**

---

### PKI Option 4: Simple Self-Signed CA

**Description:** Create your own CA with OpenSSL.

**Pros:**
- ✅ **FREE** and simple
- ✅ Full control
- ✅ Good for learning PKI concepts

**Cons:**
- ⚠️ Manual certificate management
- ⚠️ Not trusted by browsers (need to import CA)
- ⚠️ No automation

**Recommendation:** 🔵 **Good for learning/testing**

---

## Recommendation Matrix

| Scenario | Authentication | PKI Solution |
|----------|----------------|--------------|
| **Cloud-first, simple** | Azure AD | Azure Key Vault + Let's Encrypt |
| **Learning enterprise** | FreeIPA | FreeIPA Integrated PKI |
| **Minimal complexity** | OpenLDAP | Let's Encrypt + Self-signed |
| **Web apps only** | Keycloak | Let's Encrypt |
| **Traditional enterprise (NOT free tier)** | Active Directory | AD Certificate Services |

---

## My Recommendation for Your Environment

Based on your 4-server Azure Free Tier environment, I recommend:

### **Primary Recommendation: Azure AD + Let's Encrypt**

**Why:**
1. ✅ **Zero additional infrastructure** - No extra VMs needed
2. ✅ **Free tier compliant** - No cost increases
3. ✅ **Cloud-native** - Fits Azure ecosystem
4. ✅ **Modern** - Industry direction
5. ✅ **Lower complexity** - Easier to maintain
6. ✅ **MFA included** - Better security

**Implementation Plan:**
1. Configure Azure AD authentication for Linux VMs
2. Domain-join Windows Server to Azure AD
3. Configure Guacamole with Azure AD SAML
4. Use Let's Encrypt for Guacamole HTTPS
5. Use Azure Key Vault for internal certificates

**Time to Implement:** ~3-4 hours  
**Additional Cost:** $0

---

### **Alternative: FreeIPA (If Learning Enterprise IAM)**

**Why:**
1. ✅ **Complete enterprise identity solution**
2. ✅ **Great for learning** LDAP, Kerberos, PKI
3. ✅ **All-in-one** - Auth + PKI included
4. ✅ **Free and open source**

**Considerations:**
- May need to monitor resource usage on B1s VMs
- More complex to set up and maintain
- Better for enterprise simulation/learning

**Implementation Plan:**
1. Install FreeIPA server on vm-linuxapp
2. Enroll all Linux servers as clients
3. Configure Windows for LDAP authentication
4. Use FreeIPA PKI for internal certificates
5. Use Let's Encrypt for external access

**Time to Implement:** ~6-8 hours  
**Additional Cost:** $0 (uses existing resources)

---

## Implementation Availability

Would you like me to:

1. ✅ **Implement Azure AD authentication** (recommended, simpler)
2. ✅ **Implement FreeIPA** (more complex, enterprise learning)
3. ✅ **Create documentation only** (for manual implementation)
4. ✅ **Do nothing** (current SSH key model is acceptable for dev/test)

I can create Ansible playbooks and deployment scripts for either option.

---

## Conclusion

**For Free Tier Datacenter:**
- [Unverified] Active Directory is **NOT recommended** due to resource requirements
- Azure AD is the **most practical** solution for this environment
- FreeIPA is the **best learning** solution if you want enterprise IAM experience
- A **dedicated PKI server is not necessary** at this scale
- Let's Encrypt + Azure Key Vault provides adequate certificate management

**My Professional Opinion:**  
Start with **Azure AD + Let's Encrypt**. It's simpler, free, and aligns with modern cloud architecture. If you later need more complex enterprise features, you can migrate to FreeIPA without losing your work.

---

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Project:** Azure Free Tier Datacenter  
**License:** MIT  
**Last Updated:** October 17, 2025

