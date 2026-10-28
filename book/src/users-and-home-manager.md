# Wiring a user and Home Manager

This chapter shows how the one user account and its
[Home Manager](glossary.md#home-manager) environment are wired into a host,
why Home Manager runs *inside* the system configuration instead of on its own,
and what can go wrong when the system half of a switch succeeds and the Home
Manager half does not.

## The shape

The wiring has two halves and a bridge between them.

1. **The account (system side).** `flake/modules/users-config/elly/user-settings/elly-user.nix`
   declares the Linux user (`nixos` class) and, for darwin hosts, the user's
   fonts (`darwin` class). A class is the kind of configuration a module
   targets. Hosts get the account by listing the `elly`
   [category](glossary.md#category), a folder whose modules a host takes by
   one name.
2. **The environment (home side).** `flake/modules/users-config/elly-home-manager.nix`
   is the [*aggregate*](glossary.md#aggregate): one module whose
   `includes.homeManager` lists the shared categories that contain Home
   Manager modules (`elly`, `impermanence`, `nix`, `shell-config`, `system`
   and the package categories). Host-specific categories such as `tenacity`
   are deliberately left out. The aggregate is the same value for every host.
3. **The bridge.** `flake/modules/general-config/system/home-manager/enable-home-manager.nix`
   (NixOS) and `enable-home-manager-darwin.nix` (darwin) import Home
   Manager's own integration module and set `home-manager.users.<name>` to
   the aggregate. Both bridge modules live in the `system` category, so any
   host that includes `system` gets Home Manager with no further wiring.

The account name is hardcoded (`users.users.elly`, `home-manager.users.elly`,
`home.username`) on purpose. It is not a parameter, and the repo has no
worked example of a second user.

Source: `flake/modules/users-config/`, `flake/modules/general-config/system/home-manager/`,
[`wiki/config-structure/categories/system.md`](../../wiki/config-structure/categories/system.md).

## Adding to the user's environment

Most changes are not wiring changes. To add a program or dotfile for the
user:

1. Put a module file with a `homeManager` key in the right category under
   `flake/modules/` (see [adding a module](adding-a-module.md) and
   [adding a package](adding-a-package.md)).
2. Check that the aggregate already includes the category. If it does not,
   the module is silently never loaded for the user. Add the category name
   to `includes.homeManager` in `elly-home-manager.nix`, but only if the
   category really contains `homeManager` modules. Every category exists for
   every class, and the header of `elly-home-manager.nix` explains why empty
   ones are left out.

A host-specific Home Manager addition does not fork the aggregate. It is
appended to that host's `home-manager.users.elly.imports`. Tenacity does
this for its Plasma configuration
(`host-config/tenacity/configuration/plasma-tenacity.nix` says it is
imported only that way).

Because every host shares the aggregate, **everything in it has to survive
darwin**. [Darwin edge cases](darwin.md) covers how.

## Why Home Manager is integrated into the system

The alternative is *standalone* Home Manager: a `homeConfigurations` output
and a second switch command (`nh home switch`). This repo started that way
and moved. `flake/doc/trailhead-home-manager-standalone.md` records what the
move bought and cost, and it is also the way back.

The move bought:

- One switch instead of two.
- One nixpkgs instantiation instead of two.
- A home configuration that cannot drift out of sync with the system it runs
  on, because the two are evaluated together.

The move cost:

- [`useGlobalPkgs = true`](glossary.md#useglobalpkgs-and-useuserpackages),
  which makes Home Manager use the system's nixpkgs, also makes it *reject*
  any `nixpkgs.*` option inside a home module (an error, not ignored).
  `allowUnfree` therefore has to come from the system side, in
  `flake/modules/general-config/nix/nix-settings/basic-nix-settings.nix`.
- `home.profileDirectory` becomes `/etc/profiles/per-user/<name>` instead of
  `~/.nix-profile`. `useUserPackages = true` causes that change.
- Activation runs as a systemd unit (`home-manager-<name>.service`), not from
  a login shell, so its `PATH` is only coreutils, findutils, gnugrep, gnused
  and systemd. Anything that assumes an interactive environment will not find
  one.
- There is no way to switch only the home configuration.

The aggregate is a plain [deferred module](glossary.md#deferred-module): a
module stored unevaluated, which does not know who evaluates it. Going back
to standalone therefore changes only the files the trailhead document
lists, and none of the modules inside.

Source: `flake/doc/trailhead-home-manager-standalone.md`,
`flake/modules/general-config/system/home-manager/enable-home-manager.nix`,
[`wiki/config-structure/flake-parts-port-notes.md`](../../wiki/config-structure/flake-parts-port-notes.md).

## When the system switches but the home half does not

**Split-brain** here means the system generation is activated but the
user's Home Manager generation is not. The repo records only that direction. The repo has no
single page on split-brain. This section gathers what the code and notes
say, and marks what they do not.

### Why the halves can disagree

Home Manager's activation is a separate step from the system's. Activation
looks at the files Home Manager already owns and links its files into the
home directory. If a file Home Manager does not recognize sits where Home
Manager wants to write, activation stops instead of overwriting the file.

- **NixOS hosts set `backupFileExtension = "hm-bak"`.** Without that
  setting, the first unowned file aborts activation. The comment in
  `enable-home-manager.nix` describes the outcome the setting prevents as
  "failing the switch half-applied, with the system activated and the home
  not". With the setting, the file is renamed to `<file>.hm-bak` and the
  switch continues. If `.hm-bak` files show up, treat them as a real
  finding about untracked state, not as noise to sweep away.
- **The darwin integration does not set it.** `enable-home-manager-darwin.nix`
  sets `useGlobalPkgs` and `useUserPackages` only, so on darwin an unowned
  file in the way is an abort, not a rename (inferred from Home Manager's
  default; no file in the repo says it for darwin). `just hm-collisions`,
  described below, evaluates only NixOS hosts, so a Mac's collisions need
  another check before the first switch.
- **The first switch onto the integrated setup is the riskiest.** A host
  arriving from standalone Home Manager has a user profile that the
  integrated setup does not share.

### Finding collisions before you switch

`just hm-collisions` lists the files Home Manager will take over and whether
any would collide. The recipe evaluates the configuration and inspects the
home directory, builds nothing, and only means something when run on the
host itself. `just home-drift` is its read-only companion: it reports what
`/home` carries that nothing declares.

Source: `flake/scripts/hm-collisions.sh`, `.justfile`,
[`wiki/upkeep-and-admin/maintenance.md`](../../wiki/upkeep-and-admin/maintenance.md).

### The part a rollback does not undo

The one-way part of the move to integrated Home Manager is on the machine,
not in the repo. Switching to integrated reduces Home Manager's own install
step to removing the standalone profile entry. That profile lives in the
user's home directory, not in the system generation, so **rolling the
system back to an older generation does not restore it.** This has happened
on a real host: the rollback left the account with no user profile, and
recovery meant re-activating an older Home Manager generation by hand.

The recovery worked only because the generation links under
`~/.local/state/nix/profiles/` still existed. Garbage collection with
`nix-collect-garbage -d` prunes old profile generations, so tidying up
before a cutover can remove the only way back.

Before such a cutover, pin the current Home Manager generation as a
[GC root](glossary.md#gc-root) (a reference the garbage collector treats as
live) and keep it until the change has stuck. The exact command and the
recovery step are in the trailhead document.

Source: `flake/doc/trailhead-home-manager-standalone.md` ("Order, and the one-way part").

### The fallback if the home half is broken

On NixOS hosts, `elly-user.nix` puts a few packages directly on the user
account (a browser, git, an editor, and similar), with the comment "Emergency
packages if home-manager dies". The comment states the intent. No file in the
repo says how a Home Manager failure plays out, and the darwin class of that
file carries only fonts.

### What the repo does not say

Unverified: how the switch command reports a failing
`home-manager-<name>.service` on a NixOS host (general NixOS behavior, not
configured by this repo), and whether darwin's launchd activation reports a
failure the same way. No file in the repo records either. Test on the target
host, and say which level you reached: evaluated, built, or switched.

## Checklist: wiring the user into a new host

1. Include `elly` and `system` in the host's `includes.nixos` (or
   `includes.darwin`). The `system` category carries the Home Manager
   bridge.
2. Confirm that `elly-home-manager` is the aggregate being enabled; do not
   make a host-specific copy. Exclude what does not suit a platform at the
   source (see [Darwin edge cases](darwin.md)).
3. On a NixOS host that already has a home directory, run
   `just hm-collisions` before the first switch. The script cannot evaluate a
   darwin host.
4. If the host was on standalone Home Manager, pin the current generation as
   a GC root first.
5. Run `git add` on your changes, then force a real evaluation of
   `home-manager.users.elly.home.activationPackage.drvPath` for the host
   (see the command in `AGENTS.md`), not just a cheap attribute. `drvPath`
   is the store path of the derivation; evaluating it forces the whole home
   configuration.
6. After switching, check that `home-manager-<name>.service` succeeded, not
   only that the system switch returned.

Source: `AGENTS.md` ("Commands"), the sources above.
