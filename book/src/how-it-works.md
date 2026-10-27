# How the non-obvious pieces work

This chapter covers the parts of this flake that act differently from what
a reader who knows NixOS and flake-parts would assume. Each section follows
the same pattern: what you'd expect, what actually happens, and why it
matters. Read it before you edit anything under `flake/modules/`. The later
chapters assume you know it.

## `flake.nix` is a manifest, not a host list

**What you'd expect.** A `flake.nix` that lists each host and imports its
modules by path.

**What actually happens.** `flake/flake.nix` imports three flake-parts
modules: `flake-parts.flakeModules.modules`, nix-darwin's flake module, and
`(inputs.dirs-as-categories.lib.tree ./modules)`. It also imports `touchup`,
which only turns off the `formatter` output. The `dirs-as-categories` input
uses `import-tree` to read every `.nix` file under `flake/modules/`. From
those files it fills in `flake.modules.<class>.<name>`. The hosts themselves
are declared in `flake/modules/host-config/hosts.nix`.

**Why it matters.** File paths mean nothing to Nix directly. What a file is
for depends on its *filename* and on the *folder* it sits in, as the next
sections explain. Paths containing `/_` are skipped, which is why
`flake/modules/_lib/` and `general-config/impermanence/_disko/` are not
modules. Files that don't end in `.nix` are ignored, so a module's config
files can sit beside it (for example
`packages-config/development/langs/python-dev/!dotfiles/`).

Source: `flake/flake.nix`;
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"import-tree".

## A module's name is its filename

**What you'd expect.** Each module declares its own name, as in
`flake.modules.nixos.gaming = …`.

**What actually happens.** A module file never names itself.
dirs-as-categories names it after its file, so `gaming.nix` becomes the
module `gaming`, and a `default.nix` takes its folder's name. Earlier,
every file worked out its own name with boilerplate
(`lib.removeSuffix ".nix" (baseNameOf __curPos.file)`). That boilerplate is
gone.

**Why it matters.**

- **Renaming a file renames the module.** Anything that refers to the module
  by name (`includes`, `enables`, `hosts.nix`) then fails to evaluate,
  loudly. Membership survives a rename, because it comes from the folder.
- **Names share one namespace across the whole tree**, modules and
  categories alike. If two files have the same name, or a module has the
  same name as a category, evaluation stops and names both files. Before
  dirs-as-categories, such a pair merged silently. Durandal's old `boot.nix`
  merging with the `boot` category is the recorded example (§34 in
  [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)). This is
  why host-specific files carry a host suffix (`boot-durandal.nix`,
  `hardware-cube.nix`).

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Why the name comes from the filename"; `.agents/skills/new-flake-module/SKILL.md`.

## The module file shape

**What you'd expect.** A NixOS module (`{ config, pkgs, ... }: { … }`).

**What actually happens.** A module file is an attribute set whose keys are
*classes*. Each value is the module for that class:

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
That is the main thing flake-parts offers this repo: one feature's NixOS
half and Home Manager half can live in one file.

The file may instead be a function of only `lib` and/or `inputs` that
returns such a set (`{ lib, ... }: { nixos = …; }`). `pkgs` and `config`
belong in the **inner**, per-class module's arguments. A `pkgs` taken from
anywhere else would be perSystem's, which has no `nixpkgs.config` and so
silently loses `allowUnfree`.

**Why it matters.** Two failures here give misleading errors:

- **A raw NixOS module dropped under `modules/`** (for example
  `nixos-generate-config` output) asks for `config`. It therefore gets loaded
  as a flake-parts module, and evaluation dies with `infinite recursion
  encountered`, blaming `modulesPath`. Nothing in that error points at the
  real cause. The fix is to wrap it: `{ nixos = <the original module>; }`.
- **A class key can be valid and still wrong.** `jq` and `bitwarden` once
  declared `nixos` bodies full of `home.packages`.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"What a module file is";
[module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md),
"The header"; `.agents/skills/new-flake-module/SKILL.md`, "Raw NixOS modules"
and "Classes".

## Categories are folders

**What you'd expect.** Some list somewhere saying which modules make up the
"desktop" or "base" profile.

**What actually happens.** A folder below an area (`general-config/`,
`packages-config/`, …) is a **category** when one of its subfolders holds
modules. A file directly in the folder can also force the question with
`folderIsCategory`. Including a category includes every module beneath it,
at any depth, nested categories too. Nobody writes the membership list down;
it comes from where files sit.

**Why it matters.** Choosing a directory is choosing which hosts get the
module. Shared things stay optional because a host can leave a category out:
nothing in this repo declares an `mkEnableOption` for that purpose. The
[categories chapter](categories.md) covers the details and the traps.

Source: [architecture.md](../../wiki/config-structure/architecture.md),
"Quick facts"; `.agents/rules/flake-modules.md`.

## Hosts list categories with `includes`

**What you'd expect.** A host file with an `imports = [ ./a.nix ./b.nix ];`
list.

**What actually happens.** Each host has an *entry point*,
`host-config/<host>-configuration.nix`. It is itself a module file, and it
lists categories **by name**:

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

(Shortened from `durandal-configuration.nix`, which comments on every line.)
`hosts.nix` then turns each entry point into a machine:
`mkHost "x86_64-linux" config.flake.modules.nixos.durandal-configuration`.

Entry points sit **directly** in `host-config/` (and `users-config/`, for
`elly-home-manager.nix`). A file there is outside every category, so the
host definition doesn't become a member of anything. If you put an ordinary
module there, no host receives it.

**Why it matters.** If a name in `includes` doesn't exist, evaluation stops.
That is the safe failure. The silent one is the opposite case: a category no
host includes evaluates fine and installs nothing. The `module-orphans`
flake check is there to catch that.

