#!/bin/bash
#===============================================================================
# Vany - Install WireGuard Docker container
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
USERS_FILE="$VANY_DIR/users.json"
DOCKER_DIR="$VANY_DIR/docker/wireguard"
WG_DIR="$VANY_DIR/wg"
WG_PORT=51820
WG_SUBNET="10.66.66"

source "$(dirname "$0")/../scripts/docker-bootstrap.sh" 2>/dev/null || true

#-------------------------------------------------------------------------------
# Key Generation
#-------------------------------------------------------------------------------

generate_wg_keys() {
    docker run --rm linuxserver/wireguard wg genkey | tee /dev/stderr | \
        docker run --rm -i linuxserver/wireguard wg pubkey 2>/dev/null
}

#-------------------------------------------------------------------------------
# Config Initialization
#-------------------------------------------------------------------------------

init_wg_config() {
    mkdir -p "$WG_DIR/peers"

    if [[ -f "$WG_DIR/wg0.conf" ]]; then
        return 0
    fi

    local server_privkey
    server_privkey=$(docker run --rm linuxserver/wireguard wg genkey)
    local server_pubkey
    server_pubkey=$(echo "$server_privkey" | docker run --rm -i linuxserver/wireguard wg pubkey)

    local server_ip
    server_ip=$(jq -r '.ip // "0.0.0.0"' "$STATE_FILE")

    cat > "$WG_DIR/wg0.conf" <<EOF
[Interface]
Address = ${WG_SUBNET}.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${server_privkey}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

    chmod 600 "$WG_DIR/wg0.conf"

    # Store server pubkey
    echo "$server_pubkey" > "$WG_DIR/server.pub"
}

#-------------------------------------------------------------------------------
# Install
#-------------------------------------------------------------------------------

install_wireguard() {
    echo "  Installing WireGuard container..."

    init_wg_config

    # Build/pull image
    docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d

    # Open port
    open_port "$WG_PORT" udp

    # Update state
    jq --arg port "$WG_PORT" \
        '.protocols.wireguard = {"status": "running", "container": "vany-wireguard", "ports": [($port + "/udp")]}' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo "  WireGuard container started"
}

#-------------------------------------------------------------------------------
# User Management
#-------------------------------------------------------------------------------

next_wg_ip() {
    local last_octet=2
    if [[ -d "$WG_DIR/peers" ]]; then
        local existing
        existing=$(ls "$WG_DIR/peers/" 2>/dev/null | wc -l)
        last_octet=$((existing + 2))
    fi
    echo "${WG_SUBNET}.${last_octet}"
}

add_wg_user() {
    local username="$1"

    if [[ -z "$username" ]]; then
        echo "Error: Username required" >&2
        return 1
    fi

    local client_privkey
    client_privkey=$(docker run --rm linuxserver/wireguard wg genkey)
    local client_pubkey
    client_pubkey=$(echo "$client_privkey" | docker run --rm -i linuxserver/wireguard wg pubkey)
    local psk
    psk=$(docker run --rm linuxserver/wireguard wg genpsk)

    local client_ip
    client_ip=$(next_wg_ip)

    local server_pubkey
    server_pubkey=$(cat "$WG_DIR/server.pub")
    local server_ip
    server_ip=$(jq -r '.ip // "0.0.0.0"' "$STATE_FILE")

    # Add peer to server config
    cat >> "$WG_DIR/wg0.conf" <<EOF

# ${username}
[Peer]
PublicKey = ${client_pubkey}
PresharedKey = ${psk}
AllowedIPs = ${client_ip}/32
EOF

    # Create client config
    mkdir -p "$WG_DIR/peers"
    cat > "$WG_DIR/peers/${username}.conf" <<EOF
[Interface]
PrivateKey = ${client_privkey}
Address = ${client_ip}/32
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${server_pubkey}
PresharedKey = ${psk}
Endpoint = ${server_ip}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    # Update users.json
    jq --arg user "$username" --arg pubkey "$client_pubkey" --arg psk "$psk" --arg ip "$client_ip" \
        '.users[$user].protocols.wg = {"public_key": $pubkey, "psk": $psk, "ip": $ip}' \
        "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"

    # Reload WireGuard
    docker exec vany-wireguard wg syncconf wg0 <(docker exec vany-wireguard wg-quick strip wg0) 2>/dev/null || \
        docker restart vany-wireguard

    echo "  User '$username' added to WireGuard (IP: $client_ip)"
}

remove_wg_user() {
    local username="$1"

    # Remove peer section from wg0.conf
    sed -i "/# ${username}/,/^$/d" "$WG_DIR/wg0.conf"

    # Remove client config
    rm -f "$WG_DIR/peers/${username}.conf"

    # Update users.json
    jq --arg user "$username" 'del(.users[$user].protocols.wg)' \
        "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"

    # Reload
    docker restart vany-wireguard 2>/dev/null || true

    echo "  User '$username' removed from WireGuard"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_wireguard
fi
