#!/bin/bash
#===============================================================================
# Vany - Direct Protocol Installer
# Standalone installer/manager for a single protocol.
# Usage: VANY_PROTOCOL=reality bash direct-install.sh
#===============================================================================

set -e

# When piped via curl, stdin is the script itself. Read user input from /dev/tty.
exec 3</dev/tty 2>/dev/null || { echo "Error: No terminal available for interactive input"; exit 1; }

PROTOCOL="${VANY_PROTOCOL:-}"
VANY_DIR="/opt/vany"
STATE_FILE="$VANY_DIR/state.json"
USERS_FILE="$VANY_DIR/users.json"
GITHUB_RAW="https://raw.githubusercontent.com/behnamkhorsandian/Vanysh/main"

# ── Colors (Vany theme) ──────────────────────────────────────────────────────
G='\033[38;5;42m'      # Green
LG='\033[38;5;48m'     # Light green
O='\033[38;5;214m'     # Orange
D='\033[38;5;240m'     # Dark gray
R='\033[0m'            # Reset
B='\033[1m'            # Bold
DM='\033[2m'           # Dim
RED='\033[38;5;130m'   # Red/warning
BLUE='\033[38;5;39m'   # Blue
YELLOW='\033[38;5;220m'

W=70  # Width

# ── Helpers ───────────────────────────────────────────────────────────────────

hr() { printf "  ${D}"; printf '─%.0s' $(seq 1 "$W"); printf "${R}\n"; }
section() { echo -e "\n  ${O}${B}$1${R}"; hr; }
step()    { echo -e "  ${G}>${R} $1"; }
ok()      { echo -e "  ${G}*${R} $1"; }
err()     { echo -e "  ${RED}!${R} $1"; }
info()    { echo -e "  ${D}  $1${R}"; }

# ── Protocol Registry ─────────────────────────────────────────────────────────

load_protocol_registry() {
    local local_registry
    local_registry="$(dirname "${BASH_SOURCE[0]}")/lib/protocol-registry.sh"

    if [[ -f "$local_registry" ]]; then
        source "$local_registry"
        return 0
    fi

    local registry_file="/tmp/vany-protocol-registry.sh"
    if ! curl -sfL "$GITHUB_RAW/scripts/lib/protocol-registry.sh" -o "$registry_file"; then
        err "Failed to download protocol registry"
        exit 1
    fi
    source "$registry_file"
}

# ── ASCII Art Banners ─────────────────────────────────────────────────────────

declare -A BANNERS
BANNERS[reality]='░█▀▄░█▀▀░█▀█░█░░░▀█▀░▀█▀░█░█
░█▀▄░█▀▀░█▀█░█░░░░█░░░█░░░█░
░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░░▀░░░▀░'

BANNERS[ws]='░█░█░█▀▀░░░█░█▀▀░█▀▄░█▀█
░█▄█░▀▀█░▄▀░░█░░░█░█░█░█
░▀░▀░▀▀▀░▀░░░▀▀▀░▀▀░░▀░▀'

BANNERS[hysteria]='░█░█░█░█░█▀▀░▀█▀░█▀▀░█▀▄░▀█▀░█▀█
░█▀█░░█░░▀▀█░░█░░█▀▀░█▀▄░░█░░█▀█
░▀░▀░░▀░░▀▀▀░░▀░░▀▀▀░▀░▀░▀▀▀░▀░▀'

BANNERS[wg]='░█░█░▀█▀░█▀▄░█▀▀░█▀▀░█░█░█▀█░█▀▄░█▀▄
░█▄█░░█░░█▀▄░█▀▀░█░█░█░█░█▀█░█▀▄░█░█
░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀░▀░▀▀░'

BANNERS[vray]='░█░█░█▀▄░█▀█░█░█
░▀▄▀░█▀▄░█▀█░░█░
░░▀░░▀░▀░▀░▀░░▀░'

BANNERS[http-obfs]='░█░█░▀█▀░▀█▀░█▀█░░░█▀█░█▀▄░█▀▀░█▀▀
░█▀█░░█░░░█░░█▀▀░░░█░█░█▀▄░█▀▀░▀▀█
░▀░▀░░▀░░░▀░░▀░░░░░▀▀▀░▀▀░░▀░░░▀▀▀'

