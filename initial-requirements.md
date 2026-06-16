# 16 — The Scripts Project (Hermes' ops toolkit, built via Multica)

**Goal:** a `scripts` repo of shell + Python tools that Hermes runs to manage the VPS, infra, subscriptions, and reporting — **built** by the dev team through Multica and **consumed** by Hermes through named, tier-gated tools. Two loops: *Telegram → Multica* builds the scripts; *Telegram → Hermes* runs them.

**Depends on:** doc 14 (Hermes ops capabilities + the named-tool security model — this doc is the *library* those tools call), doc 06 (Multica + the Hermes bridge §10), doc 15 (squads), doc 11 (shell-engineer / python-engineer), doc 07 (autonomy tiers), doc 08 (secrets/backup), doc 05 (Hermes).

**The security spine (inherited from doc 14 §11 — non-negotiable):** Hermes **never** gets a "run any script" tool. The scripts project is the library that doc 14's *named, fixed-argv, tier-gated* tools call. Read-only reports = **T1** (auto); mutations = **T3** (echo-and-confirm). No open host shell — a curated catalog, not a firehose.

---

## 1. What the project is

A normal git repo at **`~/projects/scripts`** — a Multica workspace (doc 06 §7) — with two consumers:

- **The dev team writes it.** shell-engineer (bash), python-engineer (Python CLIs), devops-engineer (Coolify/Ansible-touching ones) build it via Multica; code-reviewer + **security-auditor** gate every PR (these run on the host — §5).
- **Hermes runs a curated subset.** The ops profile (`<DEV_USER>`, doc 14) exposes selected scripts as **named tools** via a thin `ops_scripts` plugin (§4) — same user, same host, so the scripts are readable and runnable directly (not the mount-less Docker sandbox, doc 14 §4/§10).

**Relationship to doc 14:** doc 14 §9 (`host_status`) and §10 (`file_search`) are the *first instances* of this pattern — read-only ops logic behind a fixed-argv tool. This project **generalizes** it: the logic lives here (versioned, tested, reviewed by the dev team), and the Hermes plugin is a thin wrapper that shells out to a fixed script by name. doc 14's `coolify`/`host_status`/`file_search` plugins stay; this project is where the *broader* library and any new named T3 actions (doc 14 §11) come from.

---

## 2. Repo layout & conventions

```
~/projects/scripts/
├── AGENTS.md                # canonical handbook + Team block (§5); CLAUDE.md = @AGENTS.md
├── manifest.yaml            # the contract: every exposed script → tier + args (§4)
├── shell/                   # bash/POSIX — shell-engineer (skill: shell-scripting)
├── python/                  # uv project, typed CLIs — python-engineer
│   └── src/ ...             # python-project-structure conventions
├── config/
│   └── subscriptions.yaml   # renewal dates + monthly cost (NON-secret data, §3)
└── tests/                   # pytest for Python; bats/shellcheck checks for shell
```

