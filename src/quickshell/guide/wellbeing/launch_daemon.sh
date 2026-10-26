#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/caching.sh"
# Skip background activity accounting in the local low-memory profile.
if jq -e '.general.lowMemory == true' "${QS_SETTINGS:-$HOME/.config/serpantinum/settings.json}" >/dev/null 2>&1; then
    exit 0
fi
exec python3 "$(dirname "$0")/focus_daemon.py" 
