#!/bin/bash
#===============================================================================
# DNSCloak TUI - Main Page (Protocol Browser)
# Sidebar selects protocol, content shows markdown description
# Footer hotkeys for direct actions (no nested menus)
#===============================================================================

TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TUI_DIR/engine.sh"

#-------------------------------------------------------------------------------
# Build content lines for selected protocol using markdown
#-------------------------------------------------------------------------------

_build_protocol_content() {
    local proto="$1"
    local proto_name="${PROTOCOL_NAMES[$proto]}"

    FRAME_CONTENT=()
    tui_scroll_reset

    # Title
    FRAME_CONTENT+=("${C_ORANGE}${C_BOLD}${proto_name}${C_RST}")
    FRAME_CONTENT+=("")

    # Status badge
    local is_installed=0
    local is_running=0
    if type service_installed &>/dev/null && service_installed "$proto" 2>/dev/null; then
        is_installed=1
        if type service_running &>/dev/null && service_running "$proto" 2>/dev/null; then
            is_running=1
        fi
    fi

    if [[ $is_installed -eq 1 ]]; then
        if [[ $is_running -eq 1 ]]; then
            FRAME_CONTENT+=("Status: $badge_running")
        else
            FRAME_CONTENT+=("Status: $badge_stopped")
        fi
    else
        FRAME_CONTENT+=("Status: $badge_not_installed")
    fi
    FRAME_CONTENT+=("")

    # Render markdown description if available
    local md_path="${PROTOCOL_DESC_MD[$proto]:-}"
    if [[ -n "$md_path" ]]; then
        tui_render_markdown "$md_path"
    else
        # Fallback to short description
        local desc="${PROTOCOL_DESC[$proto]}"
        while IFS= read -r line; do
            line=$(printf '%b' "$line")
            FRAME_CONTENT+=("${C_TEXT}${line}${C_RST}")
        done <<< "$(printf '%b' "$desc")"
    fi
    FRAME_CONTENT+=("")

    # Requirements
    local reqs="${PROTOCOL_REQS[$proto]}"
    if [[ -n "$reqs" ]]; then
        FRAME_CONTENT+=("${C_LGREEN}Requirements:${C_RST}")
        while IFS= read -r line; do
            line=$(printf '%b' "$line")
            FRAME_CONTENT+=("${C_LGRAY}${line}${C_RST}")
        done <<< "$(printf '%b' "$reqs")"
        FRAME_CONTENT+=("")
    fi

    # Client apps
    local clients="${PROTOCOL_CLIENTS[$proto]}"
    if [[ -n "$clients" ]]; then
        FRAME_CONTENT+=("${C_LGREEN}Client Apps:${C_RST}")
        while IFS= read -r line; do
            line=$(printf '%b' "$line")
            FRAME_CONTENT+=("${C_LGRAY}${line}${C_RST}")
        done <<< "$(printf '%b' "$clients")"
    fi
}

#-------------------------------------------------------------------------------
# Main page — protocol browser with footer hotkeys
# Returns 0 on action selection, 1 on quit
# Sets: SELECTED_PROTOCOL, PROTOCOL_ACTION
#-------------------------------------------------------------------------------

