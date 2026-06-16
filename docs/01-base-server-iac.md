# 01 — Base Server & Infrastructure as Code

**Goal:** a hardened Ubuntu 24.04 VPS, fully reproducible via Ansible, ready for everything above it. This document is the **authoritative spec** for the `ansible/` toolkit in this repo — build, review, and extend the toolkit against it.

**Why IaC here:** the playbook is the product. Every future client server = same playbook, different variables file. Manual setup is acceptable once; for a business it must be `ansible-playbook site.yml`.

---

## 1. Provisioning (manual, by design)

In the provider panel (this instance: Contabo): order `<VPS_PLAN>`, **NVMe** storage variant, **Ubuntu 24.04 LTS** (plain image, no panel/app image), paste your SSH public key at order time, note `<SERVER_IP>`. Skip the provider auto-backup add-on — doc 08 replaces it with restic→B2 plus free manual snapshots.

> Provisioning stays manual: do **not** automate it or call provider APIs. A Terraform layer is roadmap (doc 00 §9), not current scope.

## 2. Toolkit requirements (non-negotiable)

### 2.1 Reusability — top priority

- **Zero** project-specific values in roles, tasks, handlers, or `site.yml`. IPs, domains, usernames, swap size, timezone, ports — all from `inventory` + `group_vars`.
- Ship `*.example` files (`inventory.example.ini`, `group_vars/all.example.yml`, `group_vars/vault.example.yml`). New server = copy → fill → run.
- Roles are generic and composable; no role "knows" it's for project X.
- The README proves reuse by onboarding a **second, unrelated** server.

### 2.2 Maintainability

- Role-per-responsibility layout; **every task block tagged** so subsets run independently (`--tags hardening`, `--tags coolify`, `--tags devtools`, …).
- **Idempotent:** a second run reports **0 changed tasks**.
- `yamllint` + `ansible-lint` clean; collections pinned in `requirements.yml`.
- SSH config via **drop-in** (`/etc/ssh/sshd_config.d/00-hardening.conf`), never editing the main sshd file. The `00-` prefix matters: sshd uses the **first** value it reads and drop-ins load (lexicographically) before the main config — `00-` wins over e.g. cloud-init's `50-cloud-init.conf`, which can re-enable password auth.
- `Makefile` targets: `lint`, `check` (dry run), `deploy`, `vault-edit`.
- Comment non-obvious tasks; add no roles, variables, or abstractions that aren't actually used.

### 2.3 Security & safety ordering (sacred — CLAUDE.md rule 7)

- **Ansible Vault** for all secrets; real `vault.yml` gitignored and encrypted; `no_log: true` on every secret-handling task.
- **Two-stage bootstrap, lockout-proof:** first run connects as `root` (key installed at provisioning) → creates `<ADMIN_USER>` with sudo + key → **key login verified** → only then is password auth + root login disabled. `site.yml` documents the `ansible_user` flip (root first run → `<ADMIN_USER>` thereafter) in its header comment. Never produce a play that can lock the operator out.
- SSH final state: key-only — `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes`.
- UFW: default deny incoming / allow outgoing; allowed ports from a variable list (default `22, 80, 443`); **SSH allowed before UFW enable**.
- Coolify dashboard (8000) never opened publicly — Tailscale (or SSH tunnel) only.
- Fast-moving installers (Coolify, Tailscale, RTK): **verify the current official install command against upstream docs before writing the task**; cite the doc URL in the PR (CLAUDE.md rule 5).

## 3. The roles

