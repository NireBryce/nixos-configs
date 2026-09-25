# `git-forge` — `config-system/homelab/git-forge/`

_Last modified: 2026-09-25_

Forgejo, a self-hosted git forge. Added 2026-08-24, cube-only; nested under
the `homelab` umbrella since 2026-08-27 (name unaffected). As of 2026-09-07
reached at `https://git.moose-micro.ts.net/` — its own Tailscale Services
name, still fronted by Caddy ([reverse-proxy](reverse-proxy.md)) since
Tailscale Services can't terminate HTTPS declaratively yet (confirmed
upstream bug, see `tailscale-services/serve.nix`'s history section). The
`.../git/`-path-under-`ts-cube` form no longer answers (404).
[git-forge-history.md](git-forge-history.md) has the original first-switch
record and the move behind Caddy; the move to its own service name is
this category's newest change, not yet its own history entry.

> **Condensed version:**
> [git-forge-for-agents.md](git-forge-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [What's in it](#whats-in-it)
- [Why the category isn't named `forgejo`](#why-the-category-isnt-named-forgejo)
- [Zero-touch secrets, built in rather than hand-rolled](#zero-touch-secrets-built-in-rather-than-hand-rolled)
- [Actions and the runner](#actions-and-the-runner)
- [Tailnet-only access, same mechanism as Grafana](#tailnet-only-access-same-mechanism-as-grafana)
- [The tailnet device-name trap, avoided rather than hit](#the-tailnet-device-name-trap-avoided-rather-than-hit)
- [Single-user, sqlite3, registration closed](#single-user-sqlite3-registration-closed)
- [Admin account: bootstrapped from nix+sops, not created by hand](#admin-account-bootstrapped-from-nixsops-not-created-by-hand)
- [No persistence entry, same reasoning as Grafana](#no-persistence-entry-same-reasoning-as-grafana)
- [Imported by](#imported-by)
- [See also](#see-also)

## What's in it

Two files, `nixos`-class: `forgejo/forgejo.nix` (the forge) and
`forgejo/actions-runner.nix` (the CI worker, added 2026-09-24).

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

## Actions and the runner

Added 2026-09-24 on the host; moved into a VM 2026-09-25. Forgejo Actions
(GitHub-Actions-compatible workflow YAML) is enabled instance-wide
(`settings.actions.ENABLED`); the runner itself is the libvirt guest
`forge-runner` on cube — instantiated by
`virtualization/virtualization-cube.nix` through the VM generator, guest
config in `hosts/forge-runner-configuration.nix` (no `nire-` prefix:
that names the fleet machines, and this is a component of cube). What
stays on the host (`forgejo/actions-runner.nix`) is only what must be
here: the sops secret, the registration oneshot, and the staged token
copy the guest mounts.

The containment is the point: workflow code with podman/docker access is
one escape from whatever holds it, and cube holds everything sops
decrypts. In the VM it holds one secret — its own runner token. The VM
adds no listening port either way; it is dial-out, like the runner was
on the host — and its egress is nwfilter-scoped (guest NIC filter
`forge-runner-egress`: gateway DNS/DHCP and the forge's 443 only, all
private ranges and the tailnet dropped, open internet allowed), because
libvirt's own FORWARD jumps would otherwise let guest traffic bypass
nixos-firewall rules entirely.

**Job → forge, without tailscaled.** The guest is not on the tailnet. Its
`/etc/hosts` pins `git.moose-micro.ts.net` to `192.168.122.1` (the virbr0
gateway); `vm-networking.nix` already trusts that bridge and Caddy's cert
for the name is publicly trusted, so the connection URL is the ordinary
ROOT_URL over validated TLS, Caddy → loopback Forgejo. Forgejo's own
127.0.0.1:3001 stays unreachable from the guest, by design — Caddy is
the door. Labels decide which jobs it accepts (`runs-on:`): the same
`ubuntu-latest`/`ubuntu-24.04`/`nix:host` set as before, now executed by
the guest's own podman and the guest's own nix. Usage:
[homelab/forgejo.md](../homelab/forgejo.md).

**Token delivery, without a guest key.** cube's decrypted
`/run/secrets/forgejo-runner-secret` is staged (root:root 0600, by the
registration unit's root-privileged `ExecStartPost`) into
`/var/lib/forgejo-runner-share/`, which virtiofs mounts read-only into
the guest at `/mnt/runner-secret`. The guest runs no sops and has no
key; the share holds only that one file.

**Registration** is the offline scheme (Forgejo v11+ / runner v9+): a
40-char hex secret whose first 16 characters, read as raw ASCII bytes,
ARE the runner's UUID (`models/actions/forgejo.go`,
`google/uuid.FromBytes`); the deprecated registration token is not
supported. The secret is the sops key `forgejo-runner-secret`; the UUID
is pinned as a literal in the guest config, because it must reach the
runner's generated `config.yaml` at build time and the runner has no
`uuid_url` file indirection — nixpkgs' `secrets.*.uuid_url` templating
renders a key runner v13 silently drops, the swallowed-key shape, which
is why it's written out here.

`forgejo-runner-registration.service` re-runs the server-side
`forgejo forgejo-cli actions register --secret-file …` on every
activation — idempotent by design (same secret → same UUID → existing
row, no-op'd by token-hash compare) — and is what creates the row the
runner authenticates against. `libvirt-vm-forge-runner` is ordered
After= it. Rotating the secret rotates the identity: new UUID pin in the
guest config, orphaned old row to delete in the admin UI.

Two guest-side traps hit on day one, both caught by reading rendered
artifacts: the instance name's dash escapes into the unit name
(`forge-runner` → unit `forgejo-runner-forge\x2drunner.service`, so
targeting the plain spelling silently creates an empty second unit), and
`modulesPath` belongs to the inner NixOS module lambda, not the outer
flake-parts one.

**Status: bootstrap values landed 2026-09-25** (secret in sops, UUID
pinned; cube's toplevel and the 3 GB guest image both build) — but
**never switched**: nothing here is confirmed against the live instance
yet, unlike everything above it on this page.

## Tailnet-only access, same mechanism as Grafana

Forgejo binds `127.0.0.1:3001` (3000 is Grafana's), deliberately **not** in
`networking.firewall.allowedTCPPorts` — the binding is what keeps it off
the LAN, and the only client is Caddy ([reverse-proxy](reverse-proxy.md)).
Forgejo has its own Caddy vhost now (`git.moose-micro.ts.net`, reached via
its Tailscale Services name and a raw TCP forward -- see
`tailscale-services/serve.nix`), so it's a plain `reverse_proxy` with no
path prefix to strip — the `handle`/`handle_path` asymmetry with Grafana
that this used to require is retired, kept as history in
[reverse-proxy-history.md](reverse-proxy-history.md#the-retired-routes-as-they-were).

It bound `0.0.0.0` briefly at first — [git-forge-history.md](git-forge-history.md)
has that window and what it fixed quietly along the way.
`trustedInterfaces = [ "tailscale0" ]` ([system](system.md)) still applies,
to Caddy's 443 now, as the second line.

Git over SSH is a partial exception, deliberately: Forgejo's built-in SSH
server stays disabled (`START_SSH_SERVER` unset), so `git+ssh` rides the
**host's own OpenSSH** (`config-system/ssh/ssh.nix`) instead of a second port.
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

`DOMAIN` and `ROOT_URL` deliberately disagree, which reads like a typo and
isn't: `ROOT_URL` is what a browser sees — `https://git.moose-micro.ts.net/`
as of 2026-09-07's move to Forgejo's own Tailscale Services name (was
`https://ts-cube.moose-micro.ts.net/git/` before) — while `DOMAIN` is what
SSH clone URLs are built from, and git+ssh doesn't go through Caddy *or*
Tailscale Serve, so it stays the short `ts-cube` regardless of what
`ROOT_URL` does.

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
centralized in `config-system/secrets/sops.nix` — so it only decrypts on cube,
where `git-forge` is imported.

**This resets the password to the sops value on every activation** — a
considered choice, unlike the create-once shape the signing-key units use:
a password has nothing that breaks if it changes, and this repo's nix+sops
config is the sole source of truth for it. The tradeoff: a hand change
through the web UI is silently reverted on the next `just switch`.

**Status: switched and logged in, confirmed 2026-09-05.** The user has signed
in as `elly` and used the account directly (screenshot-confirmed) — the
account and password both work as declared. Whether it's genuinely
*admin* (the `--admin` flag) is **confirmed: it took** — checked from
inside the UI and reported by the user 2026-09-12. That was the only way to
check it: Forgejo's unauthenticated `/api/v1/users/search` always reports
`is_admin: false` regardless of the real value, so that field never could
settle it, and reading it as an answer produced a wrong one twice. See
[git-forge-history.md](git-forge-history.md#the-admin-account-and-an-anonymous-api-that-reports-zeroes)
for the fuller account of that trap.

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
- [git-forge-history.md](git-forge-history.md) — the first switch and the
  move behind Caddy, in full.
