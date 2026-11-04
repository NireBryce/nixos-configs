---
name: new-flake-module
description: Creates, renames and wires a module in the flake modules tree.
when_to_use: Adding, renaming or moving a .nix file under the flake modules tree, making or removing a category, or a module that doesn't seem to apply.
---

# Writing a module in this repo

**Needs:** bash-guards

## Applies to

Use this before adding, renaming or moving a `.nix` file under `flake/modules/`, changing which folders are categories, or debugging a module that does not seem to apply.

`wiki/config-structure/module-files.md` explains why modules look the way they do. The dirs-as-categories input's `doc/convention.md` lists every rule and error. Every trap below has happened here.

## Scaffolder

```sh
just add-module <class> <category>/<subdir>/<name> ["one-line description"]
```

This writes the file in the module shape (header comment, `# summary:`, `wiki/config-structure/module-style-guide.md` formatting), runs `git add` (flakes ignore untracked files), and runs the checks (`flake/scripts/modules.py add`; #293). It refuses a class dirs-as-categories does not know, a target outside every category, `default.nix`/`defaults.nix`, and a name already taken by a module or a category. It cannot decide what the module says.

## The shape

```nix
# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    homeManager = { pkgs, ... }: {
        # summary: one line (in packages-config/, `# package summary:`)
        home.packages = with pkgs; [ ripgrep ];
    };
}
```

- Allowed keys are the classes (`nixos`, `homeManager`, `darwin`), `includes`, `enables` and `folderIsCategory`. Any other key stops evaluation and names the file.
- List only the `lib`/`inputs` arguments the file uses (deadnix fails an unused one). A file using neither is a plain attribute set. A header asking for `config` makes the file a plain flake-parts module, not a module file.
- `pkgs` and the NixOS/HM `config` belong to the inner module's arguments. A `pkgs` from anywhere else is perSystem's, which lacks `nixpkgs.config`.

## A module's name is its filename

Renaming a file renames the module. Membership follows the folder, so it survives a rename. References by name (`includes`, `enables`, `hosts.nix`) break, and an unknown name stops evaluation. `default.nix` takes its folder's name. When a rename makes the old name ungreppable, record the old name in a comment (`boot-durandal.nix`).

## Names share one namespace

Modules and categories share one namespace across classes. Two with one name stop evaluation and name both files. This used to be a silent merge: `boot` was both the `general-config/boot/` category and durandal's `boot.nix`, so importing the category applied durandal's bootloader (§34).

Splitting a module out into its own category takes the new folder's name, and the moved file often still has it (`containers/containers.nix`, the third time, §35). Rename the file for the specific thing (`podman.nix`) in the same move.

## Categories come from folders

A folder below an area is a category when a subfolder holds a module. To make a flat folder a category, or keep a folder of folders plain, put `{ folderIsCategory = true; }` (or `false`) in a `defaults.nix` beside the modules (`python-dev/` and `pkm/history/` do, to stay plain). Promoting a folder can reorder hosts' package lists: same packages, different hash. Compare hosts before and after (`just diff`, `flake/scripts/host-fingerprint.nix`).

## Hyphens are legal in Nix identifiers

`kde-base` is one attribute (`[a-zA-Z_][a-zA-Z0-9_'-]*`); subtraction needs spaces. A regex over this tree that matches module names with `\w+` is wrong: `modules.py` once read `config.flake.modules.nixos.kde-base` as `kde` and reported `kde-base` an orphan. Use `[\w-]+`.

## Classes

dirs-as-categories knows `nixos`, `homeManager` and `darwin` (the `classes` in `nix eval --json ./flake#moduleGraph`; `modules.py`'s `CLASSES` mirrors it). A valid class can still be the wrong one: `jq` and `bitwarden` once declared `nixos` bodies full of `home.packages`. dirs-as-categories checks class keys, not what a class body sets. Evaluating a host that reaches the module catches the mistake as "option `home` does not exist". A module no host reaches is caught only by the orphan check, not for its contents.

The library's opt-in `dirsAsCategories.checkClassContents = "build"` or `"eval"` (v0.4.0) adds a flake check, `module-class-contents`. It names a class part that sets a namespace only another class has (`home` under `nixos`); it is a heuristic over a short list. This repo sets it to `"eval"`, so `just check` fails on a misplaced class part even under `--no-build`, as it does for orphans.

## Raw NixOS modules

Raw `nixos-generate-config` output dropped into `modules/` is not a module file. dirs-as-categories refuses a function that asks for an argument only a class module gets (`pkgs`, `modulesPath`, `osConfig`, `nixosConfig`, `darwinConfig`, `utils`), and names the argument and the fix. Older versions died with `infinite recursion encountered` naming `modulesPath`, which was not the cause. A raw module that asks only for `config`, `lib` or `options` is not caught and loads as a flake-parts module. Wrap it in the same commit:

```nix
{
    nixos = { config, lib, modulesPath, ... }: {
        # ... the original module body, unchanged
    };
}
```

## Wiki sync

When you add, remove or rename a module in a category with an article under `wiki/config-structure/categories/`, or change which folders are categories, update that article and run `just wiki-gen` in the same change. `just wiki-gen` regenerates `wiki/config-structure/categories/00-INDEX.md`'s tables, the module counts and `wiki/config-structure/architecture.md`'s diagram. `just check` fails on an orphan (a module nothing reaches; `checkOrphans = "eval"`, so `--no-build` fails too). `just modules` checks untracked files and that wiki-lint's file-only reading still matches the evaluated graph.

Further reading: `wiki/config-structure/module-files.md`, `wiki/config-structure/module-style-guide.md` (aligned `=` columns are deliberate; `nix fmt` is deliberately not wired up).
