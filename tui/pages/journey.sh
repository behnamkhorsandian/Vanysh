#!/bin/bash
# Shared setup and connection journeys. Each screen can return to the menu.

journey_requirements() {
    CHECK_PORT=""; CHECK_TRANSPORT=""; CHECK_NOTE=""
    case "$1" in
        reality|vray|mtp) CHECK_PORT=443; CHECK_TRANSPORT=tcp ;;
        ws|http-obfs) CHECK_PORT=80; CHECK_TRANSPORT=tcp; CHECK_NOTE="A Cloudflare domain is required." ;;
        wg) CHECK_PORT=51820; CHECK_TRANSPORT=udp ;;
        hysteria) CHECK_PORT=8443; CHECK_TRANSPORT=udp ;;
        dnstt|slipstream|noizdns) CHECK_PORT=53; CHECK_TRANSPORT=udp; CHECK_NOTE="A domain and DNS delegation are required." ;;
        tor-bridge) CHECK_PORT=9001; CHECK_TRANSPORT=tcp ;;
        ssh-tunnel) CHECK_PORT=22; CHECK_TRANSPORT=tcp ;;
        sos) CHECK_PORT=8899; CHECK_TRANSPORT=tcp ;;
        conduit|snowflake) CHECK_NOTE="Check your provider's bandwidth allowance." ;;
    esac
}

# Read-only checks. A local listener does not prove that the internet can reach it.
journey_port_status() {
    PORT_STATUS="Not checked. The ss command is unavailable."
    [[ -n "$CHECK_PORT" ]] || { PORT_STATUS="No fixed port listed."; return; }
    if command -v ss >/dev/null 2>&1; then
        local mode=-lnt
        [[ "$CHECK_TRANSPORT" == udp ]] && mode=-lnu
        if ss "$mode" 2>/dev/null | awk -v p=":$CHECK_PORT" 'NR > 1 {if ($4 ~ (p "$")) found=1} END {exit !found}'; then
            PORT_STATUS="A local service is listening on this port."
        else
            PORT_STATUS="No local listener found. This is normal before setup."
        fi
    fi
}

journey_firewall_status() {
    FIREWALL_STATUS="UFW is not available. Check the server firewall."
    if command -v ufw >/dev/null 2>&1; then
        local result
        result=$(ufw status 2>/dev/null | head -1)
        FIREWALL_STATUS="${result:-UFW status could not be read.}"
    fi
}

page_setup_checks() {
    local proto="$1" key message="" 
    tui_scroll_reset
    journey_requirements "$proto"
    while true; do
        tui_get_size; tui_compute_layout
        journey_port_status; journey_firewall_status
        FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Prepare ${PROTOCOL_NAMES[$proto]}${C_RST}" ""
            "These checks run on this machine. Press Q to cancel." "")
        if [[ -n "$CHECK_PORT" ]]; then
            FRAME_CONTENT+=("Required port: $CHECK_PORT/$CHECK_TRANSPORT" "$PORT_STATUS" "$FIREWALL_STATUS" "")
        fi
        [[ -n "$CHECK_NOTE" ]] && FRAME_CONTENT+=("$CHECK_NOTE" "")
        FRAME_CONTENT+=("Your server provider may have a separate firewall."
            "Vany cannot inspect or change that firewall without access."
            "Check DNS and provider steps at https://vany.sh/#docs/getting-started" ""
            "1  Open the listed port in an active UFW firewall"
            "2  Continue to the setup and management menu"
            "R  Check again    Q  Return to the protocol")
        [[ -n "$message" ]] && FRAME_CONTENT+=("" "$message")
        FRAME_FOOTER="1: local firewall  2: continue  Q: back"
        tui_render_frame
        tui_wait_key
        key="$TUI_KEY"
        case "$key" in
            1)
                if [[ -z "$CHECK_PORT" ]]; then
                    message="No fixed local port is required for this option."
                elif ! command -v ufw >/dev/null 2>&1; then
                    message="UFW is unavailable. Use your server firewall controls."
                elif ! ufw status 2>/dev/null | head -1 | grep -qi '^Status: active'; then
                    message="UFW is inactive or unavailable. Vany did not enable it."
                elif ufw allow "${CHECK_PORT}/${CHECK_TRANSPORT}" >/dev/null 2>&1; then
                    message="UFW rule added. Check the provider firewall separately."
                else
                    message="Could not add the UFW rule. Check its status and permissions."
                fi ;;
            2|ENTER) return 0 ;;
            r|R) message="Checks refreshed." ;;
            PGUP) tui_scroll_page_up ;;
            PGDN) tui_scroll_page_down ;;
            q|Q|ESC|BACKSPACE) return 1 ;;
        esac
    done
}