BANNERS[mtp]='░█▄█░▀█▀░█▀█░█▀▄░█▀█░▀█▀░█▀█
░█░█░░█░░█▀▀░█▀▄░█░█░░█░░█░█
░▀░▀░░▀░░▀░░░▀░▀░▀▀▀░░▀░░▀▀▀'

BANNERS[ssh-tunnel]='░█▀▀░█▀▀░█░█░░░▀█▀░█░█░█▀█░█▀█░█▀▀░█░░
░▀▀█░▀▀█░█▀█░░░░█░░█░█░█░█░█░█░█▀▀░█░░
░▀▀▀░▀▀▀░▀░▀░░░░▀░░▀▀▀░▀░▀░▀░▀░▀▀▀░▀▀▀'

BANNERS[dnstt]='░█▀▄░█▀█░█▀▀░▀█▀░▀█▀
░█░█░█░█░▀▀█░░█░░░█░
░▀▀░░▀░▀░▀▀▀░░▀░░░▀░'

BANNERS[slipstream]='░█▀▀░█░░░▀█▀░█▀█░█▀▀░▀█▀░█▀▄░█▀▀░█▀█░█▄█
░▀▀█░█░░░░█░░█▀▀░▀▀█░░█░░█▀▄░█▀▀░█▀█░█░█
░▀▀▀░▀▀▀░▀▀▀░▀░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░▀░▀'

BANNERS[noizdns]='░█▀█░█▀█░▀█▀░▀█▀░█▀▄░█▀█░█▀▀
░█░█░█░█░░█░░░█░░█░█░█░█░▀▀█
░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀░░▀░▀░▀▀▀'

BANNERS[conduit]='░█▀▀░█▀█░█▀█░█▀▄░█░█░▀█▀░▀█▀
░█░░░█░█░█░█░█░█░█░█░░█░░░█░
░▀▀▀░▀▀▀░▀░▀░▀▀░░▀▀▀░▀▀▀░░▀░'

BANNERS[tor-bridge]='░▀█▀░█▀█░█▀▄░░░█▀▄░█▀▄░▀█▀░█▀▄░█▀▀░█▀▀
░░█░░█░█░█▀▄░░░█▀▄░█▀▄░░█░░█░█░█░█░█▀▀
░░▀░░▀▀▀░▀░▀░░░▀▀░░▀░▀░▀▀▀░▀▀░░▀▀▀░▀▀▀'

BANNERS[snowflake]='░█▀▀░█▀█░█▀█░█░█░█▀▀░█░░░█▀█░█░█░█▀▀
░▀▀█░█░█░█░█░█▄█░█▀▀░█░░░█▀█░█▀▄░█▀▀
░▀▀▀░▀░▀░▀▀▀░▀░▀░▀░░░▀▀▀░▀░▀░▀░▀░▀▀▀'

BANNERS[sos]='░█▀▀░█▀█░█▀▀
░▀▀█░█░█░▀▀█
░▀▀▀░▀▀▀░▀▀▀'

load_protocol_registry

# ── Validation ────────────────────────────────────────────────────────────────

if [[ -z "$PROTOCOL" ]]; then
    echo -e "\n  ${RED}! No protocol specified${R}"
    echo -e "  ${D}Usage: VANY_PROTOCOL=reality bash direct-install.sh${R}\n"
    exit 1
fi

if ! vany_protocol_exists "$PROTOCOL"; then
    echo -e "\n  ${RED}! Unknown protocol: $PROTOCOL${R}"
    echo -e "  ${D}Valid: $(vany_protocol_list_inline)${R}\n"
    exit 1
fi

# ── Root Check ────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    echo -e "\n  ${RED}! This installer must be run as root${R}"
    echo -e "  ${D}Use: curl vany.sh/$PROTOCOL | sudo bash${R}\n"
    exit 1
fi

# ── Display Banner ────────────────────────────────────────────────────────────

clear 2>/dev/null || true
echo ""

