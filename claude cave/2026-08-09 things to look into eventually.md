security improvements: https://github.com/SaschaOnTour/NixOS

---

Open questions rescued from HANDOFF-tenacity.md before deleting it (2026-08-11).
Both predate the branch booting and neither has been decided:

- Are the `peripherals` modules (`logitech-g600`, `zsa-moonlander`) still wanted
  on a handheld? They came across from the pre-restructure config unexamined.
- Is full desktop package parity still wanted on tenacity — vscode, gimp,
  libre-office, zoom? It was a deliberate choice on the sibling branch, made
  before anyone had run this on the hardware.

Answered since, and recorded elsewhere: the handheld stack does work. jovian's
Steam autostart, decky-loader and handheld-daemon with adjustor all run — hhd
needed a nixpkgs patch (see jovian.nix) and its overlay thread still dies on the
display, but the daemon and its plugins load.