# Never run connection-file hooks as root. wg-quick accepts shell hooks in files.
journey_wireguard_action() {
    local action="$1" path="" key copy_dir copy_path
    if [[ "$(uname -s)" != Linux ]] || ! command -v wg-quick >/dev/null 2>&1; then
        JOURNEY_MESSAGE="Install WireGuard tools on Linux, or use the WireGuard app."
        return
    fi
    tui_get_size; tui_compute_layout
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}WireGuard ${action}${C_RST}" ""
        "Only use a configuration file from someone you trust."
        "Vany rejects files with shell hooks. Routes and DNS may change."
        "Connecting on a remote server can interrupt your SSH session." ""
        "Enter the full path to your WireGuard .conf file."
        "Press Esc to cancel.")
    FRAME_FOOTER="Enter: continue  Esc: back"
    tui_render_frame
    tui_read_line_boxed "Configuration file" "" path || return
    [[ -f "$path" && "$path" == *.conf ]] || { JOURNEY_MESSAGE="Choose an existing .conf file."; return; }
    copy_dir=$(mktemp -d "${TMPDIR:-/tmp}/vany-wg.XXXXXX") || { JOURNEY_MESSAGE="Could not prepare the configuration."; return; }
    copy_path="$copy_dir/${path##*/}"
    if ! cp -- "$path" "$copy_path" || ! chmod 600 "$copy_path"; then
        rm -f "$copy_path"; rmdir "$copy_dir" 2>/dev/null
        JOURNEY_MESSAGE="Could not read the configuration."
        return
    fi
    if grep -Eiq '^[[:space:]]*(PreUp|PostUp|PreDown|PostDown|SaveConfig)[[:space:]]*=' "$copy_path"; then
        rm -f "$copy_path"; rmdir "$copy_dir" 2>/dev/null
        JOURNEY_MESSAGE="File has hooks or SaveConfig. Use the WireGuard app instead."
        return
    fi
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Confirm WireGuard ${action}${C_RST}" ""
        "File: $path" "Network routes and DNS may change." ""
        "Press Y to continue. Press Q to cancel.")
    FRAME_FOOTER="Y: continue  Q: cancel"
    tui_render_frame
    tui_wait_key
    key="$TUI_KEY"
    if [[ "$key" != y && "$key" != Y ]]; then
        rm -f "$copy_path"; rmdir "$copy_dir" 2>/dev/null
        return
    fi
    tui_cleanup
    printf '\n  Running WireGuard %s...\n\n' "$action"
    wg-quick "$action" "$copy_path"
    local result=$?
    rm -f "$copy_path"; rmdir "$copy_dir" 2>/dev/null
    printf '\n  Press any key to return. '
    read -rsn1 </dev/tty
    tui_init
    if (( result == 0 )); then JOURNEY_MESSAGE="WireGuard $action completed. Verify the connection."; else JOURNEY_MESSAGE="WireGuard $action failed. Check the message above."; fi
}

