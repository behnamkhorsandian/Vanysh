# Self-Hosting Vany

This guide describes how to run your own Vany installer platform with a custom domain, Cloudflare Worker, Cloudflare Pages, and GitHub Actions.

## Architecture

```text
VPS owner
  curl yourdomain.com/reality | sudo bash
        |
        v
Cloudflare Worker
  serves scripts/direct-install.sh with VANY_PROTOCOL="reality"
        |
        v
GitHub repository
  scripts, Docker compose files, Worker source, Pages website
```

The VPS installer then downloads `scripts/docker-bootstrap.sh`, protocol scripts, the protocol registry, and Docker compose files into `/opt/vany`.

## Prerequisites

- A GitHub fork of this repository.
- A domain added to Cloudflare.
- GitHub repository secrets for Cloudflare deployment.
- A test VPS for real protocol E2E checks.

You do not need local Node modules, local Docker builds, or local Wrangler deploys for normal development. Push to GitHub and let Actions deploy.

## Cloudflare Setup

1. Add your domain to Cloudflare.
2. Point your registrar nameservers to Cloudflare.
3. Create a Cloudflare API token with permissions for Workers, Pages, zone read, and cache purge.
4. Add these GitHub secrets:

| Secret | Purpose |
|--------|---------|
| `CF_API_TOKEN` | Cloudflare API authentication |
| `CF_ACCOUNT_ID` | Cloudflare account ID |
| `CF_ZONE_ID` | Zone ID for your domain |

Set secrets without printing values:

```bash
gh secret set CF_API_TOKEN --repo OWNER/REPO --body "$(cat cf-token.txt)"
gh secret set CF_ACCOUNT_ID --repo OWNER/REPO --body "<account-id>"
gh secret set CF_ZONE_ID --repo OWNER/REPO --body "<zone-id>"
```

## Repository Configuration

Update these files for your fork/domain:

- `workers/src/index.ts` - GitHub Raw base URL, service metadata, public domain references.
- `workers/wrangler.toml` - Worker name, routes, KV namespace IDs, compatibility date.
- `www/index.html` - website copy and domain references.
- `scripts/lib/protocol-registry.sh` - protocol registry if you add/remove protocols.
- `.github/workflows/deploy.yml` - Pages project name if you do not use `vany`.

## Deploy

Push to `main`:

```bash
git push origin main
```

GitHub Actions will:

1. Detect changed paths.
2. Run Worker tests for Worker changes.
3. Deploy the Worker with Wrangler.
4. Deploy `www/` to Cloudflare Pages.
5. Purge Cloudflare cache when scripts, Docker, TUI, Worker, or Pages files change.

Monitor with:

```bash
gh run list --repo OWNER/REPO --limit 10
gh run view <run-id> --log
```

## Test The Installer Routes

After deployment:

```bash
curl -A curl -s https://yourdomain.com/reality | head
curl -A curl -s https://yourdomain.com/tools/cfray | head
curl -s https://yourdomain.com/health
curl -s https://yourdomain.com/reality/version
```

The protocol route should return a Bash script containing `VANY_PROTOCOL="reality"`.

## Test On A VM

Use a disposable Ubuntu/Debian VPS for real protocol testing:

```bash
curl yourdomain.com/reality | sudo bash
```

Then use the guided menu to install, add a user, print a connection config, restart, update/repair, remove the user, and uninstall.

VM tests are required for production confidence because GitHub Actions containers cannot fully prove public IP reachability, low ports, UDP, DNS delegation, Cloudflare CDN behavior, TUN/NET_ADMIN, iptables, or reboot persistence.

Recommended test order:

1. SSH tunnel or another low-risk protocol.
2. Reality or WS+CDN.
3. One DNS tunnel.
4. WireGuard last, because it changes host networking and iptables.

## Adding A Protocol

Additive protocol changes should touch these surfaces:

1. `scripts/lib/protocol-registry.sh` - metadata and lifecycle hooks.
2. `scripts/protocols/install-<protocol>.sh` - install/manage/remove behavior.
3. `docker/<runtime>/docker-compose.yml` - runtime definition if containerized.
4. `workers/src/index.ts` - Worker service metadata.
5. `docs/protocols/<protocol>.md` - user-facing notes.
6. Tests or smoke checks for route/registry coverage.

Run no local builds unless explicitly needed. Let GitHub Actions validate registry drift and compose config.

## Runtime Files On The VPS

```text
/opt/vany/
  state.json
  users.json
  docker/
  scripts/
  xray/
  wg/
  dnstt/
  hysteria/
  slipstream/
  noizdns/
  tor-bridge/
  sos/
```

## Troubleshooting

| Problem | Check |
|---------|-------|
| Protocol route returns 404 | Worker `SERVICES` keys and Bash registry drift check |
| Installer downloads old code | Cloudflare cache purge and GitHub Raw cache delay |
| Pages site not updated | `deploy.yml` Pages job logs |
| Worker deploy failed | `workers` tests and Wrangler logs in GitHub Actions |
| Protocol installs but cannot connect | Run VM E2E logs; check firewall, DNS, ports, and client config |
| DNS tunnel conflicts | Only one port 53 protocol can run until DNS edge routing exists |
| WireGuard breaks connectivity | Restore from VM snapshot or use dedicated VM; test WireGuard last |