"""A disposable studio: temporary repo, bare remote, fake agents (F-002 §5)."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = TOOLS_DIR.parent
TOOL = TOOLS_DIR / "studio"
FAKE_AGENT = TOOLS_DIR / "tests" / "fake_agent.py"
sys.path.insert(0, str(TOOLS_DIR))

FID = "F-900"
FEATURE = "studio/features/F-900-demo.md"
BOARD = "studio/STATUS.md"
BRANCH = "feature/F-900-demo"

FEATURE_TEXT = """---
id: F-900
title: Demo feature
status: {status}   # DRAFT | PLAN_REVIEW | ...
owner_now: {owner}   # who must act next
created: 2026-10-31
updated: 2026-10-31
depends_on: []
pillars: []
department: Direction   # infrastructure
---

# F-900 — Demo feature

> How to use this file.

---

## 1. Goal  ·  _Planner_

The goal.

---

## 2. Context  ·  _Planner_

---

## 3. Options Considered  ·  _Planner_

---

## 4. Constraints  ·  _Planner_

---

## 5. Acceptance Criteria  ·  _Planner_

---

## 6. Task Breakdown  ·  _Planner_

---

## 7. Plan Review  ·  _Auditor_

**Verdict:** `PENDING`
{plan_rounds}
---

## 8. Implementation Log  ·  _Builder_

**Started:** —

---

## 9. Code Review  ·  _Auditor_

**Verdict:** `PENDING`
**Reviewed commit:** <hash>  ·  **Round:** 1
{code_rounds}
---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | | | yes/no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides>
"""

BOARD_TEXT = """# STATUS — The Board

**Last updated:** 2026-10-31

| ID | Feature | Status | Next actor | Blocked by |
|---|---|---|---|---|
| F-899 | Other | DONE | — | — |
| F-900 | Demo feature | {status} | {owner} | — |

## Parked
- _none_
"""

DECISIONS_TEXT = """# DECISIONS

```
## D-### — <title>
```

---

## D-002 — Second
- **Status:** ACCEPTED

