# Stage 1: Build dnstt-server from source
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git && \
    git clone https://www.bamsoftware.com/git/dnstt.git /build/dnstt && \
    cd /build/dnstt/dnstt-server && \
    go build -ldflags="-s -w" -o /build/dnstt-server .

# Stage 2: Minimal runtime
FROM alpine:3.19

LABEL org.opencontainers.image.source="https://github.com/behnamkhorsandian/Vanysh"
LABEL org.opencontainers.image.description="Vany DNSTT server container"

RUN apk add --no-cache ca-certificates

COPY --from=builder /build/dnstt-server /usr/local/bin/dnstt-server
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/etc/dnstt"]

# DNS listener
EXPOSE 5300/udp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD pgrep dnstt-server >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
