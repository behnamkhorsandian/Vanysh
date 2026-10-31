# HTTP obfuscation

This option uses WebSocket and a Cloudflare domain with a selected Cloudflare IP address.

## Before you start

Use a domain on Cloudflare. Enable its proxy. Open TCP port 80.

The current setup uses Cloudflare Flexible mode. The connection from Cloudflare to the server does not use TLS.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl -fsSL https://vany.sh/http-obfs | sudo bash
   ```

3. Choose Install. Read each prompt before you continue.
4. Enter the Cloudflare domain when prompted.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

The client must use a reachable Cloudflare IP and the correct domain. The connection setup requires additional manual work.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.
