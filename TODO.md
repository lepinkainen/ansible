# Ansible Setup Improvement TODO

This TODO captures the most obvious improvements found during a static review of the current repository.

> Note: Runtime checks (`ansible-playbook --syntax-check`) were not executed in this environment because `ansible-playbook` is not installed.

## 1) Fix Arch validation drift vs implemented auto-update service

**Priority:** High  
**Area:** `roles/validation/tasks/Archlinux.yml`, `roles/unattended-upgrades/tasks/Archlinux.yml`

### Problem
Arch validation currently checks for:
- `pacman-upgrade.timer`
- `/etc/systemd/system/pacman-upgrade.service`
- `/usr/local/bin/pacman-upgrade.sh`

But the unattended-upgrades role actually creates:
- `arch-auto-update.timer`
- `/etc/systemd/system/arch-auto-update.service`
- `/usr/local/bin/arch-auto-update.sh`

This causes false negatives in validation.

### Fix guidance
- Update `roles/validation/tasks/Archlinux.yml` to validate the **actual** unit/script names used by `roles/unattended-upgrades/tasks/Archlinux.yml`.
- Specifically:
  - `check_name` service should be `arch-auto-update.timer`
  - file existence checks should reference:
    - `/etc/systemd/system/arch-auto-update.service`
    - `/usr/local/bin/arch-auto-update.sh`
- Re-run validation role and confirm Arch hosts report `security: ✅ PASS` when correctly configured.

### Validation steps
- `ansible-playbook playbooks/site.yml --limit <arch-host> --check --diff`
- `ansible-playbook playbooks/site.yml --limit <arch-host> --tags validation`

---

## 2) Fix Debian upgrade playbook repo file replacement on remote hosts

**Priority:** High  
**Area:** `playbooks/debian-upgrade.yml`

### Problem
The playbook uses `with_fileglob` on `/etc/apt/sources.list.d/*.list` while replacing codename strings. `with_fileglob` evaluates on the controller, not managed host, so remote files may never be iterated.

### Fix guidance
- Replace `with_fileglob` usage with remote-safe discovery:
  1. `find:` on `/etc/apt/sources.list.d` for `*.list`
  2. loop over `find_result.files | map(attribute='path')`
  3. apply `replace` to each discovered remote file
- Keep idempotence and existing `backup: true` behavior.

### Suggested pattern
- Add task:
  - `find: paths=/etc/apt/sources.list.d patterns=*.list file_type=file`
- Then loop replace over found paths.

### Validation steps
- `ansible-playbook playbooks/debian-upgrade.yml --limit <debian-host> --check --diff`
- Confirm changed lines in both `/etc/apt/sources.list` and `.list` files are previewed.

---

## 3) Align Docker playbook scope with role support/documentation

**Priority:** Medium  
**Area:** `playbooks/docker.yml`, README usage section

### Problem
`playbooks/docker.yml` currently targets only `debian_servers`, but there is explicit Arch support in:
- `roles/docker/tasks/Archlinux.yml`

This mismatch can confuse operators.

### Fix guidance
Choose one clear direction:
1. **Preferred:** expand playbook hosts to `debian_servers:arch_servers`, or
2. keep Debian-only and clearly document Docker playbook as Debian-only.

### Validation steps
- If expanded, run:
  - `ansible-playbook playbooks/docker.yml --limit <arch-host> --check --diff`
- Update README examples so target groups match real behavior.

---

## 4) Re-enable SSH host key checking (or document explicit exception)

**Priority:** Medium  
**Area:** `ansible.cfg`

### Problem
`host_key_checking = False` reduces SSH trust guarantees and increases MITM risk.

### Fix guidance
- Preferred: set `host_key_checking = True`.
- Add onboarding docs for collecting host keys (e.g. `ssh-keyscan`) and maintaining known_hosts.
- If disabling is intentional, document threat trade-off in README.

### Validation steps
- Run a limited playbook to ensure known_hosts handling works for new and existing hosts.

---

## 5) Prevent Tailscale auth key leakage in task logs/process metadata

**Priority:** Medium  
**Area:** `roles/tailscale/tasks/main.yml`

### Problem
`tailscale up --authkey={{ vault_tailscale_auth_key }}` is passed via command arguments.
Even with vault, command arguments can surface in logs/process lists.

### Fix guidance
- Add `no_log: true` to tasks handling auth key material (`tailscale up` task at minimum).
- Consider alternative auth flow that minimizes long-lived reusable keys.
- Keep `changed_when`/`failed_when` logic, but avoid exposing key in debug output.

### Validation steps
- Run tailscale tasks with verbose output and verify the auth key is redacted.

---

## 6) Migrate Debian mail transport from `ssmtp` to maintained alternative

**Priority:** Medium  
**Area:** `roles/mail-config/tasks/Debian.yml`, templates

### Problem
`ssmtp` is legacy/deprecated in many Debian contexts.

### Fix guidance
- Evaluate replacing Debian `ssmtp` setup with `msmtp` (already used on Arch).
- Update templates and apt-listchanges integration accordingly.
- Keep behavior parity for notification routing (including mailrise integration).

### Validation steps
- Send test mail after role run and validate queue/relay behavior.
- Re-run validation role mail checks.

---

## 7) Simplify SSH hardening management via drop-in template

**Priority:** Low/Medium  
**Area:** `roles/ssh-hardening/tasks/Debian.yml`, `roles/ssh-hardening/tasks/Archlinux.yml`

### Problem
Hardening is applied through many `lineinfile` edits against `/etc/ssh/sshd_config`, which can be brittle across distro defaults.

### Fix guidance
- Manage a dedicated drop-in file, e.g. `/etc/ssh/sshd_config.d/99-hardening.conf`, via template.
- Keep config validation step (`sshd -t`) before restart.
- Ensure compatibility on both Debian and Arch with correct service names.

### Validation steps
- `ansible-playbook playbooks/ssh-hardening.yml --limit <host> --check --diff`
- Confirm only intended SSH directives are managed.

---

## 8) Tighten validation strategy for CI/strict mode

**Priority:** Low/Medium  
**Area:** validation role (`roles/validation/tasks/*.yml`)

### Problem
Multiple checks use `ignore_errors: true`, which is useful for observability but can mask drift unless strict mode is applied.

### Fix guidance
- Introduce a stricter validation mode for CI (e.g. `validation_config.fail_fast: true` and/or selective removal of `ignore_errors`).
- Keep current permissive defaults for ad-hoc/local runs if needed.
- Document expected behavior for both modes.

### Validation steps
- Run validation in permissive and strict modes and compare outputs/fail behavior.

---

## Recommended execution order
1. Item 1 (Arch validation drift)
2. Item 2 (Debian upgrade remote file handling)
3. Item 3 (Docker scope/doc alignment)
4. Item 5 (Tailscale secret handling)
5. Item 4 (host key checking)
6. Item 6 (ssmtp migration)
7. Item 7 (SSH hardening refactor)
8. Item 8 (strict validation mode)
