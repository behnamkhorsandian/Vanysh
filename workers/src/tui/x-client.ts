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
    printf "\\n\${C_GREEN}"
    printf '%s\\n' '  Vany - vany.sh'
    printf '%s\\n' '  Goodbye.'
    printf "\${C_RST}\\n"
    exec 3<&- 2>/dev/null
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# -- Terminal setup --------------------------------------------------------
OLD_STTY=\$(stty -g <&3 2>/dev/null || true)
stty raw -echo <&3 2>/dev/null || true
printf "\\033[?1049h"
printf "\\033[?25l"

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

    printf "\${C_GREEN}\${C_BOLD}  DOCKER STATUS\${C_RST}\\n\\n"

    local containers=("vany-xray" "vany-wireguard" "vany-dnstt" "vany-conduit" "vany-sos")

    printf "  \${C_ORANGE}%-20s %-12s %-20s %-15s\${C_RST}\\n" "CONTAINER" "STATUS" "IMAGE" "UPTIME"
    printf "  \${C_DGRAY}%-20s %-12s %-20s %-15s\${C_RST}\\n" "─────────────────" "──────────" "──────────────────" "─────────────"

    for c in "\${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^\${c}\$"; then
            local status image uptime
            status=\$(docker inspect --format '{{.State.Status}}' "\$c" 2>/dev/null)
            image=\$(docker inspect --format '{{.Config.Image}}' "\$c" 2>/dev/null | cut -d: -f1 | rev | cut -d/ -f1 | rev)
            uptime=\$(docker inspect --format '{{.State.StartedAt}}' "\$c" 2>/dev/null | cut -dT -f1)

            local color="\${C_TEXT}"
            [[ "\$status" == "running" ]] && color="\${C_GREEN}"
            [[ "\$status" == "exited" ]] && color="\${C_RED}"

            printf "  \${C_TEXT}%-20s \${color}%-12s\${C_RST} \${C_DIM}%-20s %-15s\${C_RST}\\n" "\$c" "\$status" "\$image" "\$uptime"
        else
            printf "  \${C_TEXT}%-20s \${C_DGRAY}%-12s %-20s %-15s\${C_RST}\\n" "\$c" "--" "--" "--"
        fi
    done

    printf "\\n  \${C_DIM}Press any key to go back\${C_RST}"
}

# -- Local page: Users list ------------------------------------------------
show_users() {
    kill_stream
    CURRENT="users"
    printf "\\033[2J\\033[H"

    printf "\${C_GREEN}\${C_BOLD}  USERS\${C_RST}\\n\\n"

    if [[ ! -f "\$USERS_FILE" ]]; then
        printf "  \${C_DIM}No users database found.\${C_RST}\\n"
        printf "\\n  \${C_DIM}Press any key to go back\${C_RST}"
        return
    fi

    local usercount
    usercount=\$(jq '.users | length' "\$USERS_FILE" 2>/dev/null || echo 0)

    if [[ "\$usercount" -eq 0 ]]; then
        printf "  \${C_DIM}No users configured.\${C_RST}\\n"
    else
        printf "  \${C_ORANGE}%-20s %-15s %-30s\${C_RST}\\n" "USERNAME" "PROTOCOLS" "CREATED"
        printf "  \${C_DGRAY}%-20s %-15s %-30s\${C_RST}\\n" "──────────────────" "─────────────" "────────────────────────────"

        jq -r '.users | to_entries[] | [.key, (.value.protocols | keys | join(",")), .value.created] | @tsv' "\$USERS_FILE" 2>/dev/null | \\
        while IFS=\$'\\t' read -r name protos created; do
            printf "  \${C_TEXT}%-20s \${C_LGREEN}%-15s \${C_DIM}%-30s\${C_RST}\\n" "\$name" "\$protos" "\$created"
        done
    fi

    printf "\\n  \${C_TEXT}Total: \${C_GREEN}\$usercount\${C_RST} users"
    printf "\\n\\n  \${C_DIM}Press any key to go back\${C_RST}"
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
    printf "\${C_GREEN}\${C_BOLD}  EXECUTING\${C_RST}\\n\\n"
    printf "  \${C_DIM}\$cmd\${C_RST}\\n\\n"

    # Execute the command
    if eval "\$cmd" 2>&1 | while IFS= read -r line; do
        printf "  %s\\n" "\$line"
    done; then
        printf "\\n  \${C_GREEN}Done.\${C_RST}"
    else
        printf "\\n  \${C_RED}Failed.\${C_RST}"
    fi

    printf "\\n  \${C_DIM}Press any key to continue\${C_RST}"
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
