# `virtualization` — `nire/virtualization/`

Libvirt/QEMU VMs, and *only* that — see [system](system.md) for why podman
and distrobox (OCI containers) are a completely different category despite
"virtualization" sounding like it should cover both.

## What's in it

All four files live under `libvirt/` and are all `nixos`-class:

- **`libvirt.nix`** — `virtualisation.libvirtd`, the daemon itself.
- **`virt-tools.nix`** — client/disk-image tooling that runs *against*
  libvirtd (split out so `libvirt.nix` stays about the daemon and its
  options). Deliberately does not add `libvirt`/`qemu` packages itself —
  the `libvirtd` module already puts `cfg.package` and `cfg.qemu.package`
  onto `environment.systemPackages`, so `virsh`/`qemu-img` are already on
  `PATH` without this file repeating that.
- **`vm-networking.nix`** — lets libvirt's default NAT bridge (`virbr0`,
  with libvirt's own dnsmasq for DHCP/DNS) past the host firewall. Every
  host in this repo has `networking.firewall.enable = true`, and without
  this the symptom is a guest that boots fine, gets no DHCP lease, and
  looks like a broken NIC rather than a firewall problem.
- **`libvirt-persist.nix`** — persists
  `/var/lib/libvirt/secrets/secrets-encryption-key` specifically (not
  libvirtd's other first-run state under `/var/lib/libvirt`, which is just
  libvirtd recreating its own stock defaults and not worth keeping). Losing
  this key doesn't recreate a default — it orphans whatever it was
  encrypting. Found 2026-08-22 via `root-drift.sh` flagging it as real,
  non-cosmetic drift, alongside NetworkManager's own secret key (see
  [system](system.md)'s `networkmanager-persist.nix`).

## The near-miss this category's own header records

`libvirt.nix`'s header carries a live example of the `boot`-style merge
trap almost happening again: for about an hour on 2026-08-21, this file was
named `virtualization.nix` and declared
`flake.modules.nixos.virtualization` — the *exact* attribute name this
category's own `dirsAsCategory.nix` declares for its aggregate, once the
surrounding directory was renamed to `virtualization/`. File and category
would have both written to `flake.modules.nixos.virtualization` and
**merged** rather than conflicted, invisibly, because importing either one
would have looked like it worked. Caught and renamed before it shipped.

## Why this is its own category and not part of `system`

So the handhelds can decline it. `nire/system/` is imported whole by every
Linux host with no way to opt out of a piece of it — see
[system](system.md) and [../architecture.md](../architecture.md). Splitting
libvirt out into its own category makes it optional: a boot-time daemon
like `libvirtd` has no business running on a gamescope handheld that will
never open virt-manager. Needs `security.polkit.enable`, which the desktop
session (`kde-desktop`) already brings on the hosts that import it.

## Imported by

`durandal` and `cube` — the two workstations. Not `tenacity` or `lego`, the
two handhelds (the ones that import `jovian` — see
[desktop-env](desktop-env.md)).

## See also

- [system](system.md) — where OCI containers (podman/distrobox) actually
  live, and why "virtualization" meaning only this is a live trap for a
  stale memory.
- [impermanence](impermanence.md), [desktop-env](desktop-env.md) — the two
  other categories with their own `*-persist.nix` sibling files following
  the same "persistence lives beside what generates it" convention as
  `libvirt-persist.nix`.
- [../architecture.md](../architecture.md) — "If something shared needs to
  be optional, a category is the mechanism" — this category is the running
  example that claim is built on.
