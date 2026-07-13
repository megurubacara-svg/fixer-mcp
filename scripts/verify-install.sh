#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${FIXER_INSTALL_PREFIX:-${HOME}/.local}"
FIXER="${PREFIX}/bin/fixer"
BINARY="${PREFIX}/lib/fixer-mcp/fixer_mcp"

test -x "${FIXER}"
test -x "${BINARY}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
(
  cd "${tmp_dir}"
  PYTHONDONTWRITEBYTECODE=1 "${FIXER}" --wire-info >/dev/null
  "${BINARY}" --help >/dev/null
)
env -u FIXER_MCP_LOCKED_ROLE -u FIXER_MCP_DEFAULT_ROLE -u FIXER_MCP_DEFAULT_CWD \
  -u FIXER_MCP_AUTO_AUTH -u FIXER_MCP_TOOL_PROFILE \
  PYTHONDONTWRITEBYTECODE=1 FIXER_SMOKE_BINARY="${BINARY}" FIXER_SMOKE_TMP="${tmp_dir}" \
  bash -c 'cd "$1" && python3 "$2"' _ "${tmp_dir}" "${ROOT_DIR}/tests/fixer_mcp_stdio_smoke.py"
(
  cd "${tmp_dir}"
  PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="${ROOT_DIR}" FIXER_DB_PATH="${tmp_dir}/onboarding.db" \
    python3 -m unittest client_wires.tests.test_fixer_wire_db.ResolveProjectIdTests
)
echo 'Fixer installation verification passed: launcher, stdio initialization, and automatic CWD onboarding.'
