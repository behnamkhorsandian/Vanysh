#!/bin/bash
# Run non-interactive tasks in the existing Vany frame.

_ACTION_DIR=""
_ACTION_PID=""

_action_stop() {
    local target="$_ACTION_PID" watchdog
    [[ -n "$target" ]] || return 0
    kill -TERM -- "-$target" 2>/dev/null || true
    ( sleep 3; kill -KILL -- "-$target" 2>/dev/null || true ) &
    watchdog=$!
    wait "$target" 2>/dev/null || true
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
    _ACTION_PID=""
}

_action_cleanup() {
    _action_stop
    if [[ -n "$_ACTION_DIR" ]]; then
        rm -rf -- "$_ACTION_DIR"
        _ACTION_DIR=""
    fi
}

# Args: title, progress message, show output on completion, command and args.
tui_run_action() {
    local title="$1" message="$2" show_result="$3"
    shift 3
    local key state=running details=0 confirm=0 result=1 line
    local -a output=()
    command -v setsid >/dev/null 2>&1 || {
        FRAME_CONTENT=("${C_ORANGE}${C_BOLD}${title}${C_RST}" "" "Install the setsid utility to run this action.")
        FRAME_FOOTER="Q: return"
        tui_render_frame
        tui_wait_key
        return 1
    }
    _ACTION_DIR=$(umask 077; mktemp -d "${TMPDIR:-/tmp}/vany-action.XXXXXX") || return 1
    ( umask 077; exec setsid "$@" ) >"$_ACTION_DIR/output" 2>&1 < /dev/null &
    _ACTION_PID=$!
    tui_scroll_reset
    local redraw=1
    while true; do
        if [[ "$state" == running ]] && ! kill -0 "$_ACTION_PID" 2>/dev/null; then
            wait "$_ACTION_PID"
            result=$?
            _ACTION_PID=""
            state=done
            (( show_result )) && details=1
            redraw=1
        fi
        tui_get_size
        if (( _DRAWN_TERM_COLS != _TERM_COLS || _DRAWN_TERM_ROWS != _TERM_ROWS )); then redraw=1; fi
        if (( redraw )); then
            tui_compute_layout
            FRAME_CONTENT=("${C_ORANGE}${C_BOLD}${title}${C_RST}" "")
            if [[ "$state" == running ]]; then
                FRAME_CONTENT+=("$message" "This can take a few minutes.")
                if (( confirm )); then
                    FRAME_CONTENT+=("" "Stopping now can leave partial changes." "Press Y to stop. Press N to continue.")
                else
                    FRAME_CONTENT+=("" "Press D for details. Press Q to stop.")
                fi
                FRAME_FOOTER="D: details  Q: stop"
            elif (( result == 0 )); then
                FRAME_CONTENT+=("${C_LGREEN}Complete.${C_RST}" "" "Press D for details. Press Q to return.")
                FRAME_FOOTER="D: details  Q: return"
            else
                FRAME_CONTENT+=("${C_RED}The action did not finish.${C_RST}" "Changes may be incomplete." "" "Press D for details. Press Q to return.")
                FRAME_FOOTER="D: details  Q: return"
            fi
            if (( details )); then
                FRAME_CONTENT+=("" "${C_LGREEN}Details${C_RST}" "Press R to refresh. Use Page Up and Page Down to scroll." "")
                output=()
                while IFS= read -r line || [[ -n "$line" ]]; do output+=("$line"); done < <(
                    tail -n 250 "$_ACTION_DIR/output" 2>/dev/null |
                    LC_ALL=C sed -E 's/\x1b\[[0-9;?]*[ -\/]*[@-~]//g; s/\\/\\\\/g' |
                    LC_ALL=C tr -d '\000-\010\013-\037\177'
                )
                if (( ${#output[@]} )); then FRAME_CONTENT+=("${output[@]}"); else FRAME_CONTENT+=("No details yet."); fi
                FRAME_FOOTER="R: refresh  PgUp/PgDn: scroll  Q: return or stop"
            fi
            tui_render_frame
            redraw=0
        fi
        key=$(tui_read_key 0.5)
        case "$key" in
            TICK) : ;;
            EOF)
                _action_stop; result=130; break ;;
            q|Q|ESC)
                if [[ "$state" == done ]]; then break; fi
                confirm=1; details=0; tui_scroll_reset; redraw=1 ;;
            y|Y)
                if (( confirm )) && [[ "$state" == running ]]; then
                    _action_stop; result=130; state=done; confirm=0; redraw=1
                fi ;;
            n|N) if (( confirm )); then confirm=0; redraw=1; fi ;;
            d|D) details=$((1 - details)); tui_scroll_reset; redraw=1 ;;
            r|R) (( details )) && redraw=1 ;;
            PGUP) if (( details )); then tui_scroll_page_up; redraw=1; fi ;;
            PGDN) if (( details )); then tui_scroll_page_down; redraw=1; fi ;;
            ENTER|1) [[ "$state" == done ]] && break ;;
        esac
    done
    _action_cleanup
    tui_scroll_reset
    return "$result"
}
