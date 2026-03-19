// ---------------------------------------------------------------------------
// Vany TUI — Help Page
// ---------------------------------------------------------------------------

import { GREEN, ORANGE, BOLD, DIM, TEXT, LGREEN, DGRAY, BLUE, RST } from "../theme.js";
import { box } from "../box.js";
import { keyHint } from "../layout.js";

export function pageHelp(): string {
  const lines: string[] = [];

  lines.push(`  ${BOLD}${GREEN}VANY${RST} ${DIM}v2.0.0${RST}`);
  lines.push(`  ${DIM}Multi-protocol censorship bypass platform${RST}`);
  lines.push("");

  // Navigation
  lines.push(`  ${BOLD}${ORANGE}NAVIGATION${RST}`);
  lines.push(`    ${keyHint("p", "protocols")}   Protocol catalog and status`);
  lines.push(`    ${keyHint("s", "status")}      Docker container status (local)`);
  lines.push(`    ${keyHint("u", "users")}       User management (local)`);
  lines.push(`    ${keyHint("i", "install")}     Install wizard`);
  lines.push(`    ${keyHint("h", "help")}        This page`);
  lines.push(`    ${keyHint("q", "quit")}        Exit`);
  lines.push(`    ${keyHint("r", "refresh")}     Refresh current page`);
  lines.push("");

  // Architecture
  lines.push(`  ${BOLD}${ORANGE}ARCHITECTURE${RST}`);
  lines.push(`    ${TEXT}All protocols run in Docker containers.${RST}`);
  lines.push(`    ${TEXT}Xray shared container handles: Reality, WS+CDN, VRAY${RST}`);
  lines.push(`    ${TEXT}State stored at: /opt/vany/state.json${RST}`);
  lines.push(`    ${TEXT}Users stored at: /opt/vany/users.json${RST}`);
  lines.push("");

  // Protocols
  lines.push(`  ${BOLD}${ORANGE}PROTOCOLS${RST}`);
  lines.push(`    ${LGREEN}Reality${RST}    ${DIM}VLESS+REALITY, no domain, port 443${RST}`);
  lines.push(`    ${LGREEN}WS+CDN${RST}     ${DIM}VLESS+WebSocket through Cloudflare${RST}`);
  lines.push(`    ${LGREEN}WireGuard${RST}  ${DIM}Fast VPN, port 51820/udp${RST}`);
  lines.push(`    ${LGREEN}DNSTT${RST}      ${DIM}DNS tunnel, emergency backup${RST}`);
  lines.push(`    ${LGREEN}Conduit${RST}    ${DIM}Psiphon relay node${RST}`);
  lines.push(`    ${LGREEN}SOS${RST}        ${DIM}Emergency chat over DNSTT${RST}`);
  lines.push("");

  // Links
  lines.push(`  ${BOLD}${ORANGE}LINKS${RST}`);
  lines.push(`    ${BLUE}https://github.com/behnamkhorsandian/Vanysh${RST}`);
  lines.push(`    ${BLUE}https://www.vany.sh${RST}`);

  return lines.join("\r\n");
}
