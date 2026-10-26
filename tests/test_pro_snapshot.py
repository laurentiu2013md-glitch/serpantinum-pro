"""Isolated tests: never write to the real user home or start a desktop shell."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CREATE = ROOT / 'src/scripts/coloros/create-snapshot.py'


class SnapshotTests(unittest.TestCase):
    def test_capture_restore_and_repeat(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home, snapshot, target = root/'source', root/'snapshot', root/'target'
            for name, content in [('.local/share/serpantinum/src/example.qml', 'source'),
                                  ('.config/serpantinum/settings.json', '{"test":true}'),
                                  ('.local/state/serpantinum/notes.txt', 'private note'),
                                  ('.config/hypr/hyprland.lua', '-- custom bindings')]:
                path = home/name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text(content)
            (home/'.local/bin').mkdir(parents=True)
            (home/'.local/bin/serpantinum').symlink_to('../share/serpantinum/bin/serpantinum')
            subprocess.run(['python3', str(CREATE), '--home', str(home), '--output', str(snapshot)], check=True, capture_output=True)
            original = target/'.config/serpantinum'; original.mkdir(parents=True); (original/'stale').write_text('old')
            script = snapshot/'restore.sh'
            subprocess.run([str(script), '--all', '--target-home', str(target), '--dry-run'], check=True, capture_output=True)
            self.assertTrue((original/'stale').exists())
            subprocess.run([str(script), '--all', '--target-home', str(target)], check=True, capture_output=True)
            self.assertFalse((original/'stale').exists())
            self.assertEqual((target/'.local/state/serpantinum/notes.txt').read_text(), 'private note')
            for entry in json.loads((snapshot/'manifest.json').read_text())['entries']:
                path = target/entry['path']
                if entry['kind'] == 'symlink': self.assertEqual(os.readlink(path), entry['target'])
                else: self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), entry['sha256'])
            backups = list((target/'.local/state/quickshellconf-backups').iterdir())
            self.assertEqual((backups[0]/'home/.config/serpantinum/stale').read_text(), 'old')
            subprocess.run([str(script), '--target-home', str(target)], check=True, capture_output=True)
            self.assertEqual(len(list((target/'.local/state/quickshellconf-backups').iterdir())), 2)
            refusal = subprocess.run(['python3', str(CREATE), '--home', str(home), '--output', str(snapshot)], capture_output=True)
            self.assertNotEqual(refusal.returncode, 0)

    def test_corruption_and_mid_commit_rollback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); snapshot, target = root/'snapshot', root/'target'
            (snapshot/'home/blocked').mkdir(parents=True); target.mkdir()
            for name, content in [('a', 'new A'), ('blocked/b', 'new B')]: (snapshot/'home'/name).write_text(content)
            shutil.copy2(CREATE.with_name('restore-snapshot.sh'), snapshot/'restore.sh')
            (snapshot/'restore.sh').chmod(0o700)
            entries = [{'path':p, 'kind':'file', 'sha256':hashlib.sha256((snapshot/'home'/p).read_bytes()).hexdigest()} for p in ['a', 'blocked/b']]
            (snapshot/'manifest.json').write_text(json.dumps({'sets':{'core':['a', 'blocked/b']}, 'entries':entries}))
            (target/'a').write_text('original'); (target/'blocked').write_text('blocking file')
            result = subprocess.run([str(snapshot/'restore.sh'), '--target-home', str(target)], capture_output=True)
            self.assertNotEqual(result.returncode, 0); self.assertEqual((target/'a').read_text(), 'original')
            (snapshot/'home/a').write_text('corrupt')
            result = subprocess.run([str(snapshot/'restore.sh'), '--target-home', str(target)], capture_output=True)
            self.assertNotEqual(result.returncode, 0); self.assertIn(b'verification FAILED', result.stderr)
            self.assertEqual((target/'a').read_text(), 'original')

    def test_shellreset_forwards_to_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            snapshot = Path(directory); (snapshot/'restore.sh').write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n'); (snapshot/'restore.sh').chmod(0o700)
            env = dict(os.environ, SERPANTINUM_SNAPSHOT_DIR=str(snapshot))
            result = subprocess.run([str(ROOT/'bin/shellreset'), '--dry-run'], env=env, check=True, capture_output=True, text=True)
            self.assertEqual(result.stdout.splitlines(), ['--all', '--dry-run'])


if __name__ == '__main__': unittest.main()
