#!/usr/bin/env python3
"""Verify root through PAM-backed su before revealing one saved Wi-Fi PSK.

The authentication password is accepted only on stdin. Neither password is
written to disk or passed in process arguments; stdout is a private UI pipe.
"""
import json
import subprocess
import sys
import uuid
from gi.repository import Gio, GLib

BUS = "org.freedesktop.NetworkManager"
INTERFACE = BUS + ".Settings.Connection"


def verify_root(password):
    if not password or len(password) > 4096 or any(c in password for c in "\r\n\x00"):
        return False
    result = subprocess.run(
        ["/usr/bin/su", "--shell", "/bin/sh", "--command", "/usr/bin/true", "root"],
        input=password + "\n", text=True, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, timeout=15, cwd="/",
        env={"PATH": "/usr/bin:/bin", "LANG": "C", "TERM": "dumb"},
    )
    return result.returncode == 0


def saved_password(ident):
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    paths = bus.call_sync(BUS, "/org/freedesktop/NetworkManager/Settings", BUS + ".Settings",
                          "ListConnections", None, None, Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]
    for path in paths:
        settings = bus.call_sync(BUS, path, INTERFACE, "GetSettings", None, None,
                                 Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]
        connection = settings.get("connection", {})
        if connection.get("uuid") != ident:
            continue
        if connection.get("type") != "802-11-wireless":
            return {"error": "Select a saved Wi-Fi network."}
        security = settings.get("802-11-wireless-security", {})
        if not security:
            return {"status": "This network has no password."}
        if security.get("key-mgmt") not in ["wpa-psk", "sae"]:
            return {"error": "Password display supports personal WPA/WPA2/WPA3 networks."}
        secrets = bus.call_sync(BUS, path, INTERFACE, "GetSecrets",
                               GLib.Variant("(s)", ("802-11-wireless-security",)), None,
                               Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]
        password = secrets.get("802-11-wireless-security", {}).get("psk", "")
        return {"password": password} if password else {"error": "The saved password is unavailable."}
    return {"error": "The selected Wi-Fi network no longer exists."}


def reveal(request):
    ident = str(uuid.UUID(request["uuid"]))
    if not verify_root(request.get("password", "")):
        return {"error": "Root verification failed. Check the password and try again."}
    return saved_password(ident)


def main():
    try:
        request = json.loads(sys.stdin.readline(16384))
        result = reveal(request)
    except (ValueError, TypeError, KeyError, OSError, GLib.Error, subprocess.SubprocessError):
        result = {"error": "Could not verify or read this saved Wi-Fi password."}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
