# CLAUDE.md

Guidance for Claude Code working in this repository, on the
`flake-parts-consolidation` branch.

## Safety

The README's warning is real: this config enables impermanence and wipes `/root`
on boot. Never suggest installing it wholesale on a machine, and be careful with
anything touching `linux-flake/modules/nire/boot/impermanence/` or the
`fileSystems`/`boot` options in the host hardware modules.

`WARN-impermanence.nix` is reached by durandal through the `boot` category. It
deletes the `/root` btrfs subvolume in initrd on every boot. Read it before
changing anything near it.

Secrets are sops-nix (`linux-flake/modules/nire/system/secrets/`).
`secrets.yaml` is encrypted and committed; that is deliberate, not a mistake to
be "fixed". Its `.sops.yaml` still enrolls `nire-tenacity` even though that host
has no config here any more — the key is valid, leave it.

## State

The flake evaluates and `nix flake check --all-systems` passes. It did not until
recently: the branch was a stalled migration off `vic/den`, with 151 module files
already written in flake-parts idiom while `flake.nix` still used a raw
`nixpkgs.lib.evalModules`. `2026-08-08-PORT-PLAN-(COMPLETED).md` records that
work, where the plan turned out wrong, and what is still open.

**Nothing here has ever been built or switched.** The dev machine is
aarch64-darwin and the host is x86_64-linux, so building it needs a remote builder
or binfmt, neither of which is set up. Every "verified" claim in this repo means
*evaluates and produces the expected derivation*, never *runs*. The single
exception is `checks.<system>.module-tree`, which is static and does build here.

One host: `nire-durandal`. `nire-tenacity` exists in git history and in
`.sops.yaml`, but the den restructure dropped it rather than migrating it. Its
one surviving module, `jovian.nix`, is marked `ORPHAN-OK`.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere:

```sh
just check           # nix flake check --all-systems --no-build
just modules         # static module-tree check; the only one that means anything on darwin
just fingerprint     # drvPath of the host toplevel
just dotfiles        # every generated dotfile's attribute name
just dotfile ./.zshrc
just build / switch  # Linux only; cannot run from this machine
```

For iterating, evaluate directly:

```sh
cd linux-flake
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
nix flake check --all-systems --no-build
```

`elly` is literal in that second command on purpose: it reads an *evaluated*
config, where the attribute name is already resolved.

## Architecture

`flake.nix` is a manifest. `(inputs.import-tree ./modules)` recursively imports
every `.nix` file under `linux-flake/modules/`, and
`flake-parts.flakeModules.modules` declares the `flake.modules.<class>.<name>`
option they all write into.

**Every `.nix` file under `modules/` is a flake-parts module** — its top level is
`{ flake.modules.<class>.<name> = …; }` or similar, never a bare NixOS or Home
Manager module.

### Membership is implicit, and comes from the directory

Each category directory holds a copy of `dirsAsCategory.nix`, which derives the
category name from its own directory, collects the modules beneath it, and
declares one aggregate per class. **A module belongs to the category of the
directory it is filed in.** Adding a module is a one-file change: create the file
in the right place and it is in.

`linux-flake/dirsAsCategory.md` covers the mechanism, what is load-bearing in it,
and the trailhead to per-module opt-in if that is ever wanted. Read it before
changing any `dirsAsCategory.nix`.

Two consequences worth holding onto:

- **A category collects from its *sub*directories only.** A `.nix` file sitting
  directly in a category directory is collected by nothing.
- **Entry points are defined by being outside every category tree.**
  `modules/checks.nix`, `nireHost/hosts.nix`, `nireHost/durandal-configuration.nix`
  and `nireUser/elly-home-manager.nix` all sit where `dirsAsCategory` cannot reach
  them, deliberately. `just modules` relies on exactly this rule.

Areas: `nire/` (shared system), `nireHost/` (per-host), `nirePackages/`
(packages), `nireUser/` (elly). By declared class: 101 homeManager-only, 43
nixos-only, 9 both, and one (`elly-user.nix`) that adds `darwin` for fonts — that
last reaches nothing, since there are no `darwinConfigurations`.

