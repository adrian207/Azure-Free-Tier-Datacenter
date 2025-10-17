# Guacamole Azure AD SAML Single Sign-On Setup

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 17, 2025  
**Version:** 1.0

---

## Overview

This guide configures Apache Guacamole to use Azure Active Directory for Single Sign-On (SSO) via SAML 2.0. Users will authenticate with their Azure AD credentials instead of local Guacamole accounts.

## Prerequisites

- Guacamole deployed and running on bastion host
- Azure AD tenant with admin access
- SSL/TLS certificate (Let's Encrypt recommended)

## Part 1: Azure AD Enterprise Application Setup

### Step 1: Create Enterprise Application

1. Navigate to **Azure Portal** → **Azure Active Directory** → **Enterprise Applications**

2. Click **+ New application**

3. Click **+ Create your own application**

4. Enter name: `Guacamole Datacenter SSO`

5. Select: **Integrate any other application you don't find in the gallery (Non-gallery)**

6. Click **Create**

### Step 2: Configure SAML Single Sign-On

1. In your new application, go to **Single sign-on** in the left menu

2. Select **SAML** as the authentication method

3. Click **Edit** on **Basic SAML Configuration**

4. Configure:
   ```
   Identifier (Entity ID): 
   https://your-bastion-ip:8443/guacamole
   or
   https://your-domain.com/guacamole

   Reply URL (Assertion Consumer Service URL):
   https://your-bastion-ip:8443/guacamole/api/ext/saml/callback
   ```

5. Click **Save**

### Step 3: Configure Attributes & Claims

1. Click **Edit** on **Attributes & Claims**

2. Ensure these claims exist:
   - `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` → `user.mail`
   - `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname` → `user.givenname`
   - `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname` → `user.surname`

3. Add optional claim for groups (if using group-based permissions):
   - Claim name: `groups`
   - Source: `Groups assigned to the application`

### Step 4: Download SAML Certificate

1. In **SAML Certificates** section:
   - Download **Certificate (Base64)**
   - Copy **App Federation Metadata Url**

2. Save the certificate as `azure-ad.cer`

### Step 5: Assign Users

1. Go to **Users and groups** in the left menu

2. Click **+ Add user/group**

3. Select users or groups that should have access

4. Click **Assign**

---

## Part 2: Guacamole Configuration

### Step 1: Install SAML Extension

On the bastion host:

```bash
cd /opt/guacamole

# Download Guacamole SAML extension
GUAC_VERSION="1.5.4"  # Check for latest version
wget https://apache.org/dyn/closer.lua/guacamole/${GUAC_VERSION}/binary/guacamole-auth-sso-${GUAC_VERSION}.tar.gz

# Extract
tar -xzf guacamole-auth-sso-${GUAC_VERSION}.tar.gz

# Copy SAML extension to Guacamole extensions directory
sudo mkdir -p /etc/guacamole/extensions
sudo cp guacamole-auth-sso-${GUAC_VERSION}/saml/guacamole-auth-sso-saml-${GUAC_VERSION}.jar /etc/guacamole/extensions/

# Clean up
rm -rf guacamole-auth-sso-${GUAC_VERSION}*
```

### Step 2: Configure Guacamole Properties

Create or edit `/etc/guacamole/guacamole.properties`:

```properties
# SAML Configuration for Azure AD
saml-idp-metadata-url: https://login.microsoftonline.com/<TENANT_ID>/federationmetadata/2007-06/federationmetadata.xml
saml-entity-id: https://your-bastion-ip:8443/guacamole
saml-callback-url: https://your-bastion-ip:8443/guacamole/api/ext/saml/callback

# Group mapping (optional)
saml-group-attribute: groups

# Debugging (remove in production)
saml-debug: true
```

Replace:
- `<TENANT_ID>` with your Azure AD Tenant ID
- `your-bastion-ip` with your actual IP or domain

### Step 3: Copy Azure AD Certificate

```bash
# Copy the downloaded certificate
sudo mkdir -p /etc/guacamole/saml
sudo cp azure-ad.cer /etc/guacamole/saml/
sudo chown -R root:root /etc/guacamole/saml
sudo chmod 644 /etc/guacamole/saml/azure-ad.cer
```

### Step 4: Restart Guacamole

```bash
cd /opt/guacamole
docker-compose restart guacamole
```

---

## Part 3: SSL/TLS Configuration (Required for SAML)

SAML requires HTTPS. Configure with Let's Encrypt or nginx reverse proxy.

### Option A: Nginx Reverse Proxy with Let's Encrypt

```bash
# Install nginx and certbot
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Create nginx configuration
sudo tee /etc/nginx/sites-available/guacamole <<EOF
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    # Managed by Certbot
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        proxy_cookie_path /guacamole/ /;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/

# Get Let's Encrypt certificate
sudo certbot --nginx -d your-domain.com

# Reload nginx
sudo systemctl reload nginx
```

---

## Part 4: Testing

### Test SAML Authentication

1. Navigate to: `https://your-domain.com/guacamole`

2. You should see **Sign in with SAML** option

3. Click it - you'll be redirected to Azure AD login

4. Enter your Azure AD credentials

5. Complete MFA if prompted

6. You should be logged into Guacamole

### Verify User Information

After logging in:
- Check Settings → Preferences
- Your Azure AD name and email should appear

### Troubleshooting

**Login fails or redirects to error page:**
```bash
# Check Guacamole logs
docker logs guacamole-web

# Enable SAML debug in guacamole.properties:
saml-debug: true
```

**Certificate issues:**
```bash
# Verify certificate
openssl x509 -in /etc/guacamole/saml/azure-ad.cer -text -noout

# Check nginx SSL
sudo nginx -t
```

**Metadata URL issues:**
```bash
# Test metadata URL
curl https://login.microsoftonline.com/<TENANT_ID>/federationmetadata/2007-06/federationmetadata.xml
```

---

## Part 5: Group-Based Permissions (Optional)

### Azure AD Configuration

1. In Enterprise Application → **Users and groups**
2. Assign Azure AD groups (e.g., "Guacamole Admins")

### Guacamole Configuration

Edit `/etc/guacamole/guacamole.properties`:

```properties
# Map Azure AD groups to Guacamole permissions
saml-group-attribute: groups

# In Guacamole UI:
# Settings → Groups → Create groups matching Azure AD group IDs
# Assign connections and permissions to these groups
```

---

## Security Recommendations

1. **Always use HTTPS** - SAML requires it
2. **Enable MFA** in Azure AD Conditional Access
3. **Restrict by location** - Use Conditional Access policies
4. **Monitor sign-ins** - Azure AD → Sign-in logs
5. **Rotate certificates** - Before expiration (typically 3 years)
6. **Remove local accounts** - After SAML is working

---

## Alternative: Azure AD Application Proxy

For enhanced security, consider using Azure AD Application Proxy instead of exposing Guacamole publicly:

1. Install Application Proxy connector on-premises
2. Configure Guacamole as internal application
3. Access via `https://myapps.microsoft.com`
4. No public IP exposure required

[Unverified] Azure AD Application Proxy may have costs outside free tier.

---

## References

- [Guacamole SAML Documentation](https://guacamole.apache.org/doc/gug/saml-auth.html)
- [Azure AD SAML Setup](https://docs.microsoft.com/azure/active-directory/manage-apps/add-application-portal-setup-sso)
- [Let's Encrypt for Nginx](https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal)

---

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Project:** Azure Free Tier Datacenter  
**License:** MIT