| Role | Responsibility |
|---|---|
| **base** | `apt update`/`upgrade`; install `base_packages` (must include `acl` so `become` to non-root users works); set `timezone`; create swap file of `swap_size_gb` (perms, `mkswap`/`swapon`, fstab-guarded so reruns don't re-add); `swappiness` via `ansible.posix.sysctl`; enable unattended-upgrades. |
| **users** | Create every entry in `managed_users` — per-user sudo and docker-group flags, `~/.ssh` (700) + `authorized_keys` (600) from the configured public key, correct ownership. |
| **hardening** | sshd drop-in template from the `ssh_*` vars + restart handler; Fail2Ban `jail.local` with an `sshd` jail (`fail2ban_maxretry`/`fail2ban_bantime`). Ordered so password auth is disabled only after key login is confirmed (§2.3). |
| **firewall** | `community.general.ufw`: default deny incoming / allow outgoing, allow each port in `ufw_allowed_ports`, then enable. SSH allowed before enable. |
| **coolify** | Run the official Coolify install script with a `creates: {{ coolify_data_dir }}` guard so reruns are no-ops; `become`. The installer bundles Docker — verify current behavior upstream. |
| **tailscale** | Add Tailscale apt repo → install → `tailscale up --authkey={{ vault_tailscale_authkey }}`. Idempotency guard: skip if `tailscale status` is already authenticated. After this the VPS joins your tailnet (e.g. `vps-1`); dashboards bind to it (docs 02/06). |
| **devtools** | `<DEV_USER>` toolchain (doc 03 §2 + doc 10 §7 + doc 04 §7): PHP `devtools_php_version` via `ppa:ondrej/php` + extension set, Composer (per-user, `~/.local/bin`), mise + Node `devtools_node_version` (per-user), `gh`, `tmux`, RTK (pinned version) + its global hook, Codex CLI (official installer, PATH-guarded), ccusage via npx alias, `unset ANTHROPIC_API_KEY`/`unset OPENAI_API_KEY` billing guards. Per-user steps run with `become_user`. Entirely behind `devtools_enabled` — client boxes typically skip it. |
| **backup** | restic + offsite backups per **doc 08 §4 (the functional spec)**: install restic; `/etc/restic/env` (root, 0600) templated from vault (B2 credentials, repository, restic password); `backup.sh` from template (paths from `backup_paths`, DB-dump steps variable-driven); systemd service + timer on `backup_schedule`; retention from `backup_keep_*`; `restic init` guarded (skip when the repo already exists). Behind `backup_enabled`. |

Handlers: `restart ssh`, `restart fail2ban`, `reload ufw`.

### 3.1 The user trio (doc 00 §4)

```yaml
# group_vars/all.yml
managed_users:
  - { name: "<ADMIN_USER>",  sudo: true,  docker: false }
  - { name: "<DEV_USER>",    sudo: false, docker: true  }   # docker group: Coolify-adjacent dev + Multica daemon
  - { name: "<AGENT_USER>",  sudo: false, docker: false }   # Hermes; exec isolation via Docker backend, not group
```

> ⚠️ The `docker` group is root-equivalent on the host. `<DEV_USER>` gets it (you trust yourself + need it for Multica). `<AGENT_USER>` deliberately does **not** — Hermes reaches Docker only through its own hardened exec backend configuration (doc 05).

All users get `users_default_pubkey` unless an entry sets its own `pubkey` — per-user keys are the stricter option for client servers.

## 4. Variables (all in `group_vars/all.example.yml`, documented inline)

| Variable | Default | Notes |
|---|---|---|
| `timezone` | `<TZ>` | e.g. `Asia/Beirut` |
| `swap_size_gb` / `swappiness` | `4` / `10` | build-spike safety net |
| `base_packages` | curl, git, ufw, fail2ban, unattended-upgrades, htop, ca-certificates, gnupg, acl | list, extendable |
| `managed_users` / `users_default_pubkey` | §3.1 trio | per-user `pubkey` override allowed |
| `ssh_permit_root_login` / `ssh_password_authentication` | `"no"` / `"no"` | final hardened state |
| `ufw_allowed_ports` | `["22", "80", "443"]` | list |
| `fail2ban_maxretry` / `fail2ban_bantime` | `5` / `1h` | sshd jail |
| `coolify_install` / `coolify_data_dir` | `true` / `/data/coolify` | data dir doubles as the idempotency guard |
| `tailscale_enabled` / `tailscale_ssh` | `true` / `false` | native sshd already hardened |
| `devtools_enabled` / `devtools_user` | `false` / `<DEV_USER>` | plus `devtools_php_version` (8.4), `devtools_node_version` (22) |
| `backup_enabled` / `backup_paths` / `backup_schedule` | `false` / doc 08 §4.1 matrix / `daily` | plus `backup_keep_daily/weekly/monthly` (7/4/6) |

Secrets in `group_vars/vault.example.yml`: `vault_tailscale_authkey`, `vault_b2_account_id`, `vault_b2_account_key`, `vault_restic_repository`, `vault_restic_password`. Keep the vault minimal — only what roles actually consume.

## 5. Deliverable file tree

```
ansible/
├── ansible.cfg
├── requirements.yml              # pinned collections (community.general, ansible.posix)
├── Makefile                      # lint / check / deploy / vault-edit
├── .yamllint  .ansible-lint      # lint configs
├── inventory.example.ini
├── group_vars/
│   ├── all.example.yml           # every tunable above, documented inline
│   └── vault.example.yml         # secret placeholders (real vault.yml: encrypted + gitignored)
├── site.yml                      # roles in safe order, tagged; bootstrap notes in header
└── roles/
    ├── base/  users/  hardening/  firewall/
    ├── coolify/  tailscale/  devtools/  backup/
    └── …                         # each: tasks/ handlers/ defaults/ (templates/ where needed)
```

Role defaults live in each role's `defaults/main.yml`; project overrides live in `group_vars`. App build config (Dockerfiles etc.) lives in each application's own repo — this repo is infrastructure only (reusable scaffolding goes in `templates/`).

## 6. Order of operations

1. Provision (manual, §1) → 2. `ansible-playbook site.yml` (first run as root, then flips to `<ADMIN_USER>`) → 3. Verify §7 → 4. Snapshot (free, provider panel) labeled `post-base`.

Coolify **resource** setup (projects, apps, databases, domains) stays manual per doc 02 — the community Coolify Terraform/API providers are pre-1.0; do not depend on them.

## 7. Validation checklist

**Toolkit (definition of done):**

- [ ] `ansible-playbook site.yml --syntax-check` passes; `yamllint` + `ansible-lint` clean.
- [ ] `--check` dry run clean against a test host; real run produces a hardened, Coolify-ready host.
- [ ] Second run: **0 changed tasks**.
- [ ] Onboarding a second server works by copying `*.example` files and editing variables only; a newcomer can reproduce everything from the README alone.

**Server (after a real run):**

- [ ] `ssh <ADMIN_USER>@<SERVER_IP>` works; root + password SSH refused.
- [ ] `ssh <DEV_USER>@…` and `ssh <AGENT_USER>@…` work; neither has sudo.
- [ ] `id <DEV_USER>` shows `docker`; `id <AGENT_USER>` does not.
- [ ] `free -h` shows swap; `ufw status` shows only 22/80/443; `fail2ban-client status sshd` active; `timedatectl` shows `<TZ>`.
- [ ] `docker ps` lists Coolify; dashboard **not** reachable on `<SERVER_IP>:8000`; reachable on the tailnet IP.
- [ ] `tailscale status` connected.
- [ ] (devtools) as `<DEV_USER>`: `php -v` → 8.4, `composer -V`, `node -v` → 22, `gh --version`, `rtk --version`, `codex --version`.
- [ ] (backup) `systemctl list-timers` shows the backup timer; first `restic snapshots` succeeds.

## 8. Reuse notes

- New client = new `inventory` + `group_vars` copy. The user trio (`admin`/`dev`/`agent`) is a sane default everywhere; client servers may drop `<DEV_USER>` and disable `devtools`.
- Tailscale: for client servers, use a **separate tailnet or ACL-scoped tags** so clients never share your private network.
- Backups: separate B2 bucket + separate restic password per client — their data never shares an encryption key with yours (doc 08 §7).
- Keep `vault.yml` per-client, never shared.
