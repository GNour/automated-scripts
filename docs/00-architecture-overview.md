# 00 — Architecture Overview

**What this VPS is:** one server acting as (1) private staging + client demo host, (2) remote dev environment, (3) an autonomous AI development team (Claude Code orchestrated through Multica), and (4) a personal/family assistant reachable via Telegram (Hermes Agent).

**Reuse promise:** every document in this set uses the variables below instead of hardcoded values. Onboarding a new server, project, or client = fill the table, follow the docs in order. Nothing in the docs is specific to one person except the example column.

---

## 1. Variables (fill once, used everywhere)

| Variable | Meaning | Example (this instance) |
|---|---|---|
| `<DOMAIN>` | Root domain (DNS at registrar) | `nco-tech.com` |
| `<SERVER_IP>` | VPS public IPv4 | *(after provisioning)* |
| `<VPS_PLAN>` | Provider + plan | Contabo Cloud VPS 20 (6 vCPU/12 GB/100 GB NVMe) |
| `<ADMIN_USER>` | Non-root sudo user (ops) | `deploy` |
| `<DEV_USER>` | Development user (you + Claude Code + Multica daemon) | `dev` |
| `<AGENT_USER>` | Unprivileged user running Hermes | `hermes` |
| `<TZ>` | Server timezone | `Asia/Beirut` |
| `<GIT_ORG>` | GitHub account/org | *(yours)* |
| `<OPS_BOT>` | Telegram bot for you (full access) | `@..._ops_bot` |
| `<FAMILY_BOT>` | Telegram bot for family (restricted) | `@..._bot` |
| `<B2_BUCKET>` | Backblaze B2 bucket for restic | *(yours)* |

---

## 2. The stack, layer by layer

