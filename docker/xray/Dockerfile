FROM alpine:3.19 AS builder

ARG XRAY_VERSION=1.8.24

RUN apk add --no-cache curl unzip && \
    ARCH=$(case "$(uname -m)" in x86_64) echo 64;; aarch64) echo arm64-v8a;; *) echo 64;; esac) && \
    curl -sL "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${ARCH}.zip" -o /tmp/xray.zip && \
    unzip -q /tmp/xray.zip -d /tmp/xray && \
    chmod +x /tmp/xray/xray

FROM alpine:3.19

LABEL org.opencontainers.image.source="https://github.com/behnamkhorsandian/Vanysh"
LABEL org.opencontainers.image.description="Vany Xray container (Reality + WS + VRAY)"

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /tmp/xray/xray /usr/local/bin/xray
COPY --from=builder /tmp/xray/geoip.dat /usr/local/share/xray/geoip.dat
COPY --from=builder /tmp/xray/geosite.dat /usr/local/share/xray/geosite.dat

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/etc/xray"]

EXPOSE 443/tcp 80/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD xray api statsquery --server=127.0.0.1:10085 2>/dev/null || \
        nc -z 127.0.0.1 443 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["xray", "run", "-config", "/etc/xray/config.json"]
