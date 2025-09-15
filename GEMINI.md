This is an Ansible project for automating Debian and Arch server setup. It's designed with a security-first approach, using 1Password for secrets management and encrypted inventory and vault files.

### Project Overview

The project uses Ansible to provision and configure servers, with a focus on automation and security. It leverages Ansible Vault to encrypt sensitive data and integrates with 1Password to manage access to the vault and sudo passwords. The project is structured with roles for different aspects of server configuration, such as system basics, package management, and security updates. It supports both Debian and Arch Linux.

### 1Password Integration

- **Vault password**: `scripts/get-vault-password.sh` retrieves the vault password from 1Password.
- **Deploy password**: `scripts/get-deploy-password.sh` retrieves the sudo password for the deploy user from 1Password.
- `ansible.cfg` is pre-configured to use these scripts, so no manual password entry (`--ask-become-pass`) is needed.

### Running Playbooks

The main playbook is `playbooks/site.yml`.

- **Run the main playbook on all servers:**
  ```bash
  ansible-playbook playbooks/site.yml
  ```

- **Run on a specific server or group:**
  ```bash
  ansible-playbook playbooks/site.yml --limit <server_name>
  ansible-playbook playbooks/site.yml --limit debian_servers
  ```

- **Dry run to see changes:**
  ```bash
  ansible-playbook playbooks/site.yml --check --diff --limit <server_name>
  ```

- **Install Docker:**
  ```bash
  ansible-playbook playbooks/docker.yml
  ```

- **Harden SSH (run after initial setup):**
  ```bash
  ansible-playbook playbooks/ssh-hardening.yml --limit <server_name>
  ```

### Development Conventions

- **Secrets & Encryption:** All sensitive data (passwords, API keys) MUST be stored in Ansible Vault files.
  - The main inventory `inventory/production.yml` is encrypted.
  - Sensitive variables are stored in `vault.yml` files within `inventory/group_vars/` and `inventory/host_vars/`. These are also encrypted.
  - Use `ansible-vault edit <file_path>` to edit encrypted files.
- **Inventory:** The inventory is a single encrypted YAML file: `inventory/production.yml`. Hosts are grouped by distribution (`debian_servers`, `arch_servers`).
- **Roles:** The project is organized into roles in the `roles/` directory. Roles use OS-family-specific task files (e.g., `Debian.yml`, `Archlinux.yml`) included from `tasks/main.yml` to support multiple distributions.
- **Pre-commit hook:** A pre-commit hook at `scripts/hooks/pre-commit` prevents committing unencrypted vault files. Enable it by running: `git config core.hooksPath scripts/hooks`

### Key Files

- `ansible.cfg`: Main Ansible configuration. Sets inventory path and password scripts.
- `playbooks/site.yml`: Main playbook for server configuration.
- `inventory/production.yml`: The **encrypted** inventory file.
- `inventory/group_vars/all/config.yml`: Shared configuration for all servers.
- `inventory/group_vars/<group>/config.yml`: Distribution-specific configuration.
- `inventory/group_vars/<group>/vault.yml`: **Encrypted** sensitive data for a group.
- `inventory/host_vars/<host>/vault.yml`: **Encrypted** sensitive data for a specific host.
- `roles/`: Contains all Ansible roles.
- `scripts/get-vault-password.sh`: Script to retrieve the Ansible Vault password from 1Password.
- `scripts/get-deploy-password.sh`: Script to retrieve the sudo password from 1Password.
- `CLAUDE.md`: Detailed documentation about the project.