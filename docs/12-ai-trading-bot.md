# 12 — AI Trading Bot (Freqtrade × Binance × LLM Analyst)

**Goal:** an autonomous trader on the VPS — a **rule-based Freqtrade engine** trading Binance spot, supervised by an **LLM analyst** that reports to you and can only ever *reduce* risk, with **Telegram as your control channel and kill switch**.

**The design stance (why this is safe enough to run):** the LLM never holds the order pen. A deterministic engine trades fixed rules with engine-enforced risk limits; the analyst reads state 4×/day, journals its reasoning, messages you a digest, and may execute only a code-allowlisted set of risk-reducing actions. Five independent safety layers (§2) each work when the others fail.

**Milestone discipline:** this is its own milestone with a hard gate — **backtest → dry-run ≥ 4 weeks → live with small capital** (§10). Nothing here is investment advice; losses are possible and normal.

---

## 1. Variables (extends doc 00 §1)

| Variable | Meaning | Example |
|---|---|---|
| `<TRADER_USER>` | Unprivileged Linux user running the analyst timer | `trader` |
| `<TRADER_BOT>` | Dedicated Telegram bot for the trader (3rd bot — never shared with Hermes) | `@..._trader_bot` |
| `<BOT_CAPITAL>` | Fixed allocation moved to Binance Spot — all the bot can ever see | *(yours)* |
| `<FT_VERSION>` | Pinned Freqtrade image tag (never `:stable` in live) | *(current release)* |

## 2. Architecture & the five safety layers

```
Binance Spot ←─ orders + ON-EXCHANGE stoplosses ──┐
                                                   │
┌─ Coolify (Docker) ────────────────────────────────────────────┐
│  freqtrade engine  ── REST :8080 (internal only) ──┐          │
│  (rules + config = the only thing that can BUY)    │          │
└─────────────────────────────────────────────────────│──────────┘
   │ Telegram: fills, warnings, /commands             │
   ▼                                                  │
  YOU ◄── 4×/day digest ── analyst cycle (systemd timer, <TRADER_USER>)
              │                 reads state → LLM via OpenRouter → guardrails
              └── journal/ (every cycle, every decision, every rejection)
```

