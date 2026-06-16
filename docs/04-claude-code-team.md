# 04 — Claude Code as the Dev Team

**Goal:** Claude Code installed under `<DEV_USER>`, billed on the **Pro subscription** (never per-token), equipped with project conventions, skills, subagents, and MCPs — usable interactively by you and headlessly by Multica.

**Why Claude Code:** a terminal-native coding agent that reads the whole repo, edits files, runs tests/builds, and opens PRs. It *is* the dev team; Multica (doc 06) is its task queue; Hermes (doc 05) is how you talk to the team from your pocket.

---

## 1. Install & subscription auth (as `<DEV_USER>`)

```bash
curl -fsSL https://claude.ai/install.sh | bash   # official installer; verify current command at docs.claude.com
claude --version
claude               # first run → choose subscription login (browser device-flow works headless)
```

Inside Claude Code, `/status` should show your **Pro plan**, not API credits.

### 1.1 🔴 The billing gotcha (protect the $20/mo)

If `ANTHROPIC_API_KEY` is set in the environment, Claude Code silently uses it → **per-token API charges** instead of the subscription. Defense, all three:

1. Never export it in `<DEV_USER>`'s shell init files.
2. Other keys (OpenRouter/FAL) live only in `<AGENT_USER>`'s home (doc 05) — different Linux user, can't leak across.
3. Guard rail in `~/.bashrc`: `unset ANTHROPIC_API_KEY` (cheap insurance against a stray `.env` source).

### 1.2 Pro-tier discipline

Pro shares one usage pool across Claude chat + Claude Code (5-hour session windows + weekly caps). Practices that stretch it: keep tasks scoped (one issue = one session), `/clear` between unrelated tasks, let Multica queue rather than parallelize agent runs, check `/usage` when planning a heavy day. Hitting caps most days = the documented Max 5x upgrade trigger; occasional overflow can use Anthropic's pay-as-you-go usage credits with a monthly cap instead.

## 2. Project conventions — `CLAUDE.md` (the team handbook)

Every repo gets a `CLAUDE.md` at root; Claude Code reads it automatically. Template:

```markdown
# CLAUDE.md
## Project
<one-paragraph: what this app is, stack: Laravel 12 / PHP 8.4 / MySQL / Vite>

## Commands
- setup: composer install && npm ci
- test: php artisan test          # run before every commit
- lint: ./vendor/bin/pint
- build: npm run build

## Rules
- NEVER commit to main. Branch `feat/<issue>` or `fix/<issue>`, open a PR.
- NEVER touch .env or commit secrets.
- Migrations: additive only unless the task explicitly says otherwise.
- Follow existing code style; small focused diffs; update tests with code.

## Architecture notes
<key dirs, domain language, gotchas>
```

A global `~/.claude/CLAUDE.md` holds cross-project rules (tone of PR descriptions, commit format `type(scope): subject`, "ask via PR comment when uncertain").

## 3. Permission guardrails (defense in depth)

`~/.claude/settings.json` — sensible team defaults:

```json
{
  "permissions": {
    "allow": ["Bash(php artisan test:*)", "Bash(npm run *)", "Bash(git *)", "Bash(gh pr *)"],
    "deny":  ["Bash(git push origin main)", "Bash(rm -rf *)", "Read(.env*)", "Read(**/secrets/**)"]
  }
}
```

**Primary enforcement is GitHub, not the agent:** enable **branch protection on `main`** (require PR + your review) in every repo. Then even a misbehaving session physically cannot ship to main. PR-only is policy *and* mechanism.

## 4. Skills & subagents (the team's specialists)

- **Skills** (`~/.claude/skills/<name>/SKILL.md`): reusable how-tos the agent loads on demand. Start with three: `laravel-feature` (migration→model→test→controller→route order, project test patterns), `coolify-deploy-check` (how to verify a deploy via Coolify API/logs), `pr-quality` (PR description format, screenshot/test evidence expectations).
- **Subagents** (`.claude/agents/*.md` per repo or `~/.claude/agents/` global): role-scoped helpers Claude Code delegates to. Start with: `code-reviewer` (read-only tools, reviews the diff before PR), `test-writer` (writes/repairs tests only). Keep the roster small; add roles when a real workflow repeatedly needs one.

Grow both organically: when you correct the agent twice for the same thing, that correction becomes a skill line.

## 5. MCP servers (the team's tool belt)

MCP = Model Context Protocol, the standard for giving agents external tools. Configure as `<DEV_USER>`; verify exact commands/URLs in each server's current docs (they move fast):

