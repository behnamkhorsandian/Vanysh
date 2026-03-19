// ---------------------------------------------------------------------------
// Vany TUI — Thin Bash Client
//
// Served when user runs: curl vany.sh | sudo bash
// Pattern from 432.sh x-client: stdin is the pipe, /dev/tty (fd 3)
// handles keyboard I/O. Worker-rendered pages stream via background curl.
// Local pages (status, users) render directly from Docker/state files.
// ---------------------------------------------------------------------------

export const VANY_CLIENT_SCRIPT = `#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Vany — Interactive Terminal Client
# Usage: curl vany.sh | sudo bash
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

BASE="https://vany.sh"
VANY_DIR="/opt/vany"
STATE_FILE="\$VANY_DIR/state.json"
USERS_FILE="\$VANY_DIR/users.json"
CURRENT="protocols"
STREAM_PID=""
CR=\$'\\r'

# -- Colors ----------------------------------------------------------------
C_RST="\\033[0m"
C_GREEN="\\033[38;5;36m"
C_LGREEN="\\033[38;5;115m"
C_DGRAY="\\033[38;5;236m"
C_TEXT="\\033[38;5;253m"
C_ORANGE="\\033[38;5;172m"
C_RED="\\033[38;5;130m"
C_BOLD="\\033[1m"
C_DIM="\\033[2m"

# -- Check root ------------------------------------------------------------
if [[ "\$(id -u)" -ne 0 ]]; then
    echo -e "\${C_RED}Error: Run as root (sudo).\${C_RST}"
    exit 1
fi

# -- Bootstrap if needed ---------------------------------------------------
if ! command -v docker &>/dev/null; then
    echo -e "\${C_GREEN}First run detected. Installing Docker...\${C_RST}"
    BOOTSTRAP_URL="\${BASE}/scripts/docker-bootstrap.sh"
    curl -sf "\$BOOTSTRAP_URL" | bash
fi

# -- Initialize state if missing ------------------------------------------
if [[ ! -f "\$STATE_FILE" ]]; then
    mkdir -p "\$VANY_DIR"
    PUBLIC_IP=\$(curl -sf https://ifconfig.me || curl -sf https://ipinfo.io/ip || echo "unknown")
    MACHINE_ID=""
    [[ -f /etc/machine-id ]] && MACHINE_ID=\$(cat /etc/machine-id)
    cat > "\$STATE_FILE" <<STATEEOF
{
  "machine_id": "\$MACHINE_ID",
  "ip": "\$PUBLIC_IP",
  "provider": "unknown",
  "protocols": {}
}
STATEEOF
fi

# -- Keyboard from /dev/tty ------------------------------------------------
exec 3</dev/tty

# -- Terminal cleanup ------------------------------------------------------
OLD_STTY=""
cleanup() {
    kill_stream
    [[ -n "\$OLD_STTY" ]] && stty "\$OLD_STTY" <&3 2>/dev/null
    printf "\\033[?25h"
    printf "\\033[?1049l"
    printf "\\r\\n"
    printf "%b\\r\\n" "\${C_GREEN}  Vany - vany.sh"
    printf "%b\\r\\n" "  Goodbye.\${C_RST}"
    printf "\\r\\n"
    exec 3<&- 2>/dev/null
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# -- Terminal setup --------------------------------------------------------
OLD_STTY=\$(stty -g <&3 2>/dev/null || true)
stty -icanon -echo <&3 2>/dev/null || true
printf "\\033[?1049h"
printf "\\033[?25l"

# -- Output helper (safe for raw-ish mode) ---------------------------------
# Prints a line with CR+LF to handle any terminal mode
out() {
    printf "%s\\r\\n" "\$1"
}
oute() {
    printf "%b\\r\\n" "\$1"
}

# -- Terminal size ---------------------------------------------------------
get_size() {
    cols=\$(tput cols  <&3 2>/dev/null || echo 100)
    rows=\$(tput lines <&3 2>/dev/null || echo 40)
}

# -- Encode state for Worker -----------------------------------------------
encode_state() {
    if [[ -f "\$STATE_FILE" ]]; then
        # Collect live Docker status into state
        local state
        state=\$(cat "\$STATE_FILE")

        # Merge docker container statuses
        for container in vany-xray vany-wireguard vany-dnstt vany-conduit vany-sos; do
            local cstatus
            cstatus=\$(docker inspect --format '{{.State.Status}}' "\$container" 2>/dev/null || echo "not_installed")
            local proto="\${container#vany-}"
            state=\$(echo "\$state" | jq --arg p "\$proto" --arg s "\$cstatus" \\
                'if .protocols[\$p] then .protocols[\$p].status = \$s else . end' 2>/dev/null || echo "\$state")
        done

        echo "\$state" | base64 -w0 2>/dev/null || echo "\$state" | base64 2>/dev/null
    else
        echo "e30="
    fi
}

# -- Stream management -----------------------------------------------------
kill_stream() {
    if [[ -n "\$STREAM_PID" ]]; then
        kill "\$STREAM_PID" 2>/dev/null || true
        wait "\$STREAM_PID" 2>/dev/null || true
        STREAM_PID=""
    fi
}

start_stream() {
    local endpoint="\$1"
    kill_stream
    get_size
    local state_b64
    state_b64=\$(encode_state)
    curl -sN "\${BASE}/tui/\${endpoint}?cols=\${cols}&rows=\${rows}&stream=1&interactive=1&state=\${state_b64}" 2>/dev/null &
    STREAM_PID=\$!
}

# -- Local page: Docker status ---------------------------------------------
show_status() {
    kill_stream
    CURRENT="status"
    printf "\\033[2J\\033[H"
    get_size

    oute "\${C_GREEN}\${C_BOLD}  DOCKER STATUS\${C_RST}"
    out ""

    # Header and separator - format without ANSI, colorize separately
    local hdr sep
    hdr=\$(printf "  %-20s %-12s %-20s %-15s" "CONTAINER" "STATUS" "IMAGE" "UPTIME")
    sep=\$(printf "  %-20s %-12s %-20s %-15s" "───────────────────" "────────────" "────────────────────" "───────────────")
    oute "\${C_ORANGE}\${hdr}\${C_RST}"
    oute "\${C_DGRAY}\${sep}\${C_RST}"

    local containers=("vany-xray" "vany-wireguard" "vany-dnstt" "vany-conduit" "vany-sos")

    for c in "\${containers[@]}"; do
        local status="--" image="--" uptime="--" color="\${C_DGRAY}"
        if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^\${c}\$"; then
            status=\$(docker inspect --format '{{.State.Status}}' "\$c" 2>/dev/null || echo "--")
            image=\$(docker inspect --format '{{.Config.Image}}' "\$c" 2>/dev/null | cut -d: -f1 | rev | cut -d/ -f1 | rev)
            uptime=\$(docker inspect --format '{{.State.StartedAt}}' "\$c" 2>/dev/null | cut -dT -f1)
            [[ "\$status" == "running" ]] && color="\${C_GREEN}"
            [[ "\$status" == "exited" ]] && color="\${C_RED}"
        fi
        # Format text first (no ANSI in printf format), then colorize
        local line
        line=\$(printf "  %-20s %-12s %-20s %-15s" "\$c" "\$status" "\$image" "\$uptime")
        oute "\${color}\${line}\${C_RST}"
    done

    out ""
    oute "  \${C_LGREEN}[p]\${C_RST} \${C_TEXT}Protocols\${C_RST}  \${C_LGREEN}[u]\${C_RST} \${C_TEXT}Users\${C_RST}  \${C_LGREEN}[i]\${C_RST} \${C_TEXT}Install\${C_RST}  \${C_LGREEN}[h]\${C_RST} \${C_TEXT}Help\${C_RST}  \${C_LGREEN}[q]\${C_RST} \${C_TEXT}Quit\${C_RST}"
    oute "  \${C_DIM}Press any key to go back\${C_RST}"
}

# -- Local page: Users list ------------------------------------------------
show_users() {
    kill_stream
    CURRENT="users"
    printf "\\033[2J\\033[H"

    oute "\${C_GREEN}\${C_BOLD}  USERS\${C_RST}"
    out ""

    if [[ ! -f "\$USERS_FILE" ]]; then
        oute "  \${C_DIM}No users database found.\${C_RST}"
        out ""
        oute "  \${C_LGREEN}[p]\${C_RST} \${C_TEXT}Protocols\${C_RST}  \${C_LGREEN}[s]\${C_RST} \${C_TEXT}Status\${C_RST}  \${C_LGREEN}[h]\${C_RST} \${C_TEXT}Help\${C_RST}  \${C_LGREEN}[q]\${C_RST} \${C_TEXT}Quit\${C_RST}"
        oute "  \${C_DIM}Press any key to go back\${C_RST}"
        return
    fi

    local usercount
    usercount=\$(jq '.users | length' "\$USERS_FILE" 2>/dev/null || echo 0)

    if [[ "\$usercount" -eq 0 ]]; then
        oute "  \${C_DIM}No users configured.\${C_RST}"
    else
        local hdr sep
        hdr=\$(printf "  %-20s %-15s %-30s" "USERNAME" "PROTOCOLS" "CREATED")
        sep=\$(printf "  %-20s %-15s %-30s" "───────────────────" "──────────────" "────────────────────────────")
        oute "\${C_ORANGE}\${hdr}\${C_RST}"
        oute "\${C_DGRAY}\${sep}\${C_RST}"

        jq -r '.users | to_entries[] | [.key, (.value.protocols | keys | join(",")), .value.created] | @tsv' "\$USERS_FILE" 2>/dev/null | \\
        while IFS=\$'\\t' read -r name protos created; do
            local line
            line=\$(printf "  %-20s %-15s %-30s" "\$name" "\$protos" "\$created")
            oute "\${C_TEXT}\${line}\${C_RST}"
        done
    fi

    out ""
    oute "  \${C_TEXT}Total: \${C_GREEN}\$usercount\${C_RST} users"
    out ""
    oute "  \${C_LGREEN}[p]\${C_RST} \${C_TEXT}Protocols\${C_RST}  \${C_LGREEN}[s]\${C_RST} \${C_TEXT}Status\${C_RST}  \${C_LGREEN}[h]\${C_RST} \${C_TEXT}Help\${C_RST}  \${C_LGREEN}[q]\${C_RST} \${C_TEXT}Quit\${C_RST}"
    oute "  \${C_DIM}Press any key to go back\${C_RST}"
}

# -- Worker-rendered pages -------------------------------------------------
show_worker_page() {
    local page="\$1"
    CURRENT="\$page"
    start_stream "\$page"
}

# -- Navigate --------------------------------------------------------------
navigate() {
    case "\$1" in
        protocols) show_worker_page "protocols" ;;
        status)    show_status ;;
        users)     show_users ;;
        install)   show_worker_page "install" ;;
        help)      show_worker_page "help" ;;
    esac
}

# -- Embedded command handler -----------------------------------------------
# Worker sends: \\x1b]vany;cmd;<base64-command>\\x07
# Client detects, decodes, executes, shows result
handle_embedded_cmd() {
    local encoded="\$1"
    local cmd
    cmd=\$(echo "\$encoded" | base64 -d 2>/dev/null)
    if [[ -z "\$cmd" ]]; then
        return 1
    fi

    printf "\\033[2J\\033[H"
    oute "\${C_GREEN}\${C_BOLD}  EXECUTING\${C_RST}"
    out ""
    oute "  \${C_DIM}\$cmd\${C_RST}"
    out ""

    # Execute the command
    if eval "\$cmd" 2>&1 | while IFS= read -r line; do
        out "  \$line"
    done; then
        oute "\${C_GREEN}  Done.\${C_RST}"
    else
        oute "\${C_RED}  Failed.\${C_RST}"
    fi

    out ""
    oute "  \${C_DIM}Press any key to continue\${C_RST}"
    IFS= read -rsn1 _ <&3
    navigate "protocols"
}

# -- Read keypress from /dev/tty -------------------------------------------
read_key() {
    local c1 c2 c3
    IFS= read -rsn1 -t 1 c1 <&3 || { echo "TICK"; return; }

    if [[ "\$c1" == \$'\\033' ]]; then
        IFS= read -rsn1 -t 0.1 c2 <&3 || true
        if [[ "\$c2" == "[" ]]; then
            IFS= read -rsn1 -t 0.1 c3 <&3 || true
            case "\$c3" in
                A) echo "UP";    return ;;
                B) echo "DOWN";  return ;;
                C) echo "RIGHT"; return ;;
                D) echo "LEFT";  return ;;
            esac
        fi
        echo "ESC"
        return
    fi

    if [[ -z "\$c1" || "\$c1" == \$'\\r' || "\$c1" == \$'\\n' ]]; then
        echo "ENTER"
        return
    fi
    echo "\$c1"
}

# -- Handle key input -------------------------------------------------------
handle_key() {
    local key="\$1"
    case "\$key" in
        p|P) navigate "protocols" ;;
        s|S) navigate "status"    ;;
        u|U) navigate "users"     ;;
        i|I) navigate "install"   ;;
        h|H) navigate "help"      ;;
        r|R) navigate "\$CURRENT"  ;;
        q|Q) exit 0               ;;
        TICK) ;;
        *)
            # On local pages, any key goes back to protocols
            if [[ "\$CURRENT" == "status" || "\$CURRENT" == "users" ]]; then
                navigate "protocols"
            fi
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

# Show splash briefly
get_size
curl -sf "\${BASE}/tui/splash?cols=\${cols}&rows=\${rows}" 2>/dev/null
sleep 1

# Start on protocols page
navigate "protocols"

# Input loop
while true; do
    key=\$(read_key)
    handle_key "\$key"
done
`;
