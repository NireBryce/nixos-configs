# How the non-obvious pieces work

This chapter covers the parts of this flake that behave differently from
what a reader who knows NixOS would assume. Each section opens with the rule,
then shows the mechanism and its consequences. Read the chapter before you
edit anything under `flake/modules/`; the later chapters assume it. Terms in
*italics* on first use are defined in the [glossary](glossary.md).

## `flake.nix` is a manifest, not a host list

`flake/flake.nix` declares inputs and imports flake-parts modules; it names
no hosts and lists no modules. flake-parts is a library that builds a flake's
outputs from module-system modules (*flake-parts modules*), much as NixOS
builds a system from NixOS modules.

Among the flake-parts modules `flake/flake.nix` imports are
`flake-parts.flakeModules.modules`, nix-darwin's flake module, and
`(inputs.dirs-as-categories.lib.tree ./modules)`; `touchup` only turns off the
`formatter` output. The *dirs-as-categories* input
uses `import-tree` to read every `.nix` file under `flake/modules/`. From
those files it fills in `flake.modules.<class>.<name>`. The hosts themselves
are declared in `flake/modules/host-config/hosts.nix`.

Because no file lists modules, a file's role depends on its *filename* and
on the *folder* it sits in, as the next sections explain. Two path rules
decide which files are read at all:

- Paths containing `/_` are skipped, which is why `flake/modules/_lib/` and
  `general-config/impermanence/_disko/` are not modules.
- Files that don't end in `.nix` are ignored, so a module's config files can
  sit beside it (for example
  `packages-config/development/langs/python-dev/!dotfiles/`).

Source: `flake/flake.nix`;
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"import-tree".

## A module's name is its filename

A module file never names itself: dirs-as-categories names it after its
file. `gaming.nix` becomes the module `gaming`, and a `default.nix` takes its
folder's name. A reader used to flake-parts would expect each file to declare
`flake.modules.nixos.gaming = …`. Earlier, every file worked out its own name
with boilerplate (`lib.removeSuffix ".nix" (baseNameOf __curPos.file)`). That
boilerplate is gone.

Two consequences follow.

- Renaming a file renames the module. Anything that refers to the module by
  name (`includes`, `enables`, `hosts.nix`) then fails to evaluate, loudly.
  Membership survives a rename, because membership comes from the folder.
- Names share one namespace across the whole tree, modules and categories
  alike. If two files have the same name, or a module has the same name as a
  category, evaluation stops and names both files. Before dirs-as-categories,
  such a pair merged silently. Durandal's old `boot.nix` merging with the
  `boot` category is the recorded example (§34 in
  [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)). The shared
  namespace is why host-specific files carry a host suffix
  (`boot-durandal.nix`, `hardware-cube.nix`).

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Why the name comes from the filename"; `.agents/skills/new-flake-module/SKILL.md`.

## The module file shape

A module file is an attribute set whose keys are *module classes*, and each
value is the module for that class. A class is the kind of configuration the
module targets: `nixos`, `homeManager` or `darwin`. A reader would expect a
plain NixOS module (`{ config, pkgs, ... }: { … }`) instead.

```nix
# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # `rg` is a much faster and more powerful grep alternative
        home.packages = with pkgs; [
            ripgrep
        ];
    };
}
```

That is `packages-config/shell-apps/text-tools/ripgrep.nix` in full. The
allowed keys are `nixos`, `homeManager` and `darwin`, plus `includes`,
`enables` and `folderIsCategory`. A file may set several classes at once.
Holding several classes in one file is the main thing flake-parts offers this
repo: one feature's NixOS half and Home Manager half can live in one file.

