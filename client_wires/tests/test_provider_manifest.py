from __future__ import annotations

from pathlib import Path

from client_wires.backends.manifest import load_manifest


ROOT = Path(__file__).resolve().parents[2]
CLAUDE_MANIFEST = ROOT / "client_wires" / "backends" / "manifest" / "claude.manifest.json"


def test_claude_manifest_exposes_opus_5_and_supported_effort_levels() -> None:
    manifest = load_manifest(CLAUDE_MANIFEST)

    assert manifest.models.default == "sonnet"
    assert manifest.models.options == ["sonnet", "opus", "claude-opus-5", "haiku"]
    assert manifest.models.internal_id_map["claude-opus-5"] == "claude-opus-5"
    assert manifest.reasoning.options == ["low", "medium", "high", "xhigh", "max"]
    assert manifest.reasoning.flag_or_key == "--effort"
