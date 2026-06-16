# 13 — The Full Tech Company: Product, Design, Architecture & Marketing Roles

**Goal:** extend the engineering org (docs 09 + 11) into a *complete* tech company — the roles that decide **what** to build and **how it's sold**, not just the ones that write code: product managers, business analysts, system architects, designers, and marketing. Same mechanics as before — agents are files, work is PR-gated, Multica is the office — applied to the non-code half of a software company.

**Reads on top of:** doc 09 (the pipeline, shared roles, Team-block selection), doc 11 (the seven platform engineers), doc 04 §7 (two runtimes), doc 06 (Multica), doc 07 (autonomy tiers), doc 10 (token economy). This doc **never re-defines** a role those docs already own — it cites and extends.

---

## 1. The design problem (why this needs its own doc)

Doc 09's roster is deliberately code-centric: every role there reads or writes a *code* repo, so every role is a Claude Code subagent or the Hermes PO. The roles in this doc mostly produce **artifacts that aren't code** — PRDs, requirement specs, ADRs, user flows, UI specs, landing copy. Three questions decide how each becomes an agent:

1. **Where does the output live?** Conversation, or a versioned file?
2. **Which system runs it?** Hermes (dialogue), a Claude Code subagent (repo/artifact-bound), or Multica's non-code runtime.
3. **Does it pass a human gate?** All of them do — these roles stay T0–T2 (doc 07); none earns a T3 tool.

**The keystone decision — everything is a file, every change is a PR.** Product, design, and marketing outputs are committed as markdown + assets in a versioned repo, exactly like code. A PRD is `docs/product/<feature>.md`; an architecture decision is `docs/adr/NNNN-*.md`; landing copy is `marketing/<campaign>/copy.md`; a UI spec is `design/<feature>/spec.md` (+ optional HTML mockup). This buys, for free, what we already built for code:

- the same **PR gate** (doc 04 §3) — you approve a PRD the way you approve a diff;
- the same **Multica worktree → branch → PR** flow (doc 06 §9) for non-code teammates;
- versioned history, reuse across clients, and no new infrastructure.

