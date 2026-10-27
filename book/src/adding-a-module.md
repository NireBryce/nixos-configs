# Adding a module

This chapter covers creating any module under `flake/modules/`: choosing
where it goes, naming it, writing it in the house style, and proving it is
wired in. The same rules apply to renaming or moving a module, since in this
tree a rename changes the module's name and a move can change which hosts
get it. Packages follow the same rules, plus some of their own. See
[Adding a package](adding-a-package.md).

## Step 1: decide where it goes

Location decides membership: a module reaches whatever hosts include the
category above it. There are three places:

```text
Is it about one person's account (identity, dotfiles, HM settings)?
  yes -> users-config/<user>/<group>/
  no  -> Is it about one machine (its hardware, its fixes, what only it runs)?
           yes -> host-config/<host>/<group>/
           no  -> general-config/<subject>/…  hardware-config/…
                  homelab-config/homelab/…    or  packages-config/<kind>/…
```

- **Shared** (`general-config/`, `hardware-config/`, `homelab-config/`,
  `packages-config/`) is for anything more than one host could want, even
  if only one host takes it today. A host opts in by including the category.
- **Host-specific** (`host-config/<host>/`) is a category named after the
  host, and only that host's entry point includes it. Put things here that
  only make sense on one machine: its hardware configuration, its
  bootloader, its `stateVersion`, firmware workarounds.
- **User-specific** (`users-config/<user>/`) is a category carrying both
  halves of an account: the NixOS user account and the Home Manager
  settings. See [Wiring a user and Home Manager](users-and-home-manager.md).

**The tie-breaker.** If you can't decide between shared and host-specific,
ask what would happen if a second host included the category the module
would land in. If the answer is "that host now runs something it
shouldn't" (a VM, a firewall rule, a machine-specific fix), the module is
host-specific (§38 in
[agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)).

**Worked example.** `virtualization-cube.nix` defines the `forge-runner` VM
that only cube runs. It used to sit in the shared `virtualization`
category, and a collector rule kept it out of that category's own imports.
When that rule went away, the file moved to
`host-config/cube/cube-vm/`. Now "cube only" follows from where the file
is, instead of being a quirk someone has to remember.

Source: [where-modules-go.md](../../wiki/config-structure/where-modules-go.md),
"Deciding" and "Worked example"; current location of
`flake/modules/host-config/cube/cube-vm/virtualization-cube.nix`.

## Step 2: name it

A module's name is its filename. Modules and categories share one
namespace across the whole tree and across classes.

- **Suffix anything host-specific with the host**: `boot-cube.nix`,
  `hardware-tenacity.nix`, `nixpkgs-stateVersion-durandal.nix`.
- **Prefix anything user-specific with the user** where the name would
  otherwise be generic: `elly-git.nix`, `elly-user.nix`.
- **Name the file after the specific thing**, not after the category it
  sits in. A `containers/containers.nix` would collide with its own
  category, so it is `podman.nix` (§35). This happened more than once before
  evaluation began refusing it.
- A name that is unique anyway (`b550-suspend-fix.nix`) needs no suffix.
- **`default.nix` takes its folder's name**, and `defaults.nix` is never a
  module. `just add-module` refuses both.

Source: [where-modules-go.md](../../wiki/config-structure/where-modules-go.md),
"Naming"; `.agents/skills/new-flake-module/SKILL.md`, "Names share one
namespace".

## Step 3: write it

The scaffolder writes the correct shape and stages the file:

```sh
just add-module nixos general-config/system/my-thing/my-thing.nix "one-line description"
```

The class is `nixos`, `homeManager` or `darwin`. The path is relative to
`flake/modules/` and must end in `.nix` inside an existing category. The
command refuses an unknown class, a path outside every category,
`default.nix` or `defaults.nix`, and a name that a module or category
already uses. It writes:

```nix
# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = _: {
        # summary: one-line description
    };
}
```

When you fill it in, keep the house style. These rules are deliberate, not
cleanup targets:

- **Arguments in the right place.** `lib` and `inputs` go in the outer list,
  and only if the file uses them, because deadnix fails on an unused one.
  `pkgs` and `config` go in the inner class lambda (replace `_:` with
  `{ pkgs, config, ... }:`). There is no outer `config`.
- **Four-space indent**, with opening brackets on the same line as whatever
  opens them.
