from __future__ import annotations

from copy import copy
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

from .base import BackendAdapter, BackendDescriptor, FIXER_ROLE_SKILL_NAMES, materialize_codex_project_skills
from .catalog import load_backend_entry

_FIXER_MCP_SERVER = "fixer_mcp"
_FIXER_GATE_SERVER = "fixer_netrunner_gate"
_FIXER_GATE_TOOLS_TOML = (
    '["launch_netrunner_wave","wait_for_netrunner_wave"]'
)
_FIXER_GATE_PROFILE = "netrunner_gate"
_DEEPSEEK_MODEL_CATALOG = "__FIXER_DEEPSEEK_MODEL_CATALOG__"
_DEEPSEEK_MODEL_IDS = {
    "opencode-go/deepseek-v4-flash": "deepseek-v4-flash",
}


class CodexBackendAdapter(BackendAdapter):
    def __init__(self, inner: Any) -> None:
        entry = load_backend_entry("codex")
        self.descriptor = BackendDescriptor(
            name="codex",
            label=str(entry["label"]),
            description=str(entry["description"]),
            default_model=str(entry["default_model"]),
            default_reasoning=str(entry["default_reasoning"]),
            model_options=tuple(str(value) for value in entry["model_options"]),
            reasoning_options=tuple(str(value) for value in entry["reasoning_options"]),
            fresh_launch_supported=bool(entry.get("fresh_launch_supported", True)),
            resume_supported=bool(entry.get("resume_supported", True)),
        )
        self._inner = inner
        self.command = str(getattr(inner, "command", "codex"))
        self.supports_resume = bool(getattr(inner, "supports_resume", True))
        raw_overrides = entry.get("model_config_overrides", {})
        self._model_config_overrides = (
            dict(raw_overrides) if isinstance(raw_overrides, Mapping) else {}
        )

    def build_llm_args(self, selection: Any) -> list[str]:
        model = str(getattr(selection, "model", "") or "").strip() or self.default_model
        cli_selection = copy(selection)
        cli_selection.model = _DEEPSEEK_MODEL_IDS.get(model, model)
        args = list(self._inner.build_llm_args(cli_selection))
        args.extend(self._build_model_config_args(model))
        return args

    def _build_model_config_args(self, model: str) -> list[str]:
        raw_overrides = self._model_config_overrides.get(model, {})
        if not isinstance(raw_overrides, Mapping):
            raise RuntimeError(f"Codex config overrides for model {model!r} must be an object")

        args: list[str] = []
        for raw_key, raw_value in raw_overrides.items():
            key = str(raw_key).strip()
            value = raw_value
            if value == _DEEPSEEK_MODEL_CATALOG:
                value = str(Path(__file__).resolve().parent / "data" / "codex-deepseek-models.json")
            if isinstance(value, bool):
                encoded = "true" if value else "false"
            elif isinstance(value, (int, float)):
                encoded = str(value)
            elif isinstance(value, str):
                encoded = json.dumps(value)
            else:
                raise RuntimeError(
                    f"Codex config override {key!r} for model {model!r} must be a string, number, or boolean"
                )
            args.extend(["-c", f"{key}={encoded}"])
        return args

    def build_execution_args(self, prefs: Any) -> list[str]:
        return list(self._inner.build_execution_args(prefs))

    def build_mcp_flags(
        self,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
    ) -> list[str]:
        selected_payload = {name: dict(config) for name, config in selected.items()}
        available_payload = {name: dict(config) for name, config in available.items()}
        fixer_spec = selected_payload.get(_FIXER_MCP_SERVER)
        gate_enabled = False
        if fixer_spec is not None:
            raw_env = fixer_spec.get("env")
            fixer_env = dict(raw_env) if isinstance(raw_env, dict) else {}
            gate_enabled = (
                fixer_env.get("FIXER_MCP_LOCKED_ROLE") == "fixer"
                and fixer_env.get("FIXER_MCP_DEFAULT_ROLE") == "fixer"
                and bool(str(fixer_env.get("FIXER_MCP_DEFAULT_CWD", "")).strip())
            )
            if gate_enabled:
                gate_spec = dict(fixer_spec)
                gate_env = dict(fixer_env)
                gate_env["FIXER_MCP_AUTO_AUTH"] = "1"
                gate_env["FIXER_MCP_TOOL_PROFILE"] = _FIXER_GATE_PROFILE
                gate_spec["env"] = gate_env
                gate_spec["_source"] = "project_mcp"
                selected_payload[_FIXER_GATE_SERVER] = gate_spec
                available_payload[_FIXER_GATE_SERVER] = gate_spec
        # The legacy Codex adapter renders details such as env/cwd from the
        # available-server map. Keep selected authoritative for launch-time
        # mutations like FIXER_DB_PATH and FIXER_MCP_LOCKED_ROLE.
        available_payload.update(selected_payload)
        flags = list(self._inner.build_mcp_flags(selected_payload, available_payload))
        if gate_enabled:
            flags.extend(
                [
                    "-c",
                    f"mcp_servers.{_FIXER_GATE_SERVER}.enabled_tools={_FIXER_GATE_TOOLS_TOML}",
                    "-c",
                    f"mcp_servers.{_FIXER_MCP_SERVER}.disabled_tools={_FIXER_GATE_TOOLS_TOML}",
                    "-c",
                    f'features.code_mode.direct_only_tool_namespaces=["mcp__{_FIXER_GATE_SERVER}"]',
                ]
            )
        return flags

    def build_prompt_args(self, prompt: str) -> list[str]:
        return list(self._inner.build_prompt_args(prompt))

    def prepare_env(self, env: dict[str, str], selection: Any) -> None:
        self._inner.prepare_env(env, selection)

    def build_resume_command(self, option_args: Sequence[str], external_session_id: str) -> list[str]:
        # `codex resume` appears to keep sticky session-side state, which can
        # ignore fresh CLI flags such as `--disable apps`. Use `fork` so the
        # new interactive session inherits the previous context but honors the
        # current launcher configuration.
        return [self.command, "fork", *list(option_args), external_session_id.strip()]

    def build_headless_command(
        self,
        *,
        model: str,
        reasoning: str,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
        prompt: str,
    ) -> list[str]:
        resolved_model = model.strip() or self.default_model
        resolved_reasoning = reasoning.strip() or self.default_reasoning
        command = [self.command, "--model", _DEEPSEEK_MODEL_IDS.get(resolved_model, resolved_model)]
        if resolved_reasoning:
            command.extend(["-c", f'model_reasoning_effort="{resolved_reasoning}"'])
        command.extend(self._build_model_config_args(resolved_model))
        if resolved_model == "gpt-5.5":
            command.extend([
                "-c",
                "model_context_window=800000",
                "-c",
                "model_auto_compact_token_limit=736000",
            ])
        command.append("--dangerously-bypass-approvals-and-sandbox")
        command.extend(self.build_mcp_flags(selected, available))
        command.extend(["exec", "--skip-git-repo-check"])
        if prompt.strip():
            command.append(prompt)
        return command

    def ensure_runtime_files(
        self,
        cwd: Path,
        selection: Any,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
    ) -> None:
        del selection, selected, available
        materialize_codex_project_skills(cwd, FIXER_ROLE_SKILL_NAMES)
