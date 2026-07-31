from __future__ import annotations

from client_wires.backends.claude_adapter import ClaudeCodeBackendAdapter


def test_claude_headless_command_forwards_explicit_opus_5_and_xhigh() -> None:
    command = ClaudeCodeBackendAdapter().build_headless_command(
        model="claude-opus-5",
        reasoning="xhigh",
        selected={},
        available={},
        prompt="implement the task",
    )

    assert command == [
        "claude",
        "--model",
        "claude-opus-5",
        "--effort",
        "xhigh",
        "--dangerously-skip-permissions",
        "implement the task",
    ]


def test_claude_keeps_existing_model_aliases_and_default_selection() -> None:
    adapter = ClaudeCodeBackendAdapter()

    assert adapter.default_model == "sonnet"
    assert adapter.default_reasoning == "medium"
    assert adapter.model_options == ("sonnet", "opus", "claude-opus-5", "haiku")
    assert adapter.normalize_model("opus") == "opus"
