#!/usr/bin/env python3
"""Attach a private screenshot to the installed ChatGPT app using its composer."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import sys
import threading
import time


def run(args, **kwargs):
    return subprocess.run(args, check=True, timeout=10, **kwargs)


def notify(message, critical=False):
    subprocess.run(["notify-send", "-a", "Screenshot", "-u",
                    "critical" if critical else "normal", "ChatGPT screenshot", message],
                   check=False, timeout=5)


def clients():
    result = run(["hyprctl", "-j", "clients"], capture_output=True, text=True)
    return json.loads(result.stdout)


def app_window():
    for window in clients():
        if window.get("class", "").lower() not in {"chatgpt", "codex", "com.openai.codex"}:
            continue
        address = window.get("address", "")
        if re.fullmatch(r"0x[0-9a-fA-F]+", address) and window.get("mapped", True):
            return address
    return None


def dispatch(expression):
    result = run(["hyprctl", "dispatch", expression], capture_output=True, text=True)
    if result.stdout.strip() != "ok":
        raise RuntimeError(result.stdout.strip() or result.stderr.strip() or "Desktop action failed")


def attach(image, delete_after_paste):
    for command in ("chatgpt", "wl-copy", "hyprctl", "notify-send"):
        if not shutil.which(command):
            raise RuntimeError(f"Required command is missing: {command}")
    with image.open("rb") as source:
        if source.read(8) != b"\x89PNG\r\n\x1a\n":
            raise RuntimeError("The screenshot is not a valid PNG")

    # The documented image-paste workflow respects the model chosen in the app.
    # A new draft avoids overwriting an existing chat's composer or submitting a prompt.
    run(["chatgpt", "codex://threads/new"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.monotonic() + 25
    address = None
    while time.monotonic() < deadline:
        address = app_window()
        if address:
            break
        time.sleep(0.2)
    if not address:
        raise RuntimeError("ChatGPT did not open a window")

    dispatch('hl.dsp.focus({window="address:' + address + '"})')
    # Let the application's new-chat navigation focus its composer before pasting.
    time.sleep(1.2)
    clipboard = None
    try:
        with image.open("rb") as source:
            # Request exclusion from clipboard history. Clipboard watchers also read
            # new offers, so acknowledge only requests after the targeted app paste.
            requests = queue.Queue()
            clipboard = subprocess.Popen(
                ["wl-copy", "--foreground", "--sensitive", "--type", "image/png"],
                stdin=source, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                text=True, env={**os.environ, "WAYLAND_DEBUG": "client"})

            def read_requests():
                for line in clipboard.stderr:
                    if '.send("image/png",' in line:
                        requests.put(time.monotonic())

            reader = threading.Thread(target=read_requests, daemon=True)
            reader.start()
            time.sleep(0.7)
            if clipboard.poll() is not None:
                raise RuntimeError("Could not offer the screenshot on the clipboard")
            if app_window() != address:
                raise RuntimeError("The ChatGPT window changed before attachment")
            paste_time = time.monotonic()
            dispatch('hl.dsp.send_shortcut({mods="CTRL",key="V",window="address:' + address + '"})')
            deadline = time.monotonic() + 12
            while True:
                try:
                    requested_at = requests.get(timeout=max(0.01, deadline - time.monotonic()))
                except queue.Empty as error:
                    raise RuntimeError("ChatGPT did not accept the image; capture kept for retry") from error
                if requested_at >= paste_time:
                    break
                if time.monotonic() >= deadline:
                    raise RuntimeError("ChatGPT did not accept the image; capture kept for retry")
            # Let the compositor's data pipe finish delivering the image bytes.
            time.sleep(0.5)
        if delete_after_paste:
            image.unlink()
            if image.parent.name.startswith("serpantinum-chatgpt."):
                image.parent.rmdir()
        notify("Image attached to a new ChatGPT draft. Choose your model, add a question, and Send. "
               + ("Temporary capture deleted." if delete_after_paste else ""))
    finally:
        if clipboard is not None and clipboard.poll() is None:
            clipboard.terminate()
            try:
                clipboard.wait(timeout=2)
            except subprocess.TimeoutExpired:
                clipboard.kill()
                clipboard.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--delete-after-paste", action="store_true")
    args = parser.parse_args()
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    with (runtime / "serpantinum-chatgpt.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            notify(f"Another screenshot is being attached. This capture is kept at {args.image}", True)
            return 1
        try:
            attach(args.image.resolve(), args.delete_after_paste)
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            print(f"ChatGPT screenshot: {error}", file=sys.stderr)
            notify(f"{error}\nCapture kept at: {args.image}", True)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
