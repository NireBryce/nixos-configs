# flake-parts

_Last modified: 2026-10-20_

This repo depends on exactly one flake-parts option, `flake.modules.<class>.<name>`,
and almost everything about how the tree is organized follows from it. Read
this before `flake.nix` or any module; [architecture.md](architecture.md)
covers the mechanism built on top.

## Contents

- [Why flake-parts](#why-flake-parts)
- [See also](#see-also)

## Why flake-parts

- **[`../flake/doc/flake-parts-rationale.md`](<../../flake/doc/flake-parts-rationale.md>)**
  — the payoff is one option, `flake.modules.<class>.<name>`, which lets a
  single file declare a NixOS module and a Home Manager module as sibling
  attributes instead of two files tied together only by a shared filename
  (`nixd.nix`, since moved to the dev shell, is the worked example). Also inventories, by grep rather than
  assumption, which other flake-parts machinery this repo calls
  (`perSystem` for `nix flake check` and the one dev shell, `withSystem` once, `touchup` for
  one line) and which it never touches (`moduleWithSystem`, `debug`,
  overlay/`legacyPackages` composition, any bundled
  `flakeModules` besides `modules` and `touchup`).

## See also

- [architecture.md](architecture.md) — the category mechanism built on the
  option above: category membership derived from directory placement rather
  than declared per module.
- [module-files.md](module-files.md) — that mechanism as this repo uses it,
  through the `dirs-as-categories` input;
  [`../flake/doc/dirsAsCategory.md`](<../../flake/doc/dirsAsCategory.md>) is
  the shim-based design it replaced.
