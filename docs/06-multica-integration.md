# 06 — Multica: The Agent Task Board

**Goal:** Multica self-hosted on the VPS as `<DEV_USER>`, UI reachable at `multica.<DOMAIN>` via the existing Traefik proxy (Coolify), its daemon registering Claude Code (and Hermes) as runtimes, so tasks become assignable issues — by you in the UI, or by Hermes from Telegram.

**Why Multica:** coding agents execute well but have no management layer. Multica adds the missing piece — an issue board where agents are teammates: assign a task, the agent works autonomously, reports blockers, updates progress; skills compound across tasks. It auto-detects installed agent CLIs (Claude Code, Hermes, Codex, and others) and registers a runtime for each.

> ⚖️ **License caveat (matters for your SaaS):** Multica's terms restrict using its source to provide a hosted service to third parties or embedding it in a product without written authorization. **Personal/internal use: fine. Reselling it inside your product: requires their OK.** Architect the SaaS so Multica is optional glue, not a core dependency — or get authorization first.

---

## 1. Architecture on this box

```
Traefik (coolify-proxy)
  └─ multica.<DOMAIN> → Docker network → frontend :3000
                      → /api/* /ws/*  → backend  :8080

Multica Docker Compose (127.0.0.1, managed by dev user)
  ├─ multica-frontend-1  :3000
  ├─ multica-backend-1   :8080  (host port → 8090, avoids Coolify proxy conflict)
  └─ multica-postgres-1

Multica daemon (runs as <DEV_USER>)
  └─ detects: claude ✓  codex ✓  hermes ✓ → registers runtimes
     workspaces: /home/<DEV_USER>/projects/*
```

> **Port conflict:** `coolify-proxy` (Traefik) owns `0.0.0.0:8080`, which covers all interfaces including loopback. Multica's backend must expose on a different host port (`BACKEND_PORT=8090`). Docker networking (not host ports) handles Traefik ↔ backend traffic.

---

## 2. Install the server (as `<DEV_USER>`)

```bash
# Clone the official repo (installs to ~/.multica/server — matches existing install path)
git clone https://github.com/multica-ai/multica.git ~/.multica/server
cd ~/.multica/server

# make selfhost: generates .env with random creds, pulls images, starts services
make selfhost
```

If `.env` already exists from a prior install, `make selfhost` will use it. First boot runs DB migrations automatically.

---

## 3. Configure `.env`

Edit `~/.multica/server/.env`:

```bash
# Change these from auto-generated defaults:
JWT_SECRET=<openssl rand -hex 32>      # change if auto-generated value looks weak

# Port conflict fix — Coolify proxy owns 0.0.0.0:8080; use 8090 on the host side
BACKEND_PORT=8090

# Required once domain is live — tells the frontend its public origin
FRONTEND_ORIGIN=https://multica.<DOMAIN>

# Email (for login codes) — without this, codes print to backend logs
RESEND_API_KEY=<key>
RESEND_FROM_EMAIL=noreply@<DOMAIN>
# OR use SMTP:
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587
# SMTP_USERNAME=...
# SMTP_PASSWORD=...

# Remove or leave empty before any public deployment:
MULTICA_DEV_VERIFICATION_CODE=
```

After editing, restart the stack:

```bash
cd ~/.multica/server
docker compose -f docker-compose.selfhost.yml -f docker-compose.override.yml down
docker compose -f docker-compose.selfhost.yml -f docker-compose.override.yml up -d
```

---

## 4. Expose via Traefik (domain access)

Multica's compose binds to `127.0.0.1` — correct and intentional (Docker bypasses UFW if bound to `0.0.0.0`). To route the public domain through Coolify's existing Traefik, add a compose override that joins the `coolify` Docker network and adds Traefik labels. Docker Compose merges override files automatically.

Create `~/.multica/server/docker-compose.override.yml`:

```yaml
# Traefik routing for multica.<DOMAIN>
# Verify: docker network ls | grep coolify  (network name may include a prefix)

networks:
  coolify:
    external: true

services:
  backend:
    networks:
      - default
      - coolify
    labels:
      - traefik.enable=true
      - traefik.docker.network=coolify
      - traefik.http.routers.multica-api.rule=Host(`multica.<DOMAIN>`) && (PathPrefix(`/api`) || PathPrefix(`/ws`))
      - traefik.http.routers.multica-api.entrypoints=https
      - traefik.http.routers.multica-api.tls.certresolver=letsencrypt
      - traefik.http.routers.multica-api.priority=10
      - traefik.http.services.multica-api.loadbalancer.server.port=8080

  frontend:
    networks:
      - default
      - coolify
    labels:
      - traefik.enable=true
      - traefik.docker.network=coolify
      - traefik.http.routers.multica.rule=Host(`multica.<DOMAIN>`)
      - traefik.http.routers.multica.entrypoints=https
      - traefik.http.routers.multica.tls.certresolver=letsencrypt
      - traefik.http.routers.multica.priority=1
      - traefik.http.services.multica.loadbalancer.server.port=3000
```

> **Verify the network name** before applying: `docker network ls | grep coolify`. If Coolify prefixes it (e.g. `coolify_network`), update the `external: true` block and `traefik.docker.network` label accordingly.

