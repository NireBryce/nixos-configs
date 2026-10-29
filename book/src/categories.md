# Categories and membership

A [category](glossary.md#category) comes from the shape of the folders; no
file declares one. This chapter gives the rule, the procedures for adding a
module to a category and for creating, removing and including one, real
examples from `flake/modules/`, and the traps that produce no error.

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
  (`nixos`, `homeManager`, `darwin`). A class's version of the category holds
  only the modules that have that class's key, so it may be empty.
- The areas themselves are not categories. A file placed directly in an
  area belongs to nothing, so the host entry points sit there.

## Seeing membership as data

```sh
nix eval --json ./flake#moduleGraph     # categories, modules, classes, includes, enables
just module-graph tree --category homelab
just module-graph hosts                 # which host takes which category
```

`wiki/config-structure/architecture.md` carries a generated diagram of the
top level.

## Adding a module to a category

1. Put the file anywhere under the category's folder. Every host that
   includes the category, or a category above it, gets the module on its next
   build. [Adding a module](adding-a-module.md) covers the file itself.
2. Check the result with `just module-graph tree --category <name>`.

To keep a module out of a category, file it outside that category's tree.
No per-module exclusion exists.

## Creating a category

1. Make the folder, with at least one subfolder holding a module. For a
   flat folder, add a `defaults.nix` containing
   `{ folderIsCategory = true; }` instead.
2. Check the name. The folder name must not match any existing module or
   category, or evaluation stops and names both files. When you split
   modules out into a new folder, the moved file often still has the
   folder's name (`containers/containers.nix`). Rename it to the specific
   thing (`podman.nix`) in the same move ([lesson
   35](../../wiki/agent-lessons-learned/35-collision-a-third-time.md)).
3. Make something include the category. For the system side, add the name
   to the relevant hosts' `includes.<class>`. For the Home Manager side, add
   it to `users-config/elly-home-manager.nix`. A category that nothing
   includes evaluates without error and installs nothing. Its modules are
   [orphans](glossary.md#orphan); `just modules` fails and names them
   (`just check` does not, because it runs with `--no-build`).
4. Compare the hosts before and after (`just diff <ref>`, or the
   fingerprints). Promoting an existing folder can reorder package lists.
5. Run `just wiki-gen`. Give the category a page under
   `wiki/config-structure/categories/` if any host might include it.

## Removing a category

1. Remove its name from every `includes` list that mentions it. A list you
   miss makes evaluation stop with an unknown-name error.
2. Check what the folder becomes. If you are removing the folder's *last*
   subfolder of modules, the folder stops being a category without any
   message. Its modules then belong to the nearest category above it, which
   may be one that more hosts include. Check with
   `nix eval --json ./flake#moduleGraph`.
3. Run `just diff <ref>` across any removal. Removing a module can remove
   something another module had switched on ([lesson
   7](../../wiki/agent-lessons-learned/7-cross-module-side-effects.md)).
4. Update the category's page and run `just wiki-gen`.

## Including categories from a host

Hosts list categories by name in their [entry point](glossary.md#entry-point),
`host-config/<host>-configuration.nix`. The full example is in [Wiring a
host](wiring-a-host.md#step-2-write-the-entry-point).

Record in the entry point *why* a host leaves a category out.
`cube-configuration.nix` explains why it has no `impermanence`, and
`durandal-configuration.nix` explains why it has no `virtualization`.

## Worked examples

**Plain category.** `general-config/boot/` has subfolders `editor/`,
`generations/` and `power-button/`, each holding a module. `boot` is a
category, and the NixOS hosts include it with `"boot"`.

**Nested overlap.** `hardware-config/hardware/amd/` is a category because
its subfolders `amdcpu/` and `amdgpu/` hold modules. `amd` also sits inside
`hardware`, which is a category too, and both collect `amdcpu` and `amdgpu`.
The overlap gives a coarse handle and a fine handle on the same modules.

**A category no host includes whole.** `general-config/desktop-env/` is a
category because its subfolders `kde/` and `jovian/` hold modules. Including
it would bring in both the workstation session and the handheld session.
Each host names a single module instead: `"kde-desktop"` or `"jovian"`
(check the host's entry point for which). Both include `kde-base`
themselves.

**Forced opt-out.** `packages-config/development/langs/python-dev/` has
subfolders `ruff/` and `uv/` that would make it a category. Its
`defaults.nix` is one line:

```nix
{ folderIsCategory = false; }
```

The line keeps `python-dev` a plain folder inside `development`. Promoting it
would not change which packages any host gets, but it would reorder every
host's Home Manager package list and change every hash. Deleting the file
would promote the folder.

**Classes filter what arrives.** `lysithea-configuration.nix`, the darwin
host, includes `"system"` under `includes.darwin`. It gets no bluetooth,
networking or KDE Connect, because none of those modules has a `darwin` key.

Three smaller cases follow the same rule. A path containing `/_` is skipped
(`general-config/impermanence/_disko/`). `homelab-config/homelab/` is an
umbrella with one nested category per service, and cube includes all of them
with `"homelab"`. `host-config/cube/` and `users-config/elly/` are categories
that only their own entry point includes, so a module placed there belongs to
that host or user by construction.

## What `wiki/config-structure/categories/` documents

The wiki has one page per category that a host might include: what is in
the category, why it is shaped that way, and its traps. The index,
[`categories/00-INDEX.md`](../../wiki/config-structure/categories/00-INDEX.md),
has generated tables, one for system categories and one for the homelab set.
**Imported by** is the one column written by hand, and `just wiki-gen` keeps
that column when it regenerates the tables. The index leaves out the
`packages-config/*` subcategories, which are self-explanatory wrappers, and
the per-host bundles, which [`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md)
covers.

## Traps

- A new subfolder can promote its parent. Adding the first subfolder of
  modules to a flat folder turns the folder into a category. The folder's
  name is then reserved, and package order can shift.
- Never add an `intel` sibling under `hardware-config/hardware/`. A
  category includes everything beneath it, so the AMD hosts that include
  `hardware` would get the Intel module too. An Intel host skips `hardware`
  and imports the exact `nixos-hardware` module from its own hardware file.
- `virtualization` means only the libvirt VM category. Podman and distrobox
  are `containers`. Both are nested under `homelab`, and the category index
  lists which hosts include them.
- Leaving a category out produces no error. Check
  [`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md)'s table, or the entry
  point itself, before saying a host has something.

## Not checked

- Removing a folder's last module subfolder demotes it from a category. This
  follows from the rule and no doc describes it directly.

## Sources

- `flake/modules/host-config/{durandal,cube,tenacity,lysithea}-configuration.nix`
- `flake/modules/packages-config/development/langs/python-dev/defaults.nix`
- `flake/modules/users-config/elly-home-manager.nix`
- `flake/doc/dirsAsCategory.md`, "Things that are load-bearing"
- `.agents/rules/flake-modules.md`; `.agents/skills/new-flake-module/SKILL.md`,
  `.agents/skills/new-host-config/SKILL.md`, `.agents/skills/new-package/SKILL.md`
- `.justfile` (`module-graph`)
- [module-files.md](../../wiki/config-structure/module-files.md)
- [architecture.md](../../wiki/config-structure/architecture.md)
- [categories/00-INDEX.md](../../wiki/config-structure/categories/00-INDEX.md)
- [wiki/fleet/hosts.md](../../wiki/fleet/hosts.md)
