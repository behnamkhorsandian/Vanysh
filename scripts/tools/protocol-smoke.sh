#!/bin/bash
#===============================================================================
# Vany - Protocol Smoke Checks
# Fast CI checks for registry, protocol scripts, and compose files.
#===============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$ROOT_DIR/scripts/lib/protocol-registry.sh"

echo "Checking protocol registry entries..."

seen_runtimes=" "
for protocol in "${VANY_PROTOCOLS[@]}"; do
    script="$(vany_protocol_script "$protocol")"
    runtime=$(vany_protocol_runtime "$protocol")
    container=$(vany_protocol_container "$protocol")

    [[ -n "$script" ]] || { echo "Missing installer script metadata for $protocol" >&2; exit 1; }
    [[ -f "$ROOT_DIR/scripts/protocols/$script" ]] || { echo "Missing installer script for $protocol: $script" >&2; exit 1; }

    if [[ "$runtime" != "host" ]]; then
        [[ -n "$container" ]] || { echo "Missing container metadata for $protocol" >&2; exit 1; }
        [[ -f "$ROOT_DIR/docker/$runtime/docker-compose.yml" ]] || { echo "Missing compose file for $protocol runtime: $runtime" >&2; exit 1; }
    fi

    seen_runtimes+="$runtime "
done

echo "Validating Docker compose files..."

while IFS= read -r compose_file; do
    docker compose -f "$compose_file" config >/dev/null
done < <(find "$ROOT_DIR/docker" -name docker-compose.yml -print | sort)

echo "Checking Worker/Bash protocol registry drift..."
bash "$ROOT_DIR/scripts/tools/check-protocol-registry.sh"

echo "Protocol smoke checks passed"