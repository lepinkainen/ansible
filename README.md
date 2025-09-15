# Ansible Multi-Distribution Server Automation

Quick setup guide for running playbooks on Debian 13 (Trixie) and Arch Linux servers.

## Prerequisites

- Fresh Debian 13 (Trixie) or Arch Linux installation with sudo access (see setup below if needed)
- 1Password CLI installed and authenticated
- Vault password stored in 1Password at `Development/Ansible Vault`

### Setting up deploy user and sudo access

Create a dedicated `deploy` user for Ansible operations:

**For Debian servers:**
```bash
# On the Debian server as root or existing sudo user
apt update && apt install sudo

# Create deploy user
useradd -m -s /bin/bash -G sudo deploy
passwd deploy

# Set up SSH key for deploy user (from your local machine)
ssh-copy-id deploy@example.com

# Test deploy user access (from your local machine)
ssh deploy@example.com
sudo whoami  # Should return 'root'
```

**For Arch Linux servers:**
```bash
# On the Arch server as root
pacman -Syu sudo

visudo  # Uncomment %wheel ALL=(ALL) ALL

useradd -m -s /bin/bash -G wheel deploy
passwd deploy

# Set up SSH key for deploy user (from your local machine)
ssh-copy-id deploy@example.com

# Test deploy user access (from your local machine)
ssh deploy@example.com
sudo whoami  # Should return 'root'
```

## Setup Steps

### 1. Install Dependencies

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install -y git ansible

# Arch Linux
sudo pacman -Syu git ansible

# macOS (for control machine)
brew install ansible
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
- `vault_discord_url`: Discord webhook URL for mailrise notifications (host-specific in host_vars/)
- `vault_notification_email`: Your email address

### 4. Configure Inventory

```bash
# Edit the encrypted inventory file
ansible-vault edit inventory/production.yml
```

Add your servers by distribution group:

```yaml
debian_servers:
  hosts:
    hostname1:
      ansible_host: 192.168.1.10
    hostname2:
      ansible_host: 192.168.1.11

arch_servers:
  hosts:
    hostname3:
      ansible_host: 192.168.1.20
```

The inventory file is encrypted with Ansible Vault for security.

### 5. Run Playbook

```bash
# Run complete server setup (passwords retrieved from 1Password automatically)
ansible-playbook playbooks/site.yml

# Target specific distribution groups
ansible-playbook playbooks/site.yml --limit debian_servers
ansible-playbook playbooks/site.yml --limit arch_servers

# Or target specific servers
ansible-playbook playbooks/site.yml --limit hostname
```

Note: Passwords are automatically retrieved from 1Password - no need for `--ask-become-pass`!

## What It Does

- Sets hostname and timezone
- Installs essential packages (fish, tmux, btop, curl, starship, etc.)
- Configures user with fish shell and appropriate sudo/wheel group
- Sets up automated security updates with email notifications
- Configures mail delivery (ssmtp/msmtp + mailrise for Discord notifications)
- Sets up MOTD with system information and update status
- Optional Tailscale network setup

## Additional Playbooks

### Docker Setup

```bash
# Install Docker on all servers
ansible-playbook playbooks/docker.yml

# Install Docker on specific servers
ansible-playbook playbooks/docker.yml --limit hostname
```

The Docker playbook installs Docker CE, Docker Compose, and adds users to the docker group.

**Note**: Users must log out and log back in for docker group membership to take effect.

### SSH Security Hardening

For production servers, apply SSH hardening after initial setup:

```bash
# Review changes first (recommended)
ansible-playbook playbooks/ssh-hardening.yml --check --diff --limit hostname

# Apply SSH hardening
ansible-playbook playbooks/ssh-hardening.yml --limit hostname
```

This disables password authentication and root login, forcing public key authentication only.

### Debian Version Management

```bash
# Check current Debian versions across all servers
ansible-playbook playbooks/debian-version-check.yml

# Upgrade specific server to Trixie (Debian 13)
ansible-playbook playbooks/debian-upgrade.yml --limit hostname --check  # Preview first
ansible-playbook playbooks/debian-upgrade.yml --limit hostname          # Actual upgrade
```

## Customization

Edit configuration files to customize settings:

- `inventory/group_vars/all/config.yml` - Common settings shared across all servers
- `inventory/group_vars/debian_servers/config.yml` - Debian-specific settings
- `inventory/group_vars/arch_servers/config.yml` - Arch Linux-specific settings
- `inventory/host_vars/hostname/config.yml` - Host-specific non-sensitive settings

Common customizations include:
- Timezone and locales
- Package lists (common and distribution-specific)
- User shell and groups
- MOTD and update timing

For sensitive changes, use:

```bash
# Edit vault variables for specific distribution groups
ansible-vault edit inventory/group_vars/debian_servers/vault.yml
ansible-vault edit inventory/group_vars/arch_servers/vault.yml

# Edit host-specific sensitive settings
ansible-vault edit inventory/host_vars/hostname/vault.yml

# Edit inventory
ansible-vault edit inventory/production.yml
```

## Documentation

See [CLAUDE.md](CLAUDE.md) for detailed documentation and advanced usage.
