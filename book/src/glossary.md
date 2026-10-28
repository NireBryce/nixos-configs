# Glossary

<!-- book-nav: generated from SUMMARY.md by `just agent book-nav write`; do not edit -->
<details class="book-nav">
<summary>Book contents (you are on: Glossary)</summary>

[Introduction](introduction.md)

**Understanding the repo**

1. [How the non-obvious pieces work](how-it-works.md)
2. [Why it is built this way](rationale.md)

**Extending it**

3. [Categories and membership](categories.md)
4. [Adding a module](adding-a-module.md)
5. [Adding a package](adding-a-package.md)
6. [Wiring a host](wiring-a-host.md)
7. [Wiring a user and Home Manager](users-and-home-manager.md)
8. [Darwin edge cases](darwin.md)

**Working with agents**

9. [How agents work in this repo](agents-in-the-repo.md)
10. [Checks, guards and hooks](agent-checks-and-guards.md)
11. [Git and agent workflows](git-and-agent-workflows.md)

**Reference**

12. **Glossary** (this page)

← [Git and agent workflows](git-and-agent-workflows.md)

</details>
<!-- /book-nav -->

Terms used across the book, in alphabetical order. Each entry ends with the
repo file that owns the fact.

## Aggregate

An aggregate is a module that exists to import other modules by name. Every
category has one aggregate per module class. The Home Manager side of the user
environment is one hand-written aggregate, `elly-home-manager`, whose
`includes.homeManager` lists categories.
Source: `flake/doc/dirsAsCategory.md`; header of
`flake/modules/users-config/elly-home-manager.nix`.

## Area

An area is a top-level folder under `flake/modules/`, such as
`general-config/` or `host-config/`. An area is not a category, so a file
placed directly in one belongs to no category. Host entry points sit there
for that reason.
Source: `AGENTS.md`, "Architecture"; header of
`flake/modules/users-config/elly-home-manager.nix`.

## Category

A category is a folder below an area that has a subfolder holding modules,
or that sets `folderIsCategory = true` in a file directly inside it. Including
a category by name includes every module beneath it, at any depth. The
category's name is the folder's name.
Source: [module-files.md](../../wiki/config-structure/module-files.md), Quick
facts.

## Deferred module

`deferredModule` is a module-system option type that stores a module without
evaluating it, so that a NixOS, Home Manager or darwin configuration can
import it later. Many files can write into the same `deferredModule` option
and the module system merges them. flake-parts declares
`flake.modules.<class>.<name>` with this type.
Source: `flake/doc/flake-parts-rationale.md`.

## dirs-as-categories

dirs-as-categories is the flake input that turns `flake/modules/` into
modules. It names each module after its file and makes folders into
categories, so no file states its own name or membership. It uses import-tree
to find the files and skips any path containing `/_`.
Source: `flake/flake.nix`;
[module-files.md](../../wiki/config-structure/module-files.md).

## `drvPath`

`drvPath` is the store path of a derivation. Evaluating
`config.system.build.toplevel.drvPath` forces Nix to evaluate a host's whole
configuration without building it. A cheap attribute does not force that
much.
Source: `AGENTS.md`, "Commands".

## `enables`

`enables.<class> = [ "name" ];` gives a module access to a module of another
class. The named module arrives as the argument `enabled.<class>.<name>`, and
only declared names are present.
Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Reaching other modules".

## Entry point

A host's entry point is `host-config/<host>-configuration.nix`: a module file
that lists the host's categories in `includes.<class>`. It sits directly in
the `host-config/` area, so it belongs to no category. `hosts.nix` turns each
entry point into a machine.
Source: [where-modules-go.md](../../wiki/config-structure/where-modules-go.md),
"Not a module: entry points".

## flake-parts

flake-parts is a library for writing a flake as a set of module-system
modules. This repo uses it mainly for one option,
`flake.modules.<class>.<name>`, which lets one file hold a NixOS module and a
Home Manager module side by side.
Source: `flake/doc/flake-parts-rationale.md`.

## Flake-parts module

