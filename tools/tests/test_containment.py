"""AC9, AC9b, AC9c, AC10: child pushes, failures, resume and the lock."""

import json
import os
import signal
import subprocess
import sys
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from helpers import (
    BOARD,
    BRANCH,
    FEATURE,
    TOOL,
    TOOLS_DIR,
    Sandbox,
    auditor_code,
    auditor_plan,
    builder_escalates,
    builder_ok,
)
from studio_lib import engine, proc


CONTENDER = """
import sys, time
from pathlib import Path
sys.path.insert(0, {tools!r})
from studio_lib import proc

fake = Path({fake!r})
name = {name!r}

def wait(path):
    while not path.exists():
        time.sleep(0.01)

if {pause}:
    real_read = proc.Lock._read
    def paused_read(self):
        record = real_read(self)
        (fake / (name + ".paused")).write_text("")
        wait(fake / (name + ".go"))
        return record
    proc.Lock._read = paused_read

try:
    with proc.Lock(Path({lock!r})):
        (fake / (name + ".done")).write_text("entered")
        proc.Lock._read = real_read if {pause} else proc.Lock._read
        wait(fake / "release")
except proc.LockHeld:
    (fake / (name + ".done")).write_text("refused")
"""


def dead_pid():
    process = subprocess.Popen([sys.executable, "-c", "pass"])
    process.wait()
    return process.pid


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


