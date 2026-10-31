#!/bin/bash
# Runs in GitHub Actions. No network or host firewall changes are made.
set +e
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR=$(mktemp -d) || exit 1
trap 'rm -rf "$TEST_DIR"' EXIT
export TUI_DIR="$ROOT_DIR/tui"
source "$TUI_DIR/theme.sh"
source "$TUI_DIR/engine.sh"
source "$TUI_DIR/pages/journey.sh"
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
page_connect() { printf '%s\n' "$1" > "$TEST_DIR/connected-page"; return 0; }
printf 'ENTER\n2\nq\n' > "$TEST_DIR/keys"
page_main_menu
[[ -f "$TEST_DIR/connected-page" ]] || fail 'connect action did not open'
[[ $(cat "$TEST_DIR/connected-page") == reality ]] || fail 'connect action opened the wrong protocol'

printf 'c\n' > "$TEST_DIR/keys"
page_main_menu
[[ "$SELECTED_PROTOCOL" == _choose ]] || fail 'chooser shortcut did not return to the router'

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
printf 'TUI smoke checks passed\n'
