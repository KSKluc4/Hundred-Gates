"""The orchestrator: action table, step validation, caps, readiness, gates (F-002 §4).

Agents do the work, but every decision about what runs next and what is accepted lives
here, where the Auditor can review it and tests can cover it (F-002 §3).
"""

from __future__ import annotations

import fnmatch
import json
import os
import re
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path

from . import feature as ft
from . import notify, proc
from .feature import APPROVING, CHANGES_REQUESTED, Feature, FormatError
from .git import MAIN, Commit, Git, GitError, Snapshot

BOARD = "studio/STATUS.md"
DECISIONS = "studio/DECISIONS.md"
GLOSSARY = "studio/GLOSSARY.md"
FEATURES_DIR = "studio/features"
DEPARTMENTS_DIR = "studio/departments"
CHECKS = ("tools/test", "tools/lint", "tools/check_core_purity")
PROMPTS_DIR = Path(__file__).resolve().parent.parent / "studio_prompts"

MAX_REVIEW_ROUNDS = 3  # F-002/C10(a)
MAX_READINESS_FAILURES = 3  # F-002/C10(b)
DEFAULT_MAX_STEPS = 8  # F-002/C10(c)
GATE_STATUSES = ("APPROVED", "DONE")
_FEATURE_ID_RE = re.compile(r"^F-\d{3,}$")


class Refused(Exception):
    """The command won't proceed. Nothing was changed by the refusal."""

    def __init__(self, message: str, next_command: str = "tools/studio status") -> None:
        super().__init__(message)
        self.message = message
        self.next_command = next_command


class StepRejected(Exception):
    """An agent step failed validation. The feature is blocked and Lucas was notified."""

    def __init__(self, exit_code: int = 1) -> None:
        super().__init__("step rejected")
        self.exit_code = exit_code


@dataclass(frozen=True)
class Step:
    key: str
    role: str
    agent: str
    prompt: str
    title: str


STEPS = {
    "A": Step("A", "auditor-plan", "codex", "auditor_plan.md", "plan audit"),
    "B": Step("B", "planner", "claude", "planner.md", "plan repair"),
    "C": Step("C", "builder", "claude", "builder.md", "build / fix"),
    "D": Step("D", "auditor-code", "codex", "auditor_code.md", "code audit"),
}
# F-002/C5: input -> action. Everything else stops.
ACTION_TABLE = {
    ("PLAN_REVIEW", "Auditor"): "A",
    ("PLAN_CHANGES", "Planner"): "B",
    ("APPROVED", "Builder"): "C",
    ("CODE_CHANGES", "Builder"): "C",
    ("CODE_REVIEW", "Auditor"): "D",
}


@dataclass(frozen=True)
class Decision:
    action: str | None
    reason: str


def decide(status: str, owner: str, blocked: bool = False, resume: bool = False) -> Decision:
    """F-002/C5, C22: the only place that maps a state to an action."""
    if blocked:
        return Decision(None, "blocked")
    if status == "IN_PROGRESS":
        if resume:
            return Decision("C", "resume")
        return Decision(None, "IN_PROGRESS continues only with run --resume")
    if status not in ft.STATUSES or owner not in ft.OWNERS:
        return Decision(None, f"unknown state ({status}, {owner})")
    if owner == "Lucas":
        return Decision(None, "owner is Lucas")
    if status in ("DRAFT", "DONE", "PARKED"):
        return Decision(None, f"status is {status}")
    action = ACTION_TABLE.get((status, owner))
    if action is None:
        return Decision(None, f"no action for ({status}, {owner})")
    return Decision(action, STEPS[action].title)


def transition_errors(key: str, before: Feature, after: Feature, given_head: str) -> list[str]:
    """F-002/C2, C5, C10(d): the only accepted outputs of each action."""
    state = (after.status, after.owner)
    errors = []
    if after.status in GATE_STATUSES:
        errors.append(f"agent produced {after.status}: only a gate command may (C2)")
    if state == (before.status, before.owner):
        errors.append(f"no progress: state is still {state}")
    new_blocking = len(after.unanswered_blocking) > len(before.unanswered_blocking)
    if key in ("A", "D"):
        errors.extend(_round_errors(key, before, after, given_head))
    else:
        if len(before.plan_rounds) != len(after.plan_rounds):
            errors.append("only the Auditor writes review rounds")
        if len(before.code_rounds) != len(after.code_rounds):
            errors.append("only the Auditor writes review rounds")
    if key == "B":
        if state == ("PLAN_CHANGES", "Lucas"):
            if not new_blocking:
                errors.append("escalation needs a new blocking §10 row")
        elif state != ("PLAN_REVIEW", "Auditor"):
            errors.append(f"action B can't output {state}")
    if key == "C":
        if state == ("IN_PROGRESS", "Lucas"):
            if not new_blocking:
                errors.append("escalation needs a new blocking §10 row")
        elif state != ("CODE_REVIEW", "Auditor"):
            errors.append(f"action C can't output {state}")
    return errors