## D-001 — First
- **Status:** ACCEPTED
"""


def rounds_text(verdicts: list[str]) -> str:
    return "\n".join(
        f"<!-- review-round: {i} verdict: {v} -->\nRound {i} text."
        for i, v in enumerate(verdicts, start=1)
    )


# --- Scripted agent steps ---


def builder_ok(path: str = "src/new.txt", content: str = "work\n") -> list:
    return [
        ["write", path, content],
        ["state", "CODE_REVIEW", "Auditor"],
        ["git", "add", "--", path, FEATURE, BOARD],
        ["git", "commit", "-m", "F-900 T1: work"],
    ]


def builder_escalates() -> list:
    return [
        ["table_add", "| Q2 | Builder | Which way? | yes | |"],
        ["state", "IN_PROGRESS", "Lucas"],
        ["git", "add", "--", FEATURE, BOARD],
        ["git", "commit", "-m", "F-900: escalate"],
    ]


def auditor_code(number: int = 1, verdict: str = "APPROVE") -> list:
    state = ("CODE_CHANGES", "Builder") if verdict.startswith("CHANGES") else ("CODE_REVIEW", "Lucas")
    marker = f"<!-- review-round: {number} verdict: {verdict} -->\n**Reviewed commit:** `{{HEAD}}`"
    return [["section_add", 9, marker], ["state", *state]]


def auditor_plan(number: int = 1, verdict: str = "APPROVE") -> list:
    state = ("PLAN_CHANGES", "Planner") if verdict.startswith("CHANGES") else ("PLAN_REVIEW", "Lucas")
    marker = f"<!-- review-round: {number} verdict: {verdict} -->\nFindings."
    return [["section_add", 7, marker], ["state", *state]]


def planner_ok() -> list:
    return [
        ["section_add", 7, "> **Planner reply (Direction):** Accepted."],
        ["replace", "@feature", "The goal.", "The better goal."],
        ["state", "PLAN_REVIEW", "Auditor"],
    ]


class Sandbox:
    """One temporary repo with a bare remote. Use as a context manager."""

    def __init__(
        self,
        status: str = "APPROVED",
        owner: str = "Builder",
        plan_rounds: list[str] | None = None,
        code_rounds: list[str] | None = None,
    ) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(os.path.realpath(self.temp.name))
        self.repo = self.base / "repo"
        self.remote = self.base / "remote.git"
        self.fake_dir = self.base / "fake"
        self.bin_dir = self.base / "bin"
        self.fake_dir.mkdir()
        self.bin_dir.mkdir()
        self.env = self._make_env()
        self._make_fakes()
        self._make_repo(status, owner, plan_rounds or [], code_rounds or [])
        self.script()

    def __enter__(self) -> "Sandbox":
        return self

    def __exit__(self, *_exc: object) -> None:
        self.temp.cleanup()

    def _make_env(self) -> dict[str, str]:
        # Hermetic: a Builder runs these tests with the push guard from proc.agent_env() set.
        inherited = ("STUDIO_", "GIT_")
        env = {key: value for key, value in os.environ.items() if not key.startswith(inherited)}
        env.update(
            {
                "PATH": f"{self.bin_dir}{os.pathsep}{env['PATH']}",
                "FAKE_DIR": str(self.fake_dir),
                "STUDIO_CLAUDE_BIN": str(self.bin_dir / "claude"),
                "STUDIO_CODEX_BIN": str(self.bin_dir / "codex"),
                "STUDIO_KILL_GRACE_SECONDS": "0.4",
                "GIT_CONFIG_GLOBAL": os.devnull,
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_AUTHOR_NAME": "Test",
                "GIT_AUTHOR_EMAIL": "test@example.com",
                "GIT_COMMITTER_NAME": "Test",
                "GIT_COMMITTER_EMAIL": "test@example.com",
            }
        )
        return env

    def _make_fakes(self) -> None:
        for name in ("claude", "codex"):
            target = self.bin_dir / name
            target.write_text(
                f'#!/bin/sh\nexec "{sys.executable}" "{FAKE_AGENT}" "$@"\n'
            )
            target.chmod(0o755)
        notifier = self.bin_dir / "osascript"
        notifier.write_text(
            '#!/bin/sh\nfor last; do prev=$msg; msg=$last; done\n'
            f'printf "%s\\n===\\n" "$prev" >> "{self.fake_dir}/notifications"\n'
        )
        notifier.chmod(0o755)

    def _make_repo(self, status: str, owner: str, plan: list[str], code: list[str]) -> None:
        subprocess.run(
            ["git", "init", "-q", "--bare", "-b", "main", str(self.remote)],
            check=True,
            env=self.env,
        )
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        self.git("remote", "add", "origin", str(self.remote))
        files = {
            FEATURE: FEATURE_TEXT.format(
                status=status,
                owner=owner,
                plan_rounds=rounds_text(plan),
                code_rounds=rounds_text(code),
            ),
            BOARD: BOARD_TEXT.format(status=status, owner=owner),
            "studio/DECISIONS.md": DECISIONS_TEXT,
            "studio/GLOSSARY.md": "# GLOSSARY\n",
            "studio/design/combat.md": "# Combat\n",
            "studio/departments/direction.md": "# Direction\n",
            "AGENTS.md": "# Auditor\n",
            "CLAUDE.md": "# Builder\n",
            "README.md": "# Demo\n",
            ".gitignore": ".studio/\n",
        }
        for path, text in files.items():
            self.write(path, text)
        for script in ("tools/test", "tools/lint", "tools/check_core_purity"):
            self.write(
                script,
                f'#!/bin/sh\nexit "$(cat "{self.fake_dir}/checks_exit" 2>/dev/null || echo 0)"\n',
            )
            (self.repo / script).chmod(0o755)
        self.git("add", ".")
        self.git("commit", "-q", "-m", "init")
        self.git("push", "-q", "-u", "origin", "main")

    # --- Driving ---

    def git(self, *args: str, check: bool = True) -> str:
        result = subprocess.run(
            ["git", *args], cwd=self.repo, env=self.env, capture_output=True, text=True
        )
        if check and result.returncode != 0:
            raise AssertionError(f"git {args}: {result.stderr}")
        return result.stdout.strip()

    def remote_git(self, *args: str, check: bool = True) -> str:
        result = subprocess.run(
            ["git", f"--git-dir={self.remote}", *args],
            env=self.env,
            capture_output=True,
            text=True,
        )
        if check and result.returncode != 0:
            raise AssertionError(f"git {args}: {result.stderr}")
        return result.stdout.strip()

    def studio(self, *args: str, timeout: float = 30.0) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(TOOL), *args],
            cwd=self.repo,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=timeout,
        )

    def start_studio(self, *args: str) -> subprocess.Popen:
        return subprocess.Popen(
            [sys.executable, str(TOOL), *args],
            cwd=self.repo,
            env=self.env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def script(self, *steps: list) -> None:
        """The next agent calls, in order, across commands."""
        (self.fake_dir / "steps.json").write_text(json.dumps(list(steps)))

    def set_checks(self, exit_code: int) -> None:
        (self.fake_dir / "checks_exit").write_text(str(exit_code))

    def write(self, path: str, text: str) -> None:
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def read(self, path: str) -> str:
        return (self.repo / path).read_text()

    def commit_all(self, message: str, *paths: str) -> str:
        self.git("add", "--", *paths)
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def edit_state(self, status: str, owner: str) -> None:
        """A person editing the header, no tool involved."""
        text = self.read(FEATURE).split("\n")
        for index, line in enumerate(text):
            if line.startswith("status: "):
                text[index] = f"status: {status}"
            elif line.startswith("owner_now: "):
                text[index] = f"owner_now: {owner}"
        self.write(FEATURE, "\n".join(text))
        board = self.read(BOARD).split("\n")
        for index, line in enumerate(board):
            if line.startswith(f"| {FID} |"):
                board[index] = f"| {FID} | Demo feature | {status} | {owner} | — |"
        self.write(BOARD, "\n".join(board))

    def checkout_feature_branch(self) -> None:
        """A feature already in build: its branch exists, with one code commit."""
        self.git("checkout", "-q", "-b", BRANCH)
        self.write("src/new.txt", "work\n")
        self.commit_all("F-900 T1: work", "src/new.txt")

    def prepare_gate_b(self, verdict: str = "APPROVE") -> str:
        """From APPROVED on main: a reviewed branch at (CODE_REVIEW, Lucas). Returns the
        reviewed commit."""
        self.checkout_feature_branch()
        reviewed = self.git("rev-parse", "HEAD")
        marker = f"<!-- review-round: 1 verdict: {verdict} -->\n**Reviewed commit:** `{reviewed}`\n"
        self.write(FEATURE, self.read(FEATURE).replace("\n---\n\n## 10.", f"\n{marker}\n---\n\n## 10."))
        self.edit_state("CODE_REVIEW", "Lucas")
        self.commit_all("F-900: Auditor code review round 1", FEATURE, BOARD)
        return reviewed

    def add_remote_hook(self, script: str) -> None:
        hook = self.remote / "hooks" / "pre-receive"
        hook.write_text("#!/bin/sh\n" + script + "\n")
        hook.chmod(0o755)

    def remove_remote_hook(self) -> None:
        (self.remote / "hooks" / "pre-receive").unlink()

    def advance_remote_main(self, path: str = "remote.txt", text: str = "remote\n") -> None:
        """Someone else pushes to origin/main."""
        other = self.base / "other"
        if other.exists():
            shutil.rmtree(other)
        subprocess.run(
            ["git", "clone", "-q", str(self.remote), str(other)], check=True, env=self.env
        )
        (other / path).parent.mkdir(parents=True, exist_ok=True)
        (other / path).write_text(text)
        for args in (["add", "--", path], ["commit", "-q", "-m", "remote work"], ["push", "-q"]):
            subprocess.run(["git", *args], cwd=other, check=True, env=self.env)

    # --- Observing ---

    def calls(self) -> list[dict]:
        path = self.fake_dir / "calls.jsonl"
        if not path.exists():
            return []
        return [json.loads(line) for line in path.read_text().splitlines()]

    def roles(self) -> list[str]:
        return [call["prompt"].split("\n")[0].removeprefix("STUDIO-ROLE: ") for call in self.calls()]

    def notifications(self) -> list[str]:
        path = self.fake_dir / "notifications"
        if not path.exists():
            return []
        return [item.strip() for item in path.read_text().split("\n===\n") if item.strip()]

    def state(self) -> tuple[str, str]:
        status = owner = ""
        for line in self.read(FEATURE).split("\n"):
            if line.startswith("status: "):
                status = line.split()[1]
            elif line.startswith("owner_now: "):
                owner = line.split()[1]
        return status, owner

    def is_blocked(self) -> bool:
        return (self.repo / ".studio" / "blocked" / f"{FID}.json").exists()

    def blocked_record(self) -> dict:
        return json.loads((self.repo / ".studio" / "blocked" / f"{FID}.json").read_text())

    def lock_exists(self) -> bool:
        return (self.repo / ".studio" / "lock").exists()

    def commit_count(self) -> int:
        return int(self.git("rev-list", "--count", "HEAD"))

    def dirty(self) -> str:
        return self.git("status", "--porcelain")

    def wait_for_call(self, count: int = 1, seconds: float = 10.0) -> None:
        deadline = time.monotonic() + seconds
        while len(self.calls()) < count:
            if time.monotonic() > deadline:
                raise AssertionError("the agent was never called")
            time.sleep(0.02)
