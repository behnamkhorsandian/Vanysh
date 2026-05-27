#!/bin/bash
#===============================================================================
# Vany - Protocol Registry
# Shared metadata for installers, lifecycle scripts, and CI checks.
# Bash 3.2 compatible for local macOS validation.
#===============================================================================

if [[ -n "${VANY_PROTOCOL_REGISTRY_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
VANY_PROTOCOL_REGISTRY_LOADED=1

VANY_PROTOCOLS=(
    reality
    ws
    hysteria
    wg
    vray
    http-obfs
    mtp
    ssh-tunnel
    dnstt
    slipstream
    noizdns
    conduit
    tor-bridge
    snowflake
    sos
)

VANY_PROTOCOL_RECORDS=$(cat <<'EOF'
xray|Xray Shared Runtime|Shared runtime for VLESS/REALITY/WS/MTProto-style protocols.|443/tcp 80/tcp|Varies|install-xray.sh|xray|vany-xray|xray|xray|||https-edge|||
wireguard|WireGuard Runtime|WireGuard container runtime.|51820/udp|No|install-wireguard.sh|wireguard|vany-wireguard|wireguard|wg|||wireguard|add_wg_user|remove_wg_user|
reality|VLESS + REALITY|TLS camouflage proxy. Borrows real website certificates.|443/tcp|No|install-xray.sh|xray|vany-xray|xray|xray|reality|reality-in|https-edge|add_reality_client|remove_reality_client|uninstall_reality_protocol
ws|VLESS + WS + CDN|WebSocket proxy behind Cloudflare CDN. IP fully hidden.|80/tcp 443/tcp|Yes|install-xray.sh|xray|vany-xray|xray|xray|ws|ws-in|https-edge|add_ws_client|remove_ws_client|uninstall_ws_protocol
hysteria|Hysteria v2|QUIC-based proxy. Fastest on lossy/throttled networks.|8443/udp|No|install-hysteria.sh|hysteria|vany-hysteria|hysteria|hysteria|||hysteria-udp|||
wg|WireGuard|Full-device VPN tunnel. Kernel-level performance.|51820/udp|No|install-wireguard.sh|wireguard|vany-wireguard|wireguard|wg|||wireguard|add_wg_user|remove_wg_user|
vray|VLESS + TLS|Classic V2Ray with real TLS certificates.|443/tcp|Yes|install-xray.sh|xray|vany-xray|xray|xray|vray|vray-in|https-edge|||
http-obfs|HTTP Obfuscation|CDN host header spoofing. Hides behind popular domains.|80/tcp|CDN|install-http-obfs.sh|xray|vany-xray|xray|xray|http-obfs|ws-in|https-edge|||uninstall_http_obfs_protocol
mtp|MTProto Proxy|Telegram-only proxy with Fake-TLS camouflage.|443/tcp|No|install-xray.sh|xray|vany-xray|xray|xray|mtp|mtp-in|https-edge|||
ssh-tunnel|SSH Tunnel|Basic SOCKS5 proxy over SSH. Universally available.|22/tcp|No|install-ssh-tunnel.sh|host||ssh-tunnel|ssh|||ssh|||
dnstt|DNSTT|DNS tunnel. ~42 KB/s, last resort when all else fails.|53/udp 53/tcp|Yes|install-dnstt.sh|dnstt|vany-dnstt|dnstt|dnstt|||dns-edge|||
slipstream|Slipstream|Enhanced DNS tunnel with QUIC+TLS. ~63 KB/s.|53/udp|Yes|install-slipstream.sh|slipstream|vany-slipstream|slipstream|slipstream|||dns-edge|||
noizdns|NoizDNS|DPI-resistant DNSTT fork with noise padding.|53/udp|Yes|install-noizdns.sh|noizdns|vany-noizdns|noizdns|noizdns|||dns-edge|||
conduit|Conduit (Psiphon Relay)|Psiphon volunteer relay. Auto-configures, zero maintenance.|auto|No|install-conduit.sh|conduit|vany-conduit|conduit|conduit|||conduit|||
tor-bridge|Tor Bridge (obfs4)|obfs4 pluggable transport bridge for the Tor network.|9001/tcp|No|install-tor-bridge.sh|tor-bridge|vany-tor-bridge|tor-bridge|tor-bridge|||tor-bridge|||
snowflake|Snowflake Proxy|WebRTC Tor relay. Zero config, minimal resources.|--|No|install-snowflake.sh|snowflake|vany-snowflake|snowflake|snowflake|||snowflake|||
sos|SOS Emergency Chat|E2E encrypted emergency chat over DNS tunnel.|8899/tcp|Yes|install-sos.sh|sos|vany-sos|sos|sos|||sos|||
EOF
)

vany_protocol_field() {
    local protocol="$1"
    local field="$2"
    local key name desc ports needs_domain script runtime container state_key data_dir feature_key inbound_tag conflict_group add_user remove_user uninstall

    while IFS='|' read -r key name desc ports needs_domain script runtime container state_key data_dir feature_key inbound_tag conflict_group add_user remove_user uninstall; do
        [[ -n "$key" ]] || continue
        [[ "$key" == "$protocol" ]] || continue

        case "$field" in
            name) printf '%s' "$name" ;;
            desc) printf '%s' "$desc" ;;
            ports) printf '%s' "$ports" ;;
            needs_domain) printf '%s' "$needs_domain" ;;
            script) printf '%s' "$script" ;;
            runtime) printf '%s' "$runtime" ;;
            container) printf '%s' "$container" ;;
            state_key) printf '%s' "$state_key" ;;
            data_dir) printf '%s' "$data_dir" ;;
            feature_key) printf '%s' "$feature_key" ;;
            inbound_tag) printf '%s' "$inbound_tag" ;;
            conflict_group) printf '%s' "$conflict_group" ;;
            add_user) printf '%s' "$add_user" ;;
            remove_user) printf '%s' "$remove_user" ;;
            uninstall) printf '%s' "$uninstall" ;;
            *) return 2 ;;
        esac
        return 0
    done <<< "$VANY_PROTOCOL_RECORDS"

    return 1
}

