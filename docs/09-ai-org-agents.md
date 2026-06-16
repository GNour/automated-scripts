# 09 — The AI Organization: Agents & Skills Roster

**Goal:** a reusable "tech company" of agents — global Claude Code subagents with role-specific skills, wired into Multica — plus the two management roles you specified: a **Product Owner** that turns ideas into well-formed issues, and a **Tech Lead** that plans and breaks them down before any code is written.

**The core idea:** agents are files. A subagent = one markdown file with a role prompt + tool limits; a skill = one folder with a how-to. The whole "company" lives in `~/.claude/` + `~/.hermes/`, versioned in your infra repo as `claude-team-config/` — copy it to any server or client and the team comes with you.

**This doc refines doc 07's W1/W7:** the pipeline below is the production version of those workflows.

---

## 1. The org chart

```
                    YOU (CEO — the only human)
                          │ Telegram
              ┌───────────▼───────────┐
              │ PRODUCT OWNER (Hermes)│  idea → proper issue
              └───────────┬───────────┘
                          │ Multica issue [planning]
              ┌───────────▼───────────┐
              │ TECH LEAD (Claude sub)│  issue → ordered task plan
              └───────────┬───────────┘
                          │ Multica issues [task], dependency-ordered
   ┌──────────┬───────────┼───────────┬─────────────┐
   ▼          ▼           ▼           ▼             ▼
BACKEND   FRONTEND      QA        DEVOPS       TECH WRITER
ENGINEER  ENGINEER   ENGINEER   ENGINEER       (docs/PRs)
   └──────────┴─────┬─────┴───────────┘
                    ▼ every PR
        CODE REVIEWER + SECURITY AUDITOR (read-only gate)
                    ▼
              YOU merge → Coolify deploys
```

Division of labor across the three systems:
- **Hermes** = the *conversational* roles (PO) — intake, dialogue, no repo access needed.
- **Claude Code subagents** = the *repo* roles — everything that reads or writes code.
- **Multica** = the office: issues, assignment, worktrees, progress, accumulated skills.

## 2. Mechanics (how a "role" actually runs)

A global subagent lives at `~/.claude/agents/<role>.md`:

```markdown
---
name: backend-engineer
description: Implements Laravel backend tasks — models, migrations, services,
  APIs, queues. Use for any server-side implementation issue.
tools: Read, Edit, Write, Bash, Grep, Glob   # what this role may touch
model: inherit                                # or sonnet/haiku per role
---
You are the backend engineer. <role prompt — see §4>
```

Claude Code **auto-delegates** to a subagent when a task matches its `description`, or you/the issue can demand it explicitly. Multica issue briefs therefore end with a routing line: *"Use the backend-engineer subagent."* Each role's deep knowledge lives in **skills** (`~/.claude/skills/<skill>/SKILL.md`) preloaded via the agent's `skills:` frontmatter list — keeping agent files short and knowledge reusable across roles. The `tools:` field takes plain tool names (no command-level patterns); command scoping belongs in `settings.json` permissions.

> Verify frontmatter fields against current Claude Code docs (`/agents` command manages these interactively). On Pro tier, leave `model: inherit` except where noted — model availability varies by plan. Three cost levers ride in the same frontmatter — `model`, `effort`, and `maxTurns` — tuned per role in §4.2; **doc 13 §7 is the canonical token framework** for the whole org, this doc and doc 11 just carry the per-role tables.

## 3. The management layer (your two requested roles)

### 3.1 Product Owner — lives in Hermes (ops profile)

**Why Hermes:** ideas arrive in Telegram as half-sentences; the PO's job is *dialogue* — sharpening intent before anything enters the system. No repo needed.

Implementation: a Hermes skill/system-prompt block in the ops profile:

