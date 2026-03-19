// ---------------------------------------------------------------------------
// Vany TUI — Layout Helpers
// ---------------------------------------------------------------------------

import { DGRAY, ORANGE, GREEN, TEXT, DIM, RST } from "./theme.js";
import { visibleLen, repeat } from "./ansi.js";

/** Left-pad every line of text with a prefix */
export function lpad(text: string, prefix = "  "): string {
  return text.split("\n").map((l) => prefix + l).join("\n");
}

/** Place two text blocks side by side with a gap */
export function sideBySide(left: string, right: string, gap = 3): string {
  const lLines = left.split("\n");
  const rLines = right.split("\n");
  const lWidth = Math.max(...lLines.map(visibleLen), 0);
  const height = Math.max(lLines.length, rLines.length);
  const spacer = " ".repeat(gap);
  const merged: string[] = [];
  for (let i = 0; i < height; i++) {
    const ll = lLines[i] || "";
    const rl = rLines[i] || "";
    const pad = lWidth - visibleLen(ll);
    merged.push(ll + repeat(" ", pad) + spacer + rl);
  }
  return merged.join("\n");
}

/** Word-wrap text to maxWidth */
export function wordWrap(text: string, maxWidth = 50): string[] {
  const words = text.split(" ");
  const lines: string[] = [];
  let cur = "";
  for (const w of words) {
    if (cur.length + w.length + 1 <= maxWidth) {
      cur = cur ? `${cur} ${w}` : w;
    } else {
      lines.push(cur);
      cur = w;
    }
  }
  if (cur) lines.push(cur);
  return lines;
}

/** Format a menu item: route ... description */
export function menuLine(route: string, desc: string, width = 44): string {
  const dotsN = width - route.length - desc.length;
  const dots = ".".repeat(Math.max(3, dotsN));
  return `${ORANGE}${route}${RST} ${DGRAY}${dots}${RST} ${TEXT}${desc}${RST}`;
}

/** Center text within a given width */
export function center(text: string, width: number): string {
  const vis = visibleLen(text);
  const pad = Math.max(0, Math.floor((width - vis) / 2));
  return repeat(" ", pad) + text;
}

/** Format a key hint: [k] description */
export function keyHint(key: string, desc: string): string {
  return `${GREEN}[${key}]${RST}${DIM} ${desc}${RST}`;
}
