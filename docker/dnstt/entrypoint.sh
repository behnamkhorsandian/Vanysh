#!/bin/sh
set -e

KEY_DIR="/etc/dnstt"
PRIVKEY="$KEY_DIR/server.key"
PUBKEY="$KEY_DIR/server.pub"

# Generate keys if missing
if [ ! -f "$PRIVKEY" ]; then
    echo "[entrypoint] Generating DNSTT keypair..."
    dnstt-server -gen-key -privkey-file "$PRIVKEY" -pubkey-file "$PUBKEY"
    echo "[entrypoint] Public key: $(cat "$PUBKEY")"
fi

DOMAIN="${DNSTT_DOMAIN:-t.example.com}"
FORWARD="${DNSTT_FORWARD:-127.0.0.1:10800}"

echo "[entrypoint] Starting dnstt-server"
echo "  Domain: $DOMAIN"
echo "  Forward: $FORWARD"
echo "  Pubkey: $(cat "$PUBKEY")"

exec dnstt-server -udp 0.0.0.0:5300 -privkey-file "$PRIVKEY" "$DOMAIN" "$FORWARD"
