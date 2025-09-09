# Ansible Debian Server Automation

Quick setup guide for running the playbook on a clean Debian installation.

## Prerequisites

Fresh Debian 13 installation with sudo access.

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

### 3. Configure Vault

```bash
# Set vault password (change this!)
echo "your_secure_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Create vault from template
cp inventory/group_vars/debian_servers/vault.yml.example inventory/group_vars/debian_servers/vault.yml

# Edit vault with your settings
ansible-vault edit inventory/group_vars/debian_servers/vault.yml
```

Required vault variables:

- `vault_hostname`: Your desired server hostname
- `vault_target_user`: Your username (current user)
- `vault_smtp_host`: SMTP server (or localhost:8025 for testing)
- `vault_notification_email`: Your email address

### 4. Configure Inventory

```bash
# Create inventory
cp inventory/production.example inventory/production
```

Edit `inventory/production` and replace with:

```ini
[debian_servers]
localhost ansible_connection=local
```

### 5. Run Playbook

```bash
# Bootstrap (minimal setup)
ansible-playbook playbooks/bootstrap.yml --ask-become-pass

# Full setup
ansible-playbook playbooks/site.yml --ask-become-pass
```

## What It Does

- Sets hostname and timezone
- Installs essential packages (fish, tmux, htop, curl, etc.)
- Configures user with fish shell and docker/sudo groups
- Sets up automated security updates with email notifications
- Configures mail delivery via SSMTP

## Customization

Edit `inventory/group_vars/debian_servers/config.yml` to customize:

- Timezone and locales
- Package list
- User shell and groups
- Update timing

For sensitive changes, use:

```bash
ansible-vault edit inventory/group_vars/debian_servers/vault.yml
```

## Documentation

See [CLAUDE.md](CLAUDE.md) for detailed documentation and advanced usage.
