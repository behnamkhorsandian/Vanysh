#!/bin/bash
# Home and protocol browser. Protocol actions use the current Docker manager.

TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TUI_DIR/engine.sh"

declare -A VANY_INSTALLED=() VANY_RUNNING=()
VANY_RUNNING_COUNT=0

_refresh_menu_status() {
    VANY_INSTALLED=()
    VANY_RUNNING=()
    VANY_RUNNING_COUNT=0
    local state="${VANY_DIR:-/opt/vany}/state.json" key status container features proto
    local running="" docker_ok=0
    if command -v docker >/dev/null 2>&1; then
        if running=$(docker ps --format '{{.Names}}' 2>/dev/null); then
            docker_ok=1
        fi
    fi
    [[ -f "$state" ]] && command -v jq >/dev/null 2>&1 || return 0
    while IFS=$'\t' read -r key status container features; do
        [[ "$status" != "-" ]] || continue
        for proto in "${PROTOCOL_IDS[@]}"; do
            case "$proto" in
                reality|ws|vray|http-obfs|mtp)
                    [[ "$key" == xray && ",$features," == *",$proto,"* ]] || continue ;;
                wg) [[ "$key" == wireguard ]] || continue ;;
                ssh-tunnel) [[ "$key" == ssh-tunnel ]] || continue ;;
                *) [[ "$key" == "$proto" ]] || continue ;;
            esac
            VANY_INSTALLED[$proto]=1
            if (( docker_ok )) && [[ -n "$container" && "$container" != "-" ]] && [[ $'\n'"$running"$'\n' == *$'\n'"$container"$'\n'* ]]; then
                VANY_RUNNING[$proto]=1
                (( VANY_RUNNING_COUNT++ ))
            fi
        done
    done < <(jq -r '.protocols // {} | to_entries[] | .value as $v | [.key, ($v.status // "-"), ($v.container // "-"), (["reality", "ws", "vray", "http-obfs", "mtp"] | map(select($v[.] != null and $v[.] != false)) | join(","))] | @tsv' "$state" 2>/dev/null)
}

service_installed() { [[ ${VANY_INSTALLED[$1]:-0} == 1 ]]; }
service_running() { [[ ${VANY_RUNNING[$1]:-0} == 1 ]]; }

_build_home_content() {
    FRAME_CONTENT=(
        "${C_ORANGE}${C_BOLD}Welcome to Vany${C_RST}"
        ""
        "Vany helps you set up connections on your own server."
        "You can share access with friends and family."
        ""
        "${C_LGREEN}New here?${C_RST}"
        "  Press C for help choosing a protocol."
        "  Or press Enter to browse, then choose REALITY to start."
        "  Open the required server port before you install."
        ""
        "${C_LGREEN}Already set up?${C_RST}"
        "  Press Enter to browse protocols. Select one to manage it."
        "  Its menu can show available user and connection actions."
        "  Press S to review the saved service status."
        ""
        "${C_LGREEN}Move around${C_RST}"
        "  Use the arrow keys to select a protocol. Press Enter to open it."
        "  Press H for this page or Q to quit."
    )
}

_build_protocol_content() {
    local proto="$1" doc_file="${PROTOCOL_DESC_MD[$1]:-}"
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}${PROTOCOL_NAMES[$proto]}${C_RST}" "")
    if service_installed "$proto"; then
        if service_running "$proto"; then
            FRAME_CONTENT+=("Status: ${badge_running}")
        else
            FRAME_CONTENT+=("Status: ${badge_installed}  Check the manager for current status.")
        fi
        FRAME_CONTENT+=("Press Enter to open the management menu." "")
    else
        FRAME_CONTENT+=("Status: not found in Vany's saved state")
        FRAME_CONTENT+=("Press Enter to open the setup menu." "")
    fi
    _render_doc_file "$doc_file" || FRAME_CONTENT+=("Guide unavailable. Open the menu for setup options.")
}

