# Ansible Debian Server Automation

## Project Overview

This Ansible project automates the complete setup of Debian 13 servers with a focus on security, user management, and system configuration. It follows standard Ansible role-based architecture and uses Ansible Vault for secure management of sensitive configuration data.

## Project Structure

```plain
ansible/
├── ansible.cfg                     # Ansible configuration with vault settings
├── .env.example                   # Legacy environment variable template
├── .gitignore                     # Excludes sensitive files including vault files
├── inventory/
│   ├── production.example         # Inventory template
│   └── group_vars/
│       └── debian_servers/
│           ├── main.yml           # Main configuration (references vault)
│           ├── config.yml         # Non-sensitive configuration
│           ├── vault.yml          # Encrypted sensitive data (Ansible Vault)
│           └── vault.yml.example  # Template for vault variables
├── roles/                         # Role-based organization
│   ├── system-basics/             # Hostname, locale, timezone
│   ├── packages/                  # Core packages and tools
│   ├── motd-config/               # Message of the Day configuration
│   ├── user-management/           # User setup and shell config
│   ├── mail-config/               # SSMTP configuration
│   └── unattended-upgrades/       # Security update automation
├── playbooks/
│   ├── site.yml                  # Complete server setup
│   └── bootstrap.yml             # Minimal initial setup
└── templates/                    # Legacy template location
```

## Setup Instructions

### 1. Vault Configuration (Recommended - Secure)

**Set up Ansible Vault password:**

```bash
# Create vault password file (change the password!)
echo "your_secure_vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
```

**Create and configure vault file:**

```bash
# Copy vault template
cp inventory/group_vars/debian_servers/vault.yml.example inventory/group_vars/debian_servers/vault.yml

# Edit vault file with your sensitive settings
ansible-vault edit inventory/group_vars/debian_servers/vault.yml
```

**Set your sensitive variables in the vault:**

```yaml
---
# System Configuration
vault_hostname: your-server-hostname
vault_target_user: your-deployment-user

# Mail Configuration  
vault_smtp_host: your-smtp-server:587
vault_notification_email: your-admin@example.com
```

**Configure non-sensitive settings:**

Edit `inventory/group_vars/debian_servers/config.yml` for timezone, packages, etc.

### 2. Inventory Setup

```bash
# Copy inventory template
cp inventory/production.example inventory/production
```

Edit `inventory/production` to add your servers:

```ini
[debian_servers]
prod-web ansible_host=192.168.1.10 ansible_user=deploy
prod-db ansible_host=192.168.1.11 ansible_user=deploy
```

### 3. Legacy Environment Variable Setup (Alternative)

For development or if you prefer environment variables:

```bash
cp .env.example .env
# Edit .env with your settings
set -a; source .env; set +a
```

## Configuration

### Variable Organization (Sensitive vs Non-Sensitive)

**Sensitive Variables (Vault-encrypted in `vault.yml`):**

| Variable | Description | Security Level |
|----------|-------------|----------------|
| `vault_hostname` | Server hostname | Sensitive |
| `vault_target_user` | Deployment user | Sensitive |
| `vault_smtp_host` | SMTP server details | Sensitive |
| `vault_notification_email` | Admin email address | Sensitive |

**Non-Sensitive Variables (Plain text in `config.yml`):**

| Variable | Default | Description |
|----------|---------|-------------|
| `timezone` | Europe/Helsinki | Server timezone |
| `locales` | en_US.UTF-8, en_GB.UTF-8 | System locales |
| `core_packages` | [fish, tmux, etc.] | Packages to install |
| `user_shell` | /usr/bin/fish | Default shell |
| `user_groups` | [sudo, docker] | User groups |
| `mail_config.use_tls` | false | Use TLS for SMTP |
| `mail_config.use_starttls` | false | Use STARTTLS for SMTP |
| `unattended_upgrades.automatic_reboot` | true | Allow automatic reboots |
| `unattended_upgrades.automatic_reboot_time` | 02:00 | Scheduled reboot time |
| `motd_config.enable_welcome` | true | Enable MOTD welcome message |
| `motd_config.enable_sysinfo` | true | Enable system information display |
| `motd_config.enable_security_updates` | true | Enable security update notifications |
| `motd_config.enable_footer` | true | Enable MOTD footer |
| `motd_config.check_security_updates` | true | Check for security updates |
| `motd_config.welcome_message` | "" | Additional welcome message (optional) |
| `motd_config.footer_message` | "" | Custom footer message (optional) |

### Vault Management

**Common vault operations:**