journey_ssh_tunnel() {
    local target="" key result
    if ! command -v ssh >/dev/null 2>&1; then
        JOURNEY_MESSAGE="SSH is not installed on this device."
        return
    fi
    if ! command -v ss >/dev/null 2>&1; then
        JOURNEY_MESSAGE="Install ss to check whether the local proxy starts."
        return
    fi
    if ss -lnt 2>/dev/null | awk 'NR > 1 && $4 ~ /:1080$/ {found=1} END {exit !found}'; then
        JOURNEY_MESSAGE="Port 1080 is already in use. Stop that service first."
        return
    fi
    tui_get_size; tui_compute_layout
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Start an SSH proxy${C_RST}" ""
        "Enter the SSH login as USER@SERVER."
        "The SSH host key must already be trusted."
        "Key-based login without a password prompt is required."
        "The local proxy uses 127.0.0.1 port 1080."
        "Only apps configured to use that SOCKS proxy are routed."
        "Press Esc to cancel.")
    FRAME_FOOTER="Enter: continue  Esc: back"
    tui_render_frame
    tui_read_line_boxed "SSH login" "" target || return
    if [[ ! "$target" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        JOURNEY_MESSAGE="Use a login such as alice@server.example.com."
        return
    fi
    tui_cleanup
    (
        local ssh_pid log ready=0 attempt
        log=$(mktemp "${TMPDIR:-/tmp}/vany-ssh.XXXXXX") || exit 1
        cleanup_ssh() { [[ -n "$ssh_pid" ]] && kill "$ssh_pid" 2>/dev/null || true; rm -f "$log"; }
        trap cleanup_ssh EXIT
        trap 'exit 130' INT TERM
        if [[ -n "${SUDO_USER:-}" ]] && command -v runuser >/dev/null 2>&1; then
            runuser -u "$SUDO_USER" -- ssh -o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -N -D 127.0.0.1:1080 "$target" >"$log" 2>&1 &
        else
            ssh -o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -N -D 127.0.0.1:1080 "$target" >"$log" 2>&1 &
        fi
        ssh_pid=$!
        for (( attempt=0; attempt<10; attempt++ )); do
            kill -0 "$ssh_pid" 2>/dev/null || break
            if ss -lnt 2>/dev/null | awk 'NR > 1 && $4 ~ /:1080$/ {found=1} END {exit !found}'; then ready=1; break; fi
            sleep 1
        done
        if (( !ready )); then
            printf '\n  Could not start the SSH proxy.\n'
            cat "$log"
            printf '\n  Press any key to return. '
            read -rsn1 </dev/tty
            exit 1
        fi
        printf '\n  SSH proxy is running at 127.0.0.1:1080.\n'
        printf '  Configure your app to use this SOCKS proxy.\n'
        printf '  Press Q to stop the proxy and return.\n'
        while true; do
            if IFS= read -rsn1 -t 2 key </dev/tty; then
                case "$key" in q|Q|$'\033') exit 0 ;; esac
            fi
            if ! kill -0 "$ssh_pid" 2>/dev/null; then
                printf '\n  The SSH proxy stopped.\n'
                cat "$log"
                printf '\n  Press any key to return. '
                read -rsn1 </dev/tty
                exit 1
            fi
        done
    )
    result=$?
    tui_init
    if (( result == 0 )); then JOURNEY_MESSAGE="SSH proxy stopped."; else JOURNEY_MESSAGE="SSH proxy did not start or was interrupted."; fi
}

page_connect() {
    local proto="$1" key app="" detail=""
    tui_scroll_reset
    JOURNEY_MESSAGE=""
    case "$proto" in
        reality|ws|vray|http-obfs) app="Hiddify or another compatible VLESS app"; detail="Import the VLESS link from the server owner." ;;
        hysteria) app="Hiddify or another Hysteria v2 app"; detail="Import the Hysteria link from the server owner." ;;
        wg) app="WireGuard app"; detail="Import the .conf file from the server owner." ;;
        mtp) app="Telegram"; detail="Open the MTProto link in Telegram." ;;
        ssh-tunnel) app="SSH client and a SOCKS-capable app"; detail="Ask the server owner for the SSH login details." ;;
        dnstt|slipstream|noizdns) app="The matching DNS tunnel client"; detail="Ask the owner for the domain, key, and client settings." ;;
        sos) app="A compatible SOS chat client"; detail="Ask the owner for the relay address and room details." ;;
        conduit|tor-bridge|snowflake) app="Psiphon or Tor Browser"; detail="This is a community relay, not a private Vany connection." ;;
    esac
    while true; do
        tui_get_size; tui_compute_layout
        FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Connect with ${PROTOCOL_NAMES[$proto]}${C_RST}" ""
            "You need: $app" "$detail" "")
        if [[ "$proto" == wg ]]; then
            FRAME_CONTENT+=("1  Connect with wg-quick on this Linux machine"
                "2  Disconnect with wg-quick on this Linux machine" "")
        elif [[ "$proto" == ssh-tunnel ]]; then
            FRAME_CONTENT+=("1  Start an SSH SOCKS proxy on this device" "")
        fi
        FRAME_CONTENT+=(
            "1. Get the link or file through a private channel."
            "2. Install the matching app on your device."
            "3. Import the link or file into the app and connect." ""
            "Windows: use the app on Windows. The terminal runs in WSL."
            "macOS: use the app on your Mac."
            "Linux: use the app, or WireGuard tools for WireGuard." ""
            "A running service does not guarantee a connection.")
        FRAME_CONTENT+=("" "C  Help me choose    Q  Return to the protocol")
        [[ -n "$JOURNEY_MESSAGE" ]] && FRAME_CONTENT+=("" "$JOURNEY_MESSAGE")
        FRAME_FOOTER="C: chooser  PgDn: more  Q: back"
        tui_render_frame
        tui_wait_key
        key="$TUI_KEY"
        case "$key" in
            1) if [[ "$proto" == wg ]]; then journey_wireguard_action up; elif [[ "$proto" == ssh-tunnel ]]; then journey_ssh_tunnel; fi ;;
            2) [[ "$proto" == wg ]] && journey_wireguard_action down ;;
            c|C) SELECTED_PROTOCOL="_choose"; return 2 ;;
            PGUP) tui_scroll_page_up ;;
            PGDN) tui_scroll_page_down ;;
            q|Q|ESC|BACKSPACE) return 0 ;;
        esac
    done
}