banner="${BANNERS[$PROTOCOL]}"
if [[ -n "$banner" ]]; then
    while IFS= read -r line; do
        local_len=${#line}
        pad=$(( (W - local_len) / 2 + 2 ))
        printf "%*s" "$pad" ""
        echo -e "${G}${line}${R}"
    done <<< "$banner"
    echo ""
fi

# ── Protocol Info ─────────────────────────────────────────────────────────────

name="$(vany_protocol_name "$PROTOCOL")"
desc="$(vany_protocol_desc "$PROTOCOL")"
ports="$(vany_protocol_ports "$PROTOCOL")"
domain="$(vany_protocol_needs_domain "$PROTOCOL")"

echo -e "  ${LG}${B}${name}${R}"
echo -e "  ${D}${desc}${R}"
echo ""
echo -e "  ${D}Ports: ${R}${ports}    ${D}Domain required: ${R}${domain}"
hr

# ── Check Current Status ─────────────────────────────────────────────────────

container_name=""
is_installed=false
is_running=false

check_status() {
    if [[ -f "$STATE_FILE" ]] && command -v jq &>/dev/null; then
        local proto_key
        proto_key=$(vany_protocol_state_key "$PROTOCOL")
        local feature_key
        feature_key=$(vany_protocol_feature_key "$PROTOCOL")

        local status
        status=$(jq -r --arg proto "$proto_key" '.protocols[$proto].status // empty' "$STATE_FILE" 2>/dev/null)
        container_name=$(jq -r --arg proto "$proto_key" '.protocols[$proto].container // empty' "$STATE_FILE" 2>/dev/null)
        [[ -z "$container_name" ]] && container_name=$(vany_protocol_container "$PROTOCOL")

        if [[ -n "$feature_key" ]]; then
            local feature_state
            feature_state=$(jq -r --arg proto "$proto_key" --arg feature "$feature_key" '.protocols[$proto][$feature] // empty' "$STATE_FILE" 2>/dev/null)
            [[ -z "$feature_state" ]] && status=""
        fi

        if [[ -n "$status" ]]; then
            is_installed=true
            if [[ -n "$container_name" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
                is_running=true
            fi
        fi
    fi
}

check_status

echo ""
if $is_running; then
    echo -e "  ${G}${B}Status:${R} ${G}Running${R}  ${D}(container: ${container_name})${R}"
elif $is_installed; then
    echo -e "  ${YELLOW}${B}Status:${R} ${YELLOW}Stopped${R}  ${D}(container: ${container_name})${R}"
else
    echo -e "  ${D}${B}Status:${R} ${D}Not installed${R}"
fi
echo ""

# ── Menu ──────────────────────────────────────────────────────────────────────

show_menu() {
    if $is_installed; then
        echo -e "  ${O}${B}What would you like to do?${R}"
        echo ""
        echo -e "    ${LG}1${R}  Reinstall / Update"
        echo -e "    ${LG}2${R}  Add user"
        echo -e "    ${LG}3${R}  Remove user"
        echo -e "    ${LG}4${R}  Show connection config"
        echo -e "    ${LG}5${R}  View logs"
        echo -e "    ${LG}6${R}  Restart"
        echo -e "    ${LG}7${R}  Uninstall"
        echo -e "    ${LG}q${R}  Quit"
    else
        echo -e "  ${O}${B}Ready to install?${R}"
        echo ""
        echo -e "    ${LG}1${R}  Install ${name}"
        echo -e "    ${LG}q${R}  Quit"
    fi
    echo ""
}

# ── Bootstrap System ──────────────────────────────────────────────────────────

do_bootstrap() {
    section "System Bootstrap"

    # Download and source bootstrap
    local bootstrap_file="/tmp/vany-bootstrap.sh"
    step "Downloading bootstrap..."
    if ! curl -sfL "$GITHUB_RAW/scripts/docker-bootstrap.sh" -o "$bootstrap_file"; then
        err "Failed to download bootstrap script"
        exit 1
    fi
    source "$bootstrap_file"
    bootstrap
    echo ""
}

# ── Download Protocol Script ──────────────────────────────────────────────────

do_download_script() {
    local script_name
    script_name="$(vany_protocol_script "$PROTOCOL")"
    local script_path="/tmp/vany-${script_name}"

    step "Downloading ${script_name}..."
    if ! curl -sfL "$GITHUB_RAW/scripts/protocols/${script_name}" -o "$script_path"; then
        err "Failed to download install script"
        exit 1
    fi
    chmod +x "$script_path"
    source "$script_path"
}

# ── Install Protocol ──────────────────────────────────────────────────────────

do_install() {
    section "Installing ${name}"

    do_bootstrap
    do_download_script

    # Call the appropriate install function
    case "$PROTOCOL" in
        reality)
            install_xray
            ensure_reality_inbound
            reload_xray
            ;;
        ws)
            install_xray
            # WS inbound needs domain
            read -rp "  Enter your domain (e.g. ws.example.com): " ws_domain <&3
            if [[ -n "$ws_domain" ]]; then
                add_ws_inbound "/ws"
                set_ws_state "$ws_domain" "/ws"
                reload_xray
            fi
            ;;
        hysteria)
            install_hysteria
            ;;
        wg)
            install_wireguard
            ;;
        dnstt)
            install_dnstt
            ;;
        conduit)
            install_conduit
            ;;
        sos)
            install_sos
            ;;
        tor-bridge)
            install_tor_bridge
            ;;
        snowflake)
            install_snowflake
            ;;
        slipstream)
            install_slipstream
            ;;
        noizdns)
            install_noizdns
            ;;
        ssh-tunnel)
            install_ssh_tunnel
            ;;
        http-obfs)
            read -rp "  Enter CDN domain: " cdn_domain <&3
            if [[ -n "$cdn_domain" ]]; then
                HTTP_OBFS_DOMAIN="$cdn_domain" install_http_obfs
            fi
            ;;
        vray)
            install_xray
            read -rp "  Enter your domain: " vray_domain <&3
            if [[ -n "$vray_domain" ]] && declare -F add_vray_inbound >/dev/null; then
                add_vray_inbound "$vray_domain"
            else
                err "VLESS+TLS Docker inbound is not implemented yet"
                return 1
            fi
            ;;
        mtp)
            install_xray
            if declare -F add_mtp_inbound >/dev/null; then
                add_mtp_inbound
            else
                err "MTProto Docker inbound is not implemented yet"
                return 1
            fi
            ;;
        *)
            err "Install function not implemented for: $PROTOCOL"
            return 1
            ;;
    esac

    echo ""
    ok "Installation complete!"
    echo ""

    # Refresh status
    check_status
}

