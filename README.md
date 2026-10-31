# Vanysh

[![Deploy](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/deploy.yml/badge.svg)](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/deploy.yml)
[![Protocol Smoke](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/protocol-smoke.yml/badge.svg)](https://github.com/behnamkhorsandian/Vanysh/actions/workflows/protocol-smoke.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Vany helps you create a connection on your own Linux server or connect to a service someone else created. It also offers network checks and community relay options.

## Start

Run this command in a terminal:

```bash
curl vany.sh | sudo bash
```

To create a service on a remote server, connect to the server with SSH first and run the command there. To connect from Windows, open an Ubuntu terminal in Windows Subsystem for Linux. On macOS, use Terminal.

Press C for help choosing a protocol. On a protocol page, press 1 to create or manage a service, or 2 to connect. Press S for status and network checks. Press Q to leave a wizard.

The Linux menu can start WireGuard with a trusted configuration file and can start an SSH SOCKS proxy with an existing key. Other connections use compatible client apps. The menu explains the needed app and settings. Some protocol installers and management actions are not implemented. See the relevant guide before setup.

## Guides

- [Start with Vany](docs/getting-started.md)
- [Connect a device](docs/connect-a-device.md)
- [Network checks, ports, DNS, and provider setup](docs/network-setup.md)
- [REALITY](docs/protocols/reality.md), [WebSocket](docs/protocols/ws.md), [WireGuard](docs/protocols/wg.md), [Hysteria](docs/protocols/hysteria.md), and [SSH](docs/protocols/ssh-tunnel.md)
- [DNSTT](docs/protocols/dnstt.md), [Slipstream](docs/protocols/slipstream.md), and [NoizDNS](docs/protocols/noizdns.md)
- [Conduit](docs/protocols/conduit.md), [Tor bridge](docs/protocols/tor-bridge.md), [Snowflake](docs/protocols/snowflake.md), and [SOS chat](docs/protocols/sos.md)
- [HTTP obfuscation](docs/protocols/http-obfs.md), [VLESS with TLS](docs/protocols/vray.md), and [MTProto](docs/protocols/mtp.md)
- [Cloak offline client](docs/cloak.md) and [host the Vany platform](docs/self-hosting.md)

Conduit, Tor bridge, and Snowflake are community relays. They do not create a private family VPN. DNS tunnels require a domain and extra setup. No protocol is guaranteed to work on every network.

## Development and deployment

GitHub Actions deploys the Worker and website after relevant changes reach `main`. The protocol smoke workflow checks shell syntax, registry drift, and Docker Compose configuration. The Worker deployment runs the Worker test suite.

The terminal loads its pages from the repository. Server operations use the Docker protocol manager and the shared registry in `scripts/lib/protocol-registry.sh`. State is stored under `/opt/vany` on the server.

Automated checks cannot prove public port reachability, DNS delegation, client connectivity, or behavior on every server provider. Use a disposable Linux server and an actual client when validating protocol changes.

See [self-hosting](docs/self-hosting.md) for deployment configuration, [workers](docs/workers.md) for Worker details, and [spot VM recovery](docs/spot-vm-recovery.md) for the recovery setup.

## License

MIT. See [LICENSE](LICENSE).
