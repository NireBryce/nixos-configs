# `hardware` — `hardware-config/hardware/` (+ nested `amd`)

_Last modified: 2026-10-22_

## Contents

- [Category contents](#category-contents)
- [Nested categories overlap their parents on purpose](#nested-categories-overlap-their-parents-on-purpose)
- [Imported by](#imported-by)
- [See also](#see-also)

## Category contents

Every file is `nixos`-class:

- **`amd/`**, a nested category: `amdcpu/amdcpu.nix`
  (`inputs.nixos-hardware.nixosModules.common-cpu-amd`) and
  `amdgpu/amdgpu.nix` (`inputs.nixos-hardware.nixosModules.common-gpu-amd`,
  plus a package list — mesa, vulkan-tools, `amdgpu_top`, etc. — and
  `hardware.graphics` with 32-bit support, libva-utils and the ROCm OpenCL ICD). Every host
  in this repo is AMD.
- **`bluetooth/bluetooth.nix`** — `hardware.bluetooth` enabled, power on at
  boot, `FastConnectable`, discoverable/pairable timeouts set.
- **`firmware/`** — `firmware-all.nix` (`hardware.enableAllFirmware`,
  `enableRedistributableFirmware`) and `fwupd.nix` (`services.fwupd`, `mkDefault true`). `firmware-all.nix` also
  sets `nixpkgs.config` to the shared `flake.lib.nixpkgs.config` (`allowUnfree`), which `enableAllFirmware` needs.
- **`storage/`** — `smartd.nix` (S.M.A.R.T. monitoring: smartd with autodetect, a short
  self-test daily and a long one weekly) and
  `coredump-limit.nix` (`systemd.coredump` `MaxUse`/`KeepFree` caps).
- **`memory/swap-policy.nix`** — declares the option
  `customOption.swap.policy` (`unmanaged` default, `zram`, `zswap`);
  `zswap` turns zram off and enables `boot.zswap`. Only tenacity sets it
  (`zswap`, in `hardware-tenacity.nix`).

`bluetooth/`, `firmware/`, `storage/` and `memory/` were plain folders in
the [system](system.md) category until 2026-10-15; the hosts that import
`hardware` are the same ones that took them through `system`, so no host
gained or lost anything in the move.

## Nested categories overlap their parents on purpose

`hardware-config/hardware/amd/` is a category of its **own**, nested inside
`hardware`: its subfolders `amdcpu/` and `amdgpu/` hold modules, which is what
makes it one ([module-files.md](../module-files.md)). `hardware` includes `amd`
by name rather than listing `amdcpu`/`amdgpu` again -- a coarse handle
(`hardware`, what every host includes) reaching the same content
as the fine one (`amd`, for if this repo ever needs to distinguish AMD from
Intel hardware), by reference instead of by duplicate derivation. That has
been the shape since the 2026-08-27 collector refactor; before it the parent
recursed straight through and derived the same two modules a second time by
hand, and the effective configuration is identical either way (confirmed by a
full attribute-set diff — `environment.systemPackages`, `systemd.services`,
`users.users` — against the pre-refactor baseline, not just by evaluating
cleanly). Since 2026-10-16 dirs-as-categories builds it. The collector's
history, in `flake/doc/dirsAsCategory.md`, includes the near-miss this once
guarded against: when `dirsAsProvides.nix` was renamed to `dirsAsCategory.nix`
the exclusion list didn't follow, which would have made nested categories
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

Every NixOS host imports `hardware` directly (not the narrower `amd`) —
durandal, tenacity, cube are all AMD (Ryzen desktop/APU, Ryzen Z1
handheld). `nire-lysithea` (darwin, Apple Silicon) does not import this
category at all — importing it would resolve to an empty darwin aggregate
since neither module declares a darwin class, so it's left out rather than
imported for nothing, same reasoning `lysithea-configuration.nix` gives for
skipping `desktop-env` and `peripherals` too.

## See also

- [../module-files.md](../module-files.md) — how categories and modules are built
  generally.
- [../../fleet/hosts.md](../../fleet/hosts.md) — per-host hardware notes.
