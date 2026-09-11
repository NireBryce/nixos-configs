# `shortlinks`, for agents

_Last modified: 2026-09-11_

Condensed from [shortlinks.md](shortlinks.md), which keeps the reasoning
and the narrative. Facts only here.

golink (Tailscale's `go/foo` service) on `nire-cube`. Added 2026-08-24,
nested under `homelab` 2026-08-27. Usage is
[../homelab/creating-golinks.md](../homelab/creating-golinks.md).

## What's in it

One file, `nixos`-class: `nire/homelab/shortlinks/golink/golink.nix`.

Named `shortlinks`, not `golink`/`golinks`: category-and-module sharing a
name silently **merge**, and a name one letter off its module reads as a
typo when grepped.

## It hand-writes its own systemd unit

**There is no `services.golink` in nixpkgs** — checked against the pinned
rev; `pkgs/by-name/go/golink/` exists as a package, `nixos/modules/` has
nothing. If nixpkgs ever grows one, delete the unit and use it.

- The systemd unit name is written **literally**, not derived from
  `moduleName` — the flake-parts attribute has to track the filename, the
  unit name must not change if the file is renamed.
- `-sqlitedb` is **required** (golink exits `--sqlitedb is required` unless
  `-dev-listen` is set). It and `-config-dir` are pinned under
  `StateDirectory` rather than left to `os.UserConfigDir`, which under
  `DynamicUser` has no reliable `$HOME` behind it.

## It is not a service on this host's network

golink embeds **tsnet** and joins the tailnet as its own device with its own
IP. Its listeners are not on any of cube's interfaces.

- **No firewall change**, and not the `trustedInterfaces` mechanism Grafana
  and Forgejo use. Nothing arrives at cube's firewall for it.
- **No dependency on the host `tailscaled`** — userspace WireGuard,
  in-process. Orders after `network-online.target` only, deliberately not
  `tailscaled.service`.
- It consumes a tailnet device slot, and the tailnet ACL still applies.

## Traps

- **`AF_NETLINK` in `RestrictAddressFamilies` is load-bearing.** Leaving it
  out broke the first switch: Go's `net` package enumerates interfaces via
  `socket(AF_NETLINK, SOCK_RAW, …)`, and the block surfaces as
  `netlinkrib: address family not supported by protocol` — which names
  netlink and reads like a kernel problem. Anything tsnet-based needs it.
- **The node must stay named `go`.** `-hostname go` is what makes MagicDNS
  answer `http://go/`. This tailnet renames devices (`nire-cube` → `ts-cube`);
  renaming this one to `ts-go` for consistency breaks the service's whole
  point.
- **No `TS_AUTHKEY`, deliberately** — auth keys expire (90 days max). First
  run prints an auth URL to the journal and waits:
  `journalctl -u golink -f`, open it once. tsnet then reauthenticates from
  the stored node key forever.
- **`DynamicUser` is deliberate** — systemd owns the uid and the state
  directory's ownership, so nothing here can hit the `root:root` secret
  problem `grafana.nix` hit twice. Switching to a static user does **not**
  move existing state: `/var/lib/private/golink` would be orphaned and
  golink would come up as a fresh unauthenticated node with no links. Move
  and `chown` in the same change.
- `MemoryDenyWriteExecute` and `SystemCallFilter` stay out on purpose — an
  untested syscall filter fails as a confusing crash at start.
- No persistence entry — cube has a persistent root. On a host that wipes
  `/root`, every reboot would lose every shortlink *and* register a fresh
  tailnet device.

## Imported by

`nire-cube` only. Confirmed not to move durandal or tenacity.

## See also

[shortlinks.md](shortlinks.md) ·
[../homelab/creating-golinks.md](../homelab/creating-golinks.md) ·
[git-forge.md](git-forge.md) · [system.md](system.md) ·
[shortlinks-history.md](shortlinks-history.md)
