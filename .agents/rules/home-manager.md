---
paths:
  - "flake/modules/general-config/shell-config/**"
  - "flake/modules/general-config/system/home-manager/**"
  - "flake/modules/general-config/macos/shells/**"
  - "flake/modules/users-config/**"
  - "flake/doc/trailhead-home-manager-standalone.md"
---

# Home Manager modules and dotfiles

Full traps and integration specifics (rejected `nixpkgs.*`,
`profileDirectory`, activation's `PATH`): skill `home-manager-dotfiles`.

- Home Manager is NixOS-integrated: `home-manager.users.elly` is set from
  the system side with `useGlobalPkgs` and `useUserPackages`, in
  `general-config/system/home-manager/enable-home-manager.nix`. No
  `homeConfigurations` output, no separate home switch; `just switch`
  applies both. `flake/doc/trailhead-home-manager-standalone.md` is the way
  back.
- `ellyHomeManager` is shared verbatim by all four hosts including
  `nire-lysithea`, so everything in it has to survive darwin.
- `home.file.<n>.text` and `home.sessionPath` concatenate across modules
  rather than override: two modules writing the "same" file double it,
  silently.
- Reading a generated dotfile back is full of false negatives: a wrong
  attribute name returns empty, and some entries have `.source`, not
  `.text`.
- HM's rc ordering has silently orphaned hand-written rc content before (a
  `starship init`, a 1,659-line p10k config). Check where a block lands in
  the generated file, not just that it is present.
- Read HM's module source before assuming an option exists: there is no
  blesh module, and `home.sessionPath` is `listOf str`.
