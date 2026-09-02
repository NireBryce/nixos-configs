# `git-forge` — `nire/homelab/git-forge/`

## Contents

- [What's in it](#whats-in-it)
- [Why the category isn't named `forgejo`](#why-the-category-isnt-named-forgejo)
- [Zero-touch secrets, built in rather than hand-rolled](#zero-touch-secrets-built-in-rather-than-hand-rolled)
- [Tailnet-only access, same mechanism as Grafana](#tailnet-only-access-same-mechanism-as-grafana)
- [The tailnet device-name trap, avoided rather than hit](#the-tailnet-device-name-trap-avoided-rather-than-hit)
- [Single-user, sqlite3, registration closed](#single-user-sqlite3-registration-closed)
- [Admin account: bootstrapped from nix+sops, not created by hand](#admin-account-bootstrapped-from-nixsops-not-created-by-hand)
- [No persistence entry, same reasoning as Grafana](#no-persistence-entry-same-reasoning-as-grafana)
- [Imported by](#imported-by)
- [See also](#see-also)

Forgejo, a self-hosted git forge. Added 2026-08-24, cube-only; nested under
the `homelab` umbrella since 2026-08-27 (name unaffected). **Confirmed
working end to end, 2026-08-24**: `just switch` came up with 0 failed
units, `forgejo-secrets.service` exited `0/SUCCESS`, `forgejo.service`
stayed `active (running)` past its first 40s, and
`http://ts-cube:3001/` answered `HTTP 200` from another tailnet host.

**That URL is no longer current.** Later the same day Forgejo moved behind
Caddy ([reverse-proxy](reverse-proxy.md)): it listens on `127.0.0.1:3001`
now and is reached at `https://ts-cube.moose-micro.ts.net/git/`. The
proxied arrangement is **confirmed working too**, same day — 200 over
validated TLS from another tailnet host, generated links carrying `/git/`,
assets loading. Getting there took a second switch: the first served
Forgejo the un-stripped prefix and it 404'd everything (that page has the
writeup). Git+ssh over the host's OpenSSH (below) has NOT been exercised
yet — only the HTTP side is confirmed.

## What's in it

One file, `nixos`-class: `forgejo/forgejo.nix`.

## Why the category isn't named `forgejo`

A category and its one module both declaring `forgejo` would both write
`flake.modules.nixos.forgejo` and silently **merge** — the exact
`containers`/`podman.nix` collision [architecture.md](../architecture.md)
documents, hit for real while writing this category. Fixed by renaming the
thing that collides with its own directory; the module itself is still
named (and reads as) `forgejo`.

## Zero-touch secrets, built in rather than hand-rolled

Checked against the pinned nixpkgs' forgejo module before assuming a
Grafana-style manual secret was needed: it isn't. `services.forgejo` ships
`forgejo-secrets.service`, a oneshot that generates
`SECRET_KEY`/`INTERNAL_TOKEN`/`JWT_SECRET` under `${customDir}/conf/`
(`/var/lib/forgejo/custom/conf/` by default) on first run and no-ops after.
Nothing to create by hand.

[monitoring](monitoring.md)'s `grafana.nix` needed a hand-rolled
`grafana-secret-key-setup.service` to match this exact shape — its
`secret_key` file was hand-created, found regressed unreadable on a live
re-check, and only then fixed, modeled on `forgejo-secrets.service`:
generate-if-missing, reassert ownership unconditionally, never regenerate an
existing key. Upstream `services.forgejo` ships that pattern;
`services.grafana`'s deliberately doesn't (nixpkgs removed its
`secretKeyFile` option).

## Tailnet-only access, same mechanism as Grafana

Forgejo binds `127.0.0.1:3001` (3000 is Grafana's), deliberately **not** in
`networking.firewall.allowedTCPPorts` — the binding is what keeps it off
the LAN, and the only client is Caddy ([reverse-proxy](reverse-proxy.md)).
Caddy strips the `/git` prefix before proxying (`handle_path`), unlike
Grafana's route, because Forgejo always serves at `/` regardless of
`ROOT_URL` — the asymmetry is written up there.

It bound `0.0.0.0` for its first few hours, when
`trustedInterfaces = [ "tailscale0" ]` ([system](system.md)) was the only
thing between port 3001 and the LAN. That rule still applies — to Caddy's
443 now — but as the second line. `forgejo.nix`'s history note has the
before/after.

One knock-on the move fixed quietly: `LOCAL_ROOT_URL` defaults to
`http://%(HTTP_ADDR)s:%(HTTP_PORT)s/` and nixpkgs doesn't override it, so
under `0.0.0.0` it built self-referential URLs from an any-address; it
resolves to `http://127.0.0.1:3001/` now.

Git over SSH is a partial exception, deliberately: Forgejo's built-in SSH
server stays disabled (`START_SSH_SERVER` unset), so `git+ssh` rides the
**host's own OpenSSH** (`system/ssh/ssh.nix`) instead of a second port.
Forgejo manages `~forgejo/.ssh/authorized_keys` itself as keys are added
through the web UI; ordinary sshd lookup does the rest. Clone URLs are
`forgejo@ts-cube:...`, port 22 — already open. The module adds no new port,
only a user (`forgejo`) that can authenticate against the already-reachable
sshd.

## The tailnet device-name trap, avoided rather than hit

This tailnet's device names don't match `networking.hostName` (host
`nire-cube`, device `ts-cube` — `tailscale.nix`'s header has the trap).
This module set `DOMAIN`/`ROOT_URL` to `ts-cube` from the start, so clone
URLs and redirect checks never hit it; `grafana.nix` left its defaults at
first and sets both now.

`DOMAIN` and `ROOT_URL` deliberately disagree as of 2026-08-24, which reads
like a typo and isn't: `ROOT_URL` is what a browser sees — the full
`https://ts-cube.moose-micro.ts.net/git/` — while `DOMAIN` is what SSH
clone URLs are built from, and git+ssh doesn't go through Caddy at all, so
it stays the short `ts-cube`.

## Single-user, sqlite3, registration closed

`database.type` is left at the nixpkgs default, `sqlite3` — a single-user
homelab forge has no concurrent-write load a real RDBMS is needed for, and
it avoids standing up a second service/category just for this one. Since
only the tailnet (in practice, elly's own devices) can reach it at all,
`DISABLE_REGISTRATION = true` closes public self-registration too — a
*second* user, if this ever wants more than one, is a `forgejo admin user
create` (or the web UI's Site Administration panel) away. The first
account no longer needs that by-hand step — see below.

## Admin account: bootstrapped from nix+sops, not created by hand

Added 2026-08-26. `DISABLE_REGISTRATION` plus no setup wizard means nothing
creates the *first* account either — before this, that was a manual
`forgejo admin user create` on cube.

`forgejo-admin-bootstrap`, a oneshot ordered after `forgejo.service`, tries
`admin user create --admin` for `elly`, falling back to `admin user
change-password` if the user already exists. The password comes from a sops
secret, `forgejo-admin-password`, declared **in this module** rather than
centralized in `system/secrets/sops.nix` — so it only decrypts on cube,
where `git-forge` is imported.

**This resets the password to the sops value on every activation** — a
considered choice, unlike the create-once shape the signing-key units use:
a password has nothing that breaks if it changes, and this repo's nix+sops
config is the sole source of truth for it. The tradeoff: a hand change
through the web UI is silently reverted on the next `just switch`.

**Status: evaluates only, not yet switched on cube.** `just preflight`
passes and durandal/tenacity's toplevels are unaffected beyond the expected
drvPath move from `secrets.yaml` changing — but nobody has logged in with
this account. Treat as unverified until a real `switch` and a login.

## No persistence entry, same reasoning as Grafana

No `forgejo-persist.nix` alongside this, for the same reason
[monitoring](monitoring.md) has no `grafana-persist.nix`: `nire-cube` has a
plain persistent root, not the `/root` wipe durandal/tenacity get
(`cube-configuration.nix`'s own header), so `/var/lib/forgejo` (repos,
sqlite db, the self-generated secrets under `custom/conf/`) survives reboots
with no `environment.persistence` entry needed. If this module is ever
imported by a host that DOES wipe root, add one first, modeled on
`tailscale-persist.nix`.

## Imported by

`nire-cube` only, as of 2026-08-24. Not durandal or tenacity — same
"hasn't been asked for there yet," not a design limit, [monitoring](monitoring.md)
gives for itself.

## See also

- [homelab/forgejo.md](../homelab/forgejo.md) — the usage-tier page: how to
  actually use the forge once it's up, as opposed to how it's configured
  here.
- [reverse-proxy](reverse-proxy.md) — Caddy, which is how this is reached
  as of 2026-08-24, and where the TLS certificate comes from.
- [monitoring](monitoring.md) — the `grafana.nix` secret-handling trap this
  category deliberately doesn't repeat, and the same tailnet-only firewall
  mechanism.
- [system](system.md) — `tailscale.nix` (the firewall rule this category's
  access model depends on, and the tailnet device-name trap) and `ssh.nix`
  (the host sshd Forgejo's git+ssh rides on).
- [containers](containers.md) — `podman.nix`, the earlier category/module
  name collision this category's own naming avoids repeating.
- [hosts.md](../hosts.md) — current switch/verification status for
  `nire-cube`.
