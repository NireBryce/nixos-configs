# Categories and membership

A **category** is a named group of modules that a host takes in one line.
No file declares categories; they come from the shape of the folders. Below
are the rule, real examples from `flake/modules/`, the procedures for adding
a module to a category and for creating or removing one, and the traps that
produce no error. Unfamiliar terms are in the [glossary](glossary.md).

## The rule

- A folder below an [area](glossary.md#area) (`general-config/`,
  `hardware-config/`, `homelab-config/`, `host-config/`, `packages-config/`,
  `users-config/`) is a category when **one of its subfolders holds
  modules**.
- A file directly in the folder can override that rule:
  `folderIsCategory = true` promotes a flat folder, and `false` keeps a
  folder of folders plain. By convention the setting goes in a
  `defaults.nix`.
- Including a category includes **every module beneath it, at any depth**,
  nested categories included. A module belongs to the nearest category
  above it.
- The category's name is the folder's name. Category names share one
  namespace with every module name.
- A category exists in **every [module class](glossary.md#module-class)**
  (`nixos`, `homeManager`, `darwin`); a class is the kind of configuration a
  module targets. A class's version of the category holds only the modules
  that have that class's key, so it may be empty.
- The areas themselves are not categories. A file placed directly in an
  area belongs to nothing, so the host entry points sit there.

Source: [module-files.md](../../wiki/config-structure/module-files.md), Quick
facts; `.agents/rules/flake-modules.md`, "Membership comes from the
directory"; header of `flake/modules/users-config/elly-home-manager.nix`.

## Reading the tree: real examples

`general-config/boot/` is a plain category. Its subfolders `editor/`,
`generations/` and `power-button/` each hold a module, so `boot` is a
category, and the NixOS hosts include it with one line, `"boot"`.

`hardware-config/hardware/amd/` is a nested category. Its subfolders
`amdcpu/` and `amdgpu/` hold modules, so `amd` is a category. `amd` also
sits inside `hardware`, which is a category too, and both collect `amdcpu`
and `amdgpu`. The overlap gives a coarse handle and a fine handle on the
same modules.

`general-config/desktop-env/` is a category that no host includes whole. It
is a category because its subfolders `kde/` and `jovian/` hold modules.
`kde/` and `jovian/` hold only files, so they are plain folders. Including
`desktop-env` would bring in both the workstation session and the handheld
session. Each host names a single module instead: `"kde-desktop"` for the
workstation session or `"jovian"` for the handheld one (check the host's
entry point for which). Both modules include `kde-base` themselves.

`general-config/impermanence/` shows a skipped subfolder. Its `_disko/`
folder is ignored because the path contains `/_`. `root-rollback/` is a
nested category, since its subfolder `restore-root/` holds
`WARN-impermanence.nix` and `kde-sleepmode.nix`.

`packages-config/development/langs/python-dev/` shows a forced opt-out. Its
subfolders `ruff/` and `uv/` would make it a category on its own, but its
`defaults.nix` is one line:

```nix
{ folderIsCategory = false; }
```

The line keeps `python-dev` a plain folder inside `development`. Promoting
it would not change which packages any host gets. It would reorder every
host's Home Manager package list, though, and that changes every hash.
Deleting the file would promote the folder.

`homelab-config/homelab/` is an umbrella. It holds one nested category per
service (`backup`, `containers`, `git-forge`, `monitoring`, …). Cube includes
the whole set with `"homelab"`, and each nested category can still be
included by name on its own.

Per-host and per-user categories follow the same rule. `host-config/cube/`
is a category because its subfolders `configuration/`, `hardware/` and
`cube-vm/` hold modules. Only `cube-configuration.nix` includes `"cube"`, so
a module placed there belongs to cube by construction. `users-config/elly/`
works the same way for the account.

Classes filter what arrives. `lysithea-configuration.nix`, the darwin
example, includes `"system"` under `includes.darwin`. It does not get
bluetooth, networking or KDE Connect, because none of those modules has a
`darwin` key. Only modules with that key arrive.

Source: directory listings under `flake/modules/`;
`flake/modules/host-config/{durandal,cube,tenacity,lysithea}-configuration.nix`;
`flake/modules/packages-config/development/langs/python-dev/defaults.nix`;
`flake/doc/dirsAsCategory.md`, "Things that are load-bearing";
[module-files.md](../../wiki/config-structure/module-files.md), "Why
categories need no shim".

## Seeing membership as data

The flake publishes membership as data, so you don't have to work it out by
hand:

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

1. Put the file anywhere under the category's folder. Nothing else needs to
   change: every host that includes the category, or a category above it,
   gets the module on its next build. See [Adding a module](adding-a-module.md)
   for the file itself.
2. Check the result with `just module-graph tree --category <name>`.

To keep a module out of a category, file it outside that category's tree.
No per-module exclusion exists.

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
3. Make something include the category. For the system side, add the name
   to the relevant hosts' `includes.<class>`. For the Home Manager side, add
   it to `users-config/elly-home-manager.nix`. A category that nothing
   includes evaluates without error and installs nothing. Its modules are
   [orphans](glossary.md#orphan); `just modules` fails and names them
   (`just check` does not, because it runs with `--no-build`).
4. Compare the hosts before and after (`just diff <ref>`, or the
   fingerprints). Promoting an existing folder can reorder package lists.
5. Run `just wiki-gen`. Give the category a page under
   `wiki/config-structure/categories/` if it is one any host might include.

Source: `.agents/skills/new-flake-module/SKILL.md`, "Categories come from
folders" and "Wiki sync"; `.agents/skills/new-package/SKILL.md`, "The
shape".

## Removing a category

1. Remove its name from every `includes` list that mentions it. Any list you
   miss makes evaluation stop with an unknown-name error, so the mistake is
   loud.
2. Check what the folder becomes. If you are removing the folder's *last*
   subfolder of modules, the folder stops being a category without any
   message. Its
   modules then belong to the nearest category above it, which may be one
   that more hosts include. Unverified: no doc describes this case directly.
   It follows from the rules above. Check it with
   `nix eval --json ./flake#moduleGraph`.
3. Run `just diff <ref>` across any removal. Removing a module can remove
   something another module had switched on (§7).
4. Update the category's page and run `just wiki-gen`.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
Quick facts ("unknown names in `includes`/`enables` stop evaluation");
`AGENTS.md`, "Verify refactors by fingerprint".

## Including categories from a host

Hosts list categories by name in their
[entry point](glossary.md#entry-point), `host-config/<host>-configuration.nix`:

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

(Shortened from the example host's `tenacity-configuration.nix`, which
comments on why each line is or isn't present, including why `peripherals`
and `containers` are absent.)

Record in the entry point *why* a host leaves a category out.
`cube-configuration.nix` explains why it has no `impermanence`, and
`durandal-configuration.nix` explains why it has no `virtualization`.

Source: `flake/modules/host-config/tenacity-configuration.nix`,
`cube-configuration.nix`, `durandal-configuration.nix`.

## What `wiki/config-structure/categories/` documents

The wiki has one page per category that a host might include: what is in
the category, why it is shaped that way, and its traps. The index,
[`categories/00-INDEX.md`](../../wiki/config-structure/categories/00-INDEX.md),
has generated tables, one for system categories and one for the homelab set.
**Imported by** is the one column written by hand, and `just wiki-gen` keeps
that column when it regenerates the tables. The index leaves out two groups:

- the `packages-config/*` subcategories, which are self-explanatory
  wrappers;
- the per-host bundles, which
  [`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md) covers.

Source: `wiki/config-structure/categories/00-INDEX.md`.

## Traps

- A new subfolder can promote its parent. Adding the first subfolder of
  modules to a flat folder turns the folder into a category. The folder's
  name is then reserved, and package order can shift.
- Never add an `intel` sibling under `hardware-config/hardware/`. A
  category includes everything beneath it, so the AMD hosts that include
  `hardware` would get the Intel module too. An Intel host skips `hardware`
  and imports the exact `nixos-hardware` module from its own hardware file.
- The `virtualization` and `containers` categories are easy to confuse.
  `virtualization` means only the libvirt VM category. Podman and distrobox are `containers`.
  Both categories are nested under `homelab`, and the category index lists
  which hosts include them.
- Leaving a category out produces no error. Check
  [`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md)'s table, or the entry
  point itself, before saying a host has something.

Source: `.agents/skills/new-host-config/SKILL.md`, "Shape decisions";
[architecture.md](../../wiki/config-structure/architecture.md), "Related,
easy to get backwards"; `.agents/skills/new-flake-module/SKILL.md`.
