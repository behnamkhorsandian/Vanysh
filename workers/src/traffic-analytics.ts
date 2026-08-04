export interface EndpointAnalyticsRow {
  dimensions?: {
    clientRequestPath?: string;
  };
  sum?: {
    requests?: number;
  };
}

const PROTOCOL_ENDPOINTS: Record<string, string> = {
  mtp: 'MTProto',
  reality: 'VLESS + REALITY',
  wg: 'WireGuard',
  vray: 'VLESS + TLS',
  ws: 'VLESS + WS + CDN',
  dnstt: 'DNS Tunnel',
  conduit: 'Conduit',
  hysteria: 'Hysteria v2',
  'http-obfs': 'HTTP Obfuscation',
  'ssh-tunnel': 'SSH Tunnel',
  noizdns: 'NoizDNS',
  slipstream: 'Slipstream',
  snowflake: 'Snowflake',
  'tor-bridge': 'Tor Bridge',
  sos: 'SOS Chat',
};

/**
 * Treat requests to a protocol's top-level endpoint (including its child paths)
 * as a usage proxy. Cloudflare zone analytics cannot identify the protocol a
 * visitor eventually installs, but the endpoint they request provides a useful
 * aggregate signal without tracking individual users.
 */
export function topProtocolsFromEndpoints(rows: EndpointAnalyticsRow[], limit = 5) {
  const totals = new Map<string, number>();

  for (const row of rows) {
    const path = row.dimensions?.clientRequestPath || '';
    const endpoint = path.split('?')[0].split('/').filter(Boolean)[0]?.toLowerCase();
    const name = endpoint && PROTOCOL_ENDPOINTS[endpoint];
    if (!name) continue;

    totals.set(endpoint, (totals.get(endpoint) || 0) + (row.sum?.requests || 0));
  }

  return Array.from(totals.entries())
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([endpoint, requests]) => ({ endpoint, name: PROTOCOL_ENDPOINTS[endpoint], requests }));
}
