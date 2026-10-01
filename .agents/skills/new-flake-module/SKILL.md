---
name: new-flake-module
description: How to create, rename, or wire a flake-parts module in this repo.
when_to_use: Adding, renaming, or moving a .nix file under the flake modules tree, editing a dirsAsCategory.nix, a module that does not seem to apply.
---

# Writing a flake-parts module in this repo

## Applies to

A file under `flake/modules/` declaring `flake.modules.<class>.<name>`. Use
before adding a new `.nix` file there, renaming one, editing a
`dirsAsCategory.nix`, or debugging a module that doesn't seem to apply.

Every `.nix` under `flake/modules/` is a flake-parts module: top level
`{ flake.modules.<class>.<name> = …; }`, never a bare NixOS/HM module.
Category membership comes from directory (`flake/doc/dirsAsCategory.md`).
Every trap below has happened here.

## Scaffolder

`just add-module <class> <category>/<subdir>/<name> ["one-line description"]`
creates the file where the collector finds it, writes the header
boilerplate (`wiki/module-style-guide.md` formatting), `git add`s it (flakes
ignore untracked files), and runs collisions/orphans/untracked checks
(`flake/scripts/modules.py add`; #293). It refuses silent-failure
placements: outside every category tree, and names that would merge (same
class+name, or a category name). It cannot decide what the module *says*.

## `flake.modules` cannot live inside `perSystem`

`perSystem` itself is fine (`checks.nix` uses it). But it is evaluated per
system and transposed to `flake.<output>.<system>.*`;
`flake.modules.<class>.<name>` has no `<system>` axis — it is a top-level
`lazyAttrsOf (lazyAttrsOf deferredModule)` (`flake-parts/extras/modules.nix:33`).
`perSystem` has no `freeformType` (the only one is on top-level `flake`).
151 files got this wrong in the original port.

## A module's name is its filename

`moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file)`, so
**renaming a file renames the attribute.** `dirsAsCategory` also derives
members from filenames, so membership survives a rename; literal-name
references (host imports, other modules' `imports`) break loudly.

Bad case: a hardcoded name that disagrees with the filename. The category
looks up members by filename stem and filters with `? ${n}`, so the module
is **silently dropped** — valid, evaluated, absent. Keep declared names
derived, or in sync deliberately with a comment.

## Hyphens are legal in Nix identifiers

`kde-base` is one attribute (`[a-zA-Z_][a-zA-Z0-9_'-]*`); subtraction needs
spaces. So `with config.flake.modules.nixos; [ kde-desktop ]` works bare.
**Any regex over this tree matching module names with `\w+` is wrong**:
`modules.py` read `config.flake.modules.nixos.kde-base` as `kde` and
reported `kde-base` an orphan. It uses `[\w-]+` now.

## Names share one namespace per class; collisions merge

Same-named modules **merge**, not conflict. `boot` was both the
`nire/boot/` category and `nireHost/durandal/hardware/boot.nix`: importing
the category applied durandal's bootloader, and importing the bootloader
applied an impermanence rollback. Run `just modules` after adding/renaming.

Splitting a module into its own category makes the new directory's
basename a reserved name for every module under it; the moved file usually
still has that name (`containers/containers.nix`, the third time, §35).
Rename the file for the specific thing (`podman.nix`) in the same move.

## Two `config`s, and they shadow

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

A bare-attrset module has **no inner scope**, so `config` is the
flake-parts one; adding an argument list silently repoints every `config`.
Bind what you need in a `let` above the declaration
(`enable-home-manager.nix` does, and says why).

## Module classes are not validated

flake-parts stamps the outer attribute name as `_class` verbatim; a wrong
class declares fine and fails at the import site (`_file` =
`<flake>#modules.<class>.<name>` names the declaration). Meaningful classes:
`nixos`, `homeManager`, `flake`, `generic`; `darwin` works because
nix-darwin sets `_class` itself. A *valid* class can still be wrong: `jq`
and `bitwarden` declared `flake.modules.nixos` bodies full of `home.packages`.

## Raw NixOS modules in the import-tree path

Raw `nixos-generate-config` output dropped into `modules/` dies with
`infinite recursion encountered` naming `modulesPath` (not the cause;
flake-parts resolves it via its own `_module.args`). Wrap it in the same
commit:

```nix
{ ... }:
{ flake.modules.nixos.someHardware = { config, lib, modulesPath, ... }:
{
  # ... the original module body, unchanged
}
;}
```

Worked example of this and the `config`-shadowing trap:
`nireHost/llm-sandbox/llm-sandbox-configuration.nix` (removed 2026-08-28;
`wiki/history.md`) imported `virtualisation/disk-image.nix` via `modulesPath`
from the *inner* module's args and bound `nixCategory =
config.flake.modules.nixos.nix` in an outer `let`.

## Wiki sync

Adding/removing/renaming a module in a category with an article under
`wiki/categories/`, or editing a `dirsAsCategory.nix`: update that article
and `wiki/categories/00-INDEX.md`'s table in the same change.

Further reading: `flake/doc/dirsAsCategory.md`, `wiki/module-style-guide.md`
(aligned `=` columns deliberate; `nix fmt` deliberately not wired up).
