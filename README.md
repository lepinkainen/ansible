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
useradd -m -s /bin/bash -G sudo deploy
passwd deploy

# Set up SSH key for deploy user (from your local machine)
ssh-copy-id deploy@example.com

# Test deploy user access (from your local machine)
ssh deploy@example.com
sudo whoami  # Should return 'root'
```

On Arch linux, use `wheel` group instead of `sudo`.

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
- `vault_discord_url`: Discord webhook URL for mailrise notifications (host-specific in host_vars/)
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
- Configures mail delivery via ssmtp + mailrise for Discord notifications

## Docker Setup

Docker can be installed on servers using the dedicated Docker playbook:

```bash
# Install Docker on all servers
ansible-playbook playbooks/docker.yml

# Install Docker on specific servers
ansible-playbook playbooks/docker.yml --limit hostname
```

The Docker playbook will:

- Install Docker CE from Debian repositories
- Install Docker Compose
- Add the deploy user to the docker group
- Start and enable the Docker service

**Note**: After installation, users must log out and log back in for docker group membership to take effect.

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
