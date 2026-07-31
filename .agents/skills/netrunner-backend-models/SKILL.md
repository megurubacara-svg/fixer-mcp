---
name: netrunner-backend-models
description: "Authoritative backend/model/reasoning routing table for Netrunner wave workers. Check quota via check-my-limits (cml) BEFORE choosing; unavailable models are off-limits. Use for every wave launch backend/model decision."
---

# Netrunner Backend/Model Routing

Use this skill before every `launch_netrunner_wave` call to pick backend, model, and reasoning per worker.

## Rule 0: quota gate first

Before choosing anything, run `check-my-limits` (alias `cml`) and read the current 5h/7d windows per provider bucket. A model whose bucket is exhausted (0% left) or burning paid usage credits is OFF-LIMITS, no matter what the routing table below says. When a window is exhausted but its reset is near, prefer waiting or another live bucket over spending credits.

## Rule 0.25: current Architect baseline — GPT-5.6 only (2026-07-29)

Until the Architect explicitly changes this baseline, route every new Netrunner through the `codex` backend and the GPT-5.6 family only. Quota checks remain mandatory, but they do not authorize fallback to Gemini, Claude, Kimi, Droid, or another provider. If the required GPT-5.6 bucket is unavailable, pause dispatch and notify the Architect instead of silently switching providers.

Use this task-class mapping:

| Task class | Required route |
|---|---|
| Elementary | `codex + gpt-5.6-luna + high` |
| Simple | `codex + gpt-5.6-terra + high` |
| Medium | `codex + gpt-5.6-sol + high` |
| Complex or super-complex | `codex + gpt-5.6-sol + ultra` |

This rule supersedes all balancing, fallback, capability-rank, and emergency-provider guidance below while it is active.

Flutter/Dart work has no provider-specific exception. In particular, do **not** assume Gemini is better than GPT-5.6 or any other model for Flutter development. Classify Flutter tasks by actual complexity and use the same table above.

## Rule 0.5: balance the windows harmoniously (inactive while Rule 0.25 is active)

Subscriptions should drain evenly, not serially. When several models fit the task class, pick the provider bucket with MORE quota left — considering BOTH the 5h and the 7d window (a bucket at 10% loses to a bucket at ~50% even if the 10% one is technically available). Tune the pair (model, reasoning level) to the budget: within the same model, a lower reasoning tier burns less — when the chosen bucket is getting thin, drop the reasoning level before dropping the model class; when it is comfortable, take the higher tier. Re-check cml between waves, not just once a day: routing should drift toward whichever subscription is currently healthiest.

This rule is superseded by Rule 0.6 below while codex's weekly window is healthy (≥60%) — during that window, concentrate the workhorse load on codex rather than spreading it.

## Rule 0.6: codex weekly-quota floor (historical fallback; inactive while Rule 0.25 is active)

While codex's 7d/weekly window is **≥60% left**, codex is the primary workhorse for *everything up to and including complex tasks* — see the routing table below. Codex currently exposes only a weekly (7d) bucket (no 5h window shows in cml), so this floor is checked against the 7d number only.

When codex's weekly window drops **below 60%**, stop concentrating new work on codex at that level — fall back to Rule 0.5 balancing across the other providers (antigravity/Gemini 3.6 Flash, claude/Sonnet 5, kimi-code-native) for the below-complex and complex tiers.

**Alert obligation**: the first Fixer that observes codex's weekly window has dropped below 60% must notify the Architect once, in its own thread (e.g. `send_operator_telegram_notification`). Later Fixers do not need to repeat the alert once it has already been flagged — just route around codex per Rule 0.5 until it recovers.

## Capability rank reference (2026-07-26)

Use this to judge which models are roughly interchangeable in strength, independent of which one is currently the "first pick":

