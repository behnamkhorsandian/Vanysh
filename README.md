# Vanysh
[![Build Cloak](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/cloak-build.yml/badge.svg)](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/cloak-build.yml)
[![Deploy](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/deploy.yml/badge.svg)](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/deploy.yml)
[![Protocol Smoke](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/protocol-smoke.yml/badge.svg)](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/protocol-smoke.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Website](https://img.shields.io/website?down_color=red&down_message=offline&up_color=green&up_message=online&url=https%3A%2F%2Fvany.sh)](https://www.vany.sh)

### Project stats

[![GitHub stars](https://img.shields.io/github/stars/behnamkhorsandian/Vanysh?style=flat&logo=github&label=Stars)](https://github.com/behnamkhorsandian/Vanysh/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/behnamkhorsandian/Vanysh?style=flat&logo=github&label=Forks)](https://github.com/behnamkhorsandian/Vanysh/forks)
[![GitHub watchers](https://img.shields.io/github/watchers/behnamkhorsandian/Vanysh?style=flat&logo=github&label=Watchers)](https://github.com/behnamkhorsandian/Vanysh/watchers)
[![GitHub release downloads](https://img.shields.io/github/downloads/behnamkhorsandian/Vanysh/total?style=flat&logo=github&label=Release%20downloads)](https://github.com/behnamkhorsandian/Vanysh/releases)
[![GitHub issues](https://img.shields.io/github/issues/behnamkhorsandian/Vanysh?style=flat&logo=github&label=Open%20issues)](https://github.com/behnamkhorsandian/Vanysh/issues)
[![GitHub last commit](https://img.shields.io/github/last-commit/behnamkhorsandian/Vanysh?style=flat&logo=github&label=Last%20commit)](https://github.com/behnamkhorsandian/Vanysh/commits/main)

#### Cloudflare traffic (previous 30 days)

[![Unique visitors](https://img.shields.io/badge/Unique%20visitors-5.44k-F38020?style=flat&logo=cloudflare&logoColor=white)](https://www.vany.sh)
[![HTTP requests](https://img.shields.io/badge/HTTP%20requests-43%2C870-F38020?style=flat&logo=cloudflare&logoColor=white)](https://www.vany.sh)
[![Peak visitors per day](https://img.shields.io/badge/Peak%20visitors%2Fday-956-F38020?style=flat&logo=cloudflare&logoColor=white)](https://www.vany.sh)
[![Low visitors per day](https://img.shields.io/badge/Low%20visitors%2Fday-66-F38020?style=flat&logo=cloudflare&logoColor=white)](https://www.vany.sh)

Cloudflare figures are the latest 30-day snapshot published on the website. GitHub clone counts are available only to repository maintainers in the repository's **Insights → Traffic** view, so GitHub does not provide a public clone-count badge.

Multi-protocol censorship bypass toolkit. Pick a protocol, run one command on a VPS, and use that same command later to update, manage users, print connection configs, restart, or uninstall.

[![Screenshot of Vany TUI](https://raw.githubusercontent.com/behnamkhorsandian/Vanysh/main/github.png)](https://www.vany.sh)

## Three Entry Points

```bash
curl vany.sh                        # Browse protocol catalog (static ANSI page)
curl vany.sh/reality | sudo bash    # Install or manage one protocol on a VPS
curl vany.sh/tools/cfray | bash     # Client tools: scanners & diagnostics
```

### Offline: Cloak Desktop Client

Download the **[latest Cloak release](https://github.com/behnamkhorsandian/Vanysh/releases)** — a self-extracting archive that bundles the entire Vany suite for offline use.

```bash
chmod +x cloak-linux-amd64.sh && ./cloak-linux-amd64.sh
cloak                               # Launch TUI
cloak tmux                           # Launch in themed tmux session
cloak box                            # Encrypted dead-drop
cloak mirrors --rescue               # Find a way to reach vany.sh
```

Available for Linux (amd64/arm64), macOS (Intel/Apple Silicon), and Windows (WSL). See [docs/cloak.md](docs/cloak.md) for details.

## Protocol Catalog

### Server Protocols (install on VPS)

| Protocol | Transport | Domain | Resilience | Speed | Install |
|----------|-----------|--------|------------|-------|---------|
| Reality | VLESS+XTLS | No | High | Fast | `curl vany.sh/reality \| sudo bash` |
| WS+CDN | VLESS+WS | Yes (CF) | High | Medium | `curl vany.sh/ws \| sudo bash` |
| Hysteria v2 | QUIC/UDP | Optional | Medium | Very Fast | `curl vany.sh/hysteria \| sudo bash` |
| WireGuard | UDP | No | Low | Very Fast | `curl vany.sh/wg \| sudo bash` |
| V2Ray | VLESS+TLS | Yes | Medium | Fast | `curl vany.sh/vray \| sudo bash` |
| HTTP Obfs | WS+CDN + Clean IPs | Yes (CF) | Very High | Medium | `curl vany.sh/http-obfs \| sudo bash` |
| MTProto | Telegram Proxy | Optional | Medium | Fast | `curl vany.sh/mtp \| sudo bash` |
| SSH Tunnel | SSH SOCKS5 | No | Low | Fast | `curl vany.sh/ssh-tunnel \| sudo bash` |

### Emergency / DNS Tunnels

| Protocol | Transport | Domain | Resilience | Speed | Install |
|----------|-----------|--------|------------|-------|---------|
| DNSTT | DNS queries | Yes (NS) | Very High | Slow | `curl vany.sh/dnstt \| sudo bash` |
| Slipstream | DNS tunnel | Yes (NS) | Very High | Slow | `curl vany.sh/slipstream \| sudo bash` |
| NoizDNS | DNS (DPI-resistant) | Yes (NS) | Very High | Slow | `curl vany.sh/noizdns \| sudo bash` |

### Relay / Community

| Protocol | Type | Domain | Install |
|----------|------|--------|---------|
| Conduit | Psiphon relay | No | `curl vany.sh/conduit \| sudo bash` |
| Tor Bridge | obfs4 bridge | No | `curl vany.sh/tor-bridge \| sudo bash` |
| Snowflake | Tor relay proxy | No | `curl vany.sh/snowflake \| sudo bash` |
| SafeBox | Encrypted dead-drop | No | [vany.sh/box](https://vany.sh/box) |

### Client Tools (run from restricted network)

| Tool | Purpose | Command |
|------|---------|---------|
| CFRay | Find clean Cloudflare IPs | `curl vany.sh/tools/cfray \| bash` |
| FindNS | Discover accessible DNS resolvers | `curl vany.sh/tools/findns \| bash` |
| IP Tracer | Detect ISP, ASN, VPN leaks | `curl vany.sh/tools/tracer \| bash` |
| Speed Test | Bandwidth test via Cloudflare | `curl vany.sh/tools/speedtest \| bash` |

## Quick Start

### Server Setup (VPS owner)

```bash
# SSH into your VPS and pick a protocol:
curl vany.sh/reality | sudo bash

# Run the same command later for update, users, configs, logs, restart, or uninstall:
curl vany.sh/reality | sudo bash
```

### Client Connection (restricted country)

```bash
# Find clean Cloudflare IPs for HTTP Obfuscation:
curl vany.sh/tools/cfray | bash

# Check your connection:
curl vany.sh/tools/tracer | bash
```

Use connection links from your VPS in apps like **Hiddify**, **v2rayNG**, or **WireGuard**.

## Requirements

- **Server:** VPS with Ubuntu 20.04+ or Debian 11+, root access, 512MB RAM
- **Client tools:** Any terminal with `curl` and `bash`
- **Domain:** Required for WS+CDN, HTTP Obfs, DNS tunnels. Optional for others.

## Protocol Management

Every protocol route opens a guided manager for that protocol. The menu adapts to the current install state.

```bash
curl vany.sh/reality | sudo bash    # Reality install/update/users/config/logs/restart/uninstall
curl vany.sh/ws | sudo bash         # WS+CDN install/update/users/config/logs/restart/uninstall
curl vany.sh/wg | sudo bash         # WireGuard install/update/users/config/logs/restart/uninstall
```

The installer keeps runtime state in `/opt/vany/state.json` and users in `/opt/vany/users.json`.

## Client Apps

| Platform | Apps |
|----------|------|
| iOS | Hiddify, Shadowrocket, Streisand, WireGuard |
| Android | Hiddify, v2rayNG, WireGuard |
| Windows | Hiddify, v2rayN, WireGuard |
| macOS | Hiddify, V2rayU, WireGuard |
| Linux | v2rayA, WireGuard |

## Architecture

```text
curl vany.sh/<protocol> | sudo bash
    |
    v
Cloudflare Worker: workers/src/index.ts
    |
    v
scripts/direct-install.sh with VANY_PROTOCOL=<protocol>
    |
    v
scripts/docker-bootstrap.sh + scripts/lib/protocol-registry.sh
    |
    v
Docker runtimes on the VPS under /opt/vany
```

`scripts/lib/protocol-registry.sh` is the shared Bash protocol registry. It defines installer scripts, runtime names, containers, state keys, ports, user hooks, and uninstall hooks. Worker service metadata in `workers/src/index.ts` is kept in sync with the registry by CI.

Xray-family protocols share the `vany-xray` runtime. Reality, WS+CDN, HTTP Obfs, V2Ray, and MTProto each track their own feature state so uninstalling one does not stop Xray while another feature still uses it.

```text
Port 443 (TCP)
    +-> SNI: camouflage.com    -> Reality (VLESS+XTLS)
    +-> SNI: yourdomain.com    -> V2Ray (VLESS+TLS)
    +-> Path: /ws-path         -> WebSocket (VLESS+WS)
    +-> Fallback               -> Fake website

Port 8443 (UDP)                -> Hysteria v2 (QUIC)
Port 51820 (UDP)               -> WireGuard
Port 53 (UDP)                  -> DNS Tunnels (DNSTT/Slipstream/NoizDNS)
Port 9001 (TCP)                -> Tor Bridge (obfs4)
Port 22 (TCP)                  -> SSH Tunnel (SOCKS5)
```

## Development And Deployment

Normal development does not require local builds. Push changes and let GitHub Actions run the build, tests, and deployment.

| Workflow | Purpose |
|----------|---------|
| `deploy.yml` | Deploy Cloudflare Worker and Pages on relevant pushes to `main` |
| `protocol-smoke.yml` | Check shell syntax, registry drift, and Docker compose config |
| `spot-vm-watchdog.yml` | Restart the GCP Spot VM if it is preempted |
| `cloak-build.yml` | Build Cloak release archives on tags/manual dispatch |
| `sos-build.yml` | Build SOS release binaries on tags/manual dispatch |

Real protocol usability still needs disposable VM E2E tests. GitHub Actions can catch script, registry, Worker, and compose regressions, but it cannot fully prove public UDP, low ports, DNS delegation, Cloudflare CDN behavior, TUN/NET_ADMIN, iptables, or reboot persistence.

## Documentation

- **[Cloak Desktop Client](docs/cloak.md)** — Offline suite, install & usage
- [Project Overview](PROJECT_OVERVIEW.md)
- [Self-Hosting Guide](docs/self-hosting.md)
- [Firewall Setup](docs/firewall.md)
- [DNS Setup](docs/dns.md)
- [Workers Deployment](docs/workers.md)
- [Spot VM Recovery](docs/spot-vm-recovery.md)
- Protocol Guides: [Reality](docs/protocols/reality.md) | [WS+CDN](docs/protocols/ws.md) | [WireGuard](docs/protocols/wg.md) | [DNSTT](docs/protocols/dnstt.md) | [V2Ray](docs/protocols/vray.md) | [MTP](docs/protocols/mtp.md) | [Conduit](docs/protocols/conduit.md)

## License

MIT - See [LICENSE](LICENSE)

## Credits

- [Xray-core](https://github.com/XTLS/Xray-core)
- [Hysteria](https://github.com/apernet/hysteria)
- [dnstt](https://www.bamsoftware.com/software/dnstt/)
- [WireGuard](https://www.wireguard.com/)
- [Tor Project](https://www.torproject.org/)
- [Conduit](https://github.com/nickolasburr/conduit)
- [mtprotoproxy](https://github.com/alexbers/mtprotoproxy)
