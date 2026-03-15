#!/bin/bash
#===============================================================================
# DNSCloak TUI - Main Menu Page
# Split layout: protocol list (left) + description sidebar (right)
#===============================================================================

# Source engine
TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TUI_DIR/engine.sh"

#-------------------------------------------------------------------------------
# Get protocol status badge string
#-------------------------------------------------------------------------------

_get_proto_badge() {
    local proto="$1"

    # Check if service functions are available
    if type service_installed &>/dev/null && type service_running &>/dev/null; then
        if service_installed "$proto"; then
            if service_running "$proto"; then
                echo "running"
            else
                echo "stopped"
            fi
            return
        fi
    fi

    # Fallback: use static tags from theme
    echo "${PROTOCOL_TAGS[$proto]}"
}

#-------------------------------------------------------------------------------
# Render the main menu — returns selected protocol ID in SELECTED_PROTOCOL
# Returns: 0 on selection, 1 on quit
#-------------------------------------------------------------------------------

page_main_menu() {
    local selected=0

    while true; do
        tui_get_size
        tui_compute_layout

        clear_screen

        # Banner
        render_banner "menu" "$C_GREEN"
        printf '\n'

        # Build menu items with badges
        local items=()
        for proto in "${PROTOCOL_IDS[@]}"; do
            local name="${PROTOCOL_NAMES[$proto]}"
            local badge
            badge=$(_get_proto_badge "$proto")
            items+=("${name}|${proto}|${badge}")
        done

        if (( _COMPACT )); then
            # Compact mode: just a simple menu, no split
            draw_box_top "" "Select Protocol"
            draw_box_empty

            local i=0
            for item in "${items[@]}"; do
                local label="${item%%|*}"
                local rest="${item#*|}"
                local proto="${rest%%|*}"
                local badge="${rest##*|}"

                local prefix="   "
                local lcolor="$C_TEXT"
                if [[ $i -eq $selected ]]; then
                    prefix=" ${C_GREEN}>${C_RST}"
                    lcolor="${C_GREEN}${C_BOLD}"
                fi

                local display="${prefix} ${lcolor}${label}${C_RST}"

                case "$badge" in
                    running)       display+="  $badge_running" ;;
                    stopped)       display+="  $badge_stopped" ;;
                    recommended)   display+="  $badge_recommended" ;;
                    needs_domain)  display+="  $badge_needs_domain" ;;
                    emergency)     display+="  $badge_emergency" ;;
                    relay)         display+="  $badge_relay" ;;
                esac

                draw_box_row "$display"
                (( i++ ))
            done

            # Vertical fill: pad remaining rows
            local content_rows=$(( ${#items[@]} + 5 ))  # items + top/empty/sep/hints/bottom
            local avail=$(( _TERM_ROWS - content_rows - 18 ))  # ~18 for banner
            while (( avail-- > 0 )); do draw_box_empty; done

            draw_box_sep
            draw_box_row " ${C_DGRAY}Up/Down${C_RST}${C_DIM} navigate${C_RST}  ${C_DGRAY}Enter${C_RST}${C_DIM} select${C_RST}  ${C_DGRAY}q${C_RST}${C_DIM} quit${C_RST}"
            draw_box_bottom
        else
            # Full mode: split layout (left: list, right: description)
            compute_split "$_FRAME_W" 55

            # Get selected protocol info
            local sel_proto="${PROTOCOL_IDS[$selected]}"
            local sel_desc="${PROTOCOL_DESC[$sel_proto]}"
            local sel_reqs="${PROTOCOL_REQS[$sel_proto]}"
            local sel_clients="${PROTOCOL_CLIENTS[$sel_proto]}"

            # Draw split top
            draw_split_top "" "Protocols" "Details"
            draw_split_empty

            # Draw each protocol item on the left, description on the right
            local i=0
            local right_lines=()

            # Prepare right panel content
            IFS=$'\n' read -r -d '' -a desc_lines <<< "$(printf '%b' "$sel_desc")" || true
            IFS=$'\n' read -r -d '' -a req_lines <<< "$(printf '%b' "$sel_reqs")" || true
            IFS=$'\n' read -r -d '' -a client_lines <<< "$(printf '%b' "$sel_clients")" || true

            # Build right panel line array
            right_lines+=("${C_ORANGE}${PROTOCOL_NAMES[$sel_proto]}${C_RST}")
            right_lines+=("")
            for dl in "${desc_lines[@]}"; do
                right_lines+=("${C_TEXT}${dl}${C_RST}")
            done
            right_lines+=("")
            right_lines+=("${C_LGREEN}Requirements:${C_RST}")
            for rl in "${req_lines[@]}"; do
                right_lines+=("${C_LGRAY}${rl}${C_RST}")
            done
            right_lines+=("")
            right_lines+=("${C_LGREEN}Client Apps:${C_RST}")
            for cl in "${client_lines[@]}"; do
                right_lines+=("${C_LGRAY}${cl}${C_RST}")
            done

            # Draw rows — fill to terminal height
            local max_rows=${#items[@]}
            local right_count=${#right_lines[@]}
            (( right_count > max_rows )) && max_rows=$right_count
            # Compute available content rows (terminal - banner - chrome)
            local avail_rows=$(( _TERM_ROWS - 22 ))  # ~18 banner + 4 chrome
            (( avail_rows > max_rows )) && max_rows=$avail_rows

            for (( r = 0; r < max_rows; r++ )); do
                # Left column
                local left_text=""
                if (( r < ${#items[@]} )); then
                    local item="${items[$r]}"
                    local label="${item%%|*}"
                    local rest="${item#*|}"
                    local proto="${rest%%|*}"
                    local badge="${rest##*|}"

                    local prefix="   "
                    local lcolor="$C_TEXT"
                    if [[ $r -eq $selected ]]; then
                        prefix=" ${C_GREEN}>${C_RST}"
                        lcolor="${C_GREEN}${C_BOLD}"
                    fi

                    left_text="${prefix} ${lcolor}${label}${C_RST}"

                    case "$badge" in
                        running)       left_text+="  $badge_running" ;;
                        stopped)       left_text+="  $badge_stopped" ;;
                        recommended)   left_text+="  $badge_recommended" ;;
                        needs_domain)  left_text+="  $badge_needs_domain" ;;
                        emergency)     left_text+="  $badge_emergency" ;;
                        relay)         left_text+="  $badge_relay" ;;
                    esac
                fi

                # Right column
                local right_text=""
                if (( r < right_count )); then
                    right_text=" ${right_lines[$r]}"
                fi

                draw_split_row "$left_text" "$right_text"
            done

            draw_split_empty
            draw_split_sep
            local hints=" ${C_DGRAY}Up/Down${C_RST}${C_DIM} navigate${C_RST}  "
            hints+="${C_DGRAY}Enter${C_RST}${C_DIM} select${C_RST}  "
            hints+="${C_DGRAY}s${C_RST}${C_DIM} status${C_RST}  "
            hints+="${C_DGRAY}u${C_RST}${C_DIM} users${C_RST}  "
            hints+="${C_DGRAY}q${C_RST}${C_DIM} quit${C_RST}"
            draw_box_row "$hints"
            draw_box_bottom
        fi

        # Read key
        local key
        key=$(tui_read_key)

        case "$key" in
            UP)
                (( selected-- ))
                (( selected < 0 )) && selected=$(( ${#PROTOCOL_IDS[@]} - 1 ))
                ;;
            DOWN)
                (( selected++ ))
                (( selected >= ${#PROTOCOL_IDS[@]} )) && selected=0
                ;;
            ENTER)
                SELECTED_PROTOCOL="${PROTOCOL_IDS[$selected]}"
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
            q|Q)
                return 1
                ;;
            [0-7])
                if (( key < ${#PROTOCOL_IDS[@]} )); then
                    SELECTED_PROTOCOL="${PROTOCOL_IDS[$key]}"
                    return 0
                fi
                ;;
        esac
    done
}
