# WireGuard

WireGuard creates an encrypted VPN connection for a device.

## Before you start

Use a server with a public IP. Open UDP port 51820.

Some networks block UDP or identify WireGuard traffic. Test from the network where the user needs it.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl -fsSL https://vany.sh/wg | sudo bash
   ```

3. Choose Install. Read each prompt before you continue.
4. Choose Add user to create a device configuration.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

The menu lists configuration file names. To show a file, replace `NAME` with the user name you created and run this command on the server:

```bash
sudo cat /opt/vany/wg/peers/NAME.conf
```

Save the output as a `.conf` file. Transfer it through a private channel. Import the file into the WireGuard app and connect. The file contains private keys, so do not post it publicly.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.
