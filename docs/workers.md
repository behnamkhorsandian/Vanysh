# Cloudflare Workers And Pages Deployment

Vany uses one unified Cloudflare Worker for installer, tool, TUI, SafeBox, and stats routes. The public website is deployed separately to Cloudflare Pages from `www/`.

## Request Flow

```text
curl vany.sh/wg | sudo bash
        |
        v
Cloudflare Worker: workers/src/index.ts
        |
        v
Fetch scripts/direct-install.sh from GitHub Raw
        |
        v
Prepend VANY_PROTOCOL="wg" and return text/plain
```

The Worker routes browser users to `https://www.vany.sh/` and returns plain text for CLI user agents such as `curl` and `wget`.

## Important Routes

| Route | Purpose |
|-------|---------|
| `/` | ANSI landing page for CLI users; browser users redirect to `www` |
| `/<protocol>` | Standalone guided installer/manager for a known protocol |
| `/<protocol>/info` | Browser protocol info page |
| `/<protocol>/version` | JSON protocol metadata |
| `/scripts/*` | No-cache proxy to repository scripts |
| `/tools/<tool>` | Client-side scanner/diagnostic script |
| `/choose` | CLI protocol chooser |
| `/tui/*` | Server-rendered ANSI TUI pages |
| `/box` and `/box/<id>` | SafeBox web and CLI routes |
| `/health` | Worker health check |
| `/stats` | Worker KV counters |
| `/traffic-stats` | Cached and normalized Cloudflare zone analytics |

## Source Files

- `workers/src/index.ts` - main Worker router and service metadata.
- `workers/src/tui/` - ANSI UI renderer and TUI pages.
- `workers/src/safebox.ts` - SafeBox storage and retrieval handlers.
- `workers/src/vless.ts` - Worker-side VLESS/WebSocket support.
- `workers/wrangler.toml` - Worker name, compatibility date, routes, and KV binding.
- `workers/package.json` - Worker test and deploy commands.
- `www/index.html` - static Pages website.

## Deployment Workflow

Deployments are performed by GitHub Actions. Do not run local Wrangler deploys for normal development.

Required GitHub secrets:

| Secret | Purpose |
|--------|---------|
| `CF_API_TOKEN` | Cloudflare API token with Workers, Pages, zone read, and cache purge permissions |
| `CF_ACCOUNT_ID` | Cloudflare account ID |
| `CF_ZONE_ID` | Cloudflare zone ID for cache purge |
| `CF_ANALYTICS_TOKEN` | Read-only zone analytics token passed to the Worker as an encrypted secret |

Use a separate, least-privilege token for `CF_ANALYTICS_TOKEN`. Grant only
`Zone Analytics Read` for the Vanysh zone. The Worker keeps this token and the
zone ID server-side, then exposes only aggregate traffic counts through
`/traffic-stats`. Responses are cached at the edge for 15 minutes.

Workflow behavior:

- `.github/workflows/deploy.yml` runs on pushes to `main`.
- Worker changes run `npm ci`, `npm test`, then `wrangler deploy` in `workers/`.
- Website changes deploy `www/` with `wrangler pages deploy`.
- Script, Docker, TUI, Worker, or Pages changes purge Cloudflare cache as needed.

## CI Checks

- `.github/workflows/protocol-smoke.yml` validates shell syntax, registry drift, and Docker compose config.
- `scripts/tools/check-protocol-registry.sh` ensures Worker protocol keys match `scripts/lib/protocol-registry.sh`.
- `scripts/tools/protocol-smoke.sh` ensures every registered protocol has its installer script and runtime compose file where applicable.

## Manual Verification

After pushing, verify the actual workflow result rather than only checking dispatch:

```bash
gh run list --repo behnamkhorsandian/Vanysh --limit 10
gh run view <run-id> --log
```

Useful route checks after deploy:

```bash
curl -A curl -s https://vany.sh/wg | head
curl -s https://vany.sh/wg/version
curl -A curl -s https://vany.sh/tools/cfray | head
curl -s https://vany.sh/health
```

## Pages

The website lives in `www/` and deploys to the Cloudflare Pages project named `vany`.

Browser traffic:

```text
https://vany.sh      -> Worker redirect
https://www.vany.sh  -> Cloudflare Pages
```

The Pages project is created automatically by the deploy workflow if it does not already exist.

## Notes

- Worker routes intentionally use no-cache headers for installer scripts so VPS users get the latest command flow.
- The Worker fetches scripts from GitHub Raw; if that becomes a reliability bottleneck, add Worker cache or embed release artifacts.
- Real protocol usability still requires VM E2E tests. Worker and compose smoke tests do not prove public UDP, DNS delegation, Cloudflare CDN, TUN, or iptables behavior.
