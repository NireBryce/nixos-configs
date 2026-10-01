---
paths:
  - "flake/modules/packages-config/**"
  - "flake/modules/general-config/macos/homebrew/**"
  - "flake/modules/general-config/system/home-manager/drop-unsupported-packages.nix"
---

# Adding or platform-gating a package

Full detail: skill `package-platform-support`; the add-and-verify flow is
skill `new-package`.

`ellyHomeManager` is shared verbatim by all four hosts including
`nire-lysithea`, so everything in it has to survive darwin. Two separate
questions:

- **Can nixpkgs build it on darwin?** Answered automatically off
  `meta.platforms` by `drop-unsupported-packages.nix`. Don't hand-restate
  it with `lib.mkIf (!pkgs.stdenv.isDarwin)`.
- **Does Homebrew already install it?** Never answered automatically;
  `just available --duplicates` finds the overlap.

`obsidian.nix` is the worked example.
