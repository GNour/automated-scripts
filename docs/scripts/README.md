# Scripts project — build backlog ([task] issues for the Multica squads)

The dependency-ordered decomposition of **doc 16** (the scripts project) into
`[task]` issues, ready to create in Multica and assign to the **Engineering**
squad (doc 15). Each file here = one Multica issue = one PR (doc 04 §1.2),
following the `issue-templates/task-issue.md` format.

> **Role note:** doc 16 is the spec (the Product Owner / tech-lead plan). These
> are its child `[task]` issues. Create them in the **`scripts`** Multica
> project; assign each to the runtime + agent in its **Routing** block. Every
> PR goes to the **Quality & Review** squad — **security-auditor review is
> mandatory** here (host-touching code, doc 16 §5.3).

## Order & routing

| # | Task | Runtime | Agent | Depends on |
|---|---|---|---|---|
| 01 | Scaffold the repo + Team block + manifest | claude-code | python-engineer | — |
| 02 | CI pipeline (shellcheck + ruff/mypy/pytest) | claude-code | devops-engineer | 01 |
| 03 | `ops_scripts` Hermes plugin (manifest-driven tools) | claude-code | python-engineer | 01 |
| 04 | `health-report` (vps, T1) | codex | — | 01 |
| 05 | `backup-check` (vps, T1) | codex | — | 01 |
| 06 | `cert-expiry` (vps, T1) | codex | — | 01 |
| 07 | `docker-cleanup` (vps, **T3**) | claude-code | shell-engineer | 01 |
| 08 | `coolify-status` (infra, T1) | claude-code | devops-engineer | 01 |
| 09 | `coolify-deploy` (infra, **T3**) | claude-code | devops-engineer | 01, 08 |
| 10 | `ansible-drift` (infra, T1) | claude-code | devops-engineer | 01 |
| 11 | `subs-report` + `subscriptions.yaml` schema (T1) | claude-code | python-engineer | 01 |
| 12 | `usage-report` (subscriptions, T1) | codex | — | 01 |
| 13 | `morning-briefing` (reports, T1, aggregator) | claude-code | python-engineer | 04, 08, 11 |
| 14 | `weekly-summary` (reports, T1) | codex | — | 01, 08 |
| 15 | Wire tools into `ops_scripts` + ops profile; Telegram smoke test | claude-code | python-engineer | 03, + the scripts |

## Sequencing notes (the orchestrator's discipline)

- **01 first, alone** — it writes the `AGENTS.md` Team block + the "Conventions
  for Codex-routed work" skill-mirror (doc 09 §4.4) that every **codex** task
  below relies on. Don't start Codex tasks until 01 is merged.
- **Establish the pattern on Claude, then fan out to Codex.** 04–06, 12, 14 are
  routed to **codex** (well-scoped single scripts, doc 09 §4.3) — but run the
  first shell script (04) and first Python script (11) reviewed carefully so the
  repo conventions are concrete before Codex copies them.
- **Pool discipline (doc 06 §9):** one Claude task and one Codex task at a time;
  never parallelize within a pool.
- **03 and 15 bracket the run-side** — the plugin, then the wiring + Telegram
  smoke test. 13 (`morning-briefing`) depends on its source scripts existing.
- T3 tasks (07, 09) carry the `--dry-run`-default + echo-and-confirm contract
  (doc 07 §8, doc 16 §4).
