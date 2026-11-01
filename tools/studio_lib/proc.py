"""Agent processes: lock, process groups, timeouts, CLI flags (F-002 C3, C4, C15, C19)."""

from __future__ import annotations

import fcntl
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterator

DEFAULT_TIMEOUT_MINUTES = 90.0
KILL_GRACE_SECONDS = 30.0
POLL_SECONDS = 0.05
# F-002/C3: makes `git push` to origin fail inside every agent.
BLOCKED_PUSH_URL = "file:///dev/null/studio-agents-cannot-push"

# Chosen from `claude --help` and `codex exec --help`; recorded in README.md (F-002/C19).
# `dontAsk` denies anything not allowed, instead of waiting for a person.
_CLAUDE_BASE = ("--permission-mode", "dontAsk", "--no-session-persistence")
_PLANNER_TOOLS = "Read,Edit,Write,Glob,Grep"
_BUILDER_TOOLS = ("Bash", "Read", "Edit", "Write", "Glob", "Grep")
_BUILDER_DENIED = (
    "Bash(git push *)",
    "Bash(git checkout *)",
    "Bash(git switch *)",
    "Bash(git branch *)",
    "Bash(git rebase *)",
    "Bash(git reset *)",
)


class LockHeld(RuntimeError):
    pass


class Interrupted(RuntimeError):
    pass


def _pid_alive(pid: int | None) -> bool:
    if not pid:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _group_alive(pgid: int | None) -> bool:
    if not pgid:
        return False
    try:
        os.killpg(pgid, 0)
    except (ProcessLookupError, PermissionError):
        return False
    return True


class Lock:
    """F-002/C4: one shared lock. Stale only if neither recorded process is alive."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.agent_pgid: int | None = None

    def _write_temp(self) -> Path:
        temp = self.path.with_name(f"{self.path.name}.{os.getpid()}")
        record = {"tool_pid": os.getpid(), "agent_pgid": self.agent_pgid}
        temp.write_text(json.dumps(record))
        return temp

    def _read(self) -> dict | None:
        try:
            return json.loads(self.path.read_text())
        except (OSError, ValueError):
            return None

    def __enter__(self) -> "Lock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self._write_temp()
        try:
            # Taking the lock is one step: a contender can't act on a stale record while
            # another replaces it. The kernel drops this if the holder dies.
            with self.path.with_name(f"{self.path.name}.guard").open("w") as guard:
                fcntl.flock(guard, fcntl.LOCK_EX)
                try:
                    # Atomic: fails if the lock exists, and never leaves it half written.
                    os.link(temp, self.path)
                except FileExistsError:
                    self._clear_if_stale()
                    os.link(temp, self.path)
            return self
        finally:
            temp.unlink(missing_ok=True)

    def _clear_if_stale(self) -> None:
        """Only with the guard held."""
        record = self._read() or {}
        tool_pid = record.get("tool_pid")
        agent_pgid = record.get("agent_pgid")
        if _pid_alive(tool_pid) or _group_alive(agent_pgid):
            raise LockHeld(f"Another studio command is running (pid {tool_pid}).")
        print(f"warning: clearing stale lock from pid {tool_pid}", file=sys.stderr)
        self.path.unlink(missing_ok=True)

    def set_agent(self, pgid: int | None) -> None:
        self.agent_pgid = pgid
        os.replace(self._write_temp(), self.path)

    def __exit__(self, *_exc: object) -> None:
        record = self._read() or {}
        if record.get("tool_pid") == os.getpid():
            self.path.unlink(missing_ok=True)


@dataclass(frozen=True)
class ProcessResult:
    returncode: int | None
    timed_out: bool = False
    interrupted: bool = False
    launch_error: str | None = None

    @property
    def ok(self) -> bool:
        return self.returncode == 0 and not (self.timed_out or self.interrupted)

    def describe(self) -> str:
        if self.launch_error:
            return f"could not start: {self.launch_error}"
        if self.interrupted:
            return "interrupted"
        if self.timed_out:
            return "timed out"
        return f"exit code {self.returncode}"


def _signal_group(pgid: int, signum: int) -> None:
    try:
        os.killpg(pgid, signum)
    except (ProcessLookupError, PermissionError):
        pass


def _wait_for_group(process: subprocess.Popen, pgid: int, seconds: float) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        process.poll()
        if process.returncode is not None and not _group_alive(pgid):
            return True
        time.sleep(POLL_SECONDS)
    process.poll()
    return process.returncode is not None and not _group_alive(pgid)


def _terminate_group(process: subprocess.Popen, pgid: int, first: int, grace: float) -> None:
    """Signal, wait, then SIGTERM if needed, then SIGKILL. Returns with the group gone."""
    _signal_group(pgid, first)
    if _wait_for_group(process, pgid, grace):
        return
    if first != signal.SIGTERM:
        _signal_group(pgid, signal.SIGTERM)
        if _wait_for_group(process, pgid, grace):
            return
    _signal_group(pgid, signal.SIGKILL)
    process.wait()
    _wait_for_group(process, pgid, grace)


def kill_grace_seconds() -> float:
    return float(os.environ.get("STUDIO_KILL_GRACE_SECONDS", KILL_GRACE_SECONDS))


def run_group(
    command: list[str],
    cwd: Path,
    env: dict[str, str],
    log_path: Path,
    timeout_minutes: float,
    on_start: Callable[[int | None], None] | None = None,
) -> ProcessResult:
    """F-002/C15: own process group, timeout, Ctrl-C forwarded and waited for."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    grace = kill_grace_seconds()
    deadline = time.monotonic() + timeout_minutes * 60.0
    interrupted: list[int] = []

    def on_signal(signum: int, _frame: object) -> None:
        interrupted.append(signum)

    previous = {
        signum: signal.signal(signum, on_signal) for signum in (signal.SIGINT, signal.SIGTERM)
    }
    try:
        with log_path.open("ab") as log:
            log.write(f"$ {' '.join(command)}\n".encode())
            log.flush()
            try:
                process = subprocess.Popen(
                    command,
                    cwd=cwd,
                    env=env,
                    stdin=subprocess.DEVNULL,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    start_new_session=True,
                )
            except OSError as error:
                log.write(f"launch failed: {error}\n".encode())
                return ProcessResult(None, launch_error=str(error))
            pgid = process.pid
            if on_start:
                on_start(pgid)
            timed_out = False
            while process.poll() is None:
                if interrupted:
                    _terminate_group(process, pgid, signal.SIGINT, grace)
                    break
                if time.monotonic() >= deadline:
                    timed_out = True
                    _terminate_group(process, pgid, signal.SIGTERM, grace)
                    break
                time.sleep(POLL_SECONDS)
            # Nothing the agent left in its group may outlive the step.
            _terminate_group(process, pgid, signal.SIGTERM, grace)
            return ProcessResult(
                process.returncode, timed_out=timed_out, interrupted=bool(interrupted)
            )
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)
        if on_start:
            on_start(None)


