from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Mapping, Sequence

from .base import BackendAdapter, BackendDescriptor
from .catalog import load_backend_entry
from .manifest import load_manifest


# Public alias surfaced in the catalog / launcher.
KIMI_CODE_PUBLIC_MODEL = "kimi-k2.7-code"
# Internal model id understood by kimi-cli (-m). The managed "K2.7 Code" model.
KIMI_CODE_INTERNAL_MODEL = "kimi-code/kimi-for-coding"

# Public alias for the managed "K3" model.
KIMI_CODE_K3_MODEL = "kimi-k3"
# Internal model id understood by kimi-cli (-m) for K3.
KIMI_CODE_K3_INTERNAL_MODEL = "kimi-code/k3"

# Scoped runtime MCP config path, relative to the project cwd.  Using a scoped
# file avoids clobbering the operator's interactive .mcp.json in the project
# root and lets us pass the config explicitly via --mcp-config-file.
_KIMI_RUNTIME_MCP_CONFIG = Path(".kimi") / "fixer-runtime" / "mcp.json"

_KIMI_MODEL_ALIASES = {
    "kimi-k2.7-code": KIMI_CODE_PUBLIC_MODEL,
    "kimi-k2.7": KIMI_CODE_PUBLIC_MODEL,
    "kimi k2.7 code": KIMI_CODE_PUBLIC_MODEL,
    "k2.7 code": KIMI_CODE_PUBLIC_MODEL,
    "kimi-code": KIMI_CODE_PUBLIC_MODEL,
    "kimi-for-coding": KIMI_CODE_PUBLIC_MODEL,
    "kimi-code/kimi-for-coding": KIMI_CODE_PUBLIC_MODEL,
    "kimi-k3": KIMI_CODE_K3_MODEL,
    "kimi k3": KIMI_CODE_K3_MODEL,
    "k3": KIMI_CODE_K3_MODEL,
    "kimi-code/k3": KIMI_CODE_K3_MODEL,
}

_KIMI_INTERNAL_MODEL_IDS = {
    KIMI_CODE_PUBLIC_MODEL: KIMI_CODE_INTERNAL_MODEL,
    KIMI_CODE_K3_MODEL: KIMI_CODE_K3_INTERNAL_MODEL,
}


def _manifest_path() -> Path:
    return Path(__file__).resolve().parent / "manifest" / "kimi-code.manifest.json"


def normalize_mcp_server_for_kimi(source: Mapping[str, object]) -> dict[str, object]:
    """Translate a launcher MCP server spec into kimi-cli .mcp.json schema."""
    if "url" in source or "serverUrl" in source:
        payload: dict[str, object] = {
            "transport": "http",
            "url": source.get("url", source.get("serverUrl", "")),
            "disabled": bool(source.get("disabled", False)),
        }
        headers = source.get("headers")
        if isinstance(headers, dict) and headers:
            payload["headers"] = {str(k): str(v) for k, v in headers.items()}
        return payload

    payload = {
        "transport": "stdio",
        "command": str(source.get("command", "")).strip(),
        "disabled": bool(source.get("disabled", False)),
    }
    args = source.get("args")
    if isinstance(args, (list, tuple)):
        payload["args"] = [str(item) for item in args]
    else:
        payload["args"] = []
    env = source.get("env")
    if isinstance(env, dict) and env:
        payload["env"] = {str(key): str(value) for key, value in env.items()}
    cwd = source.get("cwd")
    if isinstance(cwd, str) and cwd.strip():
        payload["cwd"] = cwd.strip()
    return payload


