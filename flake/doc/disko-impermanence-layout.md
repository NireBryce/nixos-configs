# A reusable disko layout for the LUKS + btrfs impermanence setup

> **Written by Claude Code.** A working note, not documentation.

`modules/nire/impermanence/_disko/impermanence-luks-btrfs.nix` is a generator
for the disk layout durandal and tenacity already run, by hand, today: one
LUKS-encrypted partition, btrfs inside it, subvolumes for `root` / `home` /
`nix` / `persist` / `log`, and an unmounted `root-blank` subvolume that
`WARN-impermanence.nix`'s initrd unit snapshots from on every boot.

**Nothing imports it.** Same spirit as `dirsAsCategory.md`'s trailhead for
per-module opt-in and `mkPkgModule.md`'s for the single-package generator:
written to have the mechanism ready and checked, not to commit any host to
using it. `nire-testbed` was added with a plain persistent ext4 root instead,
deliberately, and this file exists alongside that decision rather than because
of it.

## Why it's a curried function, not a flake-parts module

```nix
{ device, luksName ? "enc", espSize ? "512M", includeSecureboot ? false, swapSize ? null }:
{ lib, ... }: { disko.devices = ...; fileSystems = ...; }
```

Call it once with a host's own parameters and you get back an ordinary
nixosModule -- a function of `{ lib, ... }`, the shape a host's own `imports`
list actually wants:

```nix
imports = [
    (import ../../nire/impermanence/_disko/impermanence-luks-btrfs.nix {
        device = "/dev/nvme0n1";
    })
];
```

It sits under `_disko/` rather than a normal category directory because
`import-tree` ignores any path containing `/_` by default -- the same rule
`_templates/dirsAsCategory.nix` and `_lib/mkPkgModule.nix` already rely on.
That matters here specifically: this file is not a `flake.modules.<class>.<name>`
module, so if import-tree tried to auto-import it the normal way, it would call
it with the standard flake-parts args (`{ config, lib, inputs, ... }`) instead
of the parameters it actually takes, and fail.

## What it produces, and what it deliberately leaves out

- `root`, `home`, `nix`, `persist`, `log` subvolumes, mounted, with
  `compress=zstd noatime`, matching `hardware-configuration.nix` /
  `hardware-tenacity.nix` exactly.
- `root-blank`, unmounted -- created, never given a `fileSystems` entry. Read
  `WARN-impermanence.nix`'s rollback script before assuming that's a mistake:
  it does `btrfs subvolume snapshot /mnt/root-blank /mnt/root` against the
  btrfs top level, not through any mountpoint.
- `fileSystems."/persist".neededForBoot` and `."/var/log".neededForBoot`, set
  by hand, because disko itself does not infer this -- both real hosts add
  these lines next to their own generated `fileSystems` block for the same
  reason.
- `includeSecureboot` (default off) adds the `secureboot` subvolume mounted at
  `/var/lib/sbctl`, matching durandal's own addition. Off by default because
  it is durandal's, not universal.
- `swapSize` (default `null`, meaning no swap) adds a btrfs swapfile subvolume
  when set. `null` matches tenacity, which has none at all.
- No LUKS `keyFile` or `passwordFile` anywhere. disko's own `luks` type
  defaults `askPassword` to true whenever none of
  `keyFile`/`passwordFile`/`enrollFido2` are set (its `lib/types/luks.nix`),
  which means both disko itself at partition time and
  `boot.initrd.luks.devices` at every later boot prompt interactively --
  which is what durandal and tenacity actually do. Automating that (a key
  file on removable media, TPM enrollment, whatever) is a real, host-specific
  decision this template does not make for you.

## What was actually verified, and how

Not just parsed. Evaluated through disko's own module system
(`nixos/lib/eval-config.nix` with `disko`'s `module.nix` imported alongside
it), twice -- once with every optional parameter at its default, once with
`includeSecureboot = true` and `swapSize = "8G"` -- and the resulting
`config.fileSystems.*`, `config.disko.devices.*` and
`config.boot.initrd.luks.devices` inspected directly, not assumed from reading
the source.

That second run is what caught a real bug before this was ever wired into
anything: the original draft merged the `neededForBoot` block onto the disko
block with `{ disko = ...; fileSystems = ...; } // lib.optionalAttrs cond
{ fileSystems = ...; }` -- `//` merges attrsets shallowly, so whenever
`includeSecureboot` was true, the right-hand `fileSystems` attrset silently
replaced the left one instead of adding to it, and `/persist` and `/var/log`
lost their `neededForBoot` entirely while `/var/lib/sbctl` kept its own. Fixed
by nesting the `//` one level deeper, at the value assigned to `fileSystems`,
not at the two modules being combined. Recorded in the file's own comment too,
not just here.

## If it's ever wanted

1. Decide the real device path and whether this host wants secureboot/swap.
2. Add `inputs.disko.nixosModules.disko` and this file (curried with that
   host's parameters) to the host's own `imports`, the same way any other
   per-host hardware file gets added.
3. Add `impermanence` to that host's category imports too -- this file only
   produces the disk layout, not the actual rollback unit, hibernation
   guards, or persistence entries. Those come from the `impermanence`
   category, same as durandal and tenacity.
4. Run `disko` against the real disk before first boot. This template has
   never been run against real hardware -- everything above is evaluation-level
   verification, not a confirmed install.
