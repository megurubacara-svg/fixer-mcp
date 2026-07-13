from __future__ import annotations

import json
import os
import shutil
import tempfile
import uuid
from pathlib import Path
from typing import Any, Mapping, Sequence

from .base import (
    BackendAdapter,
    BackendDescriptor,
    FIXER_ROLE_SKILL_NAMES,
    materialize_factory_skills,
    normalize_mcp_server_for_factory,
)
from .catalog import load_backend_entry
from .manifest import ProviderManifest, load_manifest


DROID_CANONICAL_KIMI_K26_MODEL = "kimi-k2.6"
DROID_CANONICAL_KIMI_K26_INTERNAL_MODEL = "custom:Kimi-K2.6-[Kimi]-0"
DROID_CANONICAL_KIMI_K27_MODEL = "kimi-k2.7-code"
DROID_CANONICAL_KIMI_K27_INTERNAL_MODEL = "custom:Kimi-K2.7-Code-[Kimi]-0"
DROID_CANONICAL_GLM_51_MODEL = "glm-5.1"
DROID_CANONICAL_GLM_51_INTERNAL_MODEL = "custom:GLM-5.1-[Z.AI]-0"

DROID_LEGACY_MODEL_ALIASES = {
    "custom:qwen/qwen3.6-plus:free": "OpenRouter Qwen3.6 Plus Free",
    "custom:qwen/qwen3.6-plus-preview:free": "OpenRouter Qwen3.6 Plus Free",
    "custom:qwen3.6-plus-free-[openrouter]-0": "OpenRouter Qwen3.6 Plus Free",
    "custom:qwen3.6-plus-preview-free-[openrouter]-0": "OpenRouter Qwen3.6 Plus Free",
    "openrouter/owl-alpha": "OpenRouter Owl Alpha Free",
    "custom:openrouter/owl-alpha": "OpenRouter Owl Alpha Free",
    "custom:owl-alpha-free-[openrouter]-0": "OpenRouter Owl Alpha Free",
    "kimi": DROID_CANONICAL_KIMI_K26_MODEL,
    "kimi k2.6": DROID_CANONICAL_KIMI_K26_MODEL,
    "kimi-k2.6": DROID_CANONICAL_KIMI_K26_MODEL,
    "kimi k2.6 [kimi]": DROID_CANONICAL_KIMI_K26_MODEL,
    "custom:kimi-k2.6-[kimi]-0": DROID_CANONICAL_KIMI_K26_MODEL,
    "kimi-k2.7-code": DROID_CANONICAL_KIMI_K27_MODEL,
    "kimi-k2.7": DROID_CANONICAL_KIMI_K27_MODEL,
    "kimi k2.7 code": DROID_CANONICAL_KIMI_K27_MODEL,
    "kimi k2.7 code [kimi]": DROID_CANONICAL_KIMI_K27_MODEL,
    "custom:kimi-k2.7-code-[kimi]-0": DROID_CANONICAL_KIMI_K27_MODEL,
    "glm-5.1": DROID_CANONICAL_GLM_51_MODEL,
    "z.ai glm-5.1": DROID_CANONICAL_GLM_51_MODEL,
    "z.ai glm 5.1": DROID_CANONICAL_GLM_51_MODEL,
    "custom:glm-5.1-[z.ai]-0": DROID_CANONICAL_GLM_51_MODEL,
    "custom:glm-5-[z.ai]-0": "Z.AI GLM-5",
    "custom:glm-4.7-[z.ai]-0": "Z.AI GLM-4.7",
    "custom:glm-4.5-air-[z.ai]-0": "Z.AI GLM-4.5 Air",
}

DROID_INTERNAL_MODEL_IDS = {
    DROID_CANONICAL_KIMI_K26_MODEL: DROID_CANONICAL_KIMI_K26_INTERNAL_MODEL,
    DROID_CANONICAL_KIMI_K27_MODEL: DROID_CANONICAL_KIMI_K27_INTERNAL_MODEL,
    DROID_CANONICAL_GLM_51_MODEL: DROID_CANONICAL_GLM_51_INTERNAL_MODEL,
    "Z.AI GLM-5": "custom:GLM-5-[Z.AI]-0",
    "Z.AI GLM-4.7": "custom:GLM-4.7-[Z.AI]-0",
    "Z.AI GLM-4.5 Air": "custom:GLM-4.5-air-[Z.AI]-0",
    "OpenRouter Qwen3.6 Plus Free": "custom:Qwen3.6-Plus-Free-[OpenRouter]-0",
    "OpenRouter Owl Alpha Free": "custom:Owl-Alpha-Free-[OpenRouter]-0",
}


def _manifest_path() -> Path:
    return Path(__file__).resolve().parent / "manifest" / "droid.manifest.json"


