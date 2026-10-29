# Glossary

Terms used across the book, in alphabetical order. Each entry ends with the
file that owns the fact.

## Aggregate

A module that exists to import other modules by name. Every category has one
aggregate per module class. The Home Manager side of the user environment is
one hand-written aggregate, `elly-home-manager`, whose `includes.homeManager`
lists categories.
Source: `flake/doc/dirsAsCategory.md`.

## Area

A top-level folder under `flake/modules/`, such as `general-config/` or
`host-config/`. An area is not a category, so a file placed directly in one
belongs to no category. Host entry points sit there for that reason.
Source: `AGENTS.md`, "Architecture".

## Category

A folder below an area that has a subfolder holding modules, or that sets
`folderIsCategory = true` in a file directly inside it. Including a category
by name includes every module beneath it, at any depth. The category's name is
the folder's name.
Source: [module-files.md](../../wiki/config-structure/module-files.md).

## Deferred module

A module-system option type that stores a module without evaluating it, so a
NixOS, Home Manager or darwin configuration can import it later. Many files
can write into the same `deferredModule` option and the module system merges
them. flake-parts declares `flake.modules.<class>.<name>` with this type.
Source: `flake/doc/flake-parts-rationale.md`.

## dirs-as-categories

The flake input that turns `flake/modules/` into modules. It names each module
after its file and makes folders into categories. It uses import-tree (a library that lists a
directory's `.nix` files) to find the files and skips any path containing `/_`.
Source: `flake/flake.nix`.

## `drvPath`

The store path of a derivation. Evaluating
`config.system.build.toplevel.drvPath` forces Nix to evaluate a host's whole
configuration without building it. A cheaper attribute does not force that
much.
Source: `AGENTS.md`, "Commands".

## `enables`

`enables.<class> = [ "name" ];` gives a module access to a module of another
class. The named module arrives as the argument `enabled.<class>.<name>`, and
only declared names are present.
Source: [module-files.md](../../wiki/config-structure/module-files.md).

## Entry point

A host's `host-config/<host>-configuration.nix`: a module file that lists the
host's categories in `includes.<class>`. It sits directly in the `host-config/`
area, so it belongs to no category. `hosts.nix` turns each entry point into a
machine.
Source: [where-modules-go.md](../../wiki/config-structure/where-modules-go.md).

## flake-parts

A library for writing a flake as a set of module-system modules. This repo
uses it mainly for the option `flake.modules.<class>.<name>`, which lets one
file hold a NixOS module and a Home Manager module side by side.
Source: `flake/doc/flake-parts-rationale.md`.

## Flake-parts module

A module that configures the flake itself, through `flake.*`, `perSystem` or
`withSystem`. In this tree it is a plain file outside the module-file shape,
such as `hosts.nix` or `checks.nix`. It is neither a [module file](#module-file)
nor the [NixOS module](#nixos-module) inside one.
Source: [module-files.md](../../wiki/config-structure/module-files.md).

## GC root

A reference that the Nix garbage collector treats as live, so the store paths
it points to are not deleted. `nix-collect-garbage -d` prunes old profile
generations, so a generation that must survive a cutover needs an explicit
root.
Source: `flake/doc/trailhead-home-manager-standalone.md`.

## Guard hook

A [hook](#hook-claude-code) that denies, asks or warns when a tool call matches a pattern,
such as a git command that would discard uncommitted work. Guards are string
and path matchers, not a security boundary.
Source: `.agents/rules/agent-config.md`.

## Home Manager

Manages a user's packages and dotfiles with the module system NixOS uses. Here
it runs inside each system configuration. The flake has no
`homeConfigurations` output, and one switch applies both.
Source: `flake/modules/general-config/system/home-manager/enable-home-manager.nix`.

## Hook (Claude Code)

A command the agent harness runs at a fixed event: session start, before a
tool call, or after one. Its JSON reply can deny, ask, warn or add context.
Claude Code reads the list from `.agents/settings.json`; ZCode reads the same
scripts from `.zcode/config.json`.
Source: `.agents/rules/agent-config.md`.

## Impermanence

A setup in which a host deletes its root btrfs subvolume on every boot and
replaces it with a copy of an empty subvolume, `root-blank`. Only `/nix`,
`/home`, `/var/log` and the paths listed for `/persist` survive. A host gets it
only by including the `impermanence` category.
Source: `flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`.

## `includes`

`includes.<class> = [ "name" … ];` pulls in other modules or categories of the
same class, by name. Host entry points and `elly-home-manager` use it. An
unknown name stops evaluation.
Source: [module-files.md](../../wiki/config-structure/module-files.md).

## Lesson

A numbered record of a past agent mistake, with an article in
`wiki/agent-lessons-learned/` and a one-line index entry. Where it applies to
paths or commands, it also has a reminder topic in `.agents/lessons-map.toml`.
Lesson numbers are never renumbered.
Source: [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md).

## Lint ratchet

A comparison of statix, deadnix and oversized-file counts against a committed
baseline, so a commit can lower a count but never raise it. A commit that
lowers one rewrites the baseline, and the pre-commit hook stages it.
Source: `flake/scripts/lint.py`.

## Module class

The kind of configuration a module targets: `nixos`, `homeManager` or
`darwin`. In a module file, each class is a top-level key whose value is the
module for that class.
Source: [module-files.md](../../wiki/config-structure/module-files.md).

## Module file

A `.nix` file under `flake/modules/` that holds class modules under class keys
(`nixos`, `homeManager`, `darwin`), or a function of only `lib` and `inputs`
returning such a set. dirs-as-categories names it after its filename. A bare
"module" in a name such as `just modules` means module file.
Source: [module-files.md](../../wiki/config-structure/module-files.md).

## NixOS module

The value under the `nixos` key of a [module file](#module-file): an ordinary
NixOS module, evaluated for each host that includes the file. A Home Manager
module (the `homeManager` key) and a darwin module (the `darwin` key) are the
same idea for those systems.
Source: [module-files.md](../../wiki/config-structure/module-files.md).

## Offline checks

Checks that need neither nix nor `just`. The git hooks run them when nix cannot
supply the lint tools, as in a cloud container that cannot fetch the flake
inputs. `staged` mode checks syntax and parsing of staged files plus the wiki
lint. `preflight` mode runs the `python3` steps of [preflight](#preflight) and names
what it left to CI.
Source: `flake/scripts/offline_checks.py`.

## Orphan

A module that no host reaches, because nothing includes its category or names
it. It evaluates cleanly and installs nothing. `just modules` fails on an
orphan and names it. The `module-orphans` check in `nix flake check` fails only
when built, which `just check`'s `--no-build` skips.
Source: `flake/modules/checks.nix`.

## perSystem

flake-parts' per-system scope, used here for checks and the dev shell. Its
`pkgs` is built from the fleet's shared `nixpkgs.config` and carries
`allowUnfree`; it is not the instance a host builds.
Source: `flake/modules/host-config/hosts.nix`.

## Preflight

The `just preflight` recipe: the wiki lint, the test suites, `just check`,
`just modules` and `just lint`. CI runs the recipe itself, so a step added to
it gates every PR.
Source: `.justfile`.

## Skill

A markdown procedure for one kind of task, at `.agents/skills/<name>/SKILL.md`.
A harness lists its frontmatter `description`, and an agent loads the skill
when that description matches its task.
Source: `.agents/skills/new-skill/SKILL.md`.

## Split-brain

The state where the system generation is activated but the user's Home Manager
generation is not. See
[users and Home Manager](users-and-home-manager.md#when-the-system-switches-but-the-home-half-does-not).
Source: `book/src/users-and-home-manager.md`.

## `useGlobalPkgs` and `useUserPackages`

Home Manager options set by both bridge modules. `useGlobalPkgs = true` makes
Home Manager use the system's nixpkgs, so a home module may not set
`nixpkgs.*`. `useUserPackages = true` installs packages into
`/etc/profiles/per-user/<name>` instead of `~/.nix-profile`.
Source: `flake/modules/general-config/system/home-manager/enable-home-manager.nix`.

## Worktree

A second working directory attached to the same git repository, with its own
checked-out branch and `HEAD`. Each task that will branch, commit or check out
gets its own, so concurrent sessions do not disturb each other.
Source: `.agents/skills/use-a-worktree/SKILL.md`.
