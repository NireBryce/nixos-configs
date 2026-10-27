# Categories and membership

A category is how a host takes a group of modules by one name. In this tree,
categories are not declared anywhere: they come from the shape of the
folders. This chapter explains the rule, walks through real examples from
`flake/modules/`, and covers how to add a module to a category, how to
create or remove one, and the traps that produce no error.

## The rule

- A folder below an area (`general-config/`, `hardware-config/`,
  `homelab-config/`, `host-config/`, `packages-config/`, `users-config/`)
  is a **category** when **one of its subfolders holds modules**.
- A file directly in the folder can override that: `folderIsCategory = true`
  promotes a flat folder, and `false` keeps a folder of folders plain. By
  convention the setting goes in a `defaults.nix`.
- Including a category includes **every module beneath it, at any depth**,
  nested categories included. A module belongs to the nearest category
  above it.
- The category's name is the folder's name. It shares one namespace with
  every module name.
- A category exists in **every class** (`nixos`, `homeManager`, `darwin`). A
  class's version of the category holds only the modules that have that
  class's key, so it may be empty.
- The areas themselves are not categories. A file placed directly in an
  area belongs to nothing, which is why the host entry points sit there.

Source: [module-files.md](../../wiki/config-structure/module-files.md), Quick
facts; `.agents/rules/flake-modules.md`, "Membership comes from the
directory"; header of `flake/modules/users-config/elly-home-manager.nix`.

## Reading the tree: real examples

**A plain category.** `general-config/boot/` has subfolders `editor/`,
`generations/` and `power-button/`, each holding a module. So `boot` is a
category, and the NixOS hosts include it with one line, `"boot"`.

**A nested category.** `hardware-config/hardware/amd/` has subfolders
`amdcpu/` and `amdgpu/` holding modules, so `amd` is a category. It also
sits inside `hardware`, which is a category too. Both collect `amdcpu` and
`amdgpu`. This overlap is deliberate: it gives a coarse handle and a fine
handle on the same modules.

**A category no host includes whole.** `general-config/desktop-env/` is a
category because its subfolders `kde/` and `jovian/` hold modules. Those two
subfolders hold only files, so they are plain folders, not categories.
Including `desktop-env` would bring in both the workstation session and the
handheld session. Instead, hosts name a single module: durandal and cube
include `"kde-desktop"` and tenacity includes `"jovian"`. Each of those
includes `kde-base` itself.

**A skipped subfolder.** Under `general-config/impermanence/`, the
`_disko/` folder is ignored because its path contains `/_`.
`root-rollback/` is a nested category, since its subfolder `restore-root/`
holds `WARN-impermanence.nix` and `kde-sleepmode.nix`.

**A forced opt-out.** `packages-config/development/langs/python-dev/` has
subfolders `ruff/` and `uv/`, so it would become a category on its own. Its
`defaults.nix` is one line:

```nix
{ folderIsCategory = false; }
```

That keeps it a plain folder inside `development`. Promoting it would not
change which packages any host gets, but it would reorder every host's Home
Manager package list, which changes every hash. Deleting the file would
promote the folder.

**An umbrella.** `homelab-config/homelab/` holds one nested category per
service (`backup`, `containers`, `git-forge`, `monitoring`, …). Cube
includes the whole set with `"homelab"`. Each nested category can still be
included by name on its own.

**Per-host and per-user categories.** `host-config/cube/` is a category
because its subfolders `configuration/`, `hardware/` and `cube-vm/` hold
modules. Only `cube-configuration.nix` includes `"cube"`, so a module placed
there belongs to cube by construction. `users-config/elly/` works the same
way for the account.

**Classes filter what arrives.** `lysithea-configuration.nix` includes
`"system"` under `includes.darwin`. It does not get bluetooth, networking
or KDE Connect, because none of those modules has a `darwin` key. Only
modules with that key arrive.

Source: directory listings under `flake/modules/`;
`flake/modules/host-config/{durandal,cube,tenacity,lysithea}-configuration.nix`;
`flake/modules/packages-config/development/langs/python-dev/defaults.nix`;
`flake/doc/dirsAsCategory.md`, "Things that are load-bearing";
[module-files.md](../../wiki/config-structure/module-files.md), "Why
categories need no shim".

## Seeing membership as data

You don't have to work membership out by hand:

```sh
nix eval --json ./flake#moduleGraph     # categories, modules, classes, includes, enables
just module-graph tree --category homelab
just module-graph hosts                 # which host takes which category
```

`wiki/config-structure/architecture.md` carries a generated diagram of the
top level.

Source: [architecture.md](../../wiki/config-structure/architecture.md),
Quick facts and "The layout at a glance"; `.justfile` (`module-graph`).

