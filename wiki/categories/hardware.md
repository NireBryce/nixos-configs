# `hardware` — `nire/hardware/` (+ nested `amd`)

## Contents

- [What's in it](#whats-in-it)
- [Nested categories overlap their parents on purpose](#nested-categories-overlap-their-parents-on-purpose)
- [Imported by](#imported-by)
- [See also](#see-also)

## What's in it

Two files, both under a nested `amd/` directory: `amdcpu/amdcpu.nix`
(`inputs.nixos-hardware.nixosModules.common-cpu-amd`) and
`amdgpu/amdgpu.nix` (`inputs.nixos-hardware.nixosModules.common-gpu-amd`,
plus a package list — mesa, vulkan-tools, `amdgpu_top`, etc.). Every host in
this repo is AMD, so that's the entire category so far.

## Nested categories overlap their parents on purpose

`nire/hardware/amd/` has its **own** `dirsAsCategory.nix`, nested inside
`nire/hardware/`'s. `hardware`'s own aggregate ends up referencing `amd`'s
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
for that account and `category-collector.nix`'s own header for the fix
(`bareModulesOf`) that made delegation safe here too.

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
