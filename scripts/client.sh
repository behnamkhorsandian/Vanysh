#!/bin/bash
# Client help and network tools. Server setup requires sudo.

if ! exec 3</dev/tty; then
    printf 'Open an interactive terminal to use this menu.\n' >&2
    exit 1
fi

run_tool() {
    local tool="$1" file result
    file=$(mktemp "${TMPDIR:-/tmp}/vany-tool.XXXXXX") || return 1
    if curl -fsSL --connect-timeout 10 --max-time 60 "https://vany.sh/tools/$tool" -o "$file"; then
        bash "$file"
        result=$?
    else
        printf 'Could not load the tool. Check your internet connection.\n'
        result=1
    fi
    rm -f "$file"
    return "$result"
}

while true; do
    printf '\n  VANY CLIENT\n\n'
    printf '  Connect with an app that supports your connection.\n'
    printf '  Ask your server owner for a connection link or file.\n'
    printf '  Keep that link or file private.\n\n'
    printf '  1  How to connect\n  2  Check your connection\n  3  Test connection speed\n  4  Find Cloudflare IPs\n  5  Find DNS resolvers\n  q  Quit\n\n'
    printf '  Choose an option: '
    IFS= read -r choice <&3 || exit 0
    case "$choice" in
        1)
            printf '\n  1. Install the app your server owner recommends.\n'
            printf '  2. Import the connection link or file into the app.\n'
            printf '  3. Connect in the app.\n'
            printf '  For WireGuard, use the WireGuard app and its configuration file.\n'
            printf '  For VLESS, an app such as Hiddify can import a link.\n'
            printf '  Vany does not connect your device from this menu.\n' ;;
        2) run_tool tracer ;;
        3) run_tool speedtest ;;
        4) run_tool cfray ;;
        5) run_tool findns ;;
        q|Q) exit 0 ;;
        *) printf '  Choose a number from the menu.\n' ;;
    esac
done
