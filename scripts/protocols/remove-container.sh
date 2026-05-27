#!/bin/bash
#===============================================================================
# Vany - Remove a Docker container
# Usage: remove-container.sh <protocol>
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
GITHUB_RAW="https://raw.githubusercontent.com/behnamkhorsandian/Vanysh/main"

source "$(dirname "$0")/../scripts/docker-bootstrap.sh" 2>/dev/null || true

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
    vany_protocol_container "$1"
}

get_ports() {
    local protocol="$1"
    vany_protocol_ports "$protocol"
}

get_runtime_ports() {
    local runtime="$1"
    vany_protocol_ports "$runtime"
}

remove_user_protocols() {
    local protocol="$1"
    local users_file="$VANY_DIR/users.json"

    [[ -f "$users_file" ]] || return 0
    jq --arg protocol "$protocol" \
        '(.users // {}) as $users
         | .users = ($users
             | with_entries(
                 .value.protocols = ((.value.protocols // {}) | del(.[$protocol]))
                 | select((.value.protocols // {}) | length > 0)
               ))' \
        "$users_file" > "$users_file.tmp" && mv "$users_file.tmp" "$users_file"
    chmod 600 "$users_file"
}

remove_config_inbound() {
    local inbound_tag="$1"
    local config_file="$VANY_DIR/xray/config.json"

    [[ -n "$inbound_tag" && -f "$config_file" ]] || return 0
    jq --arg tag "$inbound_tag" 'del(.inbounds[] | select(.tag == $tag))' \
        "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
}

feature_state_exists() {
    local runtime="$1"
    local feature="$2"
    jq -e --arg runtime "$runtime" --arg feature "$feature" '.protocols[$runtime][$feature] // empty' "$STATE_FILE" >/dev/null 2>&1
}

runtime_has_features() {
    local runtime="$1"
    local protocol feature

    for protocol in "${VANY_PROTOCOLS[@]}"; do
        [[ "$(vany_protocol_runtime "$protocol")" == "$runtime" ]] || continue
        feature=$(vany_protocol_feature_key "$protocol")
        [[ -z "$feature" ]] && continue
        if feature_state_exists "$runtime" "$feature"; then
            return 0
        fi
    done

    return 1
}

close_ports() {
    local port_list="$1"
    local portspec port proto_type

    for portspec in $port_list; do
        [[ "$portspec" != */* ]] && continue
        port="${portspec%%/*}"
        proto_type="${portspec#*/}"
        close_port "$port" "$proto_type" 2>/dev/null || true
    done
}

remove_shared_feature() {
    local runtime="$1"
    local feature="$2"
    local inbound_tag="$3"

    echo "  Removing $PROTO from shared $runtime runtime..."

    remove_user_protocols "$PROTO"

    if [[ "$PROTO" == "ws" ]] && feature_state_exists "$runtime" "http-obfs"; then
        inbound_tag=""
    fi
    if [[ "$PROTO" == "http-obfs" ]] && feature_state_exists "$runtime" "ws"; then
        inbound_tag=""
    fi

    remove_config_inbound "$inbound_tag"

    jq --arg runtime "$runtime" --arg feature "$feature" --arg proto "$PROTO" \
        'del(.protocols[$runtime][$feature]) | del(.protocols[$proto])' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    if runtime_has_features "$runtime"; then
        echo "  $CONTAINER kept because another protocol still uses it"
        docker exec "$CONTAINER" kill -SIGHUP 1 2>/dev/null || docker restart "$CONTAINER" 2>/dev/null || true
        return 0
    fi

    docker stop "$CONTAINER" 2>/dev/null || true
    docker rm "$CONTAINER" 2>/dev/null || true
    close_ports "$(get_runtime_ports "$runtime")"
    jq --arg runtime "$runtime" 'del(.protocols[$runtime])' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    echo "  $CONTAINER removed"
}

load_protocol_registry

if [[ -z "$PROTO" ]]; then
    echo "Usage: $0 <protocol>"
    echo "Protocols: $(vany_protocol_list_inline)"
    exit 1
fi

CONTAINER=$(get_container_name "$PROTO")
DOCKER_DIR="$VANY_DIR/docker"
RUNTIME=$(vany_protocol_runtime "$PROTO")
FEATURE=$(vany_protocol_feature_key "$PROTO")
INBOUND_TAG=$(vany_protocol_inbound_tag "$PROTO")

if [[ -n "$FEATURE" ]]; then
    remove_shared_feature "$RUNTIME" "$FEATURE" "$INBOUND_TAG"
    exit 0
fi

echo "  Removing $CONTAINER..."

# Stop and remove container
if [[ -n "$CONTAINER" ]]; then
    docker stop "$CONTAINER" 2>/dev/null || true
    docker rm "$CONTAINER" 2>/dev/null || true
fi

# Close firewall ports
if [[ "$PROTO" != "ssh-tunnel" ]]; then
    PORTS=$(get_ports "$PROTO")
    close_ports "$PORTS"
fi

# Remove DNSTT iptables NAT rule
if [[ "$PROTO" == "dnstt" ]]; then
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5300 2>/dev/null || true
fi

# Update state
STATE_KEY=$(vany_protocol_state_key "$PROTO")
jq --arg proto "$STATE_KEY" 'del(.protocols[$proto])' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

echo "  $CONTAINER removed"
