# 08 — Security, Secrets & Backups

**Goal:** the cross-cutting layer: who can touch what, where every secret lives, what gets backed up where, and the drill that proves restores actually work. This doc is the one to re-read before any client deployment.

---

## 1. Threat model (what we defend against)

1. **Internet background noise** — SSH brute force, bot scans → key-only SSH, Fail2Ban, UFW, no public dashboards.
2. **A leaked credential** — any single key/token → per-user secret isolation + scoped tokens + spend caps = small blast radius.
3. **An agent doing something dumb** — the realistic AI risk → tier model (doc 07), sandboxed exec, PR gates, allowlists. Agents are *capability-constrained*, not trusted.
4. **Data loss** — disk/host failure, fat-fingered deletion, ransomware → versioned, encrypted, **offsite at a different vendor** backups + IaC rebuild.
5. **Family misuse (accidental)** — kids clicking around → family profile is T0 by construction.

## 2. Secrets map — single source of truth

| Secret | Lives at | Owner (mode 600) | Scope/cap |
|---|---|---|---|
| SSH private keys | your devices only | you | — |
| Ansible vault password | your password manager | you | — |
| Coolify admin login | password manager | you | — |
| Coolify API token (Hermes plugin) | `~<AGENT_USER>/.hermes/.env` | `<AGENT_USER>` | **scoped**: deploy/logs/restart only if granularity allows |
| Telegram bot tokens ×2 | `~<AGENT_USER>/.hermes/.env` | `<AGENT_USER>` | revocable via BotFather |
| OpenRouter key | same | `<AGENT_USER>` | **monthly spend cap set** |
| FAL key | same | `<AGENT_USER>` | spend alert set |
| Claude subscription | `~<DEV_USER>/.claude` (login state) | `<DEV_USER>` | no API key anywhere (doc 04 §1.1) |
| GitHub auth (`gh`) | `~<DEV_USER>` | `<DEV_USER>` | repo-scoped |
| App secrets (.env) | Coolify encrypted env store | Coolify | per-app |
| Binance API key (trading bot) | Coolify env of the freqtrade resource | Coolify | **no withdrawal, IP-locked** (doc 12 §3) |
| Trading analyst env (FT REST creds, capped OpenRouter key, trader bot token) | `~<TRADER_USER>/` env file | `<TRADER_USER>` | monthly LLM cap; REST creds local-only |
| MySQL credentials | Coolify-generated | Coolify | internal network only |
| restic repo password | password manager **and nowhere else writable** | you | losing it = backups unreadable |
| B2 app key | root-owned `/etc/restic/env` (600) | root | bucket-scoped key |

**Rules:** no secret in any git repo, ever (`.gitignore` + `Read(.env*)` deny in Claude Code). No secret readable across user boundaries (`ls -la` audit quarterly). Rotation: bot tokens + Coolify token on suspicion or annually; basic-auth demo creds after each client cycle.

## 3. Network posture (recap + verify)

```bash
sudo ufw status verbose       # exactly: 22, 80, 443
sudo ss -tlnp                 # anything listening on 0.0.0.0 beyond sshd/traefik? investigate
tailscale status              # dashboards ride this, not the public net
```

Optional max-hardening (recommended once Tailscale is proven, mandatory flavor for client boxes): move SSH behind Tailscale too (`ufw delete allow OpenSSH`) — public surface becomes 80/443 only. Keep the Contabo web console (VNC) as your break-glass.

## 4. Backups — restic → Backblaze B2

**Why this design:** encrypted client-side (B2 never sees plaintext), deduplicated + versioned (point-in-time restores), **different vendor** than the VPS (survives a Contabo account problem), granular (one file or one DB), ~free at this scale. Paired with Ansible, the recovery story is: *reprovision any VPS in ~30 min, restore data, done* — stronger than any provider snapshot add-on.

### 4.1 What gets backed up (the matrix)

