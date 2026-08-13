# CLAUDE.md

> **Written by Claude Code, for Claude Code.** This is an agent's working notes,
> not documentation. It is pitched at something with no memory between sessions,
> so it belabours things a human would only need told once, and it dwells on
> mistakes because repeating them is the failure mode it exists to prevent.
> Elly has corrected the load-bearing claims; the framing is the machine's.
> `README.md` is the human entry point.

Guidance for Claude Code working in this repository, on the
`flake-parts-consolidation` branch.

## Safety

The README's warning is real: this config enables impermanence and wipes `/root`
on boot. Never suggest installing it wholesale on a machine, and be careful with
anything touching `linux-flake/modules/nire/impermanence/` or the
`fileSystems`/`boot` options in the host hardware modules.

`WARN-impermanence.nix` is reached by **both hosts** through the `impermanence`
category -- named `boot` until 2026-08-11; renamed because `boot` had come to
mean only this. It deletes the `/root` btrfs subvolume in initrd on every boot,
and it depends on a `root-blank` subvolume existing on the machine. Read it, and
`linux-flake/impermanence-stage1.md`, before changing anything near it.

Secrets are sops-nix (`linux-flake/modules/nire/system/secrets/`).
`secrets.yaml` is encrypted and committed; that is deliberate, not a mistake to
be "fixed". Its `.sops.yaml` still enrolls `nire-tenacity` even though that host
has no config here any more — the key is valid, leave it.

## State

**This branch has booted on `nire-tenacity`** — 2026-08-10, generation 62, NixOS
26.11, kernel 6.18.43, systemd stage 1. The `/root` rollback ran and was
confirmed by subvolid (607 → 622), not merely by the machine coming up.

`durandal` has not been built or switched. For now that is fine — tenacity is
serving as the testbed, so changes land there first and durandal follows later.
It is not a blocker and does not need raising as one every session. It does
mean a claim verified on tenacity is not thereby verified for durandal: say
which host you mean, and treat anything host-shaped there as unanswered.

Most of this repo's history predates that, written from an aarch64-darwin laptop
against x86_64-linux hosts with no remote builder, where the only thing that
built was `checks.<system>.module-tree`. **Treat an undated "verified" as
*evaluates*.** The first boot found four defects that evaluation and a
successful build both missed (`lessons.md` §25), so a green `nix flake check`
says nothing about behaviour.

Two hosts: `nire-durandal` (workstation) and `nire-tenacity` (handheld,
Jovian/SteamOS). Both import the `impermanence` category, so **both wipe
`/root` on boot**. Tenacity was dropped by the den restructure and brought back
from `origin/backup-before-flake-parts-happened`, the last config it actually
ran.

`2026-08-08-PORT-PLAN-(COMPLETED).md` records the migration off `vic/den`, where
the plan turned out wrong, and what is still open.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere:

```sh
just check           # nix flake check --all-systems --no-build
just modules         # static module-tree check; the only one that means anything on darwin
just available <pkg> # can it build on aarch64-darwin, and does a cask install it too
just available --duplicates   # only the ones homebrew ALSO installs, and what to do
just fingerprint     # drvPath of the host toplevel
just dotfiles        # every generated dotfile's attribute name
just dotfile ./.zshrc
just diff HEAD~1     # what changed in a host's config, attribute by attribute
just build / boot / switch   # Linux only; `boot` activates nothing until you reboot
```

On the hardware, and read-only:

```sh
just baseline        # what the machine is REALLY running -- capture before switching
just hm-collisions   # which files HM will take over, and whether any would collide
just diff-deployed   # package-level diff, running vs new toplevel; needs `just build` first
```

`host` derives from `hostname`, falling back to `nire-durandal` off-host. To
override, the assignment goes **before** the recipe name —
`just host=nire-durandal build`. `just build host=…` is not a variant; just
reads it as a second recipe name and errors.

For iterating, evaluate directly from `linux-flake/`:

```sh
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
```

`elly` is literal there on purpose: it reads an *evaluated* config, where the
attribute name is already resolved.

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

Applies to **scripted** stage 1, which this branch left on 2026-08-10. Kept
because the mechanism is one `boot.initrd.systemd.enable = false` away.

`boot.initrd.postResumeCommands` and its siblings are pasted into
`stage-1-init.sh` by a fixed sequence of 19 `substituteInPlace --replace-fail`
passes. `@postResumeCommands@` is the **10th**, so every placeholder substituted
after it — `@preDeviceCommands@`, `@preFailCommands@`, `@preLVMCommands@`,
`@resumeDevice@`, `@shell@`, `@udevRules@` — is still live in the text you just
inserted.

Naming `@preLVMCommands@` in a **comment** inside `postResumeCommands` therefore
pastes the whole LUKS unlock script into that comment. Only its first line stays
commented; the rest executes, in initrd, part-way through the `/root` rollback.

Same family as the `${...}` trap above: **text in these strings is not inert, and
a comment is not a safe place to name things.** Refer to a hook in prose, never
by its token.

### The shell's view of the machine is a mount namespace

`lsblk`, `findmnt` and `/etc` all describe **that** namespace — faithfully, and
about the wrong world. On tenacity they reported `/` as a tmpfs,
`/dev/mapper/enc` mounted at `/etc/xdg`, empty UUID columns, and an `/etc` that
is missing files the system definitely has. Read literally, the first of those
says *the disk does not match the hardware module*, which is a stop-and-ask
condition. It matched perfectly.

Sources that are not rewritten, all unprivileged:

- `/proc/1/mountinfo` — PID 1's mount table, the host's
- `/dev/disk/by-uuid/` — udev's symlinks, so LUKS and filesystem UUIDs resolve
- `/run/current-system/…` and any `/nix/store` path — for what `/etc` should hold

`btrfs subvolume list` needs privileges and is worth asking Elly to run; it
answers `root-blank` without mounting anything:

```sh
sudo btrfs subvolume list -a /
```

Read the subvolids as well as the names. `/root` far above its neighbours — 607
against 257–265 — is the rollback *demonstrably running*, a stronger fact than
`root-blank` existing.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked files, so
a new module silently does not exist.

**Read upstream source rather than guessing at options.** It settled, during the
port, that `perSystem` has no `freeformType`, that `home.sessionPath` is
`listOf str`, and that Home Manager has no blesh module at all — so
`programs.bash.blesh.enable = true` had been doing nothing. For third-party
packages, check the project's own current source too: `handheld-daemon` got a
bespoke compatibility shim for something upstream had already fixed.

**Verify refactors by fingerprint, but not only by fingerprint.** A differing
hash does not prove breakage — reordering imports permutes
`environment.systemPackages` — so compare values with `just diff`, not just the
hash.

**Bugs here serialize.** Evaluating a cheap attribute proves nothing;
`networking.hostName` resolved happily while four separate things were broken.
Force a toplevel. And note that evaluating and building both stop short of the
defects that only appear at runtime — `lessons.md` §25.

**Ask "did it work before?" first.** These machines keep journals across boots,
so `journalctl --list-boots` plus a grep settles whether something is a
regression faster than any argument about mechanism.

**Calibrate severity.** Homelab, not production; the repo has gone six months
between commits. "This is broken and here is the fix" beats incident-report
framing.

## Conventions

**Read `linux-flake/style-guide.md` before writing a new module.** Formatting
here is deliberate: the aligned-`=` columns are intentional and `nix fmt` is
deliberately not wired up, because it would flatten them. Module bodies sit one
level deeper than they need to, left over from unwrapping `perSystem`;
reindenting would risk the `''` strings in the shell modules.

**Namespacing.** `nire` unless it needs a more specific tag; `nireHost`,
`nireUser`, `nirePackages` otherwise.

**When a rename makes the old name ungreppable, say what it was** on the
declaration — see `boot-durandal.nix`, `enable-home-manager.nix`.

**A bug recorded in a comment stays in the file.** Nobody reads `git log`; the
comment is what the next person editing the code sees, and several of these
recur. Do not trim one because the fix landed.

If a later change strands a comment — the code it described is gone, or the name
it explained has changed — **move it to a `history` heading at the bottom rather
than deleting it**, and expand it enough to stand alone. It has lost the context
that made it terse, so it needs to say more, not less. `boot-durandal.nix`,
`WARN-impermanence.nix` and `vscode.nix` have them.

**`elly` is hardcoded**, in `users.users.elly`, `home.username` and
`home-manager.users.elly`. The sibling branch has `nire.primaryUser`;
introducing it here is a separate change, not a tidy-up.

**Check for an existing `programs.*` integration before hand-writing one.**

**Don't bury Python inside a bash script.** Bash is fine, and most of
`linux-flake/scripts/` is bash. But `python3 -c '...'` heredocs inside it are
not: the Python is a quoted string as far as every editor is concerned, so it
gets no syntax highlighting, no linting, and no indentation help — which is
exactly when quoting bugs stop being visible. Two ways out, by proportion:

- **A little Python in an otherwise-shell script** — put it in
  `linux-flake/scripts/util/` as a real `.py` file and call it.
- **Mostly Python** — write the whole thing in Python. `modules.py` is the
  precedent, and the trigger is the same one the `.justfile` header uses for
  shell: data structures, parsing, or anything with a reason worth explaining.

This was written after a package-availability checker went out as bash
wrapping Nix wrapping inline Python, and shipped both bugs the shape invites —
env vars passed where `argv` was read, and a mangled line nothing highlighted.

## Docs

- `2026-08-08-PORT-PLAN-(COMPLETED).md` — the migration off den: what was
  done, where the plan was wrong, and what is still open.
- `2026-08-11-HANDOFF-durandal-and-lysithea.md` — what tenacity's first boot
  bought the other two hosts. Read before touching either: durandal has
  secure-boot config nothing has exercised, and lysithea (aarch64-darwin) does
  not exist in the config at all.
- `linux-flake/dirsAsCategory.md` — the category mechanism and its trailhead.
- `linux-flake/impermanence-stage1.md` — the root rollback's move from scripted
  stage 1 to a systemd-initrd unit, done 2026-08-10 because the 2026-08-07
  nixpkgs flipped `boot.initrd.systemd.enable` to default true. Evaluates, never
  booted. Read before touching anything in initrd.
- `linux-flake/lessons.md` — how the work went wrong in the doing: tools that
  reported success while being wrong, traps that were documented and hit anyway,
  and which questions were settled by reading source. §§1–18 are the port,
  §§19–24 the first session on the hardware, §§25–31 after it booted.
- `linux-flake/home-manager-standalone.md` — reversing the HM decision, and the
  part of the cutover that is one-way on the machine rather than in the repo.
- `git show flake-parts:SESSION-HANDOFF.md` — the sibling branch's notes on dead
  ends and decisions that should not be silently relitigated.
- `git show flake-parts:linux-flake/flake-parts-reference.md` — flake-parts
  machinery, with upstream source backing each claim.
