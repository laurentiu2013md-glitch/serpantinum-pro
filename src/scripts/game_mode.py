#!/usr/bin/env python3
"""Apply reversible compositor settings; never kill apps or flush kernel caches."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

OPTIONS = {
    "decoration.blur.enabled": False,
    "decoration.shadow.enabled": False,
    "animations.enabled": False,
    "debug.vfr": True,
}
STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "serpantinum/game-mode.json"


def hyprctl(*args):
    result = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=10)
    output = result.stdout.strip()
    if result.returncode or not output or any(word in output.lower() for word in ("error", "unknown", "no such option")):
        raise RuntimeError(result.stderr.strip() or output or "Hyprland did not accept the request")
    return output


def capture():
    values = {}
    for name in OPTIONS:
        try:
            value = json.loads(hyprctl("-j", "getoption", name))
        except json.JSONDecodeError as error:
            raise RuntimeError("Hyprland returned an invalid value for " + name) from error
        for key in ("bool", "int"):
            if key in value and isinstance(value[key], (bool, int)):
                values[name] = bool(value[key])
                break
        else:
            raise RuntimeError("Cannot read Hyprland setting: " + name)
    return values


def apply(values):
    if set(values) != set(OPTIONS) or any(type(v) is not bool for v in values.values()):
        raise RuntimeError("Invalid Game Mode restore settings")
    fields = ["[" + json.dumps(k) + "] = " + str(v).lower() for k, v in values.items()]
    hyprctl("-r", "eval", "hl.config({" + ", ".join(fields) + "})")


def write_state(state):
    fd, temporary = tempfile.mkstemp(prefix=".game-mode-", dir=STATE.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(state, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, STATE)
    finally:
        Path(temporary).unlink(missing_ok=True)


def transition(action):
    if action not in ("enable", "disable", "reapply"):
        raise RuntimeError("Expected enable, disable, or reapply")
    STATE.parent.mkdir(parents=True, exist_ok=True)
    with (STATE.parent / ".game-mode.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            previous = json.loads(STATE.read_text())
            if not isinstance(previous, dict):
                raise ValueError("Expected a Game Mode state object")
        except FileNotFoundError:
            previous = {"enabled": False}
        enabled = previous.get("enabled") is True
        if (action == "reapply" or action == "disable") and not enabled:
            return
        session = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
        if not session:
            raise RuntimeError("Game Mode requires a running Hyprland session")
        if action == "disable":
            # A new compositor has its own freshly loaded settings.
            if previous.get("session") == session:
                apply(previous.get("restore", {}))
            write_state({"enabled": False})
            return
        current = capture()
        restore = previous["restore"] if enabled and previous.get("session") == session else current
        # Save recovery data before touching the compositor.
        write_state({"enabled": True, "session": session, "restore": restore})
        try:
            apply(OPTIONS)
        except Exception:
            # Keep recovery data if rolling back also fails.
            apply(current)
            write_state(previous)
            raise


if __name__ == "__main__":
    try:
        transition(sys.argv[1] if len(sys.argv) == 2 else "")
    except Exception as error:
        print("Game Mode: " + str(error), file=sys.stderr)
        sys.exit(1)
