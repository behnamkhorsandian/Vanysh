#!/bin/bash
#===============================================================================
# Vany - Install Xray (Reality + WS + VRAY) Docker container
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
USERS_FILE="$VANY_DIR/users.json"
DOCKER_DIR="$VANY_DIR/docker/xray"
XRAY_CONFIG="$VANY_DIR/xray/config.json"

source "$(dirname "$0")/../scripts/docker-bootstrap.sh" 2>/dev/null || true

#-------------------------------------------------------------------------------
# Config Initialization
#-------------------------------------------------------------------------------

init_xray_config() {
    if [[ -f "$XRAY_CONFIG" ]]; then
        return 0
    fi

    mkdir -p "$VANY_DIR/xray"
    cat > "$XRAY_CONFIG" <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "api": {
    "tag": "api",
    "services": ["StatsService"]
  },
  "stats": {},
  "inbounds": [
    {
      "tag": "api-in",
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block", "protocol": "blackhole" }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "inboundTag": ["api-in"], "outboundTag": "api", "type": "field" }
    ]
  }
}
EOF
    chmod 600 "$XRAY_CONFIG"
}

#-------------------------------------------------------------------------------
# Build and Start
#-------------------------------------------------------------------------------

install_xray() {
    echo "  Installing Xray container..."

    init_xray_config

    # Build image
    if [[ -f "$DOCKER_DIR/Dockerfile" ]]; then
        docker compose -f "$DOCKER_DIR/docker-compose.yml" build
    fi

    # Open ports
    open_port 443 tcp
    open_port 80 tcp

    # Start container
    docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d

    # Update state
    jq '.protocols.xray = {"status": "running", "container": "vany-xray", "ports": ["443/tcp", "80/tcp"]}' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo "  Xray container started"
}

#-------------------------------------------------------------------------------
# Reality-specific helpers
#-------------------------------------------------------------------------------

add_reality_inbound() {
    local private_key="$1"
    local target="$2"
    local short_ids="$3"

    local inbound
    inbound=$(cat <<EOF
{
  "tag": "reality-in",
  "port": 443,
  "protocol": "vless",
  "settings": {
    "clients": [],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "${target}:443",
      "xver": 0,
      "serverNames": ["$target"],
      "privateKey": "$private_key",
      "shortIds": $short_ids
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls"]
  }
}
EOF
)

    jq --argjson inbound "$inbound" '.inbounds += [$inbound]' "$XRAY_CONFIG" > "$XRAY_CONFIG.tmp" \
        && mv "$XRAY_CONFIG.tmp" "$XRAY_CONFIG"
}

add_ws_inbound() {
    local path="${1:-/ws}"

    local inbound
    inbound=$(cat <<EOF
{
  "tag": "ws-in",
  "port": 80,
  "protocol": "vless",
  "settings": {
    "clients": [],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "ws",
    "wsSettings": {
      "path": "$path"
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls"]
  }
}
EOF
)

    jq --argjson inbound "$inbound" '.inbounds += [$inbound]' "$XRAY_CONFIG" > "$XRAY_CONFIG.tmp" \
        && mv "$XRAY_CONFIG.tmp" "$XRAY_CONFIG"
}

add_xray_client() {
    local inbound_tag="$1"
    local uuid="$2"
    local email="$3"
    local flow="${4:-}"

    local client
    if [[ -n "$flow" ]]; then
        client="{\"id\": \"$uuid\", \"email\": \"$email\", \"flow\": \"$flow\"}"
    else
        client="{\"id\": \"$uuid\", \"email\": \"$email\"}"
    fi

    jq --arg tag "$inbound_tag" --argjson client "$client" \
        '(.inbounds[] | select(.tag == $tag) | .settings.clients) += [$client]' \
        "$XRAY_CONFIG" > "$XRAY_CONFIG.tmp" && mv "$XRAY_CONFIG.tmp" "$XRAY_CONFIG"
}

remove_xray_client() {
    local inbound_tag="$1"
    local email="$2"

    jq --arg tag "$inbound_tag" --arg email "$email" \
        '(.inbounds[] | select(.tag == $tag) | .settings.clients) |= map(select(.email != $email))' \
        "$XRAY_CONFIG" > "$XRAY_CONFIG.tmp" && mv "$XRAY_CONFIG.tmp" "$XRAY_CONFIG"
}

reload_xray() {
    docker exec vany-xray kill -SIGHUP 1 2>/dev/null || \
        docker restart vany-xray 2>/dev/null || true
}

#-------------------------------------------------------------------------------
# Generate x25519 keypair using the running container
#-------------------------------------------------------------------------------

generate_xray_keys() {
    # Ensure container is running
    if ! docker ps --format '{{.Names}}' | grep -q '^vany-xray$'; then
        echo "Error: Xray container not running" >&2
        return 1
    fi
    docker exec vany-xray xray x25519 2>/dev/null
}

# Allow sourcing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_xray
fi
