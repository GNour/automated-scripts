# 05 — Hermes Agent: Orchestrator & Personal Assistant

**Goal:** Hermes running with two Telegram personas on two separate OS users — an **ops profile** (you: full orchestrator, drives Multica/Claude Code/Coolify, runs as `<DEV_USER>`) and a **family profile** (assistant + images, zero infra reach, runs as `<AGENT_USER>`) — on OpenRouter for text and FAL for images.

**Why Hermes:** open-source, model-agnostic agent with a messaging gateway (Telegram and 20+ platforms), persistent memory, self-generated skills, natural-language cron, plugins, MCP support, and sandboxed execution backends. It's the layer that makes the server *conversational*.

**Why two profiles:** Telegram access = capability access. Family members must never be able to trigger shell execution, deployments, or dev workflows — so they get a separate bot bound to a restricted toolset. Profiles are Hermes-native (separate config/session/memory per profile, one gateway process each, one bot token each).

---

## 1. Install

Install Hermes for **both users** independently. Each user gets their own `~/.hermes/` (config, memory, skills, plugins, logs) — profiles never share state.

```bash
# As <DEV_USER> (ops profile):
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
hermes --version
hermes setup        # wizard: provider, tools, gateway — we override below

# As <AGENT_USER> (family profile):
sudo -u <AGENT_USER> bash -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'
```

Both `~/.hermes/` directories are in the backup matrix (doc 08).

## 2. Providers

### 2.1 Text → OpenRouter
Create key at openrouter.ai → set a **monthly spend cap on the key** (your budget guard, ~$10–15).

```yaml
# ~/.hermes/config.yaml (shape; confirm against current docs / `hermes model`)
provider:
  type: openrouter
  api_key: ${OPENROUTER_API_KEY}        # from ~/.hermes/.env or user env — never world-readable
model:
  default: <cost-efficient model>        # pick via `hermes model`: Gemini Flash / DeepSeek / Haiku class
  # ops profile may pin a stronger model for planning; family stays on the cheap default
```

