<!-- [task] — child of doc 16. One task = one agent session = one PR. -->

# Wire the tools into the ops profile + Telegram smoke test

**Parent:** doc 16 · **Depends on:** task-03 (+ the script tasks being merged)

## Routing

**Runtime:** claude-code
Use the **python-engineer** subagent.
<!-- claude-code: integration + touches the ops profile config (role-gated). -->

## Files / areas

- `hermes/profile-templates/ops.yaml` (enable `ops_scripts`, list the tools),
  `~/projects/scripts/manifest.yaml` (final tier-tagged tool list), the W5/weekly
  crons (doc 07).

## Acceptance criteria (this task's slice)

- [ ] `ops_scripts` enabled on the **ops profile only**; the manifest lists every
      shipped tool with the correct tier (t1/t3).
- [ ] T1 tools callable from Telegram on request ("how's the server?", "my
      morning report"); a T3 tool ("clean up docker") **echoes + waits for
      confirm** before running (doc 07 §8, doc 16 §4).
- [ ] Crons added: W5 morning briefing (`morning_briefing`) and a weekly
      `weekly_summary` push to Telegram.
- [ ] Family profile still has no `ops_scripts` (profile test passes, doc 14 §13).

## Notes

The closing integration task — proves the run loop end-to-end from Telegram
(doc 16 §7). Don't start until the plugin (task-03) and the scripts it exposes
are merged. Quality & Review, security-auditor mandatory (privilege boundary +
profile config).
