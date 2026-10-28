# Adding a module

Creating a module under `flake/modules/` takes five steps: choose where it
goes, name it, write it in the house style, stage it, and prove it is wired
in. The same rules apply to renaming or moving a module. In this tree a
rename changes the module's name, and a move can change which hosts get it.
Packages follow the same rules plus some of their own; see
[Adding a package](adding-a-package.md). Unfamiliar terms are in the
[glossary](glossary.md).

## Step 1: decide where it goes

A module's location decides its membership: the module reaches whatever
hosts include the [category](glossary.md#category) above it. (A category is
a folder whose modules a host takes by one name.) Choose one of three places:

```text
Is it about one person's account (identity, dotfiles, HM settings)?
  yes -> users-config/<user>/<group>/
  no  -> Is it about one machine (its hardware, its fixes, what only it runs)?
           yes -> host-config/<host>/<group>/
           no  -> general-config/<subject>/…  hardware-config/…
                  homelab-config/homelab/…    or  packages-config/<kind>/…
```

- Shared folders (`general-config/`, `hardware-config/`, `homelab-config/`,
  `packages-config/`) are for anything more than one host could want, even
  if only one host takes it today. A host opts in by including the category.
- A host-specific folder (`host-config/<host>/`) is a category named after
  the host, and only that host's [entry point](glossary.md#entry-point)
  includes it. Put things here that only make sense on one machine: its
  hardware configuration, its bootloader, its `stateVersion`, firmware
  workarounds.
- A user-specific folder (`users-config/<user>/`) is a category carrying both
  halves of an account: the NixOS user account and the Home Manager
  settings. See [Wiring a user and Home Manager](users-and-home-manager.md).

If you can't decide between shared and host-specific, ask what would happen
if a second host included the category the module would land in. If the
answer is "that host now runs something it shouldn't" (a VM, a firewall
rule, a machine-specific fix), the module is host-specific (§38 in
[agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)).

Worked example: `virtualization-cube.nix` defines the `forge-runner` VM that
only the example host cube runs. The file used to sit in the shared
`virtualization` category, and a collector rule kept it out of that
category's own imports. When that rule went away, the file moved to
`host-config/cube/cube-vm/`. "Cube only" now follows from where the file is,
and nobody has to remember it.

Check: name the category that the chosen folder falls under, and confirm
that the hosts you intend include it.

Source: [where-modules-go.md](../../wiki/config-structure/where-modules-go.md),
"Deciding" and "Worked example"; current location of
`flake/modules/host-config/cube/cube-vm/virtualization-cube.nix`.

## Step 2: name it

A module's name is its filename. Modules and categories share one namespace
across the whole tree and across classes.

- Suffix anything host-specific with the host: `boot-cube.nix`,
  `hardware-tenacity.nix`, `nixpkgs-stateVersion-durandal.nix`.
- Prefix anything user-specific with the user where the name would otherwise
  be generic: `elly-git.nix`, `elly-user.nix`.
- Name the file after the specific thing it configures. A
  `containers/containers.nix` would collide with its own category, so the
  file is `podman.nix` (§35). Such collisions happened more than once before
  evaluation began refusing them.
- A name that is unique anyway (`b550-suspend-fix.nix`) needs no suffix.
- `default.nix` takes its folder's name, and `defaults.nix` is never a
  module. `just add-module` refuses both.

Check: a duplicate name stops evaluation and names both files; `just
add-module` in step 3 refuses one before the file exists.

Source: [where-modules-go.md](../../wiki/config-structure/where-modules-go.md),
"Naming"; `.agents/skills/new-flake-module/SKILL.md`, "Names share one
namespace".

## Step 3: write it

Run the scaffolder, which writes the correct shape and stages the file:

```sh
just add-module nixos general-config/system/my-thing/my-thing.nix "one-line description"
```

