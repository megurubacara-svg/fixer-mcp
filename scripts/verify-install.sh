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
state_dir="${tmp_dir}/state"
smoke_root="${tmp_dir}/smoke-root"
default_db="${state_dir}/fixer-client-wires/fixer.db"
mkdir -p "${smoke_root}"
(
  cd "${tmp_dir}"
  env -u FIXER_DB_PATH XDG_STATE_HOME="${state_dir}" \
    PYTHONDONTWRITEBYTECODE=1 "${FIXER}" --wire-info >/dev/null
  test -d "${state_dir}/fixer-client-wires"
  "${BINARY}" --help >/dev/null
)
env -u FIXER_MCP_LOCKED_ROLE -u FIXER_MCP_DEFAULT_ROLE -u FIXER_MCP_DEFAULT_CWD \
  -u FIXER_MCP_AUTO_AUTH -u FIXER_MCP_TOOL_PROFILE \
  PYTHONDONTWRITEBYTECODE=1 FIXER_SMOKE_BINARY="${BINARY}" \
  FIXER_SMOKE_DB_PATH="${default_db}" FIXER_SMOKE_ROOT="${smoke_root}" \
  bash -c 'cd "$1" && python3 "$2"' _ "${tmp_dir}" "${ROOT_DIR}/tests/fixer_mcp_stdio_smoke.py"
test -s "${default_db}"
echo 'Fixer installation verification passed: persistent launcher state, stdio initialization, and automatic CWD onboarding.'
