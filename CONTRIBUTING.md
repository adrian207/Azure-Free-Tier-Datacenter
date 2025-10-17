# Contributing to Azure Free Tier Datacenter

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Project:** Azure Free Tier Datacenter

Thank you for your interest in contributing to this project! This document provides guidelines and standards for contributions.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Standards](#development-standards)
- [Submission Guidelines](#submission-guidelines)
- [Contact](#contact)

## Code of Conduct

This project maintains professional standards:

- **Be respectful** and constructive in all communications
- **Focus on the technical merit** of contributions
- **Help others learn** - this is an educational project
- **Follow industry best practices** for security and Azure deployments

## How to Contribute

### Reporting Issues

When reporting issues, please include:

1. **Clear description** of the problem
2. **Steps to reproduce** the issue
3. **Expected vs actual behavior**
4. **Environment details** (Azure region, OS, Azure CLI version)
5. **Error messages or logs** (sanitized of sensitive data)

### Suggesting Enhancements

Enhancement suggestions should include:

1. **Use case** - Why is this enhancement needed?
2. **Proposed solution** - How should it work?
3. **Alternatives considered** - What other approaches did you consider?
4. **Impact assessment** - Does it affect free tier eligibility?

### Pull Requests

1. **Fork** the repository
2. **Create a feature branch** (`git checkout -b feature/YourFeature`)
3. **Make your changes** following coding standards below
4. **Test thoroughly** in your own Azure environment
5. **Commit** with clear, descriptive messages
6. **Push** to your fork
7. **Submit a pull request** with detailed description

## Development Standards

### Bash Scripts

All bash scripts must include:

```bash
#!/bin/bash
################################################################################
# Script Title
#
# Author: [Your Name] <your.email@example.com>
# Version: X.Y
# Date: YYYY-MM-DD
# Purpose: Brief description
#
# Copyright (c) YYYY [Your Name]
# Licensed under MIT License
################################################################################

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes
```

### Coding Standards

- **Error handling**: All scripts must include proper error handling
- **Progress indicators**: User-facing scripts should show progress
- **Documentation**: All functions/playbooks must be documented
- **Security**: Never commit secrets, credentials, or sensitive data
- **Free tier compliance**: Ensure changes don't exceed Azure free tier limits

### Ansible Playbooks

```yaml
---
################################################################################
# Ansible Playbook: Title
#
# Author: [Your Name] <your.email@example.com>
# Version: X.Y
# Date: YYYY-MM-DD
# Purpose: Brief description
#
# Copyright (c) YYYY [Your Name]
# Licensed under MIT License
################################################################################
```

### Testing Requirements

Before submitting:

1. **Syntax validation**: Validate all YAML, bash, and configuration files
2. **Dry runs**: Test Ansible playbooks with `--check` mode
3. **Cost verification**: Confirm changes stay within free tier
4. **Security review**: Verify no credentials or secrets are exposed
5. **Documentation**: Update README.md if functionality changes

## Submission Guidelines

### Commit Messages

Follow this format:

```
Brief summary (50 characters or less)

More detailed explanation if needed. Wrap at 72 characters.
- Use bullet points for multiple changes
- Reference issues with #issue-number

Author: Your Name <your.email@example.com>
```

### Pull Request Description

Include:

```markdown
## Description
[Clear description of changes]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Security enhancement

## Testing
[Describe testing performed]

## Azure Free Tier Impact
[Confirm no impact on free tier eligibility]

## Checklist
- [ ] My code follows the project style guidelines
- [ ] I have tested these changes in my Azure environment
- [ ] I have updated documentation as needed
- [ ] No secrets or credentials are included
- [ ] Changes maintain free tier compliance
```

## Project Structure

When adding files, follow this structure:

```
azure-free-tier-datacenter/
├── scripts/          # Deployment and utility scripts
├── ansible/          # Ansible configuration and playbooks
├── docker/           # Docker configurations
├── docs/             # Additional documentation
└── README.md         # Main project documentation
```

## Areas for Contribution

We welcome contributions in these areas:

### High Priority

- **Cost optimization**: Techniques to reduce Azure costs further
- **Security enhancements**: Additional hardening measures
- **Monitoring improvements**: Better observability and alerting
- **Documentation**: Tutorials, troubleshooting guides, diagrams

### Medium Priority

- **Additional services**: New Azure services within free tier
- **Automation**: Enhanced CI/CD pipelines
- **Testing**: Automated testing frameworks
- **Regional support**: Configurations for different Azure regions

### Nice to Have

- **Alternative clouds**: Adaptations for AWS/GCP free tiers
- **Terraform versions**: IaC using Terraform
- **Container orchestration**: Kubernetes deployment options

## Questions or Suggestions?

For questions or suggestions, please:

1. **Check existing issues** first
2. **Open a new issue** with detailed description
3. **Contact maintainer**: Adrian Johnson <adrian207@gmail.com>

## Recognition

Contributors will be recognized in:

- Project README.md
- Release notes
- Git commit history

Thank you for contributing to making Azure infrastructure more accessible!

---

**Project Maintainer:** Adrian Johnson <adrian207@gmail.com>  
**Repository:** https://github.com/adrian207/Azure-Free-Tier-Datacenter  
**License:** MIT

