# 14 — Hermes Enhancements: Personal Assistant Data Layer & Ops Capabilities

**Goal:** turn Hermes from a conversational gateway into a *stateful* personal assistant (receipts, expenses, notes, reminders, to-dos, calendar) and a *capable* ops console (server status, file search, scoped command execution) — **without** weakening the two-profile security model (doc 05) or the autonomy tiers (doc 07).

**Grounding rule (CLAUDE.md §5):** every Hermes capability cited below was verified against the official Hermes Agent docs and repo on **2026-06-14** — see §16. Where a capability is *not yet reliable upstream*, this doc says so explicitly and gives the working pattern instead of pretending. Nothing here is guesswork; where a config key shape needs first-deploy confirmation against `hermes setup`, it is flagged.

**Profile ownership (decided up front):** the **personal-assistant data** (receipts, expenses, debts, your notes, your reminders, your to-dos) is **sensitive and yours** — it lives on the **ops profile** (`<DEV_USER>`, doc 05 §3.2, doc 06 §10), *not* the family profile. The family profile stays T0: chat, images, and simple per-person reminders only (doc 07 §4). Personal finance never touches the family bot.

---

## 0. What Hermes already gives us (capability inventory)

Before adding anything, map the requirements to **built-in** Hermes capability. Most of what you asked for needs *configuration and a directory convention*, not new code.

| Requirement | Hermes built-in that covers it | Gap to fill |
|---|---|---|
| Read/write structured files on disk | `read_file`, `patch` (Terminal & Files toolset) | a **directory convention** + (for finance) a deterministic plugin |
| Run commands / search files | `terminal` tool (backends: local/Docker/SSH/Modal/Daytona/Singularity) | scope it safely (see §10–11) |
| Reminders / scheduled nudges | `cronjob` tool — create/list/update/pause/resume/run/remove, delivers to Telegram | a durable record mirror (see §6) |
| To-dos / planning | `todo` tool (agent orchestration) | persistence + a daily surfacing cron |
| Preferences / "remember that I…" | persistent memory — `MEMORY.md`, `USER.md`, FTS5 cross-session recall | nothing — on by default |
| External services (Google Calendar) | native **MCP client** (stdio + HTTP, tool include/exclude filtering) | add one MCP server (see §8) |
| Server app status | `coolify` plugin (this repo) — `coolify_app_status` / `_logs` | host metrics still uncovered (see §9) |
| Task board | `multica` plugin (this repo, doc 06) | real-time notifications (see §12) |
| Incoming photos/files from Telegram | vision can **read** inbound images today | inbound files are **not** reliably exposed as tool paths — see §3 (the one real limitation) |

**Takeaway:** four of your six personal-assistant asks are pure configuration on top of built-ins. The only thing that needs new code is the **finance ledger** (where a mis-formatted CSV is a real bug), and the two read-only ops plugins in §9–§10.

---

## 1. Design decisions

1. **Ops profile owns personal data.** Runs as `<DEV_USER>`. The family profile is untouched (still T0, no filesystem, no finance).
2. **One canonical data tree**, `<ASSISTANT_DATA>` (default `/home/<DEV_USER>/.hermes/data/`). One root → one backup path → one place to reason about.
3. **Built-ins first, plugins where correctness matters.** Notes, to-dos, reminders, and calendar use built-in tools + the directory convention (zero new code). The **finance ledger** gets a small deterministic plugin (`ledger`) because the model must not free-hand a money CSV. This mirrors the repo's existing plugin pattern (`multica`, `coolify`, `fal_image_hq`): a directory with `plugin.yaml` + `register(ctx)` + `schemas.py` + `tools.py`, opt-in via `plugins.enabled` (see `hermes/README.md`).
4. **The data tree must be host-readable.** Outbound files use the gateway's `MEDIA:/abs/path` tag (§3); the gateway runs on the **host**, not inside the Docker exec sandbox. So `read_file`/`patch` and the `ledger` plugin operate on the host filesystem directly — they are **not** the Docker `execute_code` sandbox (doc 05 §4), which stays mount-less and network-less for throwaway compute.
5. **Phased rollout** (§15): directory + built-ins first (instant value, no code), then the `ledger` plugin, then ops plugins, then calendar MCP.

---

## 2. The data tree (`<ASSISTANT_DATA>`)

