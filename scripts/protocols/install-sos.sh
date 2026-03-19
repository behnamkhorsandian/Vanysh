#!/bin/bash
#===============================================================================
# Vany - Install SOS Docker container
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
DOCKER_DIR="$VANY_DIR/docker/sos"

source "$(dirname "$0")/../scripts/docker-bootstrap.sh" 2>/dev/null || true

install_sos() {
    echo "  Installing SOS relay container..."

    mkdir -p "$VANY_DIR/sos"

    docker compose -f "$DOCKER_DIR/docker-compose.yml" build
    docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d

    open_port 8899 tcp

    # Update state
    jq '.protocols.sos = {"status": "running", "container": "vany-sos", "ports": ["8899/tcp"]}' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo "  SOS relay container started"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_sos
fi
