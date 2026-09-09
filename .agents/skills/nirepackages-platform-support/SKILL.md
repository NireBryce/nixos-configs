---
name: nirepackages-platform-support
description: How platform support and Homebrew overlap work for packages in ellyHomeManager in this repo.
---

# Adding or platform-gating a package

## Applies to

Packages in `ellyHomeManager` (`nirePackages/`, `nireUser/`), shared across
all five hosts including darwin. Use before adding a package module, adding
an `isDarwin`/platform guard, or deciding whether a cask duplicates a
nixpkgs package.

`ellyHomeManager` is shared verbatim by all five hosts, including
`nire-lysithea` (aarch64-darwin), so everything in it has to survive darwin.
Two different questions come up here, they look identical in the config, and
only one of them is answered for you automatically.

## Can nixpkgs build it here? Answered automatically.

`nire/system/home-manager/drop-unsupported-packages.nix` re-declares
`home.packages` with an `apply` that filters by `lib.meta.availableOn`, **on
darwin only**, and warns naming everything it dropped. So:

- **Do not add `lib.mkIf (!pkgs.stdenv.isDarwin)` to a single-package module
  for platform reasons.** `meta.platforms` already says it; restating it by
  hand is a claim that can drift. Eleven modules used to, all correct, none
  necessary.
- On Linux the filter does nothing, deliberately — an unsupported package on
  durandal stays a loud error, because that is a mistake worth stopping on.
- It only reaches `home.packages`. A module whose body is
  `programs.foo.enable` or `services.foo.enable` asserts before any package
  list exists, so those still need their own guard — `vicinae.nix` is the
  worked example and says so.

## Does Homebrew already install it? Never answered automatically.

`meta.platforms` has no opinion about Homebrew and never will.
`homebrew.nix` (`flake/modules/nire/macos/homebrew/`) installs 59 casks, and
some of them are also nixpkgs packages in `ellyHomeManager` — lysithea gets
two copies of each when that happens. Run:

```sh
just available --duplicates   # only the ones homebrew ALSO installs, and what to do
```

Deciding which one wins is a judgement call per app. `obsidian.nix` is the
worked example, and its `isDarwin` test means *"on darwin, homebrew.nix owns
this app"* — **not** *"Linux-only"*. Read every remaining `isDarwin` in
`nirePackages/` that way and check which of the two questions above it's
actually answering before copying it.

## Is it darwin-only? The one case where restating the platform IS correct.

The first section's "do not add `lib.mkIf (!pkgs.stdenv.isDarwin)`" rule has a
mirror image it does not cover: a package whose `meta.platforms` names
**only** a darwin system (`cmux.nix` — `[ "aarch64-darwin" ]` — is the worked
example, added 2026-09-01). `drop-unsupported-packages.nix`'s filter runs
`if pkgs.stdenv.hostPlatform.isDarwin then <filter> else packages`, so on
Linux it is the *identity function* — the raw, unfiltered package sits in
`home.packages` regardless, and `nix flake check`/the toplevel build throws
`Refusing to evaluate package ... because it is not available on the
requested hostPlatform` on durandal, tenacity, and cube the moment
`home.packages`' `buildEnv` forces its derivation. That is the "stays a loud
error, deliberately" behavior from the section above — correct for a package
that was merely never tested on Linux, wrong here because the package is
never *going* to build there.

Guard it by hand, the opposite direction from `obsidian.nix`:

```nix
lib.mkIf pkgs.stdenv.isDarwin {
    home.packages = with pkgs; [ cmux ];
}
```

This is the one legitimate case in the tree for restating a `meta.platforms`
fact instead of trusting the automatic filter — because for a darwin-only
package the automatic filter provably does nothing on the hosts that need
protecting. See skill `new-package` for the full add-a-package workflow this
slots into.
