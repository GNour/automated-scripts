# 07 — Real-World Agentic Workflows

**Goal:** the concrete workflows this stack exists for — autonomous development and personal assistance — each with trigger → flow → guardrails. Plus the autonomy model that keeps "autonomous" from meaning "unsupervised."

---

## 1. The autonomy model (read this first)

Every capability in the system maps to a tier. The tiers are enforced by *mechanisms* (branch protection, allowlists, sandboxes, scoped tokens), not by trusting the model:

| Tier | Meaning | Examples | Enforcement |
|---|---|---|---|
| **T0 — Free** | No side effects | chat, research, planning, image gen | — |
| **T1 — Read** | Observes systems | logs, deploy status, DB read-only, Multica list | read-only tokens/users |
| **T2 — Write, gated** | Changes things behind a human gate | code → **PR** (you merge), create Multica issues, draft content | GitHub branch protection; you = the gate |
| **T3 — Dangerous** | Direct mutation | restart/redeploy apps, run migrations, delete anything | explicit confirmation phrase in Telegram + audit log; smallest possible allowlist |

**Design stance:** agents live at T0–T2 by default. T3 exists only for a short, named list of ops actions (restart app, redeploy, clear cache) and each one echoes back what it's about to do and waits for "confirm". Anything not on the T3 list simply has no tool — the family profile is the extreme case: T0 only (+ reminders).

Where each component sits: Family Hermes = T0 · Ops Hermes = T0–T2 + named T3 list · Claude Code = T2 (its world ends at the PR) · Multica = T2 (orchestrates T2 workers).

---

## 2. Development workflows (the autonomous dev team)

### W1 — Feature from your pocket (the flagship)
**Trigger:** Telegram → ops bot: *"New feature for app-x: clients can export invoices as PDF. Plan it first."*
**Flow:** Hermes drafts a plan (scope, files touched, acceptance criteria) → you approve/adjust in chat → Hermes creates a Multica issue with the refined brief → Multica assigns Claude Code → worktree, branch `feat/...`, implements with tests, Playwright-verifies the UI, opens PR → Hermes (cron bridge) notifies you with the PR link → you review on phone/laptop, merge → Coolify auto-deploys staging → Hermes confirms `/up` green.
**Guardrails:** plan approved before any code (T2 gate #1); PR review (gate #2); staging-only deploy target; one issue at a time (Pro pool).

### W2 — Bug → fix
**Trigger:** *"Invoices page 500s on staging"* (or Hermes' own health cron catches it).
**Flow:** Hermes pulls recent app logs via the Coolify plugin (T1), summarizes root-cause hypothesis → with your go-ahead, opens a Multica issue containing the stack trace → Claude Code reproduces via a failing test, fixes, PR → merge → deploy → Hermes re-checks the failing route.
**Guardrails:** logs are read-only; the *fix* still rides the full PR gate.

### W3 — New client demo, end to end
**Trigger:** *"Spin up a demo of repo-y for client Z, basic-auth, call it z-demo."*
**Flow:** Hermes creates the Coolify app via API from the repo (doc 02 pattern), sets domain `z-demo.<DOMAIN>` + basic-auth credential, deploys, smoke-checks, replies with URL + credentials (sent privately).
**Guardrails:** creation from an allowlisted repo set; T3 confirmation before creating public-facing resources; credentials generated, never reused.

### W4 — Code review on demand
**Trigger:** *"Review PR #87 on app-x before I merge."*
**Flow:** Multica issue assigned to Claude Code's `code-reviewer` subagent (read-only) → review comment posted on the PR: risks, missed tests, style.
**Guardrails:** reviewer has no write tools; merging stays yours.

## 3. Personal-assistant workflows

### W5 — Morning briefing (ops, cron)
*"Every weekday 08:00"* → Hermes assembles: Coolify health across apps, overnight Multica completions + open PRs awaiting your review, calendar (if connected via MCP), 3 relevant news items → one Telegram message. T1 only — briefings never mutate anything.

### W6 — Family assistant (family bot)
Homework help, trip ideas, recipe images ("draw the birthday cake idea"), reminders ("remind Dana piano at 5"), voice notes auto-transcribed. All T0. The deliberate showcase: same server, zero blast radius.

### W7 — Research → brief → build (the bridge workflow)
*"Research current best practice for Laravel PDF generation, write a recommendation, and if I approve, brief the team."* → Hermes researches (T0) → posts a comparison with a recommendation → on "approve", converts it into a Multica issue brief (T2) → W1 takes over. This is the pattern that makes Hermes a *product owner*, not just a chatbot.

### W8 — Ops one-liners (the named T3 list)
*"Restart app-x"* / *"redeploy staging"* / *"clear app-x cache"* → Hermes echoes the exact action + target → waits for **"confirm"** → executes via scoped Coolify token → reports result. Every T3 action lands in an audit log (doc 08).

## 4. Hermes profile design — recommended final shape

| | **Ops profile** | **Family profile** |
|---|---|---|
| Audience | you only | family allowlist |
| Role | orchestrator + PA | assistant + creative |
| Tiers | T0–T2, named T3 | T0 |
| Tools | search, images, cron, exec(Docker), coolify, multica | search, images(schnell), cron |
| Model | stronger planning model | cheapest capable |
| Tone/system prompt | terse, technical, asks before assuming | warm, simple, kid-safe answers |

Two profiles is the right number now. A third ("client-facing concierge") only when a real client workflow demands it — and that one becomes the SaaS prototype.

## 5. Rollout order (don't build all eight at once)

1. **W5** (briefing) — exercises Coolify plugin + cron, zero risk.
2. **W6** (family) — independent, instant value.
3. **W1** on a sandbox repo — the core loop, tuned where mistakes are free.
4. **W2, W8** — ops muscles, T3 confirmations proven.
5. **W3, W4, W7** — compounding extras.

Each workflow that works → distill into a Hermes/Multica skill so the next run is cheaper and more reliable.

## 6. Reuse notes

- The tier table is your **SaaS security story** verbatim: customers get profile templates = tier bundles (Starter: T0–T1; Pro: +T2; Business: +named T3). Pricing maps to autonomy.
- W3 (demo provisioning) is itself a sellable service: "demo environment per feature branch" for client teams.