| MCP | Gives the team | Notes |
|---|---|---|
| **GitHub** | Issues/PRs/repo ops beyond `gh` | `gh` CLI covers most; add MCP when workflows need richer queries |
| **Google Drive** | Read specs/briefs you store in Drive | OAuth on a headless box: run the auth flow with VS Code port-forward, or connect Drive on desktop Claude and keep VPS scope lean |
| **Context7** | Current Laravel/Node/library docs | Kills outdated-API suggestions; cheap, high value |
| **Playwright** | Real-browser testing of demos | Agent verifies UI before claiming "done"; install browsers once (`npx playwright install --with-deps chromium`) |
| **MySQL (read-only)** | Inspect staging schema/data | Create a dedicated read-only DB user; never the app's write credentials |
| **Coolify** | Deploy status, logs, restart | Scoped Coolify API token; community server or thin custom wrapper |

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp     # pattern; repeat per server
claude mcp list
```

Lean rule: an MCP earns its slot when a workflow in doc 07 uses it; otherwise it's context-window tax.

## 6. Headless mode (how Multica drives it)

```bash
claude -p "Implement #42 per the issue description. Branch fix/42, run tests, open a PR." \
  --output-format json
```

Headless runs use the same auth, CLAUDE.md, settings, and MCPs — configuration done once here powers both your interactive sessions and every Multica-dispatched task. Multica handles invocation; you only ensure this doc's setup is green first.

## 7. Second runtime: Codex CLI (the ChatGPT Plus seat)

The dev team runs **two coding agents on the same workspace**: Claude Code (Claude Pro) and Codex CLI (ChatGPT Plus). Multica registers each installed CLI as its own runtime (doc 06 §1) — two subscription pools feeding one task board.

### 7.1 Install & subscription auth (as `<DEV_USER>`)

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh   # official; verify at developers.openai.com/codex/cli
codex --version
codex            # first run → "Sign in with ChatGPT" (Plus plan, device flow works headless)
```

### 7.2 🔴 The billing gotcha, OpenAI edition

Same class as §1.1: a stray `OPENAI_API_KEY` can flip Codex to per-token API billing. Defense, both:

1. Never export it in `<DEV_USER>`'s shell init; the devtools role adds `unset OPENAI_API_KEY` right next to the Anthropic guard.
2. Pin auth in `~/.codex/config.toml`: `preferred_auth_method = "chatgpt"` (template in `codex-config/`).

### 7.3 Project conventions — AGENTS.md is the canonical handbook

Codex reads **AGENTS.md**, not CLAUDE.md — and Claude Code reads CLAUDE.md, not AGENTS.md. The org's single-source rule: every app repo keeps the full handbook (incl. the Team block) in `AGENTS.md`; `CLAUDE.md` is one line — `@AGENTS.md` (the official import pattern). Templates in `templates/`. Global rules for Codex live at `~/.codex/AGENTS.md` (payload: `codex-config/`).

### 7.4 Headless

```bash
codex exec "Implement #42 per the issue description. Branch fix/42, run tests, open a PR."
```

Multica drives it exactly as it drives `claude -p` (§6).

### 7.5 Routing & two-pool discipline

- The tech-lead routes **per task** (doc 09 §3.2): Claude Code for planning-heavy, multi-file, or role-gated work (subagents exist only there); Codex for well-scoped, single-area implementation tasks. The per-role delegation table — which roles are Codex-eligible, and the always-Claude review gate — lives in **doc 09 §4.3**.
- Balance the pools: when one subscription's window is running hot, route to the other. One issue = one runtime = one session; never split an issue across runtimes.
- Codex has no subagents — its quality bar is carried entirely by AGENTS.md plus the task brief, which is why brief quality (doc 10 §3.5) matters double there.

## 8. Validation

- [ ] `/status` → Pro subscription; `echo $ANTHROPIC_API_KEY` → empty.
- [ ] `codex --version` works as `<DEV_USER>`; `echo $OPENAI_API_KEY` → empty; Codex signed in via ChatGPT plan.
- [ ] In a repo: ask Claude Code to make a trivial change → it branches, commits, opens a PR (never touches main).
- [ ] Same trivial-change test through `codex exec` → branch + PR, and it visibly followed AGENTS.md conventions.
- [ ] Direct push to `main` is rejected by GitHub branch protection (gates both runtimes identically).
- [ ] `claude mcp list` shows the table above; Context7 answers a Laravel-12 docs question.
- [ ] One headless `claude -p` run completes and returns JSON.

## 9. Reuse notes

- `~/.claude/` (global CLAUDE.md, skills, agents, settings) is exportable — version it in your infra repo as `claude-team-config/`; new server or client = copy + `claude login`.
- Per-client: their own GitHub App installation, their own repos' CLAUDE.md, their own branch protections. Subscription seat per operating identity — clients on your SaaS would run under *their* accounts or API keys via your LiteLLM layer, never your personal Pro login.