Conventions (the engineers' skills already encode these):
- **JSON on stdout.** Every script prints structured JSON so Hermes parses results into a report — never free-text the model must scrape. Human-readable summary to stderr if useful.
- **Read-only by default; mutations gated.** Anything destructive (prune, restart, deploy, delete) defaults to `--dry-run` and needs an explicit `--yes` (`shell-scripting`, `cli-tools`). The plugin maps `--yes` to the T3 confirm (§4).
- **No secrets in the repo** (CLAUDE.md rule 1). Scoped tokens (Coolify, etc.) come from the **ops Hermes env** (`<DEV_USER>`, doc 00 §4, doc 08 §2). Subscription *metadata* (renewal dates, cost) is non-secret → `config/subscriptions.yaml`.
- **Idempotent, `shellcheck`/`ruff`+`mypy` clean, exit codes meaningful, usage header.** Definition of done per the engineers' skills (doc 11).

---

## 3. The script catalog (starter — grow as needs appear)

| Category | Script | Lang | Tier | Does |
|---|---|---|---|---|
| **vps** | `health-report` | sh | T1 | disk/RAM/CPU/load/uptime + service-active (generalizes doc 14 §9 `host_status`) |
| | `backup-check` | sh | T1 | last restic→B2 backup ran + age (doc 08) |
| | `cert-expiry` | sh | T1 | days until each TLS cert expires |
| | `docker-cleanup` | sh | **T3** | prune dangling images/volumes — `--dry-run` default |
| **infra** | `coolify-status` | py | T1 | app health across the server (scoped Coolify token, doc 04 §5) |
| | `coolify-deploy` | py | **T3** | trigger a deploy — echoes the target app first |
| | `ansible-drift` | sh | T1 | `ansible-playbook --check` diff to flag config drift (doc 01) |
| **subscriptions** | `subs-report` | py | T1 | reads `config/subscriptions.yaml`: upcoming renewals, total monthly spend |
| | `usage-report` | py | T1 | Claude Pool via `ccusage` (doc 10 §1.3), OpenRouter/FAL spend via API |
| **reports** | `morning-briefing` | py | T1 | aggregates health + coolify + open Multica PRs + upcoming subs/reminders → one JSON for W5 (doc 07 §3) |
| | `weekly-summary` | py | T1 | week's deploys, completed Multica issues, cost trend |

Most are **T1 read-only** — the safe, high-value daily surface. Only `docker-cleanup` and `coolify-deploy` mutate (T3). `morning-briefing` is the keystone: it's the data source for the W5 briefing (doc 07), so Hermes assembles your morning report by calling one script.

---

## 4. How Hermes runs them — the `ops_scripts` plugin

A thin Hermes plugin (host subprocess, the doc 14 §9/§11 pattern), one tool per exposed script, **fixed argv** — the model chooses *which* named tool, never composes a shell line:

```yaml
# manifest.yaml — the repo↔plugin contract
tools:
  - name: vps_health         # → shell/health-report.sh        tier: t1
  - name: backup_check       # → shell/backup-check.sh          tier: t1
  - name: subs_report        # → python -m scripts.subs_report  tier: t1
  - name: morning_briefing   # → python -m scripts.morning_briefing  tier: t1
  - name: docker_cleanup     # → shell/docker-cleanup.sh        tier: t3   # mutating
  - name: coolify_deploy     # → python -m scripts.coolify_deploy  tier: t3
```

- **T1 tools run on request, no confirm** ("how's the server?" → `vps_health`; "my morning report" → `morning_briefing`). They only observe.
- **T3 tools echo-and-confirm** before running (doc 07 §8): Hermes states the exact action + target and waits for **"confirm"**; the Telegram thread is the audit log (doc 08 §5).
- **Secrets** come from the ops env (Coolify token etc.); the plugin passes none from the model. Ops profile only — the **family profile never gets `ops_scripts`** (stays T0, doc 07 §4, doc 14 §13).
- **Deploy = `git pull`.** The scripts aren't a Coolify app; merging to `main` then a `git pull` in `~/projects/scripts` updates what Hermes runs. (A `post-merge` hook or a tiny `scripts-update` cron keeps it current.)

This complements — does not replace — doc 14's `coolify`, `host_status`, and `file_search` plugins. New T3 ops actions (doc 14 §11) are added here as named tools, one at a time, each a line you can point to in the audit log.

---

## 5. Building the project in Multica — the squads

This is the **build loop**. The scripts repo is a Multica workspace; the dev team builds it through the squads (doc 15).

### 5.1 Create the project & workspace
```bash
# on the VPS as <DEV_USER>
git init ~/projects/scripts && cd ~/projects/scripts   # then push to GitHub, branch protection on main (doc 04 §3)
cp ~/infra/templates/app-repo-AGENTS.md AGENTS.md       # fill the Team block below
cp ~/infra/templates/app-repo-CLAUDE.md CLAUDE.md       # one-line @AGENTS.md
```
In Multica, add `~/projects/scripts` as a workspace/project (auto-discovered under `~/projects`, or add in the UI — confirm the project-create step against your Multica version, CLAUDE.md rule 5).

### 5.2 The Team block (`AGENTS.md`)
```yaml
## Team
stack: shell + python                       # bash automation + uv Python CLIs
runtimes: claude-code, codex                # both; shell/python tasks are Codex-eligible (doc 09 §4.3)
agents: shell-engineer, python-engineer, devops-engineer
# shared roles (code-reviewer, security-auditor, qa-engineer) always available
```
Fill the **"Conventions for Codex-routed work"** section (doc 09 §4.4) — these are exactly the well-scoped tasks you'll route to Codex.

### 5.3 Which squads, and the mandatory security gate
| Phase | Squad (doc 15) | Who leads / does |
|---|---|---|
| Build | **Engineering** | `tech-lead` routes: bash → shell-engineer, Python → python-engineer, Coolify/Ansible → devops-engineer |
| Gate | **Quality & Review** | `code-reviewer` + **`security-auditor` (mandatory here)** — these scripts run on the host with real tokens; `secrets-scan` + `owasp-web` on every PR |
| Tests | **Quality & Review** | `qa-engineer` for the Python CLIs (`pytest`); `shellcheck` for shell |

> **Project rule:** because every script can touch the host, **security-auditor review is mandatory on every PR here**, not optional. Note it in the repo's `AGENTS.md`.

### 5.4 The build flow
1. Assign a `[task]` to the **Engineering** squad → `tech-lead` delegates by @-mention (e.g. *"@shell-engineer add `cert-expiry`"*).
2. The engineer works in an isolated worktree → branch → **PR**, JSON output + `--dry-run` for mutations, manifest entry added.
3. Assign the PR to **Quality & Review** → `code-reviewer` + `security-auditor`.
4. You merge → `git pull` on the host → the new tool is live for Hermes (add it to `manifest.yaml` + the `ops_scripts` plugin if it should be Hermes-callable).

---

## 6. Talking to Multica from Telegram (the Hermes bridge)

This is how you **drive the build loop from your phone** — the `multica` Hermes plugin (ops profile, runs as `<DEV_USER>` with the multica CLI authenticated, doc 06 §10, doc 14 §12).

**What the plugin gives Hermes** (create / list / status / assign / search issues):

| You say (Telegram, ops bot) | Hermes does |
|---|---|
| *"In the scripts project, add a task: report TLS cert expiry, assign to the Engineering squad."* | drafts the issue in the PO contract, shows it, and on your **"approve"** creates it in Multica labeled `[task]` (W7 → W1, doc 07 §3) |
| *"What's the scripts team working on?"* | lists open issues + status for the project |
| *"Status of issue 14?"* | reports progress / blockers / PR link |
| *"Any scripts PRs ready for me?"* | the cron poll ("every 30 min, report newly completed issues") surfaces them; webhook push is the doc 14 §12 enhancement |

The two human gates stay (doc 09 §3.2): Hermes **shows the issue draft before creating it**, and **you merge** the PR — Telegram is the convenient front-end, not a bypass of the gates. (Assigning to a *squad* lets the leader route; assign to an agent directly when you know who fits, doc 15 §5.)

---

## 7. The two loops, together

```
BUILD LOOP                                   RUN LOOP
Telegram ──"add a cert-expiry script"──┐     Telegram ──"how's the server?"──┐
  Hermes (multica plugin) ─ approve ──► Multica          Hermes (ops_scripts plugin)
  → [task] → Engineering squad                            → vps_health (T1, no confirm)
  → shell-engineer → PR                                   → JSON ──► report in Telegram
  → Quality & Review (sec-auditor)             Telegram ──"clean up docker"──┐
  → YOU merge → git pull on host                         Hermes echoes target + waits
  → tool live in ~/projects/scripts                      → "confirm" → docker_cleanup (T3)
```

The dev team (Claude/Codex via Multica) **writes** the toolkit; Hermes **operates** it — both reachable from the same Telegram bot, each gated as its tier demands.

---

## 8. Security & tiers (recap — must stay true)

- **No open host shell** (doc 14 §11). Hermes calls **named, fixed-argv** script-tools only; the model never composes a command line.
- **T1 reads auto, T3 mutations echo-and-confirm** (doc 07 §1/§8); every T3 run is an audit-log line in the Telegram thread (doc 08 §5).
- **Ops profile only.** The family profile never gets `ops_scripts` (doc 14 §13).
- **No secrets in the repo;** scoped tokens from the ops env only; subscription metadata is non-secret config (doc 00 §4, doc 08 §2).
- **Backup:** add `~/projects/scripts` to the backup matrix only if it isn't already covered by the projects backup; the irreplaceable bit is `config/subscriptions.yaml` if you hand-maintain it (doc 08 §4).
- **Security-auditor review is mandatory** on every PR (§5.3) — host-touching code earns the full gate.

---

## 9. Validation

- [ ] `~/projects/scripts` is a Multica workspace with the §5.2 Team block; branch protection on `main`.
- [ ] A `[task]` assigned to the **Engineering** squad lands a script as a PR (JSON output, `--dry-run` for mutations, `shellcheck`/`ruff` clean); the PR carries a **security-auditor** review.
- [ ] The `ops_scripts` plugin exposes the manifest's tools; a T1 (`vps_health`) runs on request, a T3 (`docker_cleanup`) echoes + waits for "confirm".
- [ ] From Telegram: *"add a task to the scripts project…"* → Hermes shows a draft, creates it on approval; *"what's the team working on?"* lists it.
- [ ] `morning_briefing` returns JSON that the W5 briefing (doc 07) renders.
- [ ] The family bot has no access to `ops_scripts` or the scripts repo.

---

## 10. Reuse notes

- The scripts project is a **per-server asset**: each client VPS gets its own `~/projects/scripts` with the same conventions and squad workflow; only `config/subscriptions.yaml` and the scoped tokens differ.
- The repo↔plugin **manifest** is the productizable contract — it's how you offer "Telegram ops console" as a tier without handing anyone a shell.
- Keep the toolkit lean (doc 10): a script earns its slot when a real workflow calls it twice; delete dead ones. The catalog (§3) is a starter, not a target.