One root under the ops user's Hermes home, so it rides a single backup path (§14):

```
/home/<DEV_USER>/.hermes/data/            # <ASSISTANT_DATA>
├── inbox/                                # raw inbound files staged from Telegram, untriaged
│   ├── receipts/
│   ├── notes/
│   └── misc/
├── receipts/                             # filed originals, foldered by month
│   └── 2026/06/2026-06-14_grocery_42.30.jpg
├── ledger/
│   ├── expenses.csv                      # schema in §4
│   ├── income.csv
│   └── debts.csv
├── notes/                                # one markdown file per note, date-prefixed
│   └── 2026-06-14_roof-quote.md
├── reminders/
│   └── reminders.jsonl                   # durable mirror of cron reminders (§6)
└── todos/
    └── todos.md                          # human-readable mirror of the built-in todo store (§7)
```

Create it once (Ansible `users` role, or by hand on first deploy):

```bash
install -d -m 700 -o <DEV_USER> -g <DEV_USER> \
  /home/<DEV_USER>/.hermes/data/{inbox/{receipts,notes,misc},receipts,ledger,notes,reminders,todos}
```

`700` because it holds personal finance — only `<DEV_USER>` (and root) reads it. It is already inside `~/.hermes`, so the brain backup (once §14 is applied) covers it.

**Tell Hermes about the tree** via a context file it auto-loads — drop a `SOUL.md` or `.hermes.md` stanza in the ops home describing the layout and the filing rules (Hermes auto-discovers `.hermes.md`, `AGENTS.md`, `CLAUDE.md`, `SOUL.md`). Example stanza:

```markdown
## Personal assistant data
Your data root is /home/<DEV_USER>/.hermes/data (referred to as DATA).
- Receipts: file originals under DATA/receipts/<YYYY>/<MM>/, name them
  <YYYY-MM-DD>_<merchant>_<amount>.<ext>. Record the expense via the ledger tool.
- Notes: one file per note at DATA/notes/<YYYY-MM-DD>_<slug>.md.
- Never edit DATA/ledger/*.csv by hand — always use the ledger_* tools.
- When you are unsure how to file something, leave it in DATA/inbox/ and ask.
```

---

## 3. Incoming files from Telegram — capability and the one real limitation

This is the only requirement where Hermes' current behaviour needs honesty rather than a config snippet.

**What works today:**
- **Vision read of photos.** A photo sent to the bot is visible to the model for reasoning — Hermes can *read a receipt's contents* (merchant, total, date) directly and write them to the ledger. For expense capture, this is enough on its own.
- **Voice notes.** The gateway downloads the audio into `~/.hermes/cache/audio/<hash>.ogg` and hands the agent a marker (`[The user sent a voice message: …/cache/audio/<hash>.ogg]`); transcription is handled, then treated like text.
- **Outbound files.** The agent emits `MEDIA:/abs/path/to/file` in a reply and the gateway ships it as a native Telegram attachment. The path must be **host-readable** (gateway runs on host, not in the Docker sandbox).

