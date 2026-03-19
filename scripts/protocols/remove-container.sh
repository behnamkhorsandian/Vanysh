#!/bin/bash
#===============================================================================
# Vany - Remove a Docker container
# Usage: remove-container.sh <protocol>
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"

source "$(dirname "$0")/../scripts/docker-bootstrap.sh" 2>/dev/null || true

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

PORT_MAP=(
    "xray:443/tcp 80/tcp"
    "wireguard:51820/udp"
    "dnstt:53/udp"
    "conduit:"
    "sos:8899/tcp"
)

get_container_name() {
    for entry in "${CONTAINER_MAP[@]}"; do
        [[ "${entry%%:*}" == "$1" ]] && echo "${entry#*:}" && return 0
    done
    echo "vany-$1"
}

get_ports() {
    for entry in "${PORT_MAP[@]}"; do
        [[ "${entry%%:*}" == "$1" ]] && echo "${entry#*:}" && return 0
    done
}

if [[ -z "$PROTO" ]]; then
    echo "Usage: $0 <protocol>"
    echo "Protocols: xray, wireguard, dnstt, conduit, sos"
    exit 1
fi

CONTAINER=$(get_container_name "$PROTO")
DOCKER_DIR="$VANY_DIR/docker"

echo "  Removing $CONTAINER..."

# Stop and remove container
docker stop "$CONTAINER" 2>/dev/null || true
docker rm "$CONTAINER" 2>/dev/null || true

# Close firewall ports
PORTS=$(get_ports "$PROTO")
for portspec in $PORTS; do
    port="${portspec%%/*}"
    proto_type="${portspec#*/}"
    close_port "$port" "$proto_type" 2>/dev/null || true
done

# Remove DNSTT iptables NAT rule
if [[ "$PROTO" == "dnstt" ]]; then
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5300 2>/dev/null || true
fi

# Update state
jq --arg proto "$PROTO" 'del(.protocols[$proto])' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

echo "  $CONTAINER removed"
