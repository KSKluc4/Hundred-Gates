"""AC1: `status` and `next`, for every input combination."""

import itertools
import unittest

from helpers import BOARD, FEATURE, Sandbox
from studio_lib.engine import decide, path_allowed
from studio_lib.feature import OWNERS, STATUSES

ACTIONS = {
    ("PLAN_REVIEW", "Auditor"): "A",
    ("PLAN_CHANGES", "Planner"): "B",
    ("APPROVED", "Builder"): "C",
    ("CODE_CHANGES", "Builder"): "C",
    ("CODE_REVIEW", "Auditor"): "D",
}


class ActionTableTests(unittest.TestCase):
    def test_every_combination_maps_to_the_c5_table(self):
        for status, owner in itertools.product(STATUSES, OWNERS):
            expected = ACTIONS.get((status, owner))
            self.assertEqual(decide(status, owner).action, expected, (status, owner))

    def test_blocked_stops_every_combination(self):
        for status, owner in itertools.product(STATUSES, OWNERS):
            self.assertIsNone(decide(status, owner, blocked=True).action, (status, owner))

    def test_unknown_values_stop(self):
        self.assertIsNone(decide("WEIRD", "Builder").action)
        self.assertIsNone(decide("APPROVED", "Nobody").action)

    def test_in_progress_stops_without_resume_for_every_owner(self):
        for owner in OWNERS:
            self.assertIsNone(decide("IN_PROGRESS", owner).action)

    def test_resume_takes_precedence_over_the_lucas_stop(self):
        self.assertEqual(decide("IN_PROGRESS", "Lucas", resume=True).action, "C")
        self.assertEqual(decide("IN_PROGRESS", "Builder", resume=True).action, "C")

    def test_resume_does_not_change_other_states(self):
        self.assertIsNone(decide("DONE", "Lucas", resume=True).action)
        self.assertIsNone(decide("IN_PROGRESS", "Builder", blocked=True, resume=True).action)


class PathLaneTests(unittest.TestCase):
    """F-002/C12."""

    def test_auditor(self):
        self.assertTrue(path_allowed("auditor-plan", FEATURE, FEATURE))
        self.assertTrue(path_allowed("auditor-code", BOARD, FEATURE))
        for path in ("studio/DECISIONS.md", "src/a.gd", "AGENTS.md", "tools/x"):
            self.assertFalse(path_allowed("auditor-code", path, FEATURE), path)

    def test_planner(self):
        for path in (FEATURE, BOARD, "studio/DECISIONS.md", "studio/GLOSSARY.md"):
            self.assertTrue(path_allowed("planner", path, FEATURE), path)
        self.assertTrue(path_allowed("planner", "studio/design/combat.md", FEATURE))
        for path in ("studio/design/a/b.md", "studio/design/x.txt", "src/a.gd", "CLAUDE.md"):
            self.assertFalse(path_allowed("planner", path, FEATURE), path)

    def test_builder(self):
        for path in ("src/a.gd", "tests/x.gd", FEATURE, BOARD, "README.md", "studio/GLOSSARY.md"):
            self.assertTrue(path_allowed("builder", path, FEATURE), path)
        for path in (
            "studio/departments/combat.md",
            "studio/design/combat.md",
            "studio/DECISIONS.md",
            "AGENTS.md",
            "CLAUDE.md",
            "studio/features/F-001-x.md",
            "studio/features/_TEMPLATE.md",
        ):
            self.assertFalse(path_allowed("builder", path, FEATURE), path)


