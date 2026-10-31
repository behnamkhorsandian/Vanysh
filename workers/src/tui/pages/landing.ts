// The same entry point opens the server and client journeys.
import { GREEN, LGREEN, TEXT, BOLD, RST } from "../theme.js";

export function pageLanding(): string {
  return [
    "",
    `  ${GREEN}░█░█░█▀█░█▀█░█░█░█▀▀░█░█${RST}`,
    `  ${GREEN}░▀▄▀░█▀█░█░█░░█░░▀▀█░█▀█${RST}`,
    `  ${GREEN}░░▀░░▀░▀░▀░▀░░▀░░▀▀▀░▀░▀${RST}`,
    "",
    `  ${BOLD}Create a service or connect to one${RST}`,
    `  ${TEXT}Run this command in a terminal:${RST}`,
    "",
    `  ${LGREEN}curl vany.sh | sudo bash${RST}`,
    "",
    `  ${TEXT}Use the chooser if you are unsure which protocol to use.${RST}`,
    `  ${TEXT}On Windows, run the command in WSL. On a server, connect with SSH first.${RST}`,
    `  ${TEXT}Guides: https://vany.sh/#docs/getting-started${RST}`,
    "",
  ].join("\n");
}

/** A two-line Bash preamble followed by an ANSI page for a plain curl. */
export function pageLandingBash(): string {
  const cleanup = "\x1b[2A\x1b[J";
  return `#!/bin/bash
printf '\\n  ░█░█░█▀█░█▀█░█░█░█▀▀░█░█\\n  ░▀▄▀░█▀█░█░█░░█░░▀▀█░█▀█\\n  ░░▀░░▀░▀░▀░▀░░▀░░▀▀▀░▀░▀\\n\\n  Starting Vany...\\n\\n'; if [[ \$(id -u) -ne 0 ]]; then printf 'Run: curl vany.sh | sudo bash\\n' >&2; exit 1; fi; tmp=\$(mktemp "\${TMPDIR:-/tmp}/vany-start.XXXXXX") || exit 1; if curl -fsSL --connect-timeout 10 --max-time 60 https://start.vany.sh/ -o "$tmp"; then VANY_SPLASH_SHOWN=1 bash "$tmp"; result=$?; else printf 'Could not load Vany. Check your internet connection.\\n' >&2; result=1; fi; rm -f "$tmp"; exit "$result"
${cleanup}${pageLanding()}`;
}
