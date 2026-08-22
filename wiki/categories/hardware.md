# `hardware` — `nire/hardware/` (+ nested `amd`)

## What's in it

Two files, both under a nested `amd/` directory: `amdcpu/amdcpu.nix`
(`inputs.nixos-hardware.nixosModules.common-cpu-amd`) and
`amdgpu/amdgpu.nix` (`inputs.nixos-hardware.nixosModules.common-gpu-amd`,
plus a package list — mesa, vulkan-tools, `amdgpu_top`, etc.). Every host in
this repo is AMD, so that's the entire category so far.

## Nested categories overlap their parents on purpose

`nire/hardware/amd/` has its **own** `dirsAsCategory.nix`, nested inside
`nire/hardware/`'s. Because `collectModules` recurses, both `hardware` and
`amd` end up as separate aggregates containing the *same two modules*
(`amdcpu`, `amdgpu`). That gives a coarse handle (`hardware`, what every
host actually imports today) and a fine one (`amd`, for if this repo ever
needs to distinguish AMD from Intel hardware) on identical content. It looks
like a bug on first read and isn't — `flake/doc/dirsAsCategory.md` documents
it explicitly as load-bearing, alongside the historical near-miss it
guards against: the class filter this relies on once nearly broke when
`dirsAsProvides.nix` was renamed to `dirsAsCategory.nix` and the exclusion
list didn't get updated with it, which would have made nested categories
collect a phantom module literally named `dirsAsCategory`.

## Imported by

All four NixOS hosts import `hardware` directly (not the narrower `amd`) —
durandal, tenacity, lego, cube are all AMD (Ryzen desktop/APU, Ryzen Z1
handhelds). `nire-lysithea` (darwin, Apple Silicon) does not import this
category at all — importing it would resolve to an empty darwin aggregate
since neither module declares a darwin class, so it's left out rather than
imported for nothing, same reasoning `lysithea-configuration.nix` gives for
skipping `desktop-env` and `peripherals` too.

## See also

- [../architecture.md](../architecture.md) — the `dirsAsCategory` mechanism
  generally.
- [../hosts.md](../hosts.md) — per-host hardware notes.
