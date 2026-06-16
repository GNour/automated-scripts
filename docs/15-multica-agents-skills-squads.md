# 15 — Multica: Agents, Skills & Squads (deploying the roster as a Multica team)

**Goal:** turn the `claude-team-config` roster (docs 09/11/13) into first-class **Multica agents** — each with its instruction and attached skills — grouped into **squads**, so you assign an issue to a squad and the leader delegates to the right specialist. This is how you run real projects through Multica on the VPS.

**Depends on:** doc 06 (Multica installed, daemon running, runtimes detected), doc 04 (Claude Code + Codex), docs 09/11/13 (the roster, skills, pipeline). doc 06 is the *install*; this doc is the *team* layer on top of it.

**Sources (CLAUDE.md rule 5):** verified against `multica.ai/docs` — [agents](https://multica.ai/docs/agents), [agents-create](https://multica.ai/docs/agents-create), [skills](https://multica.ai/docs/skills), [squads](https://multica.ai/docs/squads) — on **2026-06-16**. Multica ships weekly; re-confirm exact CLI flags with `multica <cmd> --help` before scripting.

---

## 1. How Multica models a team (the three concepts)

| Concept | What it is (per Multica docs) |
|---|---|
| **Agent** | A first-class workspace member tied to a **runtime** (daemon × one AI coding tool). Required: a **name** + a **runtime**. Optional: **system instructions** (role prompt, prepended to every task), **model**, `custom_env`, `custom_args`, **visibility**, `max_concurrent_tasks` (default 6), and **skills**. Created in the UI (Agents → **+ New**) or `multica agent create`. Every field is editable later. |
| **Skill** | A "knowledge pack" — a `SKILL.md` (+ optional files), the **Anthropic Agent Skills** standard (same format as ours). **Workspace skills** are cloud-stored and team-shared; imported by writing in the UI, a **GitHub URL**, ClawHub, or **scanning a local directory via the daemon**. Many-to-many with agents; the daemon syncs them to the tool directory at execution. |
| **Squad** | A group of agents (+ optional humans) led by **one leader agent**. A routing mechanism: assign an issue to a squad → the leader reads it, delegates to the best member by @-mention, records an evaluation, then stops. An agent can be in multiple squads. Created in the UI (Squads → **New squad**) or `multica squad create`. Only owners/admins create/modify squads. |

**Two layers, one source of truth.** A **Claude Code subagent** (`~/.claude/agents/*.md`, doc 04/09) auto-delegates *within one* `claude` session. A **Multica agent** is a *workspace teammate* that gets assigned issues. They're complementary, and they share content: a Multica agent's **instruction = the body** of our `claude-team-config/agents/<name>.md`, and its **skills = our** `claude-team-config/skills/*` imported as workspace skills. Maintain the role in the agent file; mirror it into Multica.

**Execution:** agents never run on Multica's servers — your `multica daemon` drives the tool on the VPS (doc 06). The agent is tied to a runtime; if the daemon/tool is offline, its tasks queue.

---

## 2. Squad design — the org as four squads

Squads mirror the pipeline phases (docs 09/13). The leader is the natural *triager* for that phase; you assign to a squad when you don't yet know which member fits, or directly to an agent when you do.

| Squad | Leader | Members | Routes |
|---|---|---|---|
| **Product & Discovery** | `product-manager` | business-analyst, product-designer, tech-architect | "what/why/how-it-looks/what-shape" — PRDs, requirements, design specs, ADRs (doc 13) |
| **Engineering** | `tech-lead` | laravel-backend-engineer, python-engineer, frontend-web-engineer, hybrid-mobile-engineer, shell-engineer, devops-engineer | implementation + delivery across backend, web, mobile, shell/automation, and infra; tech-lead decomposes and routes to the right engineer (doc 09 §3.2) |
| **Quality & Review** | `code-reviewer` | security-auditor, qa-engineer, accessibility-tester, performance-engineer, debugger | the gate: review, OWASP audit, tests, a11y, perf, root-cause (doc 09 §4.3 — always Claude) |
| **Docs & Content** | `tech-writer` | content-marketer | developer docs/CHANGELOG (writer) vs external launch copy (marketer) (doc 13 §4.5) |

All 19 agents placed; leaders are agents (Multica requires this). The **Engineering** squad now spans every implementation surface — backend (Laravel/Python), web (React/Next), mobile (React Native/Expo), shell/automation, and infra — so `tech-lead` can route any build task to a specialist. The **Quality & Review** squad is the doc 09 §4.3 review gate — keep every member on the **claude-code** runtime so the gate stays Claude regardless of who implemented.

---

## 3. The build sheet — every agent's runtime, squad, skills

Instruction text for each = the **body** of `claude-team-config/agents/<name>.md` (paste it into the Multica agent's *system instructions*). Skills = import these from `claude-team-config/skills/` and attach.

| Multica agent | Runtime | Model (Pro → Max/API) | Squad | Skills to attach |
|---|---|---|---|---|
| product-manager | claude-code | default → sonnet | Product & Discovery *(leader)* | prd-format, roadmap-discipline |
| business-analyst | claude-code | default → sonnet | Product & Discovery | requirements-spec, edge-case-enumeration |
| product-designer | claude-code | default → sonnet | Product & Discovery | ui-spec-format, design-system-conventions |
| tech-architect | claude-code | default → opus | Product & Discovery | adr-format, system-design-review |
| tech-lead | claude-code | default → opus | Engineering *(leader)* | — (instruction only) |
| laravel-backend-engineer | claude-code *(or codex)* | default → sonnet | Engineering | laravel-feature, db-migration-safety, pest-testing, api-conventions |
| python-engineer | claude-code *(or codex)* | default → sonnet | Engineering | python-project-structure, pytest-conventions, hermes-plugin-dev |
| frontend-web-engineer | claude-code *(or codex)* | default → sonnet | Engineering | react-component-patterns, nextjs-conventions, playwright-verify |
| hybrid-mobile-engineer | claude-code *(or codex)* | default → sonnet | Engineering | rn-expo-workflow, rn-navigation, mobile-ui-patterns |
| shell-engineer | claude-code *(or codex)* | default → sonnet | Engineering | shell-scripting |
| devops-engineer | claude-code | default → sonnet | Engineering | coolify-deploy-check, ansible-conventions, ci-pipelines |
| code-reviewer | claude-code | default → sonnet | Quality & Review *(leader)* | review-checklist |
| security-auditor | claude-code | default → opus | Quality & Review | owasp-web, secrets-scan |
| qa-engineer | claude-code | default → sonnet | Quality & Review | pest-testing, bug-reproduction, e2e-critical-flows |
| accessibility-tester | claude-code | default → sonnet | Quality & Review | a11y-audit |
| performance-engineer | claude-code | default → opus | Quality & Review | performance-investigation |
| debugger | claude-code | default → opus | Quality & Review | bug-reproduction |
| tech-writer | claude-code *(or codex)* | default → haiku | Docs & Content *(leader)* | docs-style, changelog-format |
| content-marketer | claude-code | default → haiku | Docs & Content | brand-voice, release-notes-format |

- **Model:** on **Pro**, leave the default (one shared pool, limited choice — doc 04 §1.2); set the right-hand value on **Max/API** per doc 09 §4.2 / doc 13 §7.

### 3.1 Codex-runtime agents (the second pool)

A Multica agent is tied to **one** runtime, so "running a role on Codex" means a **separate agent bound to the `codex` runtime** (ChatGPT Plus pool, doc 04 §7). Which roles are Codex-eligible is set by doc 09 §4.3 — only well-scoped *implementation* roles, never the review/gate or discovery roles:

| Codex-eligible (make a `*-codex` agent) | Claude-only (never Codex) |
|---|---|
| laravel-backend-engineer, python-engineer, **frontend-web-engineer**, **hybrid-mobile-engineer**, **shell-engineer**, tech-writer | tech-lead, code-reviewer, security-auditor, qa-engineer, accessibility-tester, performance-engineer, debugger, product-manager, business-analyst, tech-architect, product-designer, content-marketer |

Setup and rules:
- Create a twin agent, e.g. `frontend-web-engineer-codex`, runtime **codex**, **same instruction** as its Claude twin. **shell-engineer** is an especially natural Codex fit — automation scripts are well-scoped, single-area work.
- **Skills don't transfer to Codex.** Codex doesn't load Claude-style skills, so a codex agent's know-how must live in its **instruction** or in the repo's `AGENTS.md` "Conventions for Codex-routed work" skill-mirror (doc 09 §4.3/§4.4) — attaching workspace skills to a codex agent has no effect.
- **Squad placement:** codex twins join the **Engineering** squad alongside their Claude twins; `tech-lead` routes a task to whichever pool is free. The **review gate stays Claude** — never put a codex agent in Quality & Review.
- **When to bother:** add codex twins to balance pools when one subscription window runs hot (doc 04 §7.5). Start Claude-only; add them as throughput demands.

### 3.2 Public skills worth importing (skills.sh / ClawHub)

The instructions reference some on-demand public skills not in our repo. They're **enhancements, not dependencies** — the ⭐ org skills are self-contained — but they add depth. Install from [skills.sh](https://www.skills.sh/) with `npx skills add <owner/repo>` (or import the GitHub URL as a workspace skill), then attach to the matching agent:

| Agent | Beneficial public skill (skills.sh) |
|---|---|
| frontend-web-engineer | `vercel-react-best-practices`, `next-best-practices`, `vercel-composition-patterns`, `shadcn` |
| hybrid-mobile-engineer | `vercel-react-native-skills`, `sleek-design-mobile-apps` |
| product-designer | `frontend-design`, `web-design-guidelines` |
| qa-engineer / frontend-web-engineer | `webapp-testing`, `tdd` |
| accessibility-tester | `web-design-guidelines` |
| performance-engineer | `seo-audit` (web vitals/perf) |
| devops-engineer | `github-actions-docs` |
| laravel-backend-engineer / python-engineer | `supabase-postgres-best-practices` (if Postgres) |

Vet each before importing (doc 10 §5 plugin-trust policy) — a skill executes in the agent's context. Prefer one strong skill per gap over piling them on (the preload tax, doc 13 §7.2).

---

## 4. Step-by-step on the VPS (as `<DEV_USER>`)

### 4.1 Prerequisites (doc 06)
```bash
multica daemon status     # running; runtimes: claude ✓ codex ✓ hermes ✓
```
`~/.claude` already carries the agents + skills (the deploy in doc 06 / the README). The repo is on the VPS (so `claude-team-config/skills/` is scannable).

### 4.2 Import the skills as workspace skills
Import once; every agent (every teammate) can attach them. Methods (Multica skills doc): **scan the local directory** `claude-team-config/skills/` via the daemon, import the **GitHub repo** URL, or paste each in the UI. Confirm the exact command first:
```bash
multica skill --help          # confirm import/scan flags for your version
# then import the 36 org skills from claude-team-config/skills/ (local scan or GitHub)
```
Verify all 36 appear under the workspace's Skills page.

### 4.3 Create the agents
UI: **Agents → + New** → set **name**, **runtime** (claude-code), paste the **system instructions** (the body of `claude-team-config/agents/<name>.md`), set **model** (default on Pro), and **attach** the skills from the build sheet (§3). Repeat for all 19 (plus any `*-codex` twins, §3.1).

CLI (confirm flags with `multica agent create --help`):
```bash
multica agent create          # interactive: name + runtime, then instruction/model/skills
```
> Practical tip: the instruction is the single highest-leverage field. Paste the agent-file body verbatim — it already carries the boundary, the skill references, and the pipeline grounding.

### 4.4 Create the squads and add members
```bash
multica squad create --name "Product & Discovery" --leader product-manager
multica squad create --name "Engineering"         --leader tech-lead
multica squad create --name "Quality & Review"    --leader code-reviewer
multica squad create --name "Docs & Content"      --leader tech-writer

# add members (get each agent's uuid from the Agents page or `multica agent list`)
multica squad member add <product-discovery-id> --member-id <business-analyst-uuid>  --type agent --role "Requirements & edge cases"
multica squad member add <product-discovery-id> --member-id <product-designer-uuid>  --type agent --role "Flows & UI specs"
multica squad member add <product-discovery-id> --member-id <tech-architect-uuid>    --type agent --role "System design / ADRs"
# …repeat per the §2 table for Engineering, Quality & Review, Docs & Content
```
Squad **instructions** (set on the squad detail page): tell the leader how to triage — e.g. for Quality & Review: *"Route security concerns to @security-auditor, failing/missing tests to @qa-engineer, UI to @accessibility-tester, slow paths to @performance-engineer, crashes to @debugger; do the diff review yourself."*

### 4.5 Subscription discipline (doc 06 §9)
Multica's `max_concurrent_tasks` is **per agent** (default 6), but the **Claude Pro pool is shared across all claude-code agents**. To honor one-task-per-pool: set claude-code agents to `max_concurrent_tasks: 1` and don't fan one issue out to many Claude agents at once. The codex agents draw the separate ChatGPT Plus pool — one Claude + one Codex task can run side by side.

---

## 5. Running a project through the squads

1. **Discovery** (net-new) — assign the idea to **Product & Discovery**; the PM leader writes the PRD or delegates requirements/design/architecture. You approve (doc 13 gate).
2. **Plan & build** — assign to **Engineering**; `tech-lead` decomposes and delegates each task to the right engineer (claude-code or its codex variant). Work runs in an isolated worktree → branch → **PR**.
3. **Review gate** — assign the PR to **Quality & Review**; `code-reviewer` triages and delegates to security/qa/a11y/perf/debugger as needed. Always Claude (doc 09 §4.3).
4. **Merge & ship** — you merge; Coolify deploys (doc 06).
5. **Document & launch** — assign to **Docs & Content**; `tech-writer` updates docs/CHANGELOG, delegates launch copy to `content-marketer` (shipped work only, doc 13 §4.5).

Assign **directly to an agent** when you already know who fits; use the **squad** when you want the leader to route. The two human gates (scope, plan→tasks) and the merge gate stay exactly as docs 09/13 define — squads route work, they don't remove the gates.

---

## 6. Validation

- [ ] All 36 org skills appear as workspace skills; a sample attaches to an agent.
- [ ] All 19 agents exist, each with its instruction, runtime (claude-code), and the §3 skills attached; any `*-codex` twins carry their know-how in the instruction (skills don't apply to Codex, §3.1).
- [ ] The 4 squads exist with the right leader + members (§2); `multica squad` lists them.
- [ ] Assigning a feature to **Engineering** triggers `tech-lead`, which delegates by @-mention to an engineer that opens a PR.
- [ ] Assigning that PR to **Quality & Review** triggers `code-reviewer`, which routes/reviews and changes nothing.
- [ ] claude-code agents are capped at `max_concurrent_tasks: 1`; a Claude task and a Codex task can run concurrently, none parallelize within a pool.

---

## 7. Reuse notes

- The squad map + build sheet are a **productizable team template**: per client, import the same skills, create the same agents, swap only the per-repo conventions (doc 09 §9). Squads are the org chart you can hand a client.
- Keep the agent files (`claude-team-config/agents/`) the **single source** for instructions; when you correct a role, edit the file and re-paste into the Multica agent — don't let the two drift (doc 13 §1 "everything is a versioned artifact").
- Codex-runtime variants are how you scale throughput without breaking pool discipline — add them when one subscription window runs hot (doc 04 §7.5).
