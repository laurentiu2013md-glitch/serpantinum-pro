#!/usr/bin/python3
"""Read Hyprland's global cursor without input overlays or hyprctl subprocesses.
Zone sampling runs at 12.5 Hz; the compositor plugin handles cursor motion and scaling at display refresh rate.
"""
import json, os, socket, time, signal, subprocess, sys, select
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

def command(directory, text):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(.3)
        client.connect(str(directory / '.socket.sock'))
        client.sendall(text.encode())
        result = client.recv(65536).decode()
        if 'error:' in result.lower():
            raise OSError(result.strip())
        return result

class NativeCursorEffect:
    def __init__(self, directory):
        self.directory = directory
        self.enabled = None
        self.scale = 1.0
        try:
            plugins = query(directory, 'plugin list')
            self.available = any(p.get('name') == 'dynamic-cursors' for p in plugins)
        except (OSError, ValueError, TypeError):
            self.available = False

    def enable(self, enabled):
        if self.enabled == enabled:
            return
        if self.available:
            if enabled:
                command(self.directory, 'eval hl.config({plugin={dynamic_cursors={enabled=true,shake={enabled=true}}}})')
            else:
                # Let a compositor tick release the magnification software-cursor lock.
                command(self.directory, 'eval hl.dispatch(hl.plugin.dynamic_cursors.dsp_magnify({size=1.0,duration=0})); hl.config({plugin={dynamic_cursors={enabled=true,shake={enabled=false}}}})')
                time.sleep(.03)
                command(self.directory, 'eval hl.config({plugin={dynamic_cursors={enabled=false}}})')
        self.enabled = enabled
        if not enabled: self.scale = 1.0

    def locate(self):
        if self.available and self.enabled:
            command(self.directory, 'eval hl.dispatch(hl.plugin.dynamic_cursors.dsp_magnify({size=3.0,duration=2000}))')


def main():
    directory = Path(os.environ['XDG_RUNTIME_DIR']) / 'hypr' / os.environ['HYPRLAND_INSTANCE_SIGNATURE']
    effect = NativeCursorEffect(directory)
    try:
        base_size = int(subprocess.check_output(['gsettings','get','org.gnome.desktop.interface','cursor-size'], text=True, timeout=1))
    except (OSError, ValueError, subprocess.SubprocessError):
        base_size = 24
    events = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    events.connect(str(directory / '.socket2.sock')); events.setblocking(False)
    event_buffer = ''
    previous, previous_zones = None, None
    monitors, refresh = [], 0
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        while True:
            if select.select([sys.stdin], [], [], 0)[0]:
                line = sys.stdin.readline().strip()
                try:
                    if line.startswith('effects '): effect.enable(line.endswith('1'))
                    elif line == 'locate': effect.locate()
                except OSError:
                    effect.available = False
            try:
                while True:
                    try: chunk = events.recv(65536)
                    except BlockingIOError: break
                    if not chunk: break
                    event_buffer += chunk.decode(errors='replace')
                lines = event_buffer.split('\n'); event_buffer = lines.pop()
                for line in lines:
                    if line.startswith('shakeupdate>>') and effect.enabled:
                        effect.scale = float(line.rsplit(',',1)[-1])
                    elif line.startswith('shakeend>>'):
                        effect.scale = 1.0
                now = time.monotonic()
                if now >= refresh:
                    monitors = query(directory, 'monitors'); refresh = now + 5
                    available = any(item.get('name') == 'dynamic-cursors' for item in query(directory, 'plugin list'))
                    if available != effect.available:
                        previous_enabled = effect.enabled
                        effect.available = available
                        if available:
                            effect.enabled = None
                            effect.enable(previous_enabled is not False)
                current = zones(monitors, query(directory, 'cursorpos'), previous_zones)
                previous_zones = current.copy()
            except (OSError, ValueError, KeyError):
                current = {}; refresh = 0
            current['_cursorSize'] = round(base_size * effect.scale)
            current['_cursorScale'] = round(effect.scale, 3)
            current['_cursorNative'] = effect.available
            if current != previous:
                print(json.dumps(current), flush=True); previous = current
            time.sleep(.08)
    finally:
        try:
            if effect.available: command(directory, 'eval hl.dispatch(hl.plugin.dynamic_cursors.dsp_magnify({size=1.0,duration=0}))')
        except OSError: pass
        events.close()

if __name__ == '__main__': main()
