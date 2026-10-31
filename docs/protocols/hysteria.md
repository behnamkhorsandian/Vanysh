# Hysteria v2

Hysteria provides a connection over UDP. It can help on networks with packet loss.

## Before you start

Use a server with a public IP. Open UDP port 8443.

The current setup uses a self-signed certificate and a shared password. The generated link allows an unverified certificate. Protect the link and verify connections through a trusted channel.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl -fsSL https://vany.sh/hysteria | sudo bash
   ```

3. Choose Install. Read each prompt before you continue.
4. Save the connection link shown during setup.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Import the link into a compatible Hysteria v2 app, such as Hiddify.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.
