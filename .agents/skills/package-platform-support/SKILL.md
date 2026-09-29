---
name: package-platform-support
description: How to tell whether nixpkgs can build a package on darwin and whether Homebrew already installs it, when adding or platform-gating a package in this repo.
---

# Adding or platform-gating a package

## Applies to

Packages in `ellyHomeManager` (`packages-config/`, `users-config/`), shared
verbatim by all four hosts including `nire-lysithea` (aarch64-darwin), so
everything in it must survive darwin. Use before adding a package module, an
`isDarwin`/platform guard, or deciding whether a cask duplicates a nixpkgs
package. Two different questions look identical in config; only one is
answered automatically.

## Can nixpkgs build it here? Automatic.

`general-config/system/home-manager/drop-unsupported-packages.nix`
re-declares `home.packages` with an `apply` filtering by
`lib.meta.availableOn`, **on darwin only**, warning with what it dropped.

- **Don't add `lib.mkIf (!pkgs.stdenv.isDarwin)` to a single-package module
  for platform reasons**; `meta.platforms` already says it and a hand copy
  can drift (eleven modules did, all correct, none needed).
- On Linux the filter is a no-op on purpose: an unsupported package on
  durandal stays a loud error.
- It only reaches `home.packages`. A body of `programs.foo.enable` /
  `services.foo.enable` asserts before any package list exists and needs its
  own guard (`vicinae.nix` is the example).

## Does Homebrew already install it? Never automatic.

`meta.platforms` knows nothing of Homebrew. `homebrew.nix`
(`flake/modules/general-config/macos/homebrew/`) installs casks, some also
nixpkgs packages in `ellyHomeManager`: lysithea gets two copies.

```sh
just available --duplicates   # only the ones homebrew ALSO installs, and what to do
```

Which wins is per-app judgement. In `obsidian.nix` (worked example) the
`isDarwin` test means *"on darwin, homebrew.nix owns this app"*, **not**
*"Linux-only"*. Read every remaining `isDarwin` in `packages-config/` that
way; check which question it answers before copying it.

## Darwin-only package: restating the platform IS correct

Mirror case: a package whose `meta.platforms` names **only** darwin
(`cmux.nix`, `[ "aarch64-darwin" ]`, added 2026-09-01). The filter is
`if pkgs.stdenv.hostPlatform.isDarwin then <filter> else packages`, so on
Linux it is the identity: the raw package sits in `home.packages` and
`nix flake check`/the toplevel build throws `Refusing to evaluate package
... because it is not available on the requested hostPlatform` on durandal,
tenacity, and cube once `buildEnv` forces it. Right for a never-tested-on-Linux
package; wrong for one that never will build there.

Guard by hand, opposite direction from `obsidian.nix`:

```nix
lib.mkIf pkgs.stdenv.isDarwin {
    home.packages = with pkgs; [ cmux ];
}
```

The one legitimate restatement of `meta.platforms`: for darwin-only packages
the filter provably does nothing on the hosts needing protection. Full
workflow: skill `new-package`.

This skill was `nirepackages-platform-support` until 2026-09-29 (the
`nirePackages/` area is now `packages-config/`).
