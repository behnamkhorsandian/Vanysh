#!/bin/bash
# Commands run by the interactive terminal pane.
set -u
case "${1:-}" in
    manager)
        manager="${2:-}"
        if [[ -z "$manager" ]]; then
            manager=$(mktemp "${TMPDIR:-/tmp}/vany-manager.XXXXXX") || exit 1
            trap 'rm -f "$manager"' EXIT
            if ! curl -fsSL --connect-timeout 10 --max-time 60 "$GITHUB_RAW/scripts/direct-install.sh" -o "$manager"; then
                printf 'Could not load the protocol manager. Check your connection.\n'
                exit 1
            fi
        fi
        bash "$manager"
        ;;
    network)
        printf 'Checking public endpoints at Cloudflare and Google.\n'
        for host in 1.1.1.1 8.8.8.8; do
            printf '\nPing %s\n' "$host"
            if command -v ping >/dev/null 2>&1; then ping -c 2 -W 2 "$host" 2>&1 | tail -3; else printf 'Ping is not installed.\n'; fi
            if command -v dig >/dev/null 2>&1; then
                printf 'DNS answer: '
                dig +short +time=2 +tries=1 "@$host" example.com A 2>/dev/null | head -1
            else printf 'Install dig to check DNS.\n'; fi
        done
        for host in https://www.cloudflare.com https://www.google.com; do
            printf '\nHTTPS %s\n' "$host"
            curl -sS -o /dev/null --connect-timeout 3 --max-time 6 -w 'HTTP %{http_code}, %{time_total} seconds\n' "$host" 2>&1 || true
        done
        printf '\nA failure can have many causes. These checks do not prove censorship.\n'
        ;;
    speed)
        printf 'The speed test downloads data from Cloudflare.\n'
        file="${2:-}"
        if [[ ! -f "$file" ]]; then
            file=$(mktemp "${TMPDIR:-/tmp}/vany-tool.XXXXXX") || exit 1
            trap 'rm -f "$file"' EXIT
            curl -fsSL --connect-timeout 5 --max-time 20 "$GITHUB_RAW/scripts/tools/speedtest.sh" -o "$file" || exit 1
        fi
        bash "$file"
        ;;
    trace)
        printf 'Tracing the route to Cloudflare 1.1.1.1. A missing hop does not always mean a fault.\n\n'
        if command -v traceroute >/dev/null 2>&1; then
            traceroute -m 8 -q 1 -w 1 1.1.1.1
        elif command -v tracepath >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
            timeout 15 tracepath -m 8 1.1.1.1
        else printf 'Install traceroute or tracepath to use this check.\n'; exit 1; fi
        ;;
    containers)
        printf 'Docker resource usage for running containers\n\n'
        if ! command -v docker >/dev/null 2>&1; then printf 'Docker is not installed.\n'; exit 1; fi
        if ! command -v timeout >/dev/null 2>&1; then printf 'Install timeout to run this check.\n'; exit 1; fi
        timeout 15 docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'
        printf '\nThese totals do not show per-user usage.\n'
        ;;
    ssh)
        target="$2"
        log=$(mktemp "${TMPDIR:-/tmp}/vany-ssh.XXXXXX") || exit 1
        ssh_pid=""
        cleanup() { [[ -n "$ssh_pid" ]] && kill "$ssh_pid" 2>/dev/null || true; rm -f "$log"; }
        trap cleanup EXIT
        trap 'exit 130' INT TERM
        if [[ -n "${SUDO_USER:-}" ]] && command -v runuser >/dev/null 2>&1; then
            runuser -u "$SUDO_USER" -- ssh -o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -N -D 127.0.0.1:1080 "$target" >"$log" 2>&1 &
        else
            ssh -o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -N -D 127.0.0.1:1080 "$target" >"$log" 2>&1 &
        fi
        ssh_pid=$!
        ready=0
        for (( attempt=0; attempt<10; attempt++ )); do
            kill -0 "$ssh_pid" 2>/dev/null || break
            if ss -lnt 2>/dev/null | awk 'NR > 1 && $4 ~ /:1080$/ {found=1} END {exit !found}'; then ready=1; break; fi
            sleep 1
        done
        if (( !ready )); then printf 'Could not start the SSH proxy.\n'; cat "$log"; exit 1; fi
        printf 'SSH proxy is running at 127.0.0.1:1080.\nConfigure your app to use this SOCKS proxy.\nReturn to the status screen and stop this action to close it.\n'
        while kill -0 "$ssh_pid" 2>/dev/null; do
            sleep 2
        done
        printf 'The SSH proxy stopped.\n'; cat "$log"; exit 1
        ;;
    *) printf 'Unknown command.\n'; exit 2 ;;
esac
