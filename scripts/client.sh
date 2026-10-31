#!/bin/bash
# macOS client menu. Server creation runs on a separate Linux machine.
exec 3</dev/tty 2>/dev/null || { echo 'Open an interactive terminal to use Vany.'; exit 1; }
BASE="https://raw.githubusercontent.com/behnamkhorsandian/Vanysh/main"
PUBLIC_IP="unknown"
LOCATION="unknown"

# Public IP and approximate location are supplied by ipinfo.io once per session.
geo=$(curl -fsS --connect-timeout 2 --max-time 3 https://ipinfo.io/json 2>/dev/null) || geo=""
if [[ -n "$geo" ]]; then
    ip=$(printf '%s\n' "$geo" | sed -n 's/.*"ip"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr -cd '0-9a-fA-F:.')
    city=$(printf '%s\n' "$geo" | sed -n 's/.*"city"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr -cd '[:alnum:] ,.-')
    [[ -n "$ip" ]] && PUBLIC_IP="$ip"
    [[ -n "$city" ]] && LOCATION="$city"
fi

header() {
    local cpu total_mb used_mb local_ip page_size iface net
    cpu=$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/ {print $3 " user, " $5 " system"; exit}')
    total_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f MiB", $1/1048576}')
    page_size=$(sysctl -n hw.pagesize 2>/dev/null)
    used_mb=$(vm_stat 2>/dev/null | awk -v p="${page_size:-4096}" '/^Pages active:|^Pages wired down:|^Pages occupied by compressor:/ {n=$NF; gsub(/[^0-9]/,"",n); used+=n} END {if (used) printf "~%.0f MiB",used*p/1048576; else print "unknown"}')
    local_ip=$(ipconfig getifaddr en0 2>/dev/null || true)
    iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
    net=$(netstat -ibn 2>/dev/null | awk -v interface="$iface" 'NR==1 {for(i=1;i<=NF;i++){if($i=="Ibytes")r=i; if($i=="Obytes")t=i}} $1==interface && r && t {printf "%.0f/%.0f MiB",$r/1048576,$t/1048576; exit}')
    clear 2>/dev/null || true
    printf '\n  VANY | CPU %s | RAM %s / %s\n' "${cpu:-unknown}" "$used_mb" "${total_mb:-unknown}"
    printf '  Network received/sent %s on %s\n' "${net:-unknown}" "${iface:-unknown}"
    printf '  Public IP %s | Location ~%s | Local IP %s\n' "$PUBLIC_IP" "$LOCATION" "${local_ip:-unknown}"
    printf '  UTC %s | Local %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S')" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf '\n'
    CLIENT_HEADER="CPU ${cpu:-unknown} | RAM $used_mb / ${total_mb:-unknown} | Net ${net:-unknown} | Public IP $PUBLIC_IP | Location ~$LOCATION"
}

key() { IFS= read -rsn1 KEY <&3 || exit 0; printf '\n'; }
pause_key() { printf '\n  Press any key to return: '; key; }

network_checks() {
    local host
    header
    printf '  These checks contact Cloudflare and Google.\n'
    printf '  They do not prove censorship. Press Q between checks to cancel.\n\n'
    for host in 1.1.1.1 8.8.8.8; do
        printf '  Ping %s\n' "$host"
        ping -c 2 -W 2000 "$host" 2>&1 | tail -3
        if command -v dig >/dev/null 2>&1; then
            printf '  DNS answer from %s: ' "$host"
            dig +short +time=2 +tries=1 "@$host" example.com A 2>/dev/null | head -1
        else
            printf '  DNS check unavailable. Install dig to check this resolver.\n'
        fi
        local cancel=""
        if IFS= read -rsn1 -t 0.1 cancel <&3; then
            case "$cancel" in q|Q|$'\033') return ;; esac
        fi
    done
    for host in https://www.cloudflare.com https://www.google.com; do
        printf '\n  HTTPS %s\n' "$host"
        curl -sS -o /dev/null --connect-timeout 3 --max-time 6 -w '  HTTP %{http_code}, %{time_total} seconds\n' "$host" 2>&1 || true
        local cancel=""
        if IFS= read -rsn1 -t 0.1 cancel <&3; then
            case "$cancel" in q|Q|$'\033') return ;; esac
        fi
    done
    pause_key
}

status_menu() {
    while true; do
        header
        printf '  Status and checks\n\n'
        printf '  Public IP and approximate location come from ipinfo.io.\n'
        printf '  1  Check public endpoints and packet loss\n  2  Test download speed\n  3  Trace a route\n  4  Show network interface counters\n  Q  Return\n\n'
        key
        case "$KEY" in
            1) network_checks ;;
            2)
                header
                printf '  The speed test downloads about 5 MB from Cloudflare.\n  Press 1 to continue or Q to cancel: '
                key
                if [[ "$KEY" == 1 ]]; then
                    curl -sS --connect-timeout 5 --max-time 25 -o /dev/null -w '  Downloaded %{size_download} bytes at %{speed_download} bytes per second.\n' 'https://speed.cloudflare.com/__down?bytes=5000000' || true
                    pause_key
                fi ;;
            3) header; traceroute -m 8 -q 1 -w 1 1.1.1.1 2>&1; pause_key ;;
            4) header; netstat -ibn | head -25; printf '\n  Counters include virtual interfaces and may overlap.\n'; pause_key ;;
            q|Q|$'\033') return ;;
        esac
    done
}

