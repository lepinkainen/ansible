# Ansible Debian Server Automation

Quick setup guide for running the playbook on a clean Debian installation.

## Prerequisites

- Fresh Debian 13 installation with sudo access (see setup below if needed)
- 1Password CLI installed and authenticated
- Vault password stored in 1Password at `Development/Ansible Vault`

### Setting up deploy user and sudo access

Create a dedicated `deploy` user for Ansible operations:

```bash
# On the Debian server as root or existing sudo user
apt update && apt install sudo

# Create deploy user
/usr/sbin/adduser deploy
/usr/sbin/usermod -aG sudo deploy

# Set up SSH key for deploy user (from your local machine)
ssh-copy-id deploy@192.168.1.139

# Test deploy user access (from your local machine)
ssh deploy@192.168.1.139
sudo whoami  # Should return 'root'
```

## Setup Steps

### 1. Install Dependencies

```bash
sudo apt update
sudo apt install -y git ansible
```

### 2. Clone Repository

```bash
git clone https://github.com/lepinkainen/ansible.git
cd ansible
```

### 3. Setup 1Password CLI

```bash
# Install 1Password CLI (macOS)
brew install --cask 1password-cli

# Authenticate
op signin

# Store required passwords in 1Password:
# - Vault password at: Development/Ansible Vault/password
# - Deploy user password at: Development/Ansible Deploy user/password
# Then create vault from template
cp inventory/group_vars/debian_servers/vault.yml.example inventory/group_vars/debian_servers/vault.yml

# Edit vault with your settings
ansible-vault edit inventory/group_vars/debian_servers/vault.yml
```

Required vault variables:

- `vault_hostname`: Your desired server hostname (host-specific in host_vars/)
- `vault_target_user`: The user account to manage (usually `deploy`)
- `vault_smtp_host`: SMTP server (or localhost:8025 for testing)
- `vault_notification_email`: Your email address

### 4. Configure Inventory

```bash
# Edit the encrypted inventory file
ansible-vault edit inventory/production.yml
```

Add your servers:

```yaml
debian_servers:
  hosts:
    localhost:
      ansible_connection: local
```

The inventory file is encrypted with Ansible Vault for security.

### 5. Run Playbook

```bash
# Run complete server setup (passwords retrieved from 1Password automatically)
ansible-playbook playbooks/site.yml

# Or target specific servers
ansible-playbook playbooks/site.yml --limit longshot
```

Note: Passwords are automatically retrieved from 1Password - no need for `--ask-become-pass`!

## What It Does

- Sets hostname and timezone
- Installs essential packages (fish, tmux, htop, curl, etc.)
- Configures user with fish shell and sudo group
- Sets up automated security updates with email notifications
- Configures mail delivery via SSMTP

## Optional: Docker Setup

Docker is not installed by default. If you need Docker on specific servers, add to that server's host_vars:

```yaml
# inventory/host_vars/hostname/config.yml
user_groups:
  - sudo
  - docker
install_docker: true  # Future enhancement - will install Docker automatically
```

## Customization

Edit `inventory/group_vars/debian_servers/config.yml` to customize:

- Timezone and locales
- Package list
- User shell and groups
- Update timing

For sensitive changes, use:

```bash
# Edit vault variables
ansible-vault edit inventory/group_vars/debian_servers/vault.yml

# Edit inventory
ansible-vault edit inventory/production.yml
```

## Documentation

See [CLAUDE.md](CLAUDE.md) for detailed documentation and advanced usage.
