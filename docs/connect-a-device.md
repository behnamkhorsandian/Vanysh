# Connect a device

Ask the server owner which protocol to use and send you its connection link or file through a private channel. The server and device must use compatible settings. A protocol name alone is not enough to connect.

Run `curl vany.sh | sudo bash` in your terminal. Select the protocol and press 2 for Connect. Vany explains the next steps. On Windows, use an Ubuntu terminal in WSL for the Vany menu.

| Connection | What the device needs | What Vany can start |
| --- | --- | --- |
| REALITY, WebSocket, VLESS with TLS, HTTP obfuscation | A compatible VLESS app and the owner's link | App guidance |
| WireGuard | The owner's `.conf` file and WireGuard | Linux `wg-quick`, if installed, or app guidance |
| Hysteria v2 | A compatible Hysteria v2 app and the owner's link | App guidance |
| MTProto | Telegram and an MTProto link | App guidance |
| SSH tunnel | An SSH login and an app with SOCKS support | A Linux SOCKS proxy with a trusted host key and key-based login |
| DNSTT, Slipstream, NoizDNS | The matching client, domain, key, and settings | App guidance. The owner must provide client setup details |
| SOS | A compatible SOS chat client and relay details | App guidance |
| Conduit, Tor bridge, Snowflake | Psiphon or Tor Browser | Community relay guidance. These are not private Vany connections |

A VLESS link can use different transports. Ask the owner whether it uses REALITY, WebSocket, or another transport. A network check cannot identify the correct settings.

## Windows

1. Install the matching Windows app. For WireGuard, use the [official WireGuard download](https://www.wireguard.com/install/). For compatible VLESS or Hysteria links, see the [Hiddify releases](https://github.com/hiddify/hiddify-app/releases).
2. Open the app and use its import option to add the link or file.
3. Connect in the app. Accept any operating system permission only after you trust the app and the source of the configuration.
4. Open a website or app to check the connection. Ask the owner for help if it fails.

The Vany terminal runs in WSL. Its Linux network changes may affect WSL only. Use a Windows VPN app when you want Windows applications to use the connection.

## macOS

1. Install the matching macOS app. For WireGuard, use the [official WireGuard download](https://www.wireguard.com/install/). For compatible VLESS or Hysteria links, see the [Hiddify releases](https://github.com/hiddify/hiddify-app/releases).
2. Open the app and import the owner's link or file.
3. Connect in the app. macOS may ask for permission to add a VPN configuration.
4. Check the connection in an app or browser.

The macOS Vany menu provides guidance and checks. It does not start these client apps automatically.

## Linux

For an app-based connection, install the matching Linux client, import the link or file, and connect in that app. See [WireGuard](https://www.wireguard.com/install/) or the [Hiddify releases](https://github.com/hiddify/hiddify-app/releases).

For WireGuard, Vany can also call `wg-quick` when the tool is installed. On the WireGuard page, select Connect, then select the Linux connect action. Enter the path to a trusted `.conf` file. Review the warning and confirm. Use the disconnect action with the same file to stop it. Vany rejects files with shell hooks or `SaveConfig` for this action. `wg-quick` can change routes and DNS, and it can interrupt a remote SSH session.

For an SSH SOCKS proxy, first verify the server's SSH host key with the owner and set up key-based login. On the SSH page, select Connect and start the proxy. Enter `USER@SERVER`. Vany starts a proxy at `127.0.0.1:1080` when the login succeeds. Configure each application to use that SOCKS proxy. Press Q in the tunnel screen to stop it. This proxy does not automatically route all applications.

## If the connection fails

1. Confirm the protocol and connection settings with the owner.
2. Check that the app supports that protocol and transport.
3. Ask the owner to check the server logs and provider firewall.
4. On Vany's status page, run the network checks. A failure can have many causes and does not by itself prove a block.
5. Test the connection from another network if possible.

Keep links, configuration files, passwords, and private keys out of public support messages. For ports and provider steps, see [network and provider setup](network-setup.md).