### Home Manager is NixOS-integrated

`home-manager.users.elly` is set from the NixOS side with `useGlobalPkgs` and
`useUserPackages`, in `nire/system/home-manager/enable-home-manager.nix`. There
is no `homeConfigurations` output and no separate home switch; `just switch`
applies both. `linux-flake/home-manager-standalone.md` is the way back.

- HM **rejects** `nixpkgs.*` options under `useGlobalPkgs` — errors, not ignores.
  `allowUnfree` comes from the system side of `basic-nix-settings.nix`.
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not `~/.nix-profile`.
- Activation runs as a systemd unit, so its `PATH` is only
  coreutils/findutils/gnugrep/gnused/systemd.

## Traps, all of which have actually happened here

### `flake.modules` cannot live inside `perSystem`

**`perSystem` itself is fine and is used** — `checks.nix` is built on it, and it
is core flake-parts, not a den concept.

What does not work is putting `flake.modules` inside it. `perSystem` is evaluated
once per system and its outputs are transposed to `flake.<output>.<system>.*`.
`flake.modules.<class>.<name>` has no `<system>` axis: it is one
system-independent definition declared at the top level as
`lazyAttrsOf (lazyAttrsOf deferredModule)` (`flake-parts/extras/modules.nix:33`).
There is no `freeformType` on `perSystem` to let it through — the only one in
flake-parts is on the top-level `flake` option. This is what 151 files got wrong.

### Names share one namespace per class, and collisions merge

Two modules with the same name do not conflict; they **merge**. `boot` was both
the `nire/boot/` category and `nireHost/durandal/hardware/boot.nix`, so importing
the category also applied durandal's bootloader — and importing the bootloader
applied an impermanence rollback. `just modules` checks for this.

### There are two different `config`s, and they shadow

Every file has an outer flake-parts scope and an inner NixOS/HM module. Both call
their argument `config`, and they are not the same thing:

```nix
{ config, ... }:                       # flake-parts: config.flake.modules.*
{
    flake.modules.nixos.foo =
    { config, ... }:                   # NixOS: config.services.*, config.boot.*
    {
        # the outer `config` is unreachable from in here
    };
}
```

A module written as a bare attrset has **no inner scope**, so `config` in it
still means the flake-parts one, and adding an argument list silently repoints
every existing `config`. Bind what you need in a `let` above the declaration —
`enable-home-manager.nix` does exactly this and says why.

### Module classes are not validated

flake-parts stamps the outer attribute name on as `_class` verbatim and checks
nothing, so a wrong class declares fine and fails much later at the import site.
It sets `_file` to `<flake>#modules.<class>.<name>`, so the error names its own
declaration site. Only `nixos`, `homeManager`, `flake` and `generic` are
meaningful; `darwin` works because nix-darwin sets that `_class` itself.

Related: a module can declare a *valid* class and still be wrong. `jq` and
`bitwarden` declared `flake.modules.nixos` bodies full of `home.packages`.

### Raw NixOS modules in the import-tree path

Dropping fresh `nixos-generate-config` output into `modules/` makes flake-parts
resolve its `modulesPath` through its own `_module.args`, and evaluation dies
with `infinite recursion encountered` — naming `modulesPath`, which is not the
cause. Wrap it in the same commit:

```nix
{ ... }:
{ flake.modules.nixos.someHardware = { config, lib, modulesPath, ... }:
{
  # ... the original module body, unchanged
}
;}
```

### `home.file.<n>.text` concatenates; it does not override

The type is `types.lines`, so two modules declaring the same file both
contribute. `.blerc` was declared by `bash.nix` and `blesh.nix` with identical
content, which would have run every `ble-import` twice. Give each generated file
one owning module. `home.sessionPath` is `listOf str` and behaves the same way —
`shell-env.nix` and `elly-session.nix` doubled every PATH entry between them.