```bash
# View vault contents
ansible-vault view inventory/group_vars/debian_servers/vault.yml

# Edit vault contents
ansible-vault edit inventory/group_vars/debian_servers/vault.yml

# Change vault password
ansible-vault rekey inventory/group_vars/debian_servers/vault.yml

# Decrypt vault (for backup/migration)
ansible-vault decrypt inventory/group_vars/debian_servers/vault.yml
```

## Usage Commands

**Complete server setup:**

```bash
ansible-playbook playbooks/site.yml --ask-become-pass
```

**Dry run (check mode):**

```bash
ansible-playbook playbooks/site.yml --check --diff --ask-become-pass
```

**Target specific hosts:**

```bash
ansible-playbook playbooks/site.yml --limit prod-web --ask-become-pass
```

**Using environment variables (legacy):**

```bash
set -a; source .env; set +a
ansible-playbook playbooks/site.yml --ask-become-pass
```

## Security Notes

### Vault-Based Security (Default)

- **All sensitive data encrypted** with Ansible Vault (AES256)
- **Vault password stored securely** in `~/.ansible_vault_pass` (mode 600)
- **Sensitive vs non-sensitive separation** - clear distinction between vault and config files
- **Git-safe by default** - vault files are encrypted, password file excluded
- **Template files provided** for easy setup without exposing secrets

### Security Best Practices

```bash
# Use strong vault password
openssl rand -base64 32 > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Regularly rotate vault password
ansible-vault rekey inventory/group_vars/debian_servers/vault.yml

# Backup vault files (encrypted state)
cp inventory/group_vars/debian_servers/vault.yml backups/
```

### Legacy Environment Variable Safety

For development environments using `.env`:
- Environment files excluded from git
- Template files provided for setup
- No credentials in repository

## Role Responsibilities

### system-basics

- Sets hostname via systemd using `vault_hostname` (system-basics/tasks/main.yml:2-4)
- Configures /etc/hosts entry (system-basics/tasks/main.yml:6-11)
- Generates UTF-8 locales from `locales` config (system-basics/tasks/main.yml:13-17)
- Sets timezone from `timezone` config (system-basics/tasks/main.yml:19-28)

### packages  

- Installs core packages from `core_packages` config (packages/tasks/main.yml:2-5)
- Detects ARM architecture to skip Starship (packages/tasks/main.yml:7-9)
- Installs Starship prompt on x86_64 systems (packages/tasks/main.yml:11-17)

### motd-config

- Removes default `/etc/motd` to prevent conflicts (motd-config/tasks/main.yml:2-5)
- Preserves existing custom MOTD scripts (01-logo, 10-uname, 15-diskspace, 20-docker, 92-unattended-upgrades)
- Deploys complementary MOTD scripts with proper naming conventions (motd-config/tasks/main.yml:8-42)
- Scripts: 05-welcome (hostname welcome), 11-sysinfo (load/memory/users), 30-security-updates (security alerts), 95-footer (management info)
- Uses `motd_config` variables for customization and conditional deployment

### user-management

- Adds user to sudo/docker groups (user-management/tasks/main.yml:8-12)
- Uses `vault_target_user` for user management (user-management/tasks/main.yml:14-17)
- Installs fisher plugin manager (user-management/tasks/main.yml:19-24)

### mail-config

- Configures SSMTP with `vault_smtp_host` (mail-config/templates/ssmtp.conf.j2:21)
- Fixes apt-listchanges to use SSMTP (mail-config/tasks/main.yml:11-25)
- Sets up mail notifications using `vault_notification_email`

### unattended-upgrades

- Automated security updates with email notifications
- Uses `vault_notification_email` and config variables for timing
- Targets Debian security/updates repositories

## Development Workflow

### Adding New Servers

1. Manually create `deploy` user on new server (see README)
2. Add entries to `inventory/production` with `ansible_user=deploy`
3. Create `host_vars/[hostname]/vault.yml` with `vault_hostname`
4. Test connection: `ansible debian_servers -m ping`
5. Run setup: `ansible-playbook playbooks/site.yml --limit hostname --check`

### Adding New Configuration

**For sensitive data:**
1. Add variables to `inventory/group_vars/debian_servers/vault.yml`
2. Use `ansible-vault edit` to modify securely
3. Reference with `{{ vault_variable_name }}` in main.yml

**For non-sensitive data:**
1. Add variables to `inventory/group_vars/debian_servers/config.yml`
2. Reference directly in main.yml
3. Document new variables in this README

**Legacy approach:**
1. Use `lookup('env', 'VAR_NAME') | default('fallback')` pattern
2. Update `.env.example` with new variables

### Testing Changes

```bash
# Always test in check mode first
ansible-playbook playbooks/site.yml --check --diff

# Test on single host
ansible-playbook playbooks/site.yml --limit hostname --check

# Full deployment after testing
ansible-playbook playbooks/site.yml --ask-become-pass
```
