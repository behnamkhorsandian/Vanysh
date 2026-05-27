#!/bin/bash
#===============================================================================
# Vany - Docker Container Status
# Usage: status-containers.sh [protocol]
# Returns JSON status for all or one container
#===============================================================================

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
GITHUB_RAW="https://raw.githubusercontent.com/behnamkhorsandian/Vanysh/main"

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

get_container_status() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "host_managed"
        return
    fi

    if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
        echo "not_installed"
        return
    fi

    local state
    state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)
    echo "${state:-unknown}"
}

get_container_stats() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo '{"cpu": "-", "mem": "-", "uptime": "-"}'
        return
    fi

    if [[ "$(get_container_status "$name")" != "running" ]]; then
        echo '{"cpu": "-", "mem": "-", "uptime": "-"}'
        return
    fi

    local stats
    stats=$(docker stats --no-stream --format '{"cpu":"{{.CPUPerc}}","mem":"{{.MemUsage}}"}' "$name" 2>/dev/null)
    if [[ -z "$stats" ]]; then
        echo '{"cpu": "-", "mem": "-"}'
        return
    fi

    local started
    started=$(docker inspect --format '{{.State.StartedAt}}' "$name" 2>/dev/null)

    echo "$stats" | jq --arg started "$started" '. + {"started": $started}'
}

load_protocol_registry

PROTO="${1:-}"

if [[ -n "$PROTO" ]]; then
    NAME=$(vany_protocol_container "$PROTO")

    STATUS=$(get_container_status "$NAME")
    STATS=$(get_container_stats "$NAME")

    jq -n --arg name "$NAME" --arg status "$STATUS" --argjson stats "$STATS" \
        '{"container": $name, "status": $status, "stats": $stats}'
else
    # All containers
    echo "{"
    first=true
    seen=" "
    for protocol in "${VANY_PROTOCOLS[@]}"; do
        name=$(vany_protocol_container "$protocol")
        [[ -z "$name" ]] && continue
        [[ "$seen" == *" $name "* ]] && continue
        seen+="$name "

        STATUS=$(get_container_status "$name")
        STATS=$(get_container_stats "$name")

        proto="${name#vany-}"
        [[ "$first" != "true" ]] && echo ","
        first=""

        echo "  \"$proto\": $(jq -n --arg status "$STATUS" --argjson stats "$STATS" \
            '{"status": $status, "stats": $stats}')"
    done
    echo "}"
fi
