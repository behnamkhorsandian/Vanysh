#!/bin/bash
# Home and protocol browser. Protocol actions use the current Docker manager.

TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TUI_DIR/engine.sh"

declare -A VANY_INSTALLED=() VANY_RUNNING=() VANY_CONTAINER=()
VANY_RUNNING_COUNT=0

_refresh_menu_status() {
    VANY_INSTALLED=()
    VANY_RUNNING=()
    VANY_CONTAINER=()
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
            VANY_CONTAINER[$proto]="$container"
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
        "Create a service on a server or connect from this device."
        "Share access with friends and family."
        ""
        "${C_LGREEN}New here?${C_RST}"
        "  Press C for the protocol chooser at any time."
        "  Or press Enter to browse. Choose create or connect."
        "  The setup wizard checks local requirements."
        ""
        "${C_LGREEN}Already set up?${C_RST}"
        "  Press Enter to browse protocols. Select one to manage it."
        "  Choose a protocol to create, manage, or connect."
        "  Press S for status and network checks."
        ""
        "${C_LGREEN}Move around${C_RST}"
        "  Use the arrow keys to select a protocol. Press Enter to open it."
        "  Press H for this page or Q to quit."
    )
}

_build_protocol_content() {
    local proto="$1" doc_file="${PROTOCOL_DESC_MD[$1]:-}"
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}${PROTOCOL_NAMES[$proto]}${C_RST}" ""
        "1  Create or manage this service on this server"
        "2  Connect from this device"
        "C  Help me choose a protocol" "")
    if service_installed "$proto"; then
        if service_running "$proto"; then
            FRAME_CONTENT+=("Status: ${badge_running}")
        else
            FRAME_CONTENT+=("Status: ${badge_installed}  Check the manager for current status.")
        fi
        FRAME_CONTENT+=("" )
    else
        FRAME_CONTENT+=("Status: not found in Vany's saved state")
        FRAME_CONTENT+=("" )
    fi
    _render_doc_file "$doc_file" || FRAME_CONTENT+=("Guide unavailable. Open the menu for setup options.")
    FRAME_CONTENT+=("" "C  Help me choose a protocol")
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
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Status and checks${C_RST}" ""
        "Public IP and approximate location come from ipinfo.io."
        "Network rate is the total for local interfaces, not per user."
        "A running container does not prove a usable connection." ""
        "N  Check public endpoints, latency, and packet loss"
        "T  Run a connection speed test"
        "P  Show the route to a public endpoint"
        "M  Show container resource usage"
        "R  Refresh saved service status" "")
    local users_file="${VANY_USERS:-/opt/vany/users.json}" user_count
    if [[ -f "$users_file" ]] && command -v jq >/dev/null 2>&1; then
        user_count=$(jq -r '.users // {} | length' "$users_file" 2>/dev/null)
        [[ "$user_count" =~ ^[0-9]+$ ]] && FRAME_CONTENT+=("Saved users: $user_count" "")
    fi
    local proto found=0
    for proto in "${PROTOCOL_IDS[@]}"; do
        if service_installed "$proto"; then
            found=1
            if service_running "$proto"; then
                local health="not configured"
                if command -v timeout >/dev/null 2>&1; then
                    health=$(timeout 3 docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}not configured{{end}}' "${VANY_CONTAINER[$proto]}" 2>/dev/null) || health="unavailable"
                fi
                FRAME_CONTENT+=("  ${PROTOCOL_SHORT[$proto]}: running, health: $health")
            else
                FRAME_CONTENT+=("  ${PROTOCOL_SHORT[$proto]}: installed, check its manager")
            fi
        fi
    done
    (( found )) || FRAME_CONTENT+=("  No protocols found in Vany's saved state.")
    if service_running wg && [[ -f "$users_file" ]] && command -v jq >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
        local transfers peer received sent username
        FRAME_CONTENT+=("" "WireGuard peer usage since the interface started:")
        if transfers=$(timeout 5 docker exec "${VANY_CONTAINER[wg]}" wg show wg0 transfer 2>/dev/null); then
            if [[ -z "$transfers" ]]; then
                FRAME_CONTENT+=("  No WireGuard peers found.")
            else
                while IFS=$'\t' read -r peer received sent; do
                    [[ "$received" =~ ^[0-9]+$ && "$sent" =~ ^[0-9]+$ ]] || continue
                    username=$(jq -r --arg key "$peer" '[.users // {} | to_entries[] | select(.value.protocols.wg.public_key == $key) | .key] | first // "unmatched peer"' "$users_file" 2>/dev/null)
                    username=$(printf '%s' "$username" | tr -cd '[:alnum:]_.@ -' | cut -c1-32)
                    FRAME_CONTENT+=("  ${username:-unmatched peer}: server received $((received / 1048576)) MiB, sent $((sent / 1048576)) MiB")
                done <<< "$transfers"
            fi
        else
            FRAME_CONTENT+=("  WireGuard usage could not be read.")
        fi
        FRAME_CONTENT+=("  Counters reset when the interface restarts.")
    fi
    FRAME_CONTENT+=("" "Per-user traffic is not available for other protocols.")
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
        FRAME_BANNER=""
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
            FRAME_FOOTER="1: create  2: connect  C: choose"
        elif [[ "$view" == status ]]; then
            FRAME_FOOTER="N: checks  T: speed  P: route  H: home"
        else
            FRAME_FOOTER="Enter: browse  C: choose  PgDn: more"
        fi
        tui_render_frame
        tui_wait_key
        key="$TUI_KEY"
        case "$key" in
            UP) view=protocols; (( _SIDEBAR_SEL-- )); (( _SIDEBAR_SEL < 0 )) && _SIDEBAR_SEL=$(( ${#PROTOCOL_IDS[@]} - 1 )) ;;
            DOWN) view=protocols; (( _SIDEBAR_SEL++ )); (( _SIDEBAR_SEL >= ${#PROTOCOL_IDS[@]} )) && _SIDEBAR_SEL=0 ;;
            ENTER)
                if [[ "$view" == protocols && "$key" == ENTER ]]; then
                    if page_setup_checks "$proto"; then
                        PROTOCOL_TO_MANAGE="$proto"; SELECTED_PROTOCOL="_manage"; return 0
                    fi
                    last_view=""; continue
                fi
                view=protocols ;;
            1)
                if [[ "$view" == protocols ]]; then
                    if page_setup_checks "$proto"; then
                        PROTOCOL_TO_MANAGE="$proto"; SELECTED_PROTOCOL="_manage"; return 0
                    fi
                    last_view=""
                fi ;;
            2)
                if [[ "$view" == protocols ]]; then
                    page_connect "$proto"
                    if [[ $? -eq 2 ]]; then
                        CHOOSER_RETURN_PROTOCOL="$proto"
                        SELECTED_PROTOCOL="_choose"; return 0
                    fi
                    last_view=""
                fi ;;
            h|H|ESC|BACKSPACE) view=home ;;
            s|S) _refresh_menu_status; view=status; last_view="" ;;
            r|R) if [[ "$view" == status ]]; then _refresh_menu_status; last_view=""; fi ;;
            n|N) if [[ "$view" == status ]]; then tui_cleanup; journey_network_checks; tui_init; last_view=""; fi ;;
            t|T) if [[ "$view" == status ]]; then journey_run_tool speedtest; last_view=""; fi ;;
            p|P) if [[ "$view" == status ]]; then journey_trace_route; last_view=""; else view=protocols; fi ;;
            m|M) if [[ "$view" == status ]]; then journey_container_stats; last_view=""; fi ;;
            PGUP) tui_scroll_page_up ;;
            PGDN) tui_scroll_page_down ;;
            c|C)
                CHOOSER_RETURN_PROTOCOL=""
                [[ "$view" == protocols ]] && CHOOSER_RETURN_PROTOCOL="$proto"
                SELECTED_PROTOCOL="_choose"; return 0 ;;
            q|Q) return 1 ;;
        esac
    done
}