| Data | Path/source | Why it's irreplaceable |
|---|---|---|
| Coolify state | `/data/coolify` (incl. `source/.env`) | every app/domain/env definition |
| Databases | nightly `mysqldump`/`pg_dump` of each Coolify DB + Multica's Postgres → `/var/backups/db/` | the only truly unique data |
| App uploads | Coolify persistent volumes (`storage/app`) | user files |
| Hermes brain | `/home/<AGENT_USER>/.hermes/` | memory, skills, config — the agent's learning |
| Claude team config | `/home/<DEV_USER>/.claude/` | skills/agents/settings (also versioned in infra repo) |
| Multica server | its `.env` + Postgres dump (above) | board state, skills |
| Trading bot state | freqtrade `user_data/` volume (`tradesv3.sqlite`) + `journal/` (doc 12 §9) | full trade history + every analyst decision |
| Infra repo | GitHub (it's code) | — |

**Not backed up:** OS, Docker images, repos' working copies — all rebuildable from Ansible/registries/GitHub.

### 4.2 Setup (root; belongs in an Ansible `backup` role)

```bash
sudo apt install -y restic
sudo install -m 700 -d /etc/restic
sudo tee /etc/restic/env >/dev/null <<'EOF'
export B2_ACCOUNT_ID=...        # bucket-scoped app key
export B2_ACCOUNT_KEY=...
export RESTIC_REPOSITORY=b2:<B2_BUCKET>:vps-1
export RESTIC_PASSWORD=...      # ALSO in your password manager — non-negotiable
EOF
sudo chmod 600 /etc/restic/env
. /etc/restic/env && restic init
```

`/usr/local/bin/backup.sh` (nightly via systemd timer or cron):

```bash
#!/usr/bin/env bash
set -euo pipefail
source /etc/restic/env
mkdir -p /var/backups/db
# 1) dump every DB container (loop over coolify-managed containers; example:)
docker exec <mysql-container> sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > /var/backups/db/mysql-all.sql
docker exec <multica-pg> pg_dumpall -U postgres > /var/backups/db/multica.sql
# 2) snapshot the matrix
restic backup /data/coolify /var/backups/db /home/<AGENT_USER>/.hermes /home/<DEV_USER>/.claude <coolify-volume-paths>
# 3) retention: 7 daily, 4 weekly, 6 monthly
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check --read-data-subset=5%
```

Wire a failure notification: simplest is Hermes — a cron that checks the last backup timestamp every morning and yells on Telegram if it's stale (the W5 briefing already has the slot).

### 4.3 The restore drill (untested backup = no backup)

Quarterly, 20 minutes: `restic snapshots` → restore one DB dump to `/tmp` → load into a scratch MySQL container → confirm a known row exists → delete. Annually (or before going production): full drill — fresh throwaway VPS, Ansible playbook, restic restore, app up. Time it; that number is your real RTO and a selling point for clients.

## 5. Audit & monitoring (minimal, honest)

- T3 actions (doc 07): Hermes' structured logs (`hermes logs`) + keep the Telegram confirmations — that thread *is* the audit trail. Include `~/.hermes/logs` in backups.
- `lastlog` / `journalctl -u ssh` skim monthly; Fail2Ban does the live blocking.
- Coolify notifications → Telegram for failed deploys/unhealthy containers.
- Full monitoring stack (Uptime Kuma, disk/RAM alerts) = next milestone; W5 briefing covers the gap.

## 6. Validation

- [ ] Secrets map audited: every entry exists where stated, mode 600, owner correct.
- [ ] `sudo -u <AGENT_USER> cat /home/<DEV_USER>/.claude/...` → permission denied (and vice versa).
- [ ] Nightly backup ran; `restic snapshots` shows today; B2 bucket growing.
- [ ] One file + one DB restore drill completed and documented.
- [ ] Backup-staleness alert fires when you fake a failure.

## 7. Reuse notes

- This doc is the **security one-pager you hand clients** (translated from "family profile" to "user roles"). The threat model, tier system, secrets isolation, and tested-restore RTO are exactly what a company buying a "private AI server" wants to see written down.
- Per-client: separate B2 bucket + separate restic password (their data never shares an encryption key with yours), separate tailnet/ACL tag, separate bot tokens, LiteLLM virtual key with tier budget.