# ── User Management ───────────────────────────────────────────────────────────

do_add_user() {
    section "Add User"
    read -rp "  Username: " username <&3
    [[ -z "$username" ]] && { err "Username required"; return; }

    do_download_script

    case "$PROTOCOL" in
        hysteria)
            echo "  Hysteria uses shared password auth"
            ;;
        *)
            local add_fn
            add_fn="$(vany_protocol_add_user_hook "$PROTOCOL")"
            if [[ -n "$add_fn" ]] && declare -F "$add_fn" >/dev/null; then
                "$add_fn" "$username"
            else
                info "User management not implemented for $PROTOCOL"
            fi
            ;;
    esac
}

do_remove_user() {
    section "Remove User"
    read -rp "  Username to remove: " username <&3
    [[ -z "$username" ]] && { err "Username required"; return; }

    do_download_script

    local remove_fn
    remove_fn="$(vany_protocol_remove_user_hook "$PROTOCOL")"
    if [[ -n "$remove_fn" ]] && declare -F "$remove_fn" >/dev/null; then
        "$remove_fn" "$username"
    else
        info "User management not implemented for $PROTOCOL"
    fi
}

# ── Show Config ───────────────────────────────────────────────────────────────

do_show_config() {
    section "Connection Config"

    do_download_script

    local server_ip
    server_ip=$(jq -r '.ip // "unknown"' "$STATE_FILE" 2>/dev/null)

    case "$PROTOCOL" in
        reality)
            if [[ -f "$USERS_FILE" ]]; then
                echo -e "  ${D}REALITY configs:${R}"
                jq -r '.users | to_entries[] | select(.value.protocols.reality) | [.key, .value.protocols.reality.uuid] | @tsv' "$USERS_FILE" 2>/dev/null |
                    while IFS=$'\t' read -r username uuid; do
                        if declare -F reality_link >/dev/null; then
                            echo "  ${username}: $(reality_link "$uuid" "$username")"
                        else
                            echo "  ${username}: ${uuid}"
                        fi
                    done
            fi
            ;;
        ws)
            if [[ -f "$USERS_FILE" ]]; then
                echo -e "  ${D}WS+CDN configs:${R}"
                jq -r '.users | to_entries[] | select(.value.protocols.ws) | [.key, .value.protocols.ws.uuid] | @tsv' "$USERS_FILE" 2>/dev/null |
                    while IFS=$'\t' read -r username uuid; do
                        if declare -F ws_link >/dev/null; then
                            echo "  ${username}: $(ws_link "$uuid" "$username")"
                        else
                            echo "  ${username}: ${uuid}"
                        fi
                    done
            fi
            ;;
        wg)
            if [[ -d "$VANY_DIR/wg/peers" ]]; then
                echo -e "  ${D}WireGuard peer configs:${R}"
                ls "$VANY_DIR/wg/peers/" 2>/dev/null
            fi
            ;;
        hysteria)
            local pw
            pw=$(jq -r '.protocols.hysteria.password // "unknown"' "$STATE_FILE" 2>/dev/null)
            echo -e "  hysteria2://${pw}@${server_ip}:8443/?insecure=1#vany-hysteria"
            ;;
        *)
            info "Config display not implemented for $PROTOCOL"
            ;;
    esac
    echo ""
}

