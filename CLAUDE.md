# CLAUDE.md

Guidance for Claude Code working in this repository, on the
`flake-parts-consolidation` branch.

## Safety

The README's warning is real: this config enables impermanence and wipes `/root`
on boot. Never suggest installing it wholesale on a machine, and be careful with
anything touching `linux-flake/modules/nire/boot/impermanence/` or the
`fileSystems`/`boot` options in the host hardware modules.

`WARN-impermanence.nix` is reached by **both hosts** through the `boot`
category. It deletes the `/root` btrfs subvolume in initrd on every boot, and it
depends on a `root-blank` subvolume existing on the machine. Read it, and
`linux-flake/impermanence-stage1.md`, before changing anything near it.

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

**Nothing on this branch has been built or switched.** `origin/main` merged
flake-parts (PRs #28, #29) and is what the machines run, so the architecture is
proven — it is this branch's 172 commits on top of it that are not. The dev
machine is
aarch64-darwin and the host is x86_64-linux, so building it needs a remote builder
or binfmt, neither of which is set up. Every "verified" claim in this repo means
*evaluates and produces the expected derivation*, never *runs*. The single
exception is `checks.<system>.module-tree`, which is static and does build here.

Two hosts: `nire-durandal` (workstation) and `nire-tenacity` (handheld,
Jovian/SteamOS). Tenacity was dropped by the den restructure and brought back
from `origin/backup-before-flake-parts-happened`, the last config it actually
ran. Both import the `boot` category, so **both wipe `/root` on boot**.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere:

```sh
just check           # nix flake check --all-systems --no-build
just modules         # static module-tree check; the only one that means anything on darwin
just fingerprint     # drvPath of the host toplevel
just dotfiles        # every generated dotfile's attribute name
just dotfile ./.zshrc
just diff HEAD~1     # what changed in a host's config, attribute by attribute
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

### A module's name is its filename

`moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file)` in all 151
modules, so **renaming a file renames the attribute it declares.**

That is usually harmless, because `dirsAsCategory` also derives its member list
from filenames — the two move together and category membership survives a
rename. What does not survive is anything referring to the module by literal
name: a host config importing it, or another module's `imports`. Those break
loudly, which is the good case.

The bad case is hardcoding a name that then disagrees with the filename. The
category looks up members by filename stem and filters with `? ${n}`, so a
module whose declared name no longer matches its file is **silently dropped** —
valid, evaluated, and absent. Keep declared names derived, or keep them in sync
deliberately and say so in the file.

### Hyphens are legal in Nix identifiers

`kde-base` is **one** attribute name, not `kde` minus `base`. A Nix identifier is
`[a-zA-Z_][a-zA-Z0-9_'-]*`, so `a-b` is a single token and subtraction needs
spaces around the operator. Two consequences here:

- `with config.flake.modules.nixos; [ kde-desktop ]` resolves the whole
  hyphenated name, which is why a host config can list it bare.
- **Any regex over this tree that matches module names with `\w+` is wrong.**
  `modules.py` did, and read `config.flake.modules.nixos.kde-base` as a reference
  to `kde` — which left `kde-base` reported as an orphan the same hour it was
  created. It matches `[\w-]+` now.

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

### `@name@` inside an initrd hook string is a live template placeholder

`boot.initrd.postResumeCommands` and its siblings are not copied into
`stage-1-init.sh` — they are pasted in by a fixed sequence of 19
`substituteInPlace --replace-fail` passes. `@postResumeCommands@` is the
**10th**. Every placeholder substituted *after* it is still live in the text you
just inserted: `@preDeviceCommands@` (11th), `@preFailCommands@` (12th),
`@preLVMCommands@` (13th), then `@resumeDevice@`, `@setHostId@`, `@shell@`,
`@udevRules@`, `@verbose@`.

So naming `@preLVMCommands@` in a **comment** inside `postResumeCommands` pastes
the entire LUKS unlock script into the middle of that comment. Only its first
line stays commented out; the rest executes, in initrd, part-way through the
`/root` rollback. Caught in review rather than on a boot, which is why
`WARN-impermanence.nix` carries a `NOTE:` saying not to do it.

Same family as the `${...}` trap above, and the same underlying rule: **text in
these strings is not inert, and a comment is not a safe place to name things.**
Refer to a hook in prose ("the pre-LVM commands"), never by its token.

### `lsblk` and `findmnt` describe the sandbox, not the machine

The shell runs in a mount namespace, and both tools report **that** namespace —
faithfully, and about the wrong world. Run on tenacity they said `/` was a
tmpfs, showed `/dev/mapper/enc` mounted at `/etc/xdg`, and left every UUID column
empty. Read literally, that is *the disk does not match the host's hardware
module*, which is a stop-and-ask condition. It matched perfectly.

Two sources are not rewritten, and both are unprivileged:

- `/proc/1/mountinfo` — PID 1's mount table, which is the host's
- `/dev/disk/by-uuid/` — udev's symlinks, so LUKS and filesystem UUIDs resolve

Check the disk against a hardware module through those, never through `findmnt`.

`btrfs subvolume list` does need privileges, and is worth asking Elly to run
rather than working around — it answers `root-blank` without mounting anything,
unlike the `mount -o subvol=/` procedure in `HANDOFF-tenacity.md`:

```sh
sudo btrfs subvolume list -a /
```

Read the subvolids in its output as well as the names. `/root` sitting far above
its neighbours — 607 against 257–261 — is the impermanence rollback
*demonstrably running*, which is a stronger fact than `root-blank` existing.

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

**Read `linux-flake/style-guide.md` before writing a new module.** It covers the
bracket rule, the module header and where each argument belongs, the
`# # description` convention and why it stays a comment, and the fact that file
placement is load-bearing. Formatting here is deliberate — the aligned-`=`
columns are intentional and `nix fmt` is deliberately not wired up, because it
would flatten them.

Module bodies currently sit one level deeper than they need to, left over from
unwrapping `perSystem` without reflowing — reindenting would risk the `''`
strings in the shell modules.

**Namespacing.** `nire` for anything that does not need a more specific tag;
`nireHost`, `nireUser`, `nirePackages` otherwise.

**When a rename makes the old name ungreppable, say what it was** in a short
comment on the declaration — see `boot-durandal.nix` and
`enable-home-manager.nix`.

**A bug recorded in a comment stays in the file.** The commit message is the
fuller record, but nobody goes looking through `git log` — the comment is what
the next person editing this code actually reads, and several of the bugs here
are the kind that recur. Do not trim one out because the fix has landed.

If a later change leaves the comment stranded — the code it described is gone,
or the name it explained has changed, so it no longer reads as an annotation of
anything nearby — **move it to the bottom of the file under a `history` heading
rather than deleting it**, and expand it enough to stand alone. A comment that
has lost its surroundings has also lost the context that made it terse, so it
needs to say more, not less. `boot-durandal.nix` has one.

**`elly` is hardcoded**, in `users.users.elly`, `home.username`, and
`home-manager.users.elly`. The sibling branch has a `nire.primaryUser` option;
introducing it here is a deliberate separate change, not a tidy-up.

**Check for an existing `programs.*` integration before hand-writing one.**

## Docs

- `2026-08-08-PORT-PLAN-(COMPLETED).md` — the migration off den: what was
  done, where the plan was wrong, and what is still open.
- `linux-flake/dirsAsCategory.md` — the category mechanism and its trailhead.
- `linux-flake/impermanence-stage1.md` — the root rollback's move from scripted
  stage 1 to a systemd-initrd unit, done 2026-08-10 because the 2026-08-07
  nixpkgs flipped `boot.initrd.systemd.enable` to default true. Evaluates, never
  booted. Read before touching anything in initrd.
- `linux-flake/lessons.md` — how the work went wrong in the doing: tools that
  reported success while being wrong, traps that were documented and hit anyway,
  and which questions were settled by reading source. §§1–18 are the port,
  §§19–23 the first session run on the hardware.
- `linux-flake/home-manager-cutover.md` — the first-switch runbook. Read before
  `just switch`: the collision risk is real and the starting state on the
  machine is not known from here.
- `linux-flake/home-manager-standalone.md` — reversing the HM decision.
- `git show flake-parts:SESSION-HANDOFF.md` — the sibling branch's notes on dead
  ends and decisions that should not be silently relitigated.
- `git show flake-parts:linux-flake/flake-parts-reference.md` — flake-parts
  machinery, with upstream source backing each claim.
