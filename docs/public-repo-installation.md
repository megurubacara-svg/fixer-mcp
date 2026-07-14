# Public Repository Installation

`make install` runs `scripts/install.sh`. By default it builds the Go MCP server into `~/.local/lib/fixer-mcp/fixer_mcp` and installs a stable `~/.local/bin/fixer` wrapper bound to the current checkout. Set `FIXER_INSTALL_PREFIX` to choose another prefix.

The command is idempotent and only replaces files it manages. It preserves SQLite databases, project files, configuration, and authentication state, and never edits shell rc files.

The installed wrapper defaults `FIXER_DB_PATH` to `XDG_STATE_HOME/fixer-client-wires/fixer.db`, or `~/.local/state/fixer-client-wires/fixer.db` when `XDG_STATE_HOME` is not set. An explicit `FIXER_DB_PATH` always takes precedence. The state directory is created on first launch and existing databases are never replaced by installation.

`make install-verify` adds a non-interactive verification pass. It checks wrapper/runtime resolution, initializes a fresh SQLite database through MCP stdio, and exercises automatic onboarding for a previously unknown project CWD. `make docker-smoke` is the deterministic clean-container gate. The authenticated `make docker-bootstrap-e2e` gate remains optional and manual.
