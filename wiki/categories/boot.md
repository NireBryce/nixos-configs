# `boot` — `nire/boot/`

## What's in it

One file: `generations/boot-generations.nix`, caps how many bootloader
generations systemd-boot keeps. That's the whole category.

## Why one file needs a subdirectory

`dirsAsCategory` only collects from *sub*directories of the category
directory — a `.nix` file sitting straight in `nire/boot/` would be
collected by nothing (see [../architecture.md](../architecture.md)). Hence
`generations/`.

## The name trap this category is the origin of

The module can't be named `boot.nix`. A module's declared name is its
filename, so `boot.nix` here would declare `flake.modules.nixos.boot` — the
exact attribute name this category's own `dirsAsCategory.nix` already
declares for its aggregate — and same-named modules **merge** rather than
conflict. That merge is invisible: both halves would probably look like they
work. This is literally the trap `CLAUDE.md`'s Traps section cites by name
("This is how `boot` came to mean both `nire/boot/` ... and durandal's
bootloader"), and it's also why
`nireHost/durandal/hardware/boot-durandal.nix` and the other hosts'
per-host boot files (`hardware/boot-tenacity.nix`, `hardware/boot-cube.nix`)
carry a host-suffixed name instead of the generic one they'd naturally want.

## Don't confuse this with the impermanence category

`nire/boot/` is genuinely about the bootloader (generation count). It is
**not** the category that wipes `/root` — that's [impermanence](impermanence.md),
named `boot` itself until 2026-08-11, which is exactly the confusion the
rename was meant to end. If you're looking for the `/root` rollback, you
want `impermanence`, not this page.

## Imported by

All three NixOS hosts (`durandal`, `tenacity`, `cube`) — not
`lysithea` (darwin has no bootloader-generation concept here).

## See also

- [impermanence](impermanence.md) — the category this one is easy to
  confuse with by name history.
- [../traps-and-skills.md](../traps-and-skills.md) — the general form of the
  name-collision trap.
