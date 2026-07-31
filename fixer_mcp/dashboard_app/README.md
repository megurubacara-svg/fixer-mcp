# Fixer MCP Dashboard

Repo-local Flutter desktop client workspace for `Fixer MCP`.

The default app entry point opens the client-facing workspace. A client can:
- sign in with the Serverpod client identity
- review their dashboard and client-owned orders
- create a new product brief as a draft order

The existing operator dashboard remains available as `FixerDashboardApp` for
Fixer MCP project and Netrunner operations.

The operator dashboard reads the control plane directly from `fixer.db` and shows:
- registered projects
- session counts and active sessions
- autonomous-flow detection and detail
- the latest explicit autonomous status if the backend has written one

The terminal action in the dashboard opens the App Server cockpit. It can:
- select a Codex model and reasoning effort
- create and launch a persistent programmatic session with an initial prompt
- switch between existing App Server threads and send follow-up turns
- replay and follow the provider driver's JSON event stream
- manually launch the `run-visual-verifier` skill from a selected thread for
  Codemagic → Appetize → screenshot visual acceptance gating

The cockpit calls the Serverpod App Server endpoint. Set `SERVERPOD_API_URL`
when it is not available at the default `http://127.0.0.1:28080`.

## Run

From this directory:

```bash
flutter run -d macos
```

If the database lives somewhere else, set one of:
- `FIXER_MCP_DB_PATH`
- `FIXER_DB_PATH`

The app falls back to `../../fixer.db` relative to this directory.
