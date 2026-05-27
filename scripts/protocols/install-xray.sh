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

random_uuid() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    cat /proc/sys/kernel/random/uuid
  fi
}

random_hex() {
  local length="${1:-16}"
  head -c $((length / 2)) /dev/urandom | xxd -p | tr -d '\n'
}

ensure_users_file() {
  if [[ -f "$USERS_FILE" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$USERS_FILE")"
  cat > "$USERS_FILE" <<'EOF'
{
  "users": {},
  "server": {}
}
EOF
  chmod 600 "$USERS_FILE"
}

set_user_protocol() {
  local username="$1"
  local protocol="$2"
  local creds="$3"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  ensure_users_file
  jq --arg user "$username" --arg protocol "$protocol" --arg now "$now" --argjson creds "$creds" \
    '.users[$user] = (.users[$user] // {"created": $now, "protocols": {}})
     | .users[$user].protocols = (.users[$user].protocols // {})
     | .users[$user].protocols[$protocol] = $creds' \
    "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"
  chmod 600 "$USERS_FILE"
}

remove_user_protocol() {
  local username="$1"
  local protocol="$2"

  ensure_users_file
  jq --arg user "$username" --arg protocol "$protocol" \
    'del(.users[$user].protocols[$protocol])
     | if (.users[$user].protocols // {} | length) == 0 then del(.users[$user]) else . end' \
    "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"
  chmod 600 "$USERS_FILE"
}

xray_inbound_exists() {
  local tag="$1"
  [[ -f "$XRAY_CONFIG" ]] && jq -e --arg tag "$tag" '.inbounds[] | select(.tag == $tag)' "$XRAY_CONFIG" >/dev/null 2>&1
}

set_xray_feature_state() {
  local feature="$1"
  local payload="$2"

  jq --arg feature "$feature" --argjson payload "$payload" \
    '.protocols.xray = (.protocols.xray // {})
     | .protocols.xray.status = "running"
     | .protocols.xray.container = "vany-xray"
     | .protocols.xray.ports = ["443/tcp", "80/tcp"]
     | .protocols.xray[$feature] = $payload' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}

get_server_address() {
  jq -r '.ip // "unknown"' "$STATE_FILE" 2>/dev/null
}

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

    # Update runtime state while preserving protocol feature metadata.
    jq '.protocols.xray = (.protocols.xray // {})
      | .protocols.xray.status = "running"
      | .protocols.xray.container = "vany-xray"
      | .protocols.xray.ports = ["443/tcp", "80/tcp"]' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo "  Xray container started"
}

#-------------------------------------------------------------------------------
# Reality-specific helpers
#-------------------------------------------------------------------------------

add_reality_inbound() {
    local private_key="$1"
  local target="${2:-www.cloudflare.com}"
  local short_ids="${3:-[\"\"]}"

  if xray_inbound_exists "reality-in"; then
    echo "  Reality inbound already exists"
    return 0
  fi

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

    if xray_inbound_exists "ws-in"; then
      echo "  WebSocket inbound already exists"
      return 0
    fi

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

remove_xray_inbound() {
  local inbound_tag="$1"

  [[ -z "$inbound_tag" || ! -f "$XRAY_CONFIG" ]] && return 0

  jq --arg tag "$inbound_tag" 'del(.inbounds[] | select(.tag == $tag))' \
    "$XRAY_CONFIG" > "$XRAY_CONFIG.tmp" && mv "$XRAY_CONFIG.tmp" "$XRAY_CONFIG"
}

remove_protocol_users() {
  local protocol="$1"

  ensure_users_file
  jq --arg protocol "$protocol" \
    '(.users // {}) as $users
     | .users = ($users
       | with_entries(
         .value.protocols = ((.value.protocols // {}) | del(.[$protocol]))
         | select((.value.protocols // {}) | length > 0)
         ))' \
    "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"
  chmod 600 "$USERS_FILE"
}

delete_xray_feature_state() {
  local feature="$1"

  [[ -f "$STATE_FILE" ]] || return 0
  jq --arg feature "$feature" 'del(.protocols.xray[$feature])' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}

xray_feature_state_exists() {
  local feature="$1"
  jq -e --arg feature "$feature" '.protocols.xray[$feature] // empty' "$STATE_FILE" >/dev/null 2>&1
}

xray_any_feature_active() {
  local feature
  for feature in reality ws http-obfs vray mtp; do
    if xray_feature_state_exists "$feature"; then
      return 0
    fi
  done
  return 1
}

stop_xray_if_unused() {
  if xray_any_feature_active; then
    echo "  Xray runtime kept because another protocol still uses it"
    reload_xray
    return 0
  fi

  docker stop vany-xray 2>/dev/null || true
  docker rm vany-xray 2>/dev/null || true
  close_port 443 tcp 2>/dev/null || true
  close_port 80 tcp 2>/dev/null || true

  if [[ -f "$STATE_FILE" ]]; then
    jq 'del(.protocols.xray)' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  fi

  echo "  Xray runtime removed"
}

uninstall_reality_protocol() {
  remove_xray_inbound "reality-in"
  remove_protocol_users "reality"
  delete_xray_feature_state "reality"
  stop_xray_if_unused
}

uninstall_ws_protocol() {
  remove_protocol_users "ws"
  delete_xray_feature_state "ws"

  if ! xray_feature_state_exists "http-obfs"; then
    remove_xray_inbound "ws-in"
  fi

  stop_xray_if_unused
}

uninstall_http_obfs_protocol() {
  remove_protocol_users "http-obfs"
  delete_xray_feature_state "http-obfs"

  if [[ -f "$STATE_FILE" ]]; then
    jq 'del(.protocols["http-obfs"])' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  fi

  if ! xray_feature_state_exists "ws"; then
    remove_xray_inbound "ws-in"
  fi

  stop_xray_if_unused
}

reload_xray() {
    docker exec vany-xray kill -SIGHUP 1 2>/dev/null || \
        docker restart vany-xray 2>/dev/null || true
}

ensure_reality_inbound() {
  if xray_inbound_exists "reality-in"; then
    return 0
  fi

  local target="${REALITY_TARGET:-www.cloudflare.com}"
  local keys private_key public_key short_id
  keys=$(generate_xray_keys)
  private_key=$(echo "$keys" | awk '/Private key:/ {print $3}')
  public_key=$(echo "$keys" | awk '/Public key:/ {print $3}')
  short_id=$(random_hex 16)

  if [[ -z "$private_key" || -z "$public_key" || -z "$short_id" ]]; then
    echo "Error: Failed to generate REALITY keys" >&2
    return 1
  fi

  add_reality_inbound "$private_key" "$target" "[\"$short_id\"]"

  local payload
  payload=$(jq -n --arg target "$target" --arg public_key "$public_key" --arg short_id "$short_id" \
    '{target: $target, public_key: $public_key, short_id: $short_id}')
  set_xray_feature_state "reality" "$payload"
}

set_ws_state() {
  local domain="$1"
  local path="${2:-/ws}"
  local payload
  payload=$(jq -n --arg domain "$domain" --arg path "$path" '{domain: $domain, path: $path}')
  set_xray_feature_state "ws" "$payload"
}

reality_link() {
  local uuid="$1"
  local username="$2"
  local address public_key target short_id
  address=$(get_server_address)
  public_key=$(jq -r '.protocols.xray.reality.public_key // empty' "$STATE_FILE")
  target=$(jq -r '.protocols.xray.reality.target // "www.cloudflare.com"' "$STATE_FILE")
  short_id=$(jq -r '.protocols.xray.reality.short_id // empty' "$STATE_FILE")

  echo "vless://${uuid}@${address}:443?type=tcp&security=reality&pbk=${public_key}&fp=chrome&sni=${target}&sid=${short_id}&flow=xtls-rprx-vision#${username}-reality"
}

ws_link() {
  local uuid="$1"
  local username="$2"
  local domain path encoded_path
  domain=$(jq -r '.protocols.xray.ws.domain // empty' "$STATE_FILE")
  path=$(jq -r '.protocols.xray.ws.path // "/ws"' "$STATE_FILE")
  encoded_path=${path//\//%2F}

  echo "vless://${uuid}@${domain}:443?type=ws&security=tls&path=${encoded_path}&host=${domain}&sni=${domain}#${username}-ws"
}

add_reality_client() {
  local username="$1"
  [[ -z "$username" ]] && { echo "Error: Username required" >&2; return 1; }

  ensure_reality_inbound

  local uuid creds public_key target short_id
  uuid=$(random_uuid)
  public_key=$(jq -r '.protocols.xray.reality.public_key // empty' "$STATE_FILE")
  target=$(jq -r '.protocols.xray.reality.target // "www.cloudflare.com"' "$STATE_FILE")
  short_id=$(jq -r '.protocols.xray.reality.short_id // empty' "$STATE_FILE")

  add_xray_client "reality-in" "$uuid" "${username}@vany" "xtls-rprx-vision"
  creds=$(jq -n --arg uuid "$uuid" --arg flow "xtls-rprx-vision" --arg public_key "$public_key" --arg target "$target" --arg short_id "$short_id" \
    '{uuid: $uuid, flow: $flow, public_key: $public_key, target: $target, short_id: $short_id}')
  set_user_protocol "$username" "reality" "$creds"
  reload_xray

  echo "  User '$username' added to REALITY"
  echo "  $(reality_link "$uuid" "$username")"
}

remove_reality_client() {
  local username="$1"
  [[ -z "$username" ]] && { echo "Error: Username required" >&2; return 1; }

  remove_xray_client "reality-in" "${username}@vany"
  remove_user_protocol "$username" "reality"
  reload_xray

  echo "  User '$username' removed from REALITY"
}

add_ws_client() {
  local username="$1"
  [[ -z "$username" ]] && { echo "Error: Username required" >&2; return 1; }

  if ! xray_inbound_exists "ws-in"; then
    add_ws_inbound "/ws"
  fi

  local uuid domain path creds
  uuid=$(random_uuid)
  domain=$(jq -r '.protocols.xray.ws.domain // empty' "$STATE_FILE")
  path=$(jq -r '.protocols.xray.ws.path // "/ws"' "$STATE_FILE")

  add_xray_client "ws-in" "$uuid" "${username}@vany"
  creds=$(jq -n --arg uuid "$uuid" --arg domain "$domain" --arg path "$path" \
    '{uuid: $uuid, domain: $domain, path: $path}')
  set_user_protocol "$username" "ws" "$creds"
  reload_xray

  echo "  User '$username' added to WS+CDN"
  [[ -n "$domain" ]] && echo "  $(ws_link "$uuid" "$username")"
}

remove_ws_client() {
  local username="$1"
  [[ -z "$username" ]] && { echo "Error: Username required" >&2; return 1; }

  remove_xray_client "ws-in" "${username}@vany"
  remove_user_protocol "$username" "ws"
  reload_xray

  echo "  User '$username' removed from WS+CDN"
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
