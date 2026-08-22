---
name: new-flake-module
description: Traps in creating, renaming, or wiring a flake-parts module in this repo (a file under flake/modules/ declaring flake.modules.<class>.<name>). Use before adding a new .nix file under flake/modules/, renaming an existing one, editing a dirsAsCategory.nix, or debugging why a module doesn't seem to be applying.
---

# Writing a flake-parts module in this repo

Background: every `.nix` file under `flake/modules/` is a flake-parts module
— its top level is `{ flake.modules.<class>.<name> = …; }`, never a bare
NixOS or Home Manager module. Category membership is derived from directory
(`flake/doc/dirsAsCategory.md`), and `flake-parts.flakeModules.modules`
declares the option they all write into. All of the following have actually
happened in this repo.

## `flake.modules` cannot live inside `perSystem`

**`perSystem` itself is fine and is used** — `checks.nix` is built on it, and
it is core flake-parts, not a den concept.

What does not work is putting `flake.modules` inside it. `perSystem` is
evaluated once per system and its outputs are transposed to
`flake.<output>.<system>.*`. `flake.modules.<class>.<name>` has no `<system>`
axis: it is one system-independent definition declared at the top level as
`lazyAttrsOf (lazyAttrsOf deferredModule)` (`flake-parts/extras/modules.nix:33`).
There is no `freeformType` on `perSystem` to let it through — the only one in
flake-parts is on the top-level `flake` option. This is what 151 files got
wrong during the original port.

## A module's name is its filename

`moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file)` in every
module, so **renaming a file renames the attribute it declares.**

That is usually harmless, because `dirsAsCategory` also derives its member
list from filenames — the two move together and category membership
survives a rename. What does not survive is anything referring to the module
by literal name: a host config importing it, or another module's `imports`.
Those break loudly, which is the good case.

The bad case is hardcoding a name that then disagrees with the filename. The
category looks up members by filename stem and filters with `? ${n}`, so a
module whose declared name no longer matches its file is **silently
dropped** — valid, evaluated, and absent. Keep declared names derived, or
keep them in sync deliberately and say so in the file.

## Hyphens are legal in Nix identifiers

`kde-base` is **one** attribute name, not `kde` minus `base`. A Nix
identifier is `[a-zA-Z_][a-zA-Z0-9_'-]*`, so `a-b` is a single token and
subtraction needs spaces around the operator. Two consequences here:

- `with config.flake.modules.nixos; [ kde-desktop ]` resolves the whole
  hyphenated name, which is why a host config can list it bare.
- **Any regex over this tree that matches module names with `\w+` is
  wrong.** `modules.py` did, and read `config.flake.modules.nixos.kde-base`
  as a reference to `kde` — which left `kde-base` reported as an orphan the
  same hour it was created. It matches `[\w-]+` now.

## Names share one namespace per class, and collisions merge

Two modules with the same name do not conflict; they **merge**. `boot` was
both the `nire/boot/` category and `nireHost/durandal/hardware/boot.nix`, so
importing the category also applied durandal's bootloader — and importing
the bootloader applied an impermanence rollback. `just modules` checks for
this; run it after adding or renaming anything.

## There are two different `config`s, and they shadow

Every file has an outer flake-parts scope and an inner NixOS/HM module. Both
call their argument `config`, and they are not the same thing:

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
still means the flake-parts one, and adding an argument list silently
repoints every existing `config`. Bind what you need in a `let` above the
declaration — `enable-home-manager.nix` does exactly this and says why.

## Module classes are not validated

flake-parts stamps the outer attribute name on as `_class` verbatim and
checks nothing, so a wrong class declares fine and fails much later at the
import site. It sets `_file` to `<flake>#modules.<class>.<name>`, so the
error names its own declaration site. Only `nixos`, `homeManager`, `flake`
and `generic` are meaningful; `darwin` works because nix-darwin sets that
`_class` itself.

Related: a module can declare a *valid* class and still be wrong. `jq` and
`bitwarden` declared `flake.modules.nixos` bodies full of `home.packages`.

## Raw NixOS modules in the import-tree path

Dropping fresh `nixos-generate-config` output into `modules/` makes
flake-parts resolve its `modulesPath` through its own `_module.args`, and
evaluation dies with `infinite recursion encountered` — naming
`modulesPath`, which is not the cause. Wrap it in the same commit:

```nix
{ ... }:
{ flake.modules.nixos.someHardware = { config, lib, modulesPath, ... }:
{
  # ... the original module body, unchanged
}
;}
```

`nireHost/installer/installer-configuration.nix` (added 2026-08-15) is a
second worked example of both this trap and the `config`-shadowing one above
in the same file: it imports upstream's
`installer/cd-dvd/installation-cd-minimal.nix` via `modulesPath` from the
*inner* module's args, and separately binds
`nixCategory = config.flake.modules.nixos.nix` in an outer `let` rather than
adding `config` to the inner module's argument list, specifically to avoid
repointing that reference at the NixOS `config` instead.

## Keep the wiki in sync

If this change adds, removes, or renames a module in a category that has an
article under `wiki/categories/` — or edits a `dirsAsCategory.nix` — update
that article's member list and `wiki/categories/README.md`'s table in the
same change, not as a follow-up. Same discipline as keeping a stranded
comment or `CLAUDE.md`'s own State section current: the wiki is only useful
if it's corrected by whoever's change made it stale.

## Further reading

- `flake/doc/dirsAsCategory.md` — the category mechanism itself, and the
  trailhead to per-module opt-in if that's ever wanted.
- `claude cave/claude-style-guide.md` — formatting conventions (aligned `=`
  columns are deliberate; `nix fmt` is deliberately not wired up).
- `wiki/categories/README.md` — the category reference this skill's changes
  should keep current.