class ChildPushTests(unittest.TestCase):
    """AC9b."""

    def test_git_push_fails_inside_an_agent(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.git("checkout", "-q", "-b", BRANCH)
            before = box.remote_git("for-each-ref")
            box.script([["git_try", "push", "origin", BRANCH], *builder_ok()], auditor_code())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout)
            output = json.loads((box.fake_dir / "out-0.json").read_text())
            self.assertNotEqual(output["git_try"], 0, "the push must fail")
            self.assertEqual(box.remote_git("for-each-ref"), before)
            self.assertFalse(box.is_blocked())

    def test_every_call_runs_with_the_push_guards(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.script(builder_ok(), auditor_code())
            box.studio("run", "F-900")
            for call in box.calls():
                self.assertIn("cannot-push", call["pushurl"])
                self.assertEqual(call["terminal_prompt"], "0")

    def test_a_push_to_an_explicit_url_is_detected_and_blocked(self):
        with Sandbox("APPROVED", "Builder") as box:
            url = str(box.remote)
            box.script([*builder_ok(), ["git", "push", url, "HEAD:refs/heads/rogue"]], auditor_code())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertTrue(box.is_blocked())
            self.assertEqual(len(box.calls()), 1)
            self.assertIn("refs/heads/rogue", box.blocked_record()["remote_changes"])
            self.assertIn("git push origin --delete refs/heads/rogue", box.notifications()[0])

    def test_a_moved_remote_branch_gets_the_force_push_recovery(self):
        with Sandbox("APPROVED", "Builder") as box:
            old = box.git("rev-parse", "main")
            url = str(box.remote)
            box.git("checkout", "-q", "-b", BRANCH)
            step = [*builder_ok(), ["git", "push", url, "HEAD:refs/heads/main"]]
            box.script(step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertIn(f"git push --force origin {old}:refs/heads/main", box.notifications()[0])

    def test_builder_cli_denies_push_and_branch_moves(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.script(builder_ok(), auditor_code())
            box.studio("run", "F-900")
            builder, auditor = box.calls()
            self.assertIn("--disallowedTools", builder["argv"])
            self.assertIn("Bash(git push *)", builder["argv"])
            self.assertIn("dontAsk", builder["argv"])
            self.assertIn("workspace-write", auditor["argv"])
            self.assertIn("sandbox_workspace_write.network_access=false", auditor["argv"])

    def test_planner_has_no_shell(self):
        command = proc.agent_command("claude", "planner", "x", Path("/tmp"))
        tools = command[command.index("--tools") + 1]
        self.assertNotIn("Bash", tools)


class RecoveryEvidenceTests(unittest.TestCase):
    """CR-4, AC9b: the recovery is built on evidence that a broken validation can't lose, and
    unknown never reads as unchanged. Each test runs the printed recovery for real."""

    REMOTE_RECORD = ".studio/blocked/F-900.remote"

    def on_branch(self, box):
        box.git("checkout", "-q", "-b", BRANCH)
        return box.git("rev-parse", "HEAD")

    def unreadable_output(self, box):
        bad = box.fake_dir / "bad"
        bad.write_bytes(b"\xff\xfe not text")
        return ["copy", str(bad), BOARD]

    def rogue_push(self, box, target):
        return ["git", "push", str(box.remote), f"HEAD:{target}"]

    def unreachable(self):
        return ["git", "remote", "set-url", "origin", "/nonexistent/remote.git"]

    def reconnect(self, box):
        box.git("remote", "set-url", "origin", str(box.remote))

    def recover(self, box):
        command = box.blocked_record()["recovery"].replace(
            "tools/studio", f"{sys.executable} {TOOL}"
        )
        return subprocess.run(
            ["sh", "-c", command], cwd=box.repo, env=box.env, capture_output=True, text=True
        )

    def assert_recovered(self, box, start):
        result = self.recover(box)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(box.is_blocked())
        self.assertEqual(box.git("rev-parse", "HEAD"), start)
        self.assertEqual(box.git("symbolic-ref", "--short", "HEAD"), BRANCH)
        self.assertEqual(box.dirty(), "")

    def test_a_new_remote_ref_survives_a_validation_failure(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            target = "refs/heads/rogue"
            box.script([*builder_ok(), self.rogue_push(box, target), self.unreadable_output(box)])
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stderr)
            new = box.remote_git("rev-parse", target)
            record = box.blocked_record()
            self.assertEqual(record["remote_changes"], {target: [None, new]})
            self.assertTrue(record["remote_verified"])
            errors = " ".join(record["errors"])
            self.assertIn("the remote changed during the step", errors)
            self.assertIn("can't validate the step", errors)
            self.assertIn(f"git push origin --delete {target}", record["recovery"])
            self.assertEqual(len(box.notifications()), 1)
            self.assertIn(f"{target} new -> {new}", box.notifications()[0])
            self.assertIn(record["recovery"], box.notifications()[0])
            self.assert_recovered(box, start)
            self.assertEqual(box.remote_git("for-each-ref", target), "")

    def test_an_advanced_remote_ref_survives_a_validation_failure(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            target = "refs/heads/main"
            box.script([*builder_ok(), self.rogue_push(box, target), self.unreadable_output(box)])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            new = box.remote_git("rev-parse", target)
            record = box.blocked_record()
            self.assertEqual(record["remote_changes"], {target: [start, new]})
            self.assertIn(f"git push --force origin {start}:{target}", record["recovery"])
            self.assertIn(f"{target} {start} -> {new}", box.notifications()[0])
            self.assert_recovered(box, start)
            self.assertEqual(box.remote_git("rev-parse", target), start)

    def test_an_annotated_tag_gets_one_repair(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            step = [
                *builder_ok(),
                ["git", "tag", "-a", "rogue", "-m", "rogue"],
                ["git", "push", str(box.remote), "refs/tags/rogue"],
            ]
            box.script(step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertEqual(list(box.blocked_record()["remote_changes"]), ["refs/tags/rogue"])
            self.assert_recovered(box, start)
            self.assertEqual(box.remote_git("for-each-ref", "refs/tags"), "")

    def test_a_failed_agent_keeps_the_remote_evidence(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            target = "refs/heads/rogue"
            box.script(
                [
                    *builder_ok(),
                    self.rogue_push(box, target),
                    self.unreadable_output(box),
                    ["exit", 7],
                ]
            )
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            record = box.blocked_record()
            self.assertIn("exit code 7", record["reason"])
            self.assertIn(target, record["remote_changes"])
            self.assert_recovered(box, start)

    def test_a_validation_failure_keeps_the_errors_found_before_it(self):
        with Sandbox("APPROVED", "Builder") as box:
            self.on_branch(box)
            step = [
                ["write", "AGENTS.md", "# changed\n"],
                ["git", "add", "--", "AGENTS.md"],
                ["git", "commit", "-m", "outside the lane"],
                self.unreadable_output(box),
            ]
            box.script(step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            errors = " ".join(box.blocked_record()["errors"])
            self.assertIn("outside the builder lane: AGENTS.md", errors)
            self.assertIn("can't validate the step", errors)

    def test_an_unreachable_remote_is_never_reported_as_unchanged(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            refs = box.git("ls-remote", "--refs", "origin")
            box.script([*builder_ok(), self.unreachable()])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            built = box.git("rev-parse", "HEAD")
            record = box.blocked_record()
            self.assertFalse(record["remote_verified"])
            self.assertEqual(record["remote_changes"], {})
            self.assertIn("can't verify the remote", record["reason"])
            self.assertTrue(
                record["recovery"].startswith(
                    f"git ls-remote --refs origin | diff {self.REMOTE_RECORD} -"
                )
            )
            self.assertEqual(box.read(self.REMOTE_RECORD).strip(), refs)
            self.assertIn("not verified", box.notifications()[0])

            self.assertNotEqual(self.recover(box).returncode, 0, "still unreachable")
            self.assertTrue(box.is_blocked())
            self.assertEqual(box.git("rev-parse", "HEAD"), built, "nothing discarded")

            self.reconnect(box)
            self.assert_recovered(box, start)
            self.assertFalse((box.repo / self.REMOTE_RECORD).exists())

    def test_a_remote_that_moved_unseen_stops_the_recovery(self):
        with Sandbox("APPROVED", "Builder") as box:
            self.on_branch(box)
            target = "refs/heads/rogue"
            box.script([*builder_ok(), self.rogue_push(box, target), self.unreachable()])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            built = box.git("rev-parse", "HEAD")
            self.reconnect(box)
            result = self.recover(box)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(target, result.stdout)
            self.assertTrue(box.is_blocked())
            self.assertEqual(box.git("rev-parse", "HEAD"), built, "nothing discarded")

    def test_an_unreachable_remote_and_a_validation_failure_both_report(self):
        with Sandbox("APPROVED", "Builder") as box:
            self.on_branch(box)
            box.script([*builder_ok(), self.unreachable(), self.unreadable_output(box)])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            record = box.blocked_record()
            errors = " ".join(record["errors"])
            self.assertIn("can't verify the remote", errors)
            self.assertIn("can't validate the step", errors)
            self.assertFalse(record["remote_verified"])

    def test_unreadable_git_state_assumes_the_worst(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            box.script([*builder_ok(), ["write", ".git/HEAD", "garbage\n"]])
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            record = box.blocked_record()
            self.assertFalse(record["remote_verified"])
            self.assertIn(f"git reset --hard {start}", record["recovery"])
            self.assertEqual(len(box.notifications()), 1)

    def test_evidence_that_raises_anything_is_still_unknown(self):
        with Sandbox("APPROVED", "Builder") as box:
            studio = engine.Studio(box.repo)
            start = studio.git.snapshot()
            with (
                patch.object(studio.git, "remote_refs", side_effect=ValueError("odd line")),
                patch.object(studio.git, "local_refs", side_effect=OSError("gone")),
            ):
                inspection = studio._evidence(start)
            self.assertFalse(inspection.remote_verified)
            self.assertTrue(inspection.reset_needed)
            self.assertEqual(len(inspection.errors), 2)

    def test_a_rewound_head_gets_the_reset(self):
        with Sandbox("APPROVED", "Builder") as box:
            self.on_branch(box)
            box.write("src/old.txt", "old\n")
            start = box.commit_all("existing work", "src/old.txt")
            box.script([["git", "reset", "-q", "--hard", "HEAD~1"]])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertIn(f"git reset --hard {start}", box.blocked_record()["recovery"])
            self.assert_recovered(box, start)

    def test_a_moved_local_main_is_restored(self):
        """A gate pushes local main, so a rejected step can't leave it moved."""
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            box.script([*builder_ok(), ["git", "update-ref", "refs/heads/main", "HEAD"]])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            record = box.blocked_record()
            self.assertEqual(record["local_ref_changes"], {"refs/heads/main": start})
            self.assertIn("refs/heads/main", record["reason"])
            self.assert_recovered(box, start)
            self.assertEqual(box.git("rev-parse", "main"), start)

    def test_a_moved_local_main_survives_a_validation_failure(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            step = [
                *builder_ok(),
                ["git", "update-ref", "refs/heads/main", "HEAD"],
                self.unreadable_output(box),
            ]
            box.script(step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assert_recovered(box, start)
            self.assertEqual(box.git("rev-parse", "main"), start)

    def test_a_branch_the_agent_created_and_stayed_on_is_removed(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            box.script([["git", "checkout", "-q", "-b", "side"], *builder_ok()])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assert_recovered(box, start)
            self.assertEqual(box.git("branch", "--list", "side"), "")

    def test_a_commit_on_main_after_switching_to_it_is_undone(self):
        with Sandbox("APPROVED", "Builder") as box:
            main = self.on_branch(box)
            box.write("src/new.txt", "the feature's version\n")
            start = box.commit_all("existing work", "src/new.txt")
            box.script([["git", "checkout", "-q", "main"], *builder_ok()])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assert_recovered(box, start)
            self.assertEqual(box.git("rev-parse", "main"), main)

    def test_a_deleted_feature_branch_is_restored(self):
        with Sandbox("APPROVED", "Builder") as box:
            start = self.on_branch(box)
            box.script([["git", "checkout", "-q", "--detach"], ["git", "branch", "-D", BRANCH]])
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assert_recovered(box, start)


class KeepAwakeTests(unittest.TestCase):
    """F-002 §1: walking away must not put the Mac to sleep under a step."""

    def fake_caffeinate(self, box):
        fake = box.bin_dir / "caffeinate"
        fake.write_text(f'#!/bin/sh\necho "$$ $*" > "{box.fake_dir}/caffeinate"\nexec sleep 30\n')
        fake.chmod(0o755)

    def test_run_holds_the_assertion_and_releases_it(self):
        with Sandbox("DRAFT", "Planner") as box:
            self.fake_caffeinate(box)
            self.assertEqual(box.studio("run", "F-900").returncode, 0)
            deadline = time.monotonic() + 5
            while not (box.fake_dir / "caffeinate").exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            pid, *args = (box.fake_dir / "caffeinate").read_text().split()
            self.assertEqual(args[:2], ["-i", "-w"])
            self.assertFalse(alive(int(pid)))

    def test_a_machine_without_caffeinate_still_runs(self):
        with Sandbox("DRAFT", "Planner") as box:
            box.env["PATH"] = f"{box.bin_dir}:/nonexistent"
            box.env["PATH"] += ":/usr/local/bin:/opt/homebrew/bin"
            self.assertEqual(box.studio("run", "F-900").returncode, 0)


class FixtureTests(unittest.TestCase):
    def test_the_sandbox_ignores_the_push_guard_of_an_agent_session(self):
        guard = {key: value for key, value in proc.agent_env().items() if key.startswith("GIT_")}
        with patch.dict(os.environ, guard), Sandbox() as box:
            self.assertEqual(box.git("rev-parse", "HEAD"), box.remote_git("rev-parse", "main"))


class AgentFailureTests(unittest.TestCase):
    """AC9."""

    def assert_failed_step(self, box, commits):
        self.assertEqual(box.commit_count(), commits, "no commit")
        self.assertEqual(len(box.calls()), 1, "no dispatch")
        self.assertTrue(box.is_blocked())
        self.assertFalse(box.lock_exists())
        log = box.repo / box.blocked_record()["log"]
        self.assertTrue(log.is_file(), "log kept")
        self.assertIn(box.blocked_record()["log"], box.notifications()[0])

    def test_non_zero_exit_after_a_valid_looking_edit(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([*auditor_plan(1, "APPROVE"), ["exit", 3]])
            commits = box.commit_count()
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assert_failed_step(box, commits)
            self.assertIn("exit code 3", box.blocked_record()["reason"])
            self.assertIn("PLAN_REVIEW", box.read(FEATURE), "edits kept")
            self.assertNotEqual(box.dirty(), "", "edits kept, uncommitted")

    def malformed_board_step(self):
        return [
            *auditor_plan(1, "APPROVE"),
            ["replace", BOARD, "| F-900 | Demo feature | PLAN_REVIEW | Lucas | — |", "| F-900 | truncated |"],
        ]

    def assert_malformed_output_rejected(self, box, commits):
        self.assertEqual(box.commit_count(), commits, "no commit")
        self.assertEqual(len(box.calls()), 1, "no next agent")
        self.assertTrue(box.is_blocked())
        self.assertEqual(len(box.notifications()), 1)
        self.assertFalse(box.lock_exists())
        self.assertTrue((box.repo / box.blocked_record()["log"]).is_file(), "log kept")
        self.assertIn("truncated", box.read(BOARD), "edits kept")

    def test_a_truncated_board_row_is_rejected_after_a_clean_exit(self):
        """CR-3."""
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script(self.malformed_board_step(), auditor_plan(2))
            commits = box.commit_count()
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assert_malformed_output_rejected(box, commits)

    def test_a_truncated_board_row_is_rejected_after_a_failed_exit(self):
        """CR-3: the failure must reach Lucas whichever problem is seen first."""
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([*self.malformed_board_step(), ["exit", 7]], auditor_plan(2))
            commits = box.commit_count()
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assert_malformed_output_rejected(box, commits)
            self.assertIn("exit code 7", box.blocked_record()["reason"])

    def test_a_board_with_no_table_is_rejected(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([*auditor_plan(1, "APPROVE"), ["write", BOARD, "gone\n"]], auditor_plan(2))
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assertTrue(box.is_blocked())

    def test_undecodable_output_is_rejected_not_a_crash(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            bad = box.fake_dir / "bad"
            bad.write_bytes(b"\xff\xfe not text")
            box.script([["copy", str(bad), BOARD]], auditor_plan(2))
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assertTrue(box.is_blocked())
            self.assertEqual(len(box.notifications()), 1)

    def test_an_unreadable_feature_stops_run_with_a_notification(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            (box.repo / FEATURE).write_bytes(b"---\nid: F-900\n\xff\n---\n")
            box.commit_all("broken feature", FEATURE)
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assertEqual(len(box.notifications()), 1)
            self.assertEqual(box.calls(), [])
            self.assertFalse(box.lock_exists())
            for command in (("status",), ("next", "F-900")):
                self.assertNotIn("Traceback", box.studio(*command).stderr, command)

    def test_a_corrupt_blocked_marker_still_refuses(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            (box.repo / ".studio/blocked").mkdir(parents=True)
            (box.repo / ".studio/blocked/F-900.json").write_text("{not json")
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("Traceback", result.stderr)
            self.assertEqual(box.calls(), [])
            self.assertIn("unreadable marker", box.notifications()[0])
            self.assertIn("tools/studio unblock F-900", box.notifications()[0])

    def test_launch_failure_blocks(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.env["STUDIO_CODEX_BIN"] = str(box.base / "does-not-exist")
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertTrue(box.is_blocked())
            self.assertIn("could not start", box.blocked_record()["reason"])
            self.assertFalse(box.lock_exists())

    def test_hang_past_the_timeout_kills_the_group(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([["spawn_child"], ["sleep", 60]])
            commits = box.commit_count()
            result = box.studio("run", "F-900", "--timeout", "0.02")
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assert_failed_step(box, commits)
            self.assertIn("timed out", box.blocked_record()["reason"])
            self.assertFalse(alive(box.calls()[0]["pid"]))
            child = json.loads((box.fake_dir / "out-0.json").read_text())["child_pid"]
            self.assertFalse(alive(child), "the whole group is gone")

    def test_a_child_that_ignores_sigterm_gets_sigkill(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([["ignore_term"], ["sleep", 60]])
            result = box.studio("run", "F-900", "--timeout", "0.02")
            self.assertEqual(result.returncode, 1)
            self.assertFalse(alive(box.calls()[0]["pid"]))
            self.assertFalse(box.lock_exists())

    def test_interrupting_the_tool_stops_the_group(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([["spawn_child"], ["sleep", 60]])
            commits = box.commit_count()
            process = box.start_studio("run", "F-900")
            box.wait_for_call()
            time.sleep(0.3)
            process.send_signal(signal.SIGINT)
            process.communicate(timeout=15)
            self.assertEqual(process.returncode, 130)
            self.assert_failed_step(box, commits)
            self.assertIn("interrupted", box.blocked_record()["reason"])
            self.assertFalse(alive(box.calls()[0]["pid"]))
            child = json.loads((box.fake_dir / "out-0.json").read_text())["child_pid"]
            self.assertFalse(alive(child))

    def test_a_finished_agent_leaves_nothing_running(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([["spawn_child"], *auditor_plan(1, "APPROVE")])
            self.assertEqual(box.studio("run", "F-900").returncode, 0)
            child = json.loads((box.fake_dir / "out-0.json").read_text())["child_pid"]
            self.assertFalse(alive(child))

    def test_a_blocked_feature_refuses_every_mutating_command(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([["exit", 1]])
            box.studio("run", "F-900")
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertEqual(box.studio("approve", "F-900").returncode, 1)
            self.assertEqual(box.studio("done", "F-900").returncode, 1)
            self.assertEqual(len(box.calls()), 1)


class ResumeTests(unittest.TestCase):
    """AC9c."""

    def escalated(self, box):
        box.script(builder_escalates(), builder_ok(), auditor_code())
        box.studio("run", "F-900")
        self.assertEqual(box.state(), ("IN_PROGRESS", "Lucas"))

    def answer(self, box):
        box.write(FEATURE, box.read(FEATURE).replace("| Which way? | yes | |", "| Which way? | yes | Left. |"))
        box.commit_all("answer", FEATURE)

    def test_plain_run_stops(self):
        with Sandbox("APPROVED", "Builder") as box:
            self.escalated(box)
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0)
            self.assertEqual(len(box.calls()), 1)
            self.assertIn("tools/studio run --resume F-900", box.notifications()[-1])

    def test_an_answered_row_resumes_the_builder(self):
        with Sandbox("APPROVED", "Builder") as box:
            self.escalated(box)
            self.answer(box)
            result = box.studio("run", "--resume", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(box.roles(), ["Builder", "Builder", "Auditor:ModeB"])
            self.assertEqual(box.state(), ("CODE_REVIEW", "Lucas"))
            subjects = box.git("log", "--format=%s")
            self.assertIn("F-900: resume, owner Builder", subjects)

    def test_an_unanswered_blocking_row_refuses(self):
        with Sandbox("APPROVED", "Builder") as box:
            self.escalated(box)
            result = box.studio("run", "--resume", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("Q2", box.notifications()[-1])
            self.assertEqual(len(box.calls()), 1)
            self.assertEqual(box.state(), ("IN_PROGRESS", "Lucas"))

    def test_crash_recovery_with_owner_builder(self):
        with Sandbox("IN_PROGRESS", "Builder") as box:
            box.checkout_feature_branch()
            commits = box.commit_count()
            box.script(builder_ok("src/rest.txt"), auditor_code())
            result = box.studio("run", "--resume", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(box.commit_count(), commits + 2, "no resume commit needed")

    def test_resume_needs_the_feature_branch(self):
        with Sandbox("IN_PROGRESS", "Builder") as box:
            self.assertEqual(box.studio("run", "--resume", "F-900").returncode, 1)
            self.assertEqual(box.calls(), [])

    def test_resume_needs_a_clean_tree(self):
        with Sandbox("IN_PROGRESS", "Builder") as box:
            box.checkout_feature_branch()
            box.write("src/dirty.txt", "x\n")
            self.assertEqual(box.studio("run", "--resume", "F-900").returncode, 1)
            self.assertEqual(box.calls(), [])

    def test_resume_refuses_other_statuses(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.git("checkout", "-q", "-b", BRANCH)
            self.assertEqual(box.studio("run", "--resume", "F-900").returncode, 1)
            self.assertEqual(box.calls(), [])

    def test_a_resumed_step_has_the_outputs_of_action_c(self):
        with Sandbox("IN_PROGRESS", "Builder") as box:
            box.checkout_feature_branch()
            box.script([["state", "APPROVED", "Builder"], ["git", "add", "--", FEATURE, BOARD], ["git", "commit", "-m", "x"]])
            self.assertEqual(box.studio("run", "--resume", "F-900").returncode, 1)
            self.assertTrue(box.is_blocked())


class LockTests(unittest.TestCase):
    """AC10."""

    def write_lock(self, box, tool_pid, agent_pgid=None):
        (box.repo / ".studio").mkdir(exist_ok=True)
        record = {"tool_pid": tool_pid, "agent_pgid": agent_pgid}
        (box.repo / ".studio/lock").write_text(json.dumps(record))

    def test_run_excludes_every_mutating_command_but_not_readers(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([["sleep", 60]])
            process = box.start_studio("run", "F-900")
            try:
                box.wait_for_call()
                for command in (("run", "F-900"), ("approve", "F-900"), ("done", "F-900"), ("unblock", "F-900")):
                    result = box.studio(*command)
                    self.assertEqual(result.returncode, 1, command)
                    self.assertIn("refused", result.stderr, command)
                for command in (("status",), ("next", "F-900"), ("notify-test",)):
                    self.assertEqual(box.studio(*command).returncode, 0, command)
                self.assertEqual(len(box.calls()), 1)
            finally:
                process.send_signal(signal.SIGINT)
                process.communicate(timeout=15)
            self.assertFalse(box.lock_exists())

    def test_lock_records_the_tool_and_the_agent_group(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script([["sleep", 60]])
            process = box.start_studio("run", "F-900")
            try:
                box.wait_for_call()
                deadline = time.monotonic() + 5
                record = {}
                while time.monotonic() < deadline and not record.get("agent_pgid"):
                    record = json.loads((box.repo / ".studio/lock").read_text())
                self.assertEqual(record["tool_pid"], process.pid)
                self.assertEqual(record["agent_pgid"], box.calls()[0]["pid"])
            finally:
                process.send_signal(signal.SIGINT)
                process.communicate(timeout=15)

    def test_gates_exclude_each_other(self):
        with Sandbox() as box:
            box.prepare_gate_b()
            self.write_lock(box, os.getpid())
            self.assertEqual(box.studio("done", "F-900").returncode, 1)
            self.assertEqual(box.studio("approve", "F-900").returncode, 1)
            self.assertEqual(box.state(), ("CODE_REVIEW", "Lucas"))

    def test_stale_lock_is_cleared_with_a_warning(self):
        with Sandbox("DRAFT", "Planner") as box:
            self.write_lock(box, dead_pid())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("stale lock", result.stderr)
            self.assertFalse(box.lock_exists())

    def test_a_live_agent_group_keeps_a_dead_tools_lock(self):
        with Sandbox("DRAFT", "Planner") as box:
            agent = subprocess.Popen(
                [sys.executable, "-c", "import time; time.sleep(30)"], start_new_session=True
            )
            try:
                self.write_lock(box, dead_pid(), agent.pid)
                self.assertEqual(box.studio("run", "F-900").returncode, 1)
            finally:
                agent.kill()
                agent.wait()

    def test_two_contenders_at_a_stale_lock_never_both_enter(self):
        """CR-2: A pauses right after reading the stale record, while B contends."""
        with Sandbox("DRAFT", "Planner") as box:
            self.write_lock(box, dead_pid())
            lock_path = box.repo / ".studio/lock"
            first = self.start_contender(box, lock_path, "a", pause_after_read=True)
            self.wait_for(box.fake_dir / "a.paused")
            second = self.start_contender(box, lock_path, "b", pause_after_read=False)
            time.sleep(0.5)  # B gets every chance to run while A sits on its stale read.
            (box.fake_dir / "a.go").write_text("")
            self.wait_for(box.fake_dir / "a.done")
            self.wait_for(box.fake_dir / "b.done")
            outcomes = {
                name: (box.fake_dir / f"{name}.done").read_text() for name in ("a", "b")
            }
            self.assertEqual(sorted(outcomes.values()), ["entered", "refused"], outcomes)
            winner = "a" if outcomes["a"] == "entered" else "b"
            record = json.loads(lock_path.read_text())
            expected = first.pid if winner == "a" else second.pid
            self.assertEqual(record["tool_pid"], expected, "the live owner's lock survives")
            (box.fake_dir / "release").write_text("")
            for process in (first, second):
                process.communicate(timeout=15)
            self.assertFalse(box.lock_exists())

    def wait_for(self, path, seconds=10.0):
        deadline = time.monotonic() + seconds
        while not path.exists():
            if time.monotonic() > deadline:
                raise AssertionError(f"{path.name} never appeared")
            time.sleep(0.02)

    def start_contender(self, box, lock_path, name, pause_after_read):
        """A real second process: `python -c` with the Lock from the tool under test."""
        script = CONTENDER.format(
            tools=str(TOOLS_DIR),
            lock=str(lock_path),
            fake=str(box.fake_dir),
            name=name,
            pause=pause_after_read,
        )
        process = subprocess.Popen([sys.executable, "-c", script], stderr=subprocess.DEVNULL)
        self.addCleanup(process.wait)
        self.addCleanup(process.kill)
        return process

    def test_a_refused_command_leaves_the_other_lock_alone(self):
        with Sandbox("DRAFT", "Planner") as box:
            self.write_lock(box, os.getpid())
            box.studio("run", "F-900")
            self.assertTrue(box.lock_exists())


if __name__ == "__main__":
    unittest.main()