## Adding a module to a category

Put the file anywhere under the category's folder. Nothing else needs to
change. Every host that includes the category, or a category above it, gets
the module on its next build. See [Adding a module](adding-a-module.md) for
the file itself.

**To keep a module out of a category, file it outside that category's
tree.** No per-module exclusion exists.

Source: `.agents/rules/flake-modules.md`.

## Creating a category

1. Make the folder, with at least one subfolder holding a module. For a
   flat folder, add a `defaults.nix` containing
   `{ folderIsCategory = true; }` instead.
2. Check the name. The folder name must not match any existing module or
   category, or evaluation stops and names both files. When you split
   modules out into a new folder, the moved file often still has the
   folder's name (`containers/containers.nix`). Rename it to the specific
   thing (`podman.nix`) in the same move (§35 in
   [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)).
3. Make something include it. For the system side, add the name to the
   relevant hosts' `includes.<class>`. For the Home Manager side, add it to
   `users-config/elly-home-manager.nix`. A category that nothing includes
   evaluates cleanly and installs nothing. `nix flake check`'s
   `module-orphans` check reports its modules.
4. Compare the hosts before and after (`just diff <ref>`, or the
   fingerprints). Promoting an existing folder can reorder package lists.
5. Run `just wiki-gen`. Give the category a page under
   `wiki/config-structure/categories/` if it is one any host might include.

Source: `.agents/skills/new-flake-module/SKILL.md`, "Categories come from
folders" and "Wiki sync"; `.agents/skills/new-package/SKILL.md`, "The
shape".

## Removing a category

- Remove its name from every `includes` list that mentions it. Any list you
  miss makes evaluation stop with an unknown-name error, so the mistake is
  loud.
- If what you are removing is the folder's *last* subfolder of modules, the
  folder quietly stops being a category. Its modules then belong to the
  nearest category above it, which may be one that more hosts include.
  Unverified: no doc describes this case directly. It follows from the
  rules above. Check it with `nix eval --json ./flake#moduleGraph`.
- Run `just diff` across any removal. Removing a module can remove something
  another module had switched on (§7).
- Update the category's page and run `just wiki-gen`.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
Quick facts ("unknown names in `includes`/`enables` stop evaluation");
`AGENTS.md`, "Verify refactors by fingerprint".

## Including categories from a host

Hosts list categories by name in their entry point:

```nix
{
    includes.nixos = [
        "tenacity"      # this host's own directory
        "boot"
        "impermanence"
        "hardware"
        "nix"
        "shell-config"
        "system"
        "jovian"        # one module, not the desktop-env category
        "development"
        # …
        "elly"
    ];
}
```

(Shortened from `tenacity-configuration.nix`, which comments on why each
line is or isn't present, including why `peripherals` and `containers` are
absent.)

The entry points are the place to record *why* a host leaves a category
out. `cube-configuration.nix` explains why it has no `impermanence`, and
`durandal-configuration.nix` explains why it has no `virtualization`.

Source: `flake/modules/host-config/tenacity-configuration.nix`,
`cube-configuration.nix`, `durandal-configuration.nix`.

## What `wiki/config-structure/categories/` documents

There is one page per category that a host might include: what is in it,
why it is shaped that way, and its traps. The index,
[`categories/00-INDEX.md`](../../wiki/config-structure/categories/00-INDEX.md),
has generated tables, one for system categories and one for the homelab set.
**Imported by** is the one column written by hand, and `just wiki-gen` keeps
it when it regenerates the tables. The `packages-config/*` subcategories
and the per-host bundles are deliberately left out. The first are
self-explanatory wrappers, and the second are covered by
[`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md).

Source: `wiki/config-structure/categories/00-INDEX.md`.

## Traps

- **A new subfolder can promote its parent.** Adding the first subfolder of
  modules to a flat folder turns the folder into a category. Its name is
  then reserved, and package order can shift.
- **Never add an `intel` sibling under `hardware-config/hardware/`.** A
  category includes everything beneath it, so the AMD hosts that include
  `hardware` would get it too. An Intel host skips `hardware` and imports
  the exact `nixos-hardware` module from its own hardware file.
- **Categories versus containers and VMs.** `virtualization` means only the
  libvirt VM category. Podman and distrobox are `containers`. Both are
  nested under `homelab`, and the category index lists which hosts include
  them.
- **Leaving a category out produces no error.** Check
  [`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md)'s table, or the entry
  point itself, before saying a host has something.

Source: `.agents/skills/new-host-config/SKILL.md`, "Shape decisions";
[architecture.md](../../wiki/config-structure/architecture.md), "Related,
easy to get backwards"; `.agents/skills/new-flake-module/SKILL.md`.
