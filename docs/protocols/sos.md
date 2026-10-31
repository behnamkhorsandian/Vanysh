# SOS chat relay

SOS runs a relay for emergency chat. It is not a general VPN.

## Before you start

Use a server with a public IP. The relay uses TCP port 8899.

A DNS tunnel requires working DNS access. An internet shutdown can also prevent the relay from working.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl -fsSL https://vany.sh/sos | sudo bash
   ```

3. Choose Install. Read each prompt before you continue.
4. Check the service logs and the relay address after startup.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Use a compatible SOS client. A DNS tunnel needs separate setup if you want to reach the relay through DNS.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.