### Reading a generated dotfile is full of false negatives

Most shell bugs are invisible in the `.nix` and obvious in the output, but:

- **The attribute name is inconsistent.** `".zshrc"` and `"./.zshrc"` and full
  `/home/elly/...` paths all occur. A wrong name returns **empty rather than
  erroring**, which reads exactly like a real negative. `just dotfiles` first.
- **Some entries have no `.text` at all** and are built from `.source`. `.bashrc`
  is one. Read the owning option instead — `programs.bash.initExtra`.

Both of these were hit during the port, minutes apart, by someone who had already
written them down.

### Order in generated shell rc files is load-bearing

Home Manager emits `initContent` `mkBefore`, then `mkOrder 550`, then
`programs.zsh.plugins`, then unordered `initContent`. Anything that must run
after a plugin cannot sit at 550. Later definitions win, which is how a
hand-written `starship init bash` and a 1,659-line p10k config both turned out to
be dead weight.

### `${...}` inside a Nix `''` string is interpolation

Writing `${terminfo[khome]}` in what you intend as a comment is an evaluation
error. Escape as `''${...}` or reword.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked files, so
a new module silently does not exist.

**Read upstream source in the store rather than guessing at options.**
`nix build nixpkgs#<pkg>` works on darwin for most of these. This settled, during
the port: that `perSystem` has no `freeformType`, that `home.sessionPath` is
`listOf str`, and that Home Manager has no blesh module at all — which is why
`programs.bash.blesh.enable = true` had been doing nothing.

**Verify refactors by fingerprint, but not only by fingerprint.** `just
fingerprint` before and after. A differing hash does not prove breakage —
reordering imports permutes `environment.systemPackages` — so compare the values,
not just the hash.

**Bugs here serialize.** Everything that broke this branch was an evaluation
error hiding behind another evaluation error. Evaluating a cheap attribute proves
nothing; `networking.hostName` resolved happily while four separate things were
broken. Force a toplevel.

**Calibrate severity.** Homelab, not production; the repo has gone six months
between commits. "This is broken and here is the fix" beats incident-report
framing.

## Conventions

**Formatting is deliberate.** The aligned-`=` columns throughout `modules/` are
intentional. Do not run a formatter casually, and match surrounding alignment.
Module bodies are currently indented one level deeper than they need to be, left
over from unwrapping `perSystem` without reflowing — reindenting would risk the
`''` strings in the shell modules.

**Namespacing.** `nire` for anything that does not need a more specific tag;
`nireHost`, `nireUser`, `nirePackages` otherwise.

**Leave a grep trail when you make a name unfindable.** Put the literal old form
in a comment on the declaration — see the `GREP NOTE` in `boot-durandal.nix` and
in `enable-home-manager.nix`.

**`elly` is hardcoded**, in `users.users.elly`, `home.username`, and
`home-manager.users.elly`. The sibling branch has a `nire.primaryUser` option;
introducing it here is a deliberate separate change, not a tidy-up.

**Check for an existing `programs.*` integration before hand-writing one.**

## Docs

- `2026-08-08-PORT-PLAN-(COMPLETED).md` — the migration off den: what was
  done, where the plan was wrong, and what is still open.
- `linux-flake/dirsAsCategory.md` — the category mechanism and its trailhead.
- `linux-flake/2026-08-08 lessons.md` — how the port went wrong in the doing:
  tools that reported success while being wrong, traps that were documented and
  hit anyway, and which questions were settled by reading source.
- `linux-flake/home-manager-cutover.md` — the first-switch runbook. Read before
  `just switch`: the collision risk is real and the starting state on the
  machine is not known from here.
- `linux-flake/home-manager-standalone.md` — reversing the HM decision.
- `git show flake-parts:SESSION-HANDOFF.md` — the sibling branch's notes on dead
  ends and decisions that should not be silently relitigated.
- `git show flake-parts:linux-flake/flake-parts-reference.md` — flake-parts
  machinery, with upstream source backing each claim.