### 2.2 Images → FAL (two tiers)
Hermes **bundles** a FAL image provider (env `FAL_KEY`; model fixed via `image_gen.model` — no per-request override, and FLUX schnell has left the catalog). The two tiers therefore split as:
- **default**: the built-in provider on the fast/cheap model (`fal-ai/flux-2/klein/9b`, FLUX 2 Klein — schnell's successor) — family use, drafts.
- **quality**: the `fal_image_hq` plugin (`hermes/plugins/fal_image_hq/` in the infra repo) adds a `generate_image_hq` tool calling FLUX 2 Pro directly — only profiles that list the tool get it, so family stays on the cheap tier by construction.

Set a spend alert in the FAL dashboard. Note Hermes plugins are **directories** (`plugin.yaml` + `register(ctx)` module), opt-in via `plugins.enabled` in config — see `hermes/README.md`.

## 3. The two profiles

### 3.1 Create two bots (@BotFather)
`/newbot` twice → `<OPS_BOT>` and `<FAMILY_BOT>` tokens. **One token per profile — never share a token across gateways** (Telegram rejects concurrent polling). Get each person's numeric Telegram ID (e.g. via @userinfobot).

### 3.2 Ops profile — the orchestrator (runs as `<DEV_USER>`)

Config lives at `/home/<DEV_USER>/.hermes/config.yaml` (default profile for that user).

```yaml
# /home/<DEV_USER>/.hermes/config.yaml
telegram:
  token: ${TELEGRAM_OPS_TOKEN}
  allowed_users: [<YOUR_TELEGRAM_ID>]        # hard allowlist — bot ignores everyone else
display: { tool_progress: "new" }            # see what it's doing, without log spam
tools:   # full set
  - web_search
  - image_generation
  - execute_code        # Docker backend — <DEV_USER> is in docker group (doc 01 §3.1)
  - cron
  - coolify             # plugin: scoped API token (status/logs/restart/deploy)
  - multica             # plugin: create/list/assign issues, delegate to Claude/Codex
  - image               # plugin: generate_image_hq (FLUX 2 Pro)
```

### 3.3 Family profile — the assistant (runs as `<AGENT_USER>`)

Config lives at `/home/<AGENT_USER>/.hermes/config.yaml` (only profile for that user).

```yaml
# /home/<AGENT_USER>/.hermes/config.yaml
telegram:
  token: ${TELEGRAM_FAMILY_TOKEN}
  allowed_users: [<FAMILY_ID_1>, <FAMILY_ID_2>, ...]
display: { tool_progress: "off" }
tools: [web_search, image_generation, cron]   # chat, images, reminders — NOTHING else
# no execute_code, no coolify, no multica, no MCPs, no filesystem
```

Security is enforced at two levels: `<AGENT_USER>` has no docker group and no sudo (OS boundary), and the Hermes config omits all infra tools (config boundary). Both gates must pass for a family user to reach infra — they can't.

## 4. Execution sandbox (ops profile only)

Hermes offers local/Docker/SSH/etc. execution backends. **Use the Docker backend, never local**, so "run code" means *inside a throwaway container*, not on the host as `<AGENT_USER>`:

```yaml
execution:
  backend: docker
  image: python:3.12-slim       # or a custom toolbox image
  network: none                  # default-deny; enable per-task only when needed
  mounts: []                     # no host filesystem by default
```

`<DEV_USER>` is already in the `docker` group (doc 01 §3.1) — no proxy needed. `<AGENT_USER>` (family) has no docker group and no `execute_code` tool, so this section is irrelevant to it. Heavy dev work isn't done here anyway — it's delegated to Multica→Claude Code; Hermes' sandbox is for small one-off computations.

## 5. Run as services (systemd, survives reboots)

Service units are managed by Ansible (`users` role — `hermes-ops.service.j2`, `hermes-family.service.j2`). The key difference:

```ini
# hermes-ops.service — User=<DEV_USER>; default profile
[Service]
User=<DEV_USER>
EnvironmentFile=/home/<DEV_USER>/.hermes/.env
ExecStart=/home/<DEV_USER>/.local/bin/hermes gateway start --foreground

# hermes-family.service — User=<AGENT_USER>; -p family flag
[Service]
User=<AGENT_USER>
EnvironmentFile=/home/<AGENT_USER>/.hermes/.env
ExecStart=/home/<AGENT_USER>/.local/bin/hermes gateway start -p family --foreground
```

```bash
sudo systemctl enable --now hermes-ops hermes-family
sudo systemctl status hermes-ops hermes-family
```

(If `hermes gateway` lacks a foreground flag in your version, check `hermes gateway --help`.)

## 6. Assistant capabilities to switch on (both profiles where sane)

- **Cron briefings:** natural-language scheduling — ops: "every weekday 08:00, summarize Coolify health, open Multica issues, and my calendar"; family: homework reminders, weekly meal-plan prompt.
- **Voice notes:** Telegram voice → auto-transcribed → handled like text. Zero config beyond the gateway.
- **Memory + skills:** on by default; the agent builds a model of each user and saves how it solved things. Review what it's learned occasionally: `~/.hermes/` memory files.

## 7. Security checklist (this host runs your life — treat it so)

- [ ] Bot tokens + API keys only in user-readable `.env` files (`chmod 600`), never in repo.
- [ ] `allowed_users` set on **both** profiles; test from a non-allowlisted account → silence.
- [ ] Family profile genuinely cannot exec: ask it to "run ls" → refuses/lacks tool.
- [ ] Ops `execute_code` runs in Docker with no mounts/network by default.
- [ ] `<AGENT_USER>` (family) not in docker group: `id hermes | grep docker` → nothing.
- [ ] OpenRouter key capped; FAL alert set.
- [ ] Both `~/.hermes/` dirs in restic backup (doc 08) — losing them = agents forget everything.

## 8. Validation

- [ ] Both gateways active (`systemctl status hermes-ops hermes-family`), bots respond on Telegram.
- [ ] Ops (as `<DEV_USER>`): `multica issue list` works; Coolify plugin returns real status.
- [ ] Ops: `multica issue create --title "test" && multica issue list` → issue appears.
- [ ] Family: image request returns a FLUX 2 Klein image; "deploy my app" goes nowhere.
- [ ] `id hermes | grep docker` → empty (OS boundary confirmed).
- [ ] Reboot → both bots come back unaided.

## 9. Reuse notes

- This whole doc is the **per-customer unit of your future SaaS**: one isolated Hermes (container/VPS) + their bot token + a **LiteLLM virtual key** instead of your OpenRouter key (one config swap — same OpenAI-compatible shape) + tier-appropriate model allowlists/budgets enforced at the proxy. The family profile *is* the prototype of a customer profile.
- Keep a `profile-templates/` folder (ops.yaml, assistant.yaml) in your infra repo; onboarding = copy, fill token + IDs.
