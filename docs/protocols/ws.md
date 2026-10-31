# WebSocket with Cloudflare

This service sends VLESS connections through Cloudflare using WebSocket.

## Before you start

Use a domain on Cloudflare. Point its DNS record to your server and enable the Cloudflare proxy. Open TCP port 80.

The current setup uses Cloudflare Flexible mode. Traffic between Cloudflare and the server is not encrypted by TLS. Do not rely on it to protect that hop.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl vany.sh | sudo bash
   ```

3. Select this protocol. Press 1 to run the setup checks. Choose Install in the management menu.
4. Enter the Cloudflare domain when the menu asks for it.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Add a user and import its VLESS link into a compatible app.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.

For terminal commands, operating system steps, DNS, and provider firewalls, see [network and provider setup](../network-setup.md).

For app setup on Windows, macOS, and Linux, see [connect a device](../connect-a-device.md).
