This is an Ansible project for automating Debian and Arch server setup. It's designed with a security-first approach, using 1Password for secrets management and encrypted inventory and vault files.

### Project Overview

The project uses Ansible to provision and configure servers, with a focus on automation and security. It leverages Ansible Vault to encrypt sensitive data and integrates with 1Password to manage access to the vault and sudo passwords. The project is structured with roles for different aspects of server configuration, such as system basics, package management, and security updates.

### Building and Running

The main playbook is `playbooks/site.yml`. To run it, you'll need to have Ansible installed and have the 1Password CLI authenticated.

**Run the main playbook:**

```bash
ansible-playbook playbooks/site.yml
```

**Run on a specific server:**

```bash
ansible-playbook playbooks/site.yml --limit <server_name>
```

**Install Docker:**

```bash
ansible-playbook playbooks/docker.yml
```

### Development Conventions

* **Secrets:** All sensitive data, such as passwords and API keys, should be stored in Ansible Vault files. These files are encrypted and can be safely committed to the repository. The vault password is automatically retrieved from 1Password.
* **Inventory:** The inventory is managed in the encrypted `inventory/production.yml` file.
* **Roles:** The project is organized into roles, with each role responsible for a specific aspect of the server configuration.
* **Pre-commit hook:** A pre-commit hook is in place to prevent committing unencrypted vault files. To enable it, run: `git config core.hooksPath scripts/hooks`

### Key Files

* `ansible.cfg`: The main Ansible configuration file.
* `playbooks/site.yml`: The main playbook that orchestrates the server configuration.
* `inventory/production.yml`: The encrypted inventory file.
* `roles/`: The directory containing the Ansible roles.
* `scripts/get-vault-password.sh`: Script to retrieve the Ansible Vault password from 1Password.
* `scripts/get-deploy-password.sh`: Script to retrieve the sudo password from 1Password.
* `CLAUDE.md`: Detailed documentation about the project.
