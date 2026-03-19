// ---------------------------------------------------------------------------
// Vany TUI — Splash / Logo
// Simple branding splash shown on first connect before the main page.
// ---------------------------------------------------------------------------

import { GREEN, DGREEN, DGRAY, DIM, TEXT, BOLD, RST } from "./theme.js";
import { repeat } from "./ansi.js";

const LOGO_LINES = [
  "░█░█░█▀█░█▀█░█░█░█▀▀░█░█",
  "░▀▄▀░█▀█░█░█░░█░░▀▀█░█▀█",
  "░░▀░░▀░▀░▀░▀░░▀░░▀▀▀░▀░▀",
];

/** Render the Vany logo, centered in the given width */
export function logo(width: number): string {
  const lines: string[] = [];
  for (const l of LOGO_LINES) {
    const pad = Math.max(0, Math.floor((width - l.length) / 2));
    lines.push(`${repeat(" ", pad)}${GREEN}${l}${RST}`);
  }
  return lines.join("\r\n");
}

/** Render a full splash screen with logo and tagline */
export function splash(cols: number, rows: number): string {
  const out: string[] = [];
  const width = Math.min(cols, 80);

  // Vertical centering
  const contentHeight = 7; // logo (3) + gap (1) + tagline (1) + gap (1) + sub (1)
  const topPad = Math.max(0, Math.floor((rows - contentHeight) / 2));

  for (let i = 0; i < topPad; i++) out.push("");

  // Logo
  out.push(logo(width));
  out.push("");

  // Tagline
  const tagline = "Multi-protocol censorship bypass platform";
  const tagPad = Math.max(0, Math.floor((width - tagline.length) / 2));
  out.push(`${repeat(" ", tagPad)}${DIM}${tagline}${RST}`);
  out.push("");

  // Version
  const ver = "v2.0.0";
  const verPad = Math.max(0, Math.floor((width - ver.length) / 2));
  out.push(`${repeat(" ", verPad)}${DGRAY}${ver}${RST}`);

  return out.join("\r\n");
}
