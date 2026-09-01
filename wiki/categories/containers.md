# `containers` — `nire/homelab/containers/`

## Contents

- [What's in it](#whats-in-it)
- [Why it's its own category, and why that didn't change anything](#why-its-its-own-category-and-why-that-didnt-change-anything)
- [The collision this move hit for real](#the-collision-this-move-hit-for-real)
- [Imported by](#imported-by)
- [See also](#see-also)

Podman and distrobox — OCI containers — and *only* that. See
[virtualization](virtualization.md) for why libvirt/QEMU is a completely
different category despite "virtualization" sounding like it should cover
this too; it doesn't, and never has.

Moved from `nire/containers/` to `nire/homelab/containers/` on 2026-08-27,
when this and six other self-hosted-service categories (`git-forge`,
`landing`, `monitoring`, `reverse-proxy`, `shortlinks`, `virtualization`)
were nested under a new umbrella `homelab` category — see
[categories/README.md](README.md). The category name (`containers`) and
its individual importability by name are unaffected by that move; only the
directory nesting changed. Separately, and the same day, `durandal` stopped
importing this category at all — see [Imported by](#imported-by).

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
imported whole by every Linux host with no way to opt a piece of it out, and
splitting a module into its own category is this repo's only mechanism for
making something optional (see [../architecture.md](../architecture.md),
"if something shared needs to be optional, a category is the mechanism").

Unlike `virtualization`, that option wasn't exercised at the time — as of
the 2026-08-22 split, no host declined `containers`, and no host's package
set changed as a result of the move itself. That changed 2026-08-27, when
`durandal` became the first host to actually decline it (see
[Imported by](#imported-by)) — the split's optionality is load-bearing now,
not just theoretical.

## The collision this move hit for real

`virtualization/libvirt/libvirt.nix`'s own header already records a near-miss: for
about an hour on 2026-08-21, that file was named `virtualization.nix` and
declared `flake.modules.nixos.virtualization` — the exact attribute name
its own category's `dirsAsCategory.nix` derives from the surrounding
directory. Caught and renamed before it shipped.

The same thing happened here, not as a near-miss but as an actual `just
modules` failure: the module, freshly moved into `nire/containers/` (as it
was named then — see the `homelab` consolidation note above), was
still named `containers.nix`, so it declared `flake.modules.nixos.containers`
— exactly what the new category's own `dirsAsCategory.nix` declares for its
aggregate. Renamed to `podman.nix`, for the same reason `libvirt.nix` isn't
named `virtualization.nix`: name the file after the actual technology, not
the category it happens to sit in. See the file's own header for the full
account, including the two earlier names it's carried
(`virtualization.nix` → `containers.nix` → `podman.nix`).

## Imported by

`tenacity`, `cube` — two of the three NixOS hosts now on the tree. All four
NixOS hosts on the tree at the time (durandal, tenacity, lego, cube) *did*
import this explicitly from 2026-08-22 until 2026-08-27, when it was dropped
from `durandal` specifically: nothing in this repo's history ever recorded
durandal actually running a podman container or a distrobox, unlike cube's
confirmed homelab usage, so it was carried purely for parity rather than an
established need. See `durandal-configuration.nix`'s own comment at the
point it was removed. `lego` (which also imported this) was itself removed
the same day — see [../history.md](../history.md).
Not `lysithea` either way — this module is `nixos`-class only, so it never
reached darwin even back when it was still part of `system` (see
[system](system.md)'s "Imported by" section on which classes actually
cross to lysithea).

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
