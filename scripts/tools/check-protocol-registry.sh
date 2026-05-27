#!/bin/bash
#===============================================================================
# Vany - Protocol Registry Drift Check
# Ensures Worker protocol routes match the Bash installer registry.
#===============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$ROOT_DIR/scripts/lib/protocol-registry.sh"

bash_protocols=$(mktemp)
worker_protocols=$(mktemp)
trap 'rm -f "$bash_protocols" "$worker_protocols"' EXIT

printf '%s\n' "${VANY_PROTOCOLS[@]}" | sort > "$bash_protocols"

python3 - "$ROOT_DIR/workers/src/index.ts" > "$worker_protocols" <<'PY'
import re
import sys

source = open(sys.argv[1], encoding="utf-8").read().splitlines()
inside_services = False
for line in source:
    if line.startswith("const SERVICES:"):
        inside_services = True
        continue
    if inside_services and line.startswith("};"):
        break
    if not inside_services:
        continue

    match = re.match(r"^  ['\"]?([a-z0-9-]+)['\"]?: \{$", line)
    if match:
        print(match.group(1))
PY

sort -o "$worker_protocols" "$worker_protocols"

if ! diff -u "$bash_protocols" "$worker_protocols"; then
    echo "Protocol registry drift detected between scripts/lib/protocol-registry.sh and workers/src/index.ts" >&2
    exit 1
fi

echo "Protocol registry matches Worker SERVICES keys"