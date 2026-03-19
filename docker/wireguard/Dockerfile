FROM linuxserver/wireguard:latest

LABEL org.opencontainers.image.source="https://github.com/behnamkhorsandian/Vanysh"
LABEL org.opencontainers.image.description="Vany WireGuard container"

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wg show wg0 2>/dev/null | grep -q "interface" || exit 1
