# `peripherals` — `hardware-config/peripherals/`

_Last modified: 2026-10-22_

## Contents

- [What's in it](#whats-in-it)
- [The "still wanted?" question](#the-still-wanted-question)
- [Imported by](#imported-by)
- [See also](#see-also)

## What's in it

Small files, all `nixos`-class, each a single-option one-liner:

- **`logitech-g600/logitech-g600.nix`** — `services.ratbagd.enable = true;`,
  for Piper to control the mouse.
- **`zsa-moonlander/zsa-moonlander.nix`** — `hardware.keyboard.zsa.enable = true;`.

## The "still wanted?" question

Was tracked as [#440](https://github.com/NireBryce/nixos-configs/issues/440):
both modules "came across from the pre-restructure config unexamined" per a
note rescued from a deleted handoff doc, and nobody had revisited whether
either peripheral is still in use on the hosts that import this category.
Closed as dropped 2026-10-07 without a per-host decision. Revisited for
tenacity on 2026-10-15: neither device is used on the handheld, so it no
longer imports the category; durandal and cube still do.

## Imported by

`durandal` and `cube`. Not `tenacity` (dropped 2026-10-15, above), and not
`lysithea`, left out rather than imported-for-nothing since neither module
declares a `darwin` class (same reasoning as [hardware](hardware.md) and
[desktop-env](desktop-env.md) being absent from lysithea's imports).

## See also

- [#440](https://github.com/NireBryce/nixos-configs/issues/440) — the
  "still wanted?" question, closed as dropped 2026-10-07.
