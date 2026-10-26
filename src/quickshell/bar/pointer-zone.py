#!/usr/bin/python3
"""Read Hyprland's global cursor without input overlays or hyprctl subprocesses.
A single helper samples at 12.5 Hz; only zone transitions reach QML.
"""
import json, os, socket, time
from pathlib import Path

def query(directory, command):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(.3)
        client.connect(str(directory / '.socket.sock'))
        client.sendall(('j/' + command).encode())
        chunks = []
        while chunk := client.recv(65536):
            chunks.append(chunk)
        return json.loads(b''.join(chunks))

def zones(monitors, cursor, previous=None):
    result = {}
    for monitor in monitors:
        if monitor.get('disabled'): continue
        scale = monitor.get('scale', 1) or 1
        width, height = monitor['width'], monitor['height']
        if monitor.get('transform', 0) % 2: width, height = height, width
        x, y = cursor['x'] - monitor['x'], cursor['y'] - monitor['y']
        # A tiny deadband prevents repeated reversals when hovering at the boundary.
        was_upper = (previous or {}).get(monitor['name'])
        deadband = 4 if was_upper is True else -4 if was_upper is False else 0
        result[monitor['name']] = 0 <= x < width / scale and 0 <= y < height / scale * .10 + deadband
    return result

def main():
    directory = Path(os.environ['XDG_RUNTIME_DIR']) / 'hypr' / os.environ['HYPRLAND_INSTANCE_SIGNATURE']
    previous = None
    monitors = []; refresh = 0
    while True:
        try:
            if time.monotonic() >= refresh:
                monitors = query(directory, 'monitors'); refresh = time.monotonic() + 5
            current = zones(monitors, query(directory, 'cursorpos'), previous)
        except (OSError, ValueError, KeyError):
            current = {}  # Fail open: retain access to the complete bar.
            refresh = 0
        if current != previous:
            print(json.dumps(current), flush=True); previous = current
        time.sleep(.08)

if __name__ == '__main__': main()
