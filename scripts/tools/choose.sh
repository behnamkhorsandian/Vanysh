#!/bin/bash
# Choose a protocol. Each answer is one key and Q returns to Vany.
exec 3</dev/tty 2>/dev/null || { echo "Open an interactive terminal to use the chooser."; exit 1; }

ask() {
    local valid="$1" key
    while true; do
        printf '\n  Choose a number or Q to return: '
        IFS= read -rsn1 key <&3 || exit 0
        printf '\n'
        case "$key" in q|Q|$'\033') exit 0 ;; esac
        case "$valid" in *"$key"*) [[ -n "$key" ]] && { ANSWER="$key"; return; } ;; esac
        printf '  Please choose one of the listed numbers.\n'
    done
}

show_question() {
    clear 2>/dev/null || true
    [[ -n "${VANY_STATUS_HEADER:-}" ]] && printf '\n  %s\n' "$VANY_STATUS_HEADER"
    printf '  UTC %s | Local %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S')" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf '\n  VANY | Help me choose\n\n  %s\n\n' "$1"
}

check_network() {
    local host wait=2
    [[ "$(uname -s)" == Darwin ]] && wait=2000
    printf '\n  These checks contact Cloudflare and Google.\n'
    printf '  They may use mobile data and do not prove censorship.\n'
    printf '  Press Q to cancel between checks.\n\n'
    for host in 1.1.1.1 8.8.8.8; do
        printf '  Ping %s\n' "$host"
        if command -v ping >/dev/null 2>&1; then ping -c 2 -W "$wait" "$host" 2>&1 | tail -3; else printf '  Ping is unavailable.\n'; fi
        if command -v dig >/dev/null 2>&1; then
            printf '  DNS answer from %s: ' "$host"
            dig +short +time=2 +tries=1 "@$host" example.com A 2>/dev/null | head -1
        else
            printf '  DNS check unavailable. Install dig to check this resolver.\n'
        fi
        local cancel=""
        if IFS= read -rsn1 -t 0.1 cancel <&3; then
            case "$cancel" in q|Q|$'\033') exit 0 ;; esac
        fi
    done
    for host in https://www.cloudflare.com https://www.google.com; do
        printf '\n  HTTPS %s\n' "$host"
        curl -sS -o /dev/null --connect-timeout 3 --max-time 6 -w '  HTTP %{http_code}, %{time_total} seconds\n' "$host" 2>&1 || true
        local cancel=""
        if IFS= read -rsn1 -t 0.1 cancel <&3; then
            case "$cancel" in q|Q|$'\033') exit 0 ;; esac
        fi
    done
    printf '\n  A failure can have many causes. Ask the server owner which protocol works.\n'
    printf '  Press any key to continue, or Q to return. '
    local key
    IFS= read -rsn1 key <&3 || exit 0
    case "$key" in q|Q|$'\033') exit 0 ;; esac
}

show_question 'What do you want to do?'
printf '  1  Connect to a proxy or VPN\n  2  Create a service on my server\n'
ask 12
ROLE="$ANSWER"

if [[ "$ROLE" == 1 ]]; then
    show_question 'What did the server owner give you?'
    printf '  1  A VLESS link\n  2  A WireGuard configuration file\n  3  A Hysteria v2 link\n  4  I am not sure\n'
    ask 1234
    case "$ANSWER" in
        1) PROTO=reality; REASON='VLESS links can use different transports. Ask the owner which one.' ;;
        2) PROTO=wg; REASON='A WireGuard file normally ends in .conf.' ;;
        3) PROTO=hysteria; REASON='Use a client that supports Hysteria v2.' ;;
        4)
            show_question 'Would you like to check this network?'
            printf '  1  Check public endpoints\n  2  Skip the check\n'
            ask 12
            [[ "$ANSWER" == 1 ]] && check_network
            PROTO=reality
            REASON='Ask the server owner for the protocol and a private link or file. Network checks cannot identify the correct protocol.' ;;
    esac
else
    show_question 'What do you want to provide?'
    printf '  1  A connection for friends and family\n  2  A volunteer relay for other people\n  3  An emergency fallback\n'
    ask 123
    PURPOSE="$ANSWER"
    if [[ "$PURPOSE" == 2 ]]; then
        PROTO=conduit; REASON='Conduit is a volunteer Psiphon relay, not a private family VPN.'
    elif [[ "$PURPOSE" == 3 ]]; then
        show_question 'Do you control a domain name?'
        printf '  1  Yes\n  2  No\n  3  I am not sure\n'
        ask 123
        if [[ "$ANSWER" == 1 ]]; then
            PROTO=dnstt; REASON='DNSTT needs DNS delegation, a compatible client, and a separate upstream service. It can be slow.'
        else
            PROTO=reality; REASON='REALITY does not need a domain. A DNS tunnel needs one and cannot be guaranteed to work.'
        fi
    else
        show_question 'What is most important for your connection?'
        printf '  1  A simple setup without a domain\n  2  A VPN with a WireGuard app\n  3  I am not sure or want to check the network\n'
        ask 123
        case "$ANSWER" in
            1) PROTO=reality; REASON='REALITY does not require a domain. Test it on the network where it will be used.' ;;
            2) PROTO=wg; REASON='WireGuard uses UDP and may be blocked on some networks.' ;;
            3)
                show_question 'Would you like to check this network?'
                printf '  1  Check public endpoints\n  2  Skip the check\n'
                ask 12
                [[ "$ANSWER" == 1 ]] && check_network
                PROTO=reality; REASON='REALITY is a starting point without a domain. The checks cannot predict whether it will work.' ;;
        esac
    fi
fi

show_question 'A starting point'
printf '  %s\n\n  %s\n\n' "$PROTO" "$REASON"
printf '  1  Open this protocol in Vany\n  Q  Return without selecting\n'
ask 1
if [[ -n "${VANY_CHOICE_FILE:-}" ]]; then
    printf '%s\n' "$PROTO" > "$VANY_CHOICE_FILE"
else
    printf '\n  Open Vany and select %s.\n  curl vany.sh | sudo bash\n' "$PROTO"
fi
