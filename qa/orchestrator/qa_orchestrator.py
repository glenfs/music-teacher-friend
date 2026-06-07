"""
Clefira QA Orchestrator
=======================

Launches a Clefira build, talks to its debug HTTP API (scripts/qa/debug_server.gd),
runs the data-driven test cases in test_cases.yaml, and writes structured JSON
results + an LLM-ready report under ./results/.

Designed for CI/CD: idempotent, exits non-zero on any failure, captures logs
and screenshots on the way for the LLM analysis step to consume.

USAGE
-----
    # Local run with auto-launched Clefira on default port 8765.
    python qa_orchestrator.py --build ./build/Clefira.exe

    # Reuse an already-running Clefira (you started it manually with
    # --debug-server). Skip the launch step.
    python qa_orchestrator.py --no-launch --port 8765

    # Custom test fixture file.
    python qa_orchestrator.py --build ./build/Clefira.exe --cases ./my_cases.yaml

    # Filter cases by tag.
    python qa_orchestrator.py --build ./build/Clefira.exe --tag smoke
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any

import requests
import yaml

LOG = logging.getLogger("qa_orchestrator")
DEFAULT_PORT = 8765
DEFAULT_TIMEOUT_SEC = 8.0
LAUNCH_READY_TIMEOUT_SEC = 30.0
SCREENSHOT_DIR_NAME = "screenshots"
RESULTS_DIR_NAME = "results"


# ---------------------------------------------------------------------------
# Result model
# ---------------------------------------------------------------------------

@dataclass
class StepResult:
    name: str
    action: str
    ok: bool
    duration_ms: int
    observed: Any = None
    expected: Any = None
    message: str = ""


@dataclass
class CaseResult:
    name: str
    tags: list[str]
    started_unix: float
    duration_sec: float
    ok: bool
    steps: list[StepResult] = field(default_factory=list)
    screenshots: list[str] = field(default_factory=list)
    failure_reason: str | None = None


# ---------------------------------------------------------------------------
# Debug API client (thin wrapper over /endpoints)
# ---------------------------------------------------------------------------

class DebugClient:
    """Synchronous client for the Godot debug_server endpoints."""

    def __init__(self, port: int = DEFAULT_PORT, host: str = "127.0.0.1"):
        self._base = f"http://{host}:{port}"
        self._timeout = DEFAULT_TIMEOUT_SEC
        self._session = requests.Session()

    def _get(self, path: str, params: dict | None = None) -> dict:
        r = self._session.get(self._base + path, params=params or {}, timeout=self._timeout)
        r.raise_for_status()
        return r.json()

    def _post(self, path: str, body: dict | None = None) -> dict:
        r = self._session.post(self._base + path, json=body or {}, timeout=self._timeout)
        r.raise_for_status()
        return r.json()

    # ---------- typed wrappers ----------

    def health(self) -> dict:
        return self._get("/health")

    def state(self) -> dict:
        return self._get("/state")

    def logs(self, since: int = 0) -> dict:
        return self._get("/logs", params={"since": since})

    def switch_mode(self, name: str) -> dict:
        return self._post("/mode", {"name": name})

    def drill_start(self, drill_type: str, **kwargs) -> dict:
        return self._post("/drill/start", {"type": drill_type, **kwargs})

    def drill_play(self) -> dict:
        return self._post("/drill/play")

    def drill_stop(self) -> dict:
        return self._post("/drill/stop")

    def midi_inject(self, pitch: int, velocity: int = 96, hold_ms: int = 0) -> dict:
        return self._post("/midi/inject", {"pitch": pitch, "velocity": velocity, "hold_ms": hold_ms})

    def audio_probe(self) -> dict:
        return self._post("/audio/probe")

    def assert_member(self, member: str, op: str, value: Any) -> dict:
        return self._post("/assert", {"member": member, "op": op, "value": value})

    def screenshot(self, tag: str) -> dict:
        return self._post("/screenshot", {"tag": tag})

    def quit(self) -> dict:
        return self._post("/quit")


# ---------------------------------------------------------------------------
# Process launcher
# ---------------------------------------------------------------------------

class ClefiraLauncher:
    """Spawns Clefira.exe with --debug-server and tracks the process."""

    def __init__(self, exe_path: Path, port: int, extra_args: list[str] | None = None,
                 windowed: bool = False):
        if not exe_path.is_file():
            raise FileNotFoundError(f"Clefira build not found: {exe_path}")
        self._exe_path = exe_path
        self._port = port
        self._extra_args = extra_args or []
        self._windowed = windowed
        self._proc: subprocess.Popen | None = None

    def launch(self) -> None:
        args: list[str] = [str(self._exe_path)]
        if not self._windowed:
            args.append("--headless")
        # `--` separates engine flags from user-supplied --debug-server.
        args.extend(["--", "--debug-server", str(self._port)])
        args.extend(self._extra_args)
        LOG.info("launching: %s", " ".join(args))
        # CREATE_NEW_PROCESS_GROUP on Windows so we can SIGINT cleanly.
        creationflags = 0
        if sys.platform.startswith("win"):
            creationflags = subprocess.CREATE_NEW_PROCESS_GROUP  # type: ignore[attr-defined]
        self._proc = subprocess.Popen(args, creationflags=creationflags)

    def shutdown(self, grace_sec: float = 4.0) -> None:
        if self._proc is None:
            return
        if self._proc.poll() is not None:
            return
        try:
            if sys.platform.startswith("win"):
                self._proc.send_signal(signal.CTRL_BREAK_EVENT)  # type: ignore[attr-defined]
            else:
                self._proc.send_signal(signal.SIGTERM)
            self._proc.wait(timeout=grace_sec)
        except subprocess.TimeoutExpired:
            LOG.warning("Clefira didn't exit within %.1fs; killing", grace_sec)
            self._proc.kill()
        except Exception as e:  # pragma: no cover — defensive cleanup
            LOG.error("error during shutdown: %s", e)
            try:
                self._proc.kill()
            except Exception:
                pass


# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

def wait_until_ready(client: DebugClient, timeout: float = LAUNCH_READY_TIMEOUT_SEC) -> bool:
    """Polls /health until the server responds or we time out."""
    deadline = time.time() + timeout
    last_err: str = ""
    while time.time() < deadline:
        try:
            h = client.health()
            if bool(h.get("ok")):
                LOG.info("debug server ready: build=%s", h.get("build"))
                return True
        except requests.RequestException as e:
            last_err = str(e)
        time.sleep(0.5)
    LOG.error("debug server never came up — last error: %s", last_err)
    return False


def run_step(client: DebugClient, step: dict, screenshots_dir: Path) -> StepResult:
    """Dispatch one step from a YAML case. Returns a StepResult.

    Every YAML step looks like { name, action, ... }. The action field
    decides which DebugClient method runs and how the result is judged.
    """
    name: str = str(step.get("name", "<unnamed>"))
    action: str = str(step.get("action", ""))
    started = time.time()
    try:
        if action == "switch_mode":
            r = client.switch_mode(step["mode"])
            # Server returns both the int constant and the friendly name;
            # accept a match against either so YAML can use whichever's
            # more readable.
            wanted = step["mode"]
            wanted_str = str(wanted).strip().lower()
            ok = (
                r.get("mode") == wanted
                or str(r.get("name", "")).strip().lower() == wanted_str
            )
            return _step_done(name, action, started, ok, r, wanted)
        elif action == "drill_start":
            kwargs = {k: v for k, v in step.items() if k not in ("name", "action")}
            r = client.drill_start(kwargs.pop("type"), **kwargs)
            ok = int(r.get("note_count", 0)) > 0
            return _step_done(name, action, started, ok, r, ">0 notes")
        elif action == "drill_play":
            r = client.drill_play()
            return _step_done(name, action, started, bool(r.get("playing")), r, True)
        elif action == "drill_stop":
            r = client.drill_stop()
            return _step_done(name, action, started, bool(r.get("stopped")), r, True)
        elif action == "wait_ms":
            ms = int(step.get("ms", 100))
            time.sleep(ms / 1000.0)
            return _step_done(name, action, started, True, ms, ms)
        elif action == "midi_inject":
            r = client.midi_inject(int(step["pitch"]),
                                   int(step.get("velocity", 96)),
                                   int(step.get("hold_ms", 0)))
            return _step_done(name, action, started, True, r, step["pitch"])
        elif action == "assert":
            r = client.assert_member(step["member"], step.get("op", "eq"), step.get("value"))
            return _step_done(name, action, started, bool(r.get("passed")),
                              r.get("observed"), r.get("expected"))
        elif action == "assert_audio":
            # Drain the audio probe and check it contains the expected pitch.
            r = client.audio_probe()
            events: list[dict] = r.get("events", [])
            target = int(step["pitch"])
            ok = any(_pc(int(e["midi"])) == _pc(target) for e in events
                     if isinstance(e, dict) and "midi" in e)
            return _step_done(name, action, started, ok,
                              [e.get("midi") for e in events], target)
        elif action == "screenshot":
            tag = str(step.get("tag", f"case_{int(started * 1000)}"))
            r = client.screenshot(tag)
            # Passes if a path was written OR the server explicitly says
            # the capture was skipped (headless / no rendered viewport).
            ok = ("path" in r) or bool(r.get("skipped", False))
            observed = r.get("path") or ("skipped: " + str(r.get("reason", "")))
            return _step_done(name, action, started, ok, observed, tag)
        else:
            return _step_done(name, action, started, False,
                              None, None, f"unknown action: {action}")
    except requests.RequestException as e:
        return _step_done(name, action, started, False, None, None, f"HTTP error: {e}")
    except KeyError as e:
        return _step_done(name, action, started, False, None, None, f"missing field: {e}")


def _pc(midi: int) -> int:
    """Pitch class normalize (0..11)."""
    return ((midi % 12) + 12) % 12


def _step_done(name: str, action: str, started: float, ok: bool,
               observed: Any, expected: Any, message: str = "") -> StepResult:
    return StepResult(
        name=name,
        action=action,
        ok=ok,
        duration_ms=int((time.time() - started) * 1000),
        observed=observed,
        expected=expected,
        message=message,
    )


def run_case(client: DebugClient, case: dict, screenshots_dir: Path,
             results_dir: Path) -> CaseResult:
    name = str(case.get("name", "<unnamed case>"))
    tags = [str(t) for t in case.get("tags", [])]
    started = time.time()
    LOG.info("▶ %s [%s]", name, ",".join(tags) or "no tags")
    steps_out: list[StepResult] = []
    screenshots: list[str] = []
    failure_reason: str | None = None
    for step in case.get("steps", []):
        step_result = run_step(client, step, screenshots_dir)
        steps_out.append(step_result)
        if step_result.action == "screenshot" and step_result.ok:
            screenshots.append(str(step_result.observed))
        if not step_result.ok:
            failure_reason = f"step '{step_result.name}' failed: {step_result.message or 'see observed/expected'}"
            LOG.error("  ✗ %s [%s]: %s", step_result.name, step_result.action, failure_reason)
            if bool(case.get("stop_on_failure", True)):
                break
        else:
            LOG.info("  ✓ %s [%s] (%dms)", step_result.name, step_result.action, step_result.duration_ms)
    return CaseResult(
        name=name,
        tags=tags,
        started_unix=started,
        duration_sec=round(time.time() - started, 3),
        ok=failure_reason is None,
        steps=steps_out,
        screenshots=screenshots,
        failure_reason=failure_reason,
    )


def filter_cases(all_cases: list[dict], tag: str | None, names: list[str] | None) -> list[dict]:
    filtered = all_cases
    if tag:
        filtered = [c for c in filtered if tag in (c.get("tags") or [])]
    if names:
        names_set = set(names)
        filtered = [c for c in filtered if c.get("name") in names_set]
    return filtered


def write_results(results: list[CaseResult], results_dir: Path) -> Path:
    results_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "summary": {
            "total": len(results),
            "passed": sum(1 for r in results if r.ok),
            "failed": sum(1 for r in results if not r.ok),
            "duration_sec": round(sum(r.duration_sec for r in results), 3),
        },
        "cases": [asdict(r) for r in results],
    }
    out_path = results_dir / "qa_results.json"
    out_path.write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    LOG.info("wrote results: %s", out_path)
    return out_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Clefira AI-orchestrated QA pipeline")
    p.add_argument("--build", type=Path, help="Path to Clefira.exe (omit with --no-launch)")
    p.add_argument("--port", type=int, default=DEFAULT_PORT, help="Debug server port")
    p.add_argument("--no-launch", action="store_true",
                   help="Don't launch Clefira; connect to an already-running instance")
    p.add_argument("--windowed", action="store_true",
                   help="Launch in windowed mode (default headless)")
    p.add_argument("--cases", type=Path, default=Path(__file__).parent / "test_cases.yaml",
                   help="YAML file with test fixtures")
    p.add_argument("--tag", type=str, default=None, help="Run only cases with this tag")
    p.add_argument("--name", action="append", default=None,
                   help="Run only the case(s) with this name (repeatable)")
    p.add_argument("--output", type=Path, default=Path(__file__).parent / RESULTS_DIR_NAME,
                   help="Output directory for results")
    p.add_argument("--verbose", "-v", action="count", default=0)
    return p.parse_args()


def main() -> int:
    args = parse_args()
    log_level = logging.DEBUG if args.verbose >= 2 else (logging.INFO if args.verbose >= 1 else logging.WARNING)
    logging.basicConfig(level=log_level, format="%(asctime)s [%(levelname)s] %(message)s")
    LOG.setLevel(log_level if log_level != logging.WARNING else logging.INFO)

    cases_path: Path = args.cases
    if not cases_path.is_file():
        LOG.error("cases file not found: %s", cases_path)
        return 2
    raw = yaml.safe_load(cases_path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict) or "cases" not in raw:
        LOG.error("cases file must have top-level 'cases:' list")
        return 2
    cases = filter_cases(raw["cases"], args.tag, args.name)
    if not cases:
        LOG.warning("no cases matched filter — exiting clean")
        return 0

    output_dir: Path = args.output
    output_dir.mkdir(parents=True, exist_ok=True)
    screenshots_dir = output_dir / SCREENSHOT_DIR_NAME
    screenshots_dir.mkdir(parents=True, exist_ok=True)

    launcher: ClefiraLauncher | None = None
    if not args.no_launch:
        if args.build is None:
            LOG.error("--build is required unless --no-launch is set")
            return 2
        launcher = ClefiraLauncher(args.build, args.port, windowed=args.windowed)
        launcher.launch()

    client = DebugClient(args.port)
    try:
        if not wait_until_ready(client):
            LOG.error("aborting — debug server unreachable")
            return 3
        results: list[CaseResult] = []
        for case in cases:
            results.append(run_case(client, case, screenshots_dir, output_dir))
        results_path = write_results(results, output_dir)
        # Copy logs snapshot so the LLM analyser has the in-game event log.
        try:
            log_dump = client.logs(0).get("logs", [])
            (output_dir / "qa_logs.json").write_text(json.dumps(log_dump, indent=2), encoding="utf-8")
        except requests.RequestException:
            pass
        failures = sum(1 for r in results if not r.ok)
        LOG.info("done — %d passed, %d failed → %s",
                 len(results) - failures, failures, results_path)
        return 0 if failures == 0 else 1
    finally:
        try:
            client.quit()
        except requests.RequestException:
            pass
        if launcher is not None:
            launcher.shutdown()


if __name__ == "__main__":
    sys.exit(main())
