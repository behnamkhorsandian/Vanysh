// ---------------------------------------------------------------------------
// Vany TUI — Table Renderer
// Renders tabular data with Unicode box-drawing borders.
//
// Usage:
//   table({
//     headers: ["Protocol", "Status", "Port", "Users", "Container"],
//     rows: [
//       ["REALITY", "running", "443", "3", "vany-xray"],
//       ["WS+CDN",  "running", "80",  "3", "vany-xray"],
//     ],
//     title: "PROTOCOLS",
//   })
// ---------------------------------------------------------------------------

import { DGRAY, TEXT, GREEN, RED, ORANGE, BOLD, DIM, RST } from "./theme.js";
import { visibleLen, repeat } from "./ansi.js";

interface TableOpts {
  headers: string[];
  rows: string[][];
  title?: string;
  borderColor?: string;
  headerColor?: string;
  minColWidth?: number;
}

/** Render a bordered Unicode table */
export function table(opts: TableOpts): string {
  const {
    headers,
    rows,
    title = "",
    borderColor = DGRAY,
    headerColor = ORANGE,
    minColWidth = 4,
  } = opts;

  const bc = borderColor;
  const numCols = headers.length;

  // Calculate column widths
  const colWidths: number[] = headers.map((h) =>
    Math.max(minColWidth, visibleLen(h) + 2)
  );
  for (const row of rows) {
    for (let i = 0; i < numCols; i++) {
      const cell = row[i] || "";
      colWidths[i] = Math.max(colWidths[i], visibleLen(cell) + 2);
    }
  }

  // Build horizontal rules
  function hRule(left: string, mid: string, right: string): string {
    const segments = colWidths.map((w) => "─".repeat(w));
    return `${bc}${left}${segments.join(mid)}${right}${RST}`;
  }

  // Build a content row
  function contentRow(cells: string[], color = TEXT): string {
    const parts = cells.map((cell, i) => {
      const w = colWidths[i];
      const vis = visibleLen(cell);
      const pad = Math.max(0, w - vis - 1);
      return ` ${cell}${repeat(" ", pad)}`;
    });
    return `${bc}│${RST}${parts.join(`${bc}│${RST}`)}${bc}│${RST}`;
  }

  const out: string[] = [];

  // Title row (if provided)
  if (title) {
    const totalWidth = colWidths.reduce((s, w) => s + w, 0) + numCols - 1;
    const titlePad = Math.max(0, totalWidth - visibleLen(title) - 1);
    out.push(`${bc}┌${"─".repeat(totalWidth)}┐${RST}`);
    out.push(`${bc}│${RST} ${BOLD}${headerColor}${title}${RST}${repeat(" ", titlePad)}${bc}│${RST}`);
    out.push(hRule("├", "┬", "┤"));
  } else {
    out.push(hRule("┌", "┬", "┐"));
  }

  // Header row
  const headerCells = headers.map((h) => `${BOLD}${headerColor}${h}${RST}`);
  out.push(contentRow(headerCells));
  out.push(hRule("├", "┼", "┤"));

  // Data rows
  for (const row of rows) {
    out.push(contentRow(row));
  }

  // Bottom border
  out.push(hRule("└", "┴", "┘"));

  return out.join("\r\n");
}

/** Colorize a status string */
export function statusColor(status: string): string {
  switch (status.toLowerCase()) {
    case "running":
      return `${GREEN}${status}${RST}`;
    case "stopped":
    case "exited":
      return `${RED}${status}${RST}`;
    case "not installed":
    case "not_installed":
      return `${DIM}--${RST}`;
    default:
      return `${DGRAY}${status}${RST}`;
  }
}
