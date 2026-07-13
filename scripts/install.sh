#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${FIXER_INSTALL_PREFIX:-${HOME}/.local}"
BIN_DIR="${PREFIX}/bin"
LIB_DIR="${PREFIX}/lib/fixer-mcp"
VERIFY=0

usage() {
  printf 'Usage: %s [--prefix PATH] [--verify]\n' "$0"
}

while (($#)); do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix requires a path}"; BIN_DIR="${PREFIX}/bin"; LIB_DIR="${PREFIX}/lib/fixer-mcp"; shift 2 ;;
    --verify) VERIFY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

command -v go >/dev/null || { echo 'Go is required.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Python 3 is required.' >&2; exit 1; }
mkdir -p "${BIN_DIR}" "${LIB_DIR}"

tmp_binary="${TMPDIR:-/tmp}/fixer-mcp-install.$$"
trap 'rm -f "${tmp_binary}"' EXIT
(cd "${ROOT_DIR}/fixer_mcp" && go build -o "${tmp_binary}" .)
install -m 0755 "${tmp_binary}" "${LIB_DIR}/fixer_mcp"

launcher="${BIN_DIR}/fixer"
tmp_launcher="${launcher}.tmp.$$"
sed -e "s|@REPO_ROOT@|${ROOT_DIR//|/\\|}|g" -e "s|@FIXER_BINARY@|${LIB_DIR//|/\\|}/fixer_mcp|g" \
  "${ROOT_DIR}/scripts/fixer.in" >"${tmp_launcher}"
chmod 0755 "${tmp_launcher}"
mv "${tmp_launcher}" "${launcher}"

echo "Installed fixer launcher: ${launcher}"
echo "Installed MCP binary: ${LIB_DIR}/fixer_mcp"
case ":${PATH}:" in *":${BIN_DIR}:"*) ;; *) echo "Add ${BIN_DIR} to PATH (shell files were not modified)." ;; esac

if ((VERIFY)); then
  FIXER_INSTALL_PREFIX="${PREFIX}" "${ROOT_DIR}/scripts/verify-install.sh"
fi
