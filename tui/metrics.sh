#!/bin/bash
# Cached machine metrics for the Linux terminal. Public IP location is approximate.

_METRIC_AT=0
_METRIC_PREV_TOTAL=0
_METRIC_PREV_IDLE=0
_METRIC_PREV_RX=0
_METRIC_PREV_TX=0
_METRIC_PREV_NET_AT=0
_METRIC_GEO_CHECKED=0
_METRIC_CPU="?"
_METRIC_RAM="?"
_METRIC_NET="?"
_METRIC_IP="${VANY_PUBLIC_IP:-?}"
_METRIC_LOCATION="${VANY_LOCATION:-unknown}"
[[ -n "${VANY_PUBLIC_IP:-}" ]] && _METRIC_GEO_CHECKED=1
_STATUS_ROWS=()

_refresh_machine_metrics() {
    local now total idle diff idle_diff cpu user nice system idle_base iowait irq softirq steal
    now=$(date +%s)
    if (( now - _METRIC_AT >= 5 )); then
        _METRIC_AT=$now
        if [[ -r /proc/stat ]]; then
            read -r cpu user nice system idle_base iowait irq softirq steal _ < /proc/stat
            total=$((user + nice + system + idle_base + iowait + irq + softirq + steal))
            idle=$((idle_base + iowait))
            diff=$((total - _METRIC_PREV_TOTAL)); idle_diff=$((idle - _METRIC_PREV_IDLE))
            if (( _METRIC_PREV_TOTAL > 0 && diff > 0 )); then
                _METRIC_CPU="$((100 * (diff - idle_diff) / diff))%"
            fi
            _METRIC_PREV_TOTAL=$total; _METRIC_PREV_IDLE=$idle
        fi
        if [[ -r /proc/meminfo ]]; then
            _METRIC_RAM=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {if (t && a) printf "%.0f/%.0f MiB", (t-a)/1024, t/1024; else printf "?"}' /proc/meminfo)
        fi
        if [[ -r /proc/net/dev ]]; then
            local iface values rx tx a b c d e f g elapsed sum_rx=0 sum_tx=0
            while IFS=: read -r iface values; do
                iface=${iface//[[:space:]]/}
                [[ "$iface" == lo || -z "$values" ]] && continue
                read -r rx a b c d e f g tx _ <<< "$values"
                [[ "$rx" =~ ^[0-9]+$ && "$tx" =~ ^[0-9]+$ ]] || continue
                sum_rx=$((sum_rx + rx)); sum_tx=$((sum_tx + tx))
            done < /proc/net/dev
            elapsed=$((now - _METRIC_PREV_NET_AT))
            if (( _METRIC_PREV_NET_AT > 0 && elapsed > 0 && sum_rx >= _METRIC_PREV_RX && sum_tx >= _METRIC_PREV_TX )); then
                _METRIC_NET="$(((sum_rx - _METRIC_PREV_RX) / elapsed / 1024))/$(((sum_tx - _METRIC_PREV_TX) / elapsed / 1024)) KiB/s"
            fi
            _METRIC_PREV_RX=$sum_rx; _METRIC_PREV_TX=$sum_tx; _METRIC_PREV_NET_AT=$now
        fi
    fi
    # One request per session. This reports the public IP seen by ipinfo.io.
    if (( !_METRIC_GEO_CHECKED )); then
        _METRIC_GEO_CHECKED=1
        if command -v jq >/dev/null 2>&1; then
            local geo ip location
            geo=$(curl -fsS --connect-timeout 2 --max-time 3 https://ipinfo.io/json 2>/dev/null) || geo=""
            if [[ -n "$geo" ]]; then
                ip=$(jq -r '.ip // empty' <<< "$geo" 2>/dev/null | tr -cd '0-9a-fA-F:.')
                location=$(jq -r '[.city, .country] | map(select(. != null and . != "")) | join(", ")' <<< "$geo" 2>/dev/null | tr -cd '[:alnum:] ,.-')
                [[ -n "$ip" ]] && _METRIC_IP="$ip"
                [[ -n "$location" ]] && _METRIC_LOCATION="${location:0:28}"
            fi
        fi
    fi
    return 0
}

_status_add_segment() {
    local segment="$1" limit=$(( _FRAME_W - 4 ))
    (( limit < 1 )) && limit=1
    segment="${segment:0:$limit}"
    if [[ -z "$_STATUS_LINE" ]]; then
        _STATUS_LINE="$segment"
    elif (( ${#_STATUS_LINE} + ${#segment} + 3 <= limit )); then
        _STATUS_LINE+=" | $segment"
    else
        _STATUS_ROWS+=("$_STATUS_LINE")
        _STATUS_LINE="$segment"
    fi
}

_build_status_rows() {
    local _STATUS_LINE=""
    _STATUS_ROWS=()
    _status_add_segment "VANY"
    _status_add_segment "CPU $_METRIC_CPU"
    _status_add_segment "RAM $_METRIC_RAM"
    _status_add_segment "Net down/up $_METRIC_NET"
    _status_add_segment "Public IP $_METRIC_IP"
    _status_add_segment "Location ~$_METRIC_LOCATION"
    _status_add_segment "UTC $(date -u '+%Y-%m-%d %H:%M:%S')"
    _status_add_segment "Local $(date '+%Y-%m-%d %H:%M:%S %Z')"
    [[ -n "$_STATUS_LINE" ]] && _STATUS_ROWS+=("$_STATUS_LINE")
}
