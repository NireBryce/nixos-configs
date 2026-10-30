# Introduction

This book explains one repository: a personal configuration for NixOS,
nix-darwin and [Home Manager](glossary.md#home-manager), built as a single
flake with [flake-parts](glossary.md#flake-parts). It covers how the pieces
work, why they have their shape, and how to extend them with a package, a
module, a category, a host or a user. It assumes basic Nix and no knowledge
of this tree. Terms are defined in the [glossary](glossary.md).

## Do not install this

The repo configures one person's fleet. It is not a template or a
distribution. Some NixOS hosts here enable
[impermanence](glossary.md#impermanence): on every boot the `/root` btrfs
subvolume is deleted and recreated from a blank snapshot, so running the
configuration on a machine you care about can destroy data. Which hosts do
this is in [wiring a host](wiring-a-host.md#read-this-first-the-root-wipe).
Borrow the patterns instead.

## The core idea

Almost every `.nix` file under `flake/modules/` is a
[module file](glossary.md#module-file), and its filename is its module name. The folder it sits in decides its
[category](glossary.md#category). A host lists categories by name and
receives every module file in them. No central list needs updating and no
feature has its own `enable` option.

One module file can hold the NixOS module and the Home Manager module for one
feature, one [module class](glossary.md#module-class) per key.
[How it works](how-it-works.md) covers the details and the surprises.

## Three kinds of module

The repo and this book use "module" for three different things, defined in
[`wiki/config-structure/module-files.md`](../../wiki/config-structure/module-files.md).

| Name | What it is | Example |
|---|---|---|
| [Module file](glossary.md#module-file) | A `.nix` file under `flake/modules/` that holds class modules under class keys. | `ripgrep.nix` |
| [NixOS module](glossary.md#nixos-module) (also Home Manager, darwin) | The value under a class key, evaluated for each host that includes the file. | the body of `homeManager = { pkgs, ... }: { ... }` |
| [Flake-parts module](glossary.md#flake-parts-module) | A module that configures the flake itself (`flake.*`, `perSystem`). It is a plain file outside the module-file shape. | `hosts.nix` |

```nix
# ripgrep.nix (header comment omitted): a module file with one Home Manager module
{
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            ripgrep
        ];
    };
}
```

```nix
# hosts.nix (shortened): a flake-parts module that builds flake outputs
{ config, inputs, withSystem, ... }:
{
    flake.nixosConfigurations = { /* one mkHost line per machine */ };
}
```

In names such as `just modules`, "module" means module file.

## Repository map

| Path | What is there |
|---|---|
| `flake/flake.nix` | Inputs and flake-parts setup. Holds no module list. |
| `flake/modules/` | Every module, grouped into areas such as `general-config/`, `hardware-config/`, `packages-config/`, `homelab-config/`, `host-config/`, `users-config/`. |
| `flake/doc/` | Standalone notes on individual mechanisms. |
| `flake/scripts/` | Scripts behind the `just` recipes. |
| `wiki/` | The documentation, organized by task. Start at [`wiki/00-INDEX.md`](../../wiki/00-INDEX.md). |
| `AGENTS.md` (also `CLAUDE.md`) | Working rules for coding agents, written as past mistakes. |
| `.agents/` | Agent [skills](glossary.md#skill), rules and [hooks](glossary.md#hook-claude-code). |
| `book/` | This book. See [about this book](about-this-book.md). |

Hosts are declared in `flake/modules/host-config/hosts.nix`. Home Manager runs
inside each system configuration, so one switch applies both (see
[users and Home Manager](users-and-home-manager.md)). The self-hosted stack is
out of scope; start at [`wiki/homelab/00-INDEX.md`](../../wiki/homelab/00-INDEX.md).

## Reading order

1. Do [your first change](first-change.md).
2. [Adding a package](adding-a-package.md) and
   [wiring a host](wiring-a-host.md) can each be read alone after that.
3. For the design, read [how it works](how-it-works.md), then
   [why it is built this way](rationale.md). The other how-to chapters
   ([categories](categories.md), [adding a module](adding-a-module.md),
   [users and Home Manager](users-and-home-manager.md),
   [darwin](darwin.md)) assume both.
4. The agent chapters ([agents in the repo](agents-in-the-repo.md),
   [checks and guards](agent-checks-and-guards.md),
   [git and agent workflows](git-and-agent-workflows.md)) are independent of
   the rest.

## Two habits that apply everywhere

- Run `git add` before you evaluate. A flake in a git repository ignores
  untracked files, so a new module does not exist until it is tracked. Forgetting this is the
  most common way to conclude that a correct change does nothing.
- State how far you verified: evaluated, built, or switched and used. Each
  level finds problems the previous one cannot.

## Sources

- `AGENTS.md`, "Working in this repo" and "Before calling it done"
- `flake/modules/host-config/hosts.nix`
- [`wiki/config-structure/module-files.md`](../../wiki/config-structure/module-files.md)
