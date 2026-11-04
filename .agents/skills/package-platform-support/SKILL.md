---
name: package-platform-support
description: Checks whether nixpkgs builds a package on darwin and whether Homebrew already installs it, for adding or platform-gating a package.
when_to_use: Before adding a package module, adding an isDarwin or platform guard, or deciding whether a cask duplicates a nixpkgs package.
---

# Adding or platform-gating a package

## Applies to

Packages in `elly-home-manager` (`packages-config/`, `users-config/`) are shared verbatim by every host (`host-config/hosts.nix`), including `nire-lysithea` (aarch64-darwin), so everything in it must survive darwin. Use this skill before adding a package module, adding an `isDarwin`/platform guard, or deciding whether a cask duplicates a nixpkgs package. Two separate questions look identical in config, and only one is answered automatically.

## Can nixpkgs build it here? Automatic.

`general-config/system/home-manager/drop-unsupported-packages.nix` re-declares `home.packages` with an `apply` that filters by `lib.meta.availableOn`, **on darwin only**, and warns with what it dropped.

- **Do not add `lib.mkIf (!pkgs.stdenv.isDarwin)` to a single-package module for platform reasons.** `meta.platforms` already says it, and a hand copy can drift (several modules had one; all were correct and none was needed).
- On Linux the filter does nothing, so an unsupported package on durandal stays a loud error.
- The filter only reaches `home.packages`. A body of `programs.foo.enable` or `services.foo.enable` asserts before any package list exists and needs its own guard (`vicinae.nix` is the example).

## Does Homebrew already install it? Never automatic.

`meta.platforms` knows nothing about Homebrew. `homebrew.nix` (`flake/modules/general-config/macos/homebrew/`) installs casks, and some are also nixpkgs packages in `elly-home-manager`, so lysithea gets two copies.

```sh
just available --duplicates   # only the ones homebrew ALSO installs, and what to do
```

Which copy wins is a per-app decision. In `obsidian.nix` (worked example) the `isDarwin` test means "on darwin, `homebrew.nix` owns this app", not "Linux-only". Read every remaining `isDarwin` in `packages-config/` that way, and check which question it answers before copying it.

## Darwin-only package: restating the platform IS correct

When a package's `meta.platforms` names only darwin (`cmux.nix`, `[ "aarch64-darwin" ]`, added 2026-09-01), the filter does nothing on Linux. It is `if pkgs.stdenv.hostPlatform.isDarwin then <filter> else packages`, so on Linux the raw package sits in `home.packages`. `nix flake check` and the toplevel build then throw `Refusing to evaluate package ... because it is not available on the requested hostPlatform` on durandal, tenacity and cube once `buildEnv` forces it. Leave the package unguarded only if it has not been tried on Linux; guard it if it will never build there.

Guard it by hand, in the opposite direction from `obsidian.nix`:

```nix
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.packages = with pkgs; [ cmux ];
}
```

This is the one legitimate restatement of `meta.platforms`: for darwin-only packages the filter provably does nothing on the hosts that need protection. Full workflow: skill `new-package`.

This skill was `nirepackages-platform-support` until 2026-09-29 (the `nirePackages/` area is now `packages-config/`).
