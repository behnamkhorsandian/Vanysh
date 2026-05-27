# Vany Project Instructions

Vany is a multi-protocol VPN and censorship-bypass installer. The user promise is simple: buy a VPS, SSH into it, run `curl vany.sh/<protocol> | sudo bash`, then use that same command later to update, manage users, view configs, restart, or uninstall that protocol.

## Architecture Context

- `workers/` contains the unified Cloudflare Worker. It serves installer routes such as `/wg`, `/reality`, `/tools/cfray`, `/tui/*`, SafeBox routes, and health/stats endpoints.
- `www/` is the Cloudflare Pages website.
- `scripts/direct-install.sh` is the canonical guided installer/manager for one protocol.
- `scripts/lib/protocol-registry.sh` is the shared Bash protocol registry. Add protocol metadata here first, then keep Worker metadata in `workers/src/index.ts` in sync.
- `scripts/docker-bootstrap.sh` prepares a VPS: packages, Docker, tmux, sysctl, state files, user database, Docker compose files, and protocol scripts.
- `scripts/protocols/` contains protocol lifecycle modules. Keep protocol-specific install, user, config, restart, and cleanup logic in these files.
- `scripts/tools/` contains user-facing diagnostic/scanner tools and CI helper checks.
- `docker/` contains runtime compose files and Dockerfiles. Docker owns service uptime; tmux is for operator visibility/log sessions, not supervision.
- `lib/` and `services/` are legacy surfaces. Reuse proven logic when migrating, but prefer `scripts/` and `docker/` for new work.
- `cli/` contains the older local management CLI.
- `cloak/`, `build/`, and `src/sos/` support the offline Cloak/SOS release workflows.
- `docs/` contains operator, deployment, DNS, firewall, protocol, and recovery documentation.

## Runtime Model

- VPS state lives in `/opt/vany/state.json`; users live in `/opt/vany/users.json`.
- Most protocols run in isolated Docker containers under `/opt/vany/docker/<runtime>/`.
- Xray-family protocols share `vany-xray`; track individual protocol features under `.protocols.xray.<feature>` so uninstalling one feature does not remove the shared runtime while another feature still uses it.
- DNS tunnel protocols compete for port 53 unless/until a DNS edge multiplexer exists. Handle conflicts clearly.
- WireGuard uses host networking and iptables. Treat it as high risk, install/test it last, and avoid unrelated networking changes around it.

## Deployment And CI

- Do not build locally for normal development. Do not create local `node_modules`, Docker images, or local Wrangler deploys unless the user explicitly asks.
- Push changes and let GitHub Actions build, test, and deploy.
- `.github/workflows/deploy.yml` deploys the Worker and Pages on pushes to `main` when relevant paths change.
- `.github/workflows/protocol-smoke.yml` validates shell syntax, registry drift, and Docker compose config for protocol surfaces.
- `.github/workflows/spot-vm-watchdog.yml` keeps the GCP Spot VM running.
- `.github/workflows/cloak-build.yml` and `.github/workflows/sos-build.yml` build release artifacts from tags or manual dispatch.
- Required Cloudflare secrets: `CF_API_TOKEN`, `CF_ACCOUNT_ID`, `CF_ZONE_ID`.
- Verify workflow results with `gh run list` and `gh run view <id> --log`; workflow dispatch alone is not proof of success.

## Testing

- Local validation is limited to cheap checks: `bash -n`, `git diff --check`, and diagnostics. Avoid local Docker and npm builds.
- CI smoke tests catch syntax, registry, Worker, and compose regressions.
- Real protocol usability requires disposable VM E2E tests for public IP reachability, firewalls, UDP, low ports, DNS delegation, Cloudflare CDN behavior, TUN/NET_ADMIN, iptables, and reboot persistence.
- E2E order: low-risk protocol first, Xray-family next, DNS tunnel next, WireGuard last.

## Coding Standards

- Bash scripts use `#!/bin/bash`, quoted variables, `[[ ]]`, `snake_case` functions, `UPPER_SNAKE_CASE` constants, and explicit error handling.
- Keep output plain ASCII. Do not add emojis to scripts.
- Preserve existing style and keep changes scoped.
- Use structured tools such as `jq` for JSON. Avoid ad hoc JSON string edits when `jq` can do it safely.
- Never revert unrelated user changes. Do not commit unless explicitly requested.