FROM python:3.11-slim

LABEL org.opencontainers.image.source="https://github.com/behnamkhorsandian/Vanysh"
LABEL org.opencontainers.image.description="Vany SOS relay daemon"

RUN pip install --no-cache-dir aiohttp pynacl

COPY relay.py /app/relay.py

WORKDIR /app

VOLUME ["/etc/sos"]

EXPOSE 8899/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8899/')" || exit 1

CMD ["python", "relay.py", "--host", "0.0.0.0", "--port", "8899", "--data-dir", "/etc/sos"]