Restart after creating the override. **Both `-f` flags are required** — Docker only auto-loads `docker-compose.override.yml` when no `-f` is specified; with an explicit `-f`, you must list every file:

```bash
cd ~/.multica/server
docker compose -f docker-compose.selfhost.yml -f docker-compose.override.yml down
docker compose -f docker-compose.selfhost.yml -f docker-compose.override.yml up -d
```

---

## 5. DNS

Add an A record in your DNS provider:

```
Type:  A
Name:  multica
Value: <SERVER_IP>
TTL:   600
```

Traefik provisions the Let's Encrypt cert automatically on first HTTPS request once DNS propagates.

---

## 6. Install the CLI (no sudo — `<DEV_USER>` for daemon; `<AGENT_USER>` for Hermes bridge)

The official installer tries to write to `/usr/local/bin` (requires sudo). Install to `~/.local/bin` instead:

```bash
# Check current version at: https://github.com/multica-ai/multica/releases/latest
MULTICA_VER=0.3.21

curl -fsSL "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VER}/multica-cli-${MULTICA_VER}-linux-amd64.tar.gz" \
  -o /tmp/multica-cli.tar.gz

mkdir -p ~/.local/bin
tar -xzf /tmp/multica-cli.tar.gz -C ~/.local/bin
chmod +x ~/.local/bin/multica

# Add to PATH if not already present
grep -q '\.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

multica --version
```

---

## 7. Connect daemon + workspaces

Point the CLI at the domain (cross-machine URL, full TLS):

```bash
multica setup self-host \
  --server-url https://multica.<DOMAIN> \
  --app-url https://multica.<DOMAIN>

multica daemon status   # → running; lists detected agents: claude, codex, hermes
```

Workspaces = `~/projects/*` repos (auto-discovered or added in the UI). Multica runs tasks in **isolated git worktrees** — an agent task never dirties your checked-out branch.

---

## 8. First login

1. Open `https://multica.<DOMAIN>` → enter your email.
2. If no email provider is configured: `docker compose -f ~/.multica/server/docker-compose.selfhost.yml logs backend | grep -i code`
3. Enter the code → create your workspace.

---

## 9. Working model

1. **Create an issue** (UI or via Hermes): title + description = the agent's brief. Write briefs like you'd brief a junior dev: acceptance criteria, files/areas involved, "open a PR".
2. **Assign to a runtime** — Claude Code or Codex per the tech-lead's routing (doc 04 §7.5): Claude for planning-heavy/role-gated work, Codex for well-scoped implementation; Hermes for non-code issues.
3. Agent works in its worktree → branch → **PR** (GitHub branch protection from doc 04 still gates main — Multica doesn't bypass your guardrails).
4. You review/merge → Coolify webhook deploys → done.
5. **Skills**: when a task type repeats, distill it into a Multica skill so the next assignment starts smarter.

Subscription discipline: assign tasks **sequentially per runtime** — Claude tasks share the Claude Pro pool (doc 04 §1.2), Codex tasks the ChatGPT Plus pool (doc 04 §7.5). Two runtimes = two pools: one task on each can run side by side, but never parallelize within a pool.

---

## 10. The Hermes bridge (Telegram → task board)

Two integration levels — start with A, add B when wanted:

- **A. CLI wrapper (done):** the `multica` plugin (`hermes/plugins/multica/` in this repo) is wired into the ops profile (runs as `<DEV_USER>`). The ops Hermes user already has the multica CLI authenticated. Hermes can: *"create an issue: fix the date bug on invoices, assign to claude"* and *"what's the team working on?"*.
- **B. Hermes as a Multica runtime:** the daemon already detects `hermes` — assign *non-coding* issues (research, content, ops checks) to Hermes from the same board. One board, two kinds of teammate.

> **Note on the ops profile user split (doc 05 §3):** Hermes ops now runs as `<DEV_USER>`, so it shares the same `multica` CLI authentication and docker group membership. No separate PAT for Hermes is needed — it's the same user.

Webhook/notification flow (Multica → Telegram "PR ready") can ride Hermes' cron ("every 30 min, report newly completed Multica issues") until you wire real-time notifications.

---

## 11. Validation

- [ ] `https://multica.<DOMAIN>` loads with valid TLS cert; Let's Encrypt issued by Traefik.
- [ ] Login code received via email (or retrieved from backend logs).
- [ ] `multica daemon status` → running; `claude`, `codex`, and `hermes` runtimes all detected.
- [ ] End-to-end smoke test: create issue "add a /version route returning the git SHA" in a sandbox repo → assign Claude Code → PR appears → merge → Coolify deploys → route live.
- [ ] From Telegram (ops bot): create + list an issue via the bridge plugin.
- [ ] Postgres volume + `~/.multica/server/.env` added to backup matrix (doc 08).

---

## 12. Reuse notes

- For clients: Multica is **your internal tool** for delivering work to client repos — that's internal use. Don't ship it as a customer-facing component of the SaaS without license clearance.
- The issue-brief format (§9.1) is worth templating in your infra repo — consistent briefs are the highest-leverage input to agent output quality.
- The compose override pattern (`docker-compose.override.yml`) survives `make selfhost` re-runs since it lives alongside the official file and is not touched by the installer.