_render_doc_file() {
    local dfile="$1" line
    [[ -n "$dfile" ]] || return 1
    [[ "$dfile" == *.txt ]] || dfile="$dfile.txt"
    local path="$TUI_DIR/content/docs/$dfile"
    [[ -f "$path" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            '## '*) FRAME_CONTENT+=("${C_LGREEN}${line#\#\# }${C_RST}") ;;
            '# '*) continue ;;
            *) FRAME_CONTENT+=("$line") ;;
        esac
    done < <(fold -s -w "$(( _CONTENT_INNER_W - 2 ))" "$path")
}

_build_status_content() {
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Saved service status${C_RST}" "" "Select a protocol to check or manage it." "")
    local proto found=0
    for proto in "${PROTOCOL_IDS[@]}"; do
        if service_installed "$proto"; then
            found=1
            if service_running "$proto"; then
                FRAME_CONTENT+=("  ${PROTOCOL_SHORT[$proto]}: running")
            else
                FRAME_CONTENT+=("  ${PROTOCOL_SHORT[$proto]}: installed, check its manager")
            fi
        fi
    done
    (( found )) || FRAME_CONTENT+=("  No protocols found in Vany's saved state.")
    FRAME_CONTENT+=("" "Press Enter to browse protocols. Press H for home.")
}

page_main_menu() {
    local view=home last_view="" last_proto="" proto key i=0
    _SIDEBAR_SEL=0
    _SIDEBAR_DIM=0
    _refresh_menu_status
    if [[ -n "${START_PROTOCOL:-}" ]]; then
        for proto in "${PROTOCOL_IDS[@]}"; do
            [[ "$proto" == "$START_PROTOCOL" ]] && { _SIDEBAR_SEL=$i; view=protocols; break; }
            (( i++ ))
        done
        START_PROTOCOL=""
    fi
    while true; do
        tui_get_size
        proto="${PROTOCOL_IDS[$_SIDEBAR_SEL]}"
        _SIDEBAR_PAGE="$view"
        FRAME_BANNER="logo"
        FRAME_BANNER_COLOR="$C_GREEN"
        tui_compute_layout
        if [[ "$view" != "$last_view" || "$proto" != "$last_proto" ]]; then
            tui_scroll_reset
            case "$view" in
                home) _build_home_content ;;
                status) _build_status_content ;;
                protocols) _build_protocol_content "$proto" ;;
            esac
            last_view="$view"; last_proto="$proto"
        fi
        if [[ "$view" == protocols ]]; then
            FRAME_FOOTER="Arrows: choose  Enter: open  PgDn: more"
        else
            FRAME_FOOTER="Enter: browse  C: choose  PgDn: more"
        fi
        tui_render_frame
        key=$(tui_read_key)
        case "$key" in
            UP) view=protocols; (( _SIDEBAR_SEL-- )); (( _SIDEBAR_SEL < 0 )) && _SIDEBAR_SEL=$(( ${#PROTOCOL_IDS[@]} - 1 )) ;;
            DOWN) view=protocols; (( _SIDEBAR_SEL++ )); (( _SIDEBAR_SEL >= ${#PROTOCOL_IDS[@]} )) && _SIDEBAR_SEL=0 ;;
            ENTER|p|P)
                if [[ "$view" == protocols && "$key" == ENTER ]]; then
                    PROTOCOL_TO_MANAGE="$proto"; SELECTED_PROTOCOL="_manage"; return 0
                fi
                view=protocols ;;
            h|H|ESC|BACKSPACE) view=home ;;
            s|S) _refresh_menu_status; view=status; last_view="" ;;
            PGUP) tui_scroll_page_up ;;
            PGDN) tui_scroll_page_down ;;
            c|C) SELECTED_PROTOCOL="_choose"; return 0 ;;
            q|Q) return 1 ;;
        esac
    done
}