def _round_errors(key: str, before: Feature, after: Feature, given_head: str) -> list[str]:
    old = before.plan_rounds if key == "A" else before.code_rounds
    new = after.plan_rounds if key == "A" else after.code_rounds
    other_before = before.code_rounds if key == "A" else before.plan_rounds
    other_after = after.code_rounds if key == "A" else after.plan_rounds
    errors = []
    if len(other_before) != len(other_after):
        errors.append("review rounds changed in the wrong section")
    if len(new) != len(old) + 1:
        return errors + [f"expected one new review round, found {len(new) - len(old)}"]
    latest = new[-1]
    expected = max((r.number for r in old), default=0) + 1
    if latest.number != expected:
        errors.append(f"round number is {latest.number}, expected {expected}")
    changes_state = ("PLAN_CHANGES", "Planner") if key == "A" else ("CODE_CHANGES", "Builder")
    approve_state = ("PLAN_REVIEW", "Lucas") if key == "A" else ("CODE_REVIEW", "Lucas")
    state = (after.status, after.owner)
    if latest.verdict == CHANGES_REQUESTED:
        if state != changes_state:
            errors.append(f"verdict {latest.verdict} needs state {changes_state}, found {state}")
    elif latest.verdict in APPROVING:
        if state != approve_state:
            errors.append(f"verdict {latest.verdict} needs state {approve_state}, found {state}")
    else:
        errors.append(f"unknown verdict {latest.verdict}")
    if key == "D":
        reviewed = after.reviewed_commit
        if not reviewed or not given_head.startswith(reviewed):
            errors.append(f"Reviewed commit is {reviewed}, expected {given_head[:7]}")
    return errors


def path_allowed(role: str, path: str, feature_path: str) -> bool:
    """F-002/C12."""
    if role.startswith("auditor"):
        return path in (feature_path, BOARD)
    if role == "planner":
        return path in (feature_path, BOARD, DECISIONS, GLOSSARY) or (
            fnmatch.fnmatch(path, "studio/design/*.md") and path.count("/") == 2
        )
    if path in (DECISIONS, "AGENTS.md", "CLAUDE.md"):
        return False
    if path.startswith((f"{DEPARTMENTS_DIR}/", "studio/design/")):
        return False
    return not (path.startswith(f"{FEATURES_DIR}/") and path != feature_path)


@dataclass(frozen=True)
class FeatureRef:
    fid: str
    path: str
    branch: str


@dataclass(frozen=True)
class View:
    feature: Feature
    board: str


@dataclass
class Inspection:
    errors: list[str]
    commits: list[Commit]
    paths: list[str]
    remote_changes: dict[str, tuple[str | None, str | None]]


def next_step(ref: FeatureRef, feature: Feature, blocked: bool) -> tuple[str, str]:
    """What happened at a stop, and the one exact next command (F-002/C20)."""
    state = (feature.status, feature.owner)
    if blocked:
        return "blocked", f"tools/studio unblock {ref.fid}"
    if state == ("PLAN_REVIEW", "Lucas"):
        return "plan approved by the Auditor, waiting for Gate A", f"tools/studio approve {ref.fid}"
    if state == ("CODE_REVIEW", "Lucas"):
        return "ready to play, waiting for Gate B", f"tools/studio done {ref.fid}"
    if state == ("IN_PROGRESS", "Lucas"):
        return "Builder needs an answer in §10", f"tools/studio run --resume {ref.fid}"
    if feature.status == "IN_PROGRESS":
        return "build was interrupted", f"tools/studio run --resume {ref.fid}"
    if feature.owner == "Lucas" and feature.status not in ("DONE", "PARKED"):
        return "needs your decision in §10", f"open {ref.path}"
    if feature.status in ("DONE", "PARKED"):
        return f"status is {feature.status}", "tools/studio status"
    if feature.status == "DRAFT":
        return "still a draft", f"open {ref.path}"
    decision = decide(feature.status, feature.owner)
    if decision.action:
        return f"ready for action {decision.action}", f"tools/studio run {ref.fid}"
    return decision.reason, f"open {ref.path}"