class StatusCommandTests(unittest.TestCase):
    def test_prints_id_title_status_owner_and_blocked_flag(self):
        with Sandbox() as box:
            result = box.studio("status")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("F-900  Demo feature  APPROVED  Builder  [ok]", result.stdout)
            (box.repo / ".studio/blocked").mkdir(parents=True)
            (box.repo / ".studio/blocked/F-900.json").write_text("{}")
            self.assertIn("[BLOCKED]", box.studio("status").stdout)

    def test_flags_a_board_mismatch(self):
        with Sandbox() as box:
            box.write(BOARD, box.read(BOARD).replace("| APPROVED | Builder |", "| DONE | — |"))
            self.assertIn("MISMATCH", box.studio("status").stdout)

    def test_flags_a_verdict_mismatch(self):
        with Sandbox("PLAN_CHANGES", "Planner", plan_rounds=["APPROVE"]) as box:
            self.assertIn("MISMATCH", box.studio("status").stdout)

    def test_reads_the_branch_tip_from_main(self):
        with Sandbox() as box:
            box.prepare_gate_b()
            box.git("checkout", "-q", "main")
            self.assertIn("CODE_REVIEW  Lucas", box.studio("status").stdout)

    def test_never_runs_an_agent(self):
        with Sandbox() as box:
            box.studio("status")
            box.studio("next", "F-900")
            self.assertEqual(box.calls(), [])


class NextCommandTests(unittest.TestCase):
    def test_prints_the_action_for_every_runnable_state(self):
        for (status, owner), action in ACTIONS.items():
            with self.subTest(status=status), Sandbox(status, owner) as box:
                result = box.studio("next", "F-900")
                self.assertIn(f"action {action}", result.stdout)
                self.assertIn("Next: tools/studio run F-900", result.stdout)

    def test_prints_a_stop_and_one_next_command_for_every_stop_state(self):
        cases = {
            ("PLAN_REVIEW", "Lucas"): "tools/studio approve F-900",
            ("CODE_REVIEW", "Lucas"): "tools/studio done F-900",
            ("IN_PROGRESS", "Lucas"): "tools/studio run --resume F-900",
            ("IN_PROGRESS", "Builder"): "tools/studio run --resume F-900",
            ("PLAN_CHANGES", "Lucas"): f"open {FEATURE}",
            ("DRAFT", "Planner"): f"open {FEATURE}",
            ("DONE", "Lucas"): "tools/studio status",
            ("PARKED", "Lucas"): "tools/studio status",
            ("WEIRD", "Builder"): f"open {FEATURE}",
        }
        for (status, owner), command in cases.items():
            with self.subTest(status=status, owner=owner), Sandbox(status, owner) as box:
                result = box.studio("next", "F-900")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("-> stop:", result.stdout)
                self.assertIn(f"Next: {command}", result.stdout)

    def test_blocked_feature_points_at_unblock(self):
        with Sandbox() as box:
            (box.repo / ".studio/blocked").mkdir(parents=True)
            (box.repo / ".studio/blocked/F-900.json").write_text("{}")
            self.assertIn("Next: tools/studio unblock F-900", box.studio("next", "F-900").stdout)

    def test_unknown_feature_is_refused(self):
        with Sandbox() as box:
            self.assertEqual(box.studio("next", "F-777").returncode, 1)
            self.assertEqual(box.studio("next", "nonsense").returncode, 1)


class RunStopTests(unittest.TestCase):
    """`run` on a stop state: no agent, one notification with the next command."""

    def test_stop_states_never_call_an_agent(self):
        states = [
            ("DRAFT", "Planner", {}),
            ("DONE", "Lucas", {}),
            ("PARKED", "Lucas", {}),
            ("IN_PROGRESS", "Builder", {}),
            ("PLAN_REVIEW", "Lucas", {"plan_rounds": ["APPROVE"]}),
        ]
        for status, owner, rounds in states:
            with self.subTest(status=status), Sandbox(status, owner, **rounds) as box:
                result = box.studio("run", "F-900")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(box.calls(), [])
                self.assertEqual(len(box.notifications()), 1)

    def test_a_start_mismatch_refuses_to_run(self):
        with Sandbox() as box:
            box.write(BOARD, box.read(BOARD).replace("| APPROVED |", "| DRAFT |"))
            box.commit_all("board drift", BOARD)
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(box.calls(), [])
            self.assertIn("mismatch", box.notifications()[0])

    def test_plan_actions_refuse_a_feature_branch(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.git("checkout", "-q", "-b", "other")
            result = box.studio("run", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(box.calls(), [])
            self.assertIn("git checkout main", box.notifications()[0])


if __name__ == "__main__":
    unittest.main()
