from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path


def _catalog_path() -> Path:
    return Path(__file__).resolve().parent / "data" / "backend-catalog.json"


@lru_cache(maxsize=1)
def load_backend_catalog() -> dict[str, dict[str, object]]:
    payload = json.loads(_catalog_path().read_text(encoding="utf-8"))
    raw_backends = payload.get("backends", {})
    if not isinstance(raw_backends, dict):
        raise RuntimeError(f"{_catalog_path()} does not contain an object-valued backends map")

    catalog: dict[str, dict[str, object]] = {}
    for name, entry in raw_backends.items():
        if not isinstance(entry, dict):
            raise RuntimeError(f"{_catalog_path()} entry for {name!r} must be an object")
        catalog[str(name)] = entry
    return catalog


def load_backend_entry(name: str) -> dict[str, object]:
    catalog = load_backend_catalog()
    try:
        return catalog[name]
    except KeyError as exc:
        supported = ", ".join(sorted(catalog))
        raise RuntimeError(f"Backend catalog missing entry for {name!r}. Available: {supported}") from exc


def is_backend_available(name: str) -> bool:
    """Whether the Architect currently has a working subscription/auth for this backend.

    Defaults to True for entries with no explicit "available" flag, so older
    catalog entries stay usable until someone opts them out.
    """
    return bool(load_backend_entry(name).get("available", True))


def set_backend_availability(name: str, available: bool) -> None:
    """Flip a backend's availability flag and persist it to backend-catalog.json.

    This is the quick knob for "the Architect's subscription for X just
    changed" — no code change or rebuild required, only the alias/Python
    layer's in-process cache is cleared. The Go core (fixer_mcp) re-reads the
    same file on every launch, so it also picks this up immediately.
    """
    path = _catalog_path()
    payload = json.loads(path.read_text(encoding="utf-8"))
    backends = payload.get("backends", {})
    if name not in backends:
        supported = ", ".join(sorted(backends))
        raise RuntimeError(f"Backend catalog missing entry for {name!r}. Available: {supported}")
    backends[name]["available"] = bool(available)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    load_backend_catalog.cache_clear()
