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

Forgejo, a self-hosted git forge. Added 2026-08-24, cube-only. **Confirmed
working end to end, 2026-08-24**: `just switch` came up with 0 failed
units, `forgejo-secrets.service` exited `0/SUCCESS`, `forgejo.service`
stayed `active (running)` past its first 40s (not just a start that hadn't
crash-looped yet), and `http://ts-cube:3001/` answered `HTTP 200` from
another tailnet host, not just from `localhost` on cube itself. Git+ssh
over the host's OpenSSH (below) has NOT been exercised yet — only the HTTP
side is confirmed.

Moved from `nire/git-forge/` to `nire/homelab/git-forge/` on 2026-08-27,
nested under a new umbrella `homelab` category alongside six other
self-hosted-service categories — see
[categories/README.md](README.md). The category name is unaffected.

**That URL is no longer current.** Later the same day Forgejo moved behind
Caddy ([reverse-proxy](reverse-proxy.md)): it listens on `127.0.0.1:3001`
now and is reached at `https://ts-cube.moose-micro.ts.net/git/`. The
proxied arrangement is **confirmed working too**, same day — 200 over
validated TLS from another tailnet host, with Forgejo's own generated links
carrying the `/git/` prefix and assets under it loading. Getting there took
a second switch: the first one served Forgejo the un-stripped prefix and it
404'd everything, see that page's section on it.

## What's in it

One file, `nixos`-class: `forgejo/forgejo.nix`.

## Why the category isn't named `forgejo`

The category directory is `git-forge`, not `forgejo`, on purpose. A category
and its one module both declaring `forgejo` would both write
`flake.modules.nixos.forgejo` — the exact `containers`/`podman.nix`
collision [architecture.md](../architecture.md) already documents, which
`just modules` catches as a silent merge rather than an error. Hit for real
while writing this category, fixed the same way `containers.nix` was:
rename the thing that collides with its own directory, not the directory
role. The module itself is still named (and reads as) `forgejo` — only the
category umbrella needed a different name.

## Zero-touch secrets, built in rather than hand-rolled

Checked against the pinned nixpkgs' `nixos/modules/services/misc/forgejo.nix`
before assuming a Grafana-style manual secret was needed here too: it
isn't. `services.forgejo` ships its own `forgejo-secrets.service`, a
oneshot that generates `SECRET_KEY`/`INTERNAL_TOKEN`/`JWT_SECRET` itself
under `${customDir}/conf/` (`/var/lib/forgejo/custom/conf/` by default) the
first time it runs, and no-ops on every activation after that. Nothing to
create by hand, no `warnings` entry needed in this module.

[monitoring](monitoring.md)'s `grafana.nix` needed one hand-rolled to match
this exact shape, and only after finding out the hard way why: its
`secret_key` file was hand-created 2026-08-23, found regressed to
unreadable-by-`grafana` on a live re-check 2026-08-24, and only then fixed
with a `grafana-secret-key-setup.service` modeled directly on this
category's `forgejo-secrets.service` — generate-if-missing, reassert
ownership unconditionally, never regenerate an existing key. The
`services.forgejo` upstream module ships that pattern; `services.grafana`'s
own module deliberately doesn't (it used to have a `secretKeyFile` option
and nixpkgs removed it, pushing secret management onto the deployer) — so
`git-forge` got this for free from upstream, `monitoring` had to write it.

## Tailnet-only access, same mechanism as Grafana

