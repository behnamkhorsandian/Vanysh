#!/bin/bash
#===============================================================================
# Vany - Install Conduit Docker container
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
DOCKER_DIR="$VANY_DIR/docker/conduit"

source "$(dirname "$0")/../scripts/docker-bootstrap.sh" 2>/dev/null || true

install_conduit() {
    echo "  Installing Conduit container..."

    mkdir -p "$VANY_DIR/conduit"

    docker compose -f "$DOCKER_DIR/docker-compose.yml" pull
    docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d

    # Update state
    jq '.protocols.conduit = {"status": "running", "container": "vany-conduit", "ports": ["auto"]}' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo "  Conduit container started"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_conduit
fi
