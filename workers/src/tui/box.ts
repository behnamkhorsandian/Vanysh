// ---------------------------------------------------------------------------
// Vany TUI — Box Drawing
// Unicode box chars: ┌ ┐ └ ┘ │ ─ ├ ┤ ┬ ┴ ┼
// ---------------------------------------------------------------------------

import { DGRAY, TEXT, RST } from "./theme.js";
import { visibleLen, repeat } from "./ansi.js";

interface BoxOpts {
  title?: string;
  sep?: string;
  hpad?: number;
  vpad?: number;
  borderColor?: string;
  titleColor?: string;
}

export function box(lines: string[], opts: BoxOpts = {}): string {
  const {
    title = "",
    sep = "",
    hpad = 1,
    vpad = 0,
    borderColor = DGRAY,
    titleColor = TEXT,
  } = opts;

  const WE = "─", NS = "│";
  const SE = "┌", NE = "└", SW = "┐", NW = "┘";
  const SWE = "┬", NWE = "┴";
  const hp = " ".repeat(hpad);

  // Analyze column widths
  let numCols = 1;
  const maxCols: number[] = [];

  for (const line of lines) {
    const cells = sep ? line.split(sep) : [line];
    numCols = Math.max(numCols, cells.length);
    for (let i = 0; i < cells.length; i++) {
      const padded = hp + cells[i] + hp;
      const clen = visibleLen(padded);
      while (maxCols.length <= i) maxCols.push(0);
      maxCols[i] = Math.max(maxCols[i], clen);
    }
  }

  const bc = borderColor;

  // Top border with title
  let top = `${bc}${SE}${WE}${RST}${titleColor}${title}${RST}${bc}`;
  let offset = title.length + 1;

  for (let i = 0; i < maxCols.length; i++) {
    const cw = maxCols[i];
    if (i < maxCols.length - 1) {
      const fill = Math.max(0, cw - offset);
      offset = Math.max(0, offset - cw - 1);
      top += repeat(WE, fill);
      if (offset <= 0) top += SWE;
    } else {
      const fill = Math.max(0, cw - offset);
      top += repeat(WE, fill);
    }
  }
  top += `${SW}${RST}`;

  // Bottom border
  let bot = `${bc}${NE}`;
  for (let i = 0; i < maxCols.length; i++) {
    bot += repeat(WE, maxCols[i]);
    if (i < maxCols.length - 1) bot += NWE;
  }
  bot += `${NW}${RST}`;

  // Content with vertical padding
  const blankLine = sep ? Array(numCols).fill("").join(sep) : "";
  const allLines = [
    ...Array(vpad).fill(blankLine),
    ...lines,
    ...Array(vpad).fill(blankLine),
  ];

  const rows: string[] = [];
  for (const line of allLines) {
    const cells = sep ? line.split(sep) : [line];
    let row = `${bc}${NS}${RST}`;
    for (let i = 0; i < maxCols.length; i++) {
      const cell = i < cells.length ? cells[i] : "";
      const padded = hp + cell + hp;
      const padNeed = maxCols[i] - visibleLen(padded);
      row += padded + repeat(" ", padNeed);
      if (i < maxCols.length - 1) row += `${bc}${NS}${RST}`;
    }
    row += `${bc}${NS}${RST}`;
    rows.push(row);
  }

  return [top, ...rows, bot].join("\n");
}

/** Horizontal rule full-width */
export function hr(width: number, borderColor = DGRAY): string {
  return `${borderColor}${"─".repeat(width)}${RST}`;
}

/** Separator row inside a box: ├──────┤ */
export function separator(width: number, borderColor = DGRAY): string {
  return `${borderColor}├${"─".repeat(width - 2)}┤${RST}`;
}
