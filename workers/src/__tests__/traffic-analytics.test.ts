import { describe, expect, it } from 'vitest';
import { topProtocolsFromEndpoints } from '../traffic-analytics.js';

describe('topProtocolsFromEndpoints', () => {
  it('aggregates protocol endpoint and child-path requests', () => {
    const protocols = topProtocolsFromEndpoints([
      { dimensions: { clientRequestPath: '/reality' }, sum: { requests: 12 } },
      { dimensions: { clientRequestPath: '/reality/setup/linux' }, sum: { requests: 8 } },
      { dimensions: { clientRequestPath: '/dnstt/client' }, sum: { requests: 15 } },
      { dimensions: { clientRequestPath: '/docs' }, sum: { requests: 100 } },
      { dimensions: { clientRequestPath: '/' }, sum: { requests: 200 } },
    ]);

    expect(protocols).toEqual([
      { endpoint: 'reality', name: 'VLESS + REALITY', requests: 20 },
      { endpoint: 'dnstt', name: 'DNS Tunnel', requests: 15 },
    ]);
  });

  it('aggregates protocol subdomain requests when the path is not protocol-specific', () => {
    const protocols = topProtocolsFromEndpoints([
      { dimensions: { clientRequestHTTPHost: 'mtp.vany.sh', clientRequestPath: '/' }, sum: { requests: 7 } },
      { dimensions: { clientRequestHTTPHost: 'wg.vany.sh', clientRequestPath: '/' }, sum: { requests: 3 } },
      { dimensions: { clientRequestHTTPHost: 'www.vany.sh', clientRequestPath: '/' }, sum: { requests: 10 } },
      { dimensions: { clientRequestHTTPHost: 'vany.sh', clientRequestPath: '/ws' }, sum: { requests: 4 } },
    ]);

    expect(protocols).toEqual([
      { endpoint: 'mtp', name: 'MTProto', requests: 7 },
      { endpoint: 'ws', name: 'VLESS + WS + CDN', requests: 4 },
      { endpoint: 'wg', name: 'WireGuard', requests: 3 },
    ]);
  });

  it('limits the result and handles absent analytics fields', () => {
    const protocols = topProtocolsFromEndpoints([
      {},
      { dimensions: { clientRequestPath: '/wg?source=home' }, sum: { requests: 2 } },
      { dimensions: { clientRequestPath: '/WS' }, sum: { requests: 4 } },
    ], 1);

    expect(protocols).toEqual([
      { endpoint: 'ws', name: 'VLESS + WS + CDN', requests: 4 },
    ]);
  });
});
