# `boot` — `general-config/boot/`

_Last modified: 2026-09-28_

## Contents

- [What's in it](#whats-in-it)
- [Why each file sits in a subdirectory](#why-each-file-sits-in-a-subdirectory)
- [The name trap this category is the origin of](#the-name-trap-this-category-is-the-origin-of)
- [Don't confuse this with the impermanence category](#dont-confuse-this-with-the-impermanence-category)
- [Imported by](#imported-by)
- [See also](#see-also)

## What's in it

Two files:

- `generations/boot-generations.nix` caps how many bootloader generations
  systemd-boot keeps.
- `editor/boot-editor.nix` turns off kernel command-line editing at the
  systemd-boot menu (nixpkgs defaults it on; `init=/bin/sh` there is a root
  shell). Recovery parameters now go through `boot.kernelParams` and a
  rebuild, an older generation, or a live USB.

## Why each file sits in a subdirectory

Until 2026-09-28 `dirsAsCategory` skipped `.nix` files sitting straight in a
category's own directory, so a module directly in `general-config/boot/`
reached nothing — hence `generations/` and `editor/`. That rule is gone
(`flake/doc/dirsAsCategory.md`'s History); the subdirectories stay as
grouping.

## The name trap this category is the origin of

The module can't be named `boot.nix`. A module's declared name is its
filename, so `boot.nix` here would declare `flake.modules.nixos.boot` — the
exact attribute name this category's own `dirsAsCategory.nix` already
declares for its aggregate — and same-named modules **merge** rather than
conflict. That merge is invisible: both halves would probably look like they
work. This is literally the trap `CLAUDE.md`'s Traps section cites by name
("This is how `boot` came to mean both `general-config/boot/` ... and durandal's
bootloader"), and it's also why
`host-config/durandal/hardware/boot-durandal.nix` and the other hosts'
per-host boot files (`hardware/boot-tenacity.nix`, `hardware/boot-cube.nix`)
carry a host-suffixed name instead of the generic one they'd naturally want.

## Don't confuse this with the impermanence category

`general-config/boot/` is genuinely about the bootloader (generation count,
menu editor). It is
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
