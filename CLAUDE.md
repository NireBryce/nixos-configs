# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Safety

The README's warning is real: this config enables impermanence and wipes `/root`
on boot. Never suggest installing it wholesale on a machine, and be careful with
anything touching `modules/nire/impermanence-WARN-README/` or the
`fileSystems`/`boot` options in the host hardware modules.

Secrets are sops-nix (`modules/nire/secrets/`). `secrets.yaml` is encrypted and
committed; it is not a mistake to be "fixed".

## Repo shape

Three top-level areas, holding three unrelated flakes. Only `linux-flake` is
flake-parts.

- **`linux-flake/`** — the live config, and where essentially all work happens.
  flake-parts + the dendritic pattern. Two hosts: `nire-durandal` (workstation)
  and `nire-tenacity` (handheld, Jovian/SteamOS).
- **`macos/`** — a separate, older, plain flake for `nire-lysithea`. Not
  flake-parts, and its inputs deliberately diverge (it pins `nixpkgs-unstable`,
  linux-flake pins `nixos-unstable`). Changes here do not propagate.
  **It currently does not evaluate**: `nire-lysithea-home.nix` imports seven
  files from `linux-flake/configs/home-manager/user-elly/`, a layout deleted in
  `8244eb9`. Those modules now live under `linux-flake/modules/users/elly/` *as
  flake-parts modules*, so they cannot be imported by path any more. Fixing it
  means either consuming linux-flake's `flake.modules.homeManager` as an input
  or folding macos in — a design decision, not a repair. Do not assume this
  flake works.
- **`misc/`** — a directory, not a flake, though it contains one
  (`misc/dev-shells/rust/`). Nothing here is wired into either host config; its
  only referent was a broken `overlays` line removed in `d08bc50`. Standalone
  modules, util scripts. Treat as a scratch area.

Everything below is about `linux-flake/`.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere in the repo:

```sh
just check      # nix flake check -- host toplevels on Linux, orphan check everywhere
just build      # nh os build for this host, no activation
just switch     # nh os switch (applies Home Manager too, see below)
just update     # flake update + re-check
just fmt        # see "formatting" before running this

just diff HEAD~1              # what changed in a host's config vs a git ref
just dotfile .zshrc           # a dotfile as home-manager actually generates it
just orphans                  # modules nothing imports
just add-pkg cli ripgrep      # new package module, correctly opted in
just new-host-hardware NAME   # wrap nixos-generate-config output safely
```

`just orphans` is also a flake check (`checks.<system>.orphaned-modules`). It
catches the one failure mode evaluation cannot: a module that is never opted
into an aggregate is valid, evaluates fine, and simply does nothing. Being
static analysis it is platform independent, so it is the only real check that
runs on darwin.

For iterating, evaluate directly rather than building — it is far faster and
works on any platform:

```sh
cd linux-flake
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
# `elly` is literal here: this reads an *evaluated* config, where the attribute
# name is already resolved. Only module source should use nire.primaryUser.
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
nix flake check --all-systems --no-build     # evaluates every output, builds nothing
```

## Architecture: the dendritic pattern

`flake.nix` is a manifest and nothing else. `(inputs.import-tree ./modules)`
recursively imports **every** `.nix` file under `linux-flake/modules/`, so paths
carry no meaning beyond naming — files can be moved freely without editing any
import. That is the point, per the README.

**Every `.nix` file under `modules/` is a flake-parts module**, i.e. its top
level is `{ flake.modules.<class>.<name> = …; }` or similar — never a bare NixOS
or Home Manager module.

### The trap that has broken this flake twice

Dropping a raw NixOS module into `modules/` (for example fresh
`nixos-generate-config` output) makes flake-parts try to resolve that module's
`modulesPath` argument through its own `_module.args`, and evaluation dies with
`error: infinite recursion encountered`.

Worth knowing it has happened twice: the dendritic migration re-wrapped these in
bulk (`67a1284`), and later `9fa44b2` — a Claude Code session — added
`hosts/tenacity/hardware-configuration.nix` as 95 lines of unwrapped
`nixos-generate-config` output, fixed in `922289e`. So this is a mistake an
agent plausibly makes here, not just a theoretical one.

It is easy to miss because the error names `modulesPath` rather than the file
you added. If you add or regenerate a hardware config, wrap it in the same
commit:

```nix
{ ... }:
{ flake.modules.nixos.someHardware = { config, lib, modulesPath, ... }:
{
  # ... the original module body, unchanged
}
;}
```

### Module classes are not validated

flake-parts stamps the outer attribute name onto the module as `_class`
verbatim and checks nothing. A made-up class (`flake.modules.jovian.foo`)
declares successfully and then fails much later, at import, with
`cannot be imported into a module evaluation that expects class "nixos"`.
Only `nixos`, `homeManager`, `flake` and `generic` are meaningful here.

