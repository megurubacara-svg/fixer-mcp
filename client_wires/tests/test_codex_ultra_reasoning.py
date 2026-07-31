from __future__ import annotations

import unittest

from client_wires.backends.codex_adapter import CodexBackendAdapter
from client_wires.codex_compat.llm import CODEX_CLI_ADAPTER


class CodexUltraReasoningTests(unittest.TestCase):
    def test_headless_codex_launch_preserves_ultra_for_gpt_56_sol(self) -> None:
        adapter = CodexBackendAdapter(CODEX_CLI_ADAPTER)

        self.assertEqual(adapter.normalize_model("gpt-5.6-sol"), "gpt-5.6-sol")
        self.assertEqual(adapter.normalize_reasoning("ultra"), "ultra")
        self.assertEqual(
            adapter.build_headless_command(
                model="gpt-5.6-sol",
                reasoning="ultra",
                selected={},
                available={},
                prompt="verify ultra reasoning",
            ),
            [
                "codex",
                "--model",
                "gpt-5.6-sol",
                "-c",
                'model_reasoning_effort="ultra"',
                "--dangerously-bypass-approvals-and-sandbox",
                "exec",
                "--skip-git-repo-check",
                "verify ultra reasoning",
            ],
        )


if __name__ == "__main__":
    unittest.main()