Consequence: nearly every role below is a **Claude Code subagent** writing to a docs/design/marketing path. Only pure intake stays in Hermes (it's dialogue, no repo). This is the same boundary doc 09 §3 drew between the PO (Hermes) and the tech-lead (Claude) — generalized.

> **Runtime note (doc 04 §7.5):** these are planning-/writing-heavy, artifact-producing, role-gated tasks → they route to the **claude-code** runtime, which is the only one with subagents. Codex stays an implementer of well-scoped code tasks. The tech-lead never routes a `[discovery]`/`[design]`/`[content]` task to Codex.

---

## 2. The org chart, v2

Doc 09's chart covered build → review → merge. This adds the **discovery front-end** (what/why/how-it-looks, before the tech-lead) and the **go-to-market back-end** (after deploy):

```
                       YOU (CEO — the only human)
                              │ Telegram
                  ┌───────────▼───────────┐
                  │ PRODUCT OWNER (Hermes) │  idea → sharpened intake
                  └───────────┬───────────┘
   ── DISCOVERY ──────────────┼──────────────────────────────────────
                  ┌───────────▼───────────┐
                  │  PRODUCT MANAGER (sub) │  intake → PRD + roadmap slot
                  └───────────┬───────────┘
              ┌───────────────┼────────────────┐
              ▼               ▼                 ▼
        BUSINESS ANALYST  PRODUCT DESIGNER  TECH ARCHITECT
        (reqs/edge cases) (flows + UI spec) (ADR/system design)
              └───────────────┼────────────────┘
                              ▼  human gate: PRD + design + ADR approved
   ── DELIVERY (doc 09) ──────┼──────────────────────────────────────
                  ┌───────────▼───────────┐
                  │  TECH LEAD (doc 09)    │  approved scope → task plan
                  └───────────┬───────────┘
                     engineers (doc 11) → reviewer + security gate → YOU merge
                              ▼  Coolify deploys
   ── GO TO MARKET ───────────┼──────────────────────────────────────
                  ┌───────────▼───────────┐
                  │ CONTENT MARKETER (sub) │  shipped feature → release
                  └───────────────────────┘  notes, landing copy, docs
```

**Not every issue traverses every role** — that would violate doc 09/11's "slots are earned." §5 is the routing matrix that keeps a bug fix from triggering a PRD.

---

## 3. System placement — who runs where

| Role | System | Why there | Output home |
|---|---|---|---|
| Product Owner *(doc 09 §3.1)* | **Hermes** (ops profile) | Intake is dialogue; no repo | → a `[discovery]` issue |
| **product-manager** | Claude Code subagent | Reads code + existing docs to write a grounded PRD | `docs/product/*.md` |
| **business-analyst** | Claude Code subagent | Requirements rigor needs the codebase + PRD | `docs/product/*-requirements.md` |
| **tech-architect** | Claude Code subagent | System design must read current architecture | `docs/adr/NNNN-*.md` |
| **product-designer** | Claude Code subagent | Flows/UI specs reference real components & routes | `design/<feature>/` (+ HTML mockup) |
| **content-marketer** | Claude Code subagent | Accurate copy must read what actually shipped | `marketing/`, `docs/` (release notes) |
| Tech-writer *(doc 09 §4)* | Claude Code subagent | Already defined — extended in §4.6 | repo docs/`CHANGELOG` |

Conversational ideation (campaign brainstorms, "what should we build next?") can happen in **Hermes** as T0 chat; the moment it becomes a deliverable, it converts to a Multica issue routed to the right subagent — the W7 pattern (doc 07) generalized beyond engineering.

---

## 4. The new roster (agent specs)

Conventions inherited from doc 11 §"Conventions": agent file at `~/.claude/agents/<name>.md`; common header (CLAUDE.md compliance, small diffs, branch+PR, stop-and-ask when blocked); skills via the `skills:` frontmatter field so agent files stay short. ⭐ = build on day one of using that agent.

**Each spec is token-tuned (see §7).** Three frontmatter levers carry the cost discipline: `model` (right-size cognition per role), `effort` (reasoning budget: `low`→`max`), and `maxTurns` (hard cap on agentic loops). And **preload discipline:** the `skills:` field injects *full* skill content on every run (confirmed against Claude Code's subagent docs), so each agent preloads only its most-used skill(s); the rest stay invokable on-demand via the Skill tool. ⭐ marks build-priority, not preload.

Skills come in two flavors, per doc 10 §3.2:
- **Public skills** already on the box (e.g. `to-prd`, `to-issues`, `brainstorming`, `copywriting`, `copy-editing`, `brand-guidelines`, `frontend-design`, `design-taste-frontend`, `web-design-guidelines`, `doc-coauthoring`, `writing-plans`) — reuse, don't reinvent.
- **Org-convention skills** (`claude-team-config/skills/<name>/`) — thin layers that encode *our* format/standards on top of the public ones. These are where client-specificity lives (doc 09 §9).

### 4.1 product-manager

**Mandate:** turns a sharpened idea (from the PO) into a **PRD** — problem, target user, success metrics, scope/non-scope, prioritized acceptance criteria — and owns the lightweight roadmap. Decides *what* and *why*; never *how* (that's architect/tech-lead) and never *how it looks* (designer). Stops at the PRD; does not create `[task]` issues (that's the tech-lead after the gate).

```markdown
---
name: product-manager
description: Turns a [discovery] issue into a PRD — problem, users, success
  metrics, scoped acceptance criteria, non-goals. Produces a PRD doc, never
  implementation tasks or technical design.
tools: Read, Grep, Glob, Edit, Write   # reads code/docs; writes only docs/product/**
skills: prd-format            # ⭐ preloaded; roadmap/metrics on-demand (§7.2)
model: inherit                # → sonnet on Max/API (§7.1)
effort: medium
maxTurns: 15
---
```

| Skill | Kind | Purpose |
|---|---|---|
| ⭐ `prd-format` | org | Our PRD contract: problem statement, user story, success metrics (measurable), acceptance criteria (3–7 testable), explicit non-goals, open questions. Wraps the public `to-prd` skill with our headings |
| ⭐ `roadmap-discipline` | org | Where a PRD slots: now/next/later, one-feature-at-a-time (mirrors the Pro-pool discipline), how priority is argued not asserted |
| `metrics-definition` | org | Turning vague goals into instrumented, checkable success criteria |

### 4.2 business-analyst

**Mandate:** the rigor layer between PRD and build — requirements elicitation, edge-case enumeration, user-flow and data-flow mapping, acceptance-criteria sharpening, and "what did we forget?" The role that makes a PRD *implementable* without the engineer guessing.

```markdown
---
name: business-analyst
description: Hardens a PRD into precise requirements — edge cases, data flows,
  state transitions, acceptance-criteria rigor. Produces a requirements spec;
  flags ambiguities back to product-manager. No design or code.
tools: Read, Grep, Glob, Edit, Write
skills: requirements-spec, edge-case-enumeration   # both core every run
model: inherit                                      # → sonnet on Max/API (§7.1)
effort: medium
maxTurns: 15
---
```

| Skill | Kind | Purpose |
|---|---|---|
| ⭐ `requirements-spec` | org | Spec format: functional reqs, non-functional (perf/security/a11y), data dictionary, state-transition tables, traceability back to PRD criteria |
| ⭐ `edge-case-enumeration` | org | The systematic "ways this breaks" checklist: empty/null, limits, concurrency, permissions, failure modes — the input QA later turns into tests |
| `process-mapping` | org | User-journey and as-is/to-be flow capture (markdown + mermaid), no tooling needed |

### 4.3 tech-architect

**Mandate:** cross-cutting **system design** — distinct from the tech-lead's *per-issue tactical* decomposition (doc 09 §3.2). The architect owns technology selection, integration/boundary design, non-functional requirements, and **ADRs**; engages on net-new products or changes that cross module/service boundaries, not on routine features. Hands the tech-lead a sound shape to decompose within.

```markdown
---
name: tech-architect
description: System-level design for net-new or cross-cutting work — technology
  choices, service/module boundaries, integration contracts, non-functional
  requirements. Produces ADRs; reviews structural risk. Read-only on code.
tools: Read, Grep, Glob, Edit, Write   # writes only docs/adr/**
skills: adr-format, system-design-review   # ⭐ preloaded; api-contract-first on-demand
model: inherit                             # → opus on Max/API — hard judgment, spend here (§7.1)
effort: high
maxTurns: 20
---
```

| Skill | Kind | Purpose |
|---|---|---|
| ⭐ `adr-format` | org | The ADR template (context / decision / consequences / alternatives-rejected), numbering, where they live (`docs/adr/`). Pairs with the public `improve-codebase-architecture` skill which reads `docs/adr/` |
| ⭐ `system-design-review` | org | The checklist: scalability, failure isolation, data ownership, security boundaries, build-vs-buy, cost — what to interrogate before blessing a design |
| `api-contract-first` *(shared, doc 11 §8)* | org | When a project spans platforms, the architect owns the OpenAPI contract as the hand-off artifact |

**Architect vs tech-lead boundary:** architect = *should we, and in what shape?* (ADR, lives across many issues). Tech-lead = *given the blessed shape, what are the ordered tasks?* (plan, one issue). Small features skip the architect entirely — the tech-lead handles them, as today.

### 4.4 product-designer

**Mandate:** everything between "what" and "pixels in code" — user flows, information architecture, interaction design, and a **UI spec** (states, components, responsive/empty/error/loading) with an optional **HTML/CSS mockup** the frontend engineer builds against. Accessibility is in-scope, not an afterthought. Default to **one** designer role; split into `ux-designer` + `ui-designer` only when design volume justifies two slots (doc 09 §4.1 "earn the slot").

```markdown
---
name: product-designer
description: User flows, IA, interaction + visual design, and UI specs for any
  feature with an interface. Produces a design spec and optional HTML mockup
  the frontend engineer implements against. Owns accessibility at design time.
tools: Read, Grep, Glob, Edit, Write
skills: ui-spec-format, design-system-conventions   # ⭐ preloaded; brand/web-guidelines on-demand
model: inherit                                       # → sonnet on Max/API (§7.1)
effort: medium
maxTurns: 20
---
```

| Skill | Kind | Purpose |
|---|---|---|
| ⭐ `ui-spec-format` | org | The spec contract: every state (default/loading/empty/error/success), responsive breakpoints, component inventory, copy slots, a11y notes — what the frontend engineer needs to build with zero guesswork |
| ⭐ `design-system-conventions` | org | Our tokens/spacing/type scale; reuse existing components before inventing. Layers on the public `tailwind-design-system` / `frontend-design` skills |
| `brand-guidelines` *(public)* | public | Colors, typography, visual identity application |
| `web-design-guidelines` *(public)* | public | Accessibility + UX best-practice review of the produced mockup |
| `design-handoff` | org | The contract with frontend-web-engineer (doc 11 §4): spec + mockup location, what "implemented faithfully" means, who verifies in Playwright |

**Handoff chain:** product-designer's `design/<feature>/` spec is an input the tech-lead cites in the frontend task brief; the frontend-web-engineer's `playwright-verify` (doc 11 §4) walks the *designer's* acceptance states, not invented ones. Design and verification meet on the same artifact.

### 4.5 content-marketer

**Mandate:** the go-to-market voice — release notes, landing/feature copy, blog posts, changelog-for-humans, SEO basics, social announcements. Reads what actually shipped (so copy is true, not aspirational). Marketing *strategy* ideation can start as Hermes T0 chat; deliverables land here as PR'd files.

```markdown
---
name: content-marketer
description: Marketing and launch content for shipped work — release notes,
  landing copy, blog posts, announcements. Reads the merged feature so claims
  are accurate. Produces copy files; never touches app code.
tools: Read, Grep, Glob, Edit, Write   # writes only marketing/** and docs/**
skills: brand-voice            # ⭐ preloaded (tone every run); copy/release skills on-demand
model: inherit                 # → haiku on Max/API — cheapest cognition in the org (§7.1)
effort: low
maxTurns: 10
---
```

| Skill | Kind | Purpose |
|---|---|---|
| `copywriting` *(public)* | public | Writing new marketing copy from scratch |
| `copy-editing` *(public)* | public | Reviewing/refreshing existing copy |
| ⭐ `brand-voice` | org | Our tone, do/don't word list, claims policy (never promise unshipped features) — the client-specific layer |
| ⭐ `release-notes-format` | org | Human changelog vs technical CHANGELOG (the tech-writer owns the latter); what a release announcement includes |

**Boundary with tech-writer (doc 09 §4):** tech-writer = *internal/developer* truth (API docs, runbooks, CHANGELOG, README); content-marketer = *external/persuasive* voice (landing pages, launch posts). Same feature, two audiences, two roles — they don't overlap.

### 4.6 tech-writer (extension, not redefinition)

Already specified in doc 09 §4. This doc only notes its expanded surface in a full company: developer guides and API reference (alongside the `error-envelope`/`api-contract-first` artifacts), user-facing how-tos, and operational runbooks. Skills to add as demanded: `api-reference-docs`, `user-guide-format`, `runbook-format` (all org-kind). No new agent file — the doc-09 one stands.

---

## 5. Routing matrix — which roles engage per work type

The discipline that keeps the company lean. The tech-lead (and PO at intake) use this to decide who's actually needed:

| Work type | PM | BA | Architect | Designer | Eng | Marketer |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Bug fix | – | – | – | – | ✅ | – |
| Small feature (existing patterns) | – | maybe | – | maybe (if UI) | ✅ | – |
| Net-new feature (user-facing) | ✅ | ✅ | maybe | ✅ | ✅ | ✅ |
| Net-new product / service | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Internal/infra change | – | maybe | ✅ (if cross-cutting) | – | ✅ | – |
| Pure content/launch | maybe | – | – | – | – | ✅ |

"maybe" = the PO/tech-lead's judgment call, stated in the issue. The default bias is **fewer roles** — every role added to a chain is latency and token cost (doc 10 §3.4 logic, applied to people-shaped agents).

---

## 6. Multica protocol extension

Doc 09 §6 defined labels as the routing protocol (`[planning]`, `[task]`, `[review]`, `[blocked]`). This adds the discovery/GTM labels — same mechanism, new lanes:

| Label | Routes to | Produces | Gate |
|---|---|---|---|
| `[discovery]` | product-manager | PRD | you approve the PRD |
| `[requirements]` | business-analyst | requirements spec | folds into PRD approval |
| `[architecture]` | tech-architect | ADR | you approve the ADR |
| `[design]` | product-designer | UI spec + mockup | you approve the design |
| `[planning]` *(doc 09)* | tech-lead | task plan | you approve the plan |
| `[content]` | content-marketer | copy/release notes | you approve before publish |

Two human gates remain the spine (doc 09 §3.2): **scope-approved** (PRD + design + ADR, batched into one review) and **plan→tasks**. Discovery artifacts are produced in parallel where independent (PM and early design exploration), serialized where dependent (architect after PRD). Multica's worktree isolation (doc 06 §7) means a designer's mockup branch and a PM's PRD branch never collide.

Per-repo applicability is still **declared, not guessed** — the Team block (doc 09 §4.1) gains optional lines:

```markdown
## Team
stack: laravel + react
runtimes: claude-code, codex
agents: laravel-backend-engineer, frontend-web-engineer, qa-engineer
product: product-manager, business-analyst, product-designer   # discovery roles for this repo
gtm: content-marketer                                          # go-to-market roles
```

Omit `product:`/`gtm:` and the repo is engineering-only — the doc-09 behavior, unchanged. A project earns discovery/GTM roles by declaring them.

---

## 7. Token, cost & autonomy optimization

A multi-role org multiplies token spend — every role added to a chain reads context and emits an artifact. Cost efficiency is therefore a **design constraint here, not an afterthought**. Doc 10 is the toolkit; this section applies it to the new roles, in order of impact.

### 7.1 Match cognitive depth to token spend (the master lever)
Not every role deserves the same model or reasoning budget. Architecture decisions are genuinely hard — spend there. Release notes are formulaic — don't. Right-sizing per role is the single biggest cost lever in a multi-role org:

| Role | model (Pro → Max/API) | effort | maxTurns | Why |
|---|---|---|---|---|
| product-manager | inherit → sonnet | medium | 15 | Structured synthesis, not deep reasoning |
| business-analyst | inherit → sonnet | medium | 15 | Enumeration benefits from some reasoning |
| tech-architect | inherit → **opus** | high | 20 | Hard judgment — where spend earns its keep |
| product-designer | inherit → sonnet | medium | 20 | Spec is formulaic; mockup is generation |
| content-marketer | inherit → **haiku** | low | 10 | Cheapest cognition in the org; smallest model |

> **Pro caveat (doc 04 §1.2, doc 09 §2):** on Pro there's one shared pool and model availability is limited — keep `model: inherit` and lean on `effort` + `maxTurns` + skill discipline (those work on every plan). The right-hand model column applies on **Max**, or when routing through the LiteLLM/API layer (doc 00 §8), where per-role model tiering becomes the dominant cost control and a Haiku-tier marketer costs a fraction of an Opus-tier architect for the same wall-clock task.

### 7.2 Preload only the most-used skill(s); the rest on-demand
The `skills:` field injects **full skill content at startup, every invocation**. Three preloaded ~150-line skills = ~450 lines of context tax on *every* run, used or not. Rule: preload the 1–2 skills the role needs every time; leave the rest invokable on-demand via the Skill tool (loaded only when the task calls for them). The §4 frontmatter blocks already apply this — e.g. content-marketer preloads only `brand-voice`, pulling `copywriting`/`copy-editing` on demand. This is doc 10 §3.4's "MCP tax" logic applied to skills.

### 7.3 Subagent isolation as a context firewall (doc 10 §3.3)
The discovery chain is read-heavy — the exact case this was written for. Each role burns its reading (code, existing docs, the PRD) in *its own* context and returns only the tight artifact to the main thread. The tech-lead sees the approved PRD, not how it was derived. Total chain spend = the sum of small artifacts, not one ballooning context.

### 7.4 The routing matrix is a token control (doc 10 §3.5)
§5 isn't only org hygiene — *not* running PM/BA/design on a bug fix saves the entire chain's spend. The cheapest token is the one a skipped role never spends. Default bias: fewer roles per issue.

### 7.5 Trim the surface — tools, reads, output
- **Tools:** each role gets only `Read, Grep, Glob, Edit, Write` (no Bash, no MCP). Fewer tool definitions = less per-session overhead; and with no shelling out, RTK (doc 10 §1.1) is moot for these roles — overhead avoided rather than compressed. Strip anything inherited with `disallowedTools`.
- **Read surgically:** prefer Grep/Glob to find and read the *relevant* files, not whole-file read-sprints (doc 10 §2.2). Ground a PRD on the three files that matter.
- **Bounded output:** every org-skill caps its artifact's shape (PRD headings, ADR template, UI-spec sections) — a format is also an output-token ceiling; `maxTurns` stops runaway loops. Keep each org-skill ≤150 lines and link out rather than paste (doc 10 §3.2).

### 7.6 Two runtimes (doc 04 §7.5; full per-role delegation table: doc 09 §4.3)
Discovery/design/content tasks are Claude-side (subagents exist only there). Codex stays the well-scoped *implementer* — the second pool you balance against, not a discovery teammate. Routing a formulaic implementation to Codex keeps Claude's pool for the judgment-heavy discovery roles, and every PR it produces still passes the always-Claude review gate (doc 09 §4.3).

### 7.7 Autonomy (doc 07)
All roles here are T0–T2: they read (T1) and produce PR'd artifacts (T2, you gate). **No role gets a T3 tool** — "publish" is always human, after merge. More roles, zero new blast radius — and zero tokens spent on actions that should never be automatic.

---

## 8. Rollout — earn each slot (do NOT build all of §4 today)

Per CLAUDE.md rule 6 and doc 09/11's "minimum viable company," build in tiers as real work demands:

1. **Tier A — first net-new user-facing feature:** `product-manager` + `product-designer` (⭐ skills only). These two unblock "what + how it looks" and pair immediately with the existing frontend engineer.
2. **Tier B — complexity grows:** `business-analyst` (when engineers start guessing at edge cases) + `tech-architect` (first time a change crosses service/module boundaries or you face a real build-vs-buy call).
3. **Tier C — you have something to launch:** `content-marketer` + the tech-writer's GTM-adjacent skills.
4. **Split a role only on volume:** `product-designer` → `ux-designer` + `ui-designer` only when one designer is the bottleneck. Same rule for any role here.

Every correction you make reviewing a PRD/spec/design/copy PR becomes a line in that role's org-skill — the doc-09 §7 learning loop, applied to the business half. Dry-run the full chain once on the sandbox repo (idea → PO → PM PRD → design spec → architect ADR → approve → tech-lead → build → marketer release notes) before trusting it on the live project — and capture its `ccusage` cost as the baseline, then tune §7.1's effort/model knobs against real spend rather than guesses.

---

## 9. Validation

- [ ] `/agents` lists each built role with the tool limits in §4 (product/design/marketing roles can write only their artifact paths — verify by asking one to edit app code; it must refuse/branch-and-flag).
- [ ] product-manager produces a PRD in `prd-format` and stops — it does not create `[task]` issues.
- [ ] tech-architect emits an ADR citing real files and the alternatives it rejected; declines to write implementation code.
- [ ] product-designer's UI spec covers all states (loading/empty/error) and the frontend engineer's Playwright run verifies *those* states.
- [ ] content-marketer's copy makes no claim about an unshipped feature (test by briefing it before the feature merges — it must flag the gap).
- [ ] A repo with no `product:`/`gtm:` Team-block lines behaves exactly as doc 09 (engineering-only) — the new roles never auto-engage.
- [ ] The routing matrix holds: a bug-fix issue triggers no discovery role.
- [ ] No role here has a T3 tool; "publish" remains a human step (doc 07 §1).
- [ ] Token tuning is in place (§7): each role's `effort`/`maxTurns` match the §7.1 table; `skills:` preloads only the minimum set (rest on-demand); tools are limited to read + artifact-write. On Max/API, per-role `model` tiering is applied; on Pro, `model: inherit` with effort as the lever.
- [ ] `ccusage` (doc 10 §1.3) shows the discovery chain's per-issue cost is dominated by the architect, not the marketer — if a formulaic role is the cost sink, its effort/model is mis-tuned.

---

## 10. Reuse notes (SaaS / clients)

- This roster turns the **service menu** (doc 11 §11) into a full agency offering: "we cover product discovery, system design, design, build, and launch." Each role = a sellable line item; the org-skills are the quality system behind each.
- **SaaS tier mapping extends doc 09 §9:** Starter = PO + one engineer; Pro = + tech-lead + QA/reviewer; Business = + product-manager + product-designer + security cadence; **Agency/Enterprise = the full §4 roster** (BA + architect + marketing). Autonomy tiers price the *governance*; this roster prices the *coverage*.
- Per-client: agent files stay generic; the client's brand voice, design system, and PRD/ADR conventions live in *their* org-skills and repo handbooks (doc 09 §9 separation, unchanged).
- The "everything is a PR'd artifact" decision (§1) is the audit story for regulated clients: every product decision, design, and public claim has a reviewable, attributable, reversible history — same as code.
