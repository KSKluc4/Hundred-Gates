"""AC6 (readiness) and AC7 (round caps), end to end."""

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


class ReadinessTests(unittest.TestCase):
    def test_red_checks_skip_the_auditor_and_dispatch_the_builder(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.set_checks(1)
            box.script(builder_ok(), builder_ok("src/fix.txt"), builder_ok("src/fix2.txt"))
            result = box.studio("run", "F-900", "--max-steps", "2")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(box.roles(), ["Builder", "Builder"], "no Auditor call")
            self.assertIn("readiness-fail: 1 sha:", box.read(FEATURE))

    def test_red_result_is_committed_as_changes_for_the_builder(self):
        with Sandbox("CODE_REVIEW", "Auditor") as box:
            box.checkout_feature_branch()
            box.set_checks(1)
            result = box.studio("run", "F-900", "--max-steps", "0")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(box.state(), ("CODE_CHANGES", "Builder"))
            self.assertEqual(box.calls(), [])
            self.assertEqual(box.dirty(), "")
            self.assertIn("readiness failed", box.git("log", "-1", "--format=%s"))
            changed = box.git("show", "--name-only", "--format=", "HEAD").split()
            self.assertEqual(sorted(changed), sorted([FEATURE, BOARD]))
            self.assertIn("tools/test, tools/lint, tools/check_core_purity", box.read(FEATURE))

    def test_a_restart_after_red_can_not_reach_the_auditor(self):
        with Sandbox("CODE_REVIEW", "Auditor") as box:
            box.checkout_feature_branch()
            box.set_checks(1)
            box.studio("run", "F-900", "--max-steps", "0")
            box.set_checks(0)
            box.script(builder_ok("src/fix.txt"), auditor_code())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(box.roles(), ["Builder", "Auditor:ModeB"])

    def test_three_consecutive_reds_with_restarts_escalate(self):
        with Sandbox("CODE_REVIEW", "Auditor") as box:
            box.checkout_feature_branch()
            box.set_checks(1)
            box.script(builder_ok("src/a.txt"), builder_ok("src/b.txt"), builder_ok("src/c.txt"))
            for attempt in range(1, 3):
                box.studio("run", "F-900", "--max-steps", "0")
                self.assertEqual(box.state(), ("CODE_CHANGES", "Builder"), attempt)
                box.studio("run", "F-900", "--max-steps", "1")
                self.assertEqual(len(box.calls()), attempt)
            self.assertEqual(box.state(), ("CODE_CHANGES", "Lucas"))
            self.assertEqual(len(box.calls()), 2, "the third failure goes to Lucas, not the Builder")
            self.assertIn("readiness-fail: 3 sha:", box.read(FEATURE))
            self.assertIn("| yes | |", box.read(FEATURE))
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0)
            self.assertEqual(len(box.calls()), 2)

    def test_a_completed_review_resets_the_failure_count(self):
        with Sandbox("CODE_REVIEW", "Auditor") as box:
            box.checkout_feature_branch()
            box.set_checks(1)
            box.studio("run", "F-900", "--max-steps", "0")
            box.set_checks(0)
            box.script(
                builder_ok("src/a.txt"),
                auditor_code(1, "CHANGES_REQUESTED"),
                builder_ok("src/b.txt"),
            )
            box.studio("run", "F-900", "--max-steps", "3")
            box.set_checks(1)
            box.studio("run", "F-900", "--max-steps", "0")
            self.assertIn("readiness-fail: 1 sha:", box.read(FEATURE).split("after-code-round: 1")[0])
            self.assertEqual(box.state(), ("CODE_CHANGES", "Builder"))

    def test_preexisting_dirty_edits_refuse_run(self):
        for path in ("src/mine.txt", "AGENTS.md"):
            with self.subTest(path=path), Sandbox("APPROVED", "Builder") as box:
                box.write(path, "local edit\n")
                result = box.studio("run", "F-900")
                self.assertEqual(result.returncode, 1)
                self.assertEqual(box.calls(), [])
                self.assertFalse(box.is_blocked(), "a refusal blocks nothing")
                self.assertEqual(box.git("branch", "--show-current"), "main")

    def test_a_builder_that_leaves_uncommitted_files_is_rejected(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.script([*builder_ok(), ["write", "src/forgot.txt", "x\n"]], auditor_code())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertTrue(box.is_blocked())
            self.assertIn("uncommitted", str(box.blocked_record()["errors"]))
            self.assertEqual(len(box.calls()), 1)

    def test_checks_that_dirty_the_tree_stop_the_run(self):
        with Sandbox("CODE_REVIEW", "Auditor") as box:
            box.checkout_feature_branch()
            box.write("tools/test", "#!/bin/sh\necho x > generated.txt\n")
            box.commit_all("checks write a file", "tools/test")
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(box.calls(), [])

    def test_missing_check_script_counts_as_red(self):
        with Sandbox("CODE_REVIEW", "Auditor") as box:
            box.checkout_feature_branch()
            box.git("rm", "-q", "tools/lint")
            box.git("commit", "-q", "-m", "drop lint")
            box.studio("run", "F-900", "--max-steps", "0")
            self.assertEqual(box.state(), ("CODE_CHANGES", "Builder"))
            self.assertIn("tools/lint", box.read(FEATURE))


class RoundCapTests(unittest.TestCase):
    """AC7."""

    def test_third_code_changes_requested_escalates(self):
        rounds = ["CHANGES_REQUESTED", "CHANGES_REQUESTED"]
        with Sandbox("CODE_REVIEW", "Auditor", code_rounds=rounds) as box:
            box.checkout_feature_branch()
            box.script(auditor_code(3, "CHANGES_REQUESTED"), builder_ok("src/never.txt"))
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(box.roles(), ["Auditor:ModeB"], "no repair is dispatched")
            self.assertEqual(box.state(), ("CODE_CHANGES", "Lucas"))
            self.assertIn("3 code review rounds used", box.read(FEATURE))
            self.assertEqual(len(box.notifications()), 1)
            self.assertEqual(box.dirty(), "")

    def test_third_code_approval_proceeds(self):
        rounds = ["CHANGES_REQUESTED", "CHANGES_REQUESTED"]
        with Sandbox("CODE_REVIEW", "Auditor", code_rounds=rounds) as box:
            box.checkout_feature_branch()
            box.script(auditor_code(3, "APPROVE_WITH_NOTES"))
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(box.state(), ("CODE_REVIEW", "Lucas"))
            self.assertIn("tools/studio done F-900", box.notifications()[0])

    def test_third_plan_changes_requested_escalates(self):
        rounds = ["CHANGES_REQUESTED", "CHANGES_REQUESTED"]
        with Sandbox("PLAN_REVIEW", "Auditor", plan_rounds=rounds) as box:
            box.script(auditor_plan(3, "CHANGES_REQUESTED"), planner_ok())
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(box.roles(), ["Auditor:ModeA"])
            self.assertEqual(box.state(), ("PLAN_CHANGES", "Lucas"))
            self.assertIn("3 plan review rounds used", box.read(FEATURE))

    def test_third_plan_approval_proceeds(self):
        rounds = ["CHANGES_REQUESTED", "CHANGES_REQUESTED"]
        with Sandbox("PLAN_REVIEW", "Auditor", plan_rounds=rounds) as box:
            box.script(auditor_plan(3, "APPROVE"))
            self.assertEqual(box.studio("run", "F-900").returncode, 0)
            self.assertEqual(box.state(), ("PLAN_REVIEW", "Lucas"))

    def test_a_restart_at_the_cap_does_not_dispatch_the_repair(self):
        rounds = ["CHANGES_REQUESTED", "CHANGES_REQUESTED", "CHANGES_REQUESTED"]
        with Sandbox("PLAN_CHANGES", "Planner", plan_rounds=rounds) as box:
            self.assertEqual(box.studio("run", "F-900").returncode, 0)
            self.assertEqual(box.calls(), [])
            self.assertEqual(box.state(), ("PLAN_CHANGES", "Lucas"))

    def test_no_fourth_review_round_runs(self):
        rounds = ["CHANGES_REQUESTED", "CHANGES_REQUESTED", "CHANGES_REQUESTED"]
        with Sandbox("CODE_REVIEW", "Auditor", code_rounds=rounds) as box:
            box.checkout_feature_branch()
            self.assertEqual(box.studio("run", "F-900").returncode, 0)
            self.assertEqual(box.calls(), [])
            self.assertEqual(box.state(), ("CODE_REVIEW", "Auditor"), "no gate is implied")
            self.assertIn("no further audit", box.notifications()[0])
            self.assertEqual(box.git("branch", "--show-current"), BRANCH)

    def test_two_rounds_still_dispatch_the_repair(self):
        with Sandbox("PLAN_CHANGES", "Planner", plan_rounds=["CHANGES_REQUESTED"] * 2) as box:
            box.script(planner_ok(), auditor_plan(3, "APPROVE"))
            self.assertEqual(box.studio("run", "F-900").returncode, 0)
            self.assertEqual(box.roles(), ["Planner:Direction", "Auditor:ModeA"])


if __name__ == "__main__":
    unittest.main()
