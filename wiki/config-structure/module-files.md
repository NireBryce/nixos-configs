# Module files

_Last modified: 2026-10-26_

A module file under `flake/modules/` never names its module. The
[dirs-as-categories](https://github.com/NireBryce/dirs-as-categories) flake
input names it after the file (`gaming.nix` is `gaming`) and makes every
folder that holds modules a category, so a host includes a whole folder by
name. Before, each file derived its own name with boilerplate, and a
name that disagreed with the filename silently dropped the module out of its
categories. Each module now opens with a comment saying so. The input's
`doc/convention.md` has the rules; this page covers what they mean here.

## Contents

- [Quick facts](#quick-facts)
- [What a module file is](#what-a-module-file-is)
- [Why the name comes from the filename](#why-the-name-comes-from-the-filename)
- [Why categories need no shim](#why-categories-need-no-shim)
- [Why some files keep `{ lib, inputs, ... }:`](#why-some-files-keep--lib-inputs--)
- [Reaching other modules: `includes` and `enables`](#reaching-other-modules-includes-and-enables)
- [Files that are not modules](#files-that-are-not-modules)
- [Shared helpers: `flake.lib`](#shared-helpers-flakelib)
- [How the move was checked](#how-the-move-was-checked)

## Quick facts

| Thing | Rule |
|---|---|
| A module's name | its filename (`gaming.nix` → `gaming`); `default.nix` takes its folder's name |
| A module file | an attribute set whose keys are classes (`nixos`, `homeManager`, `darwin`), `includes`, `enables`, `folderIsCategory` -- or a function of only `lib`/`inputs` returning one |
| A category | a folder below an area with a subfolder holding modules, or with `folderIsCategory = true` in a file directly in it; `false` opts out |
| What a category includes | every module beneath it, nested categories included |
| Hosts and the home aggregate | `includes.<class> = [ "name" … ];`, resolved by name |
| Another class's module | `enables.<class> = [ "name" ];`, received as `enabled.<class>.<name>` |
| `defaults.nix` | never a module; its class parts apply whenever anything in its folder is reached |
| Not a module | a function asking for `config`/`withSystem`, or a file with no class key: loaded as a plain flake-parts module |
| `_` paths | skipped, as by import-tree |
| Mistakes | duplicate names, unknown keys, unknown names in `includes`/`enables` stop evaluation, naming the file |
| Checks | `nix flake check`'s `module-orphans` (dirs-as-categories' `checkOrphans`, on in `checks.nix`): modules nothing reaches; `just modules`: untracked files, and drift between wiki-lint's file-only reading and the evaluated graph |

## What a module file is

```nix
# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    nixos = { pkgs, ... }: {
        programs.steam.enable = lib.mkDefault true;
    };
}
```

dirs-as-categories reads that file, names it `gaming` after its filename,
and defines `flake.modules.nixos.gaming` itself. A file may carry several
classes (`bash.nix` has `nixos` and `homeManager`); each key is that class's
module, exactly what `flake.modules.<class>.${moduleName} = …` used to hold.

## Why the name comes from the filename

Until 2026-10-16 every module opened with

```nix
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.nixos.${moduleName} = …;
}
```

Every module already had to be named after its file -- the category
collector looked modules up by filename, so a hand-written name that
differed silently left the module out of every category. Repeating that
derivation in every file was boilerplate that could only be gotten wrong. Now
the name is never written in the file at all, so it cannot disagree with the
filename, and modules sharing a name -- or a module named like a
category -- are an evaluation error instead of a silent merge (§34, §35).

## Why categories need no shim

A category used to be a folder holding a copy of `dirsAsCategory.nix`, a
shim that found its own path through `__curPos.file` and called the
collector in `_lib/` ([dirsAsCategory.md](../../flake/doc/dirsAsCategory.md)
has that design, now history). Identical files, each of which had to stay
identical.

dirs-as-categories decides from the tree's shape instead: a folder is a
category when one of its subfolders holds modules. Against this tree that
rule finds the same categories the shims declared, plus two folders it
would also call categories, `development/langs/python-dev` and
`gui-other/pkm/history`. Promoting them changes the order of every host's
Home Manager package list (same packages, different order, so a different
hash), so each carries a one-line `defaults.nix` with
`folderIsCategory = false` to keep them plain folders. Deleting either file
promotes it.

## Why some files keep `{ lib, inputs, ... }:`

A module file may be a function of only `lib` and `inputs`: dirs-as-categories
calls it with those two to read its keys. That is safe because both exist
before `config` does (`inputs` is a flake-parts special argument), and it
is what let every module body stay untouched in the move -- `lib.mkDefault`
and `inputs.<flake>` still mean what they meant. A header lists only what
the file uses (deadnix fails an unused one); a file using neither is a plain
attribute set.

A function asking for anything else (`config`) is never called, which is
why a module can no longer read the flake-parts `config`. The files that
read the flake's own outputs -- `tailnet-hosts.nix` (the host roster) and
`virtualization-cube.nix` (forge-runner's image) -- read `inputs.self`
instead, the same attribute set. That also retires the trap of two
different `config`s in one file: inside a module file, `config` only ever
means the NixOS/Home Manager one.

## Reaching other modules: `includes` and `enables`

- A host or the home aggregate lists what it includes by name:
  `includes.nixos = [ "system" "kde-desktop" … ];`. A name nothing declares
  stops evaluation. So does a module including another:
  `kde-desktop.nix` has `includes.nixos = [ "kde-base" ];`.
- A module that hands another class's module somewhere declares it:
  `enable-home-manager.nix` has `enables.homeManager = [ "elly-home-manager" ];`
  and sets `home-manager.users.elly = enabled.homeManager.elly-home-manager;`.
  Only declared names are in `enabled`, so the declaration can't drift from
  the use, and the module graph can draw the link.

Names are the filenames: the aggregates are `cube-configuration`,
`elly-home-manager` and so on (they were `cubeConfiguration`,
`ellyHomeManager`).

## Files that are not modules

`hosts.nix`, `checks.nix`, `invariants.nix`, `dev-shell.nix`, `lib.nix` and
`nix-topology-flake.nix` are plain flake-parts modules -- functions asking
for `config`, or sets with no class key -- loaded as written. They carry no
dirs-as-categories header comment. `nix-topology.nix` was split in two for this: a module file
holds only its classes, so its `perSystem` half moved to
`nix-topology-flake.nix`.

## Shared helpers: `flake.lib`

`lib.nix` sets `flake.lib`, pure helpers modules share, one file per topic in
`modules/_lib/` (skipped by the tree, so they are not modules). A module file
reaches it as `inputs.self.lib`, a plain flake-parts module as
`config.flake.lib`. `flake.lib` is typed `raw`, so only `lib.nix` may define it.

| Helper | For |
|---|---|
| `persist.persistIfImpermanent config { directories; files; }` | state a root wipe destroys: entries only on a host with `restore-root` |
| `persist.persistRegardless config { … }` | a folder that belongs on `/persist` whether or not root is wiped (nire-cube has the volume); gated on `nire.hasPersistVolume` |
| `persist.usesImpermanence config` | the predicate itself |
| `fleet.baseHostnames names`, `fleet.tailnetName host` | `nire-<x>` base hostnames and their `ts-<x>` tailnet names |

`persistRegardless` reads an option, not `config.fileSystems`: persistence adds
`fileSystems` entries, so testing them from inside the entry is infinite
recursion. The option defaults to `usesImpermanence`; `hardware-cube.nix` sets
it. A persistence entry on a host that does not wipe root still makes
impermanence warn that `/var/lib/nixos` is not persisted.

`checks.nix`'s `lib-helpers` check runs the helpers against hand-made configs.

## How the move was checked

Every NixOS host's toplevel, lysithea's, and every Home Manager generation
came out with the same drvPath before and after, and the three desktop
hosts' fingerprints (`flake/scripts/host-fingerprint.nix`) were identical.
`just modules` now also compares the file-only reading wiki-lint uses
(`check_wiki.py`'s `static_document`) against `nix eval .#moduleGraph`, so
the two cannot drift apart. `just module-graph` draws the result (the
[flake-module-graph](https://github.com/NireBryce/flake-module-graph) input).
