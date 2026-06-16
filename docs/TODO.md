# docs/TODO.md — backlog tracker

Running list of agreed-but-not-yet-built work. Source of truth for *what* and
*why* stays in the numbered docs; this file is just the checklist. Tick items as
PRs land; move done items to the bottom or delete.

---

## Hermes enhancements (doc 14)

Rollout order is doc 14 §15. **Phase 1 is done** (data tree + ops context +
built-in assistant tools enabled). Remaining:

### Phase 2 — reminders + to-dos (no new code)
- [ ] Exercise built-in `cron` for reminders; on each reminder, append the
      mirror line to `~/.hermes/data/reminders/reminders.jsonl` (schema in
      `ops.SOUL.md`).
- [ ] Mirror the live `todo` list to `~/.hermes/data/todos/todos.md` on change.
- [ ] Add a weekday-08:00 cron that folds open to-dos into the morning briefing
      (W5, doc 07 §3).

### Phase 3 — `ledger` plugin (the one new plugin) — doc 14 §4
- [ ] Build `hermes/plugins/ledger/` (`plugin.yaml` + `register(ctx)` +
      `schemas.py` + `tools.py`), contract per `hermes/README.md`.
- [ ] Tools: `ledger_add_expense`, `ledger_add_income`, `ledger_add_debt`,
      `ledger_settle_debt`, `ledger_report`.
- [ ] Validator enforces **single currency** (`LEDGER_CURRENCY`) and the
      **category allowlist + `other`** (`LEDGER_CATEGORIES`). Decisions: doc 14 §17.
- [ ] Tests under `hermes/tests/test_ledger.py` (no network, like the others).
- [ ] Uncomment `# - ledger` in `profile-templates/ops.yaml` + add to
      `plugins.enabled`; update `ops.SOUL.md` to prefer the tool over hand-edits.

### Phase 4 — ops read-only plugins — doc 14 §9–§10
- [ ] `hermes/plugins/host_metrics/` → `host_status` (T1, fixed argv probes:
      uptime/disk/memory/load/service-is-active). Add to ops `plugins.enabled`
      and the briefing prompt.
- [ ] `hermes/plugins/file_search/` → `file_search_content` (rg) +
      `file_search_name` (fd), allowlisted roots via `FILE_SEARCH_ROOTS`, T1.

### Phase 5 — Google Calendar MCP — doc 14 §8 (Low priority)
- [ ] Pick a maintained server (`@cocal/google-calendar-mcp` or Google Workspace MCP).
- [ ] OAuth client (Desktop), creds JSON → `~/.hermes/secrets/gcal_oauth.json`
      (mode 600); run the one-time consent on the headless box.
- [ ] `mcp_servers.gcal` config; `tools.include` = read + create, **omit
      delete/update**. Scope `calendar.events`. Decision: doc 14 §17.

### Phase 6 — Multica push + named T3 host actions — doc 14 §11–§12
- [ ] Replace the cron poll with a Multica webhook → Telegram push.
- [ ] Add named, fixed-argv, confirm-gated T3 host actions only as concrete
      needs appear (no open host shell). Decision: doc 14 §17.

---

## Doc edits owed (don't apply silently — bundle with the relevant build PR)

- [ ] **doc 08 §4.1 backup matrix** + `ansible/group_vars/all.example.yml`:
      add `/home/<DEV_USER>/.hermes` and the data tree, and the Google OAuth
      secret row to doc 08 §2 (doc 14 §14). *Note: live `group_vars/all/main.yml`
      already backs up `~/.hermes`; this is the example/doc catching up.*

## Verification owed (toolchain not present in the authoring env)

- [ ] Run full `uv run pytest` (25 tests) + `uv run ruff check` in `hermes/`
      on the dev box before merging the Phase 1 branch.
- [ ] Run `make lint` (yamllint + ansible-lint) for the `users` role changes.
