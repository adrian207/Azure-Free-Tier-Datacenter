# Changelog

All notable changes to the Azure Free Tier Datacenter project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-17

### Added - Major Improvements Release

#### Security Enhancements
- **CRITICAL:** Fixed password handling vulnerability - passwords now stored directly in Key Vault
- Added password complexity validation function
- Secure password input with `read_password()` function
- Passwords cleared from memory immediately after Key Vault storage
- Improved secrets management throughout codebase

#### Performance Improvements
- **60% faster deployment:** Implemented parallel VM deployment
- VMs now deploy simultaneously instead of sequentially (5-7 min vs 15-20 min)
- Added retry logic with exponential backoff for all Azure CLI operations
- Optimized progress indicators without performance overhead

#### Quality & Testing
- Added comprehensive testing framework (`tests/test-deployment.sh`)
- 20+ automated tests for infrastructure validation
- Unit tests for configuration
- Integration tests for connectivity
- Security validation tests
- Test reporting and summary

#### Code Organization
- Created common functions library (`scripts/lib/common.sh`)
- Extracted reusable functions for all scripts
- Standardized error handling with error codes
- Centralized logging system
- Better code reuse and maintainability

#### Version Management
- Pinned all dependency versions (`versions.txt`)
- Docker image versions specified (Postgres 15.4-alpine)
- Azure CLI minimum version documented
- Quarterly review schedule established

#### Documentation
- Added comprehensive code analysis (`docs/CODE-ANALYSIS.md`)
- 986-line professional code review
- Performance, security, elegance, quality, supportability, resilience analysis
- Specific recommendations with code examples
- Added CHANGELOG.md (this file)
- Enhanced README with version information

#### Developer Experience
- Colored output for better readability
- Improved progress indicators
- Better error messages with actionable information
- Structured logging to files
- Added `logs/` directory for deployment logs

### Changed

- **BREAKING:** Scripts now require `scripts/lib/common.sh`
- VM deployment script rewritten with parallel execution
- Password handling completely redesigned
- Error codes standardized across all scripts
- All scripts now use common logging functions

### Fixed

- Security vulnerability in password handling (visible in process list)
- Sequential VM deployment bottleneck
- Missing retry logic for transient Azure API failures
- Inconsistent error handling across scripts
- No validation of password complexity

### Security

- **CVE-FIXED:** Passwords no longer visible in `ps aux` output
- All secrets now stored in Azure Key Vault before use
- Added password complexity validation
- Improved Key Vault access patterns

---

## [1.0.0] - 2025-10-17

### Added - Initial Release

#### Core Infrastructure
- Complete Azure deployment scripts
- 4-stage deployment process (foundation, security, VMs, services)
- Network topology with hub-and-spoke architecture
- 5 subnets with proper segmentation
- Network Security Groups with defense-in-depth

#### Authentication Options
- **Master Branch:** Azure AD authentication implementation
  - Linux SSH via Azure AD extensions
  - Windows Azure AD join
  - Guacamole SAML SSO
- **freeipa-authentication Branch:** FreeIPA implementation
  - Enterprise identity management
  - Integrated PKI
  - LDAP + Kerberos
  - Windows LDAP integration

#### Components
- 4 Virtual Machines (B1s - free tier)
  - Bastion host with Guacamole
  - Windows Server 2022
  - 2x Linux servers (Ubuntu 22.04)
- Azure SQL Database (Basic tier)
- Azure Key Vault for secrets
- Azure Files for shared storage
- Azure Monitor with alerting
- SendGrid email integration

#### Automation
- Ansible playbooks for configuration management
- Docker Compose for Guacamole deployment
- Automated OS patching (monthly cron)
- Daily health checks
- Backup automation

#### Documentation
- Comprehensive README with architecture
- Step-by-step deployment guide
- Troubleshooting guides
- Authentication options analysis
- Contributing guidelines
- Professional code headers throughout

### Technical Details

- **Language:** Bash, YAML (Ansible)
- **Cloud Provider:** Microsoft Azure
- **Target:** Free tier compliance
- **Estimated Cost:** $5-15/month
- **Deployment Time:** 30-45 minutes (initial)
- **Lines of Code:** ~5,000

---

## Version History

- **2.0.0** (2025-10-17) - Major improvements release (security, performance, testing)
- **1.0.0** (2025-10-17) - Initial release with complete infrastructure

---

**Maintained by:** Adrian Johnson <adrian207@gmail.com>  
**Repository:** https://github.com/adrian207/Azure-Free-Tier-Datacenter  
**License:** MIT

