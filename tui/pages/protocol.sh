#!/bin/bash
#===============================================================================
# DNSCloak TUI - Protocol Detail / Management Page
# Shows protocol info, guides, and action menu for each protocol
#===============================================================================

TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TUI_DIR/engine.sh"

#-------------------------------------------------------------------------------
# Protocol guide text (shown in left panel)
#-------------------------------------------------------------------------------

declare -A PROTOCOL_GUIDE

PROTOCOL_GUIDE[reality]="VLESS + REALITY uses Xray-core to create a
proxy that mimics legitimate HTTPS traffic.

How it works:
  Your server pretends to be a normal website
  (like google.com or apple.com). Censors see
  what looks like regular HTTPS connections.

When to use:
  * First choice for most users
  * Works without a domain name
  * Very fast, low overhead
  * Hard to detect and block

Port used: 443 (HTTPS)"

PROTOCOL_GUIDE[wg]="WireGuard is a modern VPN protocol. It creates
an encrypted tunnel for ALL device traffic.

How it works:
  Lightweight kernel-level VPN. Uses public key
  cryptography. Extremely fast handshakes.

When to use:
  * You want a full VPN (all traffic tunneled)
  * You need native app support (iOS/Android)
  * You want simplicity and speed
  * May be blocked by DPI in some countries

Port used: 51820 (UDP)"

PROTOCOL_GUIDE[ws]="VLESS + WebSocket routes traffic through
Cloudflare's CDN network.

How it works:
  Traffic goes: Client -> Cloudflare CDN ->
  Your server. Censors only see Cloudflare IPs.
  Your real server IP stays completely hidden.

When to use:
  * Your server IP is already blocked
  * You want IP protection via CDN
  * You have a domain on Cloudflare

Requires: Domain name with Cloudflare DNS
Port used: 80 (HTTP, Cloudflare handles TLS)"

PROTOCOL_GUIDE[mtp]="MTProto Proxy is Telegram's built-in proxy
protocol. It only works for Telegram.

How it works:
  Runs a proxy server that speaks Telegram's
  native protocol. Supports Fake-TLS mode to
  disguise traffic as HTTPS.

When to use:
  * You only need Telegram access
  * Users don't want to install extra apps
  * Simple, single-purpose solution

Port used: Custom (you choose during setup)"

PROTOCOL_GUIDE[dnstt]="DNS Tunnel encodes data inside DNS queries.
This is an emergency backup protocol.

How it works:
  All traffic is encoded as DNS lookups to your
  domain. Works even when all other protocols
  are blocked because DNS queries are essential.

When to use:
  * Total internet blackout
  * All other protocols are blocked
  * Emergency backup (VERY slow: ~50 KB/s)

Requires: Domain with NS record configured
Port used: 53 (DNS)"

PROTOCOL_GUIDE[conduit]="Conduit turns your server into a volunteer
relay node for the Psiphon network.

How it works:
  Runs a Docker container that relays traffic
  for Psiphon users. You donate bandwidth to
  help people in censored regions.

When to use:
  * You want to help others bypass censorship
  * You have spare bandwidth to donate
  * No client configuration needed

Requires: Docker
Port used: Assigned automatically"

PROTOCOL_GUIDE[vray]="VLESS + TLS is the classic V2Ray setup with
proper TLS certificates.

How it works:
  Standard proxy with real TLS certificate from
  Let's Encrypt. Looks like any HTTPS website.

When to use:
  * You have a domain name
  * You want maximum compatibility
  * Standard V2Ray/Xray setup

Requires: Domain name + valid DNS
Port used: 443 (HTTPS)"

PROTOCOL_GUIDE[sos]="SOS is an encrypted emergency chat system
that works over DNS tunnels.

How it works:
  Messages are encrypted end-to-end using NaCl.
  They travel through the DNSTT tunnel, making
  them nearly impossible to block.

When to use:
  * Emergency communication during blackouts
  * Needs DNSTT service running first
  * Available as TUI app or web interface

Requires: DNSTT service running, Python 3.8+"

#-------------------------------------------------------------------------------
# Protocol detail page — shows guide + action menu
# Usage: page_protocol "protocol_id"
# Returns: action string in PROTOCOL_ACTION
#   install, add_user, remove_user, show_links, status, uninstall, back
#-------------------------------------------------------------------------------

