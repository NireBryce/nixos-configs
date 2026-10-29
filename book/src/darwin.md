# Darwin edge cases

The nix-darwin host differs from the NixOS hosts in the ways listed below.
It shares the `elly-home-manager` module, the bundle of Home Manager modules,
verbatim with the Linux hosts. Each difference is absorbed per module or per
package, and the bundle is never forked.

## How the darwin host is built

- The host is declared in `flake/modules/host-config/hosts.nix` through
  `mkDarwinHost`, which mirrors the NixOS helper but calls nix-darwin's
  `darwinSystem`. Like the NixOS helper, it does not take `pkgs` from
  flake-parts' per-system scope ([perSystem](glossary.md#persystem)). The
  perSystem `pkgs` is built from the same shared `nixpkgs.config` but is a
  different instance from the host's.
- The host's definition is
  `flake/modules/host-config/lysithea-configuration.nix`, which lists
  [categories](glossary.md#category) under `includes.darwin`.
- `darwin` is its own [module class](glossary.md#module-class). A category's
  darwin [aggregate](glossary.md#aggregate) contains only the modules that
  have a `darwin` key, so including a broad category like `system` does not
  drag in Linux-only modules (bluetooth, networking and so on).
- Categories that declare nothing darwin-class (`hardware`, `desktop-env`,
  `peripherals`) are left out of the host's list, since they would resolve to
  nothing.

## One bundle, two platforms

Every fleet machine imports `elly-home-manager`, the Mac included; the
`forge-runner` guest does not (see
[users and Home Manager](users-and-home-manager.md)). Adding a package to
that bundle raises two questions:

- Can nixpkgs build it on darwin? `drop-unsupported-packages.nix` filters
  `home.packages` on darwin and warns about each package it drops. The
  filter does not cover `meta.broken` or option-shaped modules.
- Does Homebrew already install it? `meta.platforms` knows nothing about
  Homebrew, so you decide which side owns the app.

The full rules, the `obsidian.nix` Homebrew guard and the `cmux.nix`
darwin-only guard are in [Adding a package](adding-a-package.md), step 2.

## Homebrew is declarative, and removes things

`flake/modules/general-config/macos/homebrew/homebrew.nix` sets
`homebrew.onActivation.cleanup = "uninstall"`. A formula or cask not listed
in `homebrew.nix` is **removed** on the next switch. If something you
installed by hand with `brew` vanishes, that setting is why; add it to
`homebrew.nix`.

## Smaller differences

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
  forced off at the system level so it does not fight Home Manager's.
- Activation: Home Manager activates through launchd instead of a systemd
  unit. The darwin integration sets `backupFileExtension` as the NixOS one
  does, so an unowned file in the way is renamed to `<file>.hm-bak`. See
  [split-brain](glossary.md#split-brain) in the glossary.
- Fonts: the user's fonts are installed from the `darwin` class of
  `elly-user.nix`.
- Tailscale: the NixOS Tailscale module never reaches darwin; on the Mac,
  Tailscale is the `tailscale-app` cask. A Homebrew auto-update of a system
  extension can leave the old and new extension in a half-finished
  transaction until the machine is rebooted. The symptom looks like "the
  service won't install". The fix recorded in the wiki is a reboot.

## Things that do not exist on darwin

- Impermanence: the `/root` wipe is a NixOS-host mechanism (see
  [impermanence](glossary.md#impermanence)); the darwin host is an ordinary
  persistent system.
- `just boot`: NixOS-only. nix-darwin has no bootloader to stage a generation
  into, and `nh darwin` offers only build and switch, so `rebuild.sh` refuses
  it.
- sops-nix paths: on the Mac,
  `flake/modules/general-config/system/secrets/sops-darwin.nix` points
  `SOPS_AGE_KEY_FILE` at the Linux-style XDG path directly, so `sops` finds
  the key. Read the names of secrets only, never values.

## Building and verifying

- A NixOS host cannot be built from any other machine: there is no remote
  builder and no binfmt. `flake/scripts/rebuild.sh` says so, and picks
  `nh darwin` or `nh os` from the flake.
- A darwin host's toplevel and home activation package evaluate from Linux.
  CI does this on a Linux runner with
  `nix flake check --all-systems --no-build`; evaluation needs no matching
  builder. Building the Mac's configuration needs the Mac. Say which level
  you reached (evaluated, built, switched); an evaluation does not show the
  Mac works.
- `nix flake check` alone warns about an unknown output such as
  `darwinConfigurations` and evaluates nothing inside it.
  `flake/modules/checks.nix` forces the Mac's toplevel and home activation
  package, so the evaluation runs, but it does not build them.
- When you change something in the shared bundle, check the Mac's evaluation
  as well as the Linux one. The two use different `pkgs`, and a package that
  is fine on Linux can be the one that fails on the Mac.
- `just baseline` and `just diff-deployed` show whether the host runs what
  the tree says, and only work on the host itself.

## Checklist: adding something to the shared bundle

1. Run `just available <pkg>`. If nixpkgs can't build it on `aarch64-darwin`,
   the filter drops it; see [step 2](adding-a-package.md#can-nixpkgs-build-it-on-darwin-the-repo-handles-this).
2. If it is `meta.broken` there or option-shaped, guard the module; see the
   [filter's limits](adding-a-package.md#can-nixpkgs-build-it-on-darwin-the-repo-handles-this).
3. Run `just available --duplicates` and decide whether Homebrew owns it; see
   [the Homebrew question](adding-a-package.md#does-homebrew-already-install-it-you-decide).
4. Evaluate the darwin host as well as a Linux host.

## Sources

- `flake/modules/host-config/hosts.nix`
- `flake/modules/host-config/lysithea-configuration.nix`
- `flake/modules/general-config/macos/`
- `flake/modules/general-config/system/secrets/sops-darwin.nix`
- `flake/modules/users-config/elly/hm-config/hm-config.nix`
- `flake/modules/users-config/elly/user-settings/elly-user.nix`
- `flake/modules/checks.nix`
- `flake/scripts/rebuild.sh`
- `AGENTS.md`, "Commands"
- [macos.md](../../wiki/config-structure/categories/macos.md)
