# Vany Project Overview

Vany is a multi-protocol censorship-bypass platform for nontechnical VPS owners. A user should be able to buy a server, SSH into it, choose a protocol on the website, and run one command:

```bash
curl vany.sh/reality | sudo bash
```

The same protocol command is also the management entry point for update/repair, users, connection configs, logs, restart, and uninstall.

## Entry Points

- `curl vany.sh` - ANSI protocol catalog for terminal users.
- `curl vany.sh/<protocol> | sudo bash` - guided installer/manager for one protocol.
- `curl vany.sh/tools/<tool> | bash` - client-side network scanner or diagnostic tool.
- `https://www.vany.sh` - Cloudflare Pages website.

## Delivery Layer

- `workers/src/index.ts` is the unified Cloudflare Worker router.
- Known protocol routes return `scripts/direct-install.sh` with `VANY_PROTOCOL=<protocol>` prepended.
- Tool routes proxy scripts from `scripts/tools/`.
- TUI routes under `/tui/*` return server-rendered ANSI pages.
- Browser requests to `vany.sh` redirect to `www.vany.sh`; CLI requests receive plain text scripts or ANSI output.

## Installer Layer

- `scripts/direct-install.sh` is the canonical guided protocol manager.
- `scripts/lib/protocol-registry.sh` stores protocol metadata: runtime, container, ports, state key, feature key, installer script, user hooks, and uninstall hooks.
- `scripts/docker-bootstrap.sh` prepares the VPS and downloads Docker compose files, protocol scripts, the protocol registry, and runtime assets into `/opt/vany`.
- `scripts/protocols/install-*.sh` own protocol-specific lifecycle behavior.

## Runtime Layer

- Runtime state: `/opt/vany/state.json`.
- User database: `/opt/vany/users.json`.
- Docker compose files: `/opt/vany/docker/<runtime>/`.
- Protocol data: `/opt/vany/<runtime-or-protocol>/`.
- Docker owns service uptime through container restart policies.
- tmux is available for operator sessions, logs, and management visibility.

## Shared Runtime Rules

- `vany-xray` is the shared runtime for Reality, WS+CDN, HTTP Obfs, and future Xray-family protocols.
- Individual Xray features are tracked under `.protocols.xray.<feature>`.
- Removing one Xray feature must not stop `vany-xray` while another feature remains active.
- DNS tunnel protocols currently compete for port 53. Installers should block or explain conflicts until a DNS multiplexer is implemented.
- WireGuard uses host networking and iptables. Test it last and use a recovery plan.

## Repository Map

- `.github/workflows/` - remote CI, deploy, release, and VM watchdog workflows.
- `workers/` - Cloudflare Worker source, TUI renderer, Worker tests, Wrangler config.
- `www/` - Cloudflare Pages static website.
- `scripts/lib/` - shared Bash registry and helper libraries.
- `scripts/protocols/` - protocol lifecycle modules.
- `scripts/tools/` - user tools plus CI helper scripts.
- `docker/` - protocol runtime compose files and Dockerfiles.
- `docs/` - deployment, DNS, firewall, self-hosting, recovery, and protocol guides.
- `lib/` and `services/` - legacy implementation surfaces used as migration references.
- `cli/` - legacy local management CLI.
- `cloak/` and `build/` - offline Cloak client packaging.
- `src/sos/` - SOS emergency chat client and relay code.

## Workflows

- `deploy.yml` - deploys Workers and Pages on pushes to `main` when relevant files change.
- `protocol-smoke.yml` - checks Bash syntax, protocol registry drift, and Docker compose config.
- `spot-vm-watchdog.yml` - restarts the GCP Spot VM if preempted.
- `cloak-build.yml` - builds Cloak release archives on `cloak-v*` tags or manual dispatch.
- `sos-build.yml` - builds SOS binaries on `sos-v*` tags or manual dispatch.

## Testing Model

- Local checks should stay lightweight: shell syntax, diff checks, and diagnostics.
- GitHub Actions performs Worker tests and protocol smoke checks.
- Disposable VM E2E tests are required before calling a protocol production-ready because containers cannot fully simulate public networking, UDP, low ports, DNS delegation, Cloudflare CDN behavior, TUN, or iptables.

## Current Protocol Groups

- Xray family: `reality`, `ws`, `http-obfs`, `vray`, `mtp`.
- Standalone VPN/proxy: `hysteria`, `wg`, `ssh-tunnel`.
- DNS tunnels: `dnstt`, `slipstream`, `noizdns`.
- Relay/community: `conduit`, `tor-bridge`, `snowflake`, `sos`.