- **Tier A (top, mostly off-limits)**: Claude Fable 5 (NEVER use — hard banned, see below) ≈ **gpt-5.6-sol**. Unlike Fable, gpt-5.6-sol IS usable — it is now the complex-task workhorse (Rule 0.6), not banned.
- **Tier B**: **gpt-5.6-terra** ≈ claude Opus 5 (low reasoning) ≈ kimi-code-native K3-256k (high reasoning).
- **Tier C (workhorse baseline)**: **gpt-5.6-luna** ≈ Gemini 3.6 Flash ≈ claude Sonnet 5. (Correction 2026-07-26: luna is workhorse-tier, not a "simplest task" cheap pick — it was mis-ranked below in an earlier revision.)

## Routing table (historical fallback, 2026-07-26)

| Task class | First pick | Notes |
|---|---|---|
| All tasks below "complex" (simplest + simple/medium) | **codex + gpt-5.6-terra (high)** | Primary workhorse while codex weekly ≥60% (Rule 0.6). Below 60%: balance across **antigravity + Gemini 3.6 Flash (high)**, **claude + Sonnet 5**, **codex + gpt-5.6-luna (high)**, or **kimi-code-native + Kimi k2.7** per Rule 0.5. |
| Complex tasks | **codex + gpt-5.6-sol (high)** | Primary workhorse while codex weekly ≥60% (Rule 0.6). Below 60%: **kimi-code-native + Kimi K3-256k (low thinking)**, or balance per Rule 0.5. K3 eats limits hard — use deliberately. Kimi-code backend has no reasoning pass-through (`pass_mechanism: none`); "low thinking" is only honored where the backend actually supports it. |
| Hardest tasks | **codex + gpt-5.6-sol (xhigh)** | Strongest codex tier, unchanged by Rule 0.6. |
| Emergencies only | **claude + Opus 5 (low reasoning)** | Only for true emergencies. **Catalog wiring PENDING** (just released, not yet in Fixer MCP model lists). |

## Hard bans

- **Claude Fable** — never use, regardless of Tier A capability parity with gpt-5.6-sol noted above.
- **Antigravity: nothing but Gemini 3.6 Flash.** Gemini 3.1 Pro is pricier AND weaker than 3.6 Flash. Claude/GPT models inside agy have tiny limits — keep them as black-day reserve, never route ordinary work to them.
- Never route work into a bucket that is 0% or burning credits (see Rule 0).

## Provider notes

- **codex**: BACK as of 2026-07-25 (7d window refreshed to 100%; re-enabled in `backend-catalog.json`, `available: true`). Currently the primary workhorse for below-complex AND complex tasks per Rule 0.6, as long as the weekly window stays ≥60% — see the capability-rank correction above (luna is workhorse-tier, terra ≈ Opus5-low/K3-high, sol ≈ Fable but usable). Only a 7d/weekly bucket is tracked for codex right now, no 5h window. Watch it — it burned to 0% once already (2026-07-24).
- **kimi-code-native**: k2.7 for below-complex fallback, K3-256k (low thinking) for complex fallback once codex drops below the 60% floor. K3 eats quota fast — when the kimi bucket 429-storms, move work to agy/Gemini or codex rather than hammering retries (the wave 429 auto-retry exists, but quota is still spent).
- **antigravity**: Gemini 3.6 Flash is the default workhorse-tier fallback. Reasoning maps into the model string (`Gemini 3.6 Flash (High/Medium/Low)`); catalog `reasoning_options`: default/low/medium/high/thinking.
- **claude (Claude Code)**: Sonnet 5 = workhorse-tier fallback; Opus 5 = emergency tier. Watch the 5h window — when it hits 0% the backend burns paid usage credits (real incident 2026-07-24, €73+). Check cml before EVERY claude dispatch.
- **droid**: Factory auth was broken as of 2026-07-24 — verify before routing.

## Pending catalog updates (wave work, tracked in backlog)

- Add **Claude Opus 5** to the claude adapter model options + backend-catalog.json + dashboard model lists.
- ~~Add **Kimi K3-256k**~~ — DONE (wired as `kimi-k3` in kimi-code + kimi-code-native manifests and backend-catalog; used live on wave 210, 2026-07-25).
