#!/bin/bash
# Service actions use the same frame and navigation as the protocol pages.

_manage_confirm() {
    local title="$1" warning="$2" key
    tui_scroll_reset
    while true; do
        tui_get_size; tui_compute_layout
        FRAME_CONTENT=("${C_ORANGE}${C_BOLD}${title}${C_RST}" "" "$warning" "" "Y  Continue" "Q  Cancel")
        FRAME_FOOTER="Y: continue  Q: cancel"
        tui_render_frame
        tui_wait_key
        key="$TUI_KEY"
        case "$key" in
            y|Y) return 0 ;;
            n|N|q|Q|ESC|BACKSPACE) return 1 ;;
            PGUP) tui_scroll_page_up ;;
            PGDN) tui_scroll_page_down ;;
        esac
    done
}

_manage_input() {
    local prompt="$1" explanation="$2" result_name="$3"
    tui_scroll_reset
    tui_get_size; tui_compute_layout
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}${prompt}${C_RST}" "" "$explanation" "" "Enter the value below. Press Esc to cancel.")
    FRAME_FOOTER="Enter: continue  Esc: cancel"
    tui_render_frame
    tui_read_line_boxed "$prompt" "" "$result_name"
}

_manage_run() {
    local proto="$1" action="$2" title="$3" result_view="$4" domain_value="${5:-}" user_value="${6:-}"
    local manager="${TUI_DIR:-}/../scripts/direct-install.sh"
    [[ -f "$manager" ]] || manager=""
    VANY_PROTOCOL="$proto" VANY_ACTION="$action" VANY_DOMAIN="$domain_value" \
        VANY_USERNAME="$user_value" VANY_CONFIRM=y GITHUB_RAW="$GITHUB_RAW" \
        tui_run_action "$title" "Vany is working on this server." "$result_view" \
            bash "$TUI_DIR/command-tasks.sh" manager "$manager"
}

page_manage() {
    local proto="$1" key action domain_input user_input msg="" installed=0 exists refresh=1
    _SIDEBAR_PAGE=protocols
    _SIDEBAR_DIM=0
    FRAME_BANNER=""
    tui_scroll_reset
    while true; do
        if (( refresh )); then _refresh_menu_status; refresh=0; fi
        installed=0
        service_installed "$proto" && installed=1
        tui_get_size; tui_compute_layout
        FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Manage ${PROTOCOL_NAMES[$proto]}${C_RST}" "")
        if (( installed )); then
            if service_running "$proto"; then FRAME_CONTENT+=("Status: running"); else FRAME_CONTENT+=("Status: installed. Check the service if it does not connect."); fi
            FRAME_CONTENT+=("" "1  Reinstall this service" "2  Add a user" "3  Remove a user"
                "4  Show connection details" "5  Show service logs" "6  Restart the service"
                "7  Remove the service" "" "Q  Return to the protocol")
        else
            FRAME_CONTENT+=("Status: not found on this server" "" "1  Set up this service" "" "Q  Return to the protocol")
        fi
        [[ -n "$msg" ]] && FRAME_CONTENT+=("" "$msg")
        FRAME_FOOTER="Number: select  PgUp/PgDn: scroll  Q: return"
        tui_render_frame
        tui_wait_key
        key="$TUI_KEY"; msg=""
        case "$key" in
            q|Q|ESC|BACKSPACE) tui_scroll_reset; return 0 ;;
            PGUP) tui_scroll_page_up; continue ;;
            PGDN) tui_scroll_page_down; continue ;;
            1)
                case "$proto" in
                    vray|mtp) msg="Setup is not available for this protocol yet."; continue ;;
                esac
                if (( installed )); then
                    _manage_confirm "Reinstall ${PROTOCOL_NAMES[$proto]}" "Reinstalling can change connection details and interrupt users." || continue
                fi
                page_setup_checks "$proto" || { tui_scroll_reset; continue; }
                domain_input=""
                case "$proto" in
                    ws|http-obfs|dnstt|slipstream|noizdns)
                        _manage_input "Domain name" "Enter the full domain name for this service, such as vpn.example.com." domain_input || continue
                        if [[ ${#domain_input} -gt 253 || ! "$domain_input" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ || "$domain_input" != *.* || "$domain_input" == *..* ]]; then
                            msg="Enter a valid domain name, such as vpn.example.com."; continue
                        fi ;;
                esac
                _manage_run "$proto" install "Set up ${PROTOCOL_NAMES[$proto]}" 0 "$domain_input"
                refresh=1
                tui_scroll_reset ;;
            2|3)
                (( installed )) || continue
                case "$proto" in reality|ws|wg) ;; *) msg="User management is not available for this protocol."; continue ;; esac
                action=add_user
                [[ "$key" == 3 ]] && action=remove_user
                user_input=""
                _manage_input "User name" "Use letters, numbers, underscores, or hyphens. Use up to 32 characters." user_input || continue
                if [[ ! "$user_input" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$ ]]; then msg="Enter a valid user name."; continue; fi
                exists=0
                if [[ -f "${VANY_USERS:-/opt/vany/users.json}" ]] && jq -e --arg user "$user_input" --arg proto "$proto" '.users[$user].protocols[$proto] != null' "${VANY_USERS:-/opt/vany/users.json}" >/dev/null 2>&1; then exists=1; fi
                if [[ "$action" == add_user ]] && (( exists )); then msg="This user already has access to this service."; continue; fi
                if [[ "$action" == remove_user ]] && (( !exists )); then msg="This user does not have access to this service."; continue; fi
                if [[ "$action" == remove_user ]]; then
                    _manage_confirm "Remove $user_input" "This user will lose access to this service." || continue
                    _manage_run "$proto" "$action" "Remove user" 0 "" "$user_input"
                else
                    _manage_run "$proto" "$action" "Add user" 1 "" "$user_input"
                fi
                refresh=1
                tui_scroll_reset ;;
            4)
                (( installed )) || continue
                case "$proto" in reality|ws|wg|hysteria) _manage_run "$proto" config "Connection details" 1 ;; *) msg="Connection details are not available here for this protocol." ;; esac
                tui_scroll_reset ;;
            5)
                (( installed )) || continue
                if [[ "$proto" == ssh-tunnel ]]; then msg="Container logs are not available for the SSH service."; else _manage_run "$proto" logs "Service logs" 1; fi
                tui_scroll_reset ;;
            6)
                (( installed )) || continue
                if [[ "$proto" == ssh-tunnel ]]; then msg="Restart is not available here for the SSH service."; else _manage_run "$proto" restart "Restart ${PROTOCOL_NAMES[$proto]}" 0; fi
                refresh=1
                tui_scroll_reset ;;
            7)
                (( installed )) || continue
                if [[ "$proto" == ssh-tunnel ]]; then msg="Removal is not available here for the SSH service."; continue; fi
                _manage_confirm "Remove ${PROTOCOL_NAMES[$proto]}" "This removes the service and can disconnect its users." || continue
                _manage_run "$proto" uninstall "Remove ${PROTOCOL_NAMES[$proto]}" 0
                refresh=1
                tui_scroll_reset ;;
        esac
    done
}
