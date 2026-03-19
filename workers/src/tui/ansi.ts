// ---------------------------------------------------------------------------
// Vany TUI — ANSI Utilities
// ---------------------------------------------------------------------------

const ANSI_RE = /\x1b\[[0-9;]*[a-zA-Z]/g;

/** Strip all ANSI escape sequences from a string */
export function stripAnsi(s: string): string {
  return s.replace(ANSI_RE, "");
}

/** Get visible character length (excluding ANSI escapes) */
export function visibleLen(s: string): number {
  return stripAnsi(s).length;
}

/** Repeat a character n times (returns "" if n <= 0) */
export function repeat(ch: string, n: number): string {
  return n > 0 ? ch.repeat(n) : "";
}

/**
 * Extract a visible-character substring from an ANSI-colored string.
 * `start` and `end` are in visible-character positions (ignoring escapes).
 * Preserves active ANSI codes at the slice boundary.
 */
export function ansiSubstring(s: string, start: number, end: number): string {
  const ANSI = /\x1b\[[0-9;]*[a-zA-Z]/g;
  let visIdx = 0;
  let i = 0;
  let result = "";
  let activeCode = "";
  let inWindow = false;

  while (i < s.length && visIdx < end) {
    ANSI.lastIndex = i;
    const m = ANSI.exec(s);
    if (m && m.index === i) {
      if (visIdx >= start) {
        result += m[0];
      } else {
        activeCode += m[0];
      }
      i += m[0].length;
      continue;
    }

    if (visIdx >= start) {
      if (!inWindow) {
        result = activeCode + result;
        inWindow = true;
      }
      result += s[i];
    }
    visIdx++;
    i++;
  }

  return result;
}

/** Clear screen and position cursor at top-left */
export const CLEAR = "\x1b[2J\x1b[H";

/** Move cursor to top-left (overwrite in-place, no clear) */
export const HOME = "\x1b[H";

/** Hide cursor */
export const HIDE_CURSOR = "\x1b[?25l";

/** Show cursor */
export const SHOW_CURSOR = "\x1b[?25h";

/** Erase to end of screen */
export const ERASE_BELOW = "\x1b[J";

/** Move cursor to position (1-based row, col) */
export function moveTo(row: number, col: number): string {
  return `\x1b[${row};${col}H`;
}
