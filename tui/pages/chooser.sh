#!/bin/bash
# The protocol chooser uses the same frame and controls as the other pages.

chooser_network_checks() {
    local host result key
    tui_scroll_reset
    FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Network check${C_RST}" ""
        "These checks contact Cloudflare and Google."
        "Press Q between checks to cancel. A failure has many causes." "")
    FRAME_FOOTER="Q: cancel"
    tui_render_frame

    for host in 1.1.1.1 8.8.8.8; do
        FRAME_CONTENT+=("Ping $host")
        if command -v ping >/dev/null 2>&1; then
            result=$(ping -c 2 -W 2 "$host" 2>&1 | tail -2)
            while IFS= read -r line; do FRAME_CONTENT+=("  $line"); done <<< "$result"
        else
            FRAME_CONTENT+=("  Ping is not installed.")
        fi
        if command -v dig >/dev/null 2>&1; then
            result=$(dig +short +time=2 +tries=1 "@$host" example.com A 2>/dev/null | head -1)
            FRAME_CONTENT+=("  DNS answer: ${result:-no answer}")
        else
            FRAME_CONTENT+=("  DNS check unavailable. Install dig to use it.")
        fi
        FRAME_CONTENT+=("")
        tui_render_frame
        key=$(tui_read_key 0.1)
        case "$key" in q|Q|ESC|EOF) return 1 ;; esac
    done

    for host in https://www.cloudflare.com https://www.google.com; do
        result=$(curl -sS -o /dev/null --connect-timeout 3 --max-time 6 \
            -w 'HTTP %{http_code}, %{time_total} seconds' "$host" 2>&1) || true
        FRAME_CONTENT+=("HTTPS $host" "  ${result:-unavailable}" "")
        tui_render_frame
        key=$(tui_read_key 0.1)
        case "$key" in q|Q|ESC|EOF) return 1 ;; esac
    done

    FRAME_CONTENT+=("These results do not prove censorship."
        "Ask the server owner which protocol works." ""
        "1  Continue    Q  Return to the chooser")
    FRAME_FOOTER="1: continue  PgDn: more  Q: back"
    tui_render_frame
    while true; do
        tui_wait_key
        case "$TUI_KEY" in
            1|ENTER) return 0 ;;
            q|Q|ESC|BACKSPACE) return 1 ;;
            PGUP) tui_scroll_page_up; tui_render_frame ;;
            PGDN) tui_scroll_page_down; tui_render_frame ;;
        esac
    done
}

page_chooser() {
    local step=role role="" purpose="" proto="" reason="" key
    _SIDEBAR_PAGE="choose"
    _SIDEBAR_DIM=0
    FRAME_BANNER=""
    tui_scroll_reset

    while true; do
        tui_get_size
        tui_compute_layout
        FRAME_CONTENT=("${C_ORANGE}${C_BOLD}Help me choose${C_RST}" "")
        case "$step" in
            role)
                FRAME_CONTENT+=("What do you want to do?" ""
                    "1  Connect to a proxy or VPN"
                    "2  Create a service on my server") ;;
            client)
                FRAME_CONTENT+=("What did the server owner give you?" ""
                    "1  A VLESS link"
                    "2  A WireGuard configuration file"
                    "3  A Hysteria v2 link"
                    "4  I am not sure") ;;
            purpose)
                FRAME_CONTENT+=("What do you want to provide?" ""
                    "1  A connection for friends and family"
                    "2  A volunteer relay for other people"
                    "3  An emergency fallback") ;;
            domain)
                FRAME_CONTENT+=("Do you control a domain name?" ""
                    "1  Yes"
                    "2  No"
                    "3  I am not sure") ;;
            priority)
                FRAME_CONTENT+=("What matters most for your connection?" ""
                    "1  A simple setup without a domain"
                    "2  A VPN with a WireGuard app"
                    "3  I am not sure") ;;
            probe)
                FRAME_CONTENT+=("Would you like to check this network?" ""
                    "1  Check public endpoints"
                    "2  Skip the check" ""
                    "The checks contact Cloudflare and Google."
                    "They cannot determine which protocol will work.") ;;
            result)
                FRAME_CONTENT+=("A starting point: ${PROTOCOL_SHORT[$proto]:-$proto}" ""
                    "$reason" ""
                    "1  Open this protocol"
                    "B  Answer the questions again") ;;
        esac
        FRAME_CONTENT+=("" "Press a number to choose. Press Q to return.")
        FRAME_FOOTER="Number: choose  B: back  Q: return"
        tui_render_frame
        tui_wait_key
        key="$TUI_KEY"

        case "$key" in
            q|Q|ESC) return 1 ;;
            PGUP) tui_scroll_page_up; continue ;;
            PGDN) tui_scroll_page_down; continue ;;
            b|B|BACKSPACE)
                case "$step" in
                    role) return 1 ;;
                    client|purpose|result) step=role ;;
                    domain|priority) step=purpose ;;
                    probe) if [[ "$role" == connect ]]; then step=client; else step=priority; fi ;;
                esac
                tui_scroll_reset
                continue ;;
        esac

        case "$step:$key" in
            role:1) role=connect; step=client ;;
            role:2) role=create; step=purpose ;;
            client:1) proto=reality; reason='VLESS links can use different transports. Ask the owner which one.'; step=result ;;
            client:2) proto=wg; reason='A WireGuard file normally ends in .conf.'; step=result ;;
            client:3) proto=hysteria; reason='Use a client that supports Hysteria v2.'; step=result ;;
            client:4) proto=reality; reason='Ask the owner for the protocol and a private link or file.'; step=probe ;;
            purpose:1) purpose=personal; step=priority ;;
            purpose:2) proto=conduit; reason='Conduit is a volunteer Psiphon relay, not a private family VPN.'; step=result ;;
            purpose:3) purpose=emergency; step=domain ;;
            domain:1) proto=dnstt; reason='DNSTT needs DNS delegation, a compatible client, and a separate upstream service. It can be slow.'; step=result ;;
            domain:2|domain:3) proto=reality; reason='REALITY does not need a domain. A DNS tunnel needs one and cannot be guaranteed to work.'; step=result ;;
            priority:1) proto=reality; reason='REALITY does not require a domain. Test it on the network where it will be used.'; step=result ;;
            priority:2) proto=wg; reason='WireGuard uses UDP and may be blocked on some networks.'; step=result ;;
            priority:3) proto=reality; reason='REALITY is a starting point without a domain. The checks cannot predict whether it will work.'; step=probe ;;
            probe:1)
                if chooser_network_checks; then step=result; else step=probe; fi ;;
            probe:2) step=result ;;
            result:1|result:ENTER) START_PROTOCOL="$proto"; return 0 ;;
        esac
        tui_scroll_reset
    done
}
