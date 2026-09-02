# `shortlinks` — `nire/homelab/shortlinks/`

## Contents

- [What's in it](#whats-in-it)
- [Why the category isn't named `golink`](#why-the-category-isnt-named-golink)
- [It hand-writes a systemd unit, which is unusual here](#it-hand-writes-a-systemd-unit-which-is-unusual-here)
- [It is not a service on this host's network](#it-is-not-a-service-on-this-hosts-network)
- [First run needs a one-time interactive login](#first-run-needs-a-one-time-interactive-login)
- [The node must stay named `go`](#the-node-must-stay-named-go)
- [`DynamicUser`, deliberately](#dynamicuser-deliberately)
- [No persistence entry](#no-persistence-entry)
- [Imported by](#imported-by)
- [See also](#see-also)

[golink](https://github.com/tailscale/golink), Tailscale's `go/foo`
shortlink service. Added 2026-08-24, cube-only; nested under the `homelab`
umbrella since 2026-08-27 (name unaffected).

**It failed its first real switch, then was fixed and confirmed working
end to end the same day (2026-08-24)** — a missing `AF_NETLINK` in this
module's own `RestrictAddressFamilies`; see [the hardening
section](#dynamicuser-deliberately) for the setting, and
[shortlinks-history.md](shortlinks-history.md) for the crash-loop and the
fix in full.

Usage — creating and managing links — is [homelab/golinks.md](../homelab/golinks.md).
This page stays the configuration side.

## What's in it

One file, `nixos`-class: `golink/golink.nix`.

## Why the category isn't named `golink`

Same reason [git-forge](git-forge.md) isn't named `forgejo`: a category and
its one module both declaring `golink` would both write
`flake.modules.nixos.golink` and silently **merge** rather than error — the
`containers`/`podman.nix` collision [architecture.md](../architecture.md)
documents, hit for real twice already in this tree. It's `shortlinks` rather
than `golinks`, too: a category name one letter off its own module reads as
a typo the next time someone greps for it.

## It hand-writes a systemd unit, which is unusual here

**There is no `services.golink` in nixpkgs.** Checked the pinned nixpkgs
(rev `e4bae1bd`) before writing anything, per this repo's "check for an
existing `programs.*`/`services.*` integration before hand-writing one"
rule: `pkgs/by-name/go/golink/` exists as a package, and `nixos/modules/`
has nothing golink-shaped at all. So unlike `forgejo.nix` and `grafana.nix`
next door — both of which set options on an upstream module — this one
declares its own `systemd.services.golink`. If nixpkgs ever grows
`services.golink`, delete the unit and use it.

Two knock-on details of writing it by hand:

- The unit name is written out literally, not derived from `moduleName` the
  way the flake-parts attribute is. The attribute *has* to track the
  filename (that's how `dirsAsCategory` finds it); the systemd unit name is
  what `systemctl status golink` keys off and should not quietly change if
  the file is ever renamed.
- `-sqlitedb` is a **required** flag, not an optional one — `golink.go`
  exits with `--sqlitedb is required` unless `-dev-listen` is also set. Both
  it and `-config-dir` (where tsnet keeps the node key) are pinned to paths
  under the unit's `StateDirectory` rather than left to golink's
  `os.UserConfigDir` default, which under `DynamicUser` would be an implicit
  path with no reliable `$HOME` behind it.

## It is not a service on this host's network

The thing most likely to be misread by analogy with
[monitoring](monitoring.md) and [git-forge](git-forge.md): golink embeds
**tsnet**, joining the tailnet as its own *separate device*, with its own
tailnet IP — its `:80`/`:443` listeners live on that device, not on any of
`nire-cube`'s interfaces. Three consequences:

- **No firewall change at all.** No `allowedTCPPorts` entry, and not the
  `trustedInterfaces = [ "tailscale0" ]` mechanism Grafana and Forgejo rely
  on ([system](system.md)'s Tailscale section). Nothing arrives at cube's
  firewall for this; it isn't reachable on the LAN because it doesn't listen
  there.
- **No dependency on the host's `tailscaled`.** tsnet is a userspace
  WireGuard node in-process, talking to the coordination server itself — it
  doesn't use the host's tunnel, `tailscale0`, or `/dev/net/tun`. The unit
  orders after `network-online.target` only, deliberately *not*
  `tailscaled.service`.
- **It consumes a tailnet device slot, and the tailnet ACL applies to it.**
  Per `tailscale.nix`'s "TWO REAL TRAPS": an ACL that doesn't grant
  member-to-member traffic silently drops connections here too — fixed in
  Tailscale's admin console, not this repo.

## First run needs a one-time interactive login

By design, the same call [system](system.md)'s `tailscale.nix` makes for
the host daemon: **no `TS_AUTHKEY` is wired in.** Auth keys expire (90 days
max), so baking one in buys a service that fails on every boot months from
now.

Without a key, tsnet prints an auth URL and waits — confirmed by reading
tsnet v1.96.1's source: `printAuthURLLoop` logs through `(*Server).logf`,
which falls through to `log.Printf` when `UserLogf` is nil (golink sets
only `Logf`), so the URL reaches stderr, i.e. the journal:

```sh
journalctl -u golink -f     # then open the printed URL, once
```

tsnet writes its node key into the config-dir and reauthenticates from it
on every later boot — once per machine, the same shape `sudo tailscale up`
has. (tsnet ignores a later-wired authkey when state exists, so there's
still no reason to wire one. To revisit anyway: mint a key, add
`sops.secrets.tailscale_key` in `system/secrets/sops.nix`, pass it as an
`EnvironmentFile`.)

## The node must stay named `go`

`-hostname go` is what tsnet registers as, and that is what makes MagicDNS
answer `http://go/`. This is a claim about the Tailscale admin console, not
just about the module: this tailnet renames its devices (`nire-cube` the
host is `ts-cube` the device, fleet-wide — `tailscale.nix`'s trap #1), and
renaming *this* one to `ts-go` out of consistency would break the entire
point of the service. Leave it as `go`.

## `DynamicUser`, deliberately

systemd owns the uid *and* the state directory's ownership. That is
precisely the thing that went wrong twice for [monitoring](monitoring.md)'s
`grafana.nix` — a hand-created secret left `root:root`, unreadable by the
service's own user, once and then again after a hand fix regressed. Nothing
here is hand-created, so there is nothing whose ownership can be got wrong.

The trap this trades for, worth knowing before changing it: switching to a
static user does **not** move existing state. `/var/lib/private/golink`
would be left owned by a uid that no longer exists, and golink would come up
as a brand-new, unauthenticated node with no links. Move and `chown` the
directory in the same change.

Hardening is modest on purpose. `DynamicUser` already implies
`NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`, `RemoveIPC`; what's
added is the handful obviously safe for a pure-Go network daemon with no cgo
(golink's sqlite is `modernc.org/sqlite`) and no device access.
`MemoryDenyWriteExecute` and `SystemCallFilter` stay out — an untested
syscall filter fails as a confusing crash at start.

**`AF_NETLINK` in `RestrictAddressFamilies` is load-bearing** — leaving it
out is what broke the first switch. Go's `net` package enumerates interfaces
and routes through a netlink socket (`syscall.NetlinkRIB` →
`socket(AF_NETLINK, SOCK_RAW, …)`), and `RestrictAddressFamilies` makes a
blocked `socket()` return `EAFNOSUPPORT` — the
`netlinkrib: address family not supported by protocol` message verbatim.
The error names netlink and reads like a kernel problem; nothing in it says
"systemd", which is why it's written in the module too. Anything tsnet-based
needs it — don't tidy it back out.

## No persistence entry

Same reasoning [monitoring](monitoring.md) and [git-forge](git-forge.md)
each give: `nire-cube` has a plain persistent root, not the `/root` wipe
durandal/tenacity get (`cube-configuration.nix`'s header), so
`/var/lib/private/golink` — the links database *and* the tsnet node key —
survives reboots with no `environment.persistence` entry. If this module is
ever imported by a host that DOES wipe root, add one first, modeled on
`tailscale-persist.nix`; otherwise every reboot loses every shortlink and
registers a fresh tailnet device.

## Imported by

`nire-cube` only, as of 2026-08-24. Confirmed not to move durandal or
tenacity: each host's toplevel `drvPath` is byte-identical before
and after this change.

## See also

- [git-forge](git-forge.md) — the category this one is shaped after, and the
  same category/module naming collision avoided the same way.
- [monitoring](monitoring.md) — the tailnet-only-via-firewall mechanism this
  category does *not* use, and the secret/ownership history `DynamicUser`
  sidesteps here.
- [system](system.md) — `tailscale.nix`, for the host daemon, the auth-key
  decision this module mirrors, and the two tailnet traps.
- [homelab/golinks.md](../homelab/golinks.md) — the usage side: creating
  links, the template syntax, and the `curl` traps.
- [hosts.md](../hosts.md) — current switch/verification status for
  `nire-cube`.
- [shortlinks-history.md](shortlinks-history.md) — the first-switch
  crash-loop in full.