The file may instead be a function of only `lib` and/or `inputs` that
returns such a set (`{ lib, ... }: { nixos = …; }`). `pkgs` and `config`
belong in the **inner**, per-class module's arguments. A `pkgs` taken from
anywhere else comes from *perSystem*, flake-parts' per-system scope. That
`pkgs` has no `nixpkgs.config`, so it silently loses `allowUnfree`. That
design is under review in
[issue 559](https://github.com/NireBryce/nixos-configs/issues/559).

Two mistakes here are easy to make:

- A raw NixOS module dropped under `modules/` (for example
  `nixos-generate-config` output) is not a module file. dirs-as-categories
  refuses a file that asks for an argument only a class module gets (`pkgs`,
  `modulesPath`, `osConfig`, `nixosConfig`, `darwinConfig`, `utils`), and the
  error names the argument and the fix: wrap the module,
  `{ nixos = <the original module>; }`, or rename the file with a leading `_`
  and import it from a class. Older library versions died with `infinite
  recursion encountered`, blaming `modulesPath`. A raw module that asks only
  for `config`, `lib` or `options` is not caught: it loads as a flake-parts
  module.
- A class key can be valid and its body still wrong. `jq` and `bitwarden`
  once declared `nixos` bodies full of `home.packages`. dirs-as-categories
  checks class keys, not what a class body sets, so the mistake shows up when
  a host that includes the module is evaluated, as an "option `home` does not
  exist" error. A module that no host reaches is flagged only as an orphan. An
  opt-in hint is proposed in
  [dirs-as-categories issue 32](https://github.com/NireBryce/dirs-as-categories/issues/32).

Unverified: the raw-module refusal was read from the library's `nix/scan.nix`
and changelog, not run. Running it needs flake inputs that the environment this
book was written in could not fetch.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"What a module file is";
[module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md),
"The header"; `.agents/skills/new-flake-module/SKILL.md`, "Raw NixOS modules"
and "Classes".

## Categories are folders

A *category* is a group of modules defined by a folder. No file lists which
modules make up a "desktop" or "base" profile.

A folder below an *area* (`general-config/`, `packages-config/`, …) is a
category when one of its subfolders holds modules. A file directly in the
folder can also decide the question with `folderIsCategory`. Including a
category includes every module beneath it, at any depth, nested categories
too. Nobody writes the membership list down; it comes from where files sit.

Choosing a directory is therefore choosing which hosts get the module.
Shared things stay optional because a host can leave a category out, so
nothing in this repo declares an `mkEnableOption` for that purpose. The
[categories chapter](categories.md) covers the details and the traps.

Source: [architecture.md](../../wiki/config-structure/architecture.md),
"Quick facts"; `.agents/rules/flake-modules.md`.

## Hosts list categories with `includes`

A host does not import files by path; its *entry point* lists categories
**by name**. The entry point is `host-config/<host>-configuration.nix`, and
it is itself a module file:

```nix
{
    includes.nixos = [
        "durandal"      # host-config/durandal/: this machine's own modules
        "boot"
        "impermanence"  # WARN-impermanence -- wipes /root on boot
        "hardware"
        "nix"
        "peripherals"
        "shell-config"
        "system"
        "kde-desktop"   # a single module, named directly
        "development"
        "editors"
        # … the other package categories …
        "elly"
    ];
    nixos.networking.hostName = "nire-durandal";
}
```

(Shortened from the example host's `durandal-configuration.nix`, which
comments on every line.) `hosts.nix` then turns each entry point into a
machine:
`mkHost "x86_64-linux" config.flake.modules.nixos.durandal-configuration`.

Entry points sit **directly** in `host-config/` (and `users-config/`, for
`elly-home-manager.nix`). A file there is outside every category, so the
host definition doesn't become a member of anything. If you put an ordinary
module there, no host receives it.

A name in `includes` that doesn't exist stops evaluation, which is the safe
failure. The silent failure is a category that no host includes: it
evaluates fine and installs nothing. The `module-orphans` flake check exists
to catch that case.

Source: `flake/modules/host-config/durandal-configuration.nix`,
`flake/modules/host-config/hosts.nix`;
[where-modules-go.md](../../wiki/config-structure/where-modules-go.md),
"Not a module: entry points".

## `includes` and `enables`

Modules reach other modules by name, through two mechanisms, not by
importing paths:

- `includes.<class> = [ "name" … ];` pulls in other modules or categories of
  the **same** class. `kde-desktop.nix` has `includes.nixos = [ "kde-base" ];`
  and `jovian.nix` has `includes.nixos = [ "kde-base" "jovian-persist" ];`.
- `enables.<class> = [ "name" ];` gives a module access to a module of
  **another** class, which arrives as an argument, `enabled.<class>.<name>`.
  `enable-home-manager.nix` declares
  `enables.homeManager = [ "elly-home-manager" ];` and then sets
  `home-manager.users.elly = enabled.homeManager.elly-home-manager;`.
  `tenacity-configuration.nix` uses the same mechanism to append its own
  Home Manager module.

The `enabled` argument holds only the names that were declared. The
declaration and its use therefore can't drift apart, and the module graph
can draw the link. `nix eval --json ./flake#moduleGraph` publishes the whole
graph (categories, modules, classes, `includes`, `enables`) as data, and
`just module-graph` draws it.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Reaching other modules"; `flake/modules/general-config/system/home-manager/enable-home-manager.nix`.

## Files that are not module files

Not every `.nix` file under `modules/` is a module file. If a function asks for
`config` or `withSystem`, or a file has no class key, dirs-as-categories
loads it as a **plain flake-parts module**. `hosts.nix`, `checks.nix`,
`invariants.nix`, `dev-shell.nix` and `lib.nix` are written that way on
purpose, and they carry no dirs-as-categories header comment. `defaults.nix`
is never a module file: its class parts apply whenever anything in its folder is
reached, and `folderIsCategory` goes in it.

A module file can no longer read the flake-parts `config`. Files that need
the flake's own outputs read `inputs.self` instead; `tailnet-hosts.nix` does
this to get the host roster. A side effect is that the old trap of having two
different `config`s in one file is gone.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Files that are not modules" and "Why some files keep `{ lib, inputs, ... }:`".

## Shared helpers: `flake.lib`

Shared helper functions live in `flake.lib`, not in a `lib/` folder that
modules import by relative path. `flake/modules/lib.nix` sets `flake.lib`
from one file per topic in `modules/_lib/`. The underscore keeps the tree
from treating those files as modules. A module file reaches the helpers as
`inputs.self.lib`, and a plain flake-parts module as `config.flake.lib`. The
current topics are `persist` and `fleet`:

- `persist.persistIfImpermanent` keeps state only on a host that wipes
  `/root`.
- `fleet.tailnetName` turns `nire-<x>` into `ts-<x>`.

`flake.lib` is typed `raw`, so only one definition is allowed. A new topic
goes in `_lib/<topic>.nix` plus an entry in `lib.nix`. A second
`flake.lib = …` elsewhere would conflict instead of merging.

Source: `flake/modules/lib.nix`, `flake/modules/_lib/fleet.nix`;
[module-files.md](../../wiki/config-structure/module-files.md), "Shared
helpers"; commit `aca2a74`.

## Impermanence: some hosts wipe `/root` on every boot

A host that includes the `impermanence` category loses everything on `/`
that is not explicitly persisted, at every boot. *Impermanence* is the name
for this setup.

On every boot,
`general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
runs a `restore-root` unit in the initrd. The unit deletes the btrfs
subvolume that `/` lives on and replaces it with a snapshot of an empty
subvolume, `root-blank`. What survives is `/nix`, `/home`, `/var/log`, and
the paths listed for `/persist`. Hosts get this behavior only through the
`impermanence` category. A host that includes the category wipes `/root`. A
host that leaves it out keeps a plain persistent root, and its entry point
says so. Darwin has no impermanence. Check the specific host's entry point
rather than assuming.

Consequences:

- **Never install this config wholesale.** On a disk shaped like the one the
  module describes, it deletes `/`.
- **`root-blank` must already exist.** No host's config creates it, and
  without it the rollback deletes `/root` and then cannot replace it.
- Any state that matters has to be declared for persistence. Use
  `persist.persistIfImpermanent` from `flake.lib`.
- For changes near boot, prefer `just boot` over `just switch`, so the
  running generation stays in the boot menu as a fallback.
- `WARN-impermanence.nix` explains its reasons at length. Read the whole file
  before you touch anything near it.

Source: `flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
header; `AGENTS.md`, Safety; `.agents/rules/impermanence.md`;
[impermanence-and-secrets.md](../../wiki/config-structure/impermanence-and-secrets.md).

## Secrets: sops-nix, names only

Secrets live in an encrypted file inside the repository; inspect them by
name, never by value. They are managed with sops-nix
(`general-config/system/secrets/`). `secrets.yaml` is encrypted and
**committed on purpose**. Each host decrypts it with its own SSH host key,
converted to an age key. The enrolled hosts are whichever ones `.sops.yaml`
in that folder lists; read that file rather than a count.

The *names* of the keys are plaintext inside the ciphertext. To answer
"which secrets exist?", run `just read-sops-names`. The recipe prints names
only and cannot print a value. **Never use `sops -d` to answer that
question:** it prints every value, and redirecting stderr doesn't stop
stdout. The repo has leaked values that way before. The skill
`.agents/skills/secrets-hygiene/SKILL.md` covers all handling of sops
output.

Source: `AGENTS.md`, Safety; `.agents/rules/secrets.md`;
[impermanence-and-secrets.md](../../wiki/config-structure/impermanence-and-secrets.md),
"Secrets".

## Home Manager comes through NixOS

*Home Manager*, which manages a user's packages and dotfiles as modules, runs
inside each system configuration. There is no `homeConfigurations` output
and no separate home switch. `just switch` applies the system and Home
Manager together. The whole home config is one module, `elly-home-manager`,
and every host shares it, darwin included. The reasons and the failure modes
are in [Wiring a user and Home Manager](users-and-home-manager.md); the
darwin side is in [Darwin edge cases](darwin.md).

Source: [architecture.md](../../wiki/config-structure/architecture.md),
"Home Manager integration".
