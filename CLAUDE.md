# Ansible Debian Server Automation

## Project Overview

This Ansible project automates the complete setup of Debian 13 servers with a focus on security, user management, and system configuration. It follows standard Ansible role-based architecture and uses environment variables for sensitive configuration.

## Project Structure

```plain
ansible/
├── ansible.cfg                 # Ansible configuration
├── .env.example               # Environment variable template
├── .gitignore                 # Excludes sensitive files
├── inventory/
│   ├── production.example     # Inventory template
│   └── group_vars/
│       ├── debian_servers.yml           # Main configuration (uses env vars)
│       └── debian_servers.yml.example   # Configuration template
├── roles/                     # Role-based organization
│   ├── system-basics/         # Hostname, locale, timezone
│   ├── packages/              # Core packages and tools
│   ├── user-management/       # User setup and shell config
│   ├── mail-config/           # SSMTP configuration
│   └── unattended-upgrades/   # Security update automation
├── playbooks/
│   ├── site.yml              # Complete server setup
│   └── bootstrap.yml         # Minimal initial setup
└── templates/                # Legacy template location
```

## Setup Instructions

### 1. Environment Configuration

**Copy template files:**
```bash
cp .env.example .env
cp inventory/production.example inventory/production
```

**Edit `.env` with your settings:**
```bash
# Required variables
ANSIBLE_TIMEZONE=Europe/Helsinki
ANSIBLE_TARGET_USER=deploy
ANSIBLE_SMTP_HOST=mail.example.com:587
ANSIBLE_NOTIFICATION_EMAIL=admin@example.com

# Optional variables
ANSIBLE_SMTP_TLS=true
ANSIBLE_AUTO_REBOOT=false
ANSIBLE_REBOOT_TIME=03:00
```

**Load environment variables:**
```bash
# Option 1: Source the file
source .env

# Option 2: Use with export
set -a; source .env; set +a

# Option 3: Use direnv (recommended)
echo "source_env .env" > .envrc && direnv allow
```

### 2. Inventory Setup

Edit `inventory/production` to add your servers:
```ini
[debian_servers]
prod-web ansible_host=192.168.1.10 ansible_user=deploy
prod-db ansible_host=192.168.1.11 ansible_user=deploy
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ANSIBLE_TIMEZONE` | Europe/Helsinki | Server timezone |
| `ANSIBLE_TARGET_USER` | ansible_user | User for deployment |
| `ANSIBLE_SMTP_HOST` | localhost:8025 | SMTP server for mail |
| `ANSIBLE_SMTP_TLS` | false | Use TLS for SMTP |
| `ANSIBLE_SMTP_STARTTLS` | false | Use STARTTLS for SMTP |
| `ANSIBLE_NOTIFICATION_EMAIL` | root@localhost | Admin email address |
| `ANSIBLE_AUTO_REBOOT` | true | Allow automatic reboots |
| `ANSIBLE_REBOOT_TIME` | 02:00 | Scheduled reboot time |

### Static Configuration

Non-sensitive settings in `inventory/group_vars/debian_servers.yml`:
- Package lists
- User groups and shell preferences
- Locale settings

## Usage Commands

**Complete server setup:**
```bash
ansible-playbook playbooks/site.yml --ask-become-pass
```

**Bootstrap new servers:**
```bash
ansible-playbook playbooks/bootstrap.yml --ask-become-pass
```

**Dry run with environment variables:**
```bash
source .env
ansible-playbook playbooks/site.yml --check --diff --ask-become-pass
```

**Target specific hosts:**
```bash
ansible-playbook playbooks/site.yml --limit prod-web --ask-become-pass
```

## Security Notes

### Public Repository Safety
- All sensitive data externalized via environment variables
- Actual inventory files excluded from git
- Template files provided for easy setup
- No credentials or server details in repository

### For Production Use
```bash
# Use Ansible Vault for highly sensitive data
ansible-vault create group_vars/debian_servers/vault.yml

# Store vault password externally
echo "vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
```

## Role Responsibilities

### system-basics
- Sets hostname via systemd (system-basics/tasks/main.yml:2-4)
- Configures /etc/hosts entry (system-basics/tasks/main.yml:6-11)
- Generates UTF-8 locales (system-basics/tasks/main.yml:13-17)
- Sets timezone from `ANSIBLE_TIMEZONE` (system-basics/tasks/main.yml:19-28)

### packages  
- Installs core packages from variables (packages/tasks/main.yml:2-5)
- Detects ARM architecture to skip Starship (packages/tasks/main.yml:7-9)
- Installs Starship prompt on x86_64 systems (packages/tasks/main.yml:11-17)

### user-management
- Adds user to sudo/docker groups (user-management/tasks/main.yml:8-12)
- Uses `ANSIBLE_TARGET_USER` for user management (user-management/tasks/main.yml:14-17)
- Installs fisher plugin manager (user-management/tasks/main.yml:19-24)

### mail-config
- Configures SSMTP with `ANSIBLE_SMTP_HOST` (mail-config/templates/ssmtp.conf.j2:21)
- Fixes apt-listchanges to use SSMTP (mail-config/tasks/main.yml:11-25)
- Sets up mail notifications using `ANSIBLE_NOTIFICATION_EMAIL`

### unattended-upgrades
- Automated security updates with email notifications
- Uses `ANSIBLE_AUTO_REBOOT` and `ANSIBLE_REBOOT_TIME` variables
- Targets Debian security/updates repositories

## Development Workflow

### Adding New Servers
1. Add entries to `inventory/production` 
2. Test connection: `ansible debian_servers -m ping`
3. Run bootstrap: `ansible-playbook playbooks/bootstrap.yml --check`

### Adding New Configuration
1. Add variables to appropriate `group_vars` file
2. Use `lookup('env', 'VAR_NAME') | default('fallback')` pattern
3. Document new variables in this README
4. Update `.env.example` with new variables

### Testing Changes
```bash
# Always test in check mode first
ansible-playbook playbooks/site.yml --check --diff

# Test on single host
ansible-playbook playbooks/site.yml --limit hostname --check

# Full deployment after testing
ansible-playbook playbooks/site.yml --ask-become-pass
```