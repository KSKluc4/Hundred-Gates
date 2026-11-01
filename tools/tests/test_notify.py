"""F-002/C20: one exact next command, and a failed notification never fails anything."""

import http.server
import threading
import unittest

from helpers import Sandbox, auditor_code, builder_ok


class Receiver(http.server.BaseHTTPRequestHandler):
    bodies: list = []

    def do_POST(self):  # noqa: N802 - http.server's API
        length = int(self.headers["Content-Length"])
        Receiver.bodies.append((self.path, self.rfile.read(length).decode()))
        self.send_response(200)
        self.end_headers()

    def log_message(self, *_args):
        pass


class NotifyTests(unittest.TestCase):
    def test_notify_test_reaches_osascript(self):
        with Sandbox() as box:
            result = box.studio("notify-test")
            self.assertEqual(result.returncode, 0)
            self.assertEqual(len(box.notifications()), 1)
            self.assertIn("Next: tools/studio status", box.notifications()[0])

    def test_message_has_feature_event_and_one_next_command(self):
        with Sandbox("APPROVED", "Builder") as box:
            box.script(builder_ok(), auditor_code())
            box.studio("run", "F-900")
            message = box.notifications()[0]
            self.assertTrue(message.startswith("F-900: ready to play"))
            self.assertEqual(message.count("Next:"), 1)
            self.assertTrue(message.endswith("Next: tools/studio done F-900"))

    def test_message_text_travels_in_argv_not_in_the_script(self):
        with Sandbox() as box:
            (box.bin_dir / "osascript").write_text(
                f'#!/bin/sh\nprintf "%s\\n" "$@" > "{box.fake_dir}/argv"\n'
            )
            box.studio("notify-test")
            lines = (box.fake_dir / "argv").read_text()
            script, message = lines.split("end run\n")
            self.assertNotIn("notifications work", script)
            self.assertIn("notifications work", message)

    def test_a_failing_osascript_fails_nothing(self):
        with Sandbox("DRAFT", "Planner") as box:
            (box.bin_dir / "osascript").write_text("#!/bin/sh\nexit 1\n")
            self.assertEqual(box.studio("run", "F-900").returncode, 0)
            self.assertEqual(box.studio("notify-test").returncode, 0)

    def test_missing_osascript_fails_nothing(self):
        with Sandbox("DRAFT", "Planner") as box:
            (box.bin_dir / "osascript").unlink()
            box.env["PATH"] = f"{box.bin_dir}:/usr/bin/false-path"
            self.assertEqual(box.studio("notify-test").returncode, 0)

    def test_ntfy_is_used_only_when_a_topic_is_set(self):
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Receiver)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            Receiver.bodies = []
            with Sandbox() as box:
                box.env["STUDIO_NTFY_SERVER"] = f"http://127.0.0.1:{server.server_address[1]}"
                box.studio("notify-test")
                self.assertEqual(Receiver.bodies, [])
                box.env["STUDIO_NTFY_TOPIC"] = "studio-test"
                box.studio("notify-test")
                self.assertEqual(len(Receiver.bodies), 1)
                self.assertEqual(Receiver.bodies[0][0], "/studio-test")
                self.assertIn("Next: tools/studio status", Receiver.bodies[0][1])
        finally:
            server.shutdown()
            server.server_close()

    def test_an_unreachable_ntfy_server_fails_nothing(self):
        with Sandbox("DRAFT", "Planner") as box:
            box.env["STUDIO_NTFY_TOPIC"] = "studio-test"
            box.env["STUDIO_NTFY_SERVER"] = "http://127.0.0.1:9"
            self.assertEqual(box.studio("run", "F-900").returncode, 0)


if __name__ == "__main__":
    unittest.main()
