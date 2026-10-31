#!/bin/bash
# Runs in GitHub Actions. No network or host firewall changes are made.
set +e
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR=$(mktemp -d) || exit 1
trap 'rm -rf "$TEST_DIR"' EXIT
export TUI_DIR="$ROOT_DIR/tui"
source "$TUI_DIR/theme.sh"
source "$TUI_DIR/engine.sh"
source "$TUI_DIR/pages/actions.sh"
source "$TUI_DIR/pages/manage.sh"
source "$TUI_DIR/pages/journey.sh"
source "$TUI_DIR/pages/chooser.sh"
source "$TUI_DIR/pages/main.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
[[ ${#PROTOCOL_IDS[@]} -eq 15 ]] || fail 'protocol catalog did not load'
[[ ${PROTOCOL_NAMES[reality]} == 'VLESS + REALITY' ]] || fail 'protocol metadata did not load'
[[ ${PROTOCOL_NAMES[http-obfs]} == 'HTTP Obfuscation' ]] || fail 'hyphenated protocol metadata did not load'

VANY_DIR="$TEST_DIR/state"
mkdir -p "$VANY_DIR"
cat > "$VANY_DIR/state.json" <<'JSON'
{"protocols":{"xray":{"status":"running","container":"vany-xray","reality":{}},"wireguard":{"status":"running","container":"vany-wireguard"}}}
JSON
docker() { [[ "$1" == ps ]] && printf 'vany-xray\n'; }
_refresh_menu_status
service_installed reality || fail 'REALITY state was not found'
service_running reality || fail 'running REALITY container was not found'
service_installed wg || fail 'WireGuard state was not found'
service_running wg && fail 'stopped WireGuard was reported as running'
service_installed ws && fail 'an absent Xray feature was reported as installed'

VANY_USERS="$TEST_DIR/users.json"
cat > "$VANY_USERS" <<'JSON'
{"users":{"alice":{"protocols":{"wg":{"public_key":"peer-A"}}}}}
JSON
docker() {
    case "$1" in
        ps) printf 'vany-xray\nvany-wireguard\n' ;;
        inspect) printf 'healthy\n' ;;
        exec) printf 'peer-A\t2097152\t3145728\n' ;;
    esac
}
timeout() { shift; "$@"; }
_refresh_menu_status
_build_status_content
printf '%s\n' "${FRAME_CONTENT[@]}" | grep -Fq 'alice: server received 2 MiB, sent 3 MiB' || fail 'WireGuard peer usage was not displayed'

# Idle status updates must preserve the frame and the scroll position.
_FRAME_W=80; _TERM_COLS=80; _TERM_ROWS=30
_DRAWN_TERM_COLS=80; _DRAWN_TERM_ROWS=30
_STATUS_ROWS=('old status'); _SCROLL_OFFSET=7
_refresh_machine_metrics() { :; }
_build_status_rows() { _STATUS_ROWS=('updated status'); }
tui_refresh_status > "$TEST_DIR/status-output"
grep -Fq 'updated status' "$TEST_DIR/status-output" || fail 'status row was not refreshed'
grep -Fq $'\033[2J' "$TEST_DIR/status-output" && fail 'idle status update cleared the screen'
[[ $_SCROLL_OFFSET -eq 7 ]] || fail 'idle status update changed scroll position'

# A normal frame redraw should overwrite in place, not blank the terminal.
_COMPACT=1; _CONTENT_INNER_W=78; _CONTENT_H=20; _CHROME_ROWS=6; _BANNER_H=0
_SCROLL_OFFSET=0; FRAME_CONTENT=('frame content'); FRAME_FOOTER='Q: quit'
proto=wg
tui_render_frame > "$TEST_DIR/frame-output"
grep -Fq 'frame content' "$TEST_DIR/frame-output" || fail 'frame content was not rendered'
grep -Fq $'\033[2J' "$TEST_DIR/frame-output" && fail 'frame redraw cleared the screen'
[[ "$proto" == wg ]] || fail 'sidebar rendering changed the selected protocol'

# Replace only the drawing and keyboard functions. The page routing stays real.
tui_get_size() { _TERM_COLS=100; _TERM_ROWS=30; }
tui_compute_layout() { _FRAME_W=100; _CONTENT_INNER_W=77; _CONTENT_H=20; }
tui_render_frame() { :; }
tui_read_key() {
    local key
    IFS= read -r key < "$TEST_DIR/keys"
    sed '1d' "$TEST_DIR/keys" > "$TEST_DIR/keys.next"
    mv "$TEST_DIR/keys.next" "$TEST_DIR/keys"
    printf '%s\n' "$key"
}
tui_refresh_status() { printf 'tick\n' >> "$TEST_DIR/status-ticks"; }
printf 'TICK\nENTER\n' > "$TEST_DIR/keys"
tui_wait_key > "$TEST_DIR/wait-output"
[[ "$TUI_KEY" == ENTER ]] || fail 'idle update was treated as a key press'
[[ ! -e "$TEST_DIR/status-ticks" ]] || fail 'a short idle wait refreshed the status too soon'
[[ ! -s "$TEST_DIR/wait-output" ]] || fail 'status output leaked into key handling'
printf 'EOF\n' > "$TEST_DIR/keys"
tui_wait_key
[[ "$TUI_KEY" == Q ]] || fail 'closed terminal input did not exit cleanly'

