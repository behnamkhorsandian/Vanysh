#!/bin/bash
# Faucet VPN Sync — Polls /faucet/active and syncs UUIDs into Xray WS inbound
# Run via cron: * * * * * /opt/vany/scripts/tools/faucet-sync.sh
# Or as a loop: while true; do /opt/vany/scripts/tools/faucet-sync.sh; sleep 30; done

XRAY_CONFIG="${XRAY_CONFIG:-/opt/vany/xray/config.json}"
INBOUND_TAG="ws-in"
FAUCET_URL="https://vany.sh/faucet/active"
LOCK_FILE="/tmp/faucet-sync.lock"

# Prevent concurrent runs
if [[ -f "$LOCK_FILE" ]]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Fetch active faucet UUIDs from Worker
RESPONSE=$(curl -sf --max-time 10 "$FAUCET_URL" 2>/dev/null)
if [[ -z "$RESPONSE" ]]; then
    exit 0
fi

# Parse UUIDs array
ACTIVE_UUIDS=$(echo "$RESPONSE" | jq -r '.uuids[]' 2>/dev/null)
ACTIVE_COUNT=$(echo "$RESPONSE" | jq -r '.count' 2>/dev/null)

if [[ ! -f "$XRAY_CONFIG" ]]; then
    exit 1
fi

# Get current faucet clients from Xray config (email contains @faucet)
CURRENT_UUIDS=$(jq -r --arg tag "$INBOUND_TAG" \
    '(.inbounds[] | select(.tag == $tag) | .settings.clients[] | select(.email | endswith("@faucet"))) | .id' \
    "$XRAY_CONFIG" 2>/dev/null)

CHANGED=0

# Add new faucet UUIDs
for uuid in $ACTIVE_UUIDS; do
    if ! echo "$CURRENT_UUIDS" | grep -qF "$uuid"; then
        jq --arg tag "$INBOUND_TAG" \
           --arg uuid "$uuid" \
           --arg email "${uuid}@faucet" \
           '(.inbounds[] | select(.tag == $tag) | .settings.clients) += [{"id": $uuid, "email": $email}]' \
           "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp" && mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"
        CHANGED=1
    fi
done

# Remove expired faucet UUIDs (in config but not in active list)
for uuid in $CURRENT_UUIDS; do
    if ! echo "$ACTIVE_UUIDS" | grep -qF "$uuid"; then
        jq --arg tag "$INBOUND_TAG" \
           --arg uuid "$uuid" \
           '(.inbounds[] | select(.tag == $tag) | .settings.clients) |= [.[] | select(.id != $uuid)]' \
           "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp" && mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"
        CHANGED=1
    fi
done

# Reload Xray if config changed
if [[ "$CHANGED" -eq 1 ]]; then
    docker exec vany-xray kill -HUP 1 2>/dev/null || true
fi
