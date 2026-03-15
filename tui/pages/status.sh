#!/bin/bash
#===============================================================================
# DNSCloak TUI - Status Dashboard Page
# Shows service status, server info, ports, and system stats
#===============================================================================

TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TUI_DIR/engine.sh"

#-------------------------------------------------------------------------------
# Status dashboard — split layout: services (left) + server info (right)
#-------------------------------------------------------------------------------

page_status() {
    while true; do
        tui_get_size
        tui_compute_layout

        clear_screen
        render_banner "logo" "$C_GREEN"
        printf '\n'

        # ── Gather data ──────────────────────────────────────────────────
        # Server info
        local server_ip="unknown"
        local server_domain=""
        local server_provider="unknown"
        local user_count=0

        if [[ -f "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" ]] && type jq &>/dev/null; then
            server_ip=$(jq -r '.server.ip // "unknown"' "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" 2>/dev/null)
            server_domain=$(jq -r '.server.domain // ""' "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" 2>/dev/null)
            server_provider=$(jq -r '.server.provider // "unknown"' "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" 2>/dev/null)
            user_count=$(jq -r '.users // {} | keys | length' "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" 2>/dev/null)
        fi

        # System stats
        local uptime_str=""
        uptime_str=$(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /' | sed 's/,.*//')
        local load_avg=""
        load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || echo "N/A")
        local mem_used="" mem_total=""
        if type free &>/dev/null; then
            mem_used=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
            mem_total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
        fi

        # Service statuses
        local service_lines=()
        for proto in "${PROTOCOL_IDS[@]}"; do
            local name="${PROTOCOL_NAMES[$proto]}"
            local status_badge=""
            local status_detail=""

            if type service_installed &>/dev/null && service_installed "$proto"; then
                if type service_running &>/dev/null && service_running "$proto"; then
                    status_badge="$badge_running"
                    status_detail="${C_GREEN}active${C_RST}"
                else
                    status_badge="$badge_stopped"
                    status_detail="${C_YELLOW}inactive${C_RST}"
                fi
            else
                status_badge="$badge_not_installed"
                status_detail="${C_DGRAY}--${C_RST}"
            fi

            service_lines+=("${name}|${status_badge}|${status_detail}")
        done

        # ── Render ───────────────────────────────────────────────────────

        if (( _COMPACT )); then
            # Compact: single column
            draw_box_top "" "System Status"
            draw_box_empty

            # Server info
            draw_box_row " ${C_ORANGE}Server${C_RST}"
            draw_box_row "   ${C_LGRAY}IP:${C_RST}       ${C_TEXT}${server_ip}${C_RST}"
            [[ -n "$server_domain" && "$server_domain" != "null" ]] && \
                draw_box_row "   ${C_LGRAY}Domain:${C_RST}   ${C_TEXT}${server_domain}${C_RST}"
            draw_box_row "   ${C_LGRAY}Provider:${C_RST} ${C_TEXT}${server_provider}${C_RST}"
            draw_box_row "   ${C_LGRAY}Users:${C_RST}    ${C_TEXT}${user_count}${C_RST}"
            draw_box_row "   ${C_LGRAY}Uptime:${C_RST}   ${C_TEXT}${uptime_str}${C_RST}"

            draw_box_empty
            draw_box_sep
            draw_box_empty

            # Services
            draw_box_row " ${C_ORANGE}Services${C_RST}"
            for sline in "${service_lines[@]}"; do
                IFS='|' read -r sname sbadge sdetail <<< "$sline"
                draw_box_row "   ${C_TEXT}${sname}${C_RST}  ${sbadge}"
            done

            # Vertical fill
            local chrome_rows=$(( _BANNER_HEIGHT + 1 + 10 + ${#service_lines[@]} + 5 ))
            local avail=$(( _TERM_ROWS - chrome_rows ))
            while (( avail-- > 0 )); do draw_box_empty; done

            draw_box_sep
            draw_box_row " ${C_DGRAY}r${C_RST}${C_DIM} refresh${C_RST}  ${C_DGRAY}Esc${C_RST}${C_DIM} back${C_RST}  ${C_DGRAY}q${C_RST}${C_DIM} quit${C_RST}"
            draw_box_bottom
        else
            # Split layout
            compute_split "$_FRAME_W" 60

            draw_split_top "" "Services" "Server Info"
            draw_split_empty

            # Build right panel lines
            local right_lines=(
                "${C_ORANGE}Server${C_RST}"
                ""
                "  ${C_LGRAY}IP:${C_RST}       ${C_TEXT}${server_ip}${C_RST}"
            )
            [[ -n "$server_domain" && "$server_domain" != "null" ]] && \
                right_lines+=("  ${C_LGRAY}Domain:${C_RST}   ${C_TEXT}${server_domain}${C_RST}")
            right_lines+=(
                "  ${C_LGRAY}Provider:${C_RST} ${C_TEXT}${server_provider}${C_RST}"
                "  ${C_LGRAY}Users:${C_RST}    ${C_TEXT}${user_count}${C_RST}"
                "  ${C_LGRAY}Uptime:${C_RST}   ${C_TEXT}${uptime_str}${C_RST}"
            )
            if [[ -n "$load_avg" && "$load_avg" != "N/A" ]]; then
                right_lines+=("  ${C_LGRAY}Load:${C_RST}     ${C_TEXT}${load_avg}${C_RST}")
            fi
            if [[ -n "$mem_used" ]]; then
                right_lines+=("  ${C_LGRAY}Memory:${C_RST}   ${C_TEXT}${mem_used} / ${mem_total}${C_RST}")
            fi

            # Draw rows — fill to terminal height
            local left_count=${#service_lines[@]}
            local right_count=${#right_lines[@]}
            local max_rows=$left_count
            (( right_count > max_rows )) && max_rows=$right_count
            local chrome_rows=$(( _BANNER_HEIGHT + 1 + 12 ))  # banner + newline + split chrome + port section
            local avail_rows=$(( _TERM_ROWS - chrome_rows ))
            (( avail_rows < 1 )) && avail_rows=1
            (( avail_rows > max_rows )) && max_rows=$avail_rows

            for (( r = 0; r < max_rows; r++ )); do
                local left_text=""
                if (( r < left_count )); then
                    IFS='|' read -r sname sbadge sdetail <<< "${service_lines[$r]}"
                    left_text="  ${C_TEXT}${sname}${C_RST}  ${sbadge}"
                fi

                local right_text=""
                if (( r < right_count )); then
                    right_text=" ${right_lines[$r]}"
                fi

                draw_split_row "$left_text" "$right_text"
            done

            draw_split_empty

            # Port status section
            draw_split_sep
            draw_split_empty

            local port_lines=()
            _check_port 443 "HTTPS (Reality/VRay)" && port_lines+=("${_PORT_LINE}") || port_lines+=("${_PORT_LINE}")
            _check_port 80 "HTTP (WebSocket)" && port_lines+=("${_PORT_LINE}") || port_lines+=("${_PORT_LINE}")
            _check_port 51820 "WireGuard (UDP)" && port_lines+=("${_PORT_LINE}") || port_lines+=("${_PORT_LINE}")
            _check_port 53 "DNS (DNSTT)" && port_lines+=("${_PORT_LINE}") || port_lines+=("${_PORT_LINE}")

            local port_header_left="  ${C_ORANGE}Port Status${C_RST}"
            local port_header_right=" ${C_ORANGE}Quick Actions${C_RST}"
            draw_split_row "$port_header_left" "$port_header_right"

            local quick_actions=(
                " ${C_LGREEN}r${C_RST}${C_DIM} refresh${C_RST}"
                " ${C_LGREEN}Esc${C_RST}${C_DIM} back${C_RST}"
                " ${C_LGREEN}q${C_RST}${C_DIM} quit${C_RST}"
            )

            local port_count=${#port_lines[@]}
            local qa_count=${#quick_actions[@]}
            local max_bottom=$port_count
            (( qa_count > max_bottom )) && max_bottom=$qa_count

            for (( r = 0; r < max_bottom; r++ )); do
                local pl=""
                (( r < port_count )) && pl="  ${port_lines[$r]}"
                local qa=""
                (( r < qa_count )) && qa="${quick_actions[$r]}"
                draw_split_row "$pl" "$qa"
            done

            draw_split_empty
            draw_split_bottom
        fi

        # Key handling
        local key
        key=$(tui_read_key)

        case "$key" in
            r|R)  continue ;;  # refresh
            ESC)  return 0 ;;
            q|Q)  return 1 ;;
            *)    continue ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Port check helper
#-------------------------------------------------------------------------------

_PORT_LINE=""

_check_port() {
    local port="$1"
    local label="$2"
    local listening=0

    if type ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep -q ":${port} " && listening=1
    elif type netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep -q ":${port} " && listening=1
    fi

    if [[ $listening -eq 1 ]]; then
        _PORT_LINE="${C_GREEN}*${C_RST} ${C_TEXT}:${port}${C_RST} ${C_LGRAY}${label}${C_RST} ${C_GREEN}[open]${C_RST}"
        return 0
    else
        _PORT_LINE="${C_DGRAY}*${C_RST} ${C_TEXT}:${port}${C_RST} ${C_LGRAY}${label}${C_RST} ${C_DGRAY}[closed]${C_RST}"
        return 1
    fi
}
