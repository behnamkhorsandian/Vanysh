# SSH tunnel

An SSH tunnel provides a SOCKS proxy through your server.

## Before you start

You need SSH access to the server. Keep TCP port 22 open.

Some networks identify or block SSH. Test access before you depend on it.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl vany.sh | sudo bash
   ```

3. Select this protocol. Press 1 to run the setup checks. Choose Install in the management menu.
4. Follow the installer prompts and keep your existing SSH access available.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Configure each app to use the SOCKS proxy created by your SSH client. This is not a full-device VPN.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.

For terminal commands, operating system steps, DNS, and provider firewalls, see [network and provider setup](../network-setup.md).

For app setup on Windows, macOS, and Linux, see [connect a device](../connect-a-device.md).
