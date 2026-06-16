# 10 — Token-Efficiency Toolkit

**Goal:** stretch the Claude Pro pool as far as it goes. On Pro, every wasted token is shared between your interactive sessions and every Multica-dispatched agent run — so token hygiene is what makes the $20 tier viable for an AI org.

**The mental model:** tokens are spent on (a) command output noise, (b) re-reading code to rebuild understanding, (c) re-explaining context every session, and (d) tool-definition overhead you carry whether used or not. Each tool below attacks one of these. Everything here is free/OSS.

---

## 1. Tier 1 — install now

### 1.1 RTK (Rust Token Killer) — kills output noise (a)

A CLI proxy that filters and compresses command outputs before they reach the model — a single Rust binary claiming 60–90% savings on common dev commands. It hooks Claude Code's Bash tool via a PreToolUse hook, transparently rewriting calls (e.g. `git log` → `rtk git log`); measured examples include test runs collapsing from 155 lines to 3 (98%) and `git status` shrinking ~76%, with one report of ~10M tokens (89%) saved over two weeks. Typical results: `git status` compacts to a one-liner, `git commit` returns just "ok abc1234", test output reduces to failures-only.

```bash
# as <DEV_USER>; verify current command at github.com/rtk-ai/rtk
cargo install rtk   # or the repo's installer / release binary
rtk init -g         # installs the global hook + RTK.md instructions
# restart Claude Code, then after a few sessions:
rtk gain            # shows measured savings
```

Why it's Tier 1: zero workflow change, benefits **every** agent in the org on every Bash call (the hook applies to subagents too). Scope note: it intercepts Bash only — Claude Code's built-in Read/Grep/Glob tools bypass it, which §3 practices cover.

> It rewrites your agent's shell commands, so skim what it does (open source, MIT) and pin the version in your Ansible devtools role. If a command ever behaves oddly, `rtk` can be bypassed per-call — debug with the raw command before blaming the tool.

### 1.2 Context7 MCP — kills doc-guessing loops (b)

Already in your roster (doc 04). Its token story: without it, the model guesses at a Laravel 12 API, gets it wrong, you burn a fix cycle (often thousands of tokens); with it, one targeted docs lookup. Keep it.

### 1.3 ccusage — measure before optimizing

A small CLI that reads Claude Code's local session logs and reports token consumption per day/session/model. Not a saver itself — it's the meter that tells you whether RTK and your practices are working, and gives early warning before you hit Pro caps.

```bash
npx ccusage@latest          # daily report; also: blocks --live for current session window
```

Run weekly; the trend line is your Max-upgrade signal, with data instead of vibes.

## 2. Tier 2 — install when the trigger fires

### 2.1 Understand Anything — kills exploration re-reading (b)

A Claude Code plugin that analyzes a project with a multi-agent pipeline, builds a knowledge graph of every file, function, class, and dependency, and serves an interactive dashboard to explore it (~15k GitHub stars). Token relevance is indirect but real: agents (and you) stop paying for blind exploratory file-reading to rebuild the mental map; impact analysis ("what touches invoices?") becomes a graph query instead of a grep safari. It supports incremental updates so the graph tracks the code.

```bash
/plugin marketplace add Egonex-AI/Understand-Anything
/plugin install understand-anything
/understand        # run inside a repo
```

**Trigger to install:** first time you onboard a codebase you didn't write, or when any repo crosses the size where the tech-lead's planning runs start with long read-sprees. **Caution:** the initial multi-agent analysis itself costs tokens — run it once per repo (then incrementally), not per session, and start it early in a session window.

### 2.2 Serena MCP — surgical code access for large repos (b)

An MCP server that gives the agent LSP-grade semantic tools: find symbol, list references, edit at symbol level — so it reads *the function*, not *the file*. Biggest payoff on large codebases where whole-file reads dominate spend. **Trigger:** repos where files routinely exceed a few hundred lines and diffs are localized. Skip while your apps are small — it's another tool-definition overhead (see §3.4) until the repo size justifies it.

## 3. Tier 0 — free practices (bigger than any plugin)

### 3.1 Session hygiene
`/clear` between unrelated tasks (context carryover is pure waste); `/compact` at natural breakpoints of long sessions *before* auto-compact triggers at a bad moment; one issue = one session (the Multica model enforces this naturally).

### 3.2 CLAUDE.md as compression
Every convention written in CLAUDE.md/skills is paid **once per session** instead of re-derived through correction cycles. Corollary: keep CLAUDE.md itself lean — it's loaded every session; long prose belongs in skills (loaded on demand). This is doc 09's "the org learns by editing files" — it's also the token strategy.

### 3.3 Subagent isolation as a context firewall
Read-heavy work (exploration, log triage, review) delegated to a subagent burns tokens in the *subagent's* context and returns only a summary to the main thread. Doc 09's read-only roles (tech-lead, code-reviewer, security-auditor) are doing token work, not just governance work. Use the same trick ad hoc: "use a subagent to find where X is handled, report back in 5 lines."

### 3.4 The MCP tax — audit your roster
Every connected MCP server injects its tool definitions into **every session's** context, used or not. A bloated roster can cost thousands of tokens per session before the first prompt. Quarterly: `claude mcp list` → remove anything no doc-07 workflow actually uses. This is why docs 04/09 insist slots are *earned* — it's a budget rule, not an aesthetic.

### 3.5 Scoped briefs
Vague issues make agents explore; the doc-09 pipeline (PO acceptance criteria + tech-lead's "files/areas" per task) is itself a token optimization — the implementer starts knowing *where* to work. Brief quality is the cheapest token lever you own.

## 4. What to skip (for now)

- **Semantic-search MCPs needing a vector DB** (e.g. Milvus-backed code search): real value on monorepos, but infrastructure + RAM you don't need at current repo sizes. Understand Anything + Serena cover the gap lighter.
- **Context-injection frameworks** that auto-stuff project context each session: solve a problem CLAUDE.md + skills already solve, and fight progressive disclosure.
- **Statusline/dashboard token monitors** beyond ccusage: fun, not load-bearing.

## 5. Plugin trust policy (applies to everything in this doc)

Plugins and skills execute code in `<DEV_USER>`'s context — the same user holding your GitHub auth. Rules: install only from sources you've skimmed (all of the above are open source); pin versions in the Ansible devtools role; new plugin = read its hook/skill files first; nothing from this doc ever runs under `<AGENT_USER>` (Hermes' world stays separate). Anthropic's own guidance: stick to trusted sources — treat a Claude Code plugin with the same suspicion as a composer/npm dependency.

## 6. Validation

- [ ] `rtk gain` shows non-trivial savings after a week of normal use.
- [ ] `ccusage` weekly trend captured; baseline week recorded before RTK for comparison.
- [ ] `claude mcp list` audited; every entry maps to a doc-07/09 workflow.
- [ ] CLAUDE.md files under ~100 lines; long content moved to skills.
- [ ] (When installed) Understand Anything graph opens for the main repo and answers one impact-analysis question correctly.

## 7. Reuse notes

- Bake Tier 1 into the Ansible `devtools` role (rtk binary + hook, ccusage via npx alias) — every future dev box starts efficient.
- For the SaaS: token hygiene is **margin**. The same toolkit on customer-serving agents (RTK on exec output, lean tool rosters, skill-based compression) directly lowers your LiteLLM bill per customer — fold this doc into the per-customer cost model in the unit-economics spreadsheet.
