# NoizDNS

NoizDNS is a DNS tunnel based on DNSTT with added padding.

## Before you start

Use a domain you control. Delegate the tunnel DNS name to your server and open UDP port 53.

Do not run DNSTT or Slipstream on the same port. The manager does not yet show a complete client configuration.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl vany.sh | sudo bash
   ```

3. Select this protocol. Press 1 to run the setup checks. Choose Install in the management menu.
4. Enter the domain when prompted.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Use a compatible NoizDNS client and its required connection settings.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.

For terminal commands, operating system steps, DNS, and provider firewalls, see [network and provider setup](../network-setup.md).

For app setup on Windows, macOS, and Linux, see [connect a device](../connect-a-device.md).
