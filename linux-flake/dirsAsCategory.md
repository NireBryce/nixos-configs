# `dirsAsCategory`, and the trailhead out of it

> **Written by Claude Code.** A working note, not documentation: it records how one mechanism here works and what it cost to find out. Accurate as far as it was checked, and more thorough about its own reasoning than a human would bother being.


Two things: how the category mechanism works and why it is shaped the way it is,
and — if you ever want to — how to convert it to per-module opt-in.

**Nothing here is a recommendation to convert.** Categories were chosen
deliberately (`0c0b5f0`), and repaired rather than replaced during the
flake-parts port. This document exists so that decision stays reversible by
someone who wasn't there, not to argue against it.

---

## How it works

Every category directory holds a copy of `dirsAsCategory.nix`. The file derives
its own category name from the directory it sits in, so it can be copied
anywhere without editing:

```nix
categoryDir  = dirOf __curPos.file;
categoryName = baseNameOf categoryDir;
```

It then walks the subdirectories, collects every `.nix` filename beneath them,
and declares one aggregate per module class:

```nix
flake.modules.nixos.${categoryName}.imports       = forClass "nixos";
flake.modules.homeManager.${categoryName}.imports = forClass "homeManager";
flake.modules.darwin.${categoryName}.imports      = forClass "darwin";
```

`forClass` resolves the collected names to real module references and drops any
name that class does not declare:

```nix
forClass = class:
    map (n: config.flake.modules.${class}.${n})
        (lib.filter (n: config.flake.modules.${class} ? ${n}) allModules);
```

**Membership is therefore implicit: a module belongs to the category of the
directory it is filed in.** Adding a module is a one-file change — create the
file in the right place and it is in. That is the mechanism's whole appeal.

### Things that are load-bearing

- **Always define all three classes, even when the filtered list is empty.**
  Making the attribute itself conditional — `lib.optionalAttrs (forClass … != [])` —
  looks tidier and recurses: computing the attribute names of
  `flake.modules.nixos` would require reading `flake.modules.nixos`. Empty
  aggregates are harmless. Conditional ones are not.
- **The class filter is not optional.** A directory cannot know what a module
  declares. `micro.nix` declares only `homeManager`; without the filter,
  `flake.modules.nixos.editors` asks for `config.flake.modules.nixos.micro`,
  which does not exist.
- **Nested categories overlap their parents on purpose.** `nire/hardware` and
  `nire/hardware/amd` both collect `amdcpu` and `amdgpu`, because `collectModules`
  recurses. That gives coarse and fine handles on the same modules. It looks
  like a bug and is not.
- **The name filter must match the current filename.** It excluded
  `dirsAsProvides.nix` for a while after the file was renamed to
  `dirsAsCategory.nix`, so nested categories collected a phantom module called
  `dirsAsCategory`. The class filter masks that symptom, which is exactly why
  the filter itself has to be right.

### Verifying a change to it

The self-reference — reading `config.flake.modules.<class>` from a file that
also *defines* an attribute in it — is the part that can plausibly blow up. It
resolves cleanly today, but that was established by building a model with
flake-parts' exact option type and `apply`
(`flake-parts/extras/modules.nix:33,72`) and evaluating it, not by reasoning.
Do the same rather than assuming, and check three things: a category imports
only modules declaring its class, an imported module's config actually applies,
and no category name is missing.

---

## What the alternative is

The sibling `flake-parts` branch uses per-module opt-in instead. Each module
declares which aggregates it belongs to, next to its own definition:

```nix
{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports =
        [ config.flake.modules.homeManager.ripgrep ];

    flake.modules.homeManager.ripgrep = { pkgs, ... }: {
        home.packages = [ pkgs.ripgrep ];
    };
}
```

`flake.modules.<class>.<name>` is a `deferredModule`, so many files can define
the same aggregate and the module system merges them. A separate `roles.nix`
declares only the hierarchy between aggregates; nothing lists a roster.

### Why you might want it