vany_protocol_get() {
    local protocol="$1"
    local field="$2"
    local fallback="${3:-}"
    local value

    if value=$(vany_protocol_field "$protocol" "$field"); then
        if [[ -n "$value" ]]; then
            printf '%s' "$value"
        else
            printf '%s' "$fallback"
        fi
    else
        printf '%s' "$fallback"
    fi
}

vany_protocol_exists() {
    vany_protocol_field "$1" name >/dev/null 2>&1
}

vany_protocol_list_inline() {
    local first=true
    local protocol
    for protocol in "${VANY_PROTOCOLS[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            printf ' '
        fi
        printf '%s' "$protocol"
    done
}

vany_protocol_name() {
    vany_protocol_get "$1" name "$1"
}

vany_protocol_desc() {
    vany_protocol_get "$1" desc ""
}

vany_protocol_ports() {
    vany_protocol_get "$1" ports ""
}

vany_protocol_needs_domain() {
    vany_protocol_get "$1" needs_domain ""
}

vany_protocol_script() {
    vany_protocol_get "$1" script ""
}

vany_protocol_state_key() {
    vany_protocol_get "$1" state_key "$1"
}

vany_protocol_container() {
    local protocol="$1"
    local value

    if value=$(vany_protocol_field "$protocol" container); then
        printf '%s' "$value"
    else
        printf 'vany-%s' "$protocol"
    fi
}

vany_protocol_runtime() {
    vany_protocol_get "$1" runtime "$1"
}

vany_protocol_data_dir() {
    local protocol="$1"
    local value

    value=$(vany_protocol_get "$protocol" data_dir "")
    if [[ -n "$value" ]]; then
        printf '%s' "$value"
    else
        vany_protocol_runtime "$protocol"
    fi
}

vany_protocol_feature_key() {
    vany_protocol_field "$1" feature_key 2>/dev/null || true
}

vany_protocol_inbound_tag() {
    vany_protocol_field "$1" inbound_tag 2>/dev/null || true
}

vany_protocol_conflict_group() {
    vany_protocol_get "$1" conflict_group ""
}

vany_protocol_add_user_hook() {
    vany_protocol_field "$1" add_user 2>/dev/null || true
}

vany_protocol_remove_user_hook() {
    vany_protocol_field "$1" remove_user 2>/dev/null || true
}

vany_protocol_uninstall_hook() {
    vany_protocol_field "$1" uninstall 2>/dev/null || true
}