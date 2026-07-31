# App Server v1 Research: Architecture & Multi-Provider Integration

## 1. Analysis of Codex App Server Analog
The current `launcher_poc` (and by extension `client_wires/codex_compat`) uses CLI wrappers for managing interactions with various AI providers. Looking closely at `client_wires/codex_compat/llm.py` and `client_wires/backends/antigravity_adapter.py`:
- It abstracts the underlying CLI with adapters (e.g. `CodexCLIAdapter`, `AntigravityBackendAdapter`).
- It passes specific flags to force headless, programmatic interaction (e.g. `codex --ask-for-approval never`, `agy --dangerously-skip-permissions --print-timeout 120m --print "..."`).
- It manages MCP servers via dynamic TOML configs (e.g., passing `-c "mcp_servers.playwright.enabled=true"`).
- Playwright runtime is deeply integrated (`playwright_chrome_cdp.py`) to allow AI to drive CDP sessions (headed/headless) via the `playwright` MCP.

**What we steal outright:**
- The Adapter pattern for backends (`CLIAdapter` base class).
- Dynamic MCP configuration injection.
- The `playwright` CDP orchestration for UI testing/verification.

## 2. Multi-Provider Integration Map
Each backend must support programmatic streaming instead of embedding a PTY/tmux session. This eliminates PTY formatting issues, mini-Warp prompts, and gives structured control:
- **codex (GPT-5.5/5.6)**: Supports `--json` or output redirection. Native support for MCP.
- **droid (GLM-5.1 / Kimi-k2.6)**: JSON-RPC interface (`--input/--output-format stream-jsonrpc`). We must strictly fence its write scope as discovered in session 258.
- **claude (Sonnet/Opus 4.6)**: Output format stream via `--output-format stream-json`.
- **antigravity**: Native programmatic execution using `--dangerously-skip-permissions --print-timeout Xm --print "prompt"`. Output is streamed to stdout.
- **junie**: Needs an adapter implementation that maps to its specific headless execution flags.
- **kimi-code (Kimi-k2.7-code)**: Needs to be wired in the `droid_adapter.py` mapping to `custom:Kimi-K2.7-Code-[Kimi]-0` (requires Architect verification).

**Recommendation:** Programmatic-session (JSON/stream over stdout/stderr) is strictly superior to PTY/tmux for App Server v1. It avoids screen scraping, allows exact token tracking, and provides clean state recovery. Tmux should only be used as a daemonizer, not for interaction.

## 3. App Server v1 Architecture Decomposition
To evolve `launcher_poc` into a fully usable cockpit (App Server v1), the architecture must be decomposed into the following components:

1. **Session Manager (Go/Serverpod)**
   - Responsible for tracking active Fixer threads.
   - Manages state machine: Pending -> Running -> Review -> Completed.
   - Handles resume/switch operations.
2. **Session Driver (Python/Go)**
   - The execution engine (replaces `fixer_autonomous.py`).
   - Uses the Adapter pattern to launch the specific backend (codex, antigravity, etc.) using its programmatic stream interface.
   - Parses the JSON stream and converts it into unified events.
3. **Message Broker**
   - Routes stream events from the Session Driver to the Flutter Cockpit via Serverpod WebSockets.
4. **Flutter Cockpit (UI)**
   - The visual dashboard for the Architect.
   - Contains: Provider/Model selection, Reasoning effort slider, Write scope definition, live event stream view (not a terminal, but a structured chat/log view), and Review approval buttons.
5. **Persistence (`fixer.db`)**
   - Native integration with `fixer_mcp` tables (`session`, `worker_process`, `project_doc`).
   - Saves intermediate checkpoints so sessions can be paused, serialized, and resumed across node restarts.
6. **Relation to Fixer MCP**
   - App Server v1 acts as the primary visual client for `fixer_mcp`.
   - `fixer_mcp` remains the control plane and database owner, while App Server v1 is the orchestrator and UI.

## 4. Final Recommendation & Estimate
We proceed with **Programmatic-Sessions** (no PTY).
The build effort for App Server v1 (Serverpod backend + Flutter frontend + Driver integration) is estimated at **3-4 Netrunner waves (approx 8-12 hours)**.

**Next step:** Launch wave to implement the Serverpod App Server backend endpoints based on this architecture.
