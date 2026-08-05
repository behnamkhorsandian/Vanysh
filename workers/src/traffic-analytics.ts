export interface EndpointAnalyticsRow {
  dimensions?: {
    clientRequestPath?: string;
    clientRequestHTTPHost?: string;
  };
  sum?: {
    requests?: number;
  };
}

const PROTOCOL_ENDPOINTS: Record<string, string> = {
  mtp: 'MTP protocol',
  reality: 'VLESS + REALITY',
  wg: 'WireGuard',
  vray: 'VLESS + TLS',
  ws: 'VLESS Websocket',
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

function protocolEndpointFromRow(row: EndpointAnalyticsRow): string | undefined {
  const path = row.dimensions?.clientRequestPath || '';
  const pathEndpoint = path.split('?')[0].split('/').filter(Boolean)[0]?.toLowerCase();
  if (pathEndpoint && PROTOCOL_ENDPOINTS[pathEndpoint]) return pathEndpoint;

  const host = (row.dimensions?.clientRequestHTTPHost || '').toLowerCase();
  const hostEndpoint = host.endsWith('.vany.sh') ? host.slice(0, -'.vany.sh'.length).split('.').pop() : '';
  if (!hostEndpoint) return undefined;

  return PROTOCOL_ENDPOINTS[hostEndpoint] ? hostEndpoint : undefined;
}

/**
 * Treat requests to a protocol's top-level endpoint (including its child paths)
 * or fallback subdomain as a usage proxy. Cloudflare zone analytics cannot
 * identify the protocol a visitor eventually installs, but the endpoint or
 * fallback host they request provides a useful aggregate signal without
 * tracking individual users.
 */
export function topProtocolsFromEndpoints(rows: EndpointAnalyticsRow[], limit = 5) {
  const totals = new Map<string, number>();

  for (const row of rows) {
    const endpoint = protocolEndpointFromRow(row);
    if (!endpoint) continue;

    totals.set(endpoint, (totals.get(endpoint) || 0) + (row.sum?.requests || 0));
  }

  return Array.from(totals.entries())
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([endpoint, requests]) => ({ endpoint, name: PROTOCOL_ENDPOINTS[endpoint], requests }));
}
