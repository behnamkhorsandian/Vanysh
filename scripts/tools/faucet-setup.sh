#!/bin/bash
# Faucet VPN Setup — One-time setup on VPS to enable faucet VPN rewards.
#
# This script:
#   1. Generates a shared UUID for faucet users
#   2. Adds it to Xray's WS inbound as a client
#   3. Prints the wrangler command to set the KV config
#
# Usage: bash scripts/tools/faucet-setup.sh
#   Then run the printed wrangler command on your local machine.

set -e

XRAY_CONFIG="${XRAY_CONFIG:-/opt/vany/xray/config.json}"
INBOUND_TAG="ws-in"
FAUCET_EMAIL="faucet@vany"

GREEN="\033[38;5;35m"
LGREEN="\033[38;5;114m"
DIM="\033[2m"
BOLD="\033[1m"
RST="\033[0m"
RED="\033[38;5;167m"
YELLOW="\033[38;5;185m"

echo ""
echo -e "  ${GREEN}${BOLD}FAUCET VPN SETUP${RST}"
echo -e "  ${DIM}One-time setup to enable VPN rewards for faucet relay nodes${RST}"
echo ""

# Check Xray config exists
if [[ ! -f "$XRAY_CONFIG" ]]; then
    echo -e "  ${RED}Xray config not found at $XRAY_CONFIG${RST}"
    echo -e "  ${DIM}Install Xray first: curl vany.sh/ws | sudo bash${RST}"
    exit 1
fi

# Check if faucet client already exists
EXISTING=$(jq -r --arg tag "$INBOUND_TAG" \
    '(.inbounds[] | select(.tag == $tag) | .settings.clients[] | select(.email == "faucet@vany")) | .id' \
    "$XRAY_CONFIG" 2>/dev/null || true)

if [[ -n "$EXISTING" ]]; then
    echo -e "  ${YELLOW}Faucet UUID already exists:${RST} ${LGREEN}$EXISTING${RST}"
    UUID="$EXISTING"
else
    # Generate a new UUID
    if command -v uuidgen &>/dev/null; then
        UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())')
    fi

    echo -e "  ${DIM}Generated UUID:${RST} ${LGREEN}$UUID${RST}"

    # Add to Xray WS inbound
    jq --arg tag "$INBOUND_TAG" \
       --arg uuid "$UUID" \
       --arg email "$FAUCET_EMAIL" \
       '(.inbounds[] | select(.tag == $tag) | .settings.clients) += [{"id": $uuid, "email": $email}]' \
       "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp" && mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"

    echo -e "  ${GREEN}Added to Xray WS inbound${RST}"

    # Reload Xray
    docker exec vany-xray kill -HUP 1 2>/dev/null && echo -e "  ${GREEN}Xray reloaded${RST}" || echo -e "  ${YELLOW}Could not reload Xray (restart manually)${RST}"
fi

# Detect domain and path from Xray config
WS_PATH=$(jq -r --arg tag "$INBOUND_TAG" \
    '.inbounds[] | select(.tag == $tag) | .streamSettings.wsSettings.path // "/ws"' \
    "$XRAY_CONFIG" 2>/dev/null || echo "/ws")

# Default domain
DOMAIN="${FAUCET_DOMAIN:-ws-origin.vany.sh}"

echo ""
echo -e "  ${GREEN}${BOLD}SETUP COMPLETE${RST}"
echo ""
echo -e "  ${DIM}Now run this command on your local machine (where wrangler is installed):${RST}"
echo ""
echo -e "  ${LGREEN}npx wrangler kv:key put --namespace-id=4f5c4f3d5e784fe99fefec2ce5007ce8 \\${RST}"
echo -e "  ${LGREEN}  \"faucet:config\" '{\"domain\":\"${DOMAIN}\",\"path\":\"${WS_PATH}\",\"uuid\":\"${UUID}\"}'${RST}"
echo ""
echo -e "  ${DIM}This tells the Worker to use this UUID for all faucet VPN links.${RST}"
echo -e "  ${DIM}Since the UUID is already in Xray, connections will work instantly.${RST}"
echo ""
