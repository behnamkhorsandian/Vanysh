# Check your network and prepare a server

The Vany wizard can check local listeners and UFW, a Linux firewall. It can add a UFW rule when you choose that action. It cannot change your server provider's firewall or your domain records without access to those accounts.

Use the provider steps below when the wizard asks you to check a port or a domain. Provider screens can change. If a label differs, search your provider's help for the name of the setting.

## Choose the port

A port is a numbered entrance to a service. TCP and UDP are different transport types. Open only the port and transport your chosen service needs.

| Service | Default port | Domain |
| --- | --- | --- |
| REALITY | TCP 443 | Not required |
| WebSocket or HTTP obfuscation | TCP 80 on the server | Cloudflare domain required |
| WireGuard | UDP 51820 | Not required |
| Hysteria v2 | UDP 8443 | Not required |
| DNSTT, Slipstream, or NoizDNS | UDP 53 | Domain and DNS delegation required |
| SSH tunnel | TCP 22 | Not required |
| Tor bridge | TCP 9001 | Not required |
| SOS relay | TCP 8899 | Not required |
| Conduit or Snowflake | No fixed port in Vany | Not required |

Only one DNS tunnel can use port 53 on the same server. VLESS with TLS and MTProto server setup are not implemented in the current Docker manager. A service may also need outbound access. Check its guide before you change firewall rules.

## Use the Vany checks

1. Run `curl vany.sh | sudo bash` in the terminal.
2. Press C for the chooser or select a protocol with the arrow keys.
3. Press 1 to create a service. The wizard checks the local port and UFW status.
4. Press 1 to add the displayed rule to an active UFW firewall. Vany does not enable UFW.
5. Press 2 to continue to the service menu. Press Q to cancel.
6. Check the provider firewall as described below. A local rule does not open a provider firewall.

Press S on the Vany home page for status. Press N for public endpoint, DNS, latency, and packet loss checks. Press T for a speed test. Press P for a route trace. Press M for Docker resource usage. The checks cannot prove censorship or guarantee that a protocol works. A route trace may omit hops that do not answer.

When WireGuard is running, the status page can show each peer's received and sent traffic from the server's perspective. The counters reset when the interface restarts. Vany does not currently have reliable per-user traffic for the other protocols.

Vany requests public IP and approximate location from `ipinfo.io`. The IP may belong to your VPN or proxy. The network checks contact Cloudflare and Google. The speed test downloads data from Cloudflare and may use significant bandwidth.

## Commands used by the wizard

Run these on Linux if you want to inspect the same information yourself. A listener means a local process uses the port. It does not prove that the port is reachable from the internet. No listener is normal before installation.

```bash
# Public IP and approximate location
curl --max-time 3 https://ipinfo.io/json

# Local TCP and UDP listeners
ss -lnt
ss -lnu

# Status of the local UFW firewall
sudo ufw status

# Add the REALITY rule to an active UFW firewall
sudo ufw allow 443/tcp

# Check public endpoints and packet loss
ping -c 2 -W 2 1.1.1.1
ping -c 2 -W 2 8.8.8.8

# Check DNS through a specific public resolver, if dig is installed
dig +short +time=2 +tries=1 @1.1.1.1 example.com A

# Check HTTPS response and elapsed time
curl -sS -o /dev/null --connect-timeout 3 --max-time 6 -w 'HTTP %{http_code}, %{time_total} seconds\n' https://www.cloudflare.com

# Show a short route, if traceroute is installed
traceroute -m 8 -q 1 -w 1 1.1.1.1

# Show resource usage, if Docker is installed
docker stats --no-stream
```

Replace `443/tcp` with the port and transport for your service. Do not enable UFW until you allow your SSH access. Enabling a firewall without an SSH rule can lock you out.

For speed, Vany uses its Cloudflare speed test. The test downloads data and reports a measurement for the connection at that time. In the macOS menu, Vany downloads about 5 MB from `https://speed.cloudflare.com/__down?bytes=5000000`.

## Windows

Install Windows Subsystem for Linux and an Ubuntu distribution from Microsoft's [WSL installation guide](https://learn.microsoft.com/windows/wsl/install). Open Ubuntu from the Start menu and run `curl vany.sh | sudo bash` there. For a service on a remote server, use SSH to connect to that server first, then run the same command.

For a personal connection on Windows, import the link or file into the appropriate Windows app. WSL has its own network environment. A connection inside WSL does not necessarily route Windows applications through the VPN.

In PowerShell, these commands check basic DNS, ICMP, and a TCP port. Replace the example address with your server address. The TCP check does not test UDP.

```powershell
Resolve-DnsName example.com
ping 1.1.1.1
Test-NetConnection SERVER_IP -Port 443
tracert 1.1.1.1
```

## macOS

Open Terminal. Run `curl vany.sh | sudo bash` for the client menu. To create a service, connect to your Linux server with SSH and run the same command there. Import a connection link or file into the app recommended by the server owner.

