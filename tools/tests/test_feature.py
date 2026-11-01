"""Pure rules: parsing, round markers, content lanes (F-002 C6, C9, C13, AC5, AC7)."""

import unittest

import helpers
from studio_lib import feature as ft
from studio_lib.feature import Feature, FormatError


def sample(status="PLAN_REVIEW", owner="Auditor", plan=(), code=()):
    return helpers.FEATURE_TEXT.format(
        status=status,
        owner=owner,
        plan_rounds=helpers.rounds_text(list(plan)),
        code_rounds=helpers.rounds_text(list(code)),
    )


def board(status="PLAN_REVIEW", owner="Auditor"):
    return helpers.BOARD_TEXT.format(status=status, owner=owner)


class ParsingTests(unittest.TestCase):
    def test_reads_frontmatter_without_comments(self):
        item = Feature(sample())
        self.assertEqual(item.fid, "F-900")
        self.assertEqual(item.status, "PLAN_REVIEW")
        self.assertEqual(item.owner, "Auditor")
        self.assertEqual(item.department, "Direction")

    def test_splits_all_eleven_sections(self):
        self.assertEqual(sorted(Feature(sample()).sections), list(range(1, 12)))

    def test_section_heading_inside_a_code_fence_is_not_a_section(self):
        text = sample().replace("The goal.", "```\n## 4. Not a section\n```")
        self.assertEqual(sorted(Feature(text).sections), list(range(1, 12)))

    def test_rejects_a_file_without_frontmatter(self):
        with self.assertRaises(FormatError):
            Feature("# no frontmatter\n")

    def test_rejects_duplicate_sections(self):
        with self.assertRaises(FormatError):
            Feature(sample().replace("## 8. Implementation", "## 7. Implementation"))

    def test_set_field_keeps_the_comment_column(self):
        text = "---\nstatus: DRAFT            # options\nid: F-1\n---\n"
        result = ft.set_field(text, "status", "IN_PROGRESS")
        self.assertIn("status: IN_PROGRESS      # options\n", result)

    def test_set_state_changes_status_owner_and_updated(self):
        item = Feature(ft.set_state(sample(), "PLAN_CHANGES", "Planner", "2027-01-02"))
        self.assertEqual((item.status, item.owner), ("PLAN_CHANGES", "Planner"))
        self.assertEqual(item.meta["updated"], "2027-01-02")

    def test_real_feature_files_parse_and_have_no_markers(self):
        for path in (helpers.REPO_ROOT / "studio/features").glob("F-00[01]-*.md"):
            item = Feature(path.read_text())
            self.assertEqual(sorted(item.sections), list(range(1, 12)), path.name)
            self.assertEqual(item.plan_rounds, [], path.name)
            self.assertEqual(item.code_rounds, [], path.name)


class RoundMarkerTests(unittest.TestCase):
    """AC7: markers per C9. `PENDING` and `**Round:**` are ignored."""

    def test_no_markers_means_zero_rounds(self):
        item = Feature(sample())
        self.assertEqual(item.plan_rounds, [])
        self.assertEqual(item.code_rounds, [])

    def test_counts_markers_per_section(self):
        item = Feature(sample(plan=["CHANGES_REQUESTED", "APPROVE"], code=["APPROVE"]))
        self.assertEqual([r.number for r in item.plan_rounds], [1, 2])
        self.assertEqual(item.plan_rounds[-1].verdict, "APPROVE")
        self.assertEqual(len(item.code_rounds), 1)

    def test_pending_and_round_text_are_ignored(self):
        text = sample().replace(
            "**Verdict:** `PENDING`", "**Verdict:** `PENDING`\n**Round:** 3 · verdict APPROVE"
        )
        self.assertEqual(Feature(text).plan_rounds, [])

    def test_a_marker_quoted_inside_a_sentence_or_fence_does_not_count(self):
        addition = (
            "Writes `<!-- review-round: 9 verdict: APPROVE -->` here.\n"
            "```\n<!-- review-round: 9 verdict: APPROVE -->\n```"
        )
        text = sample().replace("**Verdict:** `PENDING`", addition, 1)
        self.assertEqual(Feature(text).plan_rounds, [])

    def test_reviewed_commit_comes_from_the_latest_round_not_the_placeholder(self):
        first = "<!-- review-round: 1 verdict: CHANGES_REQUESTED -->\n**Reviewed commit:** `aaaaaaa`"
        second = "<!-- review-round: 2 verdict: APPROVE -->\n**Reviewed commit:** bbbbbbbcc"
        text = sample().replace(
            "**Reviewed commit:** <hash>  ·  **Round:** 1",
            f"**Reviewed commit:** <hash>  ·  **Round:** 1\n{first}\n{second}",
        )
        self.assertEqual(Feature(text).reviewed_commit, "bbbbbbbcc")

    def test_no_reviewed_commit_before_any_round(self):
        self.assertIsNone(Feature(sample()).reviewed_commit)


