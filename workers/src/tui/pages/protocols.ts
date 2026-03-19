// ---------------------------------------------------------------------------
// Vany TUI — Protocols Page
// Renders the protocol catalog table with live status from VPS state.
// ---------------------------------------------------------------------------

import { table, statusColor } from "../table.js";
import { GREEN, ORANGE, DIM, BOLD, TEXT, RST } from "../theme.js";
import { keyHint } from "../layout.js";

interface ProtocolDef {
  name: string;
  port: string;
  container: string;
  shared?: string; // shared container name (e.g. "vany-xray")
  description: string;
}

const PROTOCOLS: Record<string, ProtocolDef> = {
  reality: {
    name: "REALITY",
    port: "443",
    container: "vany-xray",
    shared: "xray",
    description: "VLESS+REALITY — TLS camouflage, no domain needed",
  },
  ws: {
    name: "WS+CDN",
    port: "80",
    container: "vany-xray",
    shared: "xray",
    description: "VLESS+WebSocket — route through Cloudflare CDN",
  },
  wg: {
    name: "WireGuard",
    port: "51820",
    container: "vany-wireguard",
    description: "Fast kernel VPN with native app support",
  },
  dnstt: {
    name: "DNSTT",
    port: "53",
    container: "vany-dnstt",
    description: "DNS tunnel — emergency backup for blackouts",
  },
  conduit: {
    name: "Conduit",
    port: "auto",
    container: "vany-conduit",
    description: "Psiphon volunteer relay node",
  },
  sos: {
    name: "SOS",
    port: "8899",
    container: "vany-sos",
    description: "Emergency encrypted chat over DNSTT",
  },
  vray: {
    name: "VRAY",
    port: "443",
    container: "vany-xray",
    shared: "xray",
    description: "VLESS+TCP+TLS — classic V2Ray, needs domain",
  },
  mtp: {
    name: "MTProto",
    port: "443",
    container: "vany-mtp",
    description: "Telegram proxy with Fake-TLS",
  },
};

/** Render the protocols catalog page */
export function pageProtocols(state: Record<string, unknown> = {}): string {
  const protocols = (state.protocols || {}) as Record<
    string,
    { status?: string; users?: number; container?: string }
  >;

  const headers = ["Protocol", "Status", "Port", "Users", "Container"];
  const rows: string[][] = [];

  for (const [key, def] of Object.entries(PROTOCOLS)) {
    const proto = protocols[key];
    const status = proto?.status || "not installed";
    const users = proto?.users != null ? String(proto.users) : "--";
    const containerLabel = proto?.container
      ? `${proto.container}${def.shared ? " (shared)" : ""}`
      : "--";

    rows.push([
      `${BOLD}${TEXT}${def.name}${RST}`,
      statusColor(status),
      `${DIM}${def.port}${RST}`,
      users,
      `${DIM}${containerLabel}${RST}`,
    ]);
  }

  const tbl = table({
    headers,
    rows,
    title: "PROTOCOLS",
  });

  const hints = [
    keyHint("i", "install"),
    keyHint("r", "remove"),
    keyHint("Enter", "details"),
    keyHint("Esc", "back"),
  ].join("  ");

  return `${tbl}\n\n  ${hints}`;
}