| # | Layer | Lives where | Protects against |
|---|---|---|---|
| 1 | **Stoploss on exchange** (stop-loss-limit on Binance's servers) | Binance | VPS crash, network loss, bot bug mid-trade |
| 2 | **Engine config** (max trades, stake ratio, hard stoploss, blacklist) | Freqtrade config — *not LLM-writable* | bad strategy logic, LLM influence |
| 3 | **API key scoping** (no withdrawal, IP-locked to `<SERVER_IP>`) | Binance key settings | key leak — a stolen key can trade, never withdraw |
| 4 | **Agent guardrails** (code-enforced action allowlist) | `guardrails.py` | LLM hallucination — cannot open positions or touch config |
| 5 | **You + kill switch** (`/stopbuy` → `/forceexit all` → revoke key) | your phone | everything else |

**Tier mapping (doc 07 §1):** the engine is *not an agent* — deterministic rules, no tiers. The analyst is T1 (read) plus a deliberate variant of the named-T3 list: `forceexit` / `stopbuy` / `blacklist` execute **without** echo-and-confirm because (a) every verb only reduces exposure, (b) the allowlist is enforced in code, not prompt, and (c) drawdown protection can't wait for a human asleep. Opening positions is impossible *by construction* for everyone but the engine: `force_entry_enable: false` kills the force-entry endpoint itself. Your confirm-gated path is the kill switch (layer 5).

## 3. Binance account & API key

**Account hygiene (once):** 2FA via authenticator app · anti-phishing code on · move `<BOT_CAPITAL>` to Spot and keep everything else in Funding/Earn (physical separation; `tradable_balance_ratio` is the second fence) · BNB fees: keep ~$25 of BNB in Spot with "Use BNB for fees" ON (0.075% taker) and blacklist `BNB/.*` so the bot never trades its own fee asset.

**API key** (Profile → API Management → Create, label `freqtrade-vps`):

| Setting | Value |
|---|---|
| Enable Reading / **Spot & Margin Trading** | ✅ / ✅ (bot won't start without Spot write) |
| Withdrawals / Futures / Margin loans | ❌ **never** / ❌ / ❌ |
| IP restriction | **Trusted IPs only** → `<SERVER_IP>` (Binance auto-expires unrestricted trade keys — good) |

Secret is shown **once** → password manager immediately; later only Coolify env vars. Never the repo. Use `binance` (international CCXT id), not `binance.us`. **Rotation:** every 90 days, and immediately on VPS rebuild/replacement (new egress IP = dead key anyway), accidental exposure, or any unexplained order. Rotation = new key → update Coolify env → redeploy → delete old (~1 min).

## 4. Telegram — control channel & kill switch

A **dedicated** `<TRADER_BOT>` via @BotFather (token + your numeric chat id; doc 05 §3.1 mechanics). Deliberately *not* a Hermes profile: the kill switch must not share fate, tokens, or process with the orchestrator. Freqtrade's native Telegram gives you:

`/status` open trades · `/profit` P&L · `/balance` wallet · **`/stopbuy`** halt new entries · **`/forceexit <id|all>`** close now · `/stop` `/start` · `/reload_config`

**Kill-switch drill (memorize, rehearse in dry-run on day one):** `/stopbuy` → `/forceexit all` → if compromise suspected, delete the API key in the Binance app. Target: **under 2 minutes from your phone.**

> Optional, later (earn-the-slot rule, doc 10 §3.4): a read-only `freqtrade_status` tool in Hermes' ops profile so the morning briefing (W5) can include the trader. T1 only — control stays on the dedicated bot.

## 5. The `trading-bot` repo (the build unit)

New **private** GitHub repo, built through the org pipeline (doc 09) — PO issue → tech-lead plan → tasks routed per its `AGENTS.md` Team block (`runtimes: claude-code, codex` · `agents: python-engineer, qa-engineer, devops-engineer`):

```
trading-bot/
├── AGENTS.md + CLAUDE.md (@AGENTS.md)   # handbook, Team block (templates/)
├── docker-compose.yml                   # engine; no host ports published
├── .env.example                         # template only — real env in Coolify
├── user_data/
│   ├── config.json                      # no secrets — env-substituted
│   └── strategies/BaselineStrategy.py
├── agent/
│   ├── cycle.py                         # snapshot → LLM → guardrails → execute → journal
│   ├── guardrails.py                    # the §8 contract
│   ├── freqtrade_client.py              # thin REST wrapper (3 mutating calls total)
│   ├── prompts/analyst.md               # operating manual + hard rules
│   └── requirements.txt                 # requests — nothing else
├── journal/                             # gitignored; restic-backed (doc 08)
└── ops/                                 # systemd service + timer, backup include list
```

The reviewed reference implementation (the June 2026 planning guide) seeds the first issues; **doc 12 wins where they differ** (provider, users, exposure — §13).

## 6. Engine deployment (Coolify)

Coolify → New Resource → **Docker Compose** → the repo. Engine env (all as **Coolify secrets**): `BINANCE_KEY/SECRET`, `TELEGRAM_TOKEN/CHAT_ID`, `FT_API_USER/PASSWORD/JWT_SECRET` (generate with `openssl rand -hex 32`). Freqtrade maps `FREQTRADE__SECTION__KEY` env vars onto config — secrets never touch `config.json`.

Key config decisions (the *why* — full file in the repo):

| Setting | Value | Why |
|---|---|---|
| `dry_run` | `true` until §10 passes | the gate |
| `max_open_trades` / `tradable_balance_ratio` | `3` / `0.30` | engine-enforced exposure cap (layer 2) |
| `stoploss_on_exchange` + 60s refresh | `true` | layer 1: the stop lives on Binance, survives the VPS |
| `force_entry_enable` | `false` | kills `/forcebuy` + the REST endpoint — nothing outside the rules can buy |
| `pair_whitelist` | BTC/ETH/SOL vs USDT | liquid majors only for v1 |
| `pair_blacklist` | `BNB/.*`, `.*UP/ DOWN/ BULL/ BEAR/USDT` | fee-asset rule + leveraged-token decay |
| entry/exit orders | limit, order-book top, GTC, 10-min unfilled timeout | predictable fills |
| image | `freqtradeorg/freqtrade:<FT_VERSION>` | pin and bump deliberately — same philosophy as every fast-moving tool here (rule 5) |

**FreqUI exposure:** none publicly. The compose publishes no ports; reach the dashboard via Tailscale or an SSH tunnel to `:8080` — same doctrine as Coolify/Multica (doc 00 §5). The analyst reaches the REST API over localhost/Docker network only.

**First boot (dry-run):** logs show `Dry run is enabled` + exchange validation + Telegram "Bot started" · FreqUI shows simulated 1000 USDT · run the kill-switch drill once. Frequent failures: key typo / IP mismatch (`curl ifconfig.me` from the VPS), Spot-trading not ticked, clock drift (`timedatectl` → synchronized: yes — Binance signs requests with timestamps).

## 7. Baseline strategy v1 (intentionally boring)

EMA20>EMA50 uptrend filter + RSI 40–65 pullback entry + volume confirmation; exit on trend break or RSI > 78. Purpose: a measurable, explainable pipeline — not alpha. **Engine-enforced risk numbers** (layer 2, in the strategy class, not LLM-touchable):

| Parameter | Value |
|---|---|
| Hard stoploss (mirrored on-exchange) | **−5%** (not tighter — a too-tight stop-limit can miss in a fast wick) |
| Trailing stop | 2% behind, armed at +4% profit |
| Take-profit ladder (`minimal_roi`) | 8% anytime → 4% after 4h → 1% after 24h |
| Timeframe / shorting | 1h / `can_short: false` |

**Backtest before anything** (engine container, repo `docs/backtests.md` records every run): download ≥18 months of 1h candles → backtest → record total profit, win rate, **max drawdown**, profit factor, trade count. Acceptance is honest, not heroic: a drawdown you could stomach live, and >50 trades so the stats mean something. Hyperopt sparingly — overfitting is the #1 trap. Dry-run behavior must then *track* the backtest; divergence = signal logic differs between modes, fix first.

## 8. The analyst agent (supervision layer)

**Cycle (4×/day, systemd timer as `<TRADER_USER>`):** snapshot via REST (balance, open trades, profit, per-pair performance, last 10 closed) → LLM call → `guardrails.validate()` → execute accepted actions → append journal entry (+ rejections) → Telegram digest → write `heartbeat.json`. **Fail-safe by design:** a failed cycle does nothing — the engine keeps trading its rules, on-exchange stops keep protecting.

**Provider:** **OpenRouter** with a *dedicated* key, monthly cap ~$10 — same pattern as Hermes (doc 05 §2.1), Sonnet-class model. Never `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` (rule 9 — those flip the dev CLIs to API billing; the trading agent gets its own metered key). Swap to a LiteLLM virtual key when that layer lands (doc 00 §9) — same OpenAI-compatible shape, one env change.

**The guardrails contract** (the load-bearing 20 lines — model proposes, code disposes):

```python
ALLOWED = {
    "forceexit": {"trade_id": re.compile(r"^\d{1,6}$")},
    "stopbuy":   {},
    "blacklist": {"pair": re.compile(r"^[A-Z0-9]{2,10}/USDT$")},
    "note":      {"text": lambda s: isinstance(s, str) and len(s) < 2000},
}
MAX_ACTIONS_PER_CYCLE = 3   # an analyst proposing 10 actions is malfunctioning
```

Anything else is rejected and logged. The client wrapper contains exactly three mutating calls (`forceexit`, `stopbuy`, `blacklist`) — there is no code path to entries, config, or strategy.

**Analyst hard rules (prompt, enforced by review):** drawdown >10% from peak → propose `stopbuy` + explain · `forceexit` only when within 1% of the stop *and* the thesis is broken — otherwise let the engine stop do its job · uncertain → `note`; doing nothing is valid and often correct · never claim certainty; always journal; digest ≤600 chars leading with portfolio value + open count.

**Secrets/user model (doc 08 §2):** `<TRADER_USER>` is a fourth managed user — sudo ❌, docker ❌, one `managed_users` entry in the Ansible inventory (variables-only, zero role code). Its env file (mode 600): `FT_API_URL/USER/PASSWORD`, `OPENROUTER key (capped)`, `TELEGRAM_TOKEN/CHAT_ID`. Hermes cannot read it; it cannot read Hermes'.

## 9. Monitoring & backups (extends doc 08)

- **Heartbeat:** if `heartbeat.json` is older than 8h → Telegram alert. Until the monitoring stack lands, the W5 briefing slot covers it (doc 08 §5 pattern).
- **Backups:** add to `backup_paths` (inventory-only): the freqtrade `user_data/` volume (contains `tradesv3.sqlite` — full trade history/state) and `journal/`. `.env` is *not* backed up — secrets live in the password manager + Coolify.
- **Restore drill:** monthly, restore `tradesv3.sqlite` + config to a scratch dir, boot a dry-run container against it (doc 08 §4.3 discipline).
- **Weekly human review (non-negotiable):** read the journal, check guardrail rejections (any rejection = tighten the prompt), compare equity curve vs backtest expectation. No time this week? `/stopbuy` first, catch up later.

## 10. Validation gates

**Dry-run exit criteria (ALL required, ≥4 weeks):**

- [ ] Dry-run trade pattern ≈ backtest pattern (same signals, comparable hold times).
- [ ] Zero unexplained guardrail rejections; zero unaccounted failed cycles.
- [ ] Observed max drawdown tolerable with real money.
- [ ] Kill-switch drill performed twice, under 2 minutes.
- [ ] Restic restore of `tradesv3.sqlite` tested once.
- [ ] Every agent intervention explainable from the journal alone.

**Go-live:** transfer `<BOT_CAPITAL>` → flip `FREQTRADE__DRY_RUN=false` in Coolify → redeploy → startup message confirms live + `/balance` matches reality → **week-1 throttle**: `max_open_trades: 1`, `tradable_balance_ratio: 0.10`, watch every fill, and **verify the stop-loss order appears in the Binance app after the first entry fills** (layer-1 proof) → two clean weeks → restore policy values.

## 11. Runbook

| Situation | Action |
|---|---|
| Pause new trades / exit everything | `/stopbuy` · `/forceexit all` |
| Suspected key compromise | Binance app → delete key, then `/stop` |
| VPS down | Positions safe (stops live on Binance). Redeploy via Coolify; bot recovers state from `tradesv3.sqlite` |
| Agent misbehaving | `systemctl disable --now trading-agent.timer` — engine unaffected |
| Strategy change | edit → backtest → dry-run branch → only then live. Never hot-edit live |

## 12. Costs

LLM cycles (4×/day Sonnet-class): **~$4–7/mo**, hard-capped at $10 by the key. Binance spot fees 0.1%/fill (0.075% with BNB). Everything else: $0 incremental on existing infra.

## 13. Deltas vs the original planning guide (reconciled here)

The June 2026 standalone guide remains the reference implementation; this doc wins where they differ: provider is **OpenRouter now / LiteLLM later** (guide assumed LiteLLM, which is roadmap); the analyst runs as **`<TRADER_USER>`**, not the admin user; **FreqUI is Tailscale/tunnel-only**, never a public domain; the **image tag is pinned**, not `:stable`; host naming uses doc 00 variables. Per rule 5, verify the Freqtrade config schema and REST endpoints against the pinned version's docs during the build.

## 14. Reuse notes

- The pattern — deterministic engine + read-mostly LLM supervisor + code allowlist + human kill switch — is the productizable unit, and it generalizes far beyond trading (any risky automation a client wants "an AI to watch").
- Per-client: own Binance key (their account), own `<TRADER_BOT>`, own capped provider key, own journal — nothing shared, same repo template.
- This doc doubles as the governance story: every action the model can take is enumerable in 20 lines of code, and every decision it ever made is in the journal.
