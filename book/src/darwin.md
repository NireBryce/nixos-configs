# Darwin edge cases

This chapter lists what behaves differently on the one nix-darwin host, so that
you do not rediscover each of them. The short version: the Home Manager
bundle is shared verbatim with the Linux hosts, so every difference has to be
absorbed per module or per package, never by forking the bundle.

## How the darwin host is built

- It is declared in `flake/modules/host-config/hosts.nix` through
  `mkDarwinHost`, which mirrors the NixOS helper but calls nix-darwin's
  `darwinSystem`. Like the NixOS helper, it deliberately does *not* take `pkgs`
  from flake-parts' per-system scope, because that instance has no
  `nixpkgs.config` applied and would silently drop `allowUnfree`.
- Its definition is `flake/modules/host-config/lysithea-configuration.nix`,
  which lists categories under `includes.darwin`.
- `darwin` is its own module class. A category's darwin aggregate contains
  only the modules that have a `darwin` key, so including a broad category
  like `system` does not drag in Linux-only modules (bluetooth, networking and
  so on).
- Categories that declare nothing darwin-class (`hardware`, `desktop-env`,
  `peripherals`) are left out of the host's list rather than included to
  resolve to nothing.

Source: `flake/modules/host-config/hosts.nix`,
`flake/modules/host-config/lysithea-configuration.nix`,
[`wiki/config-structure/categories/macos.md`](../../wiki/config-structure/categories/macos.md).

## One bundle, two platforms

`elly-home-manager` is imported by every host, the Mac included
(see [users and Home Manager](users-and-home-manager.md)). Two different
questions come up, and they have different answers.

### "Can nixpkgs build it here?" is automatic

`flake/modules/general-config/system/home-manager/drop-unsupported-packages.nix`
re-declares `home.packages` with an `apply` function that filters by
`lib.meta.availableOn`, **on darwin only**, and warns by name about each
package it drops. On Linux it does nothing, deliberately: an unbuildable
package on the main hosts should stay a loud error.

So **do not** hand-write `lib.mkIf (!pkgs.stdenv.isDarwin)` around a package
just because it does not build on macOS; `meta.platforms` already says so.

Limits of the filter, each of which has caught someone:

- It cannot catch `meta.broken`. A package marked broken on darwin passes the
  filter and then fails evaluation. `cod` is the live example, which is why
  the zsh and bash modules still guard their `cod` lines by hand.
- It only reaches `home.packages`. A module that sets
  `programs.foo.enable = true` asserts before any package list exists, so it
  needs its own guard (`vicinae.nix`, `kde-connect.nix` and `kde-sleepmode.nix`
  are examples).
- It cannot be done by making `imports` conditional on `pkgs`. Under
  `useGlobalPkgs` that is a genuine infinite recursion, confirmed by trying it
  on the Linux hosts. Filtering has to happen on values, not imports.

### "Does Homebrew already install it?" is never automatic

`meta.platforms` knows nothing about Homebrew. If `homebrew.nix` installs a
cask for an app that a nixpkgs module also installs, the Mac gets two copies.
`just available --duplicates` lists the overlaps.

Read an existing `isDarwin` in a package module carefully: in `obsidian.nix` it
means "on darwin, Homebrew owns this app", not "Linux only".

Mirror case: a package whose `meta.platforms` names only darwin must be
guarded by hand on Linux, because the filter is the identity there and the raw
package would fail evaluation on the Linux hosts.

Source: `drop-unsupported-packages.nix`,
`.agents/skills/package-platform-support/SKILL.md`,
`flake/modules/users-config/elly-home-manager.nix` (header comment).

## Homebrew is declarative, and removes things

`flake/modules/general-config/macos/homebrew/homebrew.nix` sets
`homebrew.onActivation.cleanup = "uninstall"`. A formula or cask that is not
listed in the file is **removed** on the next switch. If you install something
by hand with `brew` and it vanishes, that is why. Add it to the file.

Source: `wiki/config-structure/categories/macos.md`.

## Small differences that bite

- **Home directory.** `hm-config.nix` defaults `home.homeDirectory` to
  `/home/<user>` with the note "Darwin is different". The darwin system module
  (`general-config/macos/system-settings/darwin-system.nix`) sets
  `users.users.<user>.home = "/Users/<user>"` and `system.primaryUser`, which
  nix-darwin needs for Homebrew and for launchd user-context activation.
- **Nix itself.** The same module sets `nix.enable = true`, so nix-darwin
  manages the Nix installation rather than assuming an external installer
  owns it.
- **Shells.** `macos/shells/shells.nix` registers bash, zsh and fish in
  `/etc/shells` and links their share directories; zsh's own completion is
  forced off at the system level so it does not fight Home Manager's.
- **Activation.** Home Manager activates through launchd instead of a systemd
  unit. The darwin integration module does not set `backupFileExtension`
  (the NixOS one does), so an unowned file in the way aborts activation rather
  than being renamed. See the split-brain section of
  [users and Home Manager](users-and-home-manager.md).
- **Fonts.** The user's fonts are installed from the `darwin` class of
  `elly-user.nix`.
- **Tailscale.** The NixOS Tailscale module never reaches darwin; on the Mac
  Tailscale is the `tailscale-app` cask. A Homebrew auto-update of a system
  extension can leave the old and new extension in a half-finished
  transaction until the machine is rebooted, which looks like "the service
  won't install". The fix recorded in the wiki is a reboot, not a config
  change.

Source: `flake/modules/general-config/macos/`,
`flake/modules/users-config/elly/hm-config/hm-config.nix`,
`flake/modules/users-config/elly/user-settings/elly-user.nix`,
`wiki/config-structure/categories/macos.md`.

## Building and verifying

- A NixOS host cannot be built from any other machine: there is no remote
  builder and no binfmt. `flake/scripts/rebuild.sh` says so, and picks
  `nh darwin` or `nh os` from the flake. Unverified here: how far a darwin
  host can be evaluated from a Linux machine. Say which level you actually
  reached (evaluated, built, switched) and do not claim the Mac works on the
  strength of a Linux evaluation.
- When you change something in the shared bundle, check the Mac's evaluation
  too, not only the Linux one. The two use different `pkgs`, and a package
  that is fine on Linux can be the one that fails there.
- `just baseline` and `just diff-deployed` answer "does the host run what
  the tree says" and only work on the host itself.

Source: `AGENTS.md` ("Commands"), `flake/scripts/rebuild.sh`.

## Checklist: adding something to the shared bundle

1. Does nixpkgs build it on `aarch64-darwin`? If not, nothing to do; the
   filter warns and drops it.
2. Is it `meta.broken` there, or behavioural (option-shaped, asserts early)?
   Then guard the module with `lib.mkIf (!pkgs.stdenv.isDarwin)`.
3. Does Homebrew already install it? Run `just available --duplicates` and
   decide which side owns it.
4. Evaluate the darwin host as well as a Linux host.
