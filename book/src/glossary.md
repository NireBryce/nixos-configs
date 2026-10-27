# Glossary

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
`general-config/` or `host-config/`. An area is not a category, so a file placed directly in one
belongs to no category. Host entry points sit there for that reason.
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
configuration without building it, which a cheap attribute does not.
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

## GC root

A GC root is a reference that the Nix garbage collector treats as live, so
the store paths it points to are not deleted. `nix-collect-garbage -d` prunes
old profile generations, so a generation that must survive a cutover needs an
explicit root.
Source: `flake/doc/trailhead-home-manager-standalone.md`, "Order, and the
one-way part".

## Home Manager

Home Manager manages a user's packages and dotfiles with the same module
system NixOS uses. In this repo it runs inside each system configuration, so
there is no `homeConfigurations` output and one switch applies both.
Source: `flake/modules/general-config/system/home-manager/enable-home-manager.nix`.

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

## Module class

A module class is the kind of configuration a module targets: `nixos`,
`homeManager` or `darwin`. In a module file, each class is a top-level key
whose value is the module for that class.
Source: [module-files.md](../../wiki/config-structure/module-files.md), "What
a module file is".

## Orphan

An orphan is a module that no host reaches, because nothing includes its
category or names it. It evaluates cleanly and installs nothing. The
`module-orphans` check in `nix flake check` reports it.
Source: [module-files.md](../../wiki/config-structure/module-files.md), Quick
facts; `flake/modules/checks.nix`.

## perSystem

perSystem is flake-parts' per-system scope, used here for checks and the dev
shell. Its default `pkgs` has no `nixpkgs.config` applied, so a `pkgs` taken
from it silently loses `allowUnfree`.
Source: `flake/modules/host-config/hosts.nix` (comments above `mkHost`);
`flake/doc/flake-parts-rationale.md`.

## `useGlobalPkgs` and `useUserPackages`

These two Home Manager options are set by the NixOS-side bridge.
`useGlobalPkgs = true` makes Home Manager use the system's nixpkgs instead of
a second instantiation, which is why a home module may not set `nixpkgs.*`.
`useUserPackages = true` installs packages into
`/etc/profiles/per-user/<name>` instead of `~/.nix-profile`.
Source: `flake/modules/general-config/system/home-manager/enable-home-manager.nix`.