protocol_page() {
    local proto="$1" app="" detail=""
    case "$proto" in
        reality|ws|vray|http-obfs) app='Hiddify or another compatible VLESS app'; detail='Import the VLESS link from the server owner.' ;;
        wg) app='WireGuard'; detail='Import the .conf file from the server owner.' ;;
        hysteria) app='Hiddify or another Hysteria v2 app'; detail='Import the Hysteria link from the server owner.' ;;
        mtp) app='Telegram'; detail='Open the MTProto link in Telegram.' ;;
        ssh-tunnel) app='SSH and an app that supports a SOCKS proxy'; detail='Ask the server owner for the SSH login details.' ;;
        dnstt|slipstream|noizdns) app='The matching DNS tunnel client'; detail='Ask the owner for the domain, key, and client settings.' ;;
        sos) app='A compatible SOS client'; detail='Ask the owner for the relay address and room details.' ;;
        conduit|tor-bridge|snowflake) app='Psiphon or Tor Browser'; detail='This is a community relay, not a private Vany connection.' ;;
    esac
    while true; do
        header
        printf '  %s\n\n  1  Connect from this Mac\n  2  Create on a Linux server\n  C  Help me choose\n  Q  Return\n\n' "$proto"
        key
        case "$KEY" in
            1)
                header
                printf '  Connect with %s\n\n' "$proto"
                printf '  App: %s\n  %s\n\n' "$app" "$detail"
                printf '  1. Get the link or file through a private channel.\n'
                printf '  2. Install the matching app on your Mac.\n'
                printf '  3. Import the link or file in the app and connect.\n\n'
                printf '  Vany cannot connect this protocol on macOS automatically.\n'
                printf '  App and setup details: https://vany.sh/#docs/protocols/%s\n' "$proto"
                pause_key ;;
            2)
                header
                printf '  Vany creates services on an Ubuntu or Debian server.\n'
                printf '  Connect to that server with SSH. Then run:\n\n  curl vany.sh | sudo bash\n'
                printf '\n  Select %s, then choose Create.\n' "$proto"
                pause_key ;;
            c|C) choose_protocol; return ;;
            q|Q|$'\033') return ;;
        esac
    done
}

choose_protocol() {
    local file result selected
    file=$(mktemp "${TMPDIR:-/tmp}/vany-chooser.XXXXXX") || return
    result=$(mktemp "${TMPDIR:-/tmp}/vany-choice.XXXXXX") || { rm -f "$file"; return; }
    if curl -fsSL --connect-timeout 8 --max-time 20 "$BASE/scripts/tools/choose.sh" -o "$file"; then
        VANY_CHOICE_FILE="$result" VANY_STATUS_HEADER="$CLIENT_HEADER" bash "$file"
        if [[ -s "$result" ]]; then IFS= read -r selected < "$result"; protocol_page "$selected"; fi
    else
        printf 'Could not load the chooser.\n'; pause_key
    fi
    rm -f "$file" "$result"
}

protocols_menu() {
    local selected
    while true; do
        header
        printf '  Select a protocol. Press one letter.\n\n'
        printf '  R REALITY      W WebSocket     G WireGuard     Y Hysteria\n'
        printf '  V VLESS+TLS    O HTTP obfs     M MTProto       H SSH\n'
        printf '  D DNSTT        L Slipstream    N NoizDNS       S SOS chat\n'
        printf '  C Conduit      B Tor bridge    F Snowflake\n\n'
        printf '  Q Return\n\n'
        key
        selected=""
        case "$KEY" in
            r|R) selected=reality ;; w|W) selected=ws ;; g|G) selected=wg ;; y|Y) selected=hysteria ;;
            v|V) selected=vray ;; o|O) selected=http-obfs ;; m|M) selected=mtp ;; h|H) selected=ssh-tunnel ;;
            d|D) selected=dnstt ;; l|L) selected=slipstream ;; n|N) selected=noizdns ;; s|S) selected=sos ;;
            c|C) selected=conduit ;; b|B) selected=tor-bridge ;; f|F) selected=snowflake ;;
            q|Q|$'\033') return ;;
        esac
        [[ -n "$selected" ]] && protocol_page "$selected"
    done
}

while true; do
    header
    printf '  Welcome to Vany\n\n'
    printf '  Connect from this Mac or create a service on a Linux server.\n'
    printf '  1  Help me choose\n  2  Browse protocols\n  3  Status and network checks\n  Q  Quit\n\n'
    key
    case "$KEY" in
        1|c|C) choose_protocol ;;
        2) protocols_menu ;;
        3|s|S) status_menu ;;
        q|Q|$'\033') exit 0 ;;
    esac
done