**The limitation (track it):** inbound **photos** are visible to vision but are **not** reliably exposed to file/terminal tools as a local path — so a literal *"save this exact image to receipts/"* cannot always be fulfilled from a compressed photo without the user re-sending. This is an open upstream issue: [NousResearch/hermes-agent#20899](https://github.com/NousResearch/hermes-agent/issues/20899).

**The working pattern (until the issue lands):**
1. **For data you care about (receipts): send as a Telegram _document_ (uncompressed "File"), not a compressed "Photo."** Documents are downloaded to the gateway's attachment cache with a real path, which `read_file`/`patch`/`ledger` can act on. (Photos are the lossy preview path; documents preserve bytes.)
2. **For quick capture:** send the photo normally — Hermes reads it with vision, extracts the fields, and writes the **structured ledger row** immediately. If you also want the original archived, send it as a document, or Hermes replies asking you to.
3. **Workflow:** new inbound file → staged in `inbox/` → Hermes proposes a filing (merchant/amount/date for receipts; slug for notes) → on your OK it moves the original to `receipts/<YYYY>/<MM>/` and appends the ledger row.

Re-check issue #20899 on each Hermes upgrade; when inbound photos gain tool-visible paths, step 1's "send as document" caveat disappears.

---

## 4. Receipts & finance tracking — the `ledger` plugin

Money is where a free-handed CSV becomes a real bug, so this is the one new plugin. Same contract as the existing repo plugins (`hermes/plugins/<name>/`, `register(ctx)`, handlers take an args dict, **always return a JSON string, never raise**, fixed argv / no shell).

**Decisions (resolved §17):** **single currency** — the validator rejects any row whose currency != `LEDGER_CURRENCY` (set once per deploy; this instance is `Asia/Beirut`, so set it to your day-to-day currency, e.g. `USD`). The `currency` column stays in the schema for clarity and future-proofing, but every row must match. **Categories = fixed allowlist + `other`** — the validator accepts a category from `LEDGER_CATEGORIES` or the literal `other` (with a free-text note); anything else is rejected so reports never fragment on typos.

**Files & schemas** (CSV, append-only, header row written on create):

```
ledger/expenses.csv : date,amount,currency,category,merchant,note,receipt_path
ledger/income.csv   : date,amount,currency,source,note
ledger/debts.csv    : date,counterparty,direction,amount,currency,due,status,note
                       # direction = owed_to_me | i_owe ; status = open | settled
```

**Tools** the plugin registers (toolset `ledger`):

| Tool | Tier | Does |
|---|---|---|
| `ledger_add_expense` | T2-local | validate + append a row to `expenses.csv` (links `receipt_path` if filed) |
| `ledger_add_income` | T2-local | append to `income.csv` |
| `ledger_add_debt` | T2-local | append to `debts.csv` |
| `ledger_settle_debt` | T2-local | mark a debt row `settled` |
| `ledger_report` | T1 | summarise by month/category/counterparty — totals, balances, who owes whom |

"T2-local" = it writes, but only to your own append-only files under `<ASSISTANT_DATA>` — no external side effect, no infra reach. Validation (amount is a number, date is ISO, currency in an allowlist) happens in Python, so the model can't corrupt the file. `ledger_report` reads and aggregates — safe to call freely (good for the morning briefing, W5).

**Config** — add `ledger` to the ops profile (built-in file tools stay available too):

```yaml
# /home/<DEV_USER>/.hermes/config.yaml  (additions)
tools:
  - read_file          # built-in: read notes/receipts text
  - patch              # built-in: edit notes
  - todo               # built-in: to-dos (§7)
  - ledger             # plugin (new, this repo)
plugins:
  enabled:
    - ledger
```

```yaml
# plugin.yaml (sketch)
name: ledger
version: 0.1.0
description: Personal finance ledger — expenses/income/debts over <ASSISTANT_DATA> (doc 14 §4)
provides_tools: [ledger_add_expense, ledger_add_income, ledger_add_debt, ledger_settle_debt, ledger_report]
requires_env:
  - ASSISTANT_DATA     # ledger root; defaults to ~/.hermes/data
  - LEDGER_CURRENCY    # single-currency guard, e.g. USD — rows in any other currency are rejected
  - LEDGER_CATEGORIES  # comma list of allowed expense categories; 'other' is always accepted
```

Starter category allowlist (tune to taste): `groceries,dining,transport,utilities,rent,health,subscriptions,shopping,travel,fees`. The validator also accepts `other` with a mandatory `note`, so nothing is unfilable — it just can't silently invent a new top-level category.

**Why a plugin and not just `patch`:** `patch` lets the model rewrite arbitrary file regions — fine for prose notes, wrong for an accounting file where one bad diff silently corrupts every future total. The plugin makes "add a row" the *only* write operation and validates it. (If you would rather not build it yet: Phase 1 in §15 runs the whole flow on `read_file`/`patch` + the directory convention; upgrade to the plugin when the ledger has enough rows to be worth protecting.)

---

## 5. Notes

No new code — built-ins cover it.

- **Capture:** Hermes writes one markdown file per note at `notes/<YYYY-MM-DD>_<slug>.md` using `patch` (creates the file), front-matter optional (`tags:`, `created:`).
- **Retrieve:** two paths — (a) the built-in **memory** system already does FTS5 recall of things you've told it; (b) full-text search across the notes *files* uses the `file_search` ops plugin from §10 scoped to `notes/`, or `terminal` running `rg` over `notes/` (see §10 for why scoping matters).
- **Voice → note:** send a voice message → transcribed → "save that as a note" → file written. Zero extra config.

---

## 6. Reminders

Use the built-in `cronjob` tool for the *scheduling/delivery*, and a durable JSONL mirror for the *record* (so reminders survive a memory trim and are auditable/listable as data).

- **Set:** "remind me to call the landlord Tuesday 6pm" → Hermes creates a `cronjob` (one-shot or recurring) that delivers a Telegram message at the time, **and** appends a line to `reminders/reminders.jsonl`:
  ```json
  {"id":"cron_a1b2","text":"call the landlord","when":"2026-06-16T18:00:00","recurring":false,"created":"2026-06-14"}
  ```
- **List / cancel:** `cronjob` already supports list/update/pause/resume/remove; the JSONL mirror gives a human-readable record and lets the ledger/briefing tooling reason over upcoming items.
- **Family reminders** stay on the family profile's own `cron` (doc 05 §3.3) — "remind Dana piano at 5" — completely separate store, no access to your data tree.

> The durable mirror is a thin convention, not a plugin: Hermes appends the line with `patch`/`read_file`. If you want guaranteed schema (like the ledger), fold a `reminder_add` tool into the same `ledger`/`assistant` plugin later — optional.

---

## 7. To-dos

Built-in `todo` tool handles the live list (add/complete/reorder, used for the agent's own planning too). Add two conventions:

- **Persistence/visibility:** mirror the active list to `todos/todos.md` so it's backed up and readable outside chat. Hermes rewrites that file with `patch` whenever the list changes.
- **Surfacing:** a `cronjob` ("every weekday 08:00, list my open to-dos") folds the to-do list into the morning briefing (W5, doc 07 §3) — to-dos you never see don't get done.

---

## 8. Google Calendar (MCP) — *Low priority*

Hermes is a native MCP client (stdio + HTTP). Google Calendar is one maintained MCP server away.

**Decision (resolved §17): read + create on request.** Hermes reads events to power reminders/briefings **and** can add events when you explicitly ask ("put dentist Tuesday 3pm"). Scope is `calendar.events`, and `tools.include` is widened to include the create-event tool — but **not** delete/update, so the bot can add but never quietly remove or rewrite an existing event. Every create still echoes back the event (title/time) before writing (the doc 07 §8 confirm habit).

**Pick a maintained server.** Two solid options as of 2026-06:
- `@cocal/google-calendar-mcp` (nspady) — tools `list-calendars`, `list-events`, `search-events`, `get-event`; OAuth via `GOOGLE_OAUTH_CREDENTIALS`. Good read coverage.
- Google's own **Workspace MCP** server (developers.google.com/workspace) — first-party, broader scopes.

**Config** (ops profile only — never family):

```yaml
# /home/<DEV_USER>/.hermes/config.yaml  (additions; confirm mcp_servers shape against the MCP config reference)
mcp_servers:
  gcal:
    command: "npx"
    args: ["-y", "@cocal/google-calendar-mcp"]
    env:
      GOOGLE_OAUTH_CREDENTIALS: "/home/<DEV_USER>/.hermes/secrets/gcal_oauth.json"  # mode 600
    enabled: true
    timeout: 120
    tools:
      include: [list-events, search-events, get-event, list-calendars, create-event]   # read + create; no delete/update
      exclude: []
      resources: false
      prompts: false
```

> Confirm the exact tool names against your chosen server's README (`@cocal/google-calendar-mcp` exposes `list-events`/`search-events`/`get-event`/`list-calendars` and a create tool; names may differ slightly). The principle holds regardless: include read + create, omit delete/update.

**Setup notes (no guesswork — these are the real moving parts):**
- Create an OAuth client (Desktop type) in Google Cloud Console, download the credentials JSON to `~/.hermes/secrets/gcal_oauth.json` (`chmod 600`, owner `<DEV_USER>`). It is a **secret** → add to the doc 08 §2 secrets map (§14 below), never the repo.
- Scope: `https://www.googleapis.com/auth/calendar.events` (read + create). `tools.include` deliberately omits delete/update, so even with this token Hermes can add events but not remove or rewrite them.
- First run does an interactive OAuth consent; the server persists the refresh token. On a headless VPS, run the consent step once over an SSH-forwarded browser or paste-the-code flow per the server's README.
- **Reminders use:** the morning briefing (W5) and an hourly "anything in the next 2 hours?" cron read the calendar via these tools and push a Telegram nudge. The calendar is *input*; reminders are *output*.

---

## 9. Hermes Ops — server status reporting

Two layers, because "server status" means both *apps* and *host*:

**Apps — already covered.** The `coolify` plugin (`coolify_app_status`, `coolify_app_logs`, T1 read-only) reports per-app health, and the W5 briefing already assembles it (doc 07 §3, §5).

**Host metrics — the gap.** Disk/RAM/CPU/uptime/service-health is not covered (full monitoring is a named next-milestone, doc 00 §9). Fill it with a tiny **read-only** plugin rather than handing Hermes a raw host shell:

```
hermes/plugins/host_metrics/   →  tool: host_status   (T1, read-only)
```

`host_status` runs a **fixed, hardcoded set** of read-only commands (no args from the model, no shell) and returns parsed JSON:

```python
# fixed argv list — the model cannot influence what runs
_PROBES = {
    "uptime":   ["uptime", "-p"],
    "disk":     ["df", "-h", "--output=target,pcent,avail", "/"],
    "memory":   ["free", "-m"],
    "load":     ["cat", "/proc/loadavg"],
    "services": ["systemctl", "is-active", "hermes-ops", "hermes-family", "docker"],
}
```

This is T1 by construction: it can only *observe*. It needs the **host** execution context, so run it via the plugin's own subprocess on the host (like `coolify`/`multica` do) — not the Docker `execute_code` sandbox. Add `host_metrics` to the ops `plugins.enabled` and the briefing prompt ("…and host disk/RAM/uptime via host_status").

> When the real monitoring stack (Uptime Kuma + alerting, doc 00 §9) lands, `host_status` becomes the cheap conversational front-end to it ("how's the server?") rather than the alerting mechanism.

---

## 10. Hermes Ops — file searching

You want Hermes to find files/content on the server. The honest constraint: the ops `execute_code` backend is **Docker, mount-less** (doc 05 §4), so a sandboxed `terminal`/`rg` sees *nothing on the host*. Two clean options:

- **A. Scoped read-only `file_search` plugin (recommended).** A plugin (host subprocess, like `coolify`) exposing `file_search(query, root)` where `root` is validated against an **allowlist** of host roots — e.g. `~/projects`, `<ASSISTANT_DATA>/notes`, `~/.hermes/data`. Internally it runs `rg --files-with-matches` / `rg -n` (or `fd` for names) with a fixed flag set, capped result count, no shell. Read-only (T1), can't escape the allowlist, can't read `~/.hermes/.env` or other users' homes.

  ```
  hermes/plugins/file_search/  →  tools: file_search_content (rg), file_search_name (fd)
  # allowlist roots from env, e.g. FILE_SEARCH_ROOTS=/home/<DEV_USER>/projects:/home/<DEV_USER>/.hermes/data
  ```

- **B. `terminal` on the SSH/local backend, allowlisted.** Heavier hammer; see §11 — only if you accept the broader exposure. For *search specifically*, the scoped plugin (A) gives you 95% of the value at T1 with no host-shell surface.

This also backs notes retrieval (§5) and "where did I put the X contract?" queries.

---

## 11. Hermes Ops — running commands on the server (read this before enabling)

This is the most dangerous ask and the one that most directly tensions the security model (doc 07 §1, doc 08 §1). Be deliberate.

**Decision (resolved §17): scoped tools, add named actions later — no open host shell.** Ship the four scoped tools below (they cover day-to-day ops), and when a genuinely new admin action is needed, add it as a single **named, fixed-argv, echo-and-confirm** T3 tool — never a general `terminal`-over-SSH shell. The "real host shell" option further down stays documented as a fallback, but is **not** the chosen path; revisit only if named actions prove insufficient.

**The model's stance:** agents are *capability-constrained, not trusted* (doc 08 §1.3). A general "run any command on the host" tool is a T3-everything firehose that defeats the tier system. So **do not** point the ops `terminal` tool at the local/SSH host backend as an open shell. Instead, decompose "run commands" into the specific things you actually need:

| What you actually want | The right mechanism | Tier |
|---|---|---|
| App ops (restart/redeploy/clear cache) | `coolify` plugin (`coolify_app_restart`/`_deploy`), scoped token, echo-and-confirm | T3, named list (doc 07 §8) |
| Check host health | `host_status` plugin (§9) | T1 |
| Find files/content | `file_search` plugin (§10) | T1 |
| Throwaway compute / scripts | `execute_code` Docker sandbox, no mounts/network (doc 05 §4) | T0/T1 |
| A genuinely new admin action | add a **named, fixed-argv** tool for *that action* (like the probes in §9) | T3, confirmed |

**If you still want a real host shell** (e.g. for ad-hoc admin you'd otherwise SSH in for): enable `terminal` on the **SSH backend** pointed at the host, but gate it hard —
- an **explicit command allowlist** (the tool refuses anything not matching a prefix list),
- **echo-and-confirm** before every run (the doc 07 §8 "confirm" protocol),
- everything logged to the audit trail (doc 08 §5 — the Telegram confirmation thread *is* the audit log),
- **ops profile only**, and ideally a non-sudo target user so the blast radius is `<DEV_USER>`, not root.

Recommendation: start with the four scoped tools above (they cover the real day-to-day) and add named T3 actions one at a time as concrete needs appear, rather than opening a shell. Every new T3 action is a line you can point to in the audit log; an open shell is not.

---

## 12. Multica integration (enhancements)

Already wired (doc 06 §10, `multica` plugin: create/list/status/assign/search). Two enhancements worth doing:

- **Real-time notifications.** Today the "PR ready / issue done" signal rides a cron poll ("every 30 min, report newly completed Multica issues", doc 06 §10). Upgrade to push: a Multica webhook → a small endpoint → Telegram, or have Hermes subscribe to the daemon's event stream if exposed. Until then the cron poll is the documented, working path — keep it.
- **Issue-from-context.** The W7 pattern (doc 07 §3): Hermes researches → you approve → it files a Multica issue. The `multica_create_issue` schema already enforces the PO contract ("only after the user approved"). No change needed — just exercise it.

No new build required for "Multica integration" beyond what doc 06 ships; the notification push is the one genuine enhancement.

---

## 13. Security & profile boundaries (recap of what must stay true)

- **Family profile unchanged:** still `tools: [web_search, image_generation, cron]`, no plugins, no filesystem, no `<ASSISTANT_DATA>`, no MCP. Its profile test (`hermes/tests/test_profiles.py`) must keep failing the build if anyone widens it.
- **Personal data is `700`, owner `<DEV_USER>`** — not world-readable, not reachable by `<AGENT_USER>` (the family/`hermes` OS user). Verify: `sudo -u <AGENT_USER> cat /home/<DEV_USER>/.hermes/data/ledger/expenses.csv` → permission denied.
- **New secrets** (Google OAuth credentials JSON) follow doc 08 §2: `~/.hermes/secrets/`, mode 600, owner `<DEV_USER>`, **never** in the repo. No new API keys in env files beyond what each tool needs.
- **Tier discipline:** `ledger_*` writes only to your local files (no infra reach); `host_status`/`file_search` are read-only (T1); calendar MCP is read-scoped via `tools.include`; the only T3 additions are named, confirmed, allowlisted.
- **`ANTHROPIC_API_KEY`/`OPENAI_API_KEY` still appear nowhere** (CLAUDE.md §9). None of this changes the auth model.

---

## 14. Backup matrix additions (proposed doc 08 deltas — do not apply silently)

Adding stateful data means doc 08 §4.1 must grow, or you'll lose it. **Two gaps surface:**

1. **Ops Hermes home isn't in the matrix.** Doc 08 §4.1 backs up `/home/<AGENT_USER>/.hermes` (family) but ops Hermes moved to `<DEV_USER>` (doc 06 §10) — its memory, skills, and now `<ASSISTANT_DATA>` are **not** currently backed up.
2. **The data tree** (`<ASSISTANT_DATA>`) is irreplaceable personal data.

Proposed matrix additions (fold into the nightly `restic backup` line, doc 08 §4.2):

| Data | Path | Why irreplaceable |
|---|---|---|
| Ops Hermes brain | `/home/<DEV_USER>/.hermes/` (memory, skills, config, logs) | the ops agent's learning + your assistant data |
| Personal data tree | `/home/<DEV_USER>/.hermes/data/` (inside the above) | receipts, ledger, notes, reminders, to-dos |

And one **secrets-map** row (doc 08 §2):

| Secret | Lives at | Owner | Scope |
|---|---|---|---|
| Google OAuth credentials (calendar MCP) | `~<DEV_USER>/.hermes/secrets/gcal_oauth.json` | `<DEV_USER>` | calendar.events (or readonly); revocable in Google Cloud Console |

> Per CLAUDE.md ("never contradict a doc silently"): these are **proposed** edits to docs 08, listed here so they land in the same PR that builds any of §4/§8. They are not yet applied to doc 08.

---

## 15. Rollout order

Mirror doc 07 §5 — don't build it all at once; each step delivers value and de-risks the next.

1. **Data tree + context stanza (§2)** — zero code. Hermes can already file notes and read receipts via vision the moment the directory and `SOUL.md` stanza exist. *Instant value.*
2. **Reminders + to-dos (§6, §7)** — built-in `cronjob`/`todo` + the JSONL/markdown mirrors. Still no plugin.
3. **`ledger` plugin (§4)** — the first new code; protect the money file once the flow is proven on built-ins.
4. **Ops read-only plugins: `host_status` (§9), `file_search` (§10)** — T1, safe, high daily utility.
5. **Calendar MCP (§8)** — *Low* priority; do after the OAuth dance is worth it.
6. **Multica push notifications (§12)** and any **named T3 host actions (§11)** — last, one at a time, each with a confirm + audit line.

Distill each working flow into a Hermes skill (agentskills.io-compatible) so the next run is cheaper — same discipline as doc 07 §5.

---

## 16. Verified upstream (CLAUDE.md §5, 2026-06-14)

| Fact | Source |
|---|---|
| Built-in tools: `read_file`, `patch` (Terminal & Files); `terminal` (backends local/Docker/SSH/Modal/Daytona/Singularity); `cronjob` (create/list/update/pause/resume/run/remove); `todo` (orchestration) | hermes-agent.nousresearch.com/docs/user-guide/features/tools |
| Memory `MEMORY.md`/`USER.md`, FTS5 cross-session recall, Honcho user modeling; skills (agentskills.io); 60+ tools; subagents; `execute_code` | hermes-agent.nousresearch.com/docs/user-guide/features/overview |
| Context-file auto-discovery (`.hermes.md`, `AGENTS.md`, `CLAUDE.md`, `SOUL.md`) | hermes-agent.nousresearch.com/docs/user-guide/features/overview |
| MCP client stdio+HTTP, `mcp_servers` config (`command`/`args`/`env`, `url`/`headers`, `enabled`, `timeout`, `tools.include/exclude`), tool naming `mcp_<server>_<tool>` | hermes-agent.nousresearch.com/docs/reference/mcp-config-reference |
| Telegram inbound voice cached at `~/.hermes/cache/audio/<hash>.ogg`; outbound `MEDIA:/path` tag; gateway runs on host (Docker caveat) | github.com/NousResearch/hermes-agent .../messaging/telegram.md |
| Inbound photos visible to vision but **not** exposed as tool-accessible file paths (open) | github.com/NousResearch/hermes-agent/issues/20899 |
| Google Calendar MCP servers: `@cocal/google-calendar-mcp` (read tools, OAuth via `GOOGLE_OAUTH_CREDENTIALS`); Google Workspace MCP (first-party) | github.com/nspady/google-calendar-mcp ; developers.google.com/workspace/calendar/api/guides/configure-mcp-server |

---

## 17. Decisions (resolved 2026-06-14)

1. **Ledger currency & categories** → **single currency** (env `LEDGER_CURRENCY`, validator rejects others) + **fixed category allowlist plus `other`** (env `LEDGER_CATEGORIES`; `other` always accepted with a note). Folded into §4.
2. **Calendar scope** → **read + create on request** (`calendar.events`; `tools.include` adds the create tool but omits delete/update). Folded into §8.
3. **Host commands** → **scoped tools, add named T3 actions later — no open host shell.** Folded into §11.

All three are settled; the whole doc can now proceed on the rollout order in §15. The only remaining first-deploy confirmations are config-key shapes against `hermes setup` and the calendar server's exact tool names (flagged inline).
