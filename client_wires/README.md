# Client Wires

Canonical client launch wires for Fixer MCP live in this directory.

These wires are the bridge between durable orchestration state in `fixer_mcp` and actual worker execution in Codex-backed sessions. They are what turns stored sessions, attached docs, MCP selections, and review rules into real Fixer, Netrunner, and Overseer runs.

## Common Path

For a new operator, the usual first commands are:

```bash
python3 client_wires/fixer_wire.py --wire-info
python3 client_wires/fixer_wire.py --role fixer
```

No sibling `mcp_servers/codex_pro_app` checkout is required; the launcher uses
the repo-vendored `client_wires.codex_compat` package.

## Why These Wires Matter

This directory is more than a launch convenience layer. It is where the repo converts the control-plane model into disciplined execution:
- role-aware startup for Fixer, Netrunner, and Overseer
- session-aware resume flows
- deterministic MCP assignment injection
- explicit autonomous worker dispatch and wake-up behavior
- backend-aware launch metadata for `codex` and `droid`

## Flow Map

- `explicit Fixer MCP flow`: this is the canonical explicit path for MCP-sensitive or durable Fixer-managed Netrunners. For live Fixer threads, prefer `fixer_mcp.launch_and_wait_netrunner`; the durable/background variant is still implemented by `client_wires/fixer_autonomous.py`.
- `manual separate-terminal`: use `$run-manual-netrunner` when the Architect wants to launch or resume the Netrunner personally in another terminal.
- `review and closure`: use `$review-netrunner-session` when a completed session needs Fixer review, acceptance, rejection, or lifecycle closure.

## Netrunner Worker Model Policy

Choose the Netrunner worker configuration by task complexity:

- simplest tasks: `codex` + `gpt-5.6-luna` + `high`
- medium-complexity tasks: `codex` + `gpt-5.6-terra` + `high`
- complex tasks: `codex` + `gpt-5.6-sol` + `medium`
- hardest tasks: `codex` + `gpt-5.6-sol` + `xhigh`

## Fixer Wire

- Entrypoint: `client_wires/fixer_wire.py`
- Purpose: launch role flows for `fixer`, `netrunner`, and `overseer`.
- Runtime source: uses the vendored `client_wires.codex_compat` launcher helpers.
- Repo-local MCP additions for this project should live in the root `mcp_config.json` so the base launcher path discovers them automatically; `client_wires/fixer_wire.py` also overlays optional root `webMCP.toml` entries after that base discovery pass for wire-specific additions.
- Manual Netrunner launch now injects `$run-manual-netrunner` with a preselected session and MCP set, then stops after the initialization checklist unless the Architect explicitly pre-approved immediate execution.
- Netrunner UX:
  - Uses keyboard-friendly interactive selectors (arrow keys + enter).
  - Enforces two dialogs in sequence (session picker, then MCP checklist).
  - Session picker shows only `in_progress` by default; `+` toggles archived statuses.
  - MCP checklist hides `fixer_mcp` (forced always-on) and persists manual overrides back to `fixer.db`.
- MVP scaffold UX:
  - `fixer --scaffold-mvp <project_slug>` creates a fresh Serverpod + Flutter + `llm_pipeline` starter from any cwd.
  - Optional `--scaffold-target-dir <parent_dir>` chooses where the new project root is created.
  - The scaffold runs before Codex bootstrap or project registration checks, so it also works for brand-new projects.
  - Plain `fixer` now exposes `MVP Scaffold` in the first menu, then asks for project name, target directory, and `dry-run` vs real create mode.
- Autonomous Netrunner dispatch:
  - `python3 client_wires/fixer_autopilot.py --cwd <project_root> --max-parallel <n>` polls Fixer-backed pending sessions and launches Netrunners automatically.
  - It reuses existing session MCP assignments and attached-doc context instead of inventing its own dispatch state.
  - Retry behavior is bounded and process-driven, borrowing the core idea from Symphony's unattended dispatch loop.
