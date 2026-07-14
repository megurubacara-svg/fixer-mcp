from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class InstallerContractTests(unittest.TestCase):
    def test_launcher_defaults_to_xdg_state_without_overriding_explicit_db(self) -> None:
        launcher = (ROOT / "scripts" / "fixer.in").read_text(encoding="utf-8")

        self.assertIn('if [[ -z "${FIXER_DB_PATH:-}" ]]; then', launcher)
        self.assertIn('XDG_STATE_HOME:-${HOME}/.local/state', launcher)
        self.assertIn("fixer-client-wires/fixer.db", launcher)
        self.assertIn('mkdir -p "$(dirname "${FIXER_DB_PATH}")"', launcher)

    def test_install_verify_checks_default_state_and_real_launcher_resolution(self) -> None:
        verification = (ROOT / "scripts" / "verify-install.sh").read_text(encoding="utf-8")

        self.assertIn('env -u FIXER_DB_PATH XDG_STATE_HOME="${state_dir}"', verification)
        self.assertIn('FIXER_SMOKE_DB_PATH="${default_db}"', verification)
        self.assertIn('FIXER_SMOKE_ROOT="${smoke_root}"', verification)
        self.assertIn('test -s "${default_db}"', verification)


if __name__ == "__main__":
    unittest.main()