page_main_menu() {
    _SIDEBAR_SEL=0
    _SIDEBAR_PAGE="protocols"
    _SIDEBAR_DIM=0

    local proto_count=${#PROTOCOL_IDS[@]}
    local last_proto=""

    # Pre-select protocol if START_PROTOCOL is set (from --page argument)
    if [[ -n "${START_PROTOCOL:-}" ]]; then
        local i=0
        for pid in "${PROTOCOL_IDS[@]}"; do
            if [[ "$pid" == "$START_PROTOCOL" ]]; then
                _SIDEBAR_SEL=$i
                break
            fi
            (( i++ ))
        done
        START_PROTOCOL=""
    fi

    while true; do
        tui_get_size

        local proto="${PROTOCOL_IDS[$_SIDEBAR_SEL]}"

        # Set banner using JSON-resolved banner file
        FRAME_BANNER="${PROTOCOL_BANNER_FILE[$proto]:-$proto}"
        local bcolor="${PROTOCOL_BANNER_COLOR[$proto]:-green}"
        FRAME_BANNER_COLOR="${_COLOR_MAP[$bcolor]:-$C_GREEN}"

        tui_compute_layout

        # Rebuild content only when protocol selection changes
        if [[ "$proto" != "$last_proto" ]]; then
            _build_protocol_content "$proto"
            last_proto="$proto"
        fi

        # Check install status for dynamic footer
        local is_installed=0
        if type service_installed &>/dev/null && service_installed "$proto" 2>/dev/null; then
            is_installed=1
        fi

        # Build footer with hotkeys
        FRAME_FOOTER="${C_DGRAY}^/v${C_RST}${C_DIM} navigate${C_RST}  "
        if [[ $is_installed -eq 0 ]]; then
            FRAME_FOOTER+="${C_DGRAY}i${C_RST}${C_DIM} install${C_RST}  "
        else
            FRAME_FOOTER+="${C_DGRAY}a${C_RST}${C_DIM} add user${C_RST}  "
            FRAME_FOOTER+="${C_DGRAY}r${C_RST}${C_DIM} remove${C_RST}  "
            FRAME_FOOTER+="${C_DGRAY}l${C_RST}${C_DIM} links${C_RST}  "
            FRAME_FOOTER+="${C_DGRAY}x${C_RST}${C_DIM} restart${C_RST}  "
            FRAME_FOOTER+="${C_DGRAY}d${C_RST}${C_DIM} uninstall${C_RST}  "
        fi
        FRAME_FOOTER+="${C_DGRAY}s${C_RST}${C_DIM} status${C_RST}  "
        FRAME_FOOTER+="${C_DGRAY}u${C_RST}${C_DIM} users${C_RST}  "
        FRAME_FOOTER+="${C_DGRAY}h${C_RST}${C_DIM} help${C_RST}  "
        FRAME_FOOTER+="${C_DGRAY}q${C_RST}${C_DIM} quit${C_RST}"

        tui_render_frame

        # Read key — all actions via hotkeys, no dual-focus
        local key
        key=$(tui_read_key)

        case "$key" in
            UP)
                (( _SIDEBAR_SEL-- ))
                (( _SIDEBAR_SEL < 0 )) && _SIDEBAR_SEL=$(( proto_count - 1 ))
                tui_scroll_reset
                ;;
            DOWN)
                (( _SIDEBAR_SEL++ ))
                (( _SIDEBAR_SEL >= proto_count )) && _SIDEBAR_SEL=0
                tui_scroll_reset
                ;;
            # Scroll content with left/right or page keys
            LEFT)
                tui_scroll_up
                ;;
            RIGHT)
                tui_scroll_down
                ;;
            # Direct action hotkeys
            i|I)
                if [[ $is_installed -eq 0 ]]; then
                    SELECTED_PROTOCOL="$proto"
                    PROTOCOL_ACTION="install"
                    return 0
                fi
                ;;
            a|A)
                if [[ $is_installed -eq 1 ]]; then
                    SELECTED_PROTOCOL="$proto"
                    PROTOCOL_ACTION="add_user"
                    return 0
                fi
                ;;
            r|R)
                if [[ $is_installed -eq 1 ]]; then
                    SELECTED_PROTOCOL="$proto"
                    PROTOCOL_ACTION="remove_user"
                    return 0
                fi
                ;;
            l|L)
                if [[ $is_installed -eq 1 ]]; then
                    SELECTED_PROTOCOL="$proto"
                    PROTOCOL_ACTION="show_links"
                    return 0
                fi
                ;;
            x|X)
                if [[ $is_installed -eq 1 ]]; then
                    SELECTED_PROTOCOL="$proto"
                    PROTOCOL_ACTION="restart"
                    return 0
                fi
                ;;
            d|D)
                if [[ $is_installed -eq 1 ]]; then
                    SELECTED_PROTOCOL="$proto"
                    PROTOCOL_ACTION="uninstall"
                    return 0
                fi
                ;;
            ENTER)
                # Enter = primary action: install if not installed, show links if installed
                SELECTED_PROTOCOL="$proto"
                if [[ $is_installed -eq 0 ]]; then
                    PROTOCOL_ACTION="install"
                else
                    PROTOCOL_ACTION="show_links"
                fi
                return 0
                ;;
            s|S)
                SELECTED_PROTOCOL="_status"
                return 0
                ;;
            u|U)
                SELECTED_PROTOCOL="_users"
                return 0
                ;;
            h|H)
                SELECTED_PROTOCOL="_help"
                return 0
                ;;
            q|Q)
                return 1
                ;;
            [0-7])
                if (( key < proto_count )); then
                    _SIDEBAR_SEL=$key
                    tui_scroll_reset
                fi
                ;;
        esac
    done
}