```
## Role: Product Owner
When I describe a feature, bug, or idea, do NOT create a Multica issue
immediately. First:
1. Restate the goal in one sentence (the user story:
   "As a <user>, I want <capability> so that <benefit>").
2. Ask me AT MOST two clarifying questions, only if genuinely ambiguous.
3. Draft the issue in the standard format below and show it to me.
4. Only after I reply "approve" — create it in Multica via the multica
   tool, labeled [planning], in the right project.

## Issue format (the contract)
- Title: imperative, ≤70 chars
- User story (one line)
- Context: why now, links, constraints
- Acceptance criteria: 3–7 testable checkboxes
- Out of scope: explicit non-goals
- Routing: which repo; suggested priority
```

The PO never decides *how* — no technical design in its output. That's the boundary with the Tech Lead.

### 3.2 Tech Lead — a Claude Code subagent, invoked via Multica `[planning]` issues

**Why Claude-side:** real planning requires reading the codebase — current architecture, existing patterns, what the change actually touches. Hermes can't see the repo deeply; the Tech Lead must.

`~/.claude/agents/tech-lead.md`:

```markdown
---
name: tech-lead
description: Plans and decomposes [planning] issues into ordered, dependency-aware
  implementation tasks. Produces plans, never implementation code.
tools: Read, Grep, Glob   # read-only by design — plain tool names only; no Bash = no execution
effort: high              # decomposition is judgment-heavy — spend here (§4.2)
maxTurns: 20
---
You are the tech lead. Given a [planning] issue:
1. Read the relevant code paths before proposing anything. Cite files.
2. Identify the approach: smallest design that satisfies all acceptance
   criteria. Note alternatives you rejected and why (2 lines max each).
3. Decompose into tasks of ≤ half a day each. For every task specify:
   title, files/areas, the runtime (claude-code | codex — doc 04 §7.5:
   Claude for planning-heavy/multi-file/role-gated work, Codex for
   well-scoped single-area implementation), the subagent to route to
   on claude-code tasks (backend-engineer / frontend-engineer /
   qa-engineer / devops-engineer / tech-writer; Codex has no subagents),
   dependencies on other tasks, and its slice of the acceptance criteria.
4. Order tasks so each leaves main deployable (migrations before code
   that needs them; feature-flag if a slice would break staging).
5. Flag risks: data migrations, breaking API changes, perf, security.
6. Output the plan as a markdown comment on the issue. STOP. Do not
   implement. Task issues are created only after human approval.
```

**Flow:** PO's `[planning]` issue → Multica assigns to Claude Code → routing line invokes tech-lead → plan lands as an issue comment → **you approve in one tap (via Hermes notification)** → Hermes' multica tool creates the child `[task]` issues from the plan, dependency-ordered → Multica feeds them to implementers sequentially (respecting your Pro-pool discipline).

Two human gates by design: idea→issue (PO shows the draft) and plan→tasks. Both are one-word approvals from your phone; both are where autonomy stays accountable.

## 4. The implementation roster

The roster has two halves:

**Platform engineers** (one per platform — Laravel, Node, Python, React/Next web, React Native, Android, iOS) carry the stack-specific knowledge. Their full specs and per-agent skills catalogs live in **doc 11**, including what each can verify on this Linux VPS vs. via cloud CI.

**Shared roles** apply to every project regardless of platform:

| Role | Tools | Mandate (prompt core) | Skills it loads |
|---|---|---|---|
| **qa-engineer** | Read, Edit(write tests only), Bash(test cmds) | Writes/repairs tests; reproduces bugs as failing tests first; E2E for critical flows. Never "fixes" app code to make tests pass. | `e2e-critical-flows`, `bug-reproduction` + the platform's test skill |
| **code-reviewer** | Read, Grep, Glob (read-only) | Reviews PR diffs: correctness, missed edge cases, style drift, test coverage. Verdict: approve / request-changes + reasons. | `review-checklist` |
| **security-auditor** | read-only | OWASP/platform security pass on auth/input/queries/secrets; flags, never fixes (fix becomes a new task). | `owasp-web`, `mobile-security`, `secrets-scan` |
| **devops-engineer** | Read, Edit, Bash(allowlist: docker/coolify/ansible cmds) | Dockerfiles, compose, Ansible roles, Coolify config, CI pipelines (incl. the mobile cloud-build pipelines doc 11 requires). | `coolify-deploy-check`, `ansible-conventions`, `ci-pipelines` |
| **tech-writer** | Read, Edit(docs/md only) | README/CHANGELOG/API docs/runbooks; updates docs in the same PR as the feature when routed jointly. | `docs-style`, `changelog-format` |