Source: `flake/modules/host-config/durandal-configuration.nix`,
`flake/modules/host-config/hosts.nix`;
[where-modules-go.md](../../wiki/config-structure/where-modules-go.md),
"Not a module: entry points".

## `includes` and `enables`

**What you'd expect.** A module imports whatever it needs by path.

**What actually happens.** There are two name-based mechanisms:

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

**Why it matters.** `enabled` holds only the names that were declared, so
the declaration and its use can't drift apart, and the module graph can
draw the link. `nix eval --json ./flake#moduleGraph` publishes the whole
graph (categories, modules, classes, `includes`, `enables`) as data, and
`just module-graph` draws it.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Reaching other modules"; `flake/modules/general-config/system/home-manager/enable-home-manager.nix`.

## Files that are not modules

**What you'd expect.** Every `.nix` file under `modules/` is a module.

**What actually happens.** If a function asks for `config` or `withSystem`,
or a file has no class key, dirs-as-categories loads it as a **plain
flake-parts module**. `hosts.nix`, `checks.nix`, `invariants.nix`,
`dev-shell.nix` and `lib.nix` are written that way on purpose, and they
carry no dirs-as-categories header comment. `defaults.nix` is never a
module: its class parts apply whenever anything in its folder is reached,
and it is where `folderIsCategory` goes.

**Why it matters.** A module file can no longer read the flake-parts
`config`. Files that need the flake's own outputs read `inputs.self`
instead. `tailnet-hosts.nix` does this to get the host roster. A side
effect is that the old trap of having two different `config`s in one file
is gone.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Files that are not modules" and "Why some files keep `{ lib, inputs, ... }:`".

## Shared helpers: `flake.lib`

**What you'd expect.** A `lib/` folder that modules import by relative path.

**What actually happens.** `flake/modules/lib.nix` sets `flake.lib` from
one file per topic in `modules/_lib/`. The underscore keeps the tree from
treating those files as modules. A module file reaches the helpers as
`inputs.self.lib`, and a plain flake-parts module as `config.flake.lib`. The
current topics are `persist` and `fleet`:

- `persist.persistIfImpermanent` keeps state only on a host that wipes
  `/root`.
- `fleet.tailnetName` turns `nire-<x>` into `ts-<x>`.

**Why it matters.** `flake.lib` is typed `raw`, so only one definition is
allowed. A new topic goes in `_lib/<topic>.nix` plus an entry in `lib.nix`.
A second `flake.lib = …` elsewhere would conflict, not merge.

Source: `flake/modules/lib.nix`, `flake/modules/_lib/fleet.nix`;
[module-files.md](../../wiki/config-structure/module-files.md), "Shared
helpers"; commit `aca2a74`.

## Impermanence: some hosts wipe `/root` on every boot

**What you'd expect.** A NixOS root filesystem that keeps what was written
to it.

**What actually happens.** On every boot,
`general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
runs a `restore-root` unit in the initrd. The unit deletes the btrfs
subvolume that `/` lives on and replaces it with a snapshot of an empty
subvolume, `root-blank`. What survives is `/nix`, `/home`, `/var/log`, and
the paths listed for `/persist`. Hosts get this only through the
`impermanence` category. A host that includes it wipes `/root`; a host that leaves it out keeps a
plain persistent root (its entry point says so). Darwin has no impermanence.
Check the specific host's entry point rather than assuming.

**Why it matters.**

- Never install this config wholesale. On a disk shaped like the one the
  module describes, it deletes `/`.
- `root-blank` must already exist. No host's config creates it, and without
  it the rollback deletes `/root` and then cannot replace it.
- Any state that matters has to be declared for persistence. Use
  `persist.persistIfImpermanent` from `flake.lib`.
- For changes near boot, prefer `just boot` over `just switch`, so the
  running generation stays in the boot menu as a fallback.
- The module explains its reasons at length. Read the whole file before you
  touch anything near it.

Source: `flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
header; `AGENTS.md`, Safety; `.agents/rules/impermanence.md`;
[impermanence-and-secrets.md](../../wiki/config-structure/impermanence-and-secrets.md).

## Secrets: sops-nix, names only

**What you'd expect.** Secrets kept out of the repository.

**What actually happens.** Secrets are managed with sops-nix
(`general-config/system/secrets/`). `secrets.yaml` is encrypted and
**committed on purpose**. Each host decrypts it with its own SSH host key,
converted to an age key. The hosts enrolled are whichever ones
`.sops.yaml` in that folder lists; read that file rather than a count.

**Why it matters.** The *names* of the keys are plaintext inside the
ciphertext. To answer "which secrets exist?", run `just read-sops-names`. It
prints names only and cannot print a value. Never use `sops -d` to answer
that question: it prints every value, and redirecting stderr doesn't stop
stdout. The repo has leaked values that way before. The skill
`.agents/skills/secrets-hygiene/SKILL.md` covers all handling of sops
output.

Source: `AGENTS.md`, Safety; `.agents/rules/secrets.md`;
[impermanence-and-secrets.md](../../wiki/config-structure/impermanence-and-secrets.md),
"Secrets".

## Home Manager comes through NixOS

There is no `homeConfigurations` output and no separate home switch.
`just switch` applies the system and Home Manager together. The whole home
config is one module, `elly-home-manager`, and every host shares it,
darwin included. The reasons and the failure modes are in
[Wiring a user and Home Manager](users-and-home-manager.md); the darwin side
is in [Darwin edge cases](darwin.md).

Source: [architecture.md](../../wiki/config-structure/architecture.md),
"Home Manager integration".
