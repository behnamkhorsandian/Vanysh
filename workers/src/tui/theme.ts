// ---------------------------------------------------------------------------
// Vany TUI — ANSI Color Theme
// 256-color palette for terminal UI
// ---------------------------------------------------------------------------

export const TEXT   = "\x1b[38;5;253m";  // white #e7e7e7 — body text
export const GREEN  = "\x1b[38;5;36m";   // main green #2eb787 — primary brand
export const LGREEN = "\x1b[38;5;115m";  // light green #9acfa0 — commands, keys
export const DGREEN = "\x1b[38;5;65m";   // dark green #466242 — subtle accents
export const BLUE   = "\x1b[38;5;68m";   // blue #6090e3 — links, URLs
export const RED    = "\x1b[38;5;130m";  // red #a25138 — errors, stopped
export const ORANGE = "\x1b[38;5;172m";  // orange #d59719 — headings, labels
export const YELLOW = "\x1b[38;5;186m";  // yellow #e5e885 — highlights
export const PURPLE = "\x1b[38;5;141m";  // purple #a492ff — emphasis
export const LGRAY  = "\x1b[38;5;151m";  // light gray #9ab0a6 — meta info
export const DGRAY  = "\x1b[38;5;236m";  // dark gray #343434 — borders, dim
export const RST    = "\x1b[0m";
export const ITALIC = "\x1b[3m";
export const BOLD   = "\x1b[1m";
export const DIM    = "\x1b[2m";

// Background colors
export const BG_BLACK = "\x1b[48;5;233m"; // near-black bg #121212

// Status colors
export const STATUS_RUNNING = GREEN;
export const STATUS_STOPPED = RED;
export const STATUS_MISSING = DGRAY;
