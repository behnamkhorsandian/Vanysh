# DNSTT

DNSTT carries traffic through DNS queries. It is a slow fallback when DNS still works.

## Before you start

Use a domain you control. Open UDP port 53 on the server and in the provider firewall.

For example, create an A record for `ns1.example.com` that points to the server IP. Create an NS record for `t.example.com` that points to `ns1.example.com`. Replace `example.com` with your domain. The DNS records must not use a Cloudflare proxy.

Do not run another DNS tunnel on the same port. A network can block DNS tunnels, and DNS access alone does not guarantee a working connection.

## Set up the service

1. Connect to your Linux server with SSH.
2. Run the command below.

   ```bash
   curl -fsSL https://vany.sh/dnstt | sudo bash
   ```

3. Choose Install. Read each prompt before you continue.
4. Enter the delegated name, such as `t.example.com`.
5. Check the service logs in the management menu. Test the connection from another network.

## Connect and manage

DNSTT needs a compatible client, the delegated name, and the server public key. The server forwards connections to `127.0.0.1:10800` by default. You must separately provide a service at that address. The manager does not configure it. DNSTT is not a one-click phone VPN.

Run the same command again to open the management menu. The menu shows which actions are available. Keep connection credentials private.

If a connection fails, check your provider firewall, the server firewall, and the service logs. A running container does not guarantee a working connection.
