"""Git layer (F-002 C3, C7, C11, C16–C18). Never `add -A`, never `branch -D`, never rewrites."""

from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

STUDIO_DIR = ".studio/"
MAIN = "main"
REMOTE = "origin"


class GitError(RuntimeError):
    def __init__(self, args: tuple[str, ...], returncode: int, stderr: str) -> None:
        self.command = "git " + " ".join(args)
        self.returncode = returncode
        self.stderr = stderr.strip()
        super().__init__(f"`{self.command}` failed: {self.stderr or returncode}")


@dataclass(frozen=True)
class Snapshot:
    """F-002/C11: what a step started from."""

    branch: str | None
    head: str
    local_refs: dict[str, str]
    remote_refs: dict[str, str]


@dataclass(frozen=True)
class Commit:
    sha: str
    subject: str


class Git:
    def __init__(self, root: Path) -> None:
        self.root = root

    def run(self, *args: str, check: bool = True) -> subprocess.CompletedProcess:
        env = {**os.environ, "LC_ALL": "C", "GIT_TERMINAL_PROMPT": "0"}
        result = subprocess.run(
            ["git", *args],
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
            errors="replace",  # An agent can leave bytes that aren't text.
        )
        if check and result.returncode != 0:
            raise GitError(args, result.returncode, result.stderr or result.stdout)
        return result

    def _out(self, *args: str) -> str:
        return self.run(*args).stdout.strip()

    def _null_list(self, *args: str) -> list[str]:
        return [item for item in self.run(*args).stdout.split("\0") if item]

    def current_branch(self) -> str | None:
        result = self.run("symbolic-ref", "-q", "--short", "HEAD", check=False)
        return result.stdout.strip() or None

    def head(self, ref: str = "HEAD") -> str:
        return self._out("rev-parse", "--verify", f"{ref}^{{commit}}")

    def show(self, ref: str, path: str) -> str:
        return self.run("show", f"{ref}:{path}").stdout

    def show_or_empty(self, ref: str, path: str) -> str:
        result = self.run("show", f"{ref}:{path}", check=False)
        return result.stdout if result.returncode == 0 else ""

    def tracked_names(self, ref: str, directory: str) -> list[str]:
        return self._null_list("ls-tree", "-r", "-z", "--name-only", ref, directory)

    def is_ancestor(self, older: str, newer: str) -> bool:
        return self.run("merge-base", "--is-ancestor", older, newer, check=False).returncode == 0

    def branch_exists(self, branch: str) -> bool:
        result = self.run("show-ref", "--verify", "--quiet", f"refs/heads/{branch}", check=False)
        return result.returncode == 0

    def local_refs(self) -> dict[str, str]:
        lines = self._out("for-each-ref", "--format=%(refname) %(objectname)", "refs/heads")
        return dict(line.split(" ", 1) for line in lines.splitlines())

    def remote_refs(self) -> dict[str, str]:
        refs = {}
        for line in self._out("ls-remote", REMOTE).splitlines():
            sha, name = line.split("\t", 1)
            refs[name] = sha
        return refs

    def remote_branch_sha(self, branch: str) -> str | None:
        return self.remote_refs().get(f"refs/heads/{branch}")

    # --- Working tree ---

    def dirty_paths(self) -> list[str]:
        """F-002/C21: `status --porcelain` minus `.studio/`. Ignored files don't count."""
        entries = self._null_list("status", "--porcelain", "-z", "--no-renames", "-uall")
        paths = {entry[3:] for entry in entries}
        return sorted(path for path in paths if not path.startswith(STUDIO_DIR))

    def is_clean(self) -> bool:
        return not self.dirty_paths()

    def is_merging(self) -> bool:
        return self.run("rev-parse", "-q", "--verify", "MERGE_HEAD", check=False).returncode == 0

    def conflicted_paths(self) -> list[str]:
        return self._null_list("diff", "--name-only", "--diff-filter=U", "-z")

    # --- F-002/C11 change detection ---

    def snapshot(self) -> Snapshot:
        return Snapshot(self.current_branch(), self.head(), self.local_refs(), self.remote_refs())

    def new_commits(self, start: str) -> list[Commit]:
        lines = self._out("log", "--format=%H %s", f"{start}..HEAD").splitlines()
        return [Commit(*(line.split(" ", 1) + [""])[:2]) for line in lines]

    def committed_paths(self, start: str, end: str = "HEAD") -> list[str]:
        """Every path in every new commit. A later revert doesn't hide an earlier edit."""
        return self._null_list(
            "log", "-m", "--format=", "--name-only", "--no-renames", "-z", f"{start}..{end}"
        )

    def subjects(self, start: str, end: str) -> list[str]:
        return self._out("log", "--format=%s", f"{start}..{end}").splitlines()

    def changed_set(self, start: str) -> list[str]:
        paths = set(self.committed_paths(start)) | set(self.dirty_paths())
        return sorted(path for path in paths if not path.startswith(STUDIO_DIR))

    # --- Writes the tool performs itself ---

    def commit_paths(self, paths: list[str], message: str) -> None:
        """F-002/C16: explicit paths only."""
        self.run("add", "--", *paths)
        self.run("commit", "-m", message)

    def create_or_checkout(self, branch: str, base: str = MAIN) -> None:
        """F-002/C7."""
        if self.branch_exists(branch):
            self.checkout(branch)
        else:
            self.run("checkout", "-b", branch, base)

    def checkout(self, branch: str) -> None:
        self.run("checkout", branch)

    def fetch(self) -> None:
        self.run("fetch", REMOTE)

    def pull_rebase(self, branch: str) -> None:
        """A failed rebase is aborted so the failure leaves the tree as it was."""
        try:
            self.run("pull", "--rebase", REMOTE, branch)
        except GitError:
            if Path(self.root, ".git", "rebase-merge").exists():
                self.run("rebase", "--abort", check=False)
            raise

    def push(self, branch: str) -> None:
        self.run("push", REMOTE, f"{branch}:{branch}")

    def merge_no_ff(self, branch: str, message: str) -> bool:
        """Returns False on a conflict, leaving the merge in place for Lucas to inspect."""
        result = self.run("merge", "--no-ff", "--no-edit", "-m", message, branch, check=False)
        if result.returncode == 0:
            return True
        if self.is_merging():
            return False
        raise GitError(("merge", branch), result.returncode, result.stderr or result.stdout)

    def delete_remote_branch(self, branch: str) -> None:
        self.run("push", REMOTE, "--delete", branch)

    def delete_local_branch(self, branch: str) -> None:
        self.run("branch", "-d", branch)
