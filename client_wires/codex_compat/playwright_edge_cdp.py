#!/usr/bin/env python3
"""Attach/launch Microsoft Edge and expose one isolated agent-owned Playwright MCP context.

Edge twin of playwright_chrome_cdp.py: same CDP bridge, but detects the Edge
executable and Edge processes, and uses a dedicated non-default user-data-dir
(Chromium 136+ ignores --remote-debugging-port on the default data directory).
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import shutil
import shlex
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request


DEFAULT_EDGE_CANDIDATES = (
    Path("/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"),
)


@dataclass(frozen=True)
class EdgeProfileProcess:
    pid: int
    command: str
    remote_debugging_port: int | None


def _find_edge() -> str:
    env_path = os.environ.get("CODEX_PRO_PLAYWRIGHT_EDGE_EXECUTABLE")
    if env_path and env_path.strip():
        return str(Path(env_path).expanduser())

    for candidate in DEFAULT_EDGE_CANDIDATES:
        if candidate.is_file():
            return str(candidate)

    for name in ("microsoft-edge", "msedge", "edge"):
        found = shutil.which(name)
        if found:
            return found

    raise RuntimeError("Microsoft Edge executable not found")


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _cdp_endpoint_is_reachable(endpoint: str, timeout_sec: float = 0.8) -> bool:
    deadline = time.monotonic() + timeout_sec
    url = endpoint.rstrip("/") + "/json/version"
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=0.5) as response:
                if response.status == 200:
                    return True
        except (OSError, urllib.error.URLError):
            pass
        time.sleep(0.1)
    return False


def _wait_for_cdp(endpoint: str, timeout_sec: float = 20.0) -> None:
    deadline = time.monotonic() + timeout_sec
    url = endpoint.rstrip("/") + "/json/version"
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=0.5) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.URLError) as exc:
            last_error = exc
        time.sleep(0.1)
    raise RuntimeError(f"Timed out waiting for Edge CDP endpoint {endpoint}: {last_error}")


def _terminate(process: subprocess.Popen[object]) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def _remote_debugging_port_from_command(command: str) -> int | None:
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()

    for index, part in enumerate(parts):
        if part.startswith("--remote-debugging-port="):
            value = part.split("=", 1)[1]
        elif part == "--remote-debugging-port" and index + 1 < len(parts):
            value = parts[index + 1]
        else:
            continue
        try:
            return int(value)
        except ValueError:
            return None
    return None


def _looks_like_edge_process(command: str) -> bool:
    lowered = command.lower()
    return (
        "microsoft edge" in lowered
        or "/msedge" in lowered
        or lowered.endswith("/msedge")
        or lowered.startswith("msedge ")
    )


def _edge_processes_for_profile(profile_dir: Path) -> list[EdgeProfileProcess]:
    marker = str(profile_dir)
    result = subprocess.run(["ps", "axo", "pid=,command="], text=True, capture_output=True)
    processes: list[EdgeProfileProcess] = []
    for line in result.stdout.splitlines():
        if marker not in line:
            continue
        parts = line.strip().split(maxsplit=1)
        if not parts:
            continue
        try:
            pid = int(parts[0])
        except ValueError:
            continue
        if pid != os.getpid():
            command = parts[1] if len(parts) > 1 else ""
            if not _looks_like_edge_process(command):
                continue
            processes.append(
                EdgeProfileProcess(
                    pid=pid,
                    command=command,
                    remote_debugging_port=_remote_debugging_port_from_command(command),
                )
            )
    return processes


def _edge_pids_for_profile(profile_dir: Path) -> list[int]:
    return [process.pid for process in _edge_processes_for_profile(profile_dir)]


def _profile_in_use_without_cdp_message(profile_dir: Path, processes: list[EdgeProfileProcess]) -> str:
    joined = ", ".join(str(process.pid) for process in processes)
    ports = sorted({process.remote_debugging_port for process in processes if process.remote_debugging_port})
    if ports:
        port_note = (
            " Found remote-debugging port(s) "
            f"{', '.join(str(port) for port in ports)}, but none answered on 127.0.0.1."
        )
    else:
        port_note = " No --remote-debugging-port flag was found on the matching Edge processes."
    return (
        "Edge profile is already in use by process(es) "
        f"{joined}: {profile_dir}, but no reachable Chrome DevTools Protocol endpoint "
        f"could be found.{port_note} Close that Edge instance, restart it with "
        "--remote-debugging-port, or set "
        "CODEX_PRO_PLAYWRIGHT_EDGE_PROFILE to a different profile directory."
    )


def _existing_cdp_endpoint_for_profile(profile_dir: Path) -> str | None:
    processes = _edge_processes_for_profile(profile_dir)
    if not processes:
        return None

    for process in processes:
        if process.remote_debugging_port is None:
            continue
        endpoint = f"http://127.0.0.1:{process.remote_debugging_port}"
        if _cdp_endpoint_is_reachable(endpoint):
            return endpoint

    raise RuntimeError(_profile_in_use_without_cdp_message(profile_dir, processes))


def _ensure_profile_not_in_use(profile_dir: Path) -> None:
    processes = _edge_processes_for_profile(profile_dir)
    if processes:
        joined = ", ".join(str(process.pid) for process in processes)
        raise RuntimeError(
            "Edge profile is already in use by process(es) "
            f"{joined}: {profile_dir}. Close that Edge instance or set "
            "CODEX_PRO_PLAYWRIGHT_EDGE_PROFILE "
            "to a different profile directory."
        )


def _terminate_edge_for_profile(edge: subprocess.Popen[object], profile_dir: Path) -> None:
    _terminate(edge)
    pids = _edge_pids_for_profile(profile_dir)
    for pid in pids:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    if pids:
        time.sleep(1)
    for pid in _edge_pids_for_profile(profile_dir):
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def _playwright_mcp_node_modules() -> Path:
    npm = shutil.which("npm")
    if not npm:
        raise RuntimeError("npm executable not found")
    result = subprocess.run(
        [
            npm,
            "exec",
            "--yes",
            "--package=@playwright/mcp@latest",
            "--package=@modelcontextprotocol/sdk@latest",
            "--",
            "sh",
            "-c",
            'realpath "$(command -v playwright-mcp)"',
        ],
        text=True,
        capture_output=True,
        timeout=90,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError("Unable to resolve the installed Playwright MCP package")
    cli_path = Path(result.stdout.strip()).resolve()
    node_modules = cli_path.parents[2]
    if not (node_modules / "@playwright" / "mcp").is_dir():
        raise RuntimeError("Resolved Playwright MCP package layout is invalid")
    return node_modules


def _owned_context_mcp_command(cdp_endpoint: str, viewport_size: str | None) -> tuple[list[str], dict[str, str]]:
    node = shutil.which("node")
    if not node:
        raise RuntimeError("node executable not found")
    helper = Path(__file__).with_name("playwright_owned_context_mcp.cjs")
    if not helper.is_file():
        raise RuntimeError("Playwright owned-context MCP helper is missing")
    node_modules = _playwright_mcp_node_modules()
    command = [node, str(helper), "--cdp-endpoint", cdp_endpoint]
    if viewport_size:
        command.extend(["--viewport-size", viewport_size])
    env = os.environ.copy()
    existing_node_path = env.get("NODE_PATH")
    env["NODE_PATH"] = str(node_modules) + (os.pathsep + existing_node_path if existing_node_path else "")
    return command, env


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Start normal Edge and bridge Playwright MCP over CDP.")
    parser.add_argument("--user-data-dir", required=True)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--viewport-size")
    parser.add_argument("--port", type=int, default=0)
    args = parser.parse_args(argv)

    profile_dir = Path(args.user_data_dir).expanduser()
    profile_dir.mkdir(parents=True, exist_ok=True)

    cdp_endpoint = _existing_cdp_endpoint_for_profile(profile_dir)
    edge: subprocess.Popen[object] | None = None
    if cdp_endpoint is None:
        port = args.port or _free_port()
        cdp_endpoint = f"http://127.0.0.1:{port}"
        edge_cmd = [
            _find_edge(),
            f"--remote-debugging-port={port}",
            f"--user-data-dir={profile_dir}",
            "--no-first-run",
            "--no-default-browser-check",
            "about:blank",
        ]
        if args.headless:
            edge_cmd.insert(1, "--headless=new")
        edge = subprocess.Popen(edge_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    mcp: subprocess.Popen[object] | None = None

    def stop_children(_signum: int, _frame: object) -> None:
        if mcp is not None:
            _terminate(mcp)
        if edge is not None:
            _terminate_edge_for_profile(edge, profile_dir)

    signal.signal(signal.SIGINT, stop_children)
    signal.signal(signal.SIGTERM, stop_children)

    try:
        if edge is not None:
            _wait_for_cdp(cdp_endpoint)
        mcp_cmd, mcp_env = _owned_context_mcp_command(cdp_endpoint, args.viewport_size)
        mcp = subprocess.Popen(mcp_cmd, env=mcp_env)
        return mcp.wait()
    finally:
        if edge is not None and os.environ.get("CODEX_PRO_PLAYWRIGHT_KEEP_EDGE") != "1":
            _terminate_edge_for_profile(edge, profile_dir)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as exc:
        print(f"playwright edge cdp wrapper failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
