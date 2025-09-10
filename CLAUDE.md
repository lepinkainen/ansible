# Ansible Debian Server Automation

## Project Overview

This Ansible project automates Debian 13 server provisioning with a security-first approach. Uses 1Password integration for secrets management and encrypted inventory/vault files. The architecture follows role-based organization with clear separation between sensitive and non-sensitive configuration.

**Key Design Decision**: No bootstrap playbook - deploy user setup is done manually as documented in README.md. This ensures proper SSH key setup and sudo access before Ansible runs.

## Critical Architecture Details

### 1Password Integration (Key Differentiator)

- **Vault password**: `scripts/get-vault-password.sh` retrieves from `op://Development/Ansible Vault/password`
- **Deploy password**: `scripts/get-deploy-password.sh` retrieves from `op://Development/Ansible Deploy user/password`
- **No manual password files**: Everything automated via 1Password CLI
- **ansible.cfg** already configured with password scripts

### Security-First File Structure

```plain
inventory/
├── production.yml              # ENCRYPTED (YAML format, not INI)
├── group_vars/debian_servers/
│   ├── main.yml               # References vault variables
│   ├── config.yml             # Non-sensitive config
│   └── vault.yml              # ENCRYPTED sensitive data
└── host_vars/[hostname]/
    └── vault.yml              # ENCRYPTED host-specific secrets
```

**Critical**: All `vault.yml` files and `production.yml` MUST be encrypted with `ansible-vault`.

### Git Security Hooks

- **Pre-commit hook**: `scripts/hooks/pre-commit` prevents unencrypted sensitive files
- **Enabled via**: `git config core.hooksPath scripts/hooks` (already configured)
- **Auto-detects**: `**/vault.yml` and `inventory/production.yml` files

## Essential Commands

### Daily Operations

```bash
# Complete server setup (passwords from 1Password automatically)
ansible-playbook playbooks/site.yml

# Target specific server
ansible-playbook playbooks/site.yml --limit longshot

# Dry run with diff
ansible-playbook playbooks/site.yml --check --diff --limit hostname
```

### Vault Management

```bash
# Edit encrypted files (uses ansible.cfg password script)
ansible-vault edit inventory/production.yml
ansible-vault edit inventory/group_vars/debian_servers/vault.yml
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

- `timezone`: Server timezone (default: Europe/Helsinki)
- `core_packages`: List of packages to install
- `user_shell`: Default shell (/usr/bin/fish)
- `motd_config.*`: MOTD customization options
- `unattended_upgrades.*`: Update timing and behavior

## Role-Specific Implementation Notes

### system-basics

- Uses `systemd-hostnamed` for hostname setting (system-basics/tasks/main.yml:2-4)
- Configures UTF-8 locales via `locale-gen` (system-basics/tasks/main.yml:13-17)

### packages  

- Installs core packages including starship prompt via apt package manager

### motd-config

- **Ansible-managed MOTD scripts**: Deploys numbered scripts to complement system defaults
- **Script sequence**: 01-logo → 10-uname → 15-diskspace → 20-docker → 30-security-updates → 92-unattended-upgrades
- **Conditional deployment**: Uses `motd_config.enable_*` flags for each script component
- **Static files**: 01-logo, 10-uname, 20-docker, 30-security-updates, 92-unattended-upgrades
- **Templates**: 15-diskspace.j2 (uses `disk_usage_locations` variable)

### mail-config

- Installs and configures ssmtp to send mail to localhost:8025
- Installs and configures mailrise systemd service for Discord notifications
- Configures apt-listchanges to use ssmtp for package change notifications
- Uses host-specific Discord webhook URLs from vault variables

## Development Workflow

### Adding New Servers

1. **Manual setup**: Create `deploy` user with sudo access (see README.md)
2. **Inventory**: Add to encrypted `inventory/production.yml`
3. **Host vars**: Create `host_vars/hostname/vault.yml` with `vault_hostname` and `vault_discord_url`
4. **Test**: `ansible hostname -m ping`
5. **Deploy**: `ansible-playbook playbooks/site.yml --limit hostname --check`

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
6. **MOTD script ordering**: Complement existing numbered scripts, don't replace

- Use `scripts/encrypt-vault-files.sh` to encrypt all vault files
- When working with vault files, decrypt them first
