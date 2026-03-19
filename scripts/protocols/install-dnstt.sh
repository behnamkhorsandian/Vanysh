#!/bin/bash
#===============================================================================
# Vany - Install DNSTT Docker container
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
DOCKER_DIR="$VANY_DIR/docker/dnstt"

source "$(dirname "$0")/../scripts/docker-bootstrap.sh" 2>/dev/null || true

#-------------------------------------------------------------------------------
# Install
#-------------------------------------------------------------------------------

install_dnstt() {
    local domain="${1:-t.example.com}"
    local forward="${2:-127.0.0.1:10800}"

    echo "  Installing DNSTT container..."
    echo "  Domain: $domain"
    echo "  Forward: $forward"

    mkdir -p "$VANY_DIR/dnstt"

    # Set environment
    export DNSTT_DOMAIN="$domain"
    export DNSTT_FORWARD="$forward"

    # Build and start
    docker compose -f "$DOCKER_DIR/docker-compose.yml" build
    docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d

    # Open DNS port and redirect 53 -> 5300
    open_port 53 udp
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5300 2>/dev/null || true

    # Wait for key generation
    sleep 3

    local pubkey=""
    if [[ -f "$VANY_DIR/dnstt/server.pub" ]]; then
        pubkey=$(cat "$VANY_DIR/dnstt/server.pub")
    fi

    # Update state
    jq --arg domain "$domain" --arg pubkey "$pubkey" \
        '.protocols.dnstt = {"status": "running", "container": "vany-dnstt", "ports": ["53/udp"], "domain": $domain, "pubkey": $pubkey}' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo "  DNSTT container started"
    [[ -n "$pubkey" ]] && echo "  Public key: $pubkey"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_dnstt "$@"
fi
