"""AC11 and AC13: prompts carry pointers only, and the role documents say what the tool needs."""

import re
import unittest

from helpers import (
    FEATURE,
    REPO_ROOT,
    Sandbox,
    auditor_code,
    auditor_plan,
    builder_ok,
    planner_ok,
)


class PromptTests(unittest.TestCase):
    def prompts(self):
        with Sandbox("PLAN_REVIEW", "Auditor") as box:
            box.script(auditor_plan(1, "CHANGES_REQUESTED"), planner_ok(), auditor_plan(2))
            box.studio("run", "F-900")
            plan_calls = box.calls()
        with Sandbox("APPROVED", "Builder") as box:
            box.script(builder_ok(), auditor_code())
            box.studio("run", "F-900")
            code_calls = box.calls()
        return [call["prompt"] for call in plan_calls + code_calls]

    def test_each_prompt_starts_with_its_role_line(self):
        first_lines = [prompt.split("\n")[0] for prompt in self.prompts()]
        self.assertEqual(
            first_lines,
            [
                "STUDIO-ROLE: Auditor:ModeA",
                "STUDIO-ROLE: Planner:Direction",
                "STUDIO-ROLE: Auditor:ModeA",
                "STUDIO-ROLE: Builder",
                "STUDIO-ROLE: Auditor:ModeB",
            ],
        )

    def test_prompts_contain_only_file_pointers(self):
        for prompt in self.prompts():
            body = [line for line in prompt.split("\n")[1:] if line.strip()]
            self.assertEqual(len(body), 1, prompt)
            self.assertIn(FEATURE, body[0])
            words = re.sub(r"`[^`]+`", "", body[0]).split()
            self.assertLessEqual(len(words), 5, prompt)
            for leak in ("Demo feature", "The goal", "APPROVED", "CODE_REVIEW"):
                self.assertNotIn(leak, prompt)

    def test_planner_department_comes_from_the_feature(self):
        with Sandbox("PLAN_CHANGES", "Planner", plan_rounds=["CHANGES_REQUESTED"]) as box:
            box.write("studio/departments/combat.md", "# Combat\n")
            box.write(FEATURE, box.read(FEATURE).replace("department: Direction", "department: Combat"))
            box.commit_all("combat owns it", FEATURE, "studio/departments/combat.md")
            box.script(planner_ok())
            box.studio("run", "F-900", "--max-steps", "1")
            prompt = box.calls()[0]["prompt"]
            self.assertTrue(prompt.startswith("STUDIO-ROLE: Planner:Combat\n"))
            self.assertIn("`studio/departments/combat.md`", prompt)

    def test_a_missing_brief_refuses_before_any_call(self):
        with Sandbox("PLAN_CHANGES", "Planner", plan_rounds=["CHANGES_REQUESTED"]) as box:
            box.write(FEATURE, box.read(FEATURE).replace("department: Direction", "department: Lore"))
            box.commit_all("no brief", FEATURE)
            self.assertEqual(box.studio("run", "F-900").returncode, 1)
            self.assertEqual(box.calls(), [])
            self.assertFalse(box.is_blocked())


class RoleDocumentTests(unittest.TestCase):
    """T9: the instructions agents load must not contradict automated calls."""

    def read(self, path):
        return (REPO_ROOT / path).read_text()

    def test_claude_md_has_the_studio_role_section(self):
        text = self.read("CLAUDE.md")
        self.assertIn("## Automated sessions (`STUDIO-ROLE`)", text)
        self.assertIn("`STUDIO-ROLE: Planner:<Department>`", text)
        self.assertIn("**edit files in place**", text)
        self.assertIn("never set `APPROVED` or `DONE`", text)

    def test_claude_md_says_the_branch_is_provided(self):
        self.assertIn("The branch is provided", self.read("CLAUDE.md"))

    def test_claude_md_allows_in_progress_only_through_resume(self):
        self.assertIn("`IN_PROGRESS` in\n     a session started by `tools/studio run --resume`", self.read("CLAUDE.md"))

    def test_agents_md_defines_the_round_marker_and_reviewed_commit(self):
        text = self.read("AGENTS.md")
        self.assertIn("`<!-- review-round: N verdict: <VERDICT> -->`", text)
        self.assertIn("**Reviewed commit:**", text)
        self.assertIn("`STUDIO-ROLE: Auditor:ModeA`", text)

    def test_template_has_no_round_placeholder(self):
        text = self.read("studio/features/_TEMPLATE.md")
        self.assertNotIn("**Round:**", text)
        self.assertNotIn("PENDING", text)

    def test_every_department_brief_has_the_in_place_rule(self):
        briefs = [
            path
            for path in (REPO_ROOT / "studio/departments").glob("*.md")
            if path.name != "README.md"
        ]
        self.assertGreaterEqual(len(briefs), 2)
        for brief in briefs:
            text = brief.read_text()
            self.assertIn("**edits the files in\nplace**", text, brief.name)
            self.assertIn("studio/prompts/autopilot-planner.md", text, brief.name)

    def test_autopilot_planner_prompt_exists(self):
        self.assertIn("edit the files in place", self.read("studio/prompts/autopilot-planner.md"))

    def test_readme_documents_the_autopilot(self):
        text = self.read("README.md")
        for needle in (
            "## Autopilot",
            "STUDIO_CLAUDE_BIN",
            "STUDIO_CODEX_BIN",
            "STUDIO_NTFY_TOPIC",
            "--permission-mode dontAsk",
            "codex exec --sandbox workspace-write",
            "### Recovery",
            "can only be detected",
        ):
            self.assertIn(needle, text)

    def test_handoffs_point_to_the_commands(self):
        self.assertIn("tools/studio run F-XXX", self.read("studio/prompts/handoffs.md"))

    def test_studio_state_is_gitignored(self):
        self.assertIn(".studio/", self.read(".gitignore").split())


if __name__ == "__main__":
    unittest.main()
