"""AC6 and AC8: gates, recovery after every partial failure, against a bare remote."""

import unittest

from helpers import BOARD, BRANCH, FEATURE, Sandbox
from studio_lib.git import Git, GitError

REJECT_MAIN = """
while read old new ref; do
  [ "$ref" = refs/heads/main ] && { echo "main is locked"; exit 1; }
done
exit 0
"""
REJECT_FEATURE = """
while read old new ref; do
  case "$ref" in refs/heads/feature/*) echo "feature is locked"; exit 1;; esac
done
exit 0
"""
REJECT_DELETES = """
while read old new ref; do
  case "$new" in *[!0]*) ;; *) echo "no deletes"; exit 1;; esac
done
exit 0
"""


def gate_a_box():
    return Sandbox("PLAN_REVIEW", "Lucas", plan_rounds=["APPROVE"])


class ApproveTests(unittest.TestCase):
    def test_sets_approved_commits_two_files_and_pushes(self):
        with gate_a_box() as box:
            result = box.studio("approve", "F-900", "--note", "Looks right.")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(box.state(), ("APPROVED", "Builder"))
            self.assertIn("| APPROVED | Builder |", box.read(BOARD))
            self.assertIn("(Gate A):** Looks right.", box.read(FEATURE))
            changed = box.git("show", "--name-only", "--format=", "HEAD").split()
            self.assertEqual(sorted(changed), sorted([FEATURE, BOARD]))
            self.assertEqual(box.git("rev-parse", "HEAD"), box.remote_git("rev-parse", "main"))
            self.assertIn("tools/studio run F-900", result.stdout)

    def test_refuses_without_an_approving_round(self):
        with Sandbox("PLAN_REVIEW", "Lucas", plan_rounds=["CHANGES_REQUESTED"]) as box:
            self.assertEqual(box.studio("approve", "F-900").returncode, 1)
            self.assertEqual(box.state(), ("PLAN_REVIEW", "Lucas"))

    def test_refuses_the_wrong_owner(self):
        with Sandbox("PLAN_REVIEW", "Auditor", plan_rounds=["APPROVE"]) as box:
            self.assertEqual(box.studio("approve", "F-900").returncode, 1)

    def test_refuses_off_main_and_on_a_dirty_tree(self):
        with gate_a_box() as box:
            box.git("checkout", "-q", "-b", "other")
            self.assertEqual(box.studio("approve", "F-900").returncode, 1)
            box.git("checkout", "-q", "main")
            box.write("stray.txt", "x\n")
            self.assertEqual(box.studio("approve", "F-900").returncode, 1)

    def test_refuses_a_blocked_feature(self):
        with gate_a_box() as box:
            (box.repo / ".studio/blocked").mkdir(parents=True)
            (box.repo / ".studio/blocked/F-900.json").write_text('{"reason": "x"}')
            self.assertEqual(box.studio("approve", "F-900").returncode, 1)
            self.assertEqual(box.state(), ("PLAN_REVIEW", "Lucas"))

    def test_rebases_over_new_remote_work(self):
        with gate_a_box() as box:
            box.advance_remote_main()
            self.assertEqual(box.studio("approve", "F-900").returncode, 0)
            self.assertIn("Gate A", box.remote_git("log", "-1", "--format=%s", "main"))
            self.assertEqual(box.remote_git("show", "main:remote.txt"), "remote")

    def test_a_rejected_push_stops_and_a_rerun_completes(self):
        with gate_a_box() as box:
            box.add_remote_hook(REJECT_MAIN)
            result = box.studio("approve", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("main is locked", result.stderr)
            self.assertIn("Next: tools/studio approve F-900", result.stderr)
            self.assertEqual(box.state(), ("APPROVED", "Builder"))
            commits = box.commit_count()
            box.remove_remote_hook()
            result = box.studio("approve", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(box.commit_count(), commits, "step 1 isn't repeated")
            self.assertEqual(box.git("rev-parse", "HEAD"), box.remote_git("rev-parse", "main"))

    def test_a_rebase_conflict_leaves_no_rebase_in_progress(self):
        with gate_a_box() as box:
            box.advance_remote_main(BOARD, "conflicting board\n")
            result = box.studio("approve", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("Next: tools/studio approve F-900", result.stderr)
            self.assertFalse((box.repo / ".git/rebase-merge").exists())
            self.assertEqual(box.dirty(), "")

    def test_a_rerun_after_success_is_a_no_op(self):
        with gate_a_box() as box:
            box.studio("approve", "F-900")
            commits = box.commit_count()
            result = box.studio("approve", "F-900")
            self.assertEqual(result.returncode, 0)
            self.assertIn("already approved", result.stdout)
            self.assertEqual(box.commit_count(), commits)


class DoneCase(unittest.TestCase):
    def assert_published(self, box, reviewed):
        self.assertEqual(box.git("branch", "--show-current"), "main")
        self.assertEqual(box.git("branch", "--list", BRANCH), "")
        self.assertEqual(box.git("ls-remote", "origin", f"refs/heads/{BRANCH}"), "")
        self.assertEqual(box.git("rev-parse", "HEAD"), box.remote_git("rev-parse", "main"))
        contains = box.git("branch", "-r", "--contains", reviewed)
        self.assertIn("origin/main", contains)
        self.assertEqual(box.state(), ("DONE", "Lucas"))
        self.assertIn("| DONE | — |", box.read(BOARD))

    def assert_branches_exist(self, box):
        self.assertIn(BRANCH, box.git("branch", "--list", BRANCH))


class DoneTests(DoneCase):
    def test_merges_pushes_and_deletes_branches(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            result = box.studio("done", "F-900", "--note", "Fun.")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)
            self.assertIn("(Gate B):** Fun.", box.read(FEATURE))
            self.assertIn("Merge F-900", box.git("log", "-1", "--format=%s"))
            self.assertEqual(len(box.git("log", "-1", "--format=%P").split()), 2, "--no-ff")

    def test_works_from_main_too(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.git("checkout", "-q", "main")
            self.assertEqual(box.studio("done", "F-900").returncode, 0)
            self.assert_published(box, reviewed)

    def test_refuses_a_changes_requested_round(self):
        with Sandbox() as box:
            box.prepare_gate_b("CHANGES_REQUESTED")
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assert_branches_exist(box)

    def test_refuses_the_wrong_state(self):
        with Sandbox() as box:
            self.assertEqual(box.studio("done", "F-900").returncode, 1)

    def test_a_later_code_commit_needs_a_new_review(self):
        with Sandbox() as box:
            box.prepare_gate_b()
            box.write("src/late.txt", "late\n")
            box.commit_all("sneak in code", "src/late.txt")
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("src/late.txt", result.stderr)
            self.assertEqual(box.state(), ("CODE_REVIEW", "Lucas"))
            self.assert_branches_exist(box)

    def test_a_later_metadata_commit_proceeds(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.write(FEATURE, box.read(FEATURE).replace("**Started:** —", "**Started:** today"))
            box.commit_all("F-900: tidy log", FEATURE)
            self.assertEqual(box.studio("done", "F-900").returncode, 0)
            self.assert_published(box, reviewed)

    def test_dirty_code_refuses_and_checks_never_run(self):
        with Sandbox() as box:
            box.prepare_gate_b()
            box.set_checks(1)
            box.write("src/new.txt", "changed\n")
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("src/new.txt", result.stderr)
            self.assertEqual(box.state(), ("CODE_REVIEW", "Lucas"))

    def test_dirty_test_file_refuses(self):
        with Sandbox() as box:
            box.prepare_gate_b()
            box.write("tests/extra.txt", "untracked\n")
            self.assertEqual(box.studio("done", "F-900").returncode, 1)

    def _uncommitted_review(self, box):
        """A manual Auditor session: edits left in the tree."""
        box.checkout_feature_branch()
        reviewed = box.git("rev-parse", "HEAD")
        box.edit_state("CODE_REVIEW", "Auditor")
        box.commit_all("F-900: ready", FEATURE, BOARD)
        marker = f"<!-- review-round: 1 verdict: APPROVE -->\n**Reviewed commit:** `{reviewed}`\n"
        box.write(FEATURE, box.read(FEATURE).replace("\n---\n\n## 10.", f"\n{marker}\n---\n\n## 10."))
        box.edit_state("CODE_REVIEW", "Lucas")
        return reviewed

    def test_the_auditors_uncommitted_edits_are_committed_then_checked(self):
        with Sandbox() as box:
            reviewed = self._uncommitted_review(box)
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)
            self.assertIn("F-900: Auditor code review round 1", box.git("log", "--format=%s"))

    def test_review_edits_outside_the_auditor_lane_refuse(self):
        with Sandbox() as box:
            self._uncommitted_review(box)
            box.write(FEATURE, box.read(FEATURE).replace("The goal.", "Changed."))
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("lanes", result.stderr)

    def test_red_checks_stop_before_done(self):
        with Sandbox() as box:
            box.prepare_gate_b()
            box.set_checks(1)
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("Checks failed", result.stderr)
            self.assertEqual(box.state(), ("CODE_REVIEW", "Lucas"))
            self.assert_branches_exist(box)

    def test_refuses_a_blocked_feature(self):
        with Sandbox() as box:
            box.prepare_gate_b()
            (box.repo / ".studio/blocked").mkdir(parents=True)
            (box.repo / ".studio/blocked/F-900.json").write_text('{"reason": "x"}')
            self.assertEqual(box.studio("done", "F-900").returncode, 1)


class DoneRecoveryTests(DoneCase):
    """AC8: stop correctly, keep the branches, and a rerun finishes the job."""

    def test_rejected_feature_push(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.add_remote_hook(REJECT_FEATURE)
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("feature is locked", result.stderr)
            self.assertIn("Next: tools/studio done F-900", result.stderr)
            self.assertEqual(box.state(), ("DONE", "Lucas"))
            self.assert_branches_exist(box)
            box.remove_remote_hook()
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)

    def test_rejected_main_push(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.add_remote_hook(REJECT_MAIN)
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("main is locked", result.stderr)
            self.assert_branches_exist(box)
            self.assertNotEqual(box.git("ls-remote", "origin", f"refs/heads/{BRANCH}"), "")
            box.remove_remote_hook()
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)

    def test_main_moved_after_the_merge_keeps_the_merge_commit(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.add_remote_hook(REJECT_MAIN)
            box.studio("done", "F-900")
            box.remove_remote_hook()
            box.advance_remote_main()
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)
            subjects = box.git("log", "--format=%s", "main").split("\n")
            self.assertEqual(subjects.count("Merge F-900: Demo feature"), 1)
            self.assertEqual(subjects.count("F-900 T1: work"), 1, "work isn't replayed")

    def test_merge_conflict_stops_with_the_files_and_the_abort_command(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.advance_remote_main("src/new.txt", "theirs\n")
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("src/new.txt", result.stderr)
            self.assertIn("Next: git merge --abort", result.stderr)
            self.assertEqual(box.git("rev-parse", "main"), box.remote_git("rev-parse", "main"))
            again = box.studio("done", "F-900")
            self.assertEqual(again.returncode, 1, "a rerun mid-conflict changes nothing")
            self.assertIn("git merge --abort", again.stderr)
            box.git("merge", "--abort")
            box.git("rm", "-q", "src/new.txt")
            box.git("commit", "-q", "-m", "drop the conflicting file")
            box.git("push", "-q", "origin", "main")
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)

    def test_failed_remote_deletion(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.add_remote_hook(REJECT_DELETES)
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertIn("no deletes", result.stderr)
            self.assertEqual(box.git("rev-parse", "HEAD"), box.remote_git("rev-parse", "main"))
            self.assert_branches_exist(box)
            box.remove_remote_hook()
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)

    def test_failed_local_deletion(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.add_remote_hook(REJECT_DELETES)
            box.studio("done", "F-900")
            box.remove_remote_hook()
            holder = box.base / "holder"
            box.git("worktree", "add", "-q", str(holder), BRANCH)
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(box.git("ls-remote", "origin", f"refs/heads/{BRANCH}"), "")
            self.assert_branches_exist(box)
            box.git("worktree", "remove", "--force", str(holder))
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)

    def test_an_unmerged_branch_is_never_force_deleted(self):
        with Sandbox() as box:
            box.git("checkout", "-q", "-b", "unmerged")
            box.write("src/unmerged.txt", "x\n")
            box.commit_all("unmerged work", "src/unmerged.txt")
            box.git("checkout", "-q", "main")
            with self.assertRaises(GitError):
                Git(box.repo).delete_local_branch("unmerged")
            self.assertIn("unmerged", box.git("branch", "--list", "unmerged"))

    def test_a_missing_local_branch_counts_as_deleted(self):
        with Sandbox() as box:
            reviewed = box.prepare_gate_b()
            box.add_remote_hook(REJECT_DELETES)
            box.studio("done", "F-900")
            box.remove_remote_hook()
            box.git("branch", "-q", "-d", BRANCH)
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_published(box, reviewed)

    def test_a_rerun_after_success_is_a_no_op(self):
        with Sandbox() as box:
            box.prepare_gate_b()
            box.studio("done", "F-900")
            head = box.git("rev-parse", "HEAD")
            result = box.studio("done", "F-900")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(box.git("rev-parse", "HEAD"), head)


if __name__ == "__main__":
    unittest.main()
