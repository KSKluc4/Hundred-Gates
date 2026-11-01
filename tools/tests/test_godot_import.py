"""tools/_godot.sh: importing must not let Godot save the editor's open tabs (F-002 §8)."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from helpers import TOOLS_DIR

FAKE_GODOT = """#!/bin/sh
[ -f "$PROBE_LAYOUT" ] && echo present >> "$PROBE_OUT" || echo hidden >> "$PROBE_OUT"
echo rewritten-by-godot > "$PROBE_LAYOUT"
exit "${PROBE_EXIT:-0}"
"""


class GodotImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(os.path.realpath(self.temp.name))
        self.editor = root / ".godot" / "editor"
        self.editor.mkdir(parents=True)
        self.layout = self.editor / "editor_layout.cfg"
        self.hidden = self.editor / "editor_layout.cfg.hidden-for-import"
        self.probe = root / "probe"
        self.godot = root / "fake_godot"
        self.godot.write_text(FAKE_GODOT)
        self.godot.chmod(0o755)
        tools = root / "tools"
        tools.mkdir()
        (tools / "_godot.sh").write_text((TOOLS_DIR / "_godot.sh").read_text())

    def run_import(self, exit_code=0):
        script = f'source "{self.layout.parents[2]}/tools/_godot.sh"; godot_import "{self.godot}"'
        env = {
            **os.environ,
            "PROBE_LAYOUT": str(self.layout),
            "PROBE_OUT": str(self.probe),
            "PROBE_EXIT": str(exit_code),
        }
        return subprocess.run(["bash", "-c", script], env=env, capture_output=True, text=True)

    def test_the_tab_list_is_hidden_during_the_import_and_restored(self):
        self.layout.write_text("open_scripts=[DECISIONS.md]\n")
        self.assertEqual(self.run_import().returncode, 0)
        self.assertEqual(self.probe.read_text().strip(), "hidden")
        self.assertEqual(self.layout.read_text(), "open_scripts=[DECISIONS.md]\n")
        self.assertFalse(self.hidden.exists())

    def test_a_failed_import_still_restores_and_reports_failure(self):
        self.layout.write_text("tabs\n")
        self.assertEqual(self.run_import(exit_code=3).returncode, 3)
        self.assertEqual(self.layout.read_text(), "tabs\n")

    def test_a_list_left_by_an_interrupted_run_is_recovered(self):
        self.hidden.write_text("from the interrupted run\n")
        self.layout.write_text("newer\n")
        self.run_import()
        self.assertEqual(self.layout.read_text(), "from the interrupted run\n")

    def test_a_project_never_opened_in_the_editor_is_fine(self):
        self.assertEqual(self.run_import().returncode, 0)
        self.assertEqual(self.probe.read_text().strip(), "hidden")


if __name__ == "__main__":
    unittest.main()
