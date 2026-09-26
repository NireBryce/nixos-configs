# `git-forge` — history

_Last modified: 2026-09-26_

Verification record for [git-forge](git-forge.md) as it was first switched
and then re-routed, split out 2026-09-03 so that page stays about the
category as it works today.

## Contents

- [First switch and the move behind Caddy](#first-switch-and-the-move-behind-caddy)
- [The brief `0.0.0.0` window](#the-brief-0000-window)
- [The admin account, and an anonymous API that reports zeroes](#the-admin-account-and-an-anonymous-api-that-reports-zeroes)
- [Mirror, not origin — and the first real mirror](#mirror-not-origin--and-the-first-real-mirror)
- [The long-lived runner, 2026-09-24 to 2026-09-26](#the-long-lived-runner-2026-09-24-to-2026-09-26)
- [See also](#see-also)

## First switch and the move behind Caddy

Confirmed working end to end on the first real switch, 2026-08-24: `just
switch` came up with 0 failed units, `forgejo-secrets.service` exited
`0/SUCCESS`, `forgejo.service` stayed `active (running)` past its first
40s, and `http://ts-cube:3001/` answered `HTTP 200` from another tailnet
host.

That URL stopped being current the same day: Forgejo moved behind Caddy
([reverse-proxy](reverse-proxy.md)), listening on `127.0.0.1:3001` and
reached at `https://ts-cube.moose-micro.ts.net/git/` instead. The proxied
arrangement was confirmed working too, same day — 200 over validated TLS
from another tailnet host, generated links carrying `/git/`, assets
loading. Getting there took a second switch: the first served Forgejo the
un-stripped prefix and it 404'd everything —
[reverse-proxy](reverse-proxy.md) has that writeup. Git+ssh over the
host's own OpenSSH was not exercised in this pass; only the HTTP side was
confirmed.

## The brief `0.0.0.0` window

Forgejo bound `0.0.0.0` for its first few hours (2026-08-24), when
`trustedInterfaces = [ "tailscale0" ]` ([system](system.md)) was the only
thing between port 3001 and the LAN. It binds `127.0.0.1` now, with Caddy
the only client. `forgejo.nix`'s own history note has the before/after.

One knock-on the move fixed quietly: `LOCAL_ROOT_URL` defaults to
`http://%(HTTP_ADDR)s:%(HTTP_PORT)s/` and nixpkgs doesn't override it, so
under `0.0.0.0` it built self-referential URLs from an any-address; it
resolves to `http://127.0.0.1:3001/` now.

## The admin account, and an anonymous API that reports zeroes

Moved here 2026-09-12 from `homelab/pending-setup.md` item 1, whose
setup half is finished. The account itself: as of 2026-08-24
`GET /git/api/v1/users/search` returned `{"data":[],"ok":true}` — the forge
up, serving, and completely empty, with registration closed so the first
account needed a manual command. 2026-08-26 `forgejo-admin-bootstrap`
(see [git-forge.md](git-forge.md)) automated it, creating the `elly`/admin
account declaratively on activation.

**The trap, and it cost two sessions.** The unauthenticated
`GET /git/api/v1/users/search` always reports `last_login` as the zero value
(`0001-01-01T00:00:00Z`) and `is_admin`/`active` as `false` — Forgejo/Gitea's
anonymous-safe field masking, not a read of account state. Two agent sessions
(2026-09-04, 2026-09-05) took the zero value at face value and wrote "nobody
has signed in yet" into `pending-setup.md` and the backup runbook. Wrong both
times: a same-day screenshot from the user showed an active, logged-in session
throughout. Re-running the query with the user actively logged in returns the
same zeroes, confirming the field is not meaningful from this endpoint rather
than that anything changed. The account existing was real; the conclusion
drawn from an anonymous call was not.

**The account is admin — confirmed by the user 2026-09-12**, from the Site
Administration panel, which was the only place that could answer it. The
masked `is_admin: false` neither proved nor disproved anything; two
sessions treating it as an answer is what this section exists to record.

## Mirror, not origin — and the first real mirror

Moved here 2026-09-12 from `homelab/pending-setup.md` item 2, which is
settled: mirror, reaffirmed the same day.

**Mirror was chosen 2026-09-03** — GitHub stays the origin, cube holds
copies, so losing cube costs nothing. The alternative (things live here
first) was explicitly gated on backups existing, which they now do — and
the choice was **reaffirmed 2026-09-12 anyway**, with the gate met rather
than pending. Worth recording because the original decision and the
reaffirmed one look identical while resting on different evidence: the
first was made because an origin was too risky, the second with that risk
actually retired.

**2026-09-11: this repo itself became the first thing actually mirrored.**
`elly/nixos-configs` was created as a genuine Forgejo pull mirror (migrate
API, `mirror: true`, `mirror_interval: 8h0m0s`, authenticated with the
`forgejo_api_key` sops secret) of
`https://github.com/NireBryce/nixos-configs.git`. GitHub stays canonical;
Forgejo re-pulls on its own schedule, with no cron in this repo. Confirmed
live: all 7 branches present and matching GitHub's own branch list. See
[forgejo.md](../homelab/forgejo.md#this-repo-is-mirrored-here).

## The long-lived runner, 2026-09-24 to 2026-09-26

Before the per-job cycle, one runner served every job. Its 40-hex secret
was the sops key `forgejo-runner-secret`, and a oneshot,
`forgejo-runner-registration.service`, re-ran
`forgejo forgejo-cli actions register --secret-file …` on every
activation: same secret, same UUID, existing row, no-op'd by token-hash
compare. A root `ExecStartPost` staged the decrypted secret into the
virtiofs share. The guest ran nixpkgs' `services.forgejo-runner` in daemon
mode, instance `forge-runner`, with the UUID
(`30343634-3961-3333-6665-303732653263`) pinned as a literal: runner v13
has no `uuid_url` file indirection, and nixpkgs' `secrets.*.uuid_url`
templating renders a key the runner silently drops (the swallowed-key
shape). Rotating the secret meant a new UUID pin in the guest config and
deleting the orphaned row in the admin UI.

Every job could read that token, and it stayed valid across jobs; the
guest was reused until an overlay reset. That is what the per-job cycle
replaced.

Traps from its first day, both caught by reading rendered artifacts: the
instance name's dash escapes into the unit name (`forge-runner` →
`forgejo-runner-forge\x2drunner.service`; targeting the plain spelling
silently creates an empty second unit), and `modulesPath` belongs to the
inner NixOS module lambda, not the outer flake-parts one. Its one real
job, `elly/nire-skills` run 2, passed on 2026-09-26 after run 1 sat in
Waiting on `runs-on: nix:host`.

## See also

- [git-forge](git-forge.md) — the category as it works today.
- [reverse-proxy](reverse-proxy.md) — Caddy, and the prefix-stripping
  incident that took two switches to get right.