```
┌─ ACCESS ────────────────────────────────────────────────────────┐
│  You/clients (HTTPS) → *.​<DOMAIN> subdomains                    │
│  You (VS Code Remote-SSH, port 22, key-only)                    │
│  You + family (Telegram → Hermes gateway, outbound polling)     │
│  You (Tailscale private network → dashboards)                   │
├─ ORCHESTRATION ─────────────────────────────────────────────────┤
│  Hermes Agent (gateway, 2 profiles)  ←→  Multica (task board)   │
│                 │ assigns                  │ runs               │
│                 ▼                          ▼                    │
│            Claude Code (headless dev team: skills/agents/MCPs)  │
├─ DELIVERY ──────────────────────────────────────────────────────┤
│  GitHub (PRs) → Coolify (build/deploy) → Traefik (TLS/routing)  │
│  → staging app, demo apps (basic-auth), Multica UI (Tailscale)  │
├─ FOUNDATION ────────────────────────────────────────────────────┤
│  Ubuntu 24.04 · Docker · UFW/Fail2Ban · Ansible-provisioned     │
│  restic → Backblaze B2 (offsite backups)                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Tool glossary — what each is and why it earned its place

| Tool | What it is | Why we use it |
|---|---|---|
| **Ubuntu 24.04 LTS** | Linux OS | Longest LTS runway (2029/2034), Coolify's recommended target, best community coverage. |
| **Ansible** | Agentless config-as-code (SSH-based) | Turns server setup into a re-runnable playbook → identical hardened servers for every future client. Chosen over Terraform because provisioning is manual and OS config is Ansible's home turf. |
| **Docker** | Container runtime | Isolation between every app/agent; the substrate Coolify, Multica, and Hermes' exec backend all run on. |
| **Coolify** | Self-hosted PaaS (open-source Heroku/Vercel) | Git-push deploys, automatic HTTPS, per-app domains/env/logs from one dashboard. Free, no per-app fees — the deployment heart of the server. |
| **Traefik** | Reverse proxy (bundled inside Coolify) | Routes `*.​<DOMAIN>` subdomains to the right container, terminates TLS (Let's Encrypt), applies basic-auth to demos. You rarely touch it directly. |
| **Tailscale** | Zero-config private VPN (WireGuard) | Dashboards (Coolify, Multica) become reachable only from your devices — entire attack surface removed. Free tier covers personal use. |
| **VS Code Remote-SSH** | IDE-over-SSH | Full dev environment on the VPS from any laptop; code never lives only on one machine. No extra server-side attack surface (vs code-server). |
| **Claude Code** | Anthropic's terminal coding agent | The "dev team" lead seat: reads repos, writes code, runs tests, opens PRs. Runs interactive (you) and headless (Multica). Billed via Claude Pro subscription — flat $20/mo. |
| **Codex CLI** | OpenAI's terminal coding agent | The second engineer seat: same workspace, registered as its own Multica runtime. Billed via ChatGPT Plus — a second flat subscription pool, doubling weekly agent capacity (doc 04 §7). |
| **Multica** | Open-source managed-agents platform (issue board for AI agents) | The management layer: assign tasks like to teammates, track progress, reuse skills. Auto-detects Claude Code + Hermes as runtimes. *(License caveat: not embeddable in a commercial hosted offering without permission — see doc 06.)* |
| **Hermes Agent** | Open-source autonomous agent (Nous Research) | The orchestrator + assistant: lives on Telegram, persistent memory, learned skills, cron scheduling, image generation, sandboxed execution. Model-agnostic. |
| **OpenRouter** | Hosted multi-model API gateway | One key → 200+ models, pay-per-token, per-key spend caps. Hermes' brain. Swappable later for self-hosted LiteLLM (same OpenAI-compatible API) when productizing. |
| **FAL** | Hosted image/video-gen API | Cost-efficient images (FLUX schnell ≈ $0.003/img) with a quality tier on demand. Plugged into Hermes as its image backend. |
| **restic + Backblaze B2** | Encrypted dedup backup tool + cheap object storage | True offsite backups at a *different vendor* than the VPS: versioned, encrypted, granular restores, ~$0 at this scale. |
| **UFW / Fail2Ban / unattended-upgrades** | Firewall / brute-force jail / auto security patches | The standard Ubuntu hardening triad. |
| **GitHub** | Code host | Private repos, PR review gate (agents are PR-only), webhooks trigger Coolify deploys. |

---

## 4. Linux user model (least privilege)

| User | sudo | Purpose | Holds secrets for |
|---|---|---|---|
| `root` | — | Disabled for SSH; used only via sudo | nothing |
| `<ADMIN_USER>` | ✅ | Server ops, Ansible target, Coolify host admin | nothing persistent |
| `<DEV_USER>` | ❌ (docker group) | Your dev work, Claude Code + Codex, Multica daemon | Claude + ChatGPT subscription logins, GitHub auth |
| `<AGENT_USER>` | ❌ | Hermes gateway only | OpenRouter key, FAL key, Telegram tokens |
| `<TRADER_USER>` | ❌ | Trading-bot analyst timer only (doc 12) | Freqtrade REST creds, capped OpenRouter trading key, trader bot token |

**Iron rule:** API keys live only in the home of the user that needs them. `ANTHROPIC_API_KEY` must exist **nowhere** — if Claude Code sees it, it bills per-token API instead of the Pro subscription.

## 5. Port & exposure map

| Service | Port | Exposure |
|---|---|---|
| SSH | 22 | Public, key-only, Fail2Ban |
| HTTP/HTTPS (Traefik) | 80/443 | Public (apps; demos behind basic-auth) |
| Coolify dashboard | 8000 | **Tailscale/SSH-tunnel only** |
| Multica UI/API | 3000/8080 | **Tailscale only** |
| Hermes gateway | none inbound | Outbound Telegram polling only |
| Freqtrade REST/FreqUI | 8080 (container) | **localhost/Tailscale/SSH-tunnel only** — never public (doc 12 §6) |
| MySQL/Postgres | internal | Docker network only, never public |

## 6. RAM budget (12 GB + 4 GB swap)

Coolify+proxy ~1.2 · staging app+MySQL ~0.8 · Multica stack ~1.2 · Hermes ~0.6 · Claude Code session 0.5–1.5 · demos 0.5–1.5 each · OS ~0.6 → **comfortable for ~2–3 demos + 1–2 concurrent agent sessions.** Sustained >85% RAM or heavy swap during builds = resize to Cloud VPS 30 (live migration, no rebuild).

## 7. Document index & build order

| Doc | Covers | Depends on |
|---|---|---|
| 01 | Base server + IaC (Ansible) | — |
| 02 | Coolify, wildcard subdomains, demo apps | 01 |
| 03 | Remote dev environment | 01 |
| 04 | Claude Code as the dev team | 03 |
| 05 | Hermes orchestrator + profiles | 01 |
| 06 | Multica integration | 02, 04, 05 |
| 07 | Real-world agentic workflows | 04–06 |
| 08 | Security, secrets, backups | all |
| 09 | The AI org: agents & skills pipeline | 04–07 |
| 10 | Token-efficiency toolkit | 04 |
| 11 | Platform engineer agents & skills catalog | 09 |
| 12 | AI trading bot (Freqtrade × Binance × LLM analyst) | 02, 05, 07, 08 |
| 13 | Full tech company: product, design, architecture & marketing roles | 04, 09, 11 |
| 14 | Hermes enhancements: personal-assistant data layer & ops capabilities | 05, 06, 07, 08 |
| 15 | Multica agents, skills & squads (the roster as a Multica team) | 06, 09, 11, 13 |
| 16 | The scripts project (Hermes ops toolkit, built via Multica) | 06, 11, 14, 15 |

## 8. Reuse notes (SaaS / clients)

- This doc set + the Ansible toolkit **is** the productizable unit: fill §1, run playbook, follow 02–08.
- Per-client swaps: OpenRouter → **LiteLLM virtual key** (one config line in Hermes); Multica → omit or license-check; family profile → "client team" profile.
- Keep one copy of these docs per client with their variables table filled — that becomes the client's runbook.

## 9. Next milestones (explicitly out of current scope)

Per CLAUDE.md rule 6, none of this gets built unless an issue explicitly says so:

- **AppFlowy** (Docker Compose resource in Coolify, Postgres + Redis, Tailscale-first).
- **Full monitoring stack** (Uptime Kuma, disk/RAM/error alerting) — the W5 briefing (doc 07) covers the gap meanwhile.
- **Production migration off Laravel Cloud** — requires tested offsite restores, live monitoring, a rollback plan, and a topology decision (second server or dedicated-core tier; staging and production should not share a box).
- **Terraform layer** (provider provisioning + Coolify resources once its providers pass 1.0).
- **LiteLLM self-hosted proxy** — the productization swap for OpenRouter (docs 00 §8, 05 §9).
