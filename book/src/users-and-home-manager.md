# Wiring a user and Home Manager

One user account and its [Home Manager](glossary.md#home-manager)
environment are wired into every host. Home Manager runs inside the system
configuration, so a switch can succeed for the system and fail for Home
Manager ([split-brain](glossary.md#split-brain); covered below).

## The account, the environment and the bridge

Three pieces wire the user in:

1. The account, on the system side.
   `flake/modules/users-config/elly/user-settings/elly-user.nix` declares the
   Linux user (`nixos` class) and, for darwin hosts, the user's fonts
   (`darwin` class). Hosts get the account by listing the `elly`
   [category](glossary.md#category).
2. The environment, on the home side.
   `flake/modules/users-config/elly-home-manager.nix` is the
   [*aggregate*](glossary.md#aggregate): one module whose
   `includes.homeManager` lists the shared categories that contain Home
   Manager modules (`elly`, `impermanence`, `nix`, `shell-config`, `system`
   and the package categories). Host-specific categories such as `tenacity`
   are left out, so the aggregate is the same value for every host.
3. The bridge between them.
   `flake/modules/general-config/system/home-manager/enable-home-manager.nix`
   (NixOS) and `enable-home-manager-darwin.nix` (darwin) import Home
   Manager's integration module and set `home-manager.users.<name>` to the
   aggregate. Both live in the `system` category, so any host that includes
   `system` gets Home Manager with no further wiring.

The account name is hardcoded (`users.users.elly`, `home-manager.users.elly`,
`home.username`). The repo has no parameter for it and no example of a second
user.

## Adding to the user's environment

Most changes are not wiring changes. To add a program or dotfile:

1. Put a module file with a `homeManager` key in the right category under
   `flake/modules/` (see [adding a module](adding-a-module.md) and
   [adding a package](adding-a-package.md)).
2. Check that `includes.homeManager` in `elly-home-manager.nix` lists the
   category. If it does not, the module never loads for the user and nothing
   reports it. Add the name only if the category contains `homeManager`
   modules. The header of `elly-home-manager.nix`
   explains why empty categories are left out.

A host-specific Home Manager addition leaves the aggregate alone: the host
appends it to its own `home-manager.users.elly.imports`. Tenacity does this
for its Plasma configuration (`host-config/tenacity/configuration/plasma-tenacity.nix`).

Every host shares the aggregate, so **everything in it has to survive
darwin**. [Darwin edge cases](darwin.md) covers how.

## Why Home Manager is integrated into the system

The alternative is *standalone* Home Manager: a `homeConfigurations` output
and a second switch command (`nh home switch`). This repo moved from
standalone to integrated. `flake/doc/trailhead-home-manager-standalone.md`
records the trade and is the way back. Going back changes only the files that
document lists, because the aggregate is a plain
[deferred module](glossary.md#deferred-module) (a module stored unevaluated)
that does not know who evaluates it.

Gains: one switch instead of two, one nixpkgs instantiation instead of two,
and a home configuration evaluated together with the system it runs on.

Costs:

- [`useGlobalPkgs = true`](glossary.md#useglobalpkgs-and-useuserpackages)
  makes Home Manager use the system's nixpkgs and reject any `nixpkgs.*`
  option inside a home module. `allowUnfree` must come from the system side,
  in `flake/modules/general-config/nix/nix-settings/basic-nix-settings.nix`,
  which reads the shared `flake.lib.nixpkgs.config`.
- `useUserPackages = true` moves `home.profileDirectory` to
  `/etc/profiles/per-user/<name>` instead of `~/.nix-profile`.
- Activation runs as a systemd unit (`home-manager-<name>.service`) outside
  any login shell. Its `PATH` is only coreutils, findutils, gnugrep, gnused
  and systemd.
- The home configuration cannot be switched alone.

## When the system switches but the home half does not

[**Split-brain**](glossary.md#split-brain) here means the system generation is activated but the user's
Home Manager generation is not.

### Why the halves can disagree

Home Manager's activation is a separate step from the system's. It links its
files into the home directory, and if a file it does not own sits where it
wants to write, activation stops and leaves the file alone.

- NixOS and darwin hosts both set `backupFileExtension = "hm-bak"`. With it,
  the unowned file is renamed to `<file>.hm-bak` and the switch continues.
  Without it, the first such file aborts the switch with the system
  activated and the home not (the comment in `enable-home-manager.nix`
  says so). Treat `.hm-bak` files as a finding about untracked state; do not
  sweep them away.
- The first switch onto the integrated setup is the riskiest. A host coming
  from standalone Home Manager has a user profile the integrated setup does
  not share.

### Finding collisions before you switch

`just hm-collisions` lists the files Home Manager will take over and whether
any would collide. It evaluates the configuration and inspects the home
directory without building, so its output is meaningful only on the host
itself. It evaluates only NixOS hosts, so on a Mac the rename is the only
protection. `just home-drift` is its read-only companion: it reports what
`/home` carries that nothing declares.

### The part a rollback does not undo

Switching to integrated reduces Home Manager's install step to removing the
standalone profile entry. That profile lives in the user's home directory,
outside the system generation, so **rolling the system back does not restore
it**. On one host the rollback left the account with no user profile, and
recovery meant re-activating an older Home Manager generation by hand. That
worked only because the generation links under
`~/.local/state/nix/profiles/` still existed, and `nix-collect-garbage -d`
prunes them.

Before such a cutover, pin the current Home Manager generation as a
[GC root](glossary.md#gc-root) (a reference the garbage collector treats as
live) and keep it until the change has stuck. The command and recovery step
are in `flake/doc/trailhead-home-manager-standalone.md`.

### The fallback packages

On NixOS hosts, `elly-user.nix` puts a few packages directly on the user
account (a browser, git, an editor, and similar), commented "Emergency
packages if home-manager dies". The darwin class of that file carries only
fonts.

## Checklist: wiring the user into a new host

1. Include `elly` and `system` in the host's `includes.nixos` (or
   `includes.darwin`).
2. Use `elly-home-manager` as the aggregate; make no host-specific copy.
   Exclude what does not suit a platform at the source (see
   [Darwin edge cases](darwin.md)).
3. On a NixOS host that already has a home directory, run
   `just hm-collisions` before the first switch.
4. If the host was on standalone Home Manager, pin the current generation as
   a GC root first.
5. After `git add`, run from `flake/`:
   `nix eval --raw '.#nixosConfigurations.nire-<name>.config.home-manager.users.elly.home.activationPackage.drvPath'`.
   Evaluating the [`drvPath`](glossary.md#drvpath) forces the whole home
   configuration without building it.
6. After switching, check that `home-manager-<name>.service` succeeded.

Not checked: how the switch command reports a failing
`home-manager-<name>.service` on a NixOS host; whether darwin's launchd
activation reports a failure the same way; how a Home Manager failure plays
out beyond the fallback packages. No file in the repo records any of these.
Test on the target host and say whether you evaluated, built or switched.

## Sources

- `flake/modules/users-config/` (`elly/user-settings/elly-user.nix`, `elly-home-manager.nix`)
- `flake/modules/general-config/system/home-manager/`
- `flake/modules/general-config/nix/nix-settings/basic-nix-settings.nix`
- `flake/doc/trailhead-home-manager-standalone.md`
- `flake/scripts/hm-collisions.sh`, `.justfile`, `AGENTS.md`
- [system.md](../../wiki/config-structure/categories/system.md)
- [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md)
- [maintenance.md](../../wiki/upkeep-and-admin/maintenance.md)
