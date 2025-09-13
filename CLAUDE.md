# Ansible Multi-Distribution Server Automation

## Project Overview

This Ansible project automates Debian 13 and Arch Linux server provisioning with a security-first approach. Uses 1Password integration for secrets management and encrypted inventory/vault files. The architecture follows role-based organization with clear separation between sensitive and non-sensitive configuration.

**Key Design Decision**: No bootstrap playbook - deploy user setup is done manually as documented in README.md. This ensures proper SSH key setup and sudo access before Ansible runs.

**Distribution Support**: Supports both Debian-based and Arch Linux systems through group-based inventory organization with shared common configuration and distribution-specific overrides.

**Current Roles**: system-basics, packages, user-management, motd-config, mail-config, unattended-upgrades, arch-auto-updates, docker

## Critical Architecture Details

### 1Password Integration (Key Differentiator)

- **Vault password**: `scripts/get-vault-password.sh` retrieves from `op://Development/Ansible Vault/password`
- **Deploy password**: `scripts/get-deploy-password.sh` retrieves from `op://Development/Ansible Deploy user/password`
- **No manual password files**: Everything automated via 1Password CLI
- **ansible.cfg** already configured with password scripts

### Security-First File Structure with Multi-Distribution Support

```plain
inventory/
├── production.yml              # ENCRYPTED (YAML format, not INI)
├── group_vars/
│   ├── all/
│   │   └── config.yml         # Shared common configuration
│   ├── debian_servers/
│   │   ├── main.yml           # References vault variables + config merges
│   │   ├── config.yml         # Debian-specific config
│   │   └── vault.yml          # ENCRYPTED sensitive data
│   └── arch_servers/
│       ├── main.yml           # References vault variables + config merges
│       ├── config.yml         # Arch-specific config
│       └── vault.yml          # ENCRYPTED sensitive data
└── host_vars/[hostname]/
    ├── config.yml             # Host-specific non-sensitive config (optional)
    └── vault.yml              # ENCRYPTED host-specific secrets
```

**Critical**: All `vault.yml` files and `production.yml` MUST be encrypted with `ansible-vault`.

### Distribution-Specific Configuration Management

**Architecture Pattern**: Group-based inventory with variable layering for clean multi-distribution support.