def normalize_droid_model_alias(model: str | None) -> str:
    candidate = (model or "").strip()
    if not candidate:
        return candidate
    return DROID_LEGACY_MODEL_ALIASES.get(candidate.casefold(), candidate)


class _DroidScopeManager:
    """Reversibly pre-cleans the global ~/.factory home.

    Droid does not honor a configurable factory-home environment variable, so
    the only way to prevent global skills/MCP from leaking into a scoped run
    is to move aside the relevant global paths before launch and restore them
    afterwards.  The operator's ~/.factory/settings.json is left in place so
    customModels continue to resolve.
    """

    _SCOPED_NAMES = ("skills", "mcp.json")

    def __init__(self, factory_home: Path | None = None) -> None:
        self._factory_home = factory_home or Path.home() / ".factory"
        self._snapshots: list[tuple[Path, Path]] = []

    def prepare(self) -> None:
        """Snapshot and move aside global skills and mcp.json."""
        self._snapshots.clear()
        self._factory_home.mkdir(parents=True, exist_ok=True)
        for name in self._SCOPED_NAMES:
            original = self._factory_home / name
            if original.exists():
                snapshot = self._unique_snapshot(original)
                shutil.move(str(original), str(snapshot))
                self._snapshots.append((snapshot, original))

    def restore(self) -> None:
        """Restore the snapshot, preserving any runtime-created paths as backups."""
        try:
            for snapshot, original in reversed(self._snapshots):
                if not snapshot.exists():
                    continue
                if original.exists():
                    backup = self._unique_runtime_backup(original)
                    shutil.move(str(original), str(backup))
                shutil.move(str(snapshot), str(original))
        finally:
            self._snapshots.clear()

    def _unique_snapshot(self, original: Path) -> Path:
        suffix = f".factory-fixer-snapshot-{uuid.uuid4().hex[:8]}"
        return self._unique_path(original, suffix)

    def _unique_runtime_backup(self, original: Path) -> Path:
        suffix = f".factory-fixer-runtime-{uuid.uuid4().hex[:8]}"
        return self._unique_path(original, suffix)

    def _unique_path(self, original: Path, suffix: str) -> Path:
        candidate = original.parent / f"{original.name}{suffix}"
        counter = 0
        while candidate.exists():
            candidate = original.parent / f"{original.name}{suffix}-{counter}"
            counter += 1
        return candidate


