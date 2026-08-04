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