### Aggregates merge — membership lives with the module

`flake.modules.<class>.<name>` is a `deferredModule`, so many files can define
the same aggregate and the module system merges them. This is the core idiom:
a module opts *itself* into a role, next to its own definition, rather than a
host listing everything it wants.

```nix
{ config, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.bluetooth ];

    flake.modules.nixos.bluetooth = { … };
}
```

Adding a module is therefore a **one-file change**. Do not reintroduce central
import lists. The aggregates that exist:

| class | aggregate | contents |
|---|---|---|
| `nixos` | `base` | everything both hosts get |
| `nixos` | `desktop` | `base` + durandal-only (kde, vscode, virtualization, yubikey, …) |
| `nixos` | `handheld` | `base` + tenacity-only (`boot-handheld`, `wm-jovian`) |
| `homeManager` | `ellyHomeManager` | elly's whole home config |
| `homeManager` | `pkgs-cli` / `pkgs-gui` / `pkgs-linux-utils` | one module per package, under `modules/pkgs/` |

`modules/roles.nix` declares only the hierarchy between roles. Hosts
(`modules/hosts/*/`) hold just their role, hardware module, hostname and
stateVersion. `modules/pkgs-{cli,gui,linux-utils}.nix` only attach a group to
`ellyHomeManager`; the groups are kept separate so a role can take some and not
others later.

Inside a flake module prefer **`config.flake.modules.…` over `self.modules.…`** —
same data without the round trip through flake outputs, and it avoids a class of
recursion errors.

### There are two different `config`s, and they shadow

Every file here has an outer flake-parts scope and an inner NixOS/HM module.
Both call their argument `config`, and they are **not the same thing**:

```nix
{ config, ... }:                       # flake-parts config: config.flake.modules.*
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.foo ];

    flake.modules.nixos.foo =
    { config, ... }:                   # NixOS config: config.services.*, config.nire.*
    {
        # the outer `config` is unreachable from in here
    };
}
```

A module written as a bare attrset (no `{ ... }:` line) has **no inner scope**,
so `config` inside it still means the flake-parts one. Adding an argument list
to reach the NixOS `config` silently changes what every existing `config` in
that module refers to, and `config.flake.modules.…` starts failing.

The fix is to bind what you need from the outer scope in a `let` *before* the
shadowing — see `modules/nire/home-manager/enable-home-manager.nix`, which has
to do exactly this to read `config.nire.primaryUser` while still referencing
`config.flake.modules.homeManager.ellyHomeManager`.

### Home Manager is NixOS-integrated

`home-manager.users.${config.nire.primaryUser}` is set from the NixOS side with
`useGlobalPkgs` and `useUserPackages`. There is no `nh home switch` step and no
`homeConfigurations` output; `just switch` applies both. Consequences worth
knowing:

- HM rejects `nixpkgs.*` options under `useGlobalPkgs`. `allowUnfree` comes from
  the system (`modules/nire/nix/nix-settings/`).
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not `~/.nix-profile`.
- Activation runs as the `home-manager-elly.service` systemd unit, not from a
  login shell, so its `PATH` is only coreutils/findutils/gnugrep/gnused/systemd.
- See `linux-flake/home-manager-cutover.md` for the migration runbook.

### Shells

A large share of this config is shell setup, under `modules/users/elly/shell-*`.
Current state, after the zi/prompt cleanup:

| | bash | zsh |
|---|---|---|
| prompt | starship | starship |
| line editor | ble.sh | zle |
| completion menu | fzf, via ble.sh `fzf-menu` | fzf, via `zsh-fzf-tab` |
| auto menu | `bleopt complete_auto_menu=1` | `zsh-autocomplete` |
| suggestions | `complete_auto_complete` | `zsh-autosuggestions` |
| highlighting | ble.sh built-in | `F-Sy-H` |

Neither shell uses a plugin manager. zi is gone: its bootstrap and plugin list
turned out never to be sourced, and everything is `programs.zsh.plugins` now.
powerlevel10k is gone too — `programs.starship` is enabled for bash, zsh and
fish in one place, `pkgs/cli/shell-util/appearance-cli/starship.nix`.

**Order in the generated rc files is load-bearing and not obvious.** Home
Manager emits, in this order: `initContent` `mkBefore`, then `mkOrder 550`,
then `programs.zsh.plugins`, then unordered `initContent`. Anything that must
run after a plugin cannot live at 550. Later definitions also win, so an alias
or prompt init written by hand earlier in the file is silently overridden by
the nix-managed one later. Both mistakes were live here: hand-written aliases
that had no effect, and a p10k theme that starship overrode.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked files, so
a new module silently does not exist and you will debug a phantom. This wastes
time every single session if forgotten.

**Development is on darwin; both hosts are `x86_64-linux`.** Evaluation works
cross-platform, building does not. `checks` is filtered by system, so
`nix flake check` on the mac exercises only the formatter — the host checks
have never run there. Claims about anything building must say so honestly.