class KimiCodeBackendAdapter(BackendAdapter):
    def __init__(self) -> None:
        entry = load_backend_entry("kimi-code")
        self.descriptor = BackendDescriptor(
            name="kimi-code",
            label=str(entry["label"]),
            description=str(entry["description"]),
            default_model=str(entry["default_model"]),
            default_reasoning=str(entry["default_reasoning"]),
            model_options=tuple(str(value) for value in entry["model_options"]),
            reasoning_options=tuple(str(value) for value in entry["reasoning_options"]),
            fresh_launch_supported=bool(entry.get("fresh_launch_supported", True)),
            resume_supported=bool(entry.get("resume_supported", True)),
        )
        self.command = "kimi-cli"
        self.supports_resume = self.descriptor.resume_supported
        self._manifest = self._load_manifest()
        self._runtime_cwd: Path | None = None

    def _load_manifest(self) -> Any:
        """Load the kimi-code manifest; fall back to defaults if absent."""
        try:
            return load_manifest(_manifest_path())
        except Exception:
            return None

    def _mcp_config_path(self, cwd: Path | None = None) -> Path:
        """Absolute path to the scoped MCP config file."""
        base = cwd or self._runtime_cwd or Path.cwd()
        return (base / _KIMI_RUNTIME_MCP_CONFIG).resolve()

    @property
    def _mcp_config_flag(self) -> str:
        """Flag name used to pass the scoped MCP config file."""
        if self._manifest is not None:
            flags = list(self._manifest.mcp.scope_flags)
            if flags:
                return flags[0]
        return "--mcp-config-file"

    def _interactive_approve_flags(self) -> list[str]:
        if self._manifest is not None:
            flags = list(self._manifest.permissions.interactive_auto_approve_flags)
            if flags:
                return flags
        return ["--yolo"]

    def _headless_approve_flags(self) -> list[str]:
        if self._manifest is not None:
            flags = list(self._manifest.permissions.headless_auto_approve_flags)
            if flags:
                return flags
        return ["--print"]

    def normalize_model(self, model: str | None) -> str:
        candidate = (model or "").strip().lower()
        if not candidate:
            return KIMI_CODE_PUBLIC_MODEL
        if candidate in _KIMI_MODEL_ALIASES:
            canonical = _KIMI_MODEL_ALIASES[candidate]
            if self._manifest is not None and canonical not in self._manifest.models.options:
                raise RuntimeError(
                    f"Kimi alias {candidate!r} resolved to {canonical!r} which is not "
                    f"declared in the manifest options: {self._manifest.models.options}"
                )
            return canonical
        # Fall back to base validation against catalog model_options.
        return super().normalize_model(model)

    def normalize_reasoning(self, reasoning: str | None) -> str:
        # kimi-cli has no reasoning-effort levels (thinking is on by default);
        # accept whatever the launcher passes and ignore it downstream.
        return "default"

    def _internal_model(self, model: str | None) -> str:
        public = self.normalize_model(model)
        if self._manifest is not None:
            internal = self._manifest.models.internal_id_map.get(public)
            if internal:
                return internal
        return _KIMI_INTERNAL_MODEL_IDS.get(public, KIMI_CODE_INTERNAL_MODEL)

    def build_llm_args(self, selection: Any) -> list[str]:
        model = str(getattr(selection, "model", "") or "").strip() or self.default_model
        return ["-m", self._internal_model(model)]

    def build_execution_args(self, prefs: Any) -> list[str]:
        del prefs
        return list(self._interactive_approve_flags())

    def build_mcp_flags(
        self,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
    ) -> list[str]:
        del selected, available
        # Use a relative path: the launcher always runs kimi-cli with cwd set to
        # the project root, so the scoped config resolves correctly without
        # needing cwd passed into this method.
        return [self._mcp_config_flag, str(_KIMI_RUNTIME_MCP_CONFIG)]

    def build_prompt_args(self, prompt: str) -> list[str]:
        # `-p`/`--prompt` is a one-shot flag on kimi-cli: passing it makes the
        # CLI run that single turn and exit, it does NOT stay in the
        # interactive TUI afterward (confirmed the hard way — a prior fix
        # here wrongly assumed `-p` auto-submits into an ongoing interactive
        # session and broke real interactive kimi-code launches). Kimi shell
        # mode has no way to auto-submit an initial prompt into a session
        # that stays open, so the launcher surfaces the bootstrap prompt to
        # the operator instead. The headless path builds its own `-p` flag
        # directly in build_headless_command, where one-shot-and-exit is the
        # correct/intended behavior.
        return []

    def build_resume_command(self, option_args: Sequence[str], external_session_id: str) -> list[str]:
        return [self.command, "-r", external_session_id.strip(), *list(option_args)]

    def prepare_env(self, env: dict[str, str], selection: Any) -> None:
        del env, selection
        return

    def build_headless_command(
        self,
        *,
        model: str,
        reasoning: str,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
        prompt: str,
    ) -> list[str]:
        del reasoning, selected, available
        # Non-interactive: --print auto-dismisses AskUserQuestion and
        # auto-approves tool calls; --yolo approves all actions.
        cmd = [
            self.command,
            *self._headless_approve_flags(),
            *self._interactive_approve_flags(),
            "-m",
            self._internal_model(model),
            self._mcp_config_flag,
            str(self._mcp_config_path()),
        ]
        if prompt.strip():
            cmd.extend(["-p", prompt.strip()])
        return cmd

    def ensure_runtime_files(
        self,
        cwd: Path,
        selection: Any,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
    ) -> None:
        del selection
        self._runtime_cwd = cwd.resolve()
        mcp_servers: dict[str, dict[str, object]] = {}
        for name, config in sorted(selected.items()):
            source = dict(available.get(name, {}))
            source.update(dict(config))
            server_payload = normalize_mcp_server_for_kimi(source)
            if server_payload.get("transport") == "http" and not str(server_payload.get("url", "")).strip():
                continue
            if server_payload.get("transport") == "stdio" and not str(server_payload.get("command", "")).strip():
                continue
            mcp_servers[name] = server_payload

        mcp_path = self._mcp_config_path(cwd)
        mcp_path.parent.mkdir(parents=True, exist_ok=True)
        mcp_path.write_text(
            json.dumps({"mcpServers": mcp_servers}, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
