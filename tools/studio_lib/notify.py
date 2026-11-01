"""Notifications (F-002/C20). A failed notification never fails the command."""

from __future__ import annotations

import os
import shutil
import subprocess
import urllib.request

TITLE = "Hundred Gates studio"
DEFAULT_NTFY_SERVER = "https://ntfy.sh"
TIMEOUT_SECONDS = 10


def _osascript(message: str) -> None:
    binary = shutil.which("osascript")
    if not binary:
        return
    # Text goes in argv, never into the script, so no message can break out of it.
    script = (
        "on run argv",
        "display notification (item 1 of argv) with title (item 2 of argv)",
        "end run",
    )
    args = [binary]
    for line in script:
        args += ["-e", line]
    subprocess.run(args + [message, TITLE], capture_output=True, timeout=TIMEOUT_SECONDS)


def _ntfy(message: str) -> None:
    topic = os.environ.get("STUDIO_NTFY_TOPIC")
    if not topic:
        return
    server = os.environ.get("STUDIO_NTFY_SERVER", DEFAULT_NTFY_SERVER).rstrip("/")
    request = urllib.request.Request(
        f"{server}/{topic}", data=message.encode(), headers={"Title": TITLE}, method="POST"
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS):
        pass


def send(feature: str, what: str, next_command: str) -> str:
    """Feature, what happened, one exact next command."""
    message = f"{feature}: {what}\nNext: {next_command}"
    print(message)
    for channel in (_osascript, _ntfy):
        try:
            channel(message)
        except Exception as error:  # noqa: BLE001 - C20: never fails the command
            print(f"warning: notification failed: {error}")
    return message
