# Ansible Multi-Distribution Server Automation

## Project Overview

This Ansible project automates Debian 13 and Arch Linux server provisioning with a security-first approach. Uses 1Password integration for secrets management and encrypted inventory/vault files. The architecture follows role-based organization with clear separation between sensitive and non-sensitive configuration.

**Key Design Decision**: No bootstrap playbook - deploy user setup is done manually as documented in README.md. This ensures proper SSH key setup and sudo access before Ansible runs.

**Distribution Support**: Supports both Debian-based and Arch Linux systems through group-based inventory organization with shared common configuration and distribution-specific overrides.

**Current Roles**: system-basics, packages, user-management, motd-config, mail-config, unattended-upgrades, tailscale, docker, ssh-hardening

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

**Role Implementation**: **Modernized Architecture** - All current roles follow the `include_tasks: "{{ ansible_os_family }}.yml"` pattern for distribution-specific logic. Each role's `main.yml` handles common tasks and includes OS-specific task files (`Debian.yml`, `Archlinux.yml`) as needed.

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

### SSH Security Hardening

```bash
# Harden SSH for production-ready servers (run AFTER site.yml)
ansible-playbook playbooks/ssh-hardening.yml --limit hostname

# Dry run to review changes first (RECOMMENDED)
ansible-playbook playbooks/ssh-hardening.yml --check --diff --limit hostname

# Harden multiple servers
ansible-playbook playbooks/ssh-hardening.yml --limit "server1,server2,server3"

# Emergency: restore SSH config from backup
# ssh root@hostname  # Use Tailscale SSH or console access
# cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
# systemctl restart ssh  # or sshd on Arch
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

### Debian Version Management

```bash
# Check current Debian versions across all servers
ansible-playbook playbooks/debian-version-check.yml

# Upgrade specific server to Trixie (Debian 13)
ansible-playbook playbooks/debian-upgrade.yml --limit hostname --check  # Dry run first
ansible-playbook playbooks/debian-upgrade.yml --limit hostname          # Actual upgrade

