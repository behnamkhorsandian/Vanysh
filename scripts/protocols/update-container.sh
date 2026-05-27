#!/bin/bash
#===============================================================================
# Vany - Update a Docker container (pull latest, restart)
# Usage: update-container.sh <protocol>
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
GITHUB_RAW="https://raw.githubusercontent.com/behnamkhorsandian/Vanysh/main"

PROTO="${1:-}"

load_protocol_registry() {
    if [[ -n "${VANY_PROTOCOL_REGISTRY_LOADED:-}" ]]; then
        return 0
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local candidate
    for candidate in \
        "$script_dir/../lib/protocol-registry.sh" \
        "$script_dir/lib/protocol-registry.sh" \
        "$VANY_DIR/scripts/lib/protocol-registry.sh"; do
        if [[ -f "$candidate" ]]; then
            source "$candidate"
            return 0
        fi
    done

    local registry_file="/tmp/vany-protocol-registry.sh"
    curl -sfL "$GITHUB_RAW/scripts/lib/protocol-registry.sh" -o "$registry_file"
    source "$registry_file"
}

get_container_name() {
    local proto="$1"
    vany_protocol_container "$proto"
}

get_docker_dir() {
    local proto="$1"
    local runtime
    runtime=$(vany_protocol_runtime "$proto")
    echo "$VANY_DIR/docker/$runtime"
}

load_protocol_registry

if [[ -z "$PROTO" ]]; then
    echo "Usage: $0 <protocol>"
    echo "Protocols: $(vany_protocol_list_inline)"
    exit 1
fi

CONTAINER=$(get_container_name "$PROTO")
DOCKER_DIR=$(get_docker_dir "$PROTO")

if [[ ! -f "$DOCKER_DIR/docker-compose.yml" ]]; then
    echo "Error: No compose file for $PROTO" >&2
    exit 1
fi

echo "  Updating $CONTAINER..."

docker compose -f "$DOCKER_DIR/docker-compose.yml" pull 2>/dev/null || \
    docker compose -f "$DOCKER_DIR/docker-compose.yml" build --no-cache

docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d

echo "  $CONTAINER updated"
