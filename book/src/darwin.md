# Darwin edge cases

This chapter lists what behaves differently on the nix-darwin host, so that
you do not rediscover each difference. The Home Manager bundle is shared
verbatim with the Linux hosts, so every difference has to be absorbed per
module or per package, never by forking the bundle. Unfamiliar terms are in
the [glossary](glossary.md).

## How the darwin host is built

- The host is declared in `flake/modules/host-config/hosts.nix` through
  `mkDarwinHost`, which mirrors the NixOS helper but calls nix-darwin's
  `darwinSystem`. Like the NixOS helper, `mkDarwinHost` deliberately does
  *not* take `pkgs` from flake-parts' per-system scope
  ([perSystem](glossary.md#persystem)). That `pkgs` instance has no
  `nixpkgs.config` applied and would silently drop `allowUnfree`.
- The host's definition is
  `flake/modules/host-config/lysithea-configuration.nix`, which lists
  categories under `includes.darwin`. A
  [category](glossary.md#category) is a folder whose modules a host takes by
  one name.
- `darwin` is its own [module class](glossary.md#module-class), the kind of
  configuration a module targets. A category's darwin
  [aggregate](glossary.md#aggregate) contains only the modules that have a
  `darwin` key, so including a broad category like `system` does not drag in
  Linux-only modules (bluetooth, networking and so on).
- Categories that declare nothing darwin-class (`hardware`, `desktop-env`,
  `peripherals`) are left out of the host's list instead of being included
  to resolve to nothing.

Source: `flake/modules/host-config/hosts.nix`,
`flake/modules/host-config/lysithea-configuration.nix`,
[`wiki/config-structure/categories/macos.md`](../../wiki/config-structure/categories/macos.md).

## One bundle, two platforms

Every host imports `elly-home-manager`, the Mac included (see
[users and Home Manager](users-and-home-manager.md)). Adding a package to
that shared bundle raises two separate questions with different answers.

### "Can nixpkgs build it here?" is automatic

`flake/modules/general-config/system/home-manager/drop-unsupported-packages.nix`
re-declares `home.packages` with an `apply` function that filters by
`lib.meta.availableOn`, **on darwin only**, and warns by name about each
package it drops. On Linux the filter does nothing, deliberately: an
unbuildable package on the main hosts should stay a loud error.

So **do not** hand-write `lib.mkIf (!pkgs.stdenv.isDarwin)` around a package
because it does not build on macOS; `meta.platforms` already records that.

The filter has three limits, each of which has caught someone:

- It cannot catch `meta.broken`. A package marked broken on darwin passes the
  filter and then fails evaluation. `cod` is the live example, which is why
  the zsh and bash modules still guard their `cod` lines by hand.
- It only reaches `home.packages`. A module that sets
  `programs.foo.enable = true` asserts before any package list exists, so it
  needs its own guard (`vicinae.nix`, `kde-connect.nix` and
  `kde-sleepmode.nix` are examples).
- It cannot be replaced by making `imports` conditional on `pkgs`. Under
  [`useGlobalPkgs`](glossary.md#useglobalpkgs-and-useuserpackages) a
  conditional `imports` is a genuine infinite recursion, confirmed by trying
  it on the Linux hosts. Filtering has to happen on values, not imports.

### "Does Homebrew already install it?" is never automatic

`meta.platforms` knows nothing about Homebrew. If `homebrew.nix` installs a
cask for an app that a nixpkgs module also installs, the Mac gets two
copies. `just available --duplicates` lists the overlaps.

Read an existing `isDarwin` in a package module carefully. In
`obsidian.nix` the guard means "on darwin, Homebrew owns this app", not
"Linux only".

The mirror case: a package whose `meta.platforms` names only darwin must be
guarded by hand on Linux. The filter is the identity function there, and the
raw package would fail evaluation on the Linux hosts.

Source: `drop-unsupported-packages.nix`,
`.agents/skills/package-platform-support/SKILL.md`,
`flake/modules/users-config/elly-home-manager.nix` (header comment).

## Homebrew is declarative, and removes things

`flake/modules/general-config/macos/homebrew/homebrew.nix` sets
`homebrew.onActivation.cleanup = "uninstall"`. A formula or cask that is not
listed in `homebrew.nix` is **removed** on the next switch. If you install
something by hand with `brew` and it vanishes, that setting is why. Add it to
`homebrew.nix`.

Source: `wiki/config-structure/categories/macos.md`.

## Small differences that bite

- Home directory: `hm-config.nix` defaults `home.homeDirectory` to
  `/home/<user>` with the note "Darwin is different". The darwin system
  module (`general-config/macos/system-settings/darwin-system.nix`) sets
  `users.users.<user>.home = "/Users/<user>"` and `system.primaryUser`, which
  nix-darwin needs for Homebrew and for launchd user-context activation.
- Nix itself: `darwin-system.nix` also sets `nix.enable = true`, so
  nix-darwin manages the Nix installation instead of assuming an external
  installer owns it.
- Shells: `macos/shells/shells.nix` registers bash, zsh and fish in
  `/etc/shells` and links their share directories. zsh's own completion is
  forced off at the system level so that it does not fight Home Manager's.
- Activation: Home Manager activates through launchd instead of a systemd
  unit. The darwin integration module does not set `backupFileExtension`
  (the NixOS one does), so an unowned file in the way aborts activation
  instead of being renamed. See the split-brain section of
  [users and Home Manager](users-and-home-manager.md).
- Fonts: the user's fonts are installed from the `darwin` class of
  `elly-user.nix`.
- Tailscale: the NixOS Tailscale module never reaches darwin; on the Mac,
  Tailscale is the `tailscale-app` cask. A Homebrew auto-update of a system
  extension can leave the old and new extension in a half-finished
  transaction until the machine is rebooted, which looks like "the service
  won't install". The fix recorded in the wiki is a reboot, not a config
  change.

Source: `flake/modules/general-config/macos/`,
`flake/modules/users-config/elly/hm-config/hm-config.nix`,
`flake/modules/users-config/elly/user-settings/elly-user.nix`,
`wiki/config-structure/categories/macos.md`.

## Things that do not exist on darwin

- Impermanence: the `/root` wipe is a NixOS-host mechanism (see
  [impermanence](glossary.md#impermanence)); the darwin host is an ordinary
  persistent system. `just boot` is NixOS-only for the same reason:
  nix-darwin has no boot generation to stage.
- sops-nix paths: on the Mac,
  `flake/modules/general-config/system/secrets/sops-darwin.nix` points
  `SOPS_AGE_KEY_FILE` at the Linux-style XDG path directly, so `sops` finds
  the key. Read the names of secrets only, never values, as everywhere in
  this repo.

## Building and verifying

- A NixOS host cannot be built from any other machine: there is no remote
  builder and no binfmt. `flake/scripts/rebuild.sh` says so, and picks
  `nh darwin` or `nh os` from the flake. Unverified here: how far a darwin
  host can be evaluated from a Linux machine. Say which level you actually
  reached (evaluated, built, switched), and do not claim the Mac works on
  the strength of a Linux evaluation.
- `nix flake check` did not force `darwinConfigurations` by itself until
  `flake/modules/checks.nix` started doing it: flake-check warns about an
  unknown output and evaluates nothing inside it. The repo's check now
  evaluates the Mac's configuration too, but a cheap attribute is still not
  a build.
- When you change something in the shared bundle, check the Mac's
  evaluation as well as the Linux one. The two use different `pkgs`, and a
  package that is fine on Linux can be the one that fails on the Mac.
- `just baseline` and `just diff-deployed` answer "does the host run what
  the tree says", and only work on the host itself.

Source: `AGENTS.md` ("Commands"), `flake/scripts/rebuild.sh`.

## Checklist: adding something to the shared bundle

1. Check whether nixpkgs builds the package on `aarch64-darwin`
   (`just available <pkg>`). If it does not, there is nothing to do: the
   filter warns and drops it.
2. Check whether the package is `meta.broken` there, or behavioural
   (option-shaped, asserts early). If so, guard the module with
   `lib.mkIf (!pkgs.stdenv.isDarwin)`.
3. Check whether Homebrew already installs it. Run
   `just available --duplicates` and decide which side owns it.
4. Evaluate the darwin host as well as a Linux host.