class DroidBackendAdapter(BackendAdapter):
    def __init__(self, factory_home: Path | None = None) -> None:
        entry = load_backend_entry("droid")
        self.descriptor = BackendDescriptor(
            name="droid",
            label=str(entry["label"]),
            description=str(entry["description"]),
            default_model=str(entry["default_model"]),
            default_reasoning=str(entry["default_reasoning"]),
            model_options=tuple(str(value) for value in entry["model_options"]),
            reasoning_options=tuple(str(value) for value in entry["reasoning_options"]),
            fresh_launch_supported=bool(entry.get("fresh_launch_supported", True)),
            resume_supported=bool(entry.get("resume_supported", True)),
        )
        self.command = "droid"
        self.supports_resume = True
        self._manifest = self._load_manifest()
        self._scope_manager = _DroidScopeManager(factory_home=factory_home)

    def _load_manifest(self) -> ProviderManifest | None:
        try:
            return load_manifest(_manifest_path())
        except Exception:
            return None

    def _internal_model(self, model: str | None) -> str:
        public_model = normalize_droid_model_alias(model)
        if self._manifest is not None:
            internal = self._manifest.models.internal_id_map.get(public_model)
            if internal:
                return internal
        return DROID_INTERNAL_MODEL_IDS.get(public_model, public_model)

    def _interactive_approve_flags(self, prefs: Any) -> list[str]:
        if self._manifest is not None and bool(getattr(prefs, "auto_approve", False)):
            return list(self._manifest.permissions.interactive_auto_approve_flags)
        return []

    def _headless_approve_flags(self) -> list[str]:
        if self._manifest is not None:
            return list(self._manifest.permissions.headless_auto_approve_flags)
        return ["--skip-permissions-unsafe"]

    def normalize_model(self, model: str | None) -> str:
        candidate = normalize_droid_model_alias(model)
        return super().normalize_model(candidate)

    def build_llm_args(self, selection: Any) -> list[str]:
        del selection
        return []

    def _resolve_reasoning(self, reasoning: str | None) -> str:
        resolved_reasoning = (reasoning or "").strip() or self.default_reasoning
        if resolved_reasoning in {"", "none"}:
            return "high"
        return resolved_reasoning

    def build_execution_args(self, prefs: Any) -> list[str]:
        # Root `droid` launches do not accept exec-only permission bypass flags.
        del prefs
        return []

    def build_interactive_execution_args(self, prefs: Any) -> list[str]:
        return self._interactive_approve_flags(prefs)

    def _write_launch_settings(
        self,
        selection: Any,
        prefs: Any,
    ) -> Path:
        """Write a temporary settings file for interactive launch."""
        settings: dict[str, object] = {}
        model = self._internal_model(str(getattr(selection, "model", "") or "").strip() or None)
        reasoning = self._resolve_reasoning(str(getattr(selection, "reasoning_effort", "") or ""))
        settings["model"] = model
        settings["reasoningEffort"] = reasoning
        tmp = tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", prefix="droid-wire-", delete=False,
        )
        json.dump(settings, tmp, indent=2)
        tmp.write("\n")
        tmp.close()
        return Path(tmp.name)

    def build_interactive_command_prefix(
        self,
        selection: Any,
        prefs: Any,
    ) -> list[str]:
        """Build the command prefix with --auto and --settings for interactive mode."""
        settings_path = self._write_launch_settings(selection, prefs)
        return [
            self.command,
            *self._interactive_approve_flags(prefs),
            "--settings",
            str(settings_path),
        ]

    def build_mcp_flags(
        self,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
    ) -> list[str]:
        del selected, available
        return []

    def build_prompt_args(self, prompt: str) -> list[str]:
        trimmed = prompt.strip()
        if not trimmed:
            return []
        return [trimmed]

    def prepare_env(self, env: dict[str, str], selection: Any) -> None:
        del selection
        for key in (
            "ALL_PROXY",
            "all_proxy",
            "HTTP_PROXY",
            "http_proxy",
            "HTTPS_PROXY",
            "https_proxy",
            "NO_PROXY",
            "no_proxy",
        ):
            env.pop(key, None)

    def build_resume_command(self, option_args: Sequence[str], external_session_id: str) -> list[str]:
        return [self.command, "--resume", external_session_id.strip(), *list(option_args)]

    def build_headless_command(
        self,
        *,
        model: str,
        reasoning: str,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
        prompt: str,
    ) -> list[str]:
        del selected, available
        command = [self.command, "exec", *self._headless_approve_flags()]
        resolved_model = self._internal_model(self.normalize_model(model))
        resolved_reasoning = self._resolve_reasoning(reasoning)
        command.extend(["-m", resolved_model, "-r", resolved_reasoning])
        command.extend(["--output-format", "json"])
        if prompt.strip():
            command.append(prompt)
        return command

    def prepare_scope(self, cwd: Path | None = None) -> Path | None:
        """Snapshot and move aside global ~/.factory skills and mcp.json.

        Droid does not honor a scoped factory home, so this returns ``None``.
        The launcher must call :meth:`restore_scope` in a ``finally`` block.
        """
        self._scope_manager.prepare()
        return None

    def restore_scope(self) -> None:
        """Restore the global ~/.factory snapshot."""
        self._scope_manager.restore()

    def ensure_runtime_files(
        self,
        cwd: Path,
        selection: Any,
        selected: Mapping[str, Mapping[str, object]],
        available: Mapping[str, Mapping[str, object]],
    ) -> None:
        settings_path = cwd / ".factory" / "settings.json"
        payload: dict[str, object] = {}
        if settings_path.is_file():
            try:
                payload = json.loads(settings_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                payload = {}

        mcp_servers: dict[str, dict[str, object]] = {}
        for name, config in sorted(selected.items()):
            # `selected` may carry launch-time env bindings that are not present
            # in the raw registry entry, such as Fixer MCP role/db bindings.
            source = dict(available.get(name, {}))
            source.update(dict(config))
            bearer_token_env_var = source.get("bearer_token_env_var")
            if isinstance(bearer_token_env_var, str) and bearer_token_env_var.strip():
                token = os.environ.get(bearer_token_env_var.strip(), "").strip()
                if token:
                    headers = dict(source.get("headers", {})) if isinstance(source.get("headers"), dict) else {}
                    headers.setdefault("Authorization", f"Bearer {token}")
                    source["headers"] = headers
            server_payload = normalize_mcp_server_for_factory(source)
            if server_payload.get("type") == "stdio" and not server_payload.get("command"):
                continue
            if server_payload.get("type") == "http" and not server_payload.get("url"):
                continue
            mcp_servers[name] = server_payload

        payload["model"] = self._internal_model(str(getattr(selection, "model", "") or "").strip() or None)
        payload["reasoningEffort"] = self._resolve_reasoning(str(getattr(selection, "reasoning_effort", "") or ""))
        session_defaults = payload.get("sessionDefaultSettings")
        if isinstance(session_defaults, dict):
            session_defaults.pop("model", None)
            session_defaults.pop("reasoningEffort", None)
            payload["sessionDefaultSettings"] = session_defaults
        settings_path.parent.mkdir(parents=True, exist_ok=True)
        settings_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        mcp_path = cwd / ".factory" / "mcp.json"
        mcp_path.write_text(json.dumps({"mcpServers": mcp_servers}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        materialize_factory_skills(cwd, FIXER_ROLE_SKILL_NAMES)
