# Start with Vany

Vany helps you create a service on a Linux server or connect from your device. Use the same command for both journeys:

```bash
curl vany.sh | sudo bash
```

On Windows, run it in an Ubuntu terminal in Windows Subsystem for Linux. On macOS, run it in Terminal. On Linux, run it in a terminal. To create a service on a remote server, connect to that server with SSH first and run the command there.

## Choose a protocol

1. Press C on the home page to open the chooser.
2. Select Connect or Create. Press one number for each answer.
3. If you are unsure about the network, choose the network check or skip it.
4. Open the suggested protocol. Its page offers Create and Connect.

Press Q at any chooser step to return. A protocol can be blocked even when a network check succeeds. Ask the server owner which protocol and app to use when you already have a connection.

## Create a service

You need an Ubuntu 20.04 or later server, or a Debian 11 or later server. You also need its public IP, SSH access, and permission to use `sudo`.

1. Connect to the server with SSH. Replace `SERVER_IP` with its address.

   ```bash
   ssh root@SERVER_IP
   ```

2. Run `curl vany.sh | sudo bash` on the server.
3. Select a protocol and press 1 for Create.
4. Read the local checks. If UFW is active, you can choose to add the required port rule.
5. Check the separate provider firewall and any domain records. See [network and provider setup](network-setup.md).
6. Continue to the service menu and choose Install.
7. Use the menu to add a user or show a connection config where supported.
8. Share the link or file through a private channel. Test it from a different network.

Not every service creates personal connections. Conduit, Tor bridge, and Snowflake are community relays. Some protocol installers or user actions are not implemented. Their guides identify those limits.

## Connect from a device

1. Ask the server owner for the protocol and its connection link or file.
2. Run `curl vany.sh | sudo bash` on your device. On Windows, run it in WSL.
3. Select the protocol and press 2 for Connect.
4. Follow the instructions for the compatible app. Import the link or file and connect in that app.
5. Keep the link or file private. It can contain credentials.

On Linux, Vany can start or stop WireGuard with `wg-quick` and a trusted configuration file. This can change routes and DNS. Vany can also start a local SSH SOCKS proxy using an existing trusted host key and key-based login. Configure each app to use that proxy.

On Windows, connect Windows applications with a Windows VPN app. A connection inside WSL may only affect WSL. The Linux header in WSL shows WSL metrics, not all Windows activity.

Vany does not yet start every protocol's client automatically. Some DNS tunnels need extra client and upstream setup. See [connect a device](connect-a-device.md) and the protocol's guide before you depend on it.

## Check status

Press S on the home page. The status page shows saved services and users when available. It also offers network checks, route tracing, speed testing, and Docker resource usage.

The header shows CPU, RAM, network activity, public IP, approximate location, UTC time, and local time when available. The location is estimated from your public IP using `ipinfo.io`. A VPN can change the IP and location shown. The checks contact public endpoints. A failed check can have many causes and does not prove censorship.

Use the arrow keys to browse. Press Page Up or Page Down for longer text. Press H for home and Q to quit. In a wizard, press Q to return.

For ports, operating system commands, DNS, and provider dashboards, see [network and provider setup](network-setup.md).
