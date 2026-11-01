"""AC2–AC5: the happy paths, and every way an agent step can be rejected."""

import unittest

from helpers import (
    BOARD,
    BRANCH,
    FEATURE,
    Sandbox,
    auditor_code,
    auditor_plan,
    builder_ok,
    planner_ok,
)


def commit_step(*paths):
    return [["git", "add", "--", *paths], ["git", "commit", "-m", "agent commit"]]


class FullPathTests(unittest.TestCase):
    """AC2."""

    def test_from_approved_on_main_with_no_feature_branch(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.script(builder_ok(), auditor_code())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(box.git("branch", "--show-current"), BRANCH)
            self.assertEqual(box.roles(), ["Builder", "Auditor:ModeB"])
            self.assertEqual(box.state(), ("CODE_REVIEW", "Lucas"))
            self.assertEqual(len(box.notifications()), 1)
            self.assertIn("tools/studio done F-900", box.notifications()[0])
            self.assertEqual(box.dirty(), "")
            self.assertIn("F-900: Auditor code review round 1", box.git("log", "-1", "--format=%s"))

    def test_the_review_edits_land_after_the_reviewed_commit(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.script(builder_ok(), auditor_code())
            box.studio("run", "F-900")
            reviewed = box.git("rev-parse", "HEAD~1")
            self.assertIn(f"**Reviewed commit:** `{reviewed}`", box.read(FEATURE))

    def test_from_plan_review_through_a_repair_to_gate_a(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script(
                auditor_plan(1, "CHANGES_REQUESTED"), planner_ok(), auditor_plan(2, "APPROVE")
            )
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                box.roles(), ["Auditor:ModeA", "Planner:Direction", "Auditor:ModeA"]
            )
            self.assertEqual(box.state(), ("PLAN_REVIEW", "Lucas"))
            self.assertEqual(box.git("branch", "--show-current"), "main")
            self.assertEqual(len(box.notifications()), 1)
            self.assertIn("tools/studio approve F-900", box.notifications()[0])
            self.assertEqual(box.dirty(), "")

    def test_tool_commits_are_explicit_and_named(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script(auditor_plan(1, "APPROVE"))
            box.studio("run", "F-900")
            self.assertEqual(
                box.git("log", "-1", "--format=%s"), "F-900: Auditor plan review round 1"
            )
            changed = box.git("show", "--name-only", "--format=", "HEAD").split()
            self.assertEqual(sorted(changed), sorted([FEATURE, BOARD]))

    def test_an_existing_feature_branch_is_reused(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.git("branch", BRANCH)
            box.script(builder_ok(), auditor_code())
            self.assertEqual(box.studio("run", "F-900").returncode, 0)
            self.assertEqual(box.git("branch", "--show-current"), BRANCH)

    def test_run_never_pushes(self):
        with Sandbox("APPROVED", "Builder") as box:
            before = box.remote_git("for-each-ref")
            box.script(builder_ok(), auditor_code())
            box.studio("run", "F-900")
            self.assertEqual(box.remote_git("for-each-ref"), before)

    def test_a_planner_may_add_a_proposed_decision_and_replies(self):
        with Sandbox("PLAN_CHANGES", "Planner", plan_rounds=["CHANGES_REQUESTED"]) as box:
            add = [
                "replace",
                "studio/DECISIONS.md",
                "## D-002",
                "## D-003 — New\n- **Status:** PROPOSED\n\n## D-002",
            ]
            box.script([add, *planner_ok()], auditor_plan(2, "APPROVE"))
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertFalse(box.is_blocked())
            self.assertIn("D-003", box.git("show", "main:studio/DECISIONS.md"))
            self.assertEqual(box.state(), ("PLAN_REVIEW", "Lucas"))

    def test_planner_escalation_stops_at_lucas(self):
        with Sandbox("PLAN_CHANGES", "Planner", plan_rounds=["CHANGES_REQUESTED"]) as box:
            escalate = [
                ["table_add", "| Q2 | Planner | Which? | yes | |"],
                ["state", "PLAN_CHANGES", "Lucas"],
            ]
            box.script(escalate)
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(box.state(), ("PLAN_CHANGES", "Lucas"))
            self.assertEqual(len(box.calls()), 1)
            self.assertFalse(box.is_blocked())

    def test_max_steps_stops_with_the_run_command(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script(auditor_plan(1, "CHANGES_REQUESTED"), planner_ok())
            result = box.studio("run", "F-900", "--max-steps", "2")
            self.assertEqual(result.returncode, 0)
            self.assertEqual(len(box.calls()), 2)
            self.assertIn("tools/studio run F-900", box.notifications()[0])


class RejectionCase(unittest.TestCase):
    """Shared assertions: no commit by the tool, no next agent, blocked, notified."""

    def assert_rejected(self, box, commits_before, reason=None):
        self.assertTrue(box.is_blocked(), "feature must be blocked")
        self.assertEqual(len(box.calls()), 1, "no further agent may run")
        self.assertEqual(box.commit_count(), commits_before, "the tool must not commit")
        self.assertEqual(len(box.notifications()), 1)
        if reason:
            self.assertIn(reason, box.blocked_record()["reason"] + str(box.blocked_record()["errors"]))
        self.assertFalse(box.lock_exists())

    def run_rejected(self, step, status="PLAN_REVIEW", owner="Auditor", reason=None, **rounds):
        with Sandbox(status, owner, **rounds) as box:
            box.script(step, auditor_plan(2, "APPROVE"))
            before = box.commit_count()
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assert_rejected(box, before, reason)


class InvalidTransitionTests(RejectionCase):
    """AC3."""

    def test_agent_writes_approved(self):
        step = [["section_add", 7, "<!-- review-round: 1 verdict: APPROVE -->"]]
        self.run_rejected(step + [["state", "APPROVED", "Builder"]], reason="only a gate")

    def test_agent_writes_done(self):
        step = [["section_add", 7, "<!-- review-round: 1 verdict: APPROVE -->"]]
        self.run_rejected(step + [["state", "DONE", "Lucas"]], reason="only a gate")

    def test_wrong_owner(self):
        step = [["section_add", 7, "<!-- review-round: 1 verdict: APPROVE -->"]]
        self.run_rejected(step + [["state", "PLAN_REVIEW", "Builder"]], reason="needs state")

    def test_verdict_contradicts_status(self):
        step = [["section_add", 7, "<!-- review-round: 1 verdict: CHANGES_REQUESTED -->"]]
        self.run_rejected(step + [["state", "PLAN_REVIEW", "Lucas"]], reason="needs state")

    def test_mismatched_board_row(self):
        step = [
            ["section_add", 7, "<!-- review-round: 1 verdict: APPROVE -->"],
            ["front", "PLAN_REVIEW", "Lucas"],
        ]
        self.run_rejected(step, reason="board says")

    def test_agent_switches_branch(self):
        step = [["git", "checkout", "-q", "-b", "elsewhere"]] + auditor_plan(1, "APPROVE")
        self.run_rejected(step, reason="branch changed")

    def test_agent_creates_a_side_branch(self):
        step = [["git", "branch", "side"]] + auditor_plan(1, "APPROVE")
        self.run_rejected(step, reason="branches were created")

    def test_no_new_round(self):
        self.run_rejected([["state", "PLAN_REVIEW", "Lucas"]], reason="expected one new")

    def test_skipped_round_number(self):
        step = [
            ["section_add", 7, "<!-- review-round: 4 verdict: APPROVE -->"],
            ["state", "PLAN_REVIEW", "Lucas"],
        ]
        self.run_rejected(step, reason="round number")

    def test_unknown_verdict(self):
        step = [
            ["section_add", 7, "<!-- review-round: 1 verdict: MAYBE -->"],
            ["state", "PLAN_REVIEW", "Lucas"],
        ]
        self.run_rejected(step, reason="unknown verdict")

    def test_stuck_step_changes_nothing(self):
        self.run_rejected([["sleep", 0]], reason="no progress")

    def test_builder_may_not_write_a_review_round(self):
        step = builder_ok()[:2] + [
            ["section_add", 9, "<!-- review-round: 1 verdict: APPROVE -->"],
            ["git", "add", "--", "src/new.txt", FEATURE, BOARD],
            ["git", "commit", "-m", "x"],
        ]
        with Sandbox("APPROVED", "Builder") as box:
            box.script(step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertIn("review rounds", str(box.blocked_record()["errors"]))

    def test_builder_escalation_needs_a_new_blocking_row(self):
        step = [["state", "IN_PROGRESS", "Lucas"], *commit_step(FEATURE, BOARD)]
        with Sandbox("APPROVED", "Builder") as box:
            box.script(step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertIn("blocking", str(box.blocked_record()["errors"]))

    def test_reviewed_commit_must_be_the_given_head(self):
        step = [
            ["section_add", 9, "<!-- review-round: 1 verdict: APPROVE -->\n**Reviewed commit:** `abcdef1`"],
            ["state", "CODE_REVIEW", "Lucas"],
        ]
        with Sandbox("APPROVED", "Builder") as box:
            box.script(builder_ok(), step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertIn("Reviewed commit", str(box.blocked_record()["errors"]))


class CommittedViolationTests(unittest.TestCase):
    """AC4: a clean final tree hides nothing."""

    def run_committed_violation(self, edit, path):
        with Sandbox("APPROVED", "Builder") as box:
            step = builder_ok()[:2] + [
                edit,
                ["git", "add", "--", "src/new.txt", FEATURE, BOARD, path],
                ["git", "commit", "-m", "sneaky commit"],
            ]
            box.script(step, auditor_code())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertEqual(box.dirty(), "", "the violation is committed, tree clean")
            self.assertTrue(box.is_blocked())
            self.assertEqual(len(box.calls()), 1)
            message = box.notifications()[0]
            self.assertIn("sneaky commit", message)
            self.assertIn(path, message)
            self.assertIn("sneaky commit", box.git("log", "-1", "--format=%s"), "history kept")
            refused = box.studio("run", "F-900")
            self.assertEqual(refused.returncode, 1)
            self.assertIn("blocked", box.notifications()[1])
            self.assertEqual(len(box.calls()), 1)

    def test_committed_edit_to_agents_md(self):
        self.run_committed_violation(["write", "AGENTS.md", "# changed\n"], "AGENTS.md")

    def test_committed_whitespace_only_edit_to_decisions(self):
        path = "studio/DECISIONS.md"
        self.run_committed_violation(["replace", path, "First\n", "First \n"], path)

    def test_an_edit_reverted_later_is_still_caught(self):
        with Sandbox("APPROVED", "Builder") as box:
            step = [
                ["write", "AGENTS.md", "# changed\n"],
                ["git", "add", "--", "AGENTS.md"],
                ["git", "commit", "-m", "edit"],
                ["git", "revert", "--no-edit", "HEAD"],
                *builder_ok(),
            ]
            box.script(step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertIn("AGENTS.md", box.blocked_record()["paths"])

    def test_a_rewritten_history_is_rejected(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.git("checkout", "-q", "-b", BRANCH)
            box.write("src/old.txt", "old\n")
            box.commit_all("existing work", "src/old.txt")
            step = [
                ["write", "src/x.txt", "x\n"],
                ["git", "add", "--", "src/x.txt"],
                ["git", "commit", "--amend", "-m", "rewritten"],
                *builder_ok(),
            ]
            box.script(step)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertIn("fast-forward", str(box.blocked_record()["errors"]))

    def test_unblock_clears_the_refusal_only(self):
        with Sandbox("APPROVED", "Builder") as box:
            step = builder_ok()[:2] + [
                ["write", "AGENTS.md", "# changed\n"],
                ["git", "add", "--", "src/new.txt", FEATURE, BOARD, "AGENTS.md"],
                ["git", "commit", "-m", "bad"],
            ]
            box.script(step, builder_ok(), auditor_code())
            box.studio("run", "F-900")
            start = box.blocked_record()["start_head"]
            self.assertIn(f"git reset --hard {start}", box.notifications()[0])
            box.git("reset", "-q", "--hard", start)
            self.assertEqual(box.studio("unblock", "F-900").returncode, 0)
            self.assertFalse(box.is_blocked())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(box.state(), ("CODE_REVIEW", "Lucas"))

    def test_unblock_on_a_clear_feature_is_harmless(self):
        with Sandbox() as box:
            result = box.studio("unblock", "F-900")
            self.assertEqual(result.returncode, 0)
            self.assertIn("isn't blocked", result.stdout)


class ContentLaneTests(RejectionCase):
    """AC5, end to end."""

    def auditor_with(self, *ops):
        return [*ops, *auditor_plan(2, "APPROVE")]

    def test_auditor_alters_section_1(self):
        step = self.auditor_with(["replace", "@feature", "The goal.", "Mine."])
        self.run_rejected(step, plan_rounds=["CHANGES_REQUESTED"], reason="§1")

    def test_auditor_deletes_an_earlier_finding(self):
        step = self.auditor_with(["replace", "@feature", "Round 1 text.", ""])
        self.run_rejected(step, plan_rounds=["CHANGES_REQUESTED"], reason="§7")

    def test_section_11_edit(self):
        step = self.auditor_with(["replace", "@feature", "<Overrides>", "Do it my way."])
        self.run_rejected(step, plan_rounds=["CHANGES_REQUESTED"], reason="§11")

    def test_another_frontmatter_field(self):
        step = self.auditor_with(["replace", "@feature", "pillars: []", "pillars: [1]"])
        self.run_rejected(step, plan_rounds=["CHANGES_REQUESTED"], reason="frontmatter")

    def test_auditor_outside_its_path_lane(self):
        step = self.auditor_with(["write", "src/fix.gd", "x\n"])
        self.run_rejected(step, plan_rounds=["CHANGES_REQUESTED"], reason="outside the auditor")

    def test_existing_decision_status_changed_by_planner(self):
        path = "studio/DECISIONS.md"
        step = [
            ["replace", path, "- **Status:** ACCEPTED", "- **Status:** SUPERSEDED"],
            *planner_ok(),
        ]
        self.run_rejected(
            step,
            status="PLAN_CHANGES",
            owner="Planner",
            plan_rounds=["CHANGES_REQUESTED"],
            reason="D-002",
        )

    def test_board_other_column(self):
        step = self.auditor_with(["replace", BOARD, "| Demo feature |", "| Renamed |"])
        self.run_rejected(step, plan_rounds=["CHANGES_REQUESTED"], reason="STATUS.md")

    def test_board_last_updated_line(self):
        step = self.auditor_with(["replace", BOARD, "2026-10-31", "2027-01-01"])
        self.run_rejected(step, plan_rounds=["CHANGES_REQUESTED"], reason="STATUS.md")


if __name__ == "__main__":
    unittest.main()
