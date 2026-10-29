#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
runtime="$source_root/../calendar-runtime"
python3 -m venv "$runtime"
"$runtime/bin/pip" install 'icalendar==7.3.0' 'recurring-ical-events==3.8.2'