### 4.1 Project-based agent selection (how the right team forms per repo)

Selection is **declared, not guessed**. Every repo's handbook (`AGENTS.md`) carries a Team block:

```markdown
## Team
stack: laravel + react-native        # what this project is
runtimes: claude-code, codex         # which agent CLIs may take tasks here
agents: laravel-backend-engineer, hybrid-mobile-engineer, qa-engineer
# only these implementation agents may receive tasks for this repo
```

(The Team block lives in the repo's `AGENTS.md` — the canonical handbook both CLIs read; `CLAUDE.md` imports it via `@AGENTS.md`. See doc 04 §7.3.)

Enforcement points: (1) the **tech-lead's** planning prompt routes tasks only to agents declared in the Team block; (2) the **PO** includes the repo in every issue, so the chain knows which team applies; (3) shared roles are implicitly always available. New project onboarding = write the Team block; nothing else changes.

Start with **tech-lead + the platform engineer(s) for your current stack + code-reviewer + qa-engineer** — the minimum viable company. Add platform engineers when a project actually declares them (same rule as MCPs: roster slots must be earned — every defined-but-unused agent is prompt/maintenance overhead).

### 4.2 Token posture per role (doc 13 §7 is canonical)

The org's master cost lever — **match cognitive depth to token spend** — applies to engineering too: spend on hard judgment (tech-lead, security-auditor), economize on formulaic output (tech-writer). Each role's `effort`, `maxTurns`, and (on Max/API) `model`:

| Role | model (Pro → Max/API) | effort | maxTurns | Why |
|---|---|---|---|---|
| tech-lead | inherit → opus | high | 20 | Decomposition is judgment-heavy — the spend earns its keep |
| security-auditor | inherit → opus | high | 15 | Security smells are subtle; reasoning pays off |
| code-reviewer | inherit → sonnet | medium | 15 | Bounded review against a checklist |
| qa-engineer | inherit → sonnet | medium | 25 | Test loops need turns, not deep reasoning |
| devops-engineer | inherit → sonnet | medium | 20 | Config work, moderate depth |
| tech-writer | inherit → **haiku** | low | 12 | Formulaic — cheapest cognition (mirrors doc 13's content-marketer) |
| platform engineers (doc 11) | inherit → sonnet | medium | 30 | Coding is many small steps; sonnet handles it — reserve opus/high for genuinely complex tasks |

**Pro caveat (doc 04 §1.2):** one shared pool, limited model choice — keep `model: inherit` and lean on `effort` + `maxTurns` (both work on every plan); per-role `model` tiering becomes the dominant lever on Max or the LiteLLM/API layer (doc 00 §8). And **preload only ⭐ skills** (doc 13 §7.2) — the `skills:` field injects full content every run, so non-⭐ skills stay invokable on-demand.

### 4.3 Runtime delegation — which roles run on Codex (the review gate stays Claude)

The org has two runtimes (doc 04 §7): **Claude Code** (Pro pool, *has* subagents) and **Codex CLI** (ChatGPT Plus pool, *no* subagents). Delegating well-scoped implementation to Codex frees the Pro pool for the judgment-heavy Claude-only roles — a capacity *and* cost win (§4.2, doc 04 §7.5).

**What "a role on Codex" actually means.** Codex has no subagents (doc 04 §7.5), so you cannot hand it a subagent file. A role "runs on Codex" by Codex reading the repo's **AGENTS.md** — which must carry that role's non-negotiables (build order, test expectations, error envelope) — plus a tight task brief. Consequence: a role is Codex-eligible only if its standards fit in AGENTS.md *and* its work is well-scoped single-area implementation. Judgment, gate, and discovery roles rely on subagent isolation, read-only tool-gating, or planning — they stay on Claude.

| Role | Runtime | Why |
|---|---|---|
| platform engineers (doc 11) | **Codex or Claude** — tech-lead routes per task | Well-scoped single-area implementation → Codex; planning-heavy/multi-file → Claude (doc 04 §7.5) |
| tech-writer | **Codex or Claude** | Docs against a shipped diff are well-scoped and formulaic |
| qa-engineer | **mostly Claude**; Codex for test-writing against a clear spec | Bug-reproduction/E2E need exploration → Claude; straight test-writing can go to Codex |
| devops-engineer | **mostly Claude**; Codex for a scoped config/Dockerfile/CI edit | Cross-cutting pipeline design → Claude; a single scoped change → Codex |
| tech-lead | **Claude only** | Planning is role-gated + read-only-tool-gated; no Codex subagents |
| **code-reviewer** | **Claude only — always** | The review gate (below) |
| security-auditor | **Claude only** | Read-only audit gate, subagent isolation |
| PM / BA / architect / designer / marketer (doc 13) | **Claude only** | Discovery/design = planning-heavy, artifact, role-gated (doc 13 §7.6) |

**The always-Claude review gate — the point of running two runtimes.** Every PR, whoever implemented it, is reviewed by the **Claude `code-reviewer` subagent** (read-only), with `security-auditor` on the same gate. This buys **cross-runtime independence**: the implementer (often Codex) and the reviewer (always Claude) are different models on different pools, so the reviewer does not inherit the implementer's blind spots. It is a quality mechanism, not a preference — a second set of eyes that literally sees differently.

```
Codex (ChatGPT Plus pool)               Claude (Pro pool)
  implements #42 (well-scoped)  →  PR  →  code-reviewer subagent (read-only)
                                          + security-auditor
                                        →  verdict on the PR  →  YOU merge
```

**Discipline (doc 04 §7.5, doc 06 §9):**
- One issue = one runtime = one session — never split an *implementation* issue across runtimes. The review is a **separate** unit of work (`[review]`, §6) on Claude, not a split of the implementation issue.
- The tech-lead routes a task to Codex only when (a) the repo's Team-block `runtimes:` lists `codex` (§4.1), (b) the task is well-scoped single-area implementation, and (c) the role is Codex-eligible above. Otherwise Claude.
- **Brief quality matters double for Codex** (doc 10 §3.5): with no subagent role-prompt, AGENTS.md + the brief are Codex's entire context — give Codex tasks tighter files/areas and acceptance criteria.
- Balance the pools: when one subscription's window runs hot, shift eligible implementation to the other.

**AGENTS.md is the Codex integration point.** For every Codex-eligible role, its skill essentials must be mirrored in the repo's AGENTS.md (Codex cannot preload a Claude skill). The first time the tech-lead routes a role to Codex on a repo is the trigger to confirm AGENTS.md carries that role's definition-of-done.

### 4.4 Sourcing agents from external catalogs (adapt, never bulk-install)

Public subagent catalogs exist — e.g. **[VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)** (MIT, ~164 agents). Treat them as a **reference quarry for role ideas and prompt content, not a drop-in roster.** Bulk-installing breaks this org's design: most ship `Bash`+`Write` on *every* role (our review/audit gate is read-only); ~¾ assume a `context-manager` orchestration substrate we don't run; none carry `skills:`/`effort:`/`maxTurns:` (undoing doc 13 §7's token discipline) and their long inline checklists tax every invocation; they hardcode `model:` instead of `inherit`; and 164 agents flood every session's context, violating §4.1's "earn the slot."

**Policy: adopt one agent at a time, when a project earns the slot, _adapted_ to our conventions.** The checklist:

- [ ] **Boundary** — gate/review roles become read-only (`Read, Grep, Glob`); implementers get the minimum tools for their mandate. Never inherit a write-capable reviewer.
- [ ] **Decouple** — strip "query the context manager" and any orchestration we don't run; route via Multica labels + the tech-lead.
- [ ] **Token discipline (doc 13 §7)** — move the long inline checklist into a skill (on-demand); keep the prompt tight; add `effort` + `maxTurns`; set `model: inherit` (tier on Max/API).
- [ ] **MCPs** — drop any tool/MCP we don't run (doc 04 §5); add ours only if a workflow needs it.
- [ ] **Ground it** — our pipeline (labels, artifact paths), Codex eligibility (§4.3), the common header.
- [ ] **Attribute** — credit the source + license in the agent file (a credit line covers a rewrite; MIT requires the notice on substantial verbatim portions).

The starter set adapted this way — `debugger`, `accessibility-tester`, `performance-engineer` (quality roles we lacked) — lives in `claude-team-config/`; each is opt-in per repo via the Team block, exactly like a platform engineer.

## 5. Skills — one full example, then the pattern

`~/.claude/skills/laravel-feature/SKILL.md`:

```markdown
---
name: laravel-feature
description: How we build a Laravel feature end-to-end in this org —
  order of work, test expectations, conventions. Load for any backend
  implementation task.
---
# Building a feature
Order: migration → model+factory → service/action class → form request
(validation) → controller (thin) → route → Pest feature test → Pint.

## Conventions
- Business logic in Action/Service classes, never controllers.
- Eloquent: explicit $fillable; no raw SQL without a comment justifying it.
- Every endpoint: a Pest feature test covering happy path + main failure.
- Money as integer cents; dates UTC in DB, localized at the edge.

## Definition of done
- `php artisan test` green, `./vendor/bin/pint` clean
- Migration runs forward AND backward (`migrate:rollback` tested)
- PR description: what/why, screenshots if UI, test evidence
```

Pattern for the rest: each skill = the answer to "what did I have to correct twice?" Keep each under ~150 lines; link out to repo docs rather than pasting them (token economy — see doc 10).

## 6. Multica side of the org

- **Labels as the protocol:** `[planning]` (→ tech-lead), `[task]` (→ implementer named in routing line), `[review]`, `[blocked]`.
- **Issue templates** (stored in `issue-templates/` at the infra repo root, per the CLAUDE.md repo map): the PO format (§3.1) and the task format (title, parent, routing, files, criteria slice).
- **Multica skills:** when a task type repeats (e.g. "add CRUD resource"), distill the winning approach into a Multica skill so future assignments start warm.
- **Hermes as runtime** stays for non-code issues (research, content) — same board, different teammate.

## 7. Rollout & tuning

1. Create the four starter agents + their skills; commit to `claude-team-config/`.
2. Dry-run the pipeline on the sandbox repo: idea → PO draft → approve → tech-lead plan → approve → 2–3 tasks → PRs → review agent → you merge.
3. Tune the PO's question budget and the tech-lead's task granularity — these two knobs determine the whole system's quality.
4. Every correction you make in review = a line added to a skill. The org learns by editing files, not by hoping.

## 8. Validation

- [ ] `/agents` lists the roster; each agent's tools match the table.
- [ ] PO refuses to create an unapproved issue; produces the exact format.
- [ ] tech-lead on a real issue cites actual files and stops at the plan.
- [ ] An implementation task lands as a PR with tests, reviewer comments on it.
- [ ] A Codex-implemented PR is reviewed by the Claude `code-reviewer` (§4.3) — implementer and reviewer are different runtimes; the review is a separate `[review]` task, not a split of the implementation issue.
- [ ] qa-engineer declines to modify app code (test its boundary deliberately).
- [ ] `claude-team-config/` cloned to a second machine reproduces the org.

## 9. Reuse notes

- The roster IS a productizable asset: per client, copy the org, swap the skills' conventions for theirs (skills are where client-specificity lives; agent files stay generic).
- SaaS tiers map cleanly: Starter = PO+one engineer; Pro = + tech-lead pipeline + QA/reviewer; Business = full roster + security-auditor cadence.
- The two-gate pipeline (idea→issue, plan→tasks) is your governance story for corporate clients — autonomous, but never unaccountable.