printf '2\n1\n2\n1\n' > "$TEST_DIR/keys"
page_chooser || fail 'chooser did not return a selection'
[[ "$START_PROTOCOL" == wg ]] || fail 'chooser selected the wrong protocol'
START_PROTOCOL=""
printf 'q\n' > "$TEST_DIR/keys"
page_chooser && fail 'chooser did not return on Q'

page_connect() { printf '%s\n' "$1" > "$TEST_DIR/connected-page"; return 0; }
printf 'ENTER\n2\nq\n' > "$TEST_DIR/keys"
page_main_menu
[[ -f "$TEST_DIR/connected-page" ]] || fail 'connect action did not open'
[[ $(cat "$TEST_DIR/connected-page") == reality ]] || fail 'connect action opened the wrong protocol'

printf 'c\n' > "$TEST_DIR/keys"
page_main_menu
[[ "$SELECTED_PROTOCOL" == _choose ]] || fail 'chooser shortcut did not return to the router'
[[ -z "$CHOOSER_RETURN_PROTOCOL" ]] || fail 'home chooser retained a protocol'

printf 'ENTER\nc\n' > "$TEST_DIR/keys"
page_main_menu
[[ "$CHOOSER_RETURN_PROTOCOL" == reality ]] || fail 'protocol chooser did not preserve the previous page'

# A mocked UFW command records changes without touching the runner firewall.
journey_port_status() { PORT_STATUS='not checked in this test'; }
ufw() {
    case "$1" in
        status) printf 'Status: %s\n' "$TEST_UFW_STATE" ;;
        allow) printf '%s\n' "$2" >> "$TEST_DIR/firewall-rules" ;;
    esac
}
TEST_UFW_STATE=active
printf '1\n2\n' > "$TEST_DIR/keys"
page_setup_checks reality || fail 'setup checks did not continue'
[[ $(cat "$TEST_DIR/firewall-rules") == 443/tcp ]] || fail 'active UFW rule was not applied'
TEST_UFW_STATE=inactive
printf '1\n2\n' > "$TEST_DIR/keys"
page_setup_checks wg || fail 'inactive firewall check did not continue'
[[ $(wc -l < "$TEST_DIR/firewall-rules") -eq 1 ]] || fail 'inactive UFW was modified'

# The service menu uses the frame and does not start an action before consent.
_manage_run() { printf '%s:%s\n' "$1" "$2" >> "$TEST_DIR/actions"; }
page_setup_checks() { return 0; }
printf '1\nn\nq\n' > "$TEST_DIR/keys"
page_manage wg
[[ ! -e "$TEST_DIR/actions" ]] || fail 'reinstall ran after cancellation'
printf '1\nq\n' > "$TEST_DIR/keys"
page_manage hysteria
[[ $(cat "$TEST_DIR/actions") == hysteria:install ]] || fail 'setup did not invoke the selected action'

# The action entry point must not need a controlling terminal or open a menu.
if sudo -n env VANY_PROTOCOL=vray VANY_ACTION=install bash "$ROOT_DIR/scripts/direct-install.sh" </dev/null > "$TEST_DIR/action-output" 2>&1; then
    fail 'unsupported protocol setup unexpectedly succeeded'
fi
grep -Fq 'not implemented' "$TEST_DIR/action-output" || fail 'action did not report the unsupported protocol'
grep -Fq 'Choose an option' "$TEST_DIR/action-output" && fail 'action opened the old protocol menu'

# Exercise a setup action with harmless stand-ins for the downloaded scripts.
mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/curl" <<'SH'
#!/bin/bash
url='' dest=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) dest="$2"; shift 2 ;;
        http*) url="$1"; shift ;;
        *) shift ;;
    esac
done
case "$url" in
    */scripts/docker-bootstrap.sh)
        printf '%s\n' 'bootstrap() { echo BOOTSTRAP_OK; }' > "$dest" ;;
    */scripts/protocols/install-xray.sh)
        cat > "$dest" <<'SCRIPT'
install_xray() { echo XRAY_OK; }
add_ws_inbound() { echo INBOUND_OK; }
set_ws_state() { echo "DOMAIN=$1"; }
reload_xray() { echo RELOAD_OK; }
SCRIPT
        ;;
    *) exit 1 ;;
esac
SH
chmod +x "$TEST_DIR/bin/curl"
if ! sudo -n env PATH="$TEST_DIR/bin:$PATH" VANY_PROTOCOL=ws VANY_ACTION=install VANY_DOMAIN=vpn.example.com bash "$ROOT_DIR/scripts/direct-install.sh" </dev/null > "$TEST_DIR/setup-output" 2>&1; then
    fail 'non-interactive setup action failed'
fi
grep -Fq 'DOMAIN=vpn.example.com' "$TEST_DIR/setup-output" || fail 'setup did not pass the selected domain'
grep -Fq 'Choose an option' "$TEST_DIR/setup-output" && fail 'setup opened the old protocol menu'
printf 'TUI smoke checks passed\n'
