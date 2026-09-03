# flake-parts

## Contents

- [Why flake-parts](#why-flake-parts)
- [See also](#see-also)

The one fact worth knowing before reading `flake.nix` or any module for the
first time: this repo depends on exactly one flake-parts option, and almost
everything else about how the tree is organized follows from it. Moved out
of [architecture.md](architecture.md) 2026-09-03 to sit ahead of it —
architecture is the mechanism built on top of this, not this itself.

## Why flake-parts

- **[`../flake/doc/flake-parts-rationale.md`](<../flake/doc/flake-parts-rationale.md>)**
  — the payoff is one option, `flake.modules.<class>.<name>`, which lets a
  single file declare a NixOS module and a Home Manager module as sibling
  attributes instead of two files tied together only by a shared filename
  (`nixd.nix` is the worked example). Also inventories, by grep rather than
  assumption, which other flake-parts machinery this repo actually calls
  (`perSystem` for `nix flake check` only, `withSystem` once, `touchup` for
  one line) and which it never touches (`moduleWithSystem`, `debug`,
  overlay/`legacyPackages` composition, dev shells, any bundled
  `flakeModules` besides `modules` and `touchup`).

## See also

- [architecture.md](architecture.md) — `dirsAsCategory`, the mechanism
  built on the option above: category membership derived from directory
  placement rather than declared per module.
- [`../flake/doc/dirsAsCategory.md`](<../flake/doc/dirsAsCategory.md>) —
  that mechanism in full.
