# Darwin edge cases

<!-- book-nav: generated from SUMMARY.md by `just agent book-nav write`; do not edit -->
<details class="book-nav">
<summary>Book contents (you are on: Darwin edge cases)</summary>

[Introduction](introduction.md)

**Understanding the repo**

1. [How the non-obvious pieces work](how-it-works.md)
2. [Why it is built this way](rationale.md)

**Extending it**

3. [Categories and membership](categories.md)
4. [Adding a module](adding-a-module.md)
5. [Adding a package](adding-a-package.md)
6. [Wiring a host](wiring-a-host.md)
7. [Wiring a user and Home Manager](users-and-home-manager.md)
8. **Darwin edge cases** (this page)

**Working with agents**

9. [How agents work in this repo](agents-in-the-repo.md)
10. [Checks, guards and hooks](agent-checks-and-guards.md)
11. [Git and agent workflows](git-and-agent-workflows.md)

**Reference**

12. [Glossary](glossary.md)

← [Wiring a user and Home Manager](users-and-home-manager.md) · [How agents work in this repo](agents-in-the-repo.md) →

</details>
<!-- /book-nav -->

The nix-darwin host differs from the NixOS hosts in the ways listed below.
The Home Manager bundle is shared verbatim with the Linux hosts. Each
difference therefore has to be absorbed per module or per package; never
fork the bundle. Unfamiliar terms are in
the [glossary](glossary.md).

## How the darwin host is built

- The host is declared in `flake/modules/host-config/hosts.nix` through
  `mkDarwinHost`, which mirrors the NixOS helper but calls nix-darwin's
  `darwinSystem`. Like the NixOS helper, `mkDarwinHost` does *not* take
  `pkgs` from flake-parts' per-system scope
  ([perSystem](glossary.md#persystem)). The perSystem `pkgs` has no
  `nixpkgs.config` applied and would drop `allowUnfree` without an error.
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
  `peripherals`) are left out of the host's list. Including them would
  resolve to nothing.

Source: `flake/modules/host-config/hosts.nix`,
`flake/modules/host-config/lysithea-configuration.nix`,
[`wiki/config-structure/categories/macos.md`](../../wiki/config-structure/categories/macos.md).

## One bundle, two platforms

Every fleet machine imports `elly-home-manager`, the Mac included; the
`forge-runner` guest does not (see
[users and Home Manager](users-and-home-manager.md)). Adding a package to
that shared bundle raises two separate questions with different answers.

### "Can nixpkgs build it here?" The filter answers

`flake/modules/general-config/system/home-manager/drop-unsupported-packages.nix`
re-declares `home.packages` with an `apply` function that filters by
`lib.meta.availableOn`, **on darwin only**, and warns by name about each
package it drops. On Linux the filter does nothing: an unbuildable package
on the main hosts should stay a loud error.

**Do not** hand-write `lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin)` around
a package because it does not build on macOS; `meta.platforms` already
records that.

The filter has three limits, and each has caused a failure here:

- It cannot catch `meta.broken`. A package marked broken on darwin passes the
  filter and then fails evaluation. `cod` is the live example, which is why
  the zsh and bash modules still guard their `cod` lines by hand.
- It only reaches `home.packages`. A module that sets
  `programs.foo.enable = true` asserts before any package list exists, so it
  needs its own guard (`vicinae.nix`, `kde-connect.nix` and
  `kde-sleepmode.nix` are examples).
- It cannot be replaced by making `imports` conditional on `pkgs`. Under
  [`useGlobalPkgs`](glossary.md#useglobalpkgs-and-useuserpackages) a
  conditional `imports` causes infinite recursion, confirmed by trying it on
  the Linux hosts. Filtering has to happen on values.

### "Does Homebrew already install it?" You decide

`meta.platforms` knows nothing about Homebrew. If `homebrew.nix` installs a
cask for an app that a nixpkgs module also installs, the Mac gets two
copies. `just available --duplicates` lists the overlaps.

Read an existing `isDarwin` in a package module carefully. In
`obsidian.nix` the guard means "on darwin, Homebrew owns this app". It does
not mean "Linux only".

The opposite case: a package whose `meta.platforms` names only darwin must be
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
  forced off at the system level so that it does not fight Home Manager's.
- Activation: Home Manager activates through launchd instead of a systemd
  unit. The darwin integration sets `backupFileExtension` as the NixOS one
  does, so an unowned file in the way is renamed to `<file>.hm-bak`. See the split-brain section of
  [users and Home Manager](users-and-home-manager.md).
- Fonts: the user's fonts are installed from the `darwin` class of
  `elly-user.nix`.
- Tailscale: the NixOS Tailscale module never reaches darwin; on the Mac,
  Tailscale is the `tailscale-app` cask. A Homebrew auto-update of a system
  extension can leave the old and new extension in a half-finished
  transaction until the machine is rebooted. The symptom looks like "the
  service won't install". The fix recorded in the wiki is a reboot; no
  config change is needed.

Source: `flake/modules/general-config/macos/`,
`flake/modules/users-config/elly/hm-config/hm-config.nix`,
`flake/modules/users-config/elly/user-settings/elly-user.nix`,
`wiki/config-structure/categories/macos.md`.

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
  the key. Read the names of secrets only, never values, as everywhere in
  this repo.

## Building and verifying

- A NixOS host cannot be built from any other machine: there is no remote
  builder and no binfmt. `flake/scripts/rebuild.sh` says so, and picks
  `nh darwin` or `nh os` from the flake.
- A darwin host's toplevel and home activation package evaluate from Linux.
  CI does this on a Linux runner with
  `nix flake check --all-systems --no-build`; evaluation needs no matching
  builder. Building the Mac's configuration needs the Mac. Say which level
  you reached (evaluated, built, switched), and do not claim the Mac works on
  the strength of an evaluation.
- `nix flake check` alone warns about an unknown output such as
  `darwinConfigurations` and evaluates nothing inside it.
  `flake/modules/checks.nix` now forces the Mac's toplevel and home
  activation package, so the evaluation runs. It still only evaluates them
  and does not build them.
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
2. Check whether the package is `meta.broken` there, or behavioral
   (option-shaped, asserts early). If so, guard the module with
   `lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin)`.
3. Check whether Homebrew already installs it. Run
   `just available --duplicates` and decide which side owns it.
4. Evaluate the darwin host as well as a Linux host.
