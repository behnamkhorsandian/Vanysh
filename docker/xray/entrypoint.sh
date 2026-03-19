#!/bin/sh
set -e

CONFIG="/etc/xray/config.json"

# Initialize empty config if missing
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "api": {
    "tag": "api",
    "services": ["StatsService"]
  },
  "stats": {},
  "inbounds": [
    {
      "tag": "api-in",
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block", "protocol": "blackhole" }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "inboundTag": ["api-in"], "outboundTag": "api", "type": "field" }
    ]
  }
}
EOF
    echo "[entrypoint] Created default config at $CONFIG"
fi

exec "$@"