# ── View Logs ─────────────────────────────────────────────────────────────────

do_logs() {
    section "Container Logs (last 30 lines)"
    if [[ -n "$container_name" ]]; then
        docker logs --tail 30 "$container_name" 2>&1 | while IFS= read -r line; do
            echo -e "  ${D}${line}${R}"
        done
    else
        info "Container not found"
    fi
    echo ""
}

# ── Restart ───────────────────────────────────────────────────────────────────

do_restart() {
    section "Restarting"
    if [[ -n "$container_name" ]]; then
        docker restart "$container_name"
        ok "Container restarted"
    else
        err "Container not found"
    fi
    echo ""
    check_status
}

# ── Uninstall ─────────────────────────────────────────────────────────────────

do_generic_uninstall() {
    if [[ -n "$(vany_protocol_feature_key "$PROTOCOL")" ]]; then
        err "Shared-runtime uninstall hook missing for $PROTOCOL"
        return 1
    fi

    if [[ -n "$container_name" ]]; then
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
        ok "Container removed"
    fi

    if [[ -f "$STATE_FILE" ]] && command -v jq &>/dev/null; then
        local proto_key
        proto_key=$(vany_protocol_state_key "$PROTOCOL")
        jq --arg proto "$proto_key" 'del(.protocols[$proto])' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    fi
}

do_uninstall() {
    section "Uninstall ${name}"
    echo -e "  ${RED}This will remove ${name} from this server.${R}"
    if [[ -n "$(vany_protocol_feature_key "$PROTOCOL")" ]]; then
        echo -e "  ${D}Shared runtimes stay up if another protocol still uses them.${R}"
    fi
    read -rp "  Are you sure? (y/N): " confirm <&3
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        do_download_script

        local uninstall_fn
        uninstall_fn=$(vany_protocol_uninstall_hook "$PROTOCOL")
        if [[ -n "$uninstall_fn" ]] && declare -F "$uninstall_fn" >/dev/null; then
            "$uninstall_fn"
        else
            do_generic_uninstall
        fi

        is_installed=false
        is_running=false
        check_status
        ok "Uninstall complete"
    else
        info "Cancelled"
    fi
    echo ""
}

# ── Main Loop ─────────────────────────────────────────────────────────────────

while true; do
    show_menu
    read -rp "  > " choice <&3
    echo ""

    case "$choice" in
        1)
            if $is_installed; then
                do_install  # Reinstall
            else
                do_install
            fi
            ;;
        2) $is_installed && do_add_user || do_install ;;
        3) $is_installed && do_remove_user ;;
        4) $is_installed && do_show_config ;;
        5) $is_installed && do_logs ;;
        6) $is_installed && do_restart ;;
        7) $is_installed && do_uninstall ;;
        q|Q|exit) echo -e "  ${D}Goodbye${R}\n"; exit 0 ;;
        *) err "Invalid option" ;;
    esac
done
