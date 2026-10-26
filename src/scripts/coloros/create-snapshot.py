#!/usr/bin/env python3
"""Capture a private, self-contained reset snapshot of the installed shell."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, default=Path.home(), help='Source home (also useful for isolated tests)')
    parser.add_argument('--output', type=Path, default=Path.home() / 'quickshellconf')
    args = parser.parse_args()
    home, output = args.home.expanduser().resolve(), args.output.expanduser().resolve()
    if output.exists():
        parser.error(f'{output} already exists; rename it before creating a new snapshot')
    sets = {
        'core': ['.local/share/serpantinum', '.config/serpantinum', '.config/quickshell',
                 '.local/bin/quickshell-lowram', '.local/bin/serpantinum', '.local/bin/serpantinumd',
                 '.local/bin/shellreset', '.local/bin/serpantinum-snapshot', '.config/fish/functions/shellreset.fish'],
        'state': ['.local/state/serpantinum'],
        'desktop': ['.config/hypr', '.config/matugen', '.config/gtk-3.0', '.config/gtk-4.0', '.config/qt6ct'],
    }
    for group, paths in sets.items():
        sets[group] = [p for p in paths if os.path.lexists(home / p)]
    if '.local/share/serpantinum' not in sets['core']:
        parser.error('No installed Serpantinum tree found in the source home')
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix='.serpantinum-snapshot-', dir=output.parent))
    try:
        payload = staging / 'home'
        for paths in sets.values():
            for rel in paths:
                source, destination = home / rel, payload / rel
                destination.parent.mkdir(parents=True, exist_ok=True)
                if source.is_symlink():
                    destination.symlink_to(os.readlink(source))
                elif source.is_dir():
                    shutil.copytree(source, destination, symlinks=True)
                else:
                    shutil.copy2(source, destination)
        entries = []
        for path in sorted(payload.rglob('*')):
            rel = str(path.relative_to(payload))
            if path.is_symlink():
                entries.append({'path': rel, 'kind': 'symlink', 'target': os.readlink(path)})
            elif path.is_file():
                with path.open('rb') as stream:
                    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
                entries.append({'path': rel, 'kind': 'file', 'bytes': path.stat().st_size, 'sha256': digest})
        manifest = {'format': 1, 'created': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    'source_home': str(home), 'sets': sets, 'entries': entries}
        (staging / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        shutil.copy2(Path(__file__).with_name('restore-snapshot.sh'), staging / 'restore.sh')
        (staging / 'restore.sh').chmod(0o700)
        (staging / 'README.md').write_text('# Private Serpantinum snapshot\n\n'
            'Preview: `./restore.sh --all --dry-run`. Restore: `./restore.sh --all`.\n\n'
            'Default restore replaces core shell paths; --state includes saved data; --desktop includes Hyprland and theme configs. '
            'Existing targets are backed up under ~/.local/state/quickshellconf-backups/. '
            'Directory replacement removes stale files from selected targets. The shell is not restarted automatically. '
            'Stop it before restoring, then log in again.\n\n'
            'manifest.json lists every file and symlink with integrity checks. External files referenced by settings '
            '(wallpapers, downloads and fonts), OS packages and Bluetooth pairing keys are not included. '
            'Absolute home paths are preserved: this snapshot primarily restores the original account. '
            'Contains personal configuration and saved state; keep it private.\n')
        staging.rename(output)
        print(f'Saved {len(entries)} files/links to {output}; existing snapshots were not overwritten.')
    finally:
        if staging.exists():
            shutil.rmtree(staging)


if __name__ == '__main__':
    main()
