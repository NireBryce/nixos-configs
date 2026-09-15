# Known-dead secrets

Registry for skill `triage-flagged-secrets`. Each row is a secret that
`secrets-guard-posttooluse.sh` can re-flag from old git history or a
committed leak, already confirmed rotated/revoked and safe to recognize on
sight rather than re-investigate. Identified by **commit + path, never by
value** — nothing here reproduces the secret itself, since matching by
provenance (which command/commit surfaced it) is enough to recognize a
repeat hit without printing anything new.

Add a row only after actually confirming the key is dead (see skill, step
3) — this file existing is not itself permission to assume a *new* hit is
safe.

| Type | Found in (commit, path) | Removed in | Confirmed dead | Notes |
|---|---|---|---|---|
| Tailscale auth key (`tskey-...`) | `449d158f` (`nire-galatea/tskey`) | `8b78516d` | 2026-09-15 | ~2-year-old key from Jan 2024 ("struggling with sops again"); `nire-galatea` isn't a host in this repo's current roster (`hosts/hosts.nix`). Deleted from the tree one commit later but the blob is still reachable from history, so `git show`/`git log -p`/anything walking that commit or blob can re-surface it. |