**Read the generated dotfile, not just the module.** Most shell bugs here are
invisible in the `.nix` source and obvious in the output. Line numbers make
ordering and duplication questions answerable in one command:

```sh
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.file.".zshrc".text'
```

The attribute name is inconsistent and worth checking first with
`--apply builtins.attrNames` on `home.file` — it has been `".zshrc"`,
`"./.zshrc"` and `"/home/elly/.zsh/plugins/…"` for different entries. Some
files have no `.text` at all and are built from `.source`.

**Read the upstream source in the store rather than guessing at options.**
`nix build nixpkgs#<pkg>` works on darwin for most of these, and grepping the
result settles questions that documentation leaves ambiguous. This has been
worth it repeatedly: ble.sh's `bleopt` defaults and its `ble-import` path
resolution, home-manager's `useUserPackages` and `profileDirectory` behaviour,
flake-parts' `_class` stamping, and whether `zsh-autosuggestions` autoloads
`add-zsh-hook` itself. In the `ble-import` case the source showed the `.bash`
extension is required for absolute paths, which would otherwise have silently
broken every import.

**Verify refactors by fingerprint, not by "it still evaluates."** For any change
meant to preserve behaviour, capture the drvPath before and after:

```sh
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
```

Identical drvPath means byte-identical output. If it differs, diff the config
attribute by attribute (`environment.systemPackages` names, `systemd.services`,
`users.users`, `fileSystems`, `environment.etc`) before concluding the change is
safe — reordering module imports permutes list-valued options like
`systemPackages`, which changes the hash without changing the package set. Use a
`git worktree` at the previous commit to evaluate both sides.

**Also spot-check the values, not just the hash.** An identical drvPath proves
the output did not move; it does not prove the mechanism you introduced is the
one producing it. After making something indirect, evaluate the indirection:

```sh
nix eval .#nixosConfigurations.nire-tenacity.config.jovian.steam.user   # => "elly"
```

**Report honestly.** Everything in this repo has so far been verified by
evaluation only — nothing has been built or switched from the dev machine. That
would need a remote builder or binfmt emulation, neither of which is set up. Say
so rather than implying a change is known to work.

## Conventions

**Formatting is deliberate.** The aligned-`=` columns throughout `modules/` are
intentional. treefmt/nixfmt is configured in `modules/formatter.nix` but
deliberately **not applied**, with `flakeCheck = false`, because running it would
flatten that style across every file. Do not run `nix fmt` casually, and match
surrounding alignment when editing.

**Namespacing**, per `notes-and-fixes.md`: `nire` is the namespace for any module
that does not need a more specific tag; start broad and narrow as things clarify.
Custom options live under it too — `nire.primaryUser` is the account name; never
hardcode `"elly"` in a nixos module, read that option instead.

**Leave a grep trail when you make a name dynamic.** Turning
`users.users.elly` into `users.users.${config.nire.primaryUser}` makes the old
string unfindable, which is the real cost of the indirection. The convention
here is to put the literal old form in a comment on the declaration — see the
`GREP NOTE` in `modules/nire/users/primary-user.nix`, which is now the only
place `users.users.elly` appears. Do the same for any future rename.

**VSCode settings live only at the repo root.** `linux-flake/.vscode/` and
`macos/.vscode/` were byte-identical copies and were removed; do not recreate
them.

**`home.file.<n>.text` concatenates; it does not override.** The type is
`types.lines`, so two modules declaring the same file both contribute and the
result is the content twice over. `.blerc` was generated duplicated for exactly
this reason, from `shell-bash/bash.nix` and `shell-bash/blesh.nix`. In a
dendritic layout this is easy to do by accident, so give each generated file a
single owning module.

**Check for an existing `programs.*` integration before hand-writing one.**
`eval "$(starship init bash)"` in `initExtra` ran alongside
`programs.starship.enableBashIntegration`, so starship initialised twice. The
HM integration is also better: it uses the store path instead of relying on
`PATH`.

**`${...}` inside a Nix `''` string is Nix interpolation.** Writing
`${terminfo[khome]}` in a comment inside `initContent` is an evaluation error,
not a comment. Escape as `''${...}` or reword. Related to the `#` FOOTGUN note
already in `shell-zsh/zsh.nix`.

## Repo docs worth reading

- `linux-flake/flake-parts-reference.md` — the flake-parts machinery this config
  depends on, with the upstream source backing each claim. Read this before
  changing anything structural.
- `linux-flake/2026-08-06 changelog.md` — the flake-parts cleanup: what was
  broken, what changed, how each refactor was verified.
- `linux-flake/home-manager-cutover.md` — first-switch runbook for the HM change.
- `linux-flake/notes-and-fixes.md` — the user's own accumulated fixes and notes.