class Studio:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.git = Git(root)
        self.state_dir = root / ".studio"

    # --- Files and state ---

    def _read(self, path: str) -> str:
        return (self.root / path).read_text()

    def _read_optional(self, path: str) -> str | None:
        target = self.root / path
        return target.read_text() if target.is_file() else None

    def _write(self, path: str, text: str) -> None:
        (self.root / path).write_text(text)

    def lock(self) -> proc.Lock:
        return proc.Lock(self.state_dir / "lock")

    def find(self, fid: str) -> FeatureRef:
        if not _FEATURE_ID_RE.match(fid):
            raise Refused(f"{fid} isn't a feature id like F-003.")
        names = {path.name for path in (self.root / FEATURES_DIR).glob(f"{fid}-*.md")}
        for tracked in self.git.tracked_names(MAIN, FEATURES_DIR):
            if Path(tracked).name.startswith(f"{fid}-"):
                names.add(Path(tracked).name)
        if len(names) != 1:
            raise Refused(f"Expected one feature file for {fid}, found {sorted(names)}.")
        name = names.pop()
        return FeatureRef(fid, f"{FEATURES_DIR}/{name}", f"feature/{Path(name).stem}")

    def all_features(self) -> list[FeatureRef]:
        names = {path.name for path in (self.root / FEATURES_DIR).glob("F-*.md")}
        names |= {
            Path(tracked).name
            for tracked in self.git.tracked_names(MAIN, FEATURES_DIR)
            if Path(tracked).name.startswith("F-")
        }
        refs = []
        for name in sorted(names):
            fid = "-".join(name.split("-")[:2])
            refs.append(FeatureRef(fid, f"{FEATURES_DIR}/{name}", f"feature/{Path(name).stem}"))
        return refs

    def view(self, ref: FeatureRef) -> View:
        """The feature's real state: its branch tip once it has one, or the checkout."""
        current = self.git.current_branch()
        if current != ref.branch and self.git.branch_exists(ref.branch):
            return View(
                Feature(self.git.show(ref.branch, ref.path)), self.git.show(ref.branch, BOARD)
            )
        return View(self._load_worktree(ref), self._read(BOARD))

    def _load_worktree(self, ref: FeatureRef) -> Feature:
        target = self.root / ref.path
        if target.is_file():
            return Feature(target.read_text())
        return Feature(self.git.show(MAIN, ref.path))

    def _blocked_path(self, fid: str) -> Path:
        return self.state_dir / "blocked" / f"{fid}.json"

    def is_blocked(self, fid: str) -> bool:
        return self._blocked_path(fid).exists()

    def _refuse_if_blocked(self, ref: FeatureRef) -> None:
        if self.is_blocked(ref.fid):
            record = json.loads(self._blocked_path(ref.fid).read_text())
            raise Refused(
                f"{ref.fid} is blocked: {record.get('reason')}",
                record.get("recovery") or f"tools/studio unblock {ref.fid}",
            )

    def _require_clean(self, before_what: str) -> None:
        dirty = self.git.dirty_paths()
        if dirty:
            raise Refused(
                f"Tree isn't clean before {before_what}: {', '.join(dirty[:10])}", "git status"
            )

    def _log_path(self, ref: FeatureRef, role: str) -> Path:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        return self.state_dir / "logs" / ref.fid / f"{stamp}-{role}.log"

    def _relative(self, path: Path) -> str:
        return str(path.relative_to(self.root))

    def _set_state(
        self, ref: FeatureRef, status: str, owner: str, message: str, feature_text: str | None = None
    ) -> None:
        """A tool write: status, owner and board row, committed by explicit path (C16)."""
        text = feature_text if feature_text is not None else self._read(ref.path)
        self._write(ref.path, ft.set_state(text, status, owner, date.today().isoformat()))
        self._write(BOARD, ft.set_board_row(self._read(BOARD), ref.fid, status, owner))
        self.git.commit_paths([ref.path, BOARD], message)

    # --- Read-only commands ---

    def status_lines(self) -> list[str]:
        lines = []
        for ref in self.all_features():
            blocked = "BLOCKED" if self.is_blocked(ref.fid) else "ok"
            try:
                view = self.view(ref)
            except (FormatError, GitError) as error:
                lines.append(f"{ref.fid}  (unreadable: {error})  [{blocked}]")
                continue
            feature = view.feature
            problems = ft.consistency_errors(feature, view.board)
            flag = f"  MISMATCH: {'; '.join(problems)}" if problems else ""
            lines.append(
                f"{ref.fid}  {feature.title}  {feature.status}  {feature.owner}  [{blocked}]{flag}"
            )
        return lines

    def next_lines(self, fid: str) -> list[str]:
        ref = self.find(fid)
        feature = self.view(ref).feature
        blocked = self.is_blocked(fid)
        decision = decide(feature.status, feature.owner, blocked)
        state = f"{fid}: ({feature.status}, {feature.owner})"
        if decision.action:
            step = STEPS[decision.action]
            where = MAIN if decision.action in ("A", "B") else ref.branch
            return [
                f"{state} -> action {decision.action}: {step.title}, {step.agent}, on {where}",
                f"Next: tools/studio run {fid}",
            ]
        what, command = next_step(ref, feature, blocked)
        return [f"{state} -> stop: {decision.reason} ({what})", f"Next: {command}"]

    # --- run ---

    def run(
        self,
        fid: str,
        resume: bool = False,
        max_steps: int = DEFAULT_MAX_STEPS,
        timeout_minutes: float = proc.DEFAULT_TIMEOUT_MINUTES,
    ) -> int:
        ref = self.find(fid)
        with self.lock() as lock:
            try:
                return self._run_locked(ref, lock, resume, max_steps, timeout_minutes)
            except StepRejected as rejected:
                return rejected.exit_code
            except (Refused, FormatError, GitError) as error:
                message = error.message if isinstance(error, Refused) else str(error)
                command = error.next_command if isinstance(error, Refused) else "git status"
                notify.send(fid, f"stopped: {message}", command)
                return 1

    def _run_locked(
        self, ref: FeatureRef, lock: proc.Lock, resume: bool, max_steps: int, timeout: float
    ) -> int:
        self._refuse_if_blocked(ref)
        self._require_clean("run")  # F-002/C21
        if resume:
            self._prepare_resume(ref)
        steps = 0
        while True:
            view = self.view(ref)
            feature = view.feature
            problems = ft.consistency_errors(feature, view.board)  # F-002/C6
            if problems:
                raise Refused(f"state mismatch: {'; '.join(problems)}", f"open {ref.path}")
            decision = decide(feature.status, feature.owner, resume=resume)
            resume = False
            if decision.action is None:
                what, command = next_step(ref, feature, False)
                notify.send(ref.fid, what, command)
                return 0
            if self._audit_cap_reached(feature, decision.action):
                notify.send(
                    ref.fid,
                    f"{MAX_REVIEW_ROUNDS} review rounds used, no further audit runs",
                    f"open {ref.path}",
                )
                return 0
            self._enter_branch(ref, decision.action)
            if self._repair_cap_reached(feature, decision.action):
                self._escalate_round_cap(ref, decision.action)
                continue
            if decision.action == "D" and not self._readiness_passes(ref, lock, timeout):
                continue
            if steps >= max_steps:  # F-002/C10(c)
                notify.send(
                    ref.fid, f"stopped after {steps} agent steps", f"tools/studio run {ref.fid}"
                )
                return 0
            self._agent_step(ref, decision.action, lock, timeout)
            steps += 1

    def _prepare_resume(self, ref: FeatureRef) -> None:
        """F-002/C22."""
        if self.git.current_branch() != ref.branch:
            raise Refused(f"--resume runs on {ref.branch}.", f"git checkout {ref.branch}")
        feature = self._load_worktree(ref)
        if feature.status != "IN_PROGRESS":
            raise Refused(f"--resume continues IN_PROGRESS only, status is {feature.status}.")
        if feature.owner == "Builder":
            return
        if feature.owner != "Lucas":
            raise Refused(f"--resume needs owner Builder or Lucas, found {feature.owner}.")
        unanswered = feature.unanswered_blocking
        if unanswered:
            names = ", ".join(q.question_id for q in unanswered)
            raise Refused(f"Blocking §10 rows have no answer: {names}.", f"open {ref.path}")
        self._set_state(ref, "IN_PROGRESS", "Builder", f"{ref.fid}: resume, owner Builder")

    def _enter_branch(self, ref: FeatureRef, action: str) -> None:
        """F-002/C7: A and B run on main, C and D on the feature branch."""
        current = self.git.current_branch()
        if action in ("A", "B"):
            if current != MAIN:
                raise Refused(f"Action {action} runs on {MAIN}.", f"git checkout {MAIN}")
        elif current != ref.branch:
            if action == "D" and not self.git.branch_exists(ref.branch):
                raise Refused(f"{ref.branch} doesn't exist.", f"open {ref.path}")
            self.git.create_or_checkout(ref.branch)

    def _audit_cap_reached(self, feature: Feature, action: str) -> bool:
        """F-002/C10(a): max 3 completed rounds, so a 4th audit never starts. The state stays
        as it is: moving it to Lucas would claim a gate that no approving round backs."""
        rounds = {"A": feature.plan_rounds, "D": feature.code_rounds}.get(action, [])
        return len(rounds) >= MAX_REVIEW_ROUNDS

    def _repair_cap_reached(self, feature: Feature, action: str) -> bool:
        """F-002/C10(a): a 3rd CHANGES_REQUESTED goes to Lucas instead of being repaired."""
        rounds = {"B": feature.plan_rounds, "C": feature.code_rounds}.get(action, [])
        return (
            len(rounds) >= MAX_REVIEW_ROUNDS
            and feature.status in ("PLAN_CHANGES", "CODE_CHANGES")
            and rounds[-1].verdict == CHANGES_REQUESTED
        )

    def _escalate_round_cap(self, ref: FeatureRef, action: str) -> None:
        feature = self._load_worktree(ref)
        kind = "plan" if action in ("A", "B") else "code"
        question = f"{MAX_REVIEW_ROUNDS} {kind} review rounds used. How should this continue?"
        text = ft.append_question(feature.text, "Studio", question, True)
        self._set_state(
            ref, feature.status, "Lucas", f"{ref.fid}: escalate, {kind} round cap reached", text
        )

    # --- F-002/C14 readiness ---

    def _run_checks(
        self, ref: FeatureRef, lock: proc.Lock, timeout: float
    ) -> tuple[list[str], Path]:
        """Runs on a clean tree, so what is tested is exactly the committed revision."""
        self._require_clean("the readiness checks")
        log = self._log_path(ref, "checks")
        failed = []
        for script in CHECKS:
            result = proc.run_group(
                [str(self.root / script)],
                self.root,
                dict(os.environ),
                log,
                timeout,
                lock.set_agent,
            )
            if result.interrupted:
                raise proc.Interrupted()
            if not result.ok:
                failed.append(script)
        dirty = self.git.dirty_paths()
        if dirty:
            raise Refused(f"Checks left files changed: {', '.join(dirty[:10])}", "git status")
        return failed, log

    def _readiness_passes(self, ref: FeatureRef, lock: proc.Lock, timeout: float) -> bool:
        failed, log = self._run_checks(ref, lock, timeout)
        if not failed:
            return True
        feature = self._load_worktree(ref)
        number = feature.consecutive_readiness_failures + 1
        escalate = number >= MAX_READINESS_FAILURES
        sha = self.git.head()
        row = ft.readiness_row(
            number, sha, failed, self._relative(log), len(feature.code_rounds)
        )
        text = ft.append_question(feature.text, "Studio", row, escalate)
        owner = "Lucas" if escalate else "Builder"
        message = f"{ref.fid}: readiness failed at {sha[:7]} ({number})"
        self._set_state(ref, "CODE_CHANGES", owner, message, text)
        return False

    # --- Agent steps ---

    def _prompt(self, step: Step, ref: FeatureRef, feature: Feature) -> str:
        text = (PROMPTS_DIR / step.prompt).read_text().strip() + "\n"
        text = text.replace("{feature_path}", ref.path)
        if step.role == "planner":
            brief = f"{DEPARTMENTS_DIR}/{feature.department.split()[0].lower()}.md"
            if not (self.root / brief).is_file():
                raise Refused(f"No department brief at {brief}.", f"open {ref.path}")
            text = text.replace("{department}", feature.department).replace("{brief}", brief)
        return text

    def _agent_step(self, ref: FeatureRef, key: str, lock: proc.Lock, timeout: float) -> None:
        step = STEPS[key]
        self._require_clean(f"action {key}")  # F-002/C21
        before_text = self._read(ref.path)
        before_board = self._read(BOARD)
        before_decisions = self._read_optional(DECISIONS)
        before = Feature(before_text)
        prompt = self._prompt(step, ref, before)
        try:
            start = self.git.snapshot()
        except GitError as error:
            raise Refused(f"Can't record the remote before a step: {error}", "git ls-remote origin")
        log = self._log_path(ref, step.role)
        command = proc.agent_command(step.agent, step.role, prompt, self.root)
        result = proc.run_group(
            command, self.root, proc.agent_env(), log, timeout, lock.set_agent
        )
        inspection = self._inspect(ref, step, start, before, before_board, before_decisions)
        if not result.ok:
            inspection.errors.insert(0, f"agent failed: {result.describe()}")  # F-002/C15
        if inspection.errors:
            self._reject(ref, step, start, inspection, log, 130 if result.interrupted else 1)
        if step.role == "builder":
            return
        dirty = self.git.dirty_paths()
        if dirty:  # F-002/C16
            self.git.commit_paths(dirty, self._commit_message(ref, key))

    def _commit_message(self, ref: FeatureRef, key: str) -> str:
        feature = self._load_worktree(ref)
        if key == "A":
            return f"{ref.fid}: Auditor plan review round {len(feature.plan_rounds)}"
        if key == "D":
            return f"{ref.fid}: Auditor code review round {len(feature.code_rounds)}"
        department = feature.department.split()[0]
        return f"{ref.fid}: Planner revisions after round {len(feature.plan_rounds)} ({department})"

    def _inspect(
        self,
        ref: FeatureRef,
        step: Step,
        start: Snapshot,
        before: Feature,
        before_board: str,
        before_decisions: str | None,
    ) -> Inspection:
        """Everything checked after a step, before anything is committed or dispatched."""
        errors: list[str] = []
        remote_changes = self._remote_changes(start, errors)
        branch = self.git.current_branch()
        if branch != start.branch:
            errors.append(f"branch changed from {start.branch} to {branch} (C7)")
        head = self.git.head()
        if not self.git.is_ancestor(start.head, head):
            errors.append("history isn't a fast-forward of the start HEAD (C11)")
        refs_now = self.git.local_refs()
        own_ref = f"refs/heads/{start.branch}"
        others_before = {name: sha for name, sha in start.local_refs.items() if name != own_ref}
        others_now = {name: sha for name, sha in refs_now.items() if name != own_ref}
        if others_before != others_now or own_ref not in refs_now:
            errors.append("branches were created, moved or deleted (C7)")
        commits = self.git.new_commits(start.head)
        paths = self.git.changed_set(start.head)
        outside = [path for path in paths if not path_allowed(step.role, path, ref.path)]
        if outside:
            errors.append(f"outside the {step.role} lane: {', '.join(outside)} (C12)")
        errors.extend(self._file_errors(ref, step, start, before, before_board, before_decisions))
        if step.role == "builder":
            leftovers = self.git.dirty_paths()
            if leftovers:
                errors.append(f"uncommitted files after the build: {', '.join(leftovers)} (C21)")
        return Inspection(errors, commits, paths, remote_changes)

    def _file_errors(
        self,
        ref: FeatureRef,
        step: Step,
        start: Snapshot,
        before: Feature,
        before_board: str,
        before_decisions: str | None,
    ) -> list[str]:
        after_text = self._read_optional(ref.path)
        after_board = self._read_optional(BOARD)
        if after_text is None or after_board is None:
            return ["the feature file or STATUS.md is gone"]
        errors = ft.content_lane_errors(step.role, before.text, after_text)
        errors.extend(ft.board_lane_errors(ref.fid, before_board, after_board))
        if step.role == "planner" and before_decisions is not None:
            after_decisions = self._read_optional(DECISIONS) or ""
            errors.extend(ft.decisions_lane_errors(before_decisions, after_decisions))
        try:
            after = Feature(after_text)
        except FormatError:
            return errors  # Already reported by the content lanes.
        errors.extend(transition_errors(step.key, before, after, start.head))
        errors.extend(ft.consistency_errors(after, after_board))  # F-002/C6
        return errors

    def _remote_changes(
        self, start: Snapshot, errors: list[str]
    ) -> dict[str, tuple[str | None, str | None]]:
        """F-002/C3 backstop: explicit-URL pushes can only be detected, not prevented."""
        try:
            now = self.git.remote_refs()
        except GitError as error:
            errors.append(f"can't verify the remote after the step: {error}")
            return {}
        names = set(now) | set(start.remote_refs)
        changes = {
            name: (start.remote_refs.get(name), now.get(name))
            for name in sorted(names)
            if start.remote_refs.get(name) != now.get(name)
        }
        if changes:
            errors.append(f"the remote changed during the step: {', '.join(changes)} (C3)")
        return changes

    def _recovery(self, ref: FeatureRef, start: Snapshot, inspection: Inspection) -> str:
        parts = []
        for name, (old, _new) in inspection.remote_changes.items():
            if old:  # F-002/C3: the only case that needs a force-push by Lucas.
                parts.append(f"git push --force origin {old}:{name}")
            else:
                parts.append(f"git push origin --delete {name}")
        if self.git.current_branch() != start.branch and start.branch:
            parts.append(f"git checkout {start.branch}")
        if inspection.commits or inspection.paths:
            parts.append(f"git reset --hard {start.head}")
            parts.append("git clean -fd")
        parts.append(f"tools/studio unblock {ref.fid}")
        return " && ".join(parts)

    def _reject(
        self,
        ref: FeatureRef,
        step: Step,
        start: Snapshot,
        inspection: Inspection,
        log: Path,
        exit_code: int,
    ) -> None:
        """F-002/C11: nothing is committed or rewritten, the feature waits for Lucas."""
        recovery = self._recovery(ref, start, inspection)
        commits = [f"{commit.sha[:7]} {commit.subject}" for commit in inspection.commits]
        record = {
            "feature": ref.fid,
            "role": step.role,
            "reason": inspection.errors[0],
            "errors": inspection.errors,
            "commits": commits,
            "paths": inspection.paths,
            "remote_changes": {
                name: list(change) for name, change in inspection.remote_changes.items()
            },
            "start_head": start.head,
            "branch": start.branch,
            "log": self._relative(log),
            "recovery": recovery,
        }
        target = self._blocked_path(ref.fid)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(record, indent=2) + "\n")
        details = [f"step rejected ({step.role}): {'; '.join(inspection.errors)}"]
        if commits:
            details.append(f"commits: {', '.join(commits)}")
        if inspection.paths:
            details.append(f"paths: {', '.join(inspection.paths)}")
        details.append(f"log: {self._relative(log)}")
        notify.send(ref.fid, "\n".join(details), recovery)
        raise StepRejected(exit_code)

    # --- Commands with no agent ---

    def unblock(self, fid: str) -> list[str]:
        ref = self.find(fid)
        with self.lock():
            target = self._blocked_path(ref.fid)
            if not target.exists():
                return [f"{ref.fid} isn't blocked."]
            target.unlink()
            return [f"{ref.fid} unblocked.", f"Next: tools/studio next {ref.fid}"]

    def approve(self, fid: str, note: str | None = None) -> list[str]:
        """F-002/C17. Each step is skipped if done, so a rerun resumes."""
        ref = self.find(fid)
        with self.lock():
            self._refuse_if_blocked(ref)
            if self.git.current_branch() != MAIN:
                raise Refused(f"approve runs on {MAIN}.", f"git checkout {MAIN}")
            self._require_clean("approve")
            feature = self._load_worktree(ref)
            if feature.status == "APPROVED":
                self.git.fetch()
                if self.git.is_ancestor("HEAD", f"origin/{MAIN}"):
                    return [f"{ref.fid} is already approved.", f"Next: tools/studio run {ref.fid}"]
            else:
                self._gate_a(ref, feature, note)
            self.git.pull_rebase(MAIN)
            self.git.push(MAIN)
            return [f"{ref.fid} approved and pushed.", f"Next: tools/studio run {ref.fid}"]

    def _gate_a(self, ref: FeatureRef, feature: Feature, note: str | None) -> None:
        if (feature.status, feature.owner) != ("PLAN_REVIEW", "Lucas"):
            raise Refused(f"approve needs (PLAN_REVIEW, Lucas), found {feature.status}.")
        rounds = feature.plan_rounds
        if not rounds or rounds[-1].verdict not in APPROVING:
            raise Refused(f"The latest §7 round of {ref.fid} doesn't approve.", f"open {ref.path}")
        problems = ft.consistency_errors(feature, self._read(BOARD))
        if problems:
            raise Refused(f"state mismatch: {'; '.join(problems)}", f"open {ref.path}")
        text = feature.text
        if note:  # F-002/C2: only gates write §11.
            text = ft.add_director_note(text, note, "Gate A", date.today().isoformat())
        self._set_state(ref, "APPROVED", "Builder", f"Gate A: approve {ref.fid}", text)

    def done(self, fid: str, note: str | None = None) -> list[str]:
        """F-002/C18. Each step is skipped if done, so a rerun resumes."""
        ref = self.find(fid)
        with self.lock() as lock:
            self._refuse_if_blocked(ref)
            if self.git.is_merging():
                raise self._merge_conflict(ref)
            view = self.view(ref)
            if view.feature.status == "DONE":
                return self._publish(ref)
            self._gate_b_preconditions(ref, view)
            on_branch = self.git.current_branch() == ref.branch
            dirty = self.git.dirty_paths()
            if dirty and not on_branch:
                raise Refused(f"Tree isn't clean: {', '.join(dirty[:10])}", "git status")
            if not on_branch:
                self.git.checkout(ref.branch)
            if dirty:
                self._commit_review_edits(ref, dirty)
            failed, log = self._run_checks(ref, lock, proc.DEFAULT_TIMEOUT_MINUTES)
            if failed:
                raise Refused(
                    f"Checks failed: {', '.join(failed)}. Log: {self._relative(log)}", failed[0]
                )
            text = self._read(ref.path)
            if note:  # F-002/C2: only gates write §11.
                text = ft.add_director_note(text, note, "Gate B", date.today().isoformat())
            self._set_state(ref, "DONE", "Lucas", f"Gate B: {ref.fid} DONE", text)
            return self._publish(ref)

    def _gate_b_preconditions(self, ref: FeatureRef, view: View) -> None:
        feature = view.feature
        if (feature.status, feature.owner) != ("CODE_REVIEW", "Lucas"):
            raise Refused(f"done needs (CODE_REVIEW, Lucas), found {feature.status}.")
        if not self.git.branch_exists(ref.branch):
            raise Refused(f"{ref.branch} doesn't exist.", f"open {ref.path}")
        rounds = feature.code_rounds
        if not rounds or rounds[-1].verdict not in APPROVING:
            raise Refused(f"The latest §9 round of {ref.fid} doesn't approve.", f"open {ref.path}")
        problems = ft.consistency_errors(feature, view.board)
        if problems:
            raise Refused(f"state mismatch: {'; '.join(problems)}", f"open {ref.path}")
        self._require_reviewed_head(ref, feature)

    def _require_reviewed_head(self, ref: FeatureRef, feature: Feature) -> None:
        """Only metadata commits may follow the reviewed commit (F-002/C18)."""
        head = self.git.head(ref.branch)
        reviewed = feature.reviewed_commit
        if not reviewed:
            raise Refused("The latest §9 round has no Reviewed commit.", f"open {ref.path}")
        try:
            full = self.git.head(reviewed)
        except GitError:
            raise Refused(f"Reviewed commit {reviewed} doesn't exist.", f"open {ref.path}")
        if not self.git.is_ancestor(full, head):
            raise Refused(f"Reviewed commit {reviewed} isn't on {ref.branch}.", f"open {ref.path}")
        extra = set(self.git.committed_paths(full, head)) - {ref.path, BOARD}
        if extra:
            raise Refused(
                f"Code changed after the review: {', '.join(sorted(extra)[:10])}. "
                "It needs a new review.",
                f"open {ref.path}",
            )

    def _commit_review_edits(self, ref: FeatureRef, dirty: list[str]) -> None:
        """F-002/C18's one exception: the Auditor's uncommitted, lane-valid edits."""
        outside = [path for path in dirty if not path_allowed("auditor-code", path, ref.path)]
        if outside:
            raise Refused(
                f"Only the Auditor's edits may be uncommitted, found {', '.join(outside)}.",
                "git status",
            )
        before = self.git.show("HEAD", ref.path)
        errors = ft.content_lane_errors("auditor-code", before, self._read(ref.path))
        errors += ft.board_lane_errors(ref.fid, self.git.show("HEAD", BOARD), self._read(BOARD))
        if errors:
            raise Refused(f"Review edits break the lanes: {'; '.join(errors)}", "git status")
        rounds = len(self._load_worktree(ref).code_rounds)
        self.git.commit_paths(dirty, f"{ref.fid}: Auditor code review round {rounds}")

    def _merge_conflict(self, ref: FeatureRef) -> Refused:
        files = ", ".join(self.git.conflicted_paths()) or "unknown"
        return Refused(
            f"Merge conflict in: {files}. Abort it, fix {MAIN}, then rerun tools/studio done "
            f"{ref.fid}.",
            "git merge --abort",
        )

    def _publish(self, ref: FeatureRef) -> list[str]:
        """Steps 3–7. Branches go only after origin/main is verified to hold the work."""
        branch = ref.branch
        local = self.git.branch_exists(branch)
        remote_sha = self.git.remote_branch_sha(branch)
        if not local and not remote_sha:
            return [f"{ref.fid} is done."]
        self._require_clean("publishing")
        head = self.git.head(branch) if local else remote_sha
        if local and remote_sha != head:
            self.git.push(branch)
        if self.git.current_branch() != MAIN:
            self.git.checkout(MAIN)
        self.git.fetch()
        origin_main = f"origin/{MAIN}"
        diverged = not (
            self.git.is_ancestor(origin_main, MAIN) or self.git.is_ancestor(MAIN, origin_main)
        )
        if self.git.is_ancestor(head, MAIN) and diverged:
            # A rerun with an unpushed merge: rebasing would replay the feature's commits.
            if not self.git.merge_no_ff(origin_main, f"Merge {origin_main}"):
                raise self._merge_conflict(ref)
        else:
            self.git.pull_rebase(MAIN)
        if not self.git.is_ancestor(head, MAIN):
            title = self._load_worktree(ref).title
            if not self.git.merge_no_ff(branch, f"Merge {ref.fid}: {title}"):
                raise self._merge_conflict(ref)
        self.git.push(MAIN)
        self.git.fetch()
        if not self.git.is_ancestor(head, f"origin/{MAIN}"):
            raise Refused(f"origin/{MAIN} doesn't contain {head[:7]}.", f"tools/studio done {ref.fid}")
        if self.git.remote_branch_sha(branch):
            self.git.delete_remote_branch(branch)
        if self.git.branch_exists(branch):
            self.git.delete_local_branch(branch)
        return [f"{ref.fid} is done: merged, pushed, branches deleted."]