Forgejo binds `127.0.0.1:3001` (3000 is already Grafana's), and that port is
deliberately **not** in `networking.firewall.allowedTCPPorts`. Since
2026-08-24 the binding is what keeps it off the LAN — nothing outside cube
can open a connection to it at all — and the only client is Caddy, one file
over in [reverse-proxy](reverse-proxy.md), which accepts on the tailnet and
proxies over loopback.

Caddy strips the `/git` prefix before proxying here (`handle_path`), unlike
Grafana's route next door, because Forgejo always serves at `/` regardless
of `ROOT_URL` — the asymmetry is written up in
[reverse-proxy](reverse-proxy.md).

It bound `0.0.0.0` for the first few hours of its existence, when
`trustedInterfaces = [ "tailscale0" ]` ([system](system.md)'s
`tailscale.nix`) was the only thing between port 3001 and the LAN. That rule
still applies — to Caddy's 443 now — but it is the second line rather than
the only one. `forgejo.nix`'s own history note at the bottom of the file has
the before/after.

One knock-on the move fixed quietly: Forgejo's `LOCAL_ROOT_URL` defaults to
`http://%(HTTP_ADDR)s:%(HTTP_PORT)s/` and nixpkgs doesn't override it, so
with `0.0.0.0` it was building self-referential URLs out of an any-address.
It resolves to `http://127.0.0.1:3001/` now.

Git access over SSH is a partial exception, and deliberately so: Forgejo's
own built-in SSH server is left disabled (`START_SSH_SERVER` unset, so it
stays at the Forgejo/Gitea default of `false`), so `git+ssh` rides on the
**host's own OpenSSH** (`system/ssh/ssh.nix`) instead of opening a second
listening port. Forgejo manages `~forgejo/.ssh/authorized_keys` itself as
users add keys through the web UI; ordinary per-user `authorized_keys`
lookup in the host's sshd does the rest, no `AuthorizedKeysCommand` needed.
Clone URLs are `forgejo@ts-cube:...`, port 22 — the same port ordinary ssh
already uses on every NixOS host, already in `allowedTCPPorts`
(`system/networking/networking.nix`) for LAN and tailnet alike. This module
does not add a new port for git+ssh; it adds a new user (`forgejo`) that can
authenticate against the sshd that was already reachable.

## The tailnet device-name trap, avoided rather than hit

`system/networking/tailscale.nix`'s own header documents a costly-to-find
trap: this tailnet's device names don't match `networking.hostName` (the
host is `nire-cube`, its Tailscale/MagicDNS name is `ts-cube`). This module
set `DOMAIN`/`ROOT_URL` to `ts-cube` explicitly from the start, so cloning
over HTTP and any redirect-URL checks never hit that trap. `grafana.nix`
left its own `domain`/`root_url` at the nixpkgs default at first, flagging
this as the trap to fix "if it's ever hit" — it sets both now, since going
behind a path prefix forced the issue anyway.

`DOMAIN` and `ROOT_URL` deliberately disagree as of 2026-08-24, which reads
like a typo and isn't. `ROOT_URL` is what a browser sees, so it is the full
`https://ts-cube.moose-micro.ts.net/git/`; `DOMAIN` is what SSH clone URLs
are built from, and git+ssh doesn't go through Caddy at all (see the
section above), so it stays the short `ts-cube` and clone URLs stay
`forgejo@ts-cube:...`.

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

Added 2026-08-26. `DISABLE_REGISTRATION` plus no setup wizard
(`useWizard` stays at its nixpkgs default `false`, and `INSTALL_LOCK` is
forced `true` a few lines up) means nothing creates the *first* account
either — before this, that was a manual `forgejo admin user create` on
cube, same as any additional user still is.

`forgejo-admin-bootstrap`, a systemd oneshot ordered after
`forgejo.service`, now does this declaratively: it tries
`admin user create --admin` for `elly`, and if that fails (the only
realistic reason, once `forgejo.service` itself is healthy, is "already
exists") falls back to `admin user change-password`. The password comes
from a new sops secret, `forgejo-admin-password`, declared **in this
module** rather than centralized in `system/secrets/sops.nix` alongside
the syncthing-\* secrets — deliberately, so it only decrypts on
`nire-cube`, where `git-forge` is actually imported, not on
durandal/tenacity too.

**This resets the password to the sops value on every activation** — a
considered choice, not the create-once/never-touch-again shape
`forgejo-secrets.service` and Grafana's `grafana-secret-key-setup.service`
use for signing keys. Unlike a signing key, a password has nothing else
that breaks if it changes, and the intent is for this repo's nix+sops
config to be the sole source of truth for it. The real tradeoff: changing
the password by hand through the web UI would get silently reverted on
the next `just switch`.

**Status: evaluates only, not yet switched on cube.** `just preflight`
passes and durandal/tenacity's toplevels were confirmed unaffected
beyond the expected drvPath move from `secrets.yaml`'s own content
changing (`just diff` shows no sampled attribute differs) — but nobody
has logged in with this account yet. Treat as unverified until a real
`switch` on cube and a login confirm it, per this repo's own "treat an
undated verified as evaluates" rule.

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
