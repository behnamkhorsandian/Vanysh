# REALITY

REALITY provides a VLESS connection without a domain. It can help when direct VPN traffic is blocked.

## Before you start

Use a server with a public IP. Open TCP port 443.

No protocol can guarantee access on every network.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl vany.sh | sudo bash
   ```

3. Select this protocol. Press 1 to run the setup checks. Choose Install in the management menu.
4. Choose Add user after installation, then show the connection config.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Import the VLESS link into a compatible app, such as Hiddify.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.

For terminal commands, operating system steps, DNS, and provider firewalls, see [network and provider setup](../network-setup.md).

For app setup on Windows, macOS, and Linux, see [connect a device](../connect-a-device.md).
