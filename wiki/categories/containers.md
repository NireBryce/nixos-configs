# `containers` — `nire/homelab/containers/`

## Contents

- [What's in it](#whats-in-it)
- [Why it's its own category, and why that didn't change anything](#why-its-its-own-category-and-why-that-didnt-change-anything)
- [The collision this move hit for real](#the-collision-this-move-hit-for-real)
- [Imported by](#imported-by)
- [See also](#see-also)

Podman and distrobox — OCI containers — and *only* that. See
[virtualization](virtualization.md) for why libvirt/QEMU is a different
category despite "virtualization" sounding like it should cover this too.
Nested under the `homelab` umbrella since 2026-08-27 (name unaffected);
durandal stopped importing it the same day — see
[Imported by](#imported-by).

## What's in it

One file, `podman/podman.nix`, `nixos`-class:

- `virtualisation.podman.enable`, `dockerCompat`, and `defaultNetwork.settings.dns_enabled`
  (needed so containers under `podman-compose` can talk to each other).
- `environment.systemPackages`: `distrobox`, `distrobox-tui`, `distroshelf`,
  `boxbuddy`, `host-spawn`, `podman-compose`.
- `environment.etc."distrobox/distrobox.conf"` — mounts both
  `/etc/profiles/per-user` *and* `/etc/static/profiles/per-user` read-only
  into distrobox containers. Both paths are needed, not one:
  `/etc/profiles/per-user/elly` is itself a symlink to
  `/etc/static/profiles/per-user/elly` (nixpkgs'
  `config/users-groups.nix`), which is the one that actually points into
  `/nix/store` — mounting only the first gives a container a dangling link.
- A dedicated `container` system user (`isNormalUser`, `linger = true`,
  pinned `subUidRanges`/`subGidRanges` at `165536:65536`) alongside elly's
  own pinned range at `100000:65536`. Both are explicit, **not**
  `autoSubUidGidRange`, on purpose — see the file's own comment on
  [an auto-allocator that cannot see manual entries](../history.md), the
  actual incident this pinning exists to prevent.

## Why it's its own category, and why that didn't change anything

Split out of `system` 2026-08-22, structurally the same move
[virtualization](virtualization.md) got the day before: `nire/system/` is
imported whole by every Linux host, and splitting a module into its own
category is this repo's only mechanism for making something optional
([../architecture.md](../architecture.md)). At split time no host declined
it; that changed 2026-08-27 when `durandal` became the first (see
[Imported by](#imported-by)) — the optionality is load-bearing now.

## The collision this move hit for real

The only category/module collision that actually shipped far enough for
`just modules` to catch: the freshly moved module was still named
`containers.nix`, declaring `flake.modules.nixos.containers` — exactly what
the new category's `dirsAsCategory.nix` declares for its aggregate.
Renamed to `podman.nix`: name the file after the technology, not the
category it sits in (same reason `libvirt.nix` isn't `virtualization.nix`;
see [virtualization](virtualization.md)'s near-miss section). The file's
own header has the two earlier names it carried
(`virtualization.nix` → `containers.nix` → `podman.nix`).

## Imported by

`tenacity`, `cube`. All four NixOS hosts on the tree at the time (durandal,
tenacity, lego, cube) imported it 2026-08-22→08-27, when durandal dropped
it: nothing in this repo's history records durandal actually running a
container or distrobox, unlike cube's confirmed homelab usage — parity, not
need (see `durandal-configuration.nix`'s comment at the removal point).
`lego` was removed the same day ([../history.md](../history.md)). Not
`lysithea` — the module is `nixos`-class only.

## See also

- [virtualization](virtualization.md) — the category this one is easy to
  confuse by name and by history; that page's own header now points back
  here for the same reason.
- [system](system.md) — where this module used to live, and the
  "Containers vs. virtualization" section kept there as a pointer for
  anyone remembering the old location.
- [../architecture.md](../architecture.md) — "if something shared needs to
  be optional, a category is the mechanism," and the merge-vs-conflict trap
  a same-named category and module walk straight into.
- [monitoring](monitoring.md) — `cadvisor.nix` scrapes the containers this
  category enables, on `nire-cube`.
