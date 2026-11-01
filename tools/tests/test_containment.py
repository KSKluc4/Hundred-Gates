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
    Sandbox,
    auditor_code,
    auditor_plan,
    builder_escalates,
    builder_ok,
)
from studio_lib import proc


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

    def test_a_refused_command_leaves_the_other_lock_alone(self):
        with Sandbox("DRAFT", "Planner") as box:
            self.write_lock(box, os.getpid())
            box.studio("run", "F-900")
            self.assertTrue(box.lock_exists())


if __name__ == "__main__":
    unittest.main()
