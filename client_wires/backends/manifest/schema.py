"""Declarative provider manifest schema and loader for the Fixer MCP adapter abstraction.

A provider manifest captures the six capability entities that vary across CLI
backends (models, reasoning, skills, MCP servers, permissions, operator
questions) plus launch templates and tool registration policy. The schema is
intended to be consumed by both Python launcher code and future Go tooling, so
it serializes to plain JSON and avoids Python-only constructs.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any


class ManifestValidationError(Exception):
    """Raised when a manifest fails schema or contract validation."""

    def __init__(self, message: str, path: str = "") -> None:
        self.path = path
        super().__init__(f"{path}: {message}" if path else message)


AUTH_MECHANISMS = ("subscription", "api_key", "byok")
REASONING_PASS_MECHANISMS = ("flag", "config-key", "none")
SKILL_SCOPE_STRATEGIES = (
    "disable-global-flag",
    "per-skill-disable",
    "location-flag",
    "pre-clean",
    "none",
)
MCP_CONFIG_FORMATS = (
    "codex-c-overrides",
    "mcp-config-file",
    "strict-mcp-config",
    "factory-mcp.json",
    "serverUrl",
    "junie-location",
    "kimi-code-mcp-json",
)
MCP_SCOPE_STRATEGIES = (
    "enumerate-disable",
    "strict-config-flag",
    "location-flag",
    "mcp-config-file",
    "pre-clean",
    "none",
    "project-config-file",
)
OPERATOR_QUESTION_MECHANISMS = (
    "AskUserQuestion",
    "droid.ask_user-jsonrpc",
    "kimi-code-question",
    "none",
)
TOOL_REGISTRATION_MODES = ("native",)


def _require_str(data: dict[str, Any], key: str, path: str) -> str:
    value = data.get(key)
    if not isinstance(value, str):
        raise ManifestValidationError(f"{key!r} must be a string", path)
    return value


def _require_bool(data: dict[str, Any], key: str, path: str) -> bool:
    value = data.get(key)
    if not isinstance(value, bool):
        raise ManifestValidationError(f"{key!r} must be a boolean", path)
    return value


def _require_str_list(
    data: dict[str, Any], key: str, path: str, *, nonempty: bool = False
) -> list[str]:
    value = data.get(key)
    if not isinstance(value, list):
        raise ManifestValidationError(f"{key!r} must be a list", path)
    items = [str(item) for item in value]
    if nonempty and not items:
        raise ManifestValidationError(f"{key!r} must be non-empty", path)
    return items


def _require_str_in(
    data: dict[str, Any], key: str, allowed: tuple[str, ...], path: str
) -> str:
    value = _require_str(data, key, path)
    if value not in allowed:
        raise ManifestValidationError(
            f"{key!r}={value!r} not in {allowed}", path
        )
    return value


def _require_str_map(
    data: dict[str, Any], key: str, path: str
) -> dict[str, str]:
    value = data.get(key)
    if not isinstance(value, dict):
        raise ManifestValidationError(f"{key!r} must be an object", path)
    result: dict[str, str] = {}
    for sub_key, sub_value in value.items():
        if not isinstance(sub_value, str):
            raise ManifestValidationError(
                f"{key!r}.{sub_key} must be a string", path
            )
        result[str(sub_key)] = sub_value
    return result


@dataclass(frozen=True)
class ManifestModels:
    """Model catalog and resolution policy for a provider."""

    options: list[str]
    default: str
    internal_id_map: dict[str, str]
    byok: bool
    auth: str
    api_key_env: str | None = None

    def validate(self, path: str = "models") -> None:
        if not self.options:
            raise ManifestValidationError("options must be non-empty", path)
        if self.default not in self.options:
            raise ManifestValidationError(
                f"default={self.default!r} not in options", path
            )
        if self.auth not in AUTH_MECHANISMS:
            raise ManifestValidationError(
                f"auth={self.auth!r} not in {AUTH_MECHANISMS}", path
            )
        for option in self.options:
            internal_id = self.internal_id_map.get(option, option)
            if not internal_id or not isinstance(internal_id, str):
                raise ManifestValidationError(
                    f"option {option!r} has no internal id mapping", path
                )
        if self.auth == "api_key" and not self.api_key_env:
            raise ManifestValidationError(
                "api_key_env is required when auth='api_key'", path
            )

    @classmethod
    def from_dict(cls, data: dict[str, Any], path: str = "models") -> ManifestModels:
        return cls(
            options=_require_str_list(data, "options", path, nonempty=True),
            default=_require_str(data, "default", path),
            internal_id_map=_require_str_map(data, "internal_id_map", path),
            byok=_require_bool(data, "byok", path),
            auth=_require_str_in(data, "auth", AUTH_MECHANISMS, path),
            api_key_env=data.get("api_key_env") or None,
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        if payload["api_key_env"] is None:
            payload.pop("api_key_env")
        return payload


@dataclass(frozen=True)
class ManifestReasoning:
    """Reasoning-effort selection and how it is passed to the provider CLI."""

    options: list[str]
    default: str
    pass_mechanism: str
    flag_or_key: str | None = None

    def validate(self, path: str = "reasoning") -> None:
        if not self.options:
            raise ManifestValidationError("options must be non-empty", path)
        if self.default not in self.options:
            raise ManifestValidationError(
                f"default={self.default!r} not in options", path
            )
        if self.pass_mechanism not in REASONING_PASS_MECHANISMS:
            raise ManifestValidationError(
                f"pass_mechanism={self.pass_mechanism!r} not in {REASONING_PASS_MECHANISMS}",
                path,
            )
        if self.pass_mechanism != "none" and not self.flag_or_key:
            raise ManifestValidationError(
                "flag_or_key is required when pass_mechanism is not 'none'", path
            )

    @classmethod
    def from_dict(
        cls, data: dict[str, Any], path: str = "reasoning"
    ) -> ManifestReasoning:
        return cls(
            options=_require_str_list(data, "options", path, nonempty=True),
            default=_require_str(data, "default", path),
            pass_mechanism=_require_str_in(
                data, "pass_mechanism", REASONING_PASS_MECHANISMS, path
            ),
            flag_or_key=data.get("flag_or_key") or None,
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        if payload["flag_or_key"] is None:
            payload.pop("flag_or_key")
        return payload


@dataclass(frozen=True)
class ManifestSkills:
    """Skill injection directory and scope-isolation strategy."""

    inject_dir: str
    scope_strategy: str
    scope_flags: list[str] = field(default_factory=list)

    def validate(self, path: str = "skills") -> None:
        if not self.inject_dir:
            raise ManifestValidationError("inject_dir must be non-empty", path)
        if self.scope_strategy not in SKILL_SCOPE_STRATEGIES:
            raise ManifestValidationError(
                f"scope_strategy={self.scope_strategy!r} not in {SKILL_SCOPE_STRATEGIES}",
                path,
            )

    @classmethod
    def from_dict(cls, data: dict[str, Any], path: str = "skills") -> ManifestSkills:
        return cls(
            inject_dir=_require_str(data, "inject_dir", path),
            scope_strategy=_require_str_in(
                data, "scope_strategy", SKILL_SCOPE_STRATEGIES, path
            ),
            scope_flags=_require_str_list(data, "scope_flags", path),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class ManifestMcp:
    """MCP server config format and scope-isolation strategy."""

    config_format: str
    scope_strategy: str
    scope_flags: list[str] = field(default_factory=list)

    def validate(self, path: str = "mcp") -> None:
        if self.config_format not in MCP_CONFIG_FORMATS:
            raise ManifestValidationError(
                f"config_format={self.config_format!r} not in {MCP_CONFIG_FORMATS}",
                path,
            )
        if self.scope_strategy not in MCP_SCOPE_STRATEGIES:
            raise ManifestValidationError(
                f"scope_strategy={self.scope_strategy!r} not in {MCP_SCOPE_STRATEGIES}",
                path,
            )

    @classmethod
    def from_dict(cls, data: dict[str, Any], path: str = "mcp") -> ManifestMcp:
        return cls(
            config_format=_require_str_in(
                data, "config_format", MCP_CONFIG_FORMATS, path
            ),
            scope_strategy=_require_str_in(
                data, "scope_strategy", MCP_SCOPE_STRATEGIES, path
            ),
            scope_flags=_require_str_list(data, "scope_flags", path),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class ManifestPermissions:
    """Auto-approval flags for interactive and headless sessions."""

    interactive_auto_approve_flags: list[str] = field(default_factory=list)
    headless_auto_approve_flags: list[str] = field(default_factory=list)
    interactive_auto_approve_justification: str | None = None
    headless_auto_approve_justification: str | None = None

    def validate(self, path: str = "permissions") -> None:
        self._check_approval_set(
            "interactive",
            self.interactive_auto_approve_flags,
            self.interactive_auto_approve_justification,
            path,
        )
        self._check_approval_set(
            "headless",
            self.headless_auto_approve_flags,
            self.headless_auto_approve_justification,
            path,
        )

    def _check_approval_set(
        self,
        label: str,
        flags: list[str],
        justification: str | None,
        path: str,
    ) -> None:
        if not flags:
            if not justification:
                raise ManifestValidationError(
                    f"{label}_auto_approve_flags is empty and no justification provided",
                    path,
                )
            return
        for item in flags:
            if not item or not isinstance(item, str):
                raise ManifestValidationError(
                    f"{label}_auto_approve_flags must contain non-empty strings", path
                )

    @classmethod
    def from_dict(
        cls, data: dict[str, Any], path: str = "permissions"
    ) -> ManifestPermissions:
        return cls(
            interactive_auto_approve_flags=_require_str_list(
                data, "interactive_auto_approve_flags", path
            ),
            headless_auto_approve_flags=_require_str_list(
                data, "headless_auto_approve_flags", path
            ),
            interactive_auto_approve_justification=data.get(
                "interactive_auto_approve_justification"
            )
            or None,
            headless_auto_approve_justification=data.get(
                "headless_auto_approve_justification"
            )
            or None,
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        for key in (
            "interactive_auto_approve_justification",
            "headless_auto_approve_justification",
        ):
            if payload.get(key) is None:
                payload.pop(key, None)
        return payload


@dataclass(frozen=True)
class ManifestOperatorQuestions:
    """Provider support for in-session AskUser / operator questions."""

    supported: bool
    mechanism: str | None = None
    headless_auto_approve_dismisses: bool = False

    def validate(self, path: str = "operator_questions") -> None:
        if self.supported:
            if not self.mechanism:
                raise ManifestValidationError(
                    "mechanism is required when supported=true", path
                )
            if self.mechanism not in OPERATOR_QUESTION_MECHANISMS:
                raise ManifestValidationError(
                    f"mechanism={self.mechanism!r} not in {OPERATOR_QUESTION_MECHANISMS}",
                    path,
                )
        else:
            if self.mechanism:
                raise ManifestValidationError(
                    "mechanism must be omitted when supported=false", path
                )

    @classmethod
    def from_dict(
        cls, data: dict[str, Any], path: str = "operator_questions"
    ) -> ManifestOperatorQuestions:
        return cls(
            supported=_require_bool(data, "supported", path),
            mechanism=data.get("mechanism") or None,
            headless_auto_approve_dismisses=bool(
                data.get("headless_auto_approve_dismisses", False)
            ),
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        if payload["mechanism"] is None:
            payload.pop("mechanism")
        return payload


@dataclass(frozen=True)
class ManifestLaunch:
    """Command templates for interactive, headless, and resume launches."""

    interactive_cmd_template: str
    headless_cmd_template: str
    resume_interactive: str
    resume_headless: str

    def validate(self, path: str = "launch") -> None:
        for key in (
            "interactive_cmd_template",
            "headless_cmd_template",
            "resume_interactive",
            "resume_headless",
        ):
            value = getattr(self, key)
            if not value or not isinstance(value, str):
                raise ManifestValidationError(
                    f"{key} must be a non-empty string", path
                )

    @classmethod
    def from_dict(cls, data: dict[str, Any], path: str = "launch") -> ManifestLaunch:
        return cls(
            interactive_cmd_template=_require_str(
                data, "interactive_cmd_template", path
            ),
            headless_cmd_template=_require_str(
                data, "headless_cmd_template", path
            ),
            resume_interactive=_require_str(data, "resume_interactive", path),
            resume_headless=_require_str(data, "resume_headless", path),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class ProviderManifest:
    """Top-level per-provider manifest."""

    provider: str
    label: str
    description: str
    models: ManifestModels
    reasoning: ManifestReasoning
    skills: ManifestSkills
    mcp: ManifestMcp
    tool_registration: str
    permissions: ManifestPermissions
    operator_questions: ManifestOperatorQuestions
    launch: ManifestLaunch

    def validate(self, path: str = "") -> None:
        for key in ("provider", "label", "description"):
            if not getattr(self, key) or not isinstance(getattr(self, key), str):
                raise ManifestValidationError(f"{key} must be a non-empty string", path)
        if self.tool_registration not in TOOL_REGISTRATION_MODES:
            raise ManifestValidationError(
                f"tool_registration={self.tool_registration!r} not in {TOOL_REGISTRATION_MODES}",
                path,
            )
        self.models.validate(f"{path}.models" if path else "models")
        self.reasoning.validate(f"{path}.reasoning" if path else "reasoning")
        self.skills.validate(f"{path}.skills" if path else "skills")
        self.mcp.validate(f"{path}.mcp" if path else "mcp")
        self.permissions.validate(f"{path}.permissions" if path else "permissions")
        self.operator_questions.validate(
            f"{path}.operator_questions" if path else "operator_questions"
        )
        self.launch.validate(f"{path}.launch" if path else "launch")

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> ProviderManifest:
        if not isinstance(data, dict):
            raise ManifestValidationError("manifest must be an object")
        required_sections = (
            "models",
            "reasoning",
            "skills",
            "mcp",
            "permissions",
            "operator_questions",
            "launch",
        )
        for section in required_sections:
            if section not in data:
                raise ManifestValidationError(f"missing required section {section!r}")
        manifest = cls(
            provider=_require_str(data, "provider", ""),
            label=_require_str(data, "label", ""),
            description=_require_str(data, "description", ""),
            models=ManifestModels.from_dict(data["models"]),
            reasoning=ManifestReasoning.from_dict(data["reasoning"]),
            skills=ManifestSkills.from_dict(data["skills"]),
            mcp=ManifestMcp.from_dict(data["mcp"]),
            tool_registration=_require_str_in(
                data, "tool_registration", TOOL_REGISTRATION_MODES, ""
            ),
            permissions=ManifestPermissions.from_dict(data["permissions"]),
            operator_questions=ManifestOperatorQuestions.from_dict(
                data["operator_questions"]
            ),
            launch=ManifestLaunch.from_dict(data["launch"]),
        )
        manifest.validate()
        return manifest

    def to_dict(self) -> dict[str, Any]:
        return {
            "provider": self.provider,
            "label": self.label,
            "description": self.description,
            "models": self.models.to_dict(),
            "reasoning": self.reasoning.to_dict(),
            "skills": self.skills.to_dict(),
            "mcp": self.mcp.to_dict(),
            "tool_registration": self.tool_registration,
            "permissions": self.permissions.to_dict(),
            "operator_questions": self.operator_questions.to_dict(),
            "launch": self.launch.to_dict(),
        }


def load_manifest(path_or_dict: Path | str | dict[str, Any]) -> ProviderManifest:
    """Load and validate a provider manifest from a path or dict."""
    if isinstance(path_or_dict, (str, Path)):
        raw = Path(path_or_dict).read_text(encoding="utf-8")
        import json

        data = json.loads(raw)
    else:
        data = path_or_dict
    if not isinstance(data, dict):
        raise ManifestValidationError("manifest must be an object")
    return ProviderManifest.from_dict(data)
