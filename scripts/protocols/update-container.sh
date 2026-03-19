#!/bin/bash
#===============================================================================
# Vany - Update a Docker container (pull latest, restart)
# Usage: update-container.sh <protocol>
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"

PROTO="${1:-}"
CONTAINER_MAP=(
    "xray:vany-xray"
    "reality:vany-xray"
    "ws:vany-xray"
    "vray:vany-xray"
    "wireguard:vany-wireguard"
    "wg:vany-wireguard"
    "dnstt:vany-dnstt"
    "conduit:vany-conduit"
    "sos:vany-sos"
)

get_container_name() {
    local proto="$1"
    for entry in "${CONTAINER_MAP[@]}"; do
        local key="${entry%%:*}"
        local val="${entry#*:}"
        if [[ "$key" == "$proto" ]]; then
            echo "$val"
            return 0
        fi
    done
    echo "vany-$proto"
}

get_docker_dir() {
    local container="$1"
    case "$container" in
        vany-xray)      echo "$VANY_DIR/docker/xray" ;;
        vany-wireguard) echo "$VANY_DIR/docker/wireguard" ;;
        vany-dnstt)     echo "$VANY_DIR/docker/dnstt" ;;
        vany-conduit)   echo "$VANY_DIR/docker/conduit" ;;
        vany-sos)       echo "$VANY_DIR/docker/sos" ;;
        *)              echo "$VANY_DIR/docker/$1" ;;
    esac
}

if [[ -z "$PROTO" ]]; then
    echo "Usage: $0 <protocol>"
    echo "Protocols: xray, wireguard, dnstt, conduit, sos"
    exit 1
fi

CONTAINER=$(get_container_name "$PROTO")
DOCKER_DIR=$(get_docker_dir "$CONTAINER")

if [[ ! -f "$DOCKER_DIR/docker-compose.yml" ]]; then
    echo "Error: No compose file for $PROTO" >&2
    exit 1
fi

echo "  Updating $CONTAINER..."

docker compose -f "$DOCKER_DIR/docker-compose.yml" pull 2>/dev/null || \
    docker compose -f "$DOCKER_DIR/docker-compose.yml" build --no-cache

docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d

echo "  $CONTAINER updated"
