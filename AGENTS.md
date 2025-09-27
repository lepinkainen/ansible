# Repository Guidelines

## Project Structure & Module Organization

Playbooks live under `playbooks/`, with `site.yml` orchestrating the full server setup and targeted playbooks such as `docker.yml` and `ssh-hardening.yml`. Reusable logic is in `roles/`, each role owning its `tasks/`, `templates/`, and defaults. Inventory data is kept in `inventory/`, with encrypted group and host vars; run `ansible-vault view` when you need to inspect them. Utility scripts (e.g., password helpers) live in `scripts/`, and shared doc assets for LLM agents are under `llm-shared/`.

## Build, Test, and Development Commands

Use `ansible-playbook playbooks/site.yml --syntax-check` before committing to catch YAML and module issues. Run `ansible-playbook playbooks/site.yml --check` for a dry-run on the limit you are targeting. For focused work, pair `--limit debian_servers` or a specific hostname. Secrets are supplied by `scripts/get-vault-password.sh` and `scripts/get-deploy-password.sh`; source them or pass via `--vault-password-file`.

## Coding Style & Naming Conventions

Use two-space indentation in YAML files and keep task lists readable by grouping related vars. Task names should be imperative ("Configure mailrise webhook"). Variables use `snake_case`, with vault-prefixed entries for secrets. Prefer role defaults over hard-coded values, and place host-specific data in `inventory/host_vars/<hostname>.yml`. Keep templates in Jinja2 with `{{ variable }}` spacing.

## Testing Guidelines

Always start with `ansible-playbook … --syntax-check` followed by `--check --diff` on at least one host to confirm idempotence. When introducing new roles, add a targeted playbook (or update `debian-version-check.yml`) to exercise it. Document manual verification steps in the PR when automation is not feasible.

## Commit & Pull Request Guidelines

Follow the existing Conventional Commits style (`feat:`, `fix:`, `chore:`, `docs:`). Group related Ansible changes per commit and include inventory or vault updates in separate commits for traceability. Pull requests need: summary of the role/playbook impact, instructions for re-running affected playbooks, linked issues (if any), and screenshots or command outputs when behaviour changes.

## Secrets & Vault Workflow

Keep secrets in vault-backed files; never commit decrypted content. Use `scripts/vault-files.sh` to list encrypted files and `ansible-vault edit inventory/production.yml` to update them. If you add a new secret, document the expected 1Password path and update the example files under `inventory/group_vars/*/vault.yml.example`.
