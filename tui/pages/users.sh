#!/bin/bash
#===============================================================================
# DNSCloak TUI - User Management Page
# List users, add/remove users, show connection links
#===============================================================================

TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TUI_DIR/engine.sh"

#-------------------------------------------------------------------------------
# User list page — shows all users with their enabled protocols
# Returns: action in USER_ACTION (add, remove, links, back)
#-------------------------------------------------------------------------------

page_users() {
    local selected=0

    while true; do
        tui_get_size
        tui_compute_layout

        clear_screen
        render_banner "logo" "$C_GREEN"
        printf '\n'

        # Get user list
        local users=()
        local user_protos=()
        if [[ -f "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" ]] && type jq &>/dev/null; then
            local users_json
            users_json=$(jq -r '.users // {} | keys[]' "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" 2>/dev/null)
            while IFS= read -r uname; do
                [[ -z "$uname" ]] && continue
                users+=("$uname")
                # Get protocols for this user
                local protos
                protos=$(jq -r ".users[\"$uname\"].protocols // {} | keys | join(\", \")" \
                    "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" 2>/dev/null)
                user_protos+=("$protos")
            done <<< "$users_json"
        fi

        local user_count=${#users[@]}

        # Main content
        draw_box_top "" "User Management"
        draw_box_empty

        local user_section_rows=0
        if [[ $user_count -eq 0 ]]; then
            draw_box_row " ${C_LGRAY}No users configured yet.${C_RST}"
            draw_box_row " ${C_LGRAY}Install a protocol first, then add users.${C_RST}"
            user_section_rows=2
        else
            # Table header
            local hdr
            hdr=$(printf ' %-20s %s' "${C_ORANGE}Username${C_RST}" "${C_ORANGE}Protocols${C_RST}")
            draw_box_row "$hdr"
            draw_box_sep
            user_section_rows=$(( 2 + user_count ))

            local i=0
            for uname in "${users[@]}"; do
                local prefix="  "
                local ucolor="$C_TEXT"
                if [[ $i -eq $selected && $selected -lt $user_count ]]; then
                    prefix="${C_GREEN}>${C_RST} "
                    ucolor="${C_GREEN}${C_BOLD}"
                fi
                local row
                row=$(printf '%s%-20s %b%s%b' "$prefix" "${ucolor}${uname}${C_RST}" "$C_LGRAY" "${user_protos[$i]}" "$C_RST")
                draw_box_row "$row"
                (( i++ ))
            done
        fi

        draw_box_empty
        draw_box_sep
        draw_box_empty

        # Action menu (below the user list)
        local actions=("Add User" "Remove User" "Show User Links" "Back to Main Menu")
        local action_ids=("add" "remove" "links" "back")
        local action_offset=$user_count
        local action_count=${#actions[@]}
        local total_items=$(( user_count + action_count ))

        local a=0
        for action in "${actions[@]}"; do
            local idx=$(( action_offset + a ))
            local prefix="   "
            local acolor="$C_TEXT"
            if [[ $selected -eq $idx ]]; then
                prefix=" ${C_GREEN}>${C_RST}"
                acolor="${C_GREEN}${C_BOLD}"
            fi
            draw_box_row "${prefix} ${acolor}${action}${C_RST}"
            (( a++ ))
        done

        # Vertical fill
        # Chrome: newline(1) + top(1) + empty(1) + user_section + empty(1) + sep(1) + empty(1) +
        #   actions + sep(1) + hints(1) + bottom(1) = 8 + user_section + actions
        local chrome_rows=$(( _BANNER_HEIGHT + 1 + 8 + user_section_rows + action_count ))
        local avail=$(( _TERM_ROWS - chrome_rows ))
        while (( avail-- > 0 )); do draw_box_empty; done

        draw_box_sep
        draw_box_row " ${C_DGRAY}Up/Down${C_RST}${C_DIM} navigate${C_RST}  ${C_DGRAY}Enter${C_RST}${C_DIM} select${C_RST}  ${C_DGRAY}Esc${C_RST}${C_DIM} back${C_RST}"
        draw_box_bottom

        # Key handling
        local key
        key=$(tui_read_key)

        case "$key" in
            UP)
                (( selected-- ))
                (( selected < 0 )) && selected=$(( total_items - 1 ))
                ;;
            DOWN)
                (( selected++ ))
                (( selected >= total_items )) && selected=0
                ;;
            ENTER)
                if (( selected < user_count )); then
                    # Selected a user — show their links
                    _show_user_links_page "${users[$selected]}"
                else
                    local action_idx=$(( selected - action_offset ))
                    USER_ACTION="${action_ids[$action_idx]}"
                    case "$USER_ACTION" in
                        add)    _add_user_page ;;
                        remove) _remove_user_page ;;
                        links)
                            if [[ $user_count -gt 0 ]]; then
                                _show_user_links_page "${users[0]}"
                            fi
                            ;;
                        back) return 0 ;;
                    esac
                fi
                ;;
            ESC)
                return 0
                ;;
            q|Q)
                USER_ACTION="quit"
                return 0
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Add user sub-page
#-------------------------------------------------------------------------------