# Short checks for reachability, latency and packet loss. Results are not a
# censorship classification. They use public third-party endpoints.
journey_network_checks() {
    local host
    printf '\n  Checking public endpoints. This sends requests to Cloudflare and Google.\n'
    printf '  Press Q to cancel between checks.\n\n'
    for host in 1.1.1.1 8.8.8.8; do
        printf '  Ping %s\n' "$host"
        if command -v ping >/dev/null 2>&1; then
            ping -c 2 -W 2 "$host" 2>&1 | tail -3
        else
            printf '  Ping is not installed.\n'
        fi
        if command -v dig >/dev/null 2>&1; then
            printf '  DNS answer from %s: ' "$host"
            dig +short +time=2 +tries=1 "@$host" example.com A 2>/dev/null | head -1
        else
            printf '  DNS check unavailable. Install dig to check this resolver.\n'
        fi
        local cancel=""
        if IFS= read -rsn1 -t 0.1 cancel </dev/tty; then
            case "$cancel" in q|Q|$'\033') return ;; esac
        fi
    done
    for host in https://www.cloudflare.com https://www.google.com; do
        printf '\n  HTTPS %s\n' "$host"
        curl -sS -o /dev/null --connect-timeout 3 --max-time 6 \
            -w '  HTTP %{http_code}, total %{time_total} seconds\n' "$host" 2>&1 || true
        local cancel=""
        if IFS= read -rsn1 -t 0.1 cancel </dev/tty; then
            case "$cancel" in q|Q|$'\033') return ;; esac
        fi
    done
    printf '\n  A failure can have many causes. These checks do not prove censorship.\n'
    printf '  Press any key to return. '
    read -rsn1 </dev/tty
}

journey_run_tool() {
    local tool="$1" file="" temporary=0
    tui_cleanup
    printf '\n  Speed test downloads data from Cloudflare.\n'
    printf '  Press Q to cancel or any other key to continue: '
    local key
    read -rsn1 key </dev/tty
    case "$key" in q|Q|$'\033') tui_init; return ;; esac
    file="${TUI_DIR:-}/../scripts/tools/${tool}.sh"
    if [[ ! -f "$file" ]]; then
        file=$(mktemp "${TMPDIR:-/tmp}/vany-tool.XXXXXX") || { tui_init; return; }
        temporary=1
        if ! curl -fsSL --connect-timeout 5 --max-time 20 "$GITHUB_RAW/scripts/tools/${tool}.sh" -o "$file"; then
            printf '\n  Could not download the tool.\n'
            rm -f "$file"; tui_init; return
        fi
    fi
    bash "$file"
    (( temporary )) && rm -f "$file"
    printf '\n  Press any key to return. '
    read -rsn1 </dev/tty
    tui_init
}

journey_trace_route() {
    tui_cleanup
    printf '\n  Tracing the route to Cloudflare 1.1.1.1.\n'
    printf '  A missing hop does not always mean a fault.\n\n'
    if command -v traceroute >/dev/null 2>&1; then
        traceroute -m 8 -q 1 -w 1 1.1.1.1 2>&1
    elif command -v tracepath >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
        timeout 15 tracepath -m 8 1.1.1.1 2>&1 || true
    else
        printf '  Install traceroute or tracepath to use this check.\n'
    fi
    printf '\n  Press any key to return. '
    read -rsn1 </dev/tty
    tui_init
}

journey_container_stats() {
    tui_cleanup
    printf '\n  Docker resource usage for running containers\n\n'
    if command -v docker >/dev/null 2>&1; then
        if command -v timeout >/dev/null 2>&1; then
            timeout 15 docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}' 2>&1 || true
        else
            printf '  Install the timeout utility to run this check.\n'
        fi
    else
        printf '  Docker is not installed.\n'
    fi
    printf '\n  These totals do not show per-user usage.\n'
    printf '  Press any key to return. '
    read -rsn1 </dev/tty
    tui_init
}
