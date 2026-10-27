---
name: new-flake-module
description: How to create, rename, or wire a module in this repo.
when_to_use: Adding, renaming, or moving a .nix file under the flake modules tree, making or unmaking a category, a module that does not seem to apply.
---

# Writing a module in this repo

## Applies to

A file under `flake/modules/`. Use before adding a new `.nix` file there,
renaming or moving one, changing which folders are categories, or
debugging a module that doesn't seem to apply.

`wiki/module-files.md` is why modules look the way they do; the
dirs-as-categories input's `doc/convention.md` has every rule and error.
Every trap below has happened here.

## Scaffolder

`just add-module <class> <category>/<subdir>/<name> ["one-line description"]`
writes the file in the module shape (header comment, `# summary:`,
`wiki/module-style-guide.md` formatting), `git add`s it (flakes ignore
untracked files), and runs the checks (`flake/scripts/modules.py add`;
#293). It refuses a class dirs-as-categories doesn't know, a target outside
every category, `default.nix`/`defaults.nix`, and a name already taken by a
module or a category. It cannot decide what the module *says*.

## The shape

```nix
# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, ... }:
{
    homeManager = { pkgs, ... }: {
        # summary: one line (in packages-config/, `# package summary:`)
        home.packages = with pkgs; [ ripgrep ];
    };
}
```

- Keys: classes (`nixos`, `homeManager`, `darwin`), `includes`, `enables`,
  `folderIsCategory`. Anything else stops evaluation naming the file.
- The header lists only `lib`/`inputs` the file actually uses (deadnix
  fails an unused one); a file using neither is a plain attribute set. A
  header asking for `config` makes the file a plain flake-parts module, not
  a module file.
- `pkgs` and the NixOS/HM `config` belong to the inner module's arguments.
  `pkgs` from anywhere else would be perSystem's, without `nixpkgs.config`.

## A module's name is its filename

**Renaming a file renames the module.** Membership follows the folder, so
it survives a rename; references by name (`includes`, `enables`,
`hosts.nix`) break loudly -- an unknown name stops evaluation. `default.nix`
takes its folder's name. When a rename makes the old name ungreppable, say
what it was in a comment (`boot-durandal.nix`).

## Names share one namespace

Modules and categories share it, across classes. Two with one name stop
evaluation, naming both files -- the failure that used to be a silent
merge: `boot` was both the `general-config/boot/` category and durandal's
`boot.nix`, so importing the category applied durandal's bootloader (§34).

Splitting a module out into its own category makes the new folder's name
taken; the moved file usually still has it (`containers/containers.nix`,
the third time, §35). Rename the file for the specific thing (`podman.nix`)
in the same move.

## Categories come from folders

A folder below an area is a category when a subfolder holds a module. To
make a flat folder a category, or keep a folder of folders plain, put
`{ folderIsCategory = true; }` (or `false`) in a `defaults.nix` beside the
modules (`python-dev/` and `pkm/history/` do, to stay plain). Promoting a
folder can reorder hosts' package lists -- same packages, different hash --
so compare hosts before and after (`just diff`,
`flake/scripts/host-fingerprint.nix`).

## Hyphens are legal in Nix identifiers

`kde-base` is one attribute (`[a-zA-Z_][a-zA-Z0-9_'-]*`); subtraction needs
spaces. **Any regex over this tree matching module names with `\w+` is
wrong**: `modules.py` once read `config.flake.modules.nixos.kde-base` as
`kde` and reported `kde-base` an orphan. Use `[\w-]+`.

## Classes

dirs-as-categories knows `nixos`, `homeManager`, `darwin` (the `classes` in
`nix eval --json ./flake#moduleGraph`; `modules.py`'s `CLASSES` mirrors it). A *valid* class can still be wrong: `jq` and `bitwarden`
once declared `nixos` bodies full of `home.packages`.

## Raw NixOS modules

Raw `nixos-generate-config` output dropped into `modules/` is a function
asking for `config`, so it is loaded as a flake-parts module and dies with
`infinite recursion encountered` naming `modulesPath` (not the cause).
Wrap it in the same commit:

```nix
{
    nixos = { config, lib, modulesPath, ... }: {
        # ... the original module body, unchanged
    };
}
```

## Wiki sync

Adding/removing/renaming a module in a category with an article under
`wiki/categories/`, or changing which folders are categories: update that
article and run `just wiki-gen` (regenerates `wiki/categories/00-INDEX.md`'s
tables, the module counts and `wiki/architecture.md`'s diagram) in the same
change. `just check` fails on an orphan (a module nothing reaches; the
`module-orphans` check); `just modules` checks untracked files, and that
wiki-lint's file-only reading still matches the evaluated graph.

Further reading: `wiki/module-files.md`, `wiki/module-style-guide.md`
(aligned `=` columns deliberate; `nix fmt` deliberately not wired up).