# Upgrade all Debian servers that need it (use with caution)
ansible-playbook playbooks/debian-upgrade.yml --check  # Review changes first
ansible-playbook playbooks/debian-upgrade.yml          # Actual upgrade
```

**Version Management Best Practices**:

- Always run version check first to identify servers needing updates
- Use `--check` mode to preview changes before actual upgrades
- Upgrade one server at a time (playbook uses `serial: 1` for safety)
- Test on `longshot` (test VM) before production servers
- Ensure backups and console access before major upgrades
- All roles now use dynamic variables (`ansible_distribution_release`) instead of hardcoded versions

## Variable Architecture

### Sensitive (Encrypted in vault.yml)

- `vault_hostname`: Server hostname (host-specific in host_vars/)
- `vault_target_user`: Human user account (the actual person using the machine)
- `vault_deploy_user`: Deployment user for Ansible automation (usually "deploy")
- `vault_smtp_host`: SMTP server with port
- `vault_notification_email`: Admin email address
- `vault_discord_url`: Discord webhook URL for mailrise notifications (host-specific in host_vars/)
- `vault_user_ssh_key`: SSH public key for the human user account (optional)
- `vault_tailscale_auth_key`: Tailscale authentication key for network setup (optional)

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
- `tailscale_config.enabled`: Boolean to enable Tailscale setup (default: false)

**Distribution-specific variables** (defined in `group_vars/{distribution}/config.yml`):

- `package_manager`: "apt" (Debian) or "pacman" (Arch)
- `motd_path`: Distribution-specific MOTD directory
- `core_packages`: Distribution-specific packages (merged with common_packages)
- `user_groups`: ["sudo"] (Debian) or ["wheel"] (Arch)

## Role-Specific Implementation Notes

### system-basics

- **Modernized architecture**: Uses `include_tasks: "{{ ansible_os_family }}.yml"` pattern
- **Common tasks**: Hostname setting via `hostname` module, UTF-8 locales via `locale-gen`, timezone via `timezone` module
- **Distribution-specific**: Package cache updates (apt/pacman) in separate `Debian.yml`/`Archlinux.yml` files

### packages  

- **Simplified architecture**: Uses generic `package` module (auto-detects apt/pacman)
- **Package management**: Combines `common_packages` (shared) + `core_packages` (distribution-specific)
- **Two-step process**: Cache update first, then package installation

### motd-config

- **Role-based separation**: Uses distribution-specific task files (`Debian.yml`, `Archlinux.yml`)
- **Debian approach**: Deploys numbered scripts to `/etc/update-motd.d/` (01-logo → 10-uname → 15-diskspace → 20-docker → 30-security-updates → 92-unattended-upgrades)
- **Arch approach**: Creates single dynamic MOTD script in `/etc/profile.d/motd.sh`
- **Conditional deployment**: Uses `motd_config.enable_*` flags for each script component (default: true)
- **Static files**: 01-logo, 10-uname, 20-docker, 30-security-updates, 92-unattended-upgrades
- **Templates**: 15-diskspace.j2 (Debian), motd.sh.j2 (Arch)
- **File locations**: roles/motd-config/files/ and roles/motd-config/templates/

### mail-config

- **Role-based separation**: Uses distribution-specific task files (`Debian.yml`, `Archlinux.yml`) plus shared `mailrise-common.yml`
- **Debian**: Installs and configures ssmtp + apt-listchanges integration
- **Arch**: Installs and configures msmtp
- **Common**: Mailrise Docker container setup for Discord notifications (when enabled)
- Uses host-specific Discord webhook URLs from vault variables

### unattended-upgrades

- **Consolidated role**: Handles both Debian unattended-upgrades and Arch auto-updates (merged from former arch-auto-updates role)
- **Role-based separation**: Uses distribution-specific task files (`Debian.yml`, `Archlinux.yml`)
- **Debian**: apt unattended-upgrades package with configuration templates
- **Arch**: Custom systemd timer + pacman upgrade script
- **Template organization**: `templates/debian/` and `templates/arch/` subdirectories
- **Common configuration**: Uses `auto_reboot_config.*` variables for reboot settings

### user-management

- **Role-based separation**: Uses `common-users.yml` for shared logic plus distribution-specific task files
- **Common tasks**: User creation, shell setup, fisher installation
- **Distribution-specific**: Deploy user group assignment (sudo vs wheel)
- **Variable-driven**: Uses `user_groups` from group_vars instead of hardcoded conditions

### tailscale

- **Role-based separation**: Uses distribution-specific task files (`Debian.yml`, `Archlinux.yml`)
- **Conditional deployment**: Only runs when `tailscale_config.enabled` is true (default: false)
- **Debian approach**: Adds official Tailscale repository with GPG key verification, installs from official repo
- **Arch approach**: Installs from standard pacman repositories
- **Common configuration**: Enables tailscaled service, configures network with auth key, enables SSH access
- **Security**: Uses vault variable `vault_tailscale_auth_key` for authentication
- **Features**: Auto-accepts routes, enables Tailscale SSH for secure remote access

### ssh-hardening

- **Role-based separation**: Uses distribution-specific task files (`Debian.yml`, `Archlinux.yml`)
- **Security focus**: Separate playbook for production-ready servers with proven SSH key access
- **SSH configuration**: Disables password authentication, root login, forces public key only
- **Safety features**: Validates existing SSH key access before applying hardening, backs up config files
- **Distribution-specific**: Handles different SSH service names (`ssh` vs `sshd`) and restart procedures
- **Tailscale compatibility**: Preserves Tailscale SSH functionality (operates independently of OpenSSH)
- **Emergency recovery**: Creates timestamped backups for manual restoration if needed

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
4. **Role updates**: All roles follow the modernized `include_tasks: "{{ ansible_os_family }}.yml"` pattern. Create new distribution-specific task files (e.g., `Ubuntu.yml`) for each role.
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

## LLM-Shared Integration & Development Guidelines

This project follows the `llm-shared` submodule standards:

- **Shell tools**: Use modern alternatives (`rg` instead of `grep`, `fd` instead of `find`)
- **Git hooks**: Located in `scripts/hooks/` (enabled via `git config core.hooksPath scripts/hooks`)
- **Development workflow**: Feature branches preferred over direct main commits
- **Project guidelines**: See `llm-shared/project_tech_stack.md` for universal practices

**AI Assistant Guidelines**:

- Use `rg` for searching instead of `grep` or `find`
- Follow the modernized role architecture pattern (`include_tasks: "{{ ansible_os_family }}.yml"`)
- Always test changes with `--check --diff` before real deployment
- Use generic `package` module instead of distribution-specific ones where possible

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
- `roles/*/tasks/main.yml` - Role orchestration and distribution dispatch
- `roles/*/tasks/Debian.yml` - Debian-specific tasks (all roles)
- `roles/*/tasks/Archlinux.yml` - Arch-specific tasks (all roles)  
- `roles/*/tasks/common-*.yml` - Shared task files (mail-config, user-management)
- `roles/motd-config/files/` - Static MOTD scripts  
- `roles/motd-config/templates/` - Jinja2 MOTD templates
- `roles/unattended-upgrades/templates/debian/` - Debian-specific templates
- `roles/unattended-upgrades/templates/arch/` - Arch-specific templates

### Encryption Workflow

- **Before editing**: Files auto-decrypt via ansible.cfg password scripts
- **After changes**: Run `./scripts/encrypt-vault-files.sh` to bulk encrypt
- **Check status**: `./scripts/encrypt-vault-files.sh --dry-run`
- Always use the `longshot` server for testing, it's a virtual machine with no permanent data
- Always use the current debian stable version for Debian servers - Current codename is trixie as of September 2025
- Never use `ansible-vault edit` to modify vault files. Use `ansible-vault decrypt` instead
