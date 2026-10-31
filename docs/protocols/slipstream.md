# Slipstream

Slipstream is a DNS tunnel for a slow fallback connection.

## Before you start

Use a domain you control. Delegate the tunnel DNS name to your server and open UDP port 53.

Do not run DNSTT or NoizDNS on the same port. The manager does not yet show a complete client configuration.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl -fsSL https://vany.sh/slipstream | sudo bash
   ```

3. Choose Install. Read each prompt before you continue.
4. Enter the domain when prompted.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Use a compatible Slipstream client and its required connection settings.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.
