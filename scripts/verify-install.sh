#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${FIXER_INSTALL_PREFIX:-${HOME}/.local}"
FIXER="${PREFIX}/bin/fixer"
BINARY="${PREFIX}/lib/fixer-mcp/fixer_mcp"

test -x "${FIXER}"
test -x "${BINARY}"
"${FIXER}" --wire-info >/dev/null
"${BINARY}" --help >/dev/null

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
env -u FIXER_MCP_LOCKED_ROLE -u FIXER_MCP_DEFAULT_ROLE -u FIXER_MCP_DEFAULT_CWD \
  -u FIXER_MCP_AUTO_AUTH -u FIXER_MCP_TOOL_PROFILE \
  FIXER_SMOKE_BINARY="${BINARY}" FIXER_SMOKE_TMP="${tmp_dir}" python3 "${ROOT_DIR}/tests/fixer_mcp_stdio_smoke.py"
FIXER_DB_PATH="${tmp_dir}/onboarding.db" python3 -m unittest \
  client_wires.tests.test_fixer_wire_db.ResolveProjectIdTests
echo 'Fixer installation verification passed: launcher, stdio initialization, and automatic CWD onboarding.'
