# `git-forge` — `nire/git-forge/`

Forgejo, a self-hosted git forge. Added 2026-08-24, cube-only. **Confirmed
working end to end, 2026-08-24**: `just switch` came up with 0 failed
units, `forgejo-secrets.service` exited `0/SUCCESS`, `forgejo.service`
stayed `active (running)` past its first 40s (not just a start that hadn't
crash-looped yet), and `http://ts-cube:3001/` answered `HTTP 200` from
another tailnet host, not just from `localhost` on cube itself. Git+ssh
over the host's OpenSSH (below) has NOT been exercised yet — only the HTTP
side is confirmed.

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

Forgejo binds `0.0.0.0:3001` (3000 is already Grafana's), but that port is
deliberately **not** added to `networking.firewall.allowedTCPPorts`. What
restricts access is the same `trustedInterfaces = [ "tailscale0" ]` rule
[system](system.md)'s `tailscale.nix` sets on every host — see
[monitoring](monitoring.md)'s own writeup of this mechanism, applied here to
a third service rather than reinvented.

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
host is `nire-cube`, its Tailscale/MagicDNS name is `ts-cube`). `grafana.nix`
left `domain`/`root_url` at the nixpkgs default rather than fix this
proactively, flagging it as the trap to fix "if it's ever hit." This module
sets `DOMAIN`/`ROOT_URL` to `ts-cube` explicitly from the start, so cloning
over HTTP and any redirect-URL checks don't hit that trap at all.

## Single-user, sqlite3, registration closed

`database.type` is left at the nixpkgs default, `sqlite3` — a single-user
homelab forge has no concurrent-write load a real RDBMS is needed for, and
it avoids standing up a second service/category just for this one. Since
only the tailnet (in practice, elly's own devices) can reach it at all,
`DISABLE_REGISTRATION = true` closes public self-registration too — a new
user, if this ever wants more than one, is a `forgejo admin user create`
away.

## No persistence entry, same reasoning as Grafana

No `forgejo-persist.nix` alongside this, for the same reason
[monitoring](monitoring.md) has no `grafana-persist.nix`: `nire-cube` has a
plain persistent root, not the `/root` wipe durandal/tenacity/lego get
(`cube-configuration.nix`'s own header), so `/var/lib/forgejo` (repos,
sqlite db, the self-generated secrets under `custom/conf/`) survives reboots
with no `environment.persistence` entry needed. If this module is ever
imported by a host that DOES wipe root, add one first, modeled on
`tailscale-persist.nix`.

## Imported by

`nire-cube` only, as of 2026-08-24. Not durandal, tenacity, or lego — same
"hasn't been asked for there yet," not a design limit, [monitoring](monitoring.md)
gives for itself.

## See also

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