page_protocol() {
    local proto="$1"
    local proto_name="${PROTOCOL_NAMES[$proto]}"
    local guide="${PROTOCOL_GUIDE[$proto]}"
    local selected=0

    # Determine available actions based on install status
    local is_installed=0
    if type service_installed &>/dev/null; then
        service_installed "$proto" && is_installed=1
    fi

    while true; do
        tui_get_size
        local width=$(( _TERM_COLS > 110 ? 110 : _TERM_COLS - 4 ))
        (( width < 70 )) && width=70
        local compact=0
        (( width < 90 )) && compact=1

        # Build action list
        local actions=()
        local action_ids=()
        if [[ $is_installed -eq 0 ]]; then
            actions+=("Install ${proto_name}")
            action_ids+=("install")
        else
            actions+=("Add User" "Remove User" "Show User Links" "Service Status" "Restart Service" "Uninstall")
            action_ids+=("add_user" "remove_user" "show_links" "status" "restart" "uninstall")
        fi
        actions+=("Back to Main Menu")
        action_ids+=("back")

        local action_count=${#actions[@]}

        clear_screen

        # Banner
        local banner_name="$proto"
        [[ "$proto" == "wg" ]] && banner_name="wireguard"
        render_banner "$banner_name" "$C_BLUE"
        printf '\n'

        if (( compact )); then
            # Compact: just action list
            draw_box_top "$width" "$proto_name"
            draw_box_empty "$width"

            # Status line
            if [[ $is_installed -eq 1 ]]; then
                local status_text=""
                if type service_running &>/dev/null && service_running "$proto"; then
                    status_text="Status: $badge_running"
                else
                    status_text="Status: $badge_stopped"
                fi
                draw_box_row " $status_text" "$width"
                draw_box_empty "$width"
            fi

            # Guide text (first 5 lines only in compact)
            local line_count=0
            while IFS= read -r line; do
                (( line_count >= 5 )) && break
                draw_box_row " ${C_TEXT}${line}${C_RST}" "$width"
                (( line_count++ ))
            done <<< "$guide"

            draw_box_empty "$width"
            draw_box_sep "$width"
            draw_box_empty "$width"

            # Action menu
            local i=0
            for action in "${actions[@]}"; do
                local prefix="   "
                local lcolor="$C_TEXT"
                if [[ $i -eq $selected ]]; then
                    prefix=" ${C_GREEN}>${C_RST}"
                    lcolor="${C_GREEN}${C_BOLD}"
                fi
                draw_box_row "${prefix} ${lcolor}${action}${C_RST}" "$width"
                (( i++ ))
            done

            draw_box_empty "$width"
            draw_box_sep "$width"
            draw_box_row " ${C_DGRAY}Up/Down${C_RST}${C_DIM} navigate${C_RST}  ${C_DGRAY}Enter${C_RST}${C_DIM} select${C_RST}  ${C_DGRAY}Esc${C_RST}${C_DIM} back${C_RST}" "$width"
            draw_box_bottom "$width"
        else
            # Full split layout: guide (left) + actions (right)
            compute_split "$width" 60

            draw_split_top "$width" "$proto_name" "Actions"

            # Status line
            if [[ $is_installed -eq 1 ]]; then
                local status_text=""
                if type service_running &>/dev/null && service_running "$proto"; then
                    status_text="Status: $badge_running"
                else
                    status_text="Status: $badge_stopped"
                fi
                draw_split_row " $status_text" "" "$width"
            fi
            draw_split_empty "$width"

            # Build guide lines array
            local guide_lines=()
            while IFS= read -r line; do
                guide_lines+=("$line")
            done <<< "$guide"

            # Draw rows
            local guide_count=${#guide_lines[@]}
            local max_rows=$guide_count
            (( action_count + 2 > max_rows )) && max_rows=$(( action_count + 2 ))

            for (( r = 0; r < max_rows; r++ )); do
                local left_text=""
                if (( r < guide_count )); then
                    left_text=" ${C_TEXT}${guide_lines[$r]}${C_RST}"
                fi

                local right_text=""
                if (( r < action_count )); then
                    local prefix="   "
                    local lcolor="$C_TEXT"
                    if [[ $r -eq $selected ]]; then
                        prefix=" ${C_GREEN}>${C_RST}"
                        lcolor="${C_GREEN}${C_BOLD}"
                    fi
                    right_text="${prefix} ${lcolor}${actions[$r]}${C_RST}"
                fi

                draw_split_row "$left_text" "$right_text" "$width"
            done

            draw_split_empty "$width"
            draw_split_sep "$width"

            # Client apps info
            local clients="${PROTOCOL_CLIENTS[$proto]}"
            local client_line=""
            IFS=$'\n' read -r client_line <<< "$(printf '%b' "$clients")"
            draw_box_row " ${C_LGREEN}Client Apps:${C_RST} ${C_LGRAY}${client_line}${C_RST}" "$width"

            draw_box_sep "$width"
            draw_box_row " ${C_DGRAY}Up/Down${C_RST}${C_DIM} navigate${C_RST}  ${C_DGRAY}Enter${C_RST}${C_DIM} select${C_RST}  ${C_DGRAY}Esc${C_RST}${C_DIM} back${C_RST}" "$width"
            draw_box_bottom "$width"
        fi

        # Key handling
        local key
        key=$(tui_read_key)

        case "$key" in
            UP)
                (( selected-- ))
                (( selected < 0 )) && selected=$(( action_count - 1 ))
                ;;
            DOWN)
                (( selected++ ))
                (( selected >= action_count )) && selected=0
                ;;
            ENTER)
                PROTOCOL_ACTION="${action_ids[$selected]}"
                return 0
                ;;
            ESC)
                PROTOCOL_ACTION="back"
                return 0
                ;;
            q|Q)
                PROTOCOL_ACTION="quit"
                return 0
                ;;
        esac
    done
}