- **Directory and membership come apart.** A module can live wherever it reads
  best and still belong to whatever aggregate is right. Under categories, moving
  a file changes what installs it — which cuts against the whole reason this
  repo uses `import-tree` (paths carry no meaning).
- **One module, several aggregates, no duplication.** Today the only way a
  module joins two categories is to sit under both, or for one category to
  nest inside the other.
- **Roles get cheap.** `base` / `desktop` / `handheld` with modules opting into
  more than one is awkward to express through directories, and it is exactly
  what a second host needs. This is the strongest reason, and it becomes real
  the moment tenacity comes back.
- **It is explicit.** You can grep a module and see where it goes.

### What it costs

- **~150 one-line additions**, one per module.
- **No file lists a roster any more.** There is no `desktop.nix` to open. The
  sibling branch answers this with `just modules`, a static-analysis script that
  reconstructs membership, plus `--reverse` to invert it. If you convert, port
  that in the same change or the layout gets genuinely hard to read — this was
  raised there *after* adoption and the script is what settled it.
- **A new silent failure mode.** Omit the opt-in line and nothing happens: the
  module is valid, evaluates cleanly, installs nothing, and no evaluation can
  ever produce an error. Categories cannot fail this way, because membership is
  automatic. The sibling branch runs a reachability check as a flake check
  specifically to cover this, and it is not optional there.
- **Name collisions merge instead of erroring.** Module names share one
  namespace per class, so a copy-paste that forgets to rename yields one module
  silently carrying both configs. Their `add-pkg.sh` refuses duplicate names for
  this reason.

---

## How to convert, if you decide to

Order matters; each step's precondition is the previous one.

1. **Get a fingerprint first.** Capture
   `nixosConfigurations.<host>.config.system.build.toplevel.drvPath` and an
   attribute sample (`environment.systemPackages` names, `systemd.services`,
   `users.users`, `environment.etc`) on a tree that evaluates. A fingerprint of
   a broken tree is worthless, and this refactor is meant to preserve behaviour
   exactly.

2. **Decide the aggregate names before touching files.** The natural choice is
   to keep the existing category names — `development`, `editors`, `gui-other`,
   `linux-utils`, `nix-utils`, `shell-apps`, `terminals`, and the `nire/*` ones —
   so the conversion changes only *how* membership is established, not what the
   groups are called. `aspect-durandal.nix`'s `moduleList` is then still the
   host's roster, unchanged. Renaming at the same time makes the diff
   unreviewable.

3. **Generate the opt-in lines from the categories themselves.** The current
   `dirsAsCategory` output *is* the answer key: for each category, the list of
   modules and the classes each declares. Emit one `imports` line per
   module/class pair and insert it above that module's own declaration. Do this
   mechanically — hand-editing 150 files invites exactly the omission that has
   no error.

4. **Keep an intermediate tier if the roles are ever going to differ.** Package
   categories feeding a role, rather than each package joining the role
   directly, is what lets a host take some categories and not others later
   without touching 100+ files.

5. **Delete the 24 `dirsAsCategory.nix` last**, once the opt-in lines are in and
   the fingerprint matches. Deleting first means the tree stops working and you
   lose the ability to diff against it.

6. **Add the reachability check in the same change.** Not after. Step 3's
   failure mode is silent, and it is the only one that no amount of evaluating
   will surface. `git show flake-parts:linux-flake/scripts/modules.py` is a
   starting point; note it deliberately uses two different edge models —
   segment-scoped for display, file-level for the check — because segment
   scoping loses `let`-bound references and reported 119 of 160 modules as dead.

Expect `drvPath` to change from import reordering alone: permuting
`environment.systemPackages` changes the hash without changing the package set.
Compare sets, not hashes.

---

## Related reading

- `2026-08-08-PORT-PLAN-(COMPLETED).md` — Phase 2d, where the
  repair-not-replace decision was made.
- `git show flake-parts:SESSION-HANDOFF.md` §6 — the sibling branch's account of
  the opt-in pattern: what it replaced, its four failure modes, and the
  mechanics of converting ~140 files to it.
