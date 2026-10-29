# Adding a module

Creating a module under `flake/modules/` takes five steps: choose where it
goes, name it, write it in the house style, stage it, and prove a host reaches it. Renaming or moving a module follows the same rules: a rename changes the
module's name, and a move can change which hosts get it. Packages add rules
of their own; see [Adding a package](adding-a-package.md).

## Step 1: decide where it goes

A module reaches whatever hosts include the [category](glossary.md#category)
above it, so its location decides its membership. Choose one of three places:

```text
Is it about one person's account (identity, dotfiles, HM settings)?
  yes -> users-config/<user>/<group>/
  no  -> Is it about one machine (its hardware, its fixes, what only it runs)?
           yes -> host-config/<host>/<group>/
           no  -> general-config/<subject>/…  hardware-config/…
                  homelab-config/homelab/…    or  packages-config/<kind>/…
```

- Shared folders (`general-config/`, `hardware-config/`, `homelab-config/`,
  `packages-config/`) hold anything more than one host could want, even if
  only one host takes it today. A host opts in by including the category.
- `host-config/<host>/` is a category named after the host, and only that
  host's [entry point](glossary.md#entry-point) includes it. Put hardware
  configuration, the bootloader, `stateVersion` and firmware workarounds
  here.
- `users-config/<user>/` is a category carrying both halves of an account:
  the NixOS user and the Home Manager settings. See
  [Wiring a user and Home Manager](users-and-home-manager.md).

If you can't decide between shared and host-specific, ask what happens if a
second host included the category. If that host would now run something it
shouldn't (a VM, a firewall rule, a machine-specific fix), the module is
host-specific ([lesson 38](../../wiki/agent-lessons-learned/38-scope-the-fix-to-the-caller.md)).

Example: `virtualization-cube.nix` defines the `forge-runner` VM that only
the example host cube runs. It lives in `host-config/cube/cube-vm/` so that
"cube only" follows from the file's location.

## Step 2: name it

A module's name is its filename. Modules and categories share one namespace
across the whole tree and across classes. A duplicate name stops evaluation
and names both files.

- Suffix host-specific files with the host: `boot-cube.nix`,
  `hardware-tenacity.nix`, `nixpkgs-stateVersion-durandal.nix`.
- Prefix user-specific files with the user where the name would otherwise be
  generic: `elly-git.nix`, `elly-user.nix`.
- Name the file after the specific thing it configures. A
  `containers/containers.nix` would collide with its own category, so the
  file is `podman.nix` ([lesson 35](../../wiki/agent-lessons-learned/35-collision-a-third-time.md)).
- A name that is unique anyway (`b550-suspend-fix.nix`) needs no suffix.
- `default.nix` takes its folder's name, and `defaults.nix` is never a
  module. `just add-module` refuses both.

## Step 3: write it

Run the scaffolder, which writes a [dirs-as-categories](glossary.md#dirs-as-categories)
module file and stages it:

```sh
just add-module nixos general-config/system/my-thing/my-thing.nix "one-line description"
```

The first argument is the [module class](glossary.md#module-class): `nixos`,
`homeManager` or `darwin`. The path is relative to `flake/modules/` and must
end in `.nix` inside an existing category. The command refuses an unknown
class, a path outside every category, `default.nix` or `defaults.nix`, and a
name that a module or category already uses. It writes:

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

Keep the house style when you fill the file in. Do not "clean up" these
rules.

**Arguments**

| Rule | Detail |
|---|---|
| `lib`, `inputs` | Go in the outer argument list, only if the file uses them (deadnix fails on an unused one). |
| `pkgs`, `config` | Go in the inner class lambda: replace `_:` with `{ pkgs, config, ... }:`. There is no outer `config`. |

**Formatting**

| Rule | Detail |
|---|---|
| Indent | Four spaces, with opening brackets on the same line as whatever opens them. |
| Alignment | Align `=` columns in runs of related assignments. `nix fmt` is not wired up because it would undo the alignment. |

**Comments**

| Rule | Detail |
|---|---|
| Width | Wrap at 80 columns plus the line's indent. `just comment-wrap` reports violations. |
| Summary | One `# summary:` per module, on one line (`# package summary:` in `packages-config/`). Tighten it rather than wrap it. |
| Placement | Put the reasoning next to the option it explains, inside the body. |
| `''` strings | `#` inside a `''` string is shell text and lands verbatim in the generated file. Put notes for the person editing the `.nix` above the string. |

Before writing an integration by hand, look for an existing `programs.*`
option.

If the tree already has [orphans](glossary.md#orphan) or untracked `.nix`
files, `just add-module` still creates and stages the file, then exits 1
(`just modules` reports the same).

## Step 4: `git add` before `nix eval`

A flake inside a git repository ignores untracked files. A new module that
hasn't been `git add`ed **does not exist** to Nix, and nothing reports its
absence. `just add-module` stages the file for you. For a file created by
hand, stage it and run the checks:

```sh
git add flake/modules/general-config/system/my-thing/my-thing.nix
just modules     # reports untracked .nix files and graph drift
just check       # evaluates every host (see Step 5: it does not catch orphans)
```

When iterating, force the whole toplevel, because a cheap attribute can
resolve while something else is broken. Evaluating the toplevel's
[`drvPath`](glossary.md#drvpath) forces the whole host configuration without
building it:

```sh
cd flake
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
```

Check: the command prints a `/nix/store/….drv` path, and `just modules`
reports no untracked files.

## Step 5: make sure something reaches it

A module inside a category reaches every host that includes that category.
If no host includes the category, the module is an
[orphan](glossary.md#orphan): it evaluates and installs nothing.

- `just modules` fails on an orphan and names it. It reads the `orphans`
  list from `nix eval --json ./flake#moduleGraph`.
- `just check` does not catch an orphan. The `module-orphans` flake check
  fails only when built, and `just check` runs with `--no-build`.

If a host should take the module without the rest of its category, name the
module in an `includes` list directly, as the hosts do with `kde-desktop`.

Also check whether your new folder has turned its parent into a category;
see [Categories and membership](categories.md).

## Renaming or moving a module

- A rename renames the module. Membership follows the folder, so it
  survives. References by name ([`includes`](glossary.md#includes),
  [`enables`](glossary.md#enables), `hosts.nix`) break with an error; fix them in the same change.
- When a rename makes the old name impossible to find, add a one-line
  comment containing the old string on the declaration. `boot-durandal.nix`
  and `enable-home-manager.nix` do this.
- Moving a file to another category changes its hosts. Moving it into a new
  subfolder can promote the parent folder to a category.
- Comments that record a bug stay. If a change strands such a comment, move
  it to a `history` section at the bottom of the file and expand it so it
  makes sense on its own. `just history-line <file>` prints where that
  section starts.
- After a refactor, compare values, not only hashes: `just diff <ref>` shows
  what changed. An unchanged fingerprint after a change you expected to
  matter calls for a closer look ([lesson 4](../../wiki/agent-lessons-learned/4-unchanged-fingerprint-inert-code.md),
  [lesson 43](../../wiki/agent-lessons-learned/43-fingerprint-passed-for-the-wrong-reason.md)).

## Wrapping a raw NixOS module

When you paste `nixos-generate-config` output or any plain NixOS module,
wrap it in the same commit:

```nix
{
    nixos = { config, lib, modulesPath, ... }: {
        # … the original module body, unchanged
    };
}
```

[dirs-as-categories](glossary.md#dirs-as-categories) refuses an unwrapped module that asks for an argument
only a class module (the value under `nixos`, for example) gets, such as `modulesPath` or `pkgs`, and the error
names the argument. The error also suggests an alternative to the wrapper:
rename the file with a leading `_` and import it from a class, as in
`nixos.imports = [ ./_name.nix ];`.

A raw module that asks only for `config`, `lib` or `options` is not refused.
It loads as a [flake-parts module](glossary.md#flake-parts-module), so wrap
those too.

## Keeping the wiki in step

If the category you changed has a page under
`wiki/config-structure/categories/`, update it in the same change, then run
`just wiki-gen` to regenerate the category index tables, the module counts
and the architecture diagram. `just wiki-lint` fails when they are stale.
The procedure is the `wiki-sync` [skill](glossary.md#skill).

## Sources

- [where-modules-go.md](../../wiki/config-structure/where-modules-go.md)
- [module-files.md](../../wiki/config-structure/module-files.md)
- [module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md)
- `.agents/skills/new-flake-module/SKILL.md`
- `.agents/rules/flake-modules.md`
- `AGENTS.md`, "Working in this repo" and "Commands"
- `flake/scripts/modules.py` (`add`, `BOILERPLATE`)
- `flake/modules/host-config/cube/cube-vm/virtualization-cube.nix`