A flake-parts module configures the flake itself, through `flake.*`,
`perSystem` or `withSystem`, and is evaluated by flake-parts' `mkFlake`. In
this tree it is a plain file that is not in the module-file shape, such as
`hosts.nix` or `checks.nix`. A flake-parts module is neither a
[module file](#module-file) nor the [NixOS module](#nixos-module) inside
one.
Source: [module-files.md](../../wiki/config-structure/module-files.md), "Three
kinds of module, and what to call each".

## GC root

A GC root is a reference that the Nix garbage collector treats as live, so
the store paths it points to are not deleted. `nix-collect-garbage -d` prunes
old profile generations, so a generation that must survive a cutover needs an
explicit root.
Source: `flake/doc/trailhead-home-manager-standalone.md`, "Order, and the
one-way part".

## Guard hook

A guard hook is a harness hook that denies, asks or warns when a tool call
matches a pattern. Examples are a git command that would discard uncommitted
work and a command that would print decrypted secrets. The guards are string and
path matchers. They are not a security boundary.
Source: `.agents/rules/agent-config.md`; the scripts under `.agents/hooks/`.

## Home Manager

Home Manager manages a user's packages and dotfiles with the same module
system NixOS uses. In this repo it runs inside each system configuration.
The flake has no `homeConfigurations` output, and one switch applies both.
Source: `flake/modules/general-config/system/home-manager/enable-home-manager.nix`.

## Hook (Claude Code)

A hook is a command the agent harness runs at a fixed event: session start,
before a tool call, or after one. Its JSON reply can deny, ask, warn or add
context. Claude Code reads the list from `.agents/settings.json`; ZCode reads
the same scripts from `.zcode/config.json`.
Source: `.agents/settings.json`; `.agents/rules/agent-config.md`.

## Impermanence

Impermanence is the setup in which a host deletes its root btrfs subvolume
on every boot and replaces it with a copy of an empty subvolume,
`root-blank`. Only `/nix`, `/home`, `/var/log` and the paths listed for
`/persist` survive. A host gets it only by including the `impermanence`
category.
Source: header of
`flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`.

## `includes`

`includes.<class> = [ "name" … ];` pulls in other modules or categories of the
same class, by name. Host entry points and `elly-home-manager` use it to list
what they take. An unknown name stops evaluation.
Source: [module-files.md](../../wiki/config-structure/module-files.md), Quick
facts.

## Lesson

A lesson is a numbered record of a past agent mistake. It has an article in
`wiki/agent-lessons-learned/` and a one-line index entry naming the rule's
Home and what enforces it. Where it applies to paths or commands, it also
has a reminder topic in `.agents/lessons-map.toml`. Lesson numbers are stable
and never renumbered.
Source: [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md),
header.

## Lint ratchet

The lint ratchet compares statix, deadnix and oversized-file counts against a
committed baseline, so a commit can lower a count but never raise it. A
commit that lowers one rewrites the baseline, and the pre-commit hook stages
it.
Source: `flake/scripts/lint.py`, docstring; `.githooks/pre-commit`.

## Module class

A module class is the kind of configuration a module targets: `nixos`,
`homeManager` or `darwin`. In a module file, each class is a top-level key
whose value is the module for that class.
Source: [module-files.md](../../wiki/config-structure/module-files.md), "What
a module file is".

## Module file

A module file is a `.nix` file under `flake/modules/` that holds one or more
class modules under class keys (`nixos`, `homeManager`, `darwin`), or is a
function of only `lib` and `inputs` returning such a set. dirs-as-categories
names it after its filename and fills `flake.modules.<class>.<name>` from it.
A bare "module" in a name such as `just modules` means module file.
Source: [module-files.md](../../wiki/config-structure/module-files.md), "Three
kinds of module, and what to call each".

## NixOS module

A NixOS module is the value under the `nixos` key of a [module file](#module-file):
an ordinary NixOS module, evaluated by `nixosSystem` for each host that
includes the file. A Home Manager module (the `homeManager` key) and a darwin
module (the `darwin` key) are the same idea for those systems.
Source: [module-files.md](../../wiki/config-structure/module-files.md), "Three
kinds of module, and what to call each".

## Offline checks

The offline checks are the checks that need neither nix nor `just`. The git
hooks run them when nix cannot supply the lint tools, as in a cloud container
that cannot fetch the flake inputs. `staged` mode checks syntax and parsing
of staged files plus the wiki lint. `preflight` mode runs preflight's
`python3` steps except those that need nix, and names what it left to CI.
Source: `flake/scripts/offline_checks.py`, docstring.

## Orphan

An orphan is a module that no host reaches, because nothing includes its
category or names it. It evaluates cleanly and installs nothing.
`just modules` fails on an orphan and names it. The `module-orphans` check
in `nix flake check` fails only when built, which `just check`'s `--no-build`
skips.
Source: [module-files.md](../../wiki/config-structure/module-files.md), Quick
facts; `flake/modules/checks.nix`.

## perSystem

perSystem is flake-parts' per-system scope, used here for checks and the dev
shell. Its default `pkgs` has no `nixpkgs.config` applied, so a `pkgs` taken
from it loses `allowUnfree` without an error.
Source: `flake/modules/host-config/hosts.nix` (comments above `mkHost`);
`flake/doc/flake-parts-rationale.md`.

## Preflight

Preflight is the `just preflight` recipe: the wiki lint, the test suites,
`just check`, `just modules` and `just lint`. CI runs the recipe itself, so
a step added to it gates every PR.
Source: `.justfile`, `preflight`; `.github/workflows/check.yml`.

## Skill

A skill is a markdown procedure for one kind of task, at
`.agents/skills/<name>/SKILL.md`. Its frontmatter `description` is what a
harness lists, and an agent loads the skill when that description matches
its task.
Source: `.agents/skills/new-skill/SKILL.md`.

## `useGlobalPkgs` and `useUserPackages`

Both bridge modules (`enable-home-manager.nix` and
`enable-home-manager-darwin.nix`) set these Home Manager options.
`useGlobalPkgs = true` makes Home Manager use the system's nixpkgs and skip
a second instantiation. A home module therefore may not set `nixpkgs.*`.
`useUserPackages = true` installs packages into
`/etc/profiles/per-user/<name>` instead of `~/.nix-profile`.
Source: `flake/modules/general-config/system/home-manager/enable-home-manager.nix`.

## Worktree

A worktree is a second working directory attached to the same git
repository, with its own checked-out branch and `HEAD` but shared branches
and objects. Each task that will branch, commit or check out gets its own,
so concurrent sessions do not disturb each other.
Source: `.agents/skills/use-a-worktree/SKILL.md`.
