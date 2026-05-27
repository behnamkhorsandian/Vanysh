#!/bin/bash
#===============================================================================
# Vany - Install HTTP Obfuscation (WS+CDN with Host header spoofing)
# Server-side identical to WS+CDN. Difference is client config.
#===============================================================================

set -e

VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
GITHUB_RAW="https://raw.githubusercontent.com/behnamkhorsandian/Vanysh/main"

source "$(dirname "$0")/../scripts/docker-bootstrap.sh" 2>/dev/null || true

source_xray_installer() {
    if declare -F install_xray >/dev/null && declare -F add_ws_inbound >/dev/null; then
        return 0
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    local candidate
    for candidate in \
        "$script_dir/install-xray.sh" \
        "$VANY_DIR/scripts/install-xray.sh" \
        "$VANY_DIR/scripts/protocols/install-xray.sh"; do
        if [[ -f "$candidate" ]]; then
            source "$candidate"
            return 0
        fi
    done

    local xray_script="/tmp/vany-install-xray.sh"
    curl -sfL "$GITHUB_RAW/scripts/protocols/install-xray.sh" -o "$xray_script"
    source "$xray_script"
}

install_http_obfs() {
    local domain="${HTTP_OBFS_DOMAIN:-}"
    local username="${FIRST_USERNAME:-user1}"

    if [[ -z "$domain" ]]; then
        echo "  Error: HTTP_OBFS_DOMAIN is required"
        exit 1
    fi

    echo "  Installing HTTP Obfuscation (WS+CDN with Host spoofing)..."
    echo "  Note: Server-side is identical to WS+CDN."
    echo "  The difference is the client uses clean CDN IPs."

    # Reuse WS+CDN install (same xray inbound)
    export WS_DOMAIN="$domain"
    source_xray_installer
    install_xray
    add_ws_inbound "/ws"
    local payload
    payload=$(jq -n --arg domain "$domain" --arg path "/ws" '{domain: $domain, path: $path}')
    set_xray_feature_state "http-obfs" "$payload"
    reload_xray

    # Update state to also mark http-obfs as available
    jq --arg domain "$domain" \
        '.protocols["http-obfs"] = {"status": "running", "container": "vany-xray", "shared": "xray", "ports": ["80/tcp"], "domain": $domain}' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo ""
    echo "  HTTP Obfuscation ready"
    echo "  Domain: $domain"
    echo "  First username: $username"
    echo ""
    echo "  Client setup:"
    echo "    1. Use 'cfray' tool to find clean Cloudflare IPs"
    echo "    2. Set clean IP as 'address' in VLESS config"
    echo "    3. Set '$domain' as 'Host' header"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_http_obfs
fi
