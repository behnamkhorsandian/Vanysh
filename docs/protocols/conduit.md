# Conduit

Conduit runs a volunteer relay for the Psiphon network. It is not a private VPN for your family.

## Before you start

Use a server with a public IP and sufficient bandwidth.

Your server provider may charge for relay traffic.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl -fsSL https://vany.sh/conduit | sudo bash
   ```

3. Choose Install. Read each prompt before you continue.
4. Choose View logs in the management menu to check the relay.

## Connect and manage

Psiphon manages client connections. You do not create personal users in this menu.

Run the same command again to view logs, restart, or remove the relay.

If the relay does not start, check the service logs and your server's internet connection. A running container does not guarantee that the relay can accept traffic.
