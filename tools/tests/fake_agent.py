#!/usr/bin/env python3
"""Stands in for `claude` and `codex` (F-002/C19). Replays scripted steps from $FAKE_DIR."""

import json
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

BOARD = Path("studio/STATUS.md")


def feature_path(prompt):
    return Path(re.search(r"studio/features/[\w.-]+\.md", prompt).group(0))


def head():
    return subprocess.run(
        ["git", "rev-parse", "HEAD"], capture_output=True, text=True, check=True
    ).stdout.strip()


def set_front(path, status, owner):
    text = path.read_text()
    text = re.sub(r"(?m)^status: \S+", f"status: {status}", text, count=1)
    text = re.sub(r"(?m)^owner_now: \S+", f"owner_now: {owner}", text, count=1)
    path.write_text(text)


def set_board(path, status, owner):
    fid = re.search(r"F-\d+", path.name).group(0)
    lines = BOARD.read_text().split("\n")
    for index, line in enumerate(lines):
        if line.startswith(f"| {fid} |"):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            cells[2], cells[3] = status, owner
            lines[index] = "| " + " | ".join(cells) + " |"
    BOARD.write_text("\n".join(lines))


def section_add(path, number, addition):
    lines = path.read_text().split("\n")
    start = next(i for i, line in enumerate(lines) if line.startswith(f"## {number}. "))
    end = next((i for i in range(start, len(lines)) if lines[i] == "---"), len(lines))
    text = addition.replace("{HEAD}", head())
    path.write_text("\n".join(lines[:end] + text.split("\n") + [""] + lines[end:]))


def table_add(path, row):
    lines = path.read_text().split("\n")
    start = next(i for i, line in enumerate(lines) if line.startswith("## 10. "))
    last = max(i for i in range(start, len(lines)) if lines[i].startswith("|"))
    path.write_text("\n".join(lines[: last + 1] + [row] + lines[last + 1 :]))


def apply(op, path, out):
    name, *args = op
    if name == "state":
        set_front(path, *args)
        set_board(path, *args)
    elif name == "front":
        set_front(path, *args)
    elif name == "board":
        set_board(path, *args)
    elif name == "section_add":
        section_add(path, *args)
    elif name == "table_add":
        table_add(path, *args)
    elif name == "replace":
        target = Path(args[0]) if args[0] != "@feature" else path
        target.write_text(target.read_text().replace(args[1], args[2], 1))
    elif name == "write":
        Path(args[0]).parent.mkdir(parents=True, exist_ok=True)
        Path(args[0]).write_text(args[1])
    elif name == "copy":
        Path(args[1]).write_bytes(Path(args[0]).read_bytes())
    elif name == "git":
        subprocess.run(["git", *args], check=True, capture_output=True)
    elif name == "git_try":
        result = subprocess.run(["git", *args], capture_output=True, text=True)
        out["git_try"] = result.returncode
    elif name == "exit":
        sys.exit(args[0])
    elif name == "sleep":
        time.sleep(args[0])
    elif name == "ignore_term":
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
    elif name == "spawn_child":
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        out["child_pid"] = child.pid
    else:
        raise SystemExit(f"unknown op {name}")


def main():
    fake_dir = Path(os.environ["FAKE_DIR"])
    prompt = next((arg for arg in sys.argv[1:] if "STUDIO-ROLE" in arg), "")
    calls = fake_dir / "calls.jsonl"
    index = len(calls.read_text().splitlines()) if calls.exists() else 0
    record = {
        "argv": sys.argv[1:],
        "binary": Path(sys.argv[0]).name,
        "prompt": prompt,
        "pid": os.getpid(),
        "pushurl": os.environ.get("GIT_CONFIG_VALUE_0"),
        "terminal_prompt": os.environ.get("GIT_TERMINAL_PROMPT"),
    }
    with calls.open("a") as handle:
        handle.write(json.dumps(record) + "\n")
    steps = json.loads((fake_dir / "steps.json").read_text())
    if index >= len(steps):
        print("no scripted step left")
        sys.exit(99)
    out = {}
    path = feature_path(prompt)
    try:
        for op in steps[index]:
            apply(op, path, out)
            (fake_dir / f"out-{index}.json").write_text(json.dumps(out))
    finally:
        (fake_dir / f"out-{index}.json").write_text(json.dumps(out))


if __name__ == "__main__":
    main()