@contextmanager
def keep_awake() -> Iterator[None]:
    """F-002 §1: Lucas walks away, so an idle Mac must not sleep under a step. `-w` ends the
    assertion with this process, however it dies. A closed lid still sleeps."""
    binary = shutil.which("caffeinate")
    process = None
    if binary:
        try:
            process = subprocess.Popen(
                [binary, "-i", "-w", str(os.getpid())],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError:
            process = None
    try:
        yield
    finally:
        if process:
            process.terminate()
            process.wait()


def agent_env() -> dict[str, str]:
    """F-002/C3: every agent call runs with `git push` to origin broken."""
    return {
        **os.environ,
        "GIT_CONFIG_COUNT": "1",
        "GIT_CONFIG_KEY_0": "remote.origin.pushurl",
        "GIT_CONFIG_VALUE_0": BLOCKED_PUSH_URL,
        "GIT_TERMINAL_PROMPT": "0",
    }


def agent_command(agent: str, role: str, prompt: str, root: Path) -> list[str]:
    """F-002/C19: least-privilege flags per role."""
    if agent == "codex":
        binary = os.environ.get("STUDIO_CODEX_BIN", "codex")
        return [
            binary,
            "exec",
            "--sandbox",
            "workspace-write",
            "-c",
            "sandbox_workspace_write.network_access=false",
            "--cd",
            str(root),
            prompt,
        ]
    binary = os.environ.get("STUDIO_CLAUDE_BIN", "claude")
    if role == "planner":
        tools = _PLANNER_TOOLS
        return [binary, "-p", prompt, "--tools", tools, "--allowedTools", tools, *_CLAUDE_BASE]
    return [
        binary,
        "-p",
        prompt,
        "--allowedTools",
        *_BUILDER_TOOLS,
        "--disallowedTools",
        *_BUILDER_DENIED,
        *_CLAUDE_BASE,
    ]