_add_user_page() {
    tui_get_size
    tui_compute_layout

    clear_screen
    printf '\n'
    draw_box_top "" "Add User"
    draw_box_empty
    draw_box_row " ${C_TEXT}Enter a username for the new user.${C_RST}"
    draw_box_row " ${C_LGRAY}They will be added to all installed protocols.${C_RST}"
    draw_box_empty
    draw_box_sep
    draw_box_row " ${C_DGRAY}Enter username  |  Esc back${C_RST}"
    draw_box_empty

    local username=""
    tui_read_line_boxed "Username" "" username
    local input_rc=$?
    draw_box_bottom
    [[ $input_rc -ne 0 || -z "$username" ]] && return

    printf '\n'

    # Add user to each installed protocol
    local added=0
    for proto in "${PROTOCOL_IDS[@]}"; do
        if type service_installed &>/dev/null && service_installed "$proto"; then
            local add_fn="add_${proto}_user"
            [[ "$proto" == "wg" ]] && add_fn="add_wg_user"
            if type "$add_fn" &>/dev/null; then
                printf '  %b[+]%b Adding to %s... ' "$C_GREEN" "$C_RST" "${PROTOCOL_NAMES[$proto]}"
                "$add_fn" "$username" 2>/dev/null && {
                    printf '%b done%b\n' "$C_GREEN" "$C_RST"
                    (( added++ ))
                } || printf '%b failed%b\n' "$C_RED" "$C_RST"
            fi
        fi
    done

    if [[ $added -eq 0 ]]; then
        printf '  %b[!]%b No installed protocols found. Install a protocol first.\n' "$C_YELLOW" "$C_RST"
    else
        printf '\n  %b[+]%b User "%s" added to %d protocol(s)\n' "$C_GREEN" "$C_RST" "$username" "$added"
    fi

    press_any_key
}

#-------------------------------------------------------------------------------
# Remove user sub-page
#-------------------------------------------------------------------------------

_remove_user_page() {
    tui_get_size
    tui_compute_layout

    clear_screen
    printf '\n'
    draw_box_top "" "Remove User"
    draw_box_empty
    draw_box_row " ${C_TEXT}Enter the username to remove.${C_RST}"
    draw_box_row " ${C_RED}This will remove them from ALL protocols.${C_RST}"
    draw_box_empty
    draw_box_sep
    draw_box_row " ${C_DGRAY}Enter username  |  Esc back${C_RST}"
    draw_box_empty

    local username=""
    tui_read_line_boxed "Username" "" username
    local input_rc=$?
    draw_box_bottom
    [[ $input_rc -ne 0 || -z "$username" ]] && return

    printf '\n'
    printf '\033[?25h'
    if tui_confirm "Remove user '$username' from all protocols?"; then
        printf '\033[?25l'
        for proto in "${PROTOCOL_IDS[@]}"; do
            local remove_fn="remove_${proto}_user"
            [[ "$proto" == "wg" ]] && remove_fn="remove_wg_user"
            if type "$remove_fn" &>/dev/null; then
                "$remove_fn" "$username" 2>/dev/null && \
                    printf '  %b[+]%b Removed from %s\n' "$C_GREEN" "$C_RST" "${PROTOCOL_NAMES[$proto]}"
            fi
        done
        printf '\n  %b[+]%b User "%s" removed\n' "$C_GREEN" "$C_RST" "$username"
    else
        printf '\033[?25l'
    fi

    press_any_key
}

#-------------------------------------------------------------------------------
# Show user links sub-page
#-------------------------------------------------------------------------------

_show_user_links_page() {
    local username="$1"

    tui_get_size
    tui_compute_layout

    clear_screen
    printf '\n'
    draw_box_top "" "Links for: $username"
    draw_box_empty

    if [[ -f "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" ]] && type jq &>/dev/null; then
        local protos
        protos=$(jq -r ".users[\"$username\"].protocols // {} | keys[]" \
            "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" 2>/dev/null)

        if [[ -z "$protos" ]]; then
            draw_box_row " ${C_LGRAY}No protocols configured for this user.${C_RST}"
        else
            while IFS= read -r proto; do
                draw_box_row " ${C_ORANGE}${PROTOCOL_NAMES[$proto]:-$proto}${C_RST}"
                draw_box_sep

                # Call protocol-specific link display
                local show_fn="show_${proto}_links"
                [[ "$proto" == "reality" ]] && show_fn="show_user_links"
                if type "$show_fn" &>/dev/null; then
                    "$show_fn" "$username" 2>/dev/null | while IFS= read -r line; do
                        draw_box_row " $line"
                    done
                else
                    # Fallback: dump the protocol config
                    local config
                    config=$(jq ".users[\"$username\"].protocols[\"$proto\"]" \
                        "${DNSCLOAK_USERS:-/opt/dnscloak/users.json}" 2>/dev/null)
                    while IFS= read -r line; do
                        draw_box_row " ${C_TEXT}$line${C_RST}"
                    done <<< "$config"
                fi
                draw_box_empty
            done <<< "$protos"
        fi
    else
        draw_box_row " ${C_LGRAY}User database not found or jq not installed.${C_RST}"
    fi

    draw_box_bottom
    printf '\n'
    press_any_key
}