**Variable Precedence** (Ansible's standard precedence applies):
1. `group_vars/all/config.yml` - Common configuration shared across all distributions
2. `group_vars/{distribution_group}/config.yml` - Distribution-specific overrides and additions  
3. `group_vars/{distribution_group}/main.yml` - Merges sensitive vault variables with config
4. `host_vars/{hostname}/config.yml` - Host-specific overrides (optional)

**Key Distribution Variables**:
- `package_manager`: "apt" (Debian) or "pacman" (Arch) 
- `motd_path`: "/etc/update-motd.d" (Debian) or "/etc/profile.d" (Arch)
- `user_groups`: ["sudo"] (Debian) or ["wheel"] (Arch)
- `common_packages`: Shared across distributions (defined in all/config.yml)
- `core_packages`: Distribution-specific packages (merged with common_packages in roles)

**Role Implementation**: Roles use `when: ansible_os_family == "..."` conditions and reference the standardized variables above for clean cross-distribution compatibility.

### Git Security Hooks

- **Pre-commit hook**: `scripts/hooks/pre-commit` prevents unencrypted sensitive files
- **Enabled via**: `git config core.hooksPath scripts/hooks` (already configured)
- **Auto-detects**: `**/vault.yml` and `inventory/production.yml` files

## Essential Commands

### Daily Operations

```bash
# Complete server setup (passwords from 1Password automatically)
ansible-playbook playbooks/site.yml

# Target specific distribution group  
ansible-playbook playbooks/site.yml --limit debian_servers
ansible-playbook playbooks/site.yml --limit arch_servers

# Target specific server
ansible-playbook playbooks/site.yml --limit hostname

# Dry run with diff
ansible-playbook playbooks/site.yml --check --diff --limit hostname
```

### Vault Management

```bash
# Edit encrypted files (uses ansible.cfg password script)
ansible-vault edit inventory/production.yml
ansible-vault edit inventory/group_vars/debian_servers/vault.yml
ansible-vault edit inventory/group_vars/arch_servers/vault.yml
ansible-vault edit inventory/host_vars/hostname/vault.yml

# Bulk encrypt all sensitive files
./scripts/encrypt-vault-files.sh

# Dry run to see what would be encrypted
./scripts/encrypt-vault-files.sh --dry-run
```

## Variable Architecture

### Sensitive (Encrypted in vault.yml)

- `vault_hostname`: Server hostname (host-specific in host_vars/)
- `vault_target_user`: Deployment user (usually "deploy")  
- `vault_smtp_host`: SMTP server with port
- `vault_notification_email`: Admin email address
- `vault_discord_url`: Discord webhook URL for mailrise notifications (host-specific in host_vars/)

### Non-Sensitive (Plain text in config.yml)

**Common variables** (defined in `group_vars/all/config.yml`):
- `timezone`: Server timezone (default: Europe/Helsinki)
- `locales`: System locales (default: en_US.UTF-8, en_GB.UTF-8)
- `common_packages`: Packages shared across all distributions
- `user_shell`: Default shell (/usr/bin/fish)
- `motd_config.*`: MOTD customization options
- `auto_reboot_config.*`: Common reboot settings
- `disk_usage_locations`: Array of mount points to monitor (default: ['/'])
- `mail_config.enable_mailrise`: Boolean to control mailrise service

**Distribution-specific variables** (defined in `group_vars/{distribution}/config.yml`):
- `package_manager`: "apt" (Debian) or "pacman" (Arch)
- `motd_path`: Distribution-specific MOTD directory
- `core_packages`: Distribution-specific packages (merged with common_packages)
- `user_groups`: ["sudo"] (Debian) or ["wheel"] (Arch)
- `unattended_upgrades.*` (Debian) or `auto_updates.*` (Arch): Distribution-specific update configuration

## Role-Specific Implementation Notes

### system-basics

- Uses `systemd-hostnamed` for hostname setting (system-basics/tasks/main.yml:2-4)
- Configures UTF-8 locales via `locale-gen` (system-basics/tasks/main.yml:13-17)

### packages  

- Installs packages using distribution-specific package managers (apt/pacman)
- Combines `common_packages` (shared) and `core_packages` (distribution-specific)
- Automatically handles distribution differences through inventory group variables

### motd-config

- **Ansible-managed MOTD scripts**: Deploys numbered scripts to complement system defaults (removes /etc/motd first)
- **Script sequence**: 01-logo → 10-uname → 15-diskspace → 20-docker → 30-security-updates → 92-unattended-upgrades
- **Conditional deployment**: Uses `motd_config.enable_*` flags for each script component (default: true)
- **Static files**: 01-logo, 10-uname, 20-docker, 30-security-updates, 92-unattended-upgrades
- **Templates**: 15-diskspace.j2 (uses `disk_usage_locations` variable, supports color-coded usage thresholds)
- **File locations**: roles/motd-config/files/ and roles/motd-config/templates/

### mail-config

- Installs and configures ssmtp to send mail to localhost:8025
- Installs and configures mailrise systemd service for Discord notifications
- Configures apt-listchanges to use ssmtp for package change notifications
- Uses host-specific Discord webhook URLs from vault variables

## Development Workflow

### Adding New Servers

1. **Manual setup**: Create `deploy` user with sudo/wheel access (see README.md)
2. **Inventory**: Add to encrypted `inventory/production.yml` under appropriate group (`debian_servers` or `arch_servers`)
3. **Host vars**: Create `host_vars/hostname/vault.yml` with `vault_hostname` and `vault_discord_url`
4. **Optional config**: Create `host_vars/hostname/config.yml` for host-specific non-sensitive config (e.g., `disk_usage_locations`, `mail_config.enable_mailrise`)
5. **Test**: `ansible hostname -m ping`
6. **Deploy**: `ansible-playbook playbooks/site.yml --limit hostname --check`

### Adding New Distributions

To add support for a new distribution (e.g., Ubuntu, RHEL):

1. **Inventory group**: Add new group to `inventory/production.yml`
2. **Group variables**: Create `inventory/group_vars/new_distro_servers/` with `config.yml`, `main.yml`, and `vault.yml`
3. **Distribution variables**: Define `package_manager`, `motd_path`, `user_groups`, and `core_packages` in the new config.yml
4. **Role updates**: Add `when: ansible_os_family == "..."` conditions to roles as needed
5. **Test thoroughly**: Use `--check --diff` to verify behavior before deployment

### Security Requirements

- **All vault files encrypted**: Use `./scripts/encrypt-vault-files.sh`
- **Git hooks active**: Prevents accidental commits of unencrypted secrets
- **1Password required**: Must have `op` CLI authenticated
- **Test encryption**: Pre-commit hook validates before each commit

### Testing Strategy

```bash
# Always check mode first
ansible-playbook playbooks/site.yml --check --diff --limit hostname

# Verify connectivity
ansible debian_servers -m ping

# Check vault file encryption status
./scripts/encrypt-vault-files.sh --dry-run
```

## LLM-Shared Integration

This project follows the `llm-shared` guidelines:

- **Git hooks**: Located in `scripts/hooks/` (enabled via core.hooksPath)
- **No direct main commits**: Use feature branches
- **Task-based workflow**: Use `task` command for builds (when applicable)

## Critical Gotchas

1. **No bootstrap playbook**: Deploy user setup is manual (see README.md)
2. **Inventory format**: Uses YAML (`production.yml`), not INI
3. **Password automation**: No `--ask-become-pass` needed with 1Password
4. **Encryption requirement**: ALL sensitive files must be vault-encrypted
5. **MOTD script ordering**: Complement existing numbered scripts, don't replace
6. **Host-specific configs**: Both vault.yml (encrypted) and config.yml (plain) can exist in host_vars/
7. **Docker group membership**: Users must log out/in after docker role runs for group changes to take effect

## Quick Reference

### Essential File Patterns

- `inventory/production.yml` - ENCRYPTED inventory (YAML format)
- `inventory/group_vars/all/config.yml` - Common shared configuration
- `inventory/group_vars/debian_servers/vault.yml` - ENCRYPTED Debian group secrets
- `inventory/group_vars/debian_servers/config.yml` - Debian-specific config
- `inventory/group_vars/arch_servers/vault.yml` - ENCRYPTED Arch group secrets  
- `inventory/group_vars/arch_servers/config.yml` - Arch-specific config
- `inventory/host_vars/hostname/vault.yml` - ENCRYPTED host secrets
- `inventory/host_vars/hostname/config.yml` - Host-specific config (optional)
- `roles/*/tasks/main.yml` - Role task definitions
- `roles/motd-config/files/` - Static MOTD scripts  
- `roles/motd-config/templates/` - Jinja2 MOTD templates

### Encryption Workflow

- **Before editing**: Files auto-decrypt via ansible.cfg password scripts
- **After changes**: Run `./scripts/encrypt-vault-files.sh` to bulk encrypt
- **Check status**: `./scripts/encrypt-vault-files.sh --dry-run`