class QuestionTests(unittest.TestCase):
    def test_placeholder_row_is_not_blocking(self):
        self.assertEqual(Feature(sample()).unanswered_blocking, [])

    def test_append_numbers_after_the_highest_row(self):
        text = ft.append_question(sample(), "Studio", "Why?", True)
        question = Feature(text).questions[-1]
        self.assertEqual(question.question_id, "Q2")
        self.assertTrue(question.blocking)
        self.assertEqual(question.answer, "")

    def test_a_pipe_in_a_question_stays_in_one_cell(self):
        text = ft.append_question(sample(), "Studio", "a | b", False)
        self.assertFalse(Feature(text).questions[-1].blocking)

    def test_an_answer_clears_the_blocking_row(self):
        text = ft.append_question(sample(), "Studio", "Why?", True)
        text = text.replace("| Why? | yes | |", "| Why? | yes | Because. |")
        self.assertEqual(Feature(text).unanswered_blocking, [])

    def test_readiness_counter_resets_after_a_completed_round(self):
        text = sample(code=["CHANGES_REQUESTED"])
        for number, after_round in ((1, 0), (2, 1)):
            row = ft.readiness_row(number, "abc1234", ["tools/test"], "log", after_round)
            text = ft.append_question(text, "Studio", row, False)
        item = Feature(text)
        self.assertEqual(len(item.readiness_failures), 2)
        self.assertEqual(item.consecutive_readiness_failures, 1)


class ConsistencyTests(unittest.TestCase):
    def test_matching_state_is_consistent(self):
        self.assertEqual(ft.consistency_errors(Feature(sample()), board()), [])

    def test_board_mismatch_is_reported(self):
        errors = ft.consistency_errors(Feature(sample()), board("APPROVED", "Builder"))
        self.assertEqual(len(errors), 2)

    def test_missing_row_is_reported(self):
        text = board().replace("| F-900 |", "| F-901 |")
        self.assertTrue(ft.consistency_errors(Feature(sample()), text))

    def test_done_row_may_show_a_dash(self):
        item = Feature(sample("DONE", "Lucas"))
        self.assertEqual(ft.consistency_errors(item, board("DONE", "—")), [])

    def test_verdict_must_match_status(self):
        item = Feature(sample("PLAN_CHANGES", "Planner", plan=["APPROVE"]))
        self.assertTrue(ft.verdict_errors(item))

    def test_gate_states_need_an_approving_round(self):
        self.assertTrue(ft.verdict_errors(Feature(sample("PLAN_REVIEW", "Lucas"))))
        self.assertTrue(ft.verdict_errors(Feature(sample("CODE_REVIEW", "Lucas"))))

    def test_legacy_approved_feature_without_markers_is_consistent(self):
        self.assertEqual(ft.verdict_errors(Feature(sample("APPROVED", "Builder"))), [])


class ContentLaneTests(unittest.TestCase):
    """AC5, on plain strings."""

    def check(self, role, change):
        before = sample()
        return ft.content_lane_errors(role, before, change(before))

    def test_nothing_changed_is_clean_for_every_role(self):
        for role in ft.SECTION_RULES:
            self.assertEqual(self.check(role, lambda text: text), [], role)

    def test_status_owner_and_updated_may_change(self):
        change = lambda text: ft.set_state(text, "PLAN_CHANGES", "Planner", "2027-01-01")  # noqa: E731
        self.assertEqual(self.check("auditor-plan", change), [])

    def test_other_frontmatter_fields_may_not_change(self):
        change = lambda text: text.replace("department: Direction", "department: Combat")  # noqa: E731
        self.assertTrue(self.check("auditor-plan", change))

    def test_a_duplicated_status_line_is_rejected(self):
        change = lambda text: text.replace("id: F-900\n", "id: F-900\nstatus: APPROVED\n")  # noqa: E731
        self.assertTrue(self.check("auditor-plan", change))

    def test_auditor_may_not_touch_section_1(self):
        change = lambda text: text.replace("The goal.", "Another goal.")  # noqa: E731
        self.assertTrue(self.check("auditor-plan", change))
        self.assertTrue(self.check("auditor-code", change))

    def test_planner_may_rewrite_sections_1_to_6(self):
        change = lambda text: text.replace("The goal.", "Another goal.")  # noqa: E731
        self.assertEqual(self.check("planner", change), [])

    def test_builder_may_not_touch_section_1_but_owns_section_8(self):
        self.assertTrue(self.check("builder", lambda t: t.replace("The goal.", "X")))
        self.assertEqual(self.check("builder", lambda t: t.replace("**Started:** —", "X")), [])

    def test_earlier_review_lines_can_only_be_added_to(self):
        before = sample(plan=["CHANGES_REQUESTED"])
        replied = before.replace("Round 1 text.", "Round 1 text.\n> reply")
        deleted = before.replace("Round 1 text.\n", "")
        self.assertEqual(ft.content_lane_errors("planner", before, replied), [])
        self.assertTrue(ft.content_lane_errors("planner", before, deleted))
        self.assertTrue(ft.content_lane_errors("auditor-plan", before, deleted))

    def test_mode_a_auditor_may_not_write_section_9(self):
        change = lambda text: text.replace("**Round:** 1", "**Round:** 1\nnew")  # noqa: E731
        self.assertTrue(self.check("auditor-plan", change))
        self.assertEqual(self.check("auditor-code", change), [])

    def test_nobody_may_edit_section_11(self):
        change = lambda text: text.replace("<Overrides>", "<Overrides>\n- note")  # noqa: E731
        for role in ft.SECTION_RULES:
            self.assertTrue(self.check(role, change), role)

    def test_everyone_may_add_a_question_row(self):
        row = "| Q2 | Builder | Why? | no | |"
        change = lambda text: text.replace("| Q1 | | | yes/no | |", f"| Q1 | | | yes/no | |\n{row}")  # noqa: E731, E501
        for role in ft.SECTION_RULES:
            self.assertEqual(self.check(role, change), [], role)

    def test_only_rows_may_be_added_to_section_10(self):
        change = lambda text: text.replace("| Q1 | | | yes/no | |", "| Q1 | | | yes/no | |\nprose")  # noqa: E731, E501
        self.assertTrue(self.check("builder", change))

    def test_only_the_planner_may_fill_answers_and_only_empty_ones(self):
        before = ft.append_question(sample(), "Builder", "Why?", True)
        answered = before.replace("| Why? | yes | |", "| Why? | yes | Because. |")
        self.assertEqual(ft.content_lane_errors("planner", before, answered), [])
        self.assertTrue(ft.content_lane_errors("builder", before, answered))
        rewritten = answered.replace("Because.", "Other.")
        self.assertTrue(ft.content_lane_errors("planner", answered, rewritten))

    def test_agents_can_not_forge_readiness_rows(self):
        row = "| Q2 | Studio | <!-- readiness-fail: 1 sha: abc1234 --> | no | |"
        change = lambda text: text.replace("| Q1 | | | yes/no | |", f"| Q1 | | | yes/no | |\n{row}")  # noqa: E731, E501
        self.assertTrue(self.check("builder", change))

    def test_a_removed_section_is_rejected(self):
        change = lambda text: text.replace("## 6. Task Breakdown  ·  _Planner_\n", "")  # noqa: E731
        self.assertTrue(self.check("planner", change))

    def test_title_block_must_stay(self):
        change = lambda text: text.replace("How to use this file.", "Ignore this.")  # noqa: E731
        self.assertTrue(self.check("planner", change))