- Serial autonomous Fixer loop:
  - `python3 client_wires/fixer_autonomous.py register-fixer --cwd <project_root>` stores the active Fixer resume thread for later autonomous wake-ups.
  - `register-fixer` resolves the Fixer Codex session in this order: explicit `--fixer-session-id`, then `CODEX_THREAD_ID` / `CODEX_SESSION_ID` from the current shell, then history-based auto-detection.
  - `fixer_mcp.wait_for_netrunner_session` polls Fixer MCP session/proposal state and returns structured review-ready completion metadata.
  - `fixer_mcp.launch_and_wait_netrunner` composes both so an Architect-visible Fixer thread can stay in-place through MCP-sensitive worker completion.
  - Codex Fixer launches mount a second `fixer_netrunner_gate` MCP namespace whose server-level surface contains only `launch_and_wait_netrunner`, `launch_netrunner_wave`, and `wait_for_netrunner_wave`. The primary `fixer_mcp` copy hides those duplicates, while `features.code_mode.direct_only_tool_namespaces` keeps blocking serial and wave orchestration as native calls for GPT-5.6 Code Mode models without exposing the full Fixer tool catalog directly.
  - The gate process auto-authenticates only when it is simultaneously locked to `fixer`, bound to a registered project CWD, explicitly opted into auto-auth, and started with the `netrunner_gate` tool profile. Ordinary Fixer MCP processes retain normal `assume_role` authentication.
  - The repo-managed wire now forces the attached `fixer_mcp` server timeout floor to `21600s`, matching the long explicit wait window and avoiding the old accidental `600s` client cutoff on `launch_and_wait_netrunner`.
  - Claude Code launch materialization writes `.mcp.json` per-server `timeout` in milliseconds, using `per_tool_timeout_ms` first and otherwise converting the wire's second-based timeout fields.
  - The old parallel sidecar stubs are not canonical launcher surfaces. Future parallel Netrunner orchestration should use durable Fixer-owned messages/run-state and write-scope guardrails rather than reviving retired tool names.
  - Fresh role launches set `FIXER_MCP_LOCKED_ROLE` on the forced `fixer_mcp` server: `overseer` for Overseer, `fixer` for Fixer, and `netrunner` for Netrunner.
  - `python3 client_wires/fixer_autonomous.py launch-netrunner --cwd <project_root> --session-id <local_session_id>` launches one headless-durable Netrunner using the project's assigned MCP/doc context and the implementation-session rule that code changes ship with relevant automated test additions/updates/removals.
  - Routine operator Telegram updates now go through `fixer_mcp.send_operator_telegram_notification` with project-bound context; `telegram_notify` is no longer part of the normal Fixer/Netrunner MCP surface for this workflow.
  - Older broken tests in scope are part of the worker obligation when they block the change; Ghost Run must not degrade into code-only delivery.
  - When a final tester worker reports bugs, the autonomous review handoff is expected to spawn repair Netrunner sessions from those findings before Ghost Run concludes.
  - `fixer_mcp.wake_fixer_autonomous` is the project-scoped wake-up tool for autonomous Netrunners; it resumes the registered Fixer thread headlessly into `$review-netrunner-session`, then the Fixer continues the serial autonomous loop.
- Fixer UX:
  - Shows a role-specific pre-screen: `Start new Fixer` or `Resume existing Fixer`.
  - Resume picker lists prior Fixer Codex sessions with `started` and `updated` timestamps.
  - No MCP selection UI is shown for Fixer; `fixer_mcp` remains forced-attached.
  - Fixer launch uses `--sandbox danger-full-access` to preserve codex-pro style cross-cwd filesystem behavior.
- Fresh Fixer/Overseer launches ensure the current cwd is registered in the launcher DB before role startup.
  - Unknown cwd onboarding happens through the launcher path, so normal role startup does not require a manual Overseer `register_project` call first.
- Overseer UX:
  - Overseer launch also defaults to `--sandbox danger-full-access` unless an explicit sandbox flag is passed through.
- Session resume:
  - Tracks `codex` session IDs in `session_codex_link`.
  - Selecting an archived session (`review`/`completed`) auto-resumes `codex` by stored session ID.
- Session lifecycle closure: Fixer/Overseer now finalize reviewed work via `set_session_status` (typically `review` -> `completed`), with optional rollback to `pending`/`in_progress` when rework is needed.
- Netrunner supports non-interactive verification flags:
  - `--netrunner-session-id <id>`
  - `--netrunner-mcp <name[,name...]>` (repeatable)
  - `--dry-run` (prints resolved launch command without running Codex)

## Compatibility Bridge

Legacy alias target remains supported:

- `python3 ../mcp_servers/fixer.py`

That legacy script delegates into this repo-local entrypoint, so execution passes through `client_wires/fixer_wire.py`.

## Canonical Docs

- Runtime modes: `docs/reference/30_ops/runtime_modes_native_vs_headless.md` in the public export
- Native prompt helpers: `docs/reference/30_ops/native_netrunner_prompt_helpers.md` in the public export
- Native Telegram operator notifications: `docs/reference/30_ops/native_telegram_operator_notifications.md` in the public export
- Project handoff storage and tools: `docs/reference/20_architecture/project_handoff_storage.md` in the public export

## Quick Checks

- `python3 client_wires/fixer_wire.py --wire-info`
- `python3 ../mcp_servers/fixer.py --wire-info`
- `python3 client_wires/fixer_wire.py --role fixer --help`
- `python3 client_wires/fixer_wire.py --scaffold-mvp sample_app --dry-run`
- `python3 client_wires/fixer_autopilot.py --cwd /path/to/project --once --dry-run`
- `python3 client_wires/fixer_autonomous.py register-fixer --cwd /path/to/project --fixer-session-id <codex_session_id>`
- `python3 client_wires/fixer_autonomous.py launch-netrunner --cwd /path/to/project --session-id 3`
