# Tor bridge

A Tor bridge helps people connect to the Tor network. It is a community service.

## Before you start

Use a server with a public IP. Open TCP port 9001.

This is not a private Vany VPN. Check the Tor project guidance before sharing bridge details.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl vany.sh | sudo bash
   ```

3. Select this protocol. Press 1 to run the setup checks. Choose Install in the management menu.
4. Check the logs for the bridge line after startup.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Tor users need the bridge details in a compatible Tor client.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.

For terminal commands, operating system steps, DNS, and provider firewalls, see [network and provider setup](../network-setup.md).

For app setup on Windows, macOS, and Linux, see [connect a device](../connect-a-device.md).