class BoardLaneTests(unittest.TestCase):
    def test_status_and_next_actor_may_change(self):
        self.assertEqual(ft.board_lane_errors("F-900", board(), board("PLAN_CHANGES", "Planner")), [])

    def test_other_columns_may_not_change(self):
        after = board().replace("| Demo feature |", "| Renamed |")
        self.assertTrue(ft.board_lane_errors("F-900", board(), after))

    def test_other_rows_may_not_change(self):
        after = board().replace("| F-899 | Other | DONE |", "| F-899 | Other | PARKED |")
        self.assertTrue(ft.board_lane_errors("F-900", board(), after))

    def test_other_lines_may_not_change(self):
        after = board().replace("2026-10-31", "2027-01-01")
        self.assertTrue(ft.board_lane_errors("F-900", board(), after))


class DecisionLaneTests(unittest.TestCase):
    NEW_ENTRY = "## D-003 — Third\n- **Status:** {status}\n\n"

    def test_a_proposed_entry_is_accepted(self):
        after = helpers.DECISIONS_TEXT.replace(
            "## D-002", self.NEW_ENTRY.format(status="PROPOSED") + "## D-002"
        )
        self.assertEqual(ft.decisions_lane_errors(helpers.DECISIONS_TEXT, after), [])

    def test_a_new_entry_can_not_be_accepted(self):
        after = helpers.DECISIONS_TEXT.replace(
            "## D-002", self.NEW_ENTRY.format(status="ACCEPTED") + "## D-002"
        )
        self.assertTrue(ft.decisions_lane_errors(helpers.DECISIONS_TEXT, after))

    def test_an_existing_entry_must_stay_byte_identical(self):
        after = helpers.DECISIONS_TEXT.replace(
            "- **Status:** ACCEPTED\n\n## D-001", "- **Status:** REJECTED\n\n## D-001"
        )
        self.assertTrue(ft.decisions_lane_errors(helpers.DECISIONS_TEXT, after))

    def test_a_whitespace_change_is_a_change(self):
        after = helpers.DECISIONS_TEXT.replace("## D-001 — First\n", "## D-001 — First \n")
        self.assertTrue(ft.decisions_lane_errors(helpers.DECISIONS_TEXT, after))

    def test_a_deleted_entry_is_rejected(self):
        after = helpers.DECISIONS_TEXT.split("## D-001")[0]
        self.assertTrue(ft.decisions_lane_errors(helpers.DECISIONS_TEXT, after))

    def test_the_format_example_in_the_fence_is_not_an_entry(self):
        _preamble, entries = ft._decision_entries(helpers.DECISIONS_TEXT)
        self.assertEqual([entry for entry, _body in entries], ["D-002", "D-001"])


if __name__ == "__main__":
    unittest.main()