The first argument is the [module class](glossary.md#module-class): `nixos`,
`homeManager` or `darwin`, the kind of configuration the module targets. The
path is relative to `flake/modules/` and must end in `.nix` inside an
existing category. The command refuses an unknown class, a path outside
every category, `default.nix` or `defaults.nix`, and a name that a module or
category already uses. It writes:

```nix
# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = _: {
        # summary: one-line description
    };
}
```

When you fill the file in, keep the house style. Do not "clean up" these
rules:

- Put arguments in the right place. `lib` and `inputs` go in the outer list,
  and only if the file uses them, because deadnix fails on an unused one.
  `pkgs` and `config` go in the inner class lambda (replace `_:` with
  `{ pkgs, config, ... }:`). There is no outer `config`.
- Indent four spaces, with opening brackets on the same line as whatever
  opens them.
- Align `=` columns for runs of related assignments, matching the
  surrounding block. `nix fmt` is not wired up because it would undo the
  alignment.
- Wrap comments at 80 columns plus the line's indent. `just comment-wrap`
  reports violations. Keep `# summary:` to one line; tighten it rather than
  wrap it.
- Write one `# summary:` per module. In `packages-config/` it is
  `# package summary:`.
- Put the reasoning next to the option it explains, inside the body.
- `#` inside a `''` string is shell text and ends up verbatim in the
  generated file. Put notes for the person editing the `.nix` above the
  string.
- Look for an existing `programs.*` integration before writing one by hand.

Check: `just add-module` exits with an error, before writing anything, for
each refusal listed above. On success the file is staged. The command also
exits 1 after creating and staging the file if other orphans or untracked
`.nix` files already exist (`just modules` reports the same).

Source: `.agents/skills/new-flake-module/SKILL.md`, "Scaffolder" and "The
shape"; `flake/scripts/modules.py` (`add`, `BOILERPLATE`);
[module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md);
`.agents/rules/flake-modules.md`, Conventions.

## Step 4: `git add` before `nix eval`

A flake inside a git repository ignores untracked files. To Nix, a new
module that hasn't been `git add`ed **does not exist**, and nothing reports
its absence. `just add-module` stages the file for you. If
you created the file by hand, stage it yourself and run the checks:

```sh
git add flake/modules/general-config/system/my-thing/my-thing.nix
just modules     # reports untracked .nix files and graph drift
just check       # evaluates every host; does not fail on an orphan; `just modules` does (see Step 5)
```

When iterating, force the whole toplevel. A cheap attribute can resolve
while something else is broken. Evaluating the toplevel's
[`drvPath`](glossary.md#drvpath) forces the whole host configuration without
building it:

```sh
cd flake
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
```

Check: the `nix eval` command prints a `/nix/store/….drv` path, and
`just modules` reports no untracked files.

Source: `AGENTS.md`, "Working in this repo" and "Commands";
`.agents/rules/flake-modules.md`.

## Step 5: make sure something reaches it

A module inside a category reaches every host that includes that category.
If no host includes the category, the module is an
[**orphan**](glossary.md#orphan): it evaluates and installs nothing.

- `just modules` fails on an orphan and names it. It reads the `orphans`
  list from `nix eval --json ./flake#moduleGraph`.
- `just check` does not catch an orphan. The `module-orphans` flake check
  fails only when built, and `just check` runs with `--no-build`.

If a host should take the module on its own, without the rest of the
category, name the module in an `includes` list directly, as the hosts do
with `kde-desktop`.

Also check whether your new folder has turned its parent into a category.
See [Categories and membership](categories.md).

Check: `just modules` passes, or the `orphans` list in
`nix eval --json ./flake#moduleGraph` does not include the module.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
Quick facts; `.agents/skills/new-flake-module/SKILL.md`, "Categories come
from folders".

## Renaming or moving a module

- A rename renames the module. Membership follows the folder, so it
  survives. References by name (`includes`, `enables`, `hosts.nix`) break
  with an error; fix them in the same change.
- Leave the old name somewhere greppable. When a rename makes the old name
  impossible to find, add a one-line comment containing the old string on
  the declaration. `boot-durandal.nix` and `enable-home-manager.nix` do this.
- A move can change which hosts get the module. Moving a file to another
  category changes its hosts. Moving it into a new subfolder can promote the
  parent folder to a category.
- Comments that record a bug stay. If a change strands such a comment, move
  it to a `history` section at the bottom of the file and expand it so it
  still makes sense on its own. `just history-line <file>` prints where that
  section starts.
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

dirs-as-categories refuses an unwrapped module that asks for an argument
only a class module gets, such as `modulesPath` or `pkgs`, and the error
names the argument. The error suggests a second fix besides the wrapper
above: rename the file with a leading `_` and import it from a class, as in
`nixos.imports = [ ./_name.nix ];`.

A raw module that asks only for `config`, `lib` or `options` is not refused.
It loads as a flake-parts module, so wrap those too. Older library versions
died with `infinite recursion encountered`, naming `modulesPath`, an error
that did not point at the real cause.

Source: `.agents/skills/new-flake-module/SKILL.md`, "Raw NixOS modules".

## Keeping the wiki in step

If the category you changed has a page under
`wiki/config-structure/categories/`, update the page in the same change.
Then run `just wiki-gen`, which regenerates the category index tables, the
module counts and the architecture diagram. `just wiki-lint` fails when they
are stale. The procedure is the `wiki-sync` skill.

Source: `.agents/skills/new-flake-module/SKILL.md`, "Wiki sync".
