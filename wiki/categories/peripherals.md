# `peripherals` — `nire/peripherals/`

## What's in it

Two small files, both `nixos`-class, both single-option one-liners:

- **`logitech-g600/logitech-g600.nix`** — `services.ratbagd.enable = true;`,
  for Piper to control the mouse.
- **`zsa-moonlander/zsa-moonlander.nix`** — `hardware.keyboard.zsa.enable = true;`.

## Open question this category carries

Whether these are still wanted at all is explicitly unresolved — see
[../open-threads.md](../open-threads.md): both modules "came across from the
pre-restructure config unexamined" per a note rescued from a deleted handoff
doc, and nobody's revisited whether either peripheral is still in use on the
hosts that import this category.

## Imported by

All three NixOS hosts (`durandal`, `tenacity`, `cube`) — not
`lysithea`, left out rather than imported-for-nothing since neither module
declares a `darwin` class (same reasoning as [hardware](hardware.md) and
[desktop-env](desktop-env.md) being absent from lysithea's imports).

## See also

- [../open-threads.md](../open-threads.md) — the unresolved "still wanted?"
  question.
