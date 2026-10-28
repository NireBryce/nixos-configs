# `boot` — `general-config/boot/`

_Last modified: 2026-10-22_

## Contents

- [Category contents](#category-contents)
- [Why each file sits in a subdirectory](#why-each-file-sits-in-a-subdirectory)
- [The name trap this category is the origin of](#the-name-trap-this-category-is-the-origin-of)
- [Don't confuse this with the impermanence category](#dont-confuse-this-with-the-impermanence-category)
- [Imported by](#imported-by)
- [See also](#see-also)

## Category contents

The files:

- `generations/boot-generations.nix` caps how many bootloader generations
  systemd-boot keeps.
- `editor/boot-editor.nix` turns off kernel command-line editing at the
  systemd-boot menu (nixpkgs defaults it on; `init=/bin/sh` there is a root
  shell). Recovery parameters now go through `boot.kernelParams` and a
  rebuild, an older generation, or a live USB.
- `power-button/no-tiny-power-button.nix` blacklists the kernel module
  `tiny_power_button` (a VM-only driver that, on 6.18.57, binds the real
  power button and powers off at once instead of suspending). TEMPORARY: it
  warns at eval time when the kernel version differs from the one it was
  confirmed on; removal condition in `wiki/upkeep-and-admin/temporary-patches-and-hacks.md`.

## Why each file sits in a subdirectory

Until 2026-09-28 the category collector skipped `.nix` files sitting
straight in a category's own directory, so a module directly in
`general-config/boot/` reached nothing — hence `generations/`, `editor/` and `power-button/`
(`flake/doc/dirsAsCategory.md`'s History). Since 2026-10-16 they are what
makes `boot` a category at all: a folder with a subfolder holding modules is
one ([module-files.md](../module-files.md)). **Flatten both and `boot`
stops being a category**, and every host's `includes` of it fails to
evaluate.

## The name trap this category is the origin of

The module can't be named `boot.nix`. A module's name is its filename, so
`boot.nix` here would be a module named `boot` — the name of this category.
Today that stops evaluation, naming both; until 2026-10-16 the two **merged**
rather than conflicting, and that merge was invisible: both halves would
probably look like they work. This is literally the trap `CLAUDE.md`'s Traps section cites by name
("This is how `boot` came to mean both `general-config/boot/` ... and durandal's
bootloader"), and it's also why
`host-config/durandal/hardware/boot-durandal.nix` and the other hosts'
per-host boot files (`hardware/boot-tenacity.nix`, `hardware/boot-cube.nix`)
carry a host-suffixed name instead of the generic one they'd naturally want.

## Don't confuse this with the impermanence category

`general-config/boot/` is about the bootloader (generation count,
menu editor, a power-button workaround). It is
**not** the category that wipes `/root` — that's [impermanence](impermanence.md),
named `boot` itself until 2026-08-11, which is exactly the confusion the
rename was meant to end. If you're looking for the `/root` rollback, you
want `impermanence`, not this page.

## Imported by

Every NixOS host (`durandal`, `tenacity`, `cube`) — not
`lysithea` (darwin has no bootloader-generation concept here).

## See also

- [impermanence](impermanence.md) — the category this one is easy to
  confuse with by name history.
- [../../meta/traps-and-skills.md](../../meta/traps-and-skills.md) — the general form of the
  name-collision trap.