- **Aligned `=` columns** for runs of related assignments. Match the
  surrounding block. This alignment is why `nix fmt` is not wired up.
- **Comments wrap at 80 columns plus the line's indent.** `just
  comment-wrap` reports violations. Keep `# summary:` to one line; tighten
  it rather than wrap it.
- **One `# summary:` per module.** In `packages-config/` it is
  `# package summary:`.
- **Put the reasoning next to the option it explains**, inside the body.
- **`#` inside a `''` string is shell text** and ends up verbatim in the
  generated file. Notes for the person editing the `.nix` go above the
  string.
- Look for an existing `programs.*` integration before writing one by hand.

Source: `.agents/skills/new-flake-module/SKILL.md`, "Scaffolder" and "The
shape"; `flake/scripts/modules.py` (`add`, `BOILERPLATE`);
[module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md);
`.agents/rules/flake-modules.md`, Conventions.

## Step 4: `git add` before `nix eval`

A flake inside a git repository ignores untracked files. A new module that
hasn't been `git add`ed **does not exist** as far as Nix is concerned, and
nothing reports that. `just add-module` stages the file for you. If you
created the file by hand, stage it yourself:

```sh
git add flake/modules/general-config/system/my-thing/my-thing.nix
just modules     # reports untracked .nix files and graph drift
just check       # evaluates every host; fails on an orphan (module-orphans)
```

When iterating, force a real toplevel. A cheap attribute can resolve while
something else is broken:

```sh
cd flake
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
```

Source: `AGENTS.md`, "Working in this repo" and "Commands";
`.agents/rules/flake-modules.md`.

## Step 5: make sure something reaches it

A module inside a category reaches every host that includes that category.
If no host includes the category, the module is an **orphan**: it evaluates
and installs nothing. The `module-orphans` check in `nix flake check`
reports it. If a host should take the module on its own, without the rest
of the category, name it in an `includes` list directly, as the hosts do
with `kde-desktop`.

Also check whether your new folder has turned its parent into a category.
See [Categories and membership](categories.md).

Source: [module-files.md](../../wiki/config-structure/module-files.md),
Quick facts; `.agents/skills/new-flake-module/SKILL.md`, "Categories come
from folders".

## Renaming or moving a module

- **A rename renames the module.** Membership follows the folder, so it
  survives. References by name (`includes`, `enables`, `hosts.nix`) break,
  but loudly. Fix them in the same change.
- **Leave the old name somewhere greppable.** When a rename makes the old
  name impossible to find, add a one-line comment on the declaration that
  contains the old string. `boot-durandal.nix` and
  `enable-home-manager.nix` do this.
- **A move can change which hosts get the module.** Moving a file to another
  category changes its hosts. Moving it into a new subfolder can promote the
  parent folder to a category.
- **Comments that record a bug stay.** If a change strands such a comment,
  move it to a `history` section at the bottom of the file and expand it so
  it still makes sense on its own. `just history-line <file>` prints where
  that section starts.
- After a refactor, compare values, not only hashes. `just diff <ref>` says
  *what* changed. An unchanged fingerprint after a change you expected to
  matter is a reason to look closer (§4, §43).

Source: `.agents/skills/new-flake-module/SKILL.md`, "A module's name is its
filename"; `.agents/rules/flake-modules.md`, Conventions; `AGENTS.md`,
"Verify refactors by fingerprint, but not only by fingerprint".

## Wrapping a raw NixOS module

If you paste `nixos-generate-config` output, or any plain NixOS module,
wrap it in the same commit:

```nix
{
    nixos = { config, lib, modulesPath, ... }: {
        # … the original module body, unchanged
    };
}
```

If you leave it unwrapped, evaluation dies with `infinite recursion
encountered`, naming `modulesPath`. That error does not point at the real
cause.

Source: `.agents/skills/new-flake-module/SKILL.md`, "Raw NixOS modules".

## Keeping the wiki in step

If the category you changed has a page under
`wiki/config-structure/categories/`, update it in the same change. Then run
`just wiki-gen`, which regenerates the category index tables, the module
counts and the architecture diagram. `just wiki-lint` fails when they are
stale. The procedure is the `wiki-sync` skill.

Source: `.agents/skills/new-flake-module/SKILL.md`, "Wiki sync".
