# Start your own Vany server

Vany helps you set up a connection on a server that you control. You can share access with friends and family.

## Before you start

- Get a Linux server with a public IP address. Ubuntu 20.04 or later and Debian 11 or later are supported.
- Get the server's IP address and SSH login details from your server provider.
- Make sure you can use `sudo` on the server.
- Check the server provider's firewall. Open the port for the protocol you choose.

A protocol is the method your devices use to connect. Start with REALITY if you do not know which one to choose. It does not need a domain. A network can still block it.

## Open Vany

1. Open a terminal on your computer.
2. Connect to your server with SSH. Replace the example address with your server's address.

   ```bash
   ssh root@SERVER_IP
   ```

3. Run this command on the server.

   ```bash
   curl -fsSL https://vany.sh | sudo bash
   ```

4. Read the home page. Press Enter to browse protocols, or press C for help choosing one.
5. Use the arrow keys to select a protocol. Press Enter to open its setup or management menu.
6. Follow the prompts. Open the required port in your provider's firewall as well as the server firewall.

Press H to return home. Press S to view saved service status. Press Q to quit. Use Page Up and Page Down to read longer pages.

## Give someone access

1. Open the protocol's management menu again.
2. Choose Add user if that option is supported for your protocol.
3. Choose Show connection config if it is available. Some protocols need additional manual setup.
4. Send the connection link or file through a private channel. Anyone with the credentials may be able to use the service.
5. Ask the person to import the link or file into a compatible app and connect.
6. Test the connection from a different network. A running service does not prove that a device can reach it.

For REALITY, see the [REALITY guide](protocols/reality.md). For WireGuard, see the [WireGuard guide](protocols/wg.md).

## Manage an existing service

Run the same Vany command on your server. Select the protocol you installed. Its menu offers the available actions, such as logs, restart, or removal. Some actions are not implemented for every protocol.

If a connection fails, check the service logs and the provider firewall. Check the protocol guide for its port and domain requirements. Do not share logs that contain passwords or connection links.

## Connect from your own device

Run `curl -fsSL https://vany.sh | bash` without `sudo` for client help and network tools. This menu does not connect your device. Use a compatible app with the link or file from your server owner.