```bash
curl --max-time 3 https://ipinfo.io/json
ping -c 2 -W 2000 1.1.1.1
dig +short +time=2 +tries=1 @1.1.1.1 example.com A
traceroute -m 8 -q 1 -w 1 1.1.1.1
```

The macOS menu shows interface counters, not a per-user traffic total. Use its Status menu for the speed test and network checks.

## Linux

Open a terminal and run `curl vany.sh | sudo bash`. Select Connect for client instructions. The WireGuard page can use `wg-quick` with a trusted `.conf` file if the tool is installed. It can change routes and DNS. Vany rejects files with shell hooks or `SaveConfig` for this action.

The SSH tunnel page can start a local SOCKS proxy with a trusted host key and key-based login. The proxy uses `127.0.0.1:1080`. Configure each application to use that proxy. Press Q in the tunnel screen to stop it.

For other protocols, import the owner's link or file into a compatible application. Vany does not yet start every client itself. When you administer a remote server, SSH to it before you select Create.

## Open a port at your server provider

Allow the exact transport and destination port from the table. If you restrict source addresses, include the networks that your users connect from. Keep SSH access restricted to trusted administrator addresses where practical.

### DigitalOcean

1. Open the DigitalOcean control panel and select Networking, then Firewalls.
2. Create a firewall or select the firewall attached to your Droplet.
3. Add an inbound rule with the required TCP or UDP port and allowed sources.
4. Attach the firewall to the correct Droplet and save the rule.
5. Check the Droplet's own firewall too.

### AWS EC2

1. Open EC2 and select your instance.
2. Open its Security tab and select the attached security group.
3. Edit inbound rules. Add the required TCP or UDP port and allowed source range.
4. Save the rule. Confirm that the instance has a public IP and the subnet route allows internet access.
5. If the subnet uses a restrictive network ACL, allow the required inbound and return traffic there too.

### Hetzner Cloud

1. Open the Cloud Console and select the project and server.
2. Open Firewalls. Create or select the firewall for that server.
3. Add an inbound TCP or UDP rule for the required port and source range.
4. Apply the firewall to the server and save the changes.
5. Check the server's own firewall too.

### Vultr

1. Open the Vultr customer portal and select Firewall.
2. Create or select a firewall group.
3. Add an inbound rule for the required protocol, port, and source range.
4. Attach the group to the correct server and save it.
5. Check the server's own firewall too.

### Google Cloud

1. Open the Google Cloud console and select the correct project.
2. Open VPC network, then Firewall. Create an ingress rule.
3. Select the VPC network used by the VM and a target such as its network tag.
4. Set the allowed source ranges and the required TCP or UDP port.
5. Save the rule. Confirm that the target matches the VM and that the VM has a reachable external IP.
6. Check the VM's own firewall too.

## Set up a domain

A domain is a name such as `example.com`. Your DNS provider stores records that point names to addresses. Find out which company hosts your DNS before you edit records. A registrar and a DNS provider can be different companies.

### Cloudflare

1. Add your domain to Cloudflare and follow Cloudflare's nameserver instructions at your registrar.
2. Open DNS, then Records for the domain.
3. For WebSocket, create an A record for your chosen name that points to the server's public IPv4 address. Enable the Cloudflare proxy for that record.
4. The current Vany WebSocket origin uses HTTP on port 80. Cloudflare Flexible mode does not encrypt the Cloudflare-to-server hop. Do not use this setup when that hop must have TLS. Full or Full strict needs a TLS-enabled origin and will not work with the current HTTP-only origin as is.
5. For a DNS tunnel, use DNS-only records. Create an A record such as `ns1.example.com` pointing to the server. Create an NS record for a delegated name such as `t.example.com` pointing to `ns1.example.com`.
6. Wait for the records to update. Query the delegated name and check that UDP port 53 reaches your server.

DNS tunnel setup needs a compatible client. DNSTT also needs a separate service listening at its configured upstream address. See the [DNSTT guide](protocols/dnstt.md).

### Namecheap

1. Sign in to Namecheap and open Domain List. Select Manage for your domain.
2. If Namecheap hosts your DNS, open Advanced DNS and add the needed A or NS records.
3. If another provider hosts DNS, edit records at that provider instead. To use Cloudflare DNS, first follow Cloudflare's nameserver instructions and update the nameservers at Namecheap.
4. Save the records and allow time for DNS updates.

### GoDaddy

1. Sign in to GoDaddy and open the domain's DNS management page.
2. If GoDaddy hosts your DNS, add the required A or NS records there.
3. If another provider hosts DNS, edit records at that provider instead. To use Cloudflare DNS, first follow Cloudflare's nameserver instructions and update the nameservers at GoDaddy.
4. Save the records and allow time for DNS updates. If the DNS editor does not support the required subdomain delegation, ask the provider or use a DNS host that supports NS delegation.

## Check the result

After installation, select the protocol and inspect its logs. Test from another network using the connection link or file. For TCP, a remote `nc -vz SERVER_IP PORT` can check whether a port accepts a connection. It does not establish that the VPN works. UDP needs a protocol-specific client test.

Do not post connection links, WireGuard configuration files, private keys, or passwords in public logs or support requests.
