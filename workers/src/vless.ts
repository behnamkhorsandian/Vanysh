/**
 * VLESS-over-WebSocket proxy for Cloudflare Workers.
 *
 * Eliminates the need for a VPS running Xray. The Worker itself terminates
 * VLESS protocol over WebSocket and proxies TCP traffic via the Workers
 * TCP Sockets API (connect()).
 *
 * Flow:
 *  1. VLESS client connects via WebSocket to /vless
 *  2. First binary frame contains VLESS header (version, UUID, command, target)
 *  3. Worker validates UUID against KV (faucet:client:<uuid>)
 *  4. Worker opens TCP connection to the target via connect()
 *  5. Bidirectional pipe: WebSocket ↔ TCP
 *  6. When faucet session expires, KV TTL removes UUID → next connection refused
 */

import { connect } from 'cloudflare:sockets';

interface Env {
  SAFEBOX: KVNamespace;
}

/** Convert 16 raw UUID bytes to standard string format */
function bytesToUuid(bytes: Uint8Array): string {
  const hex = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

/** Parse VLESS header from the first WebSocket binary frame */
function parseVlessHeader(buf: ArrayBuffer): {
  uuid: string;
  version: number;
  command: number;
  port: number;
  hostname: string;
  payload: Uint8Array;
} | null {
  const view = new DataView(buf);
  const bytes = new Uint8Array(buf);
  let offset = 0;

  if (buf.byteLength < 24) return null; // Too short

  // Version (1 byte)
  const version = view.getUint8(offset++);

  // UUID (16 bytes)
  const uuid = bytesToUuid(bytes.subarray(offset, offset + 16));
  offset += 16;

  // Addon length + skip addon data
  const addonLen = view.getUint8(offset++);
  offset += addonLen;

  // Command: 1 = TCP, 2 = UDP
  const command = view.getUint8(offset++);

  // Port (2 bytes, big-endian)
  const port = view.getUint16(offset);
  offset += 2;

  // Address type
  const addrType = view.getUint8(offset++);
  let hostname: string;

  switch (addrType) {
    case 1: { // IPv4
      if (buf.byteLength < offset + 4) return null;
      hostname = `${view.getUint8(offset++)}.${view.getUint8(offset++)}.${view.getUint8(offset++)}.${view.getUint8(offset++)}`;
      break;
    }
    case 2: { // Domain
      const len = view.getUint8(offset++);
      if (buf.byteLength < offset + len) return null;
      hostname = new TextDecoder().decode(bytes.subarray(offset, offset + len));
      offset += len;
      break;
    }
    case 3: { // IPv6
      if (buf.byteLength < offset + 16) return null;
      const parts: string[] = [];
      for (let i = 0; i < 8; i++) {
        parts.push(view.getUint16(offset).toString(16));
        offset += 2;
      }
      hostname = `[${parts.join(':')}]`;
      break;
    }
    default:
      return null;
  }

  const payload = bytes.subarray(offset);
  return { uuid, version, command, port, hostname, payload };
}

export async function handleVless(request: Request, env: Env): Promise<Response> {
  const upgrade = request.headers.get('Upgrade');
  if (!upgrade || upgrade.toLowerCase() !== 'websocket') {
    return new Response('Expected WebSocket', { status: 426 });
  }

  const pair = new WebSocketPair();
  const [client, server] = Object.values(pair);
  (server as WebSocket).accept();

  let tcpWriter: WritableStreamDefaultWriter<Uint8Array> | null = null;
  let headerProcessed = false;
  const pending: ArrayBuffer[] = [];

  (server as WebSocket).addEventListener('message', (event: MessageEvent) => {
    const data = event.data;
    if (typeof data === 'string') return; // VLESS is binary only
    const buf = data as ArrayBuffer;

    if (!headerProcessed) {
      headerProcessed = true;

      const header = parseVlessHeader(buf);
      if (!header) {
        (server as WebSocket).close(1008, 'Bad header');
        return;
      }

      // Only TCP supported (command 1)
      if (header.command !== 1) {
        (server as WebSocket).close(1008, 'TCP only');
        return;
      }

      // Validate UUID, connect, and pipe — all async
      (async () => {
        try {
          // Check UUID in KV
          const valid = await env.SAFEBOX.get(`faucet:client:${header.uuid}`);
          if (!valid) {
            (server as WebSocket).close(1008, 'Unauthorized');
            return;
          }

          // Send VLESS response header: [version, 0 (no addon)]
          (server as WebSocket).send(new Uint8Array([header.version, 0]));

          // Connect to target
          const socket = connect({ hostname: header.hostname, port: header.port });
          const writer = socket.writable.getWriter();
          tcpWriter = writer;

          // Send initial payload (data after VLESS header)
          if (header.payload.byteLength > 0) {
            await writer.write(header.payload);
          }

          // Flush any messages that arrived while we were validating
          for (const p of pending) {
            await writer.write(new Uint8Array(p));
          }
          pending.length = 0;

          // Pipe: TCP readable → WebSocket
          const reader = socket.readable.getReader();
          try {
            while (true) {
              const { done, value } = await reader.read();
              if (done) break;
              (server as WebSocket).send(value);
            }
          } catch { /* connection closed */ }
          (server as WebSocket).close(1000);
        } catch {
          (server as WebSocket).close(1011, 'Connect failed');
        }
      })();
    } else if (tcpWriter) {
      // Pipe: WebSocket → TCP writable
      tcpWriter.write(new Uint8Array(buf)).catch(() => {});
    } else {
      // Buffer messages while TCP connection is being established
      pending.push(buf);
    }
  });

  (server as WebSocket).addEventListener('close', () => {
    tcpWriter?.close().catch(() => {});
  });

  (server as WebSocket).addEventListener('error', () => {
    tcpWriter?.close().catch(() => {});
  });

  return new Response(null, { status: 101, webSocket: client });
}
