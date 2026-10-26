#!/usr/bin/env bash
# Restore this snapshot as the current user. No sudo or package installation.
set -euo pipefail
bundle=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec python3 - "$bundle" "$@" <<'PY'
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import sys
import tempfile

bundle = Path(sys.argv[1])
parser = argparse.ArgumentParser(description='Overwrite the shell setup from this snapshot, backing up existing targets first.')
parser.add_argument('--desktop', action='store_true', help='Also replace Hyprland, Matugen, GTK3/4 and Qt6ct configuration directories.')
parser.add_argument('--state', action='store_true', help='Also replace saved Serpantinum state, including notes and shelf entries.')
parser.add_argument('--all', action='store_true', help='Restore core, desktop configuration and saved state.')
parser.add_argument('--dry-run', action='store_true', help='Verify and list selected replacements without writing anything.')
parser.add_argument('--verify-only', action='store_true', help='Check selected snapshot files without restoring.')
parser.add_argument('--target-home', type=Path, default=Path.home(), help='Destination home directory; defaults to your home. Useful for isolated testing.')
args = parser.parse_args(sys.argv[2:])
target = args.target_home.expanduser().resolve()
if target == Path('/') or target == bundle or bundle in target.parents:
    parser.error('Choose a home directory outside the snapshot; refusing root or a directory inside the snapshot.')
manifest = json.loads((bundle / 'manifest.json').read_text())
groups = ['core'] + (['desktop'] if args.desktop or args.all else []) + (['state'] if args.state or args.all else [])
selected = [rel for group in groups for rel in manifest['sets'][group]]
def safe_relative(value):
    rel = Path(value)
    if rel.is_absolute() or '..' in rel.parts or str(rel) in ('', '.'):
        raise ValueError(f'Unsafe snapshot path: {value}')
    return rel
for rel in selected:
    safe_relative(rel)
def includes(rel):
    return any(rel == root or rel.startswith(root + '/') for root in selected)
count = 0
for entry in manifest['entries']:
    rel = entry['path']
    safe_relative(rel)
    if not includes(rel):
        continue
    source = bundle / 'home' / rel
    if entry['kind'] == 'symlink':
        valid = source.is_symlink() and os.readlink(source) == entry['target']
    else:
        valid = source.is_file() and not source.is_symlink()
        if valid:
            with source.open('rb') as stream:
                valid = hashlib.file_digest(stream, 'sha256').hexdigest() == entry['sha256']
    if not valid:
        raise SystemExit(f'Snapshot verification FAILED: {rel}. Nothing restored.')
    count += 1
for rel in selected:
    if not os.path.lexists(bundle / 'home' / rel):
        raise SystemExit(f'Snapshot target is missing: {rel}')
    # Avoid silently writing through symlinked parent directories.
    for parent in (target / rel).parents:
        if parent == target:
            break
        if parent.is_symlink():
            raise SystemExit(f'Refusing symlinked destination parent: {parent}')
print(f'Verified {count} files/links. Destination: {target}')
for rel in selected:
    print(f'  REPLACE {rel}')
if args.dry_run or args.verify_only:
    print('No files changed.')
    sys.exit(0)

def copy(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        destination.symlink_to(os.readlink(source))
    elif source.is_dir():
        shutil.copytree(source, destination, symlinks=True)
    else:
        shutil.copy2(source, destination)
def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)
def interrupted(signum, frame):
    raise InterruptedError('Restore interrupted')
signal.signal(signal.SIGTERM, interrupted)
target.mkdir(parents=True, exist_ok=True)
stage = Path(tempfile.mkdtemp(prefix='.quickshellconf-stage-', dir=target))
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
backup = target / '.local/state/quickshellconf-backups' / stamp
touched = []
try:
    # Prepare all copies before replacing any target.
    for rel in selected:
        copy(bundle / 'home' / rel, stage / rel)
    backup.mkdir(parents=True, mode=0o700)
    receipt = {'snapshot':str(bundle), 'target_home':str(target), 'targets':[]}
    for rel in selected:
        destination = target / rel
        saved = backup / 'home' / rel
        existed = os.path.lexists(destination)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if existed:
            saved.parent.mkdir(parents=True, exist_ok=True)
            destination.rename(saved)
        touched.append((rel, existed))
        (stage / rel).rename(destination)
        receipt['targets'].append({'path':rel, 'previously_existed':existed})
    (backup / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
except BaseException:
    for rel, existed in reversed(touched):
        destination = target / rel
        remove(destination)
        if existed:
            (backup / 'home' / rel).rename(destination)
    print('Restore failed; replaced targets were rolled back.', file=sys.stderr)
    raise
finally:
    shutil.rmtree(stage, ignore_errors=True)
print(f'Restore complete. Previous targets: {backup}')
print('The running shell was not restarted. Log out and back in to load the complete restored desktop setup.')
PY
