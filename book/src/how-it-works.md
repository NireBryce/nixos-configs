# How the non-obvious pieces work

Several parts of this flake behave differently from what a reader who knows
NixOS would assume. Each section states the rule, then the mechanism and its
consequences. The later chapters assume this one.

## The module file shape

A [module file](glossary.md#module-file) is an attribute set whose keys are
[module classes](glossary.md#module-class), and each value is the module for
that class. A plain NixOS module (`{ config, pkgs, ... }: { … }`) is not a
module file.

```nix
# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
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

The example is `packages-config/shell-apps/text-tools/ripgrep.nix` in full. The
allowed keys are the class keys `nixos`, `homeManager` and `darwin`, plus
[`includes`](#hosts-list-categories-with-includes),
[`enables`](#includes-and-enables) and `folderIsCategory`. A file may set
several classes at once, so one feature's NixOS half and Home Manager half can
live in one file. This is the main thing [flake-parts](glossary.md#flake-parts)
offers this repo.

The file may instead be a function of only `lib` and/or `inputs` that
returns such a set (`{ lib, ... }: { nixos = …; }`). `pkgs` and `config`
belong in the arguments of the **inner**, per-class module. A `pkgs` taken from
the outer function comes from [perSystem](glossary.md#persystem). That
`pkgs` is built from the fleet's shared `nixpkgs.config`
(`flake/modules/_lib/nixpkgs.nix`), so it carries `allowUnfree` like a host's,
but it is a separate nixpkgs instance.

Two mistakes are easy to make:

- A raw NixOS module dropped under `modules/` (for example
  `nixos-generate-config` output) is not a module file.
  [dirs-as-categories](glossary.md#dirs-as-categories) refuses it when it asks for an argument only a class module gets, and the
  error names the argument. Wrap it as `{ nixos = <the original module>; }`;
  see [Wrapping a raw NixOS
  module](adding-a-module.md#wrapping-a-raw-nixos-module).
- A class key can be valid and its body still wrong. `jq` and `bitwarden`
  once declared `nixos` bodies full of `home.packages`. dirs-as-categories
  checks class keys but not what a class body sets. The mistake shows up as an
  "option `home` does not exist" error when a host that includes the module
  is evaluated. A module that no host reaches is flagged only as an orphan
  (`just modules`).

The library has an opt-in check for the second mistake. This repo sets
`dirsAsCategories.checkClassContents = "eval"`, which adds a flake check
named `module-class-contents` that throws while it is evaluated, so `just
check` fails on it even under `--no-build`. The check covers a short list of
namespaces (for example `home` under `nixos`). A misplaced body outside that
list still surfaces only when a host is evaluated.

## A module's name is its filename

A module file never names itself: dirs-as-categories names it after its
file. `gaming.nix` becomes the module `gaming`, and a `default.nix` takes its
folder's name.

- Renaming a file renames the module. Anything that refers to the module by
  name (`includes`, `enables`, `hosts.nix`) then fails to evaluate.
  Membership survives a rename, because membership comes from the folder.
- Names share one namespace across the whole tree, modules and categories
  alike. If two files have the same name, or a module has the same name as a
  category, evaluation stops, names both files and says which kind of clash
  it is. Host-specific files carry a host suffix (`boot-durandal.nix`,
  `hardware-cube.nix`) to stay clear of the shared namespace. The recorded
  example is [lesson
  34](../../wiki/agent-lessons-learned/34-collision-where-both-halves-work.md).

## Categories are folders

A [category](glossary.md#category) comes from a folder. No file lists which
modules make up a "desktop" or "base" profile. To see real data:

```sh
nix eval --json ./flake#moduleGraph     # categories, modules, classes, includes, enables
just module-graph tree --category shell-apps
```

A folder below an [area](glossary.md#area) (`general-config/`,
`packages-config/`, …) is a category when one of its subfolders holds modules. A file directly in the
folder can decide the question with `folderIsCategory`. Including a category
includes every module beneath it, at any depth.

Choosing a directory for a module therefore chooses which hosts get it. A
host can leave a category out, which keeps shared things optional, so nothing
in this repo declares an `mkEnableOption` for that purpose. The path from
`ripgrep.nix` to every host:

```text
packages-config/shell-apps/text-tools/ripgrep.nix
        |  sits in the folder text-tools/, below shell-apps/
        |  (text-tools is itself a category, nested in shell-apps)
        v
category "shell-apps"   (includes every module beneath the folder)
        |  listed in includes.homeManager
        v
users-config/elly-home-manager.nix
        |  taken in by enable-home-manager.nix (NixOS) and
        |  enable-home-manager-darwin.nix (darwin)
        v
every host
```

The [categories chapter](categories.md) covers the details and the traps.

## Hosts list categories with `includes`

A host's [entry point](glossary.md#entry-point) lists categories **by name**.
The entry point is `host-config/<host>-configuration.nix`, itself a module file:

```nix
{
    includes.nixos = [
        "durandal"      # host-config/durandal/: this machine's own modules
        "boot"
        "impermanence"  # WARN-impermanence -- wipes /root on boot
        "hardware"
        # … the other categories …
        "elly"
    ];
    nixos.networking.hostName = "nire-durandal";
}
```

The full example is in [Wiring a
host](wiring-a-host.md#step-2-write-the-entry-point). `hosts.nix` turns each
entry point into a machine:
`mkHost "x86_64-linux" config.flake.modules.nixos.durandal-configuration`.

Entry points sit **directly** in `host-config/` (and `users-config/`, for
`elly-home-manager.nix`). A file there is outside every category, so an
ordinary module put there reaches no host.

A name in `includes` that doesn't exist stops evaluation. A category that no
host includes evaluates fine and installs nothing; its modules are
[orphans](glossary.md#orphan). `just check` fails on them: `checks.nix` sets
`checkOrphans = "eval"`, so the `module-orphans` check throws while it is
evaluated, which `--no-build` still does.

## `includes` and `enables`

Modules reach other modules by name, never by importing paths.

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

The `enabled` argument holds only the names that were declared, so the
declaration and its use can't drift apart, and the module graph can draw the
link. `just module-graph` draws the graph from `flake.moduleGraph`.

## Impermanence: some hosts wipe `/root` on every boot

A host that includes the `impermanence` category loses everything on `/`
that is not explicitly persisted, at every boot. A host that leaves the
category out keeps a plain persistent root, and its entry point says so.
Darwin has no impermanence. Check the specific host's entry point before
assuming either way. The warning, the `root-blank` prerequisite and the
precautions are in [Wiring a
host](wiring-a-host.md#read-this-first-the-root-wipe).

State that matters has to be declared for persistence with
`persist.persistIfImpermanent` from `flake.lib` (see
[Shared helpers](#shared-helpers-flakelib)).

## Secrets: sops-nix, names only

sops-nix manages secrets (`general-config/system/secrets/`). `secrets.yaml` is
encrypted and **committed on purpose**. Each host decrypts it with its own SSH host key,
converted to an age key. The enrolled hosts are whichever ones `.sops.yaml`
in that folder lists; read that file rather than a count.

The names of the keys are plaintext inside the ciphertext. To answer
"which secrets exist?", run `just read-sops-names`. The recipe prints names
only. **Never use `sops -d` to answer that question:** it prints every value,
and redirecting stderr doesn't stop stdout. The repo has leaked values that
way before. The skill `.agents/skills/secrets-hygiene/SKILL.md` covers all
handling of sops output.

## Home Manager comes through NixOS

[Home Manager](glossary.md#home-manager) runs inside each system
configuration. The flake has no `homeConfigurations`
output and no separate home switch. `just switch` applies the system and Home
Manager together. The whole home config is one module, `elly-home-manager`,
and every host shares it, darwin included. The reasons and the failure modes
are in [Wiring a user and Home Manager](users-and-home-manager.md); the
darwin side is in [Darwin edge cases](darwin.md).

## Less common

### `flake.nix` is a manifest

`flake/flake.nix` declares inputs and imports flake-parts modules; it names
no hosts and lists no modules. flake-parts builds a flake's outputs from
module-system modules ([flake-parts modules](glossary.md#flake-parts-module)),
much as NixOS builds a system from NixOS modules.

`flake.nix` imports `flake-parts.flakeModules.modules`, nix-darwin's flake module, and
`(inputs.dirs-as-categories.lib.tree ./modules)`, among others. The flake-parts
`touchup` module only turns off the `formatter` output. The
[dirs-as-categories](glossary.md#dirs-as-categories) input uses `import-tree`
to read every `.nix` file under `flake/modules/`, and fills in
`flake.modules.<class>.<name>` from those files. The hosts are declared in
`flake/modules/host-config/hosts.nix`.

Two path rules decide which files are read at all:

- Paths containing `/_` are skipped, which is why `flake/modules/_lib/` and
  `general-config/impermanence/_disko/` are not modules.
- Files that don't end in `.nix` are ignored, so a module's config files can
  sit beside it (for example
  `packages-config/development/langs/python-dev/!dotfiles/`).

### Files that are not module files

dirs-as-categories loads a file as a **plain flake-parts module** when its
function asks for `config` or `withSystem`, or when it has no class key.
`hosts.nix`, `checks.nix`, `invariants.nix`, `dev-shell.nix` and `lib.nix`
are written that way on purpose, and they carry no dirs-as-categories header
comment. `defaults.nix` is never a module file and has no module name. Any
class keys in it (`nixos`, `homeManager`, `darwin`) apply whenever anything in
its folder is reached. By convention it is also where
`folderIsCategory` is set.

A module file cannot read the flake-parts `config`. Files that need the
flake's own outputs read `inputs.self` instead; `tailnet-hosts.nix` does this
to get the host roster.

### Shared helpers: `flake.lib`

Modules do not import a `lib/` folder by relative path. `flake/modules/lib.nix`
sets `flake.lib` from one file per topic in `modules/_lib/`. A module file
reaches the helpers as `inputs.self.lib`, and a plain flake-parts module as
`config.flake.lib`. The topics are `persist`, `fleet` and `nixpkgs`:

- `persist.persistIfImpermanent` keeps state only on a host that wipes
  `/root`.
- `fleet.tailnetName` turns `nire-<x>` into `ts-<x>`.
- `nixpkgs.config` is the fleet's one `nixpkgs.config` (`allowUnfree`). Hosts
  set it, and perSystem's `pkgs` is built from it.

`flake.lib` is typed `raw`, so only one definition is allowed. A new topic
goes in `_lib/<topic>.nix` plus an entry in `lib.nix`. A second
`flake.lib = …` elsewhere would conflict instead of merging.

## Not checked

- The raw-module refusal and the class-contents check were read from the
  library's `nix/` files and changelog, not run. Running them needs flake
  inputs that the environment this book was written in could not fetch.

## Sources

- `flake/flake.nix`, `flake/modules/lib.nix`, `flake/modules/_lib/fleet.nix`
- `flake/modules/host-config/durandal-configuration.nix`,
  `flake/modules/host-config/hosts.nix`
- `flake/modules/general-config/system/home-manager/enable-home-manager.nix`
- `flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
- `AGENTS.md`, Safety; `.agents/rules/flake-modules.md`,
  `.agents/rules/impermanence.md`, `.agents/rules/secrets.md`;
  `.agents/skills/new-flake-module/SKILL.md`,
  `.agents/skills/secrets-hygiene/SKILL.md`
- [module-files.md](../../wiki/config-structure/module-files.md)
- [architecture.md](../../wiki/config-structure/architecture.md)
- [where-modules-go.md](../../wiki/config-structure/where-modules-go.md)
- [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md)
- [module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md)
- [impermanence-and-secrets.md](../../wiki/config-structure/impermanence-and-secrets.md)
