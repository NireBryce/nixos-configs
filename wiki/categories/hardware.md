# `hardware` — `hardware-config/hardware/` (+ nested `amd`)

_Last modified: 2026-10-15_

## Contents

- [What's in it](#whats-in-it)
- [Nested categories overlap their parents on purpose](#nested-categories-overlap-their-parents-on-purpose)
- [Imported by](#imported-by)
- [See also](#see-also)

## What's in it

Eight files, all `nixos`-class:

- **`amd/`**, a nested category: `amdcpu/amdcpu.nix`
  (`inputs.nixos-hardware.nixosModules.common-cpu-amd`) and
  `amdgpu/amdgpu.nix` (`inputs.nixos-hardware.nixosModules.common-gpu-amd`,
  plus a package list — mesa, vulkan-tools, `amdgpu_top`, etc.). Every host
  in this repo is AMD.
- **`bluetooth/bluetooth.nix`** — `hardware.bluetooth`.
- **`firmware/`** — `firmware-all.nix` (`hardware.enableAllFirmware`,
  `enableRedistributableFirmware`) and `fwupd.nix` (`services.fwupd`).
- **`storage/`** — `smartd.nix` (S.M.A.R.T. monitoring and scheduled
  self-tests) and `coredump-limit.nix` (`systemd.coredump` limits).
- **`memory/swap-policy.nix`** — the zram/zswap swap-policy toggle.

`bluetooth/`, `firmware/`, `storage/` and `memory/` were plain folders in
the [system](system.md) category until 2026-10-15; the hosts that import
`hardware` are the same three that took them through `system`, so no host
gained or lost anything in the move.

## Nested categories overlap their parents on purpose

`hardware-config/hardware/amd/` has its **own** `dirsAsCategory.nix`, nested inside
`hardware-config/hardware/`'s. `hardware`'s own aggregate ends up referencing `amd`'s
aggregate by name rather than re-deriving `amdcpu`/`amdgpu` independently
(as of the 2026-08-27 refactor into `modules/_lib/category-collector.nix` —
see that doc's History section) — a coarse handle (`hardware`, what every
host actually imports today) reaching the same content as the fine one
(`amd`, for if this repo ever needs to distinguish AMD from Intel hardware),
by reference instead of by duplicate derivation. Before that refactor it
recursed straight through and derived the same two modules a second time by
hand; the effective configuration is identical either way (confirmed by a
full attribute-set diff — `environment.systemPackages`, `systemd.services`,
`users.users` — against the pre-refactor baseline, not just by evaluating
cleanly). It looks like a bug on first read and isn't — `flake/doc/dirsAsCategory.md`
documents it explicitly as load-bearing, alongside the historical near-miss
it guards against: the class filter this relies on once nearly broke when
`dirsAsProvides.nix` was renamed to `dirsAsCategory.nix` and the exclusion
list didn't get updated with it, which would have made nested categories
collect a phantom module literally named `dirsAsCategory`.

**Getting the delegation right took two wrong attempts, and the wrong one
would have silently broken `nire-cube`, not this category.** A version that
delegated without also carrying along a nested category's own bare `.nix`
files was tried in the same change and found to drop `libvirt-vm-llm-sandbox`
from `nire-cube`'s `systemd.services` — the equivalent delegation one
category over, `homelab` → `virtualization`, collapsing the exact
independent-walk quirk that used to deliver that VM's wiring. See
[homelab.md](homelab.md#nested-categories-overlap-their-parents-on-purpose)
for that account. The fix, `bareModulesOf`, was retired 2026-09-28 along
with the rule that made it necessary (`flake/doc/dirsAsCategory.md`'s
History).

## Imported by

All three NixOS hosts import `hardware` directly (not the narrower `amd`) —
durandal, tenacity, cube are all AMD (Ryzen desktop/APU, Ryzen Z1
handheld). `nire-lysithea` (darwin, Apple Silicon) does not import this
category at all — importing it would resolve to an empty darwin aggregate
since neither module declares a darwin class, so it's left out rather than
imported for nothing, same reasoning `lysithea-configuration.nix` gives for
skipping `desktop-env` and `peripherals` too.

## See also

- [../architecture.md](../architecture.md) — the `dirsAsCategory` mechanism
  generally.
- [../hosts.md](../hosts.md) — per-host hardware notes.
