# Agent Installation Contract

Use this document as an execution checklist when installing Fixer MCP for another operator. Do not copy credentials into the repository or logs.

## Prerequisites

- Ubuntu: install Git, Bash, Python 3.12+, Go 1.25.4+, Node.js/npm, and Docker Engine for container smoke tests.
- macOS: install Xcode command-line tools, Python 3.12+, Go 1.25.4+, Node.js/npm, and Docker Desktop for container smoke tests.
- Install the Codex CLI and authenticate interactively with `codex login` before authenticated worker launches. Deterministic verification does not require Codex authentication.

## Clone, install, verify

```bash
git clone git@github.com:kamenetskiy-to/fixer-mcp.git fixer-mcp
# HTTPS alternative: git clone https://github.com/kamenetskiy-to/fixer-mcp.git fixer-mcp
cd fixer-mcp
make install-verify
```

The installer defaults to `~/.local`, builds the repo-native Go server, and creates `~/.local/bin/fixer`. The wrapper is bound to this checkout's absolute path, so keep the checkout there; after moving it, rerun `make install-verify`. Installation is safe to rerun: it replaces only its managed binary and wrapper and does not remove databases, configuration, credentials, or project files. It never edits shell startup files. If needed, add `~/.local/bin` to `PATH` yourself. A custom location is supported with `FIXER_INSTALL_PREFIX=/path make install-verify`.

## First project

From the new project's root, run:

```bash
fixer --role fixer
```

Normal launcher startup registers an unknown project CWD automatically. Do not perform manual Overseer registration for ordinary first use. For Codex-backed work, complete `codex login` first.

## Update or reinstall

```bash
git pull --ff-only
make install-verify
```

## Troubleshooting

- `fixer: command not found`: add the install prefix's `bin` directory to `PATH`, or invoke it by absolute path.
- Go/Python version errors: install the prerequisite versions, then rerun.
- Docker smoke failures: ensure the daemon is running; `make install-verify` itself is non-interactive and does not require Docker.
- Authenticated launch failures: run `codex login`; never place auth data in this checkout.
- Override state location with `FIXER_DB_PATH`; existing state is not overwritten by installation.
- Without an override, state lives at `XDG_STATE_HOME/fixer-client-wires/fixer.db`, or `~/.local/state/fixer-client-wires/fixer.db` by default. The launcher creates that parent directory on first use.

## Success criteria

Installation is complete only when `make install-verify` passes, `fixer --wire-info` resolves the checkout launcher and installed repo-native MCP binary, the fresh stdio smoke initializes SQLite, and the automatic new-CWD onboarding test passes. Run `make docker-smoke` as the deterministic clean-container release gate. `make docker-bootstrap-e2e` is optional, authenticated, network-dependent, and must be run manually by an operator with local Codex auth.
