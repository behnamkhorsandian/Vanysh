# Secret Exposure Audit — 2026-08-04

## Scope and limitations

This audit covers the 265 tracked files and all 242 commits available in the
local clone. It looks specifically for committed credentials and for workflow
patterns that could disclose GitHub Actions secrets. Protocol design and
implementation are intentionally out of scope for this first layer.

The public GitHub Actions logs could not be downloaded from the audit
environment because outbound access to GitHub was denied and no authenticated
GitHub CLI session was available. Consequently, this report does **not** claim
that historical logs were inspected. A repository administrator must complete
the log-review checklist below.

## Results

### Current source tree

No live credential was identified in the tracked source tree.

The scan checked for private-key blocks and recognizable GitHub, AWS, Google,
Slack, Stripe, JWT, Cloudflare, and generic credential-assignment formats.
Candidates were manually classified as package-lock integrity hashes, bundled
font/binary data, documented placeholders, or test fixtures. `.env.example`
contains placeholders only.

### Git history

No live credential was identified in the Git objects reachable from the 242
locally available commits. The same credential patterns were applied to 1,005
unique blobs.

Three historical `.env.example` blobs contain the literal line
`-----BEGIN OPENSSH PRIVATE KEY-----`, but the surrounding text is documentation
and the body is the explicit placeholder `... (the key content) ...`; it is not
a usable key. Other candidates were dependency integrity hashes or test data.

This conclusion applies only to refs present in this clone. Deleted remote
branches, pull-request refs, forks, releases, issue attachments, and unreachable
objects were not available for inspection.

### GitHub Actions and logs

The workflow definitions use the GitHub `secrets` context rather than literal
credentials. Two avoidable logging paths were found and remediated:

1. The Cloudflare cache-purge step printed the complete API error response.
   Provider responses should be treated as sensitive diagnostic data.
2. The SOS build printed the value of `SOS_RELAY_HOST`, despite obtaining it
   from the secrets context. It now prints only whether a value was supplied.

GitHub normally masks exact registered secret values, but masking is a safety
net rather than a guarantee: transformed values, structured secrets, and values
not registered with GitHub can still appear in logs.

## Preventive controls added

- A Gitleaks workflow scans the complete checked-out history on pushes to
  `main`, pull requests, and manual runs.
- Workflow permissions are explicitly read-only for that scan.
- Known diagnostic output paths no longer print secret-derived values or full
  provider responses.

## Required administrator follow-up

1. In **Actions**, inspect and download every retained run log, especially
   `Deploy`, `Build SOS Binaries`, and `Spot VM Watchdog`. Search both plain and
   encoded/fragmented forms of every current and retired credential.
2. Review repository, environment, and organization Actions secrets; remove
   unused entries and rotate credentials that have ever been printed, copied
   into an artifact, or shared outside the secret store.
3. Inspect Actions artifacts and releases. SOS binaries intentionally embed the
   DNSTT public key and relay endpoint; confirm these values are non-secret and
   name/store them accordingly to avoid a false confidentiality assumption.
4. Review audit logs for secret reads, workflow changes, unexpected deployments,
   and credential use from unfamiliar IP addresses.
5. Enable GitHub secret scanning and push protection (including validity checks,
   where available) in repository security settings.
6. If a credential is found, revoke it first, review provider access logs, issue
   a least-privilege replacement, delete affected logs/artifacts, and only then
   consider history rewriting. History rewriting alone does not revoke a secret.

## Risk conclusion

- **Tracked code:** no exposed live secret found; moderate confidence.
- **Reachable local history:** no exposed live secret found; moderate confidence.
- **Historical Actions logs/artifacts:** not verified; status unknown until an
  administrator performs the required review.

This is a point-in-time secret-exposure review, not a guarantee that credentials
were never exposed or that the protocol implementations are secure.
