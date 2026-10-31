# Snowflake

Snowflake runs a volunteer relay that helps people reach the Tor network.

## Before you start

Use a server with internet access and enough bandwidth.

Your server provider may charge for relay traffic.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl -fsSL https://vany.sh/snowflake | sudo bash
   ```

3. Choose Install. Read each prompt before you continue.
4. Check the service logs after startup.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

Tor manages connections through the Snowflake network. There is no personal VPN link to share.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.
