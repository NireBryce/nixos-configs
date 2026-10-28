# Introduction

This book explains one repository: a personal configuration for NixOS,
nix-darwin and [Home Manager](glossary.md#home-manager), built as a single
flake with [flake-parts](https://flake.parts). Home Manager manages a user's
packages and dotfiles with the NixOS module system. flake-parts is a library
for writing a flake as a set of modules (see the
[glossary](glossary.md#flake-parts)).

The book covers:

- what the pieces are and why they have their current shape;
- how coding agents maintain the repo;
- how to make the common extensions: a package, a module, a category, a
  host, a user.

It assumes basic Nix and no prior knowledge of this tree.

## Read this first

### This is one person's fleet, not a product

The repo configures a personal fleet of machines. It is not a template, a
distribution or a framework, and nobody else should install, run or deploy
it. Read it to understand how it works. Borrow the pieces as examples for
your own NixOS configuration repository:

- a module tree where folders define groups;
- Home Manager run from the system configuration;
- hooks that keep working without network access;
- docs that check themselves.

The concrete reason not to deploy it: some NixOS hosts here enable
[impermanence](glossary.md#impermanence). On every boot, the `/root` btrfs
subvolume is deleted and recreated from a blank snapshot. Anything not
explicitly persisted is gone at the next reboot, so running the configuration
on a machine you care about can destroy data. Do not assume which hosts wipe
`/root`, in either direction; check `flake/modules/host-config/hosts.nix` and
[`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md).

### Coding agents wrote most of this, and the user directs them

Large language model (LLM) coding agents co-wrote most of the repository:
this book, the wiki, the code comments, the scripts, and the skills and
hooks. The user aims the agents, reviews and adjusts what they produce, and
rarely writes text directly. The user gives two reasons. There is no time to
write and maintain all of it by hand. Without the agents, the code would go
undocumented and the documentation would fall out of date.

Agent authorship changes how you should read the repo:

- The prose has an agent's habits. Rules are written as hard-won lessons, and
  the docs address agents as much as people.
- The user has corrected the load-bearing claims. The rest is agent output
  with less scrutiny. Treat the documentation as reliable but unproven, and
  check any statement that matters to you against the code it cites.
- The repo relies on mechanical checks to make up for that. Lints compare
  documentation against the code, and tests pin each checker to a case it
  should catch. The docs mark claims they could not confirm with an inline
  qualifier such as `UNVERIFIED` or "not confirmed live"; this book writes
  `Unverified:`. The chapters on
  [agents in the repo](agents-in-the-repo.md),
  [checks and guards](agent-checks-and-guards.md) and
  [git and agent workflows](git-and-agent-workflows.md) describe how these
  checks work and where they stop working.
- Agents drafted this book the same way, from the wiki, the code, comments
  and git history, and the user reviewed it. Its claims cite their sources so
  that you can check them.

Source: `README.md` ("most of the prose in this repo ... is written by coding
agents"), `AGENTS.md` (its opening note). The user's working method and the
two reasons are the user's own description; no file in the repo records them.

### How to use this book

Read it to learn a pattern, then look at the code that implements it. The
how-to chapters describe this repo's own procedures. If you build something
similar, expect to change names, paths and rules to suit your fleet.

### How the book relates to the wiki

The repo's wiki is the source for facts. The book links into it wherever a
wiki page already covers a topic, and does not duplicate it. When the book
disagrees with the wiki or the code, the wiki and the code win.

Links of the form `../../wiki/...` point at files in the repository. They
work when you read the book's Markdown on GitHub or in a checkout. On a
rendered mdBook site they leave the book and will not resolve.

## What it builds

- NixOS hosts, declared in `flake/modules/host-config/hosts.nix` as
  `flake.nixosConfigurations`.
- nix-darwin hosts, declared in the same file as
  `flake.darwinConfigurations`.
- Home Manager for one user, integrated into each system configuration.
  The flake has no `homeConfigurations` output, and one switch applies both.
  See [users and Home Manager](users-and-home-manager.md).
- A small self-hosted stack on one host. The stack is out of scope for this
  book; start at
  [`wiki/homelab/00-INDEX.md`](../../wiki/homelab/00-INDEX.md).

Source: `flake/flake.nix`, `flake/modules/host-config/hosts.nix`,
`README.md`, `wiki/overview.md`.

## Three kinds of module

The word "module" names three different things here, and the book keeps them
apart. The repo follows the same convention, defined in
[`wiki/config-structure/module-files.md`](../../wiki/config-structure/module-files.md).

| Name | What it is | Example |
|---|---|---|
| [Module file](glossary.md#module-file) | A `.nix` file under `flake/modules/` that holds one or more class modules under class keys. It is named by its filename. | `ripgrep.nix` |
| [NixOS module](glossary.md#nixos-module) (also Home Manager module, darwin module) | The value under a class key: an ordinary module of that system, evaluated for each host that includes the file. | the body of `homeManager = { pkgs, ... }: { ... }` |
| [Flake-parts module](glossary.md#flake-parts-module) | A module that configures the flake itself (`flake.*`, `perSystem`, `withSystem`). In this tree it is a plain file outside the module-file shape. | `hosts.nix` |

One module file and one flake-parts module, side by side:

```nix
# ripgrep.nix (header comment omitted): a module file with one Home Manager module
{
    homeManager = { pkgs, ... }: {
        # `rg` is a much faster and more powerful grep alternative
        home.packages = with pkgs; [
            ripgrep
        ];
    };
}
```

```nix
# hosts.nix (shortened): a flake-parts module; it builds flake outputs
{ config, inputs, withSystem, ... }:
{
    flake.nixosConfigurations = { /* one mkHost line per machine */ };
}
```

The distinction explains an error you will meet. A plain NixOS module (for
example `nixos-generate-config` output) placed under `flake/modules/` is not a
module file. When it asks for an argument only a class module gets, such as
`modulesPath`, dirs-as-categories refuses it and names the argument. Wrapping
it as `{ nixos = <the module>; }` makes it a module file
(see [wrapping a raw NixOS module](adding-a-module.md#wrapping-a-raw-nixos-module)).
Where a name already contains the word, such as `just modules` or
`module-orphans`, "module" means module file.

## The core idea

Almost every `.nix` file under `flake/modules/` is a module file, named by its
filename. The exceptions are plain flake-parts modules such as `hosts.nix` and
`checks.nix`, `defaults.nix` files, and anything under a `_` path.

The folder a module file sits in decides its
[category](glossary.md#category): a named group of module files that a host
takes in one line. A host lists categories by name and receives every module
file in them. Membership is the directory tree, so no central list needs to be
kept in sync and no feature has its own `enable` option.

One module file can declare the NixOS module and the Home Manager module of
one feature side by side, one [module class](glossary.md#module-class) per
key. [How it works](how-it-works.md) has the details and the places where
this design surprises people.

## Repository map

| Path | What is there |
|---|---|
| `flake/flake.nix` | Inputs and flake-parts setup. Holds no module list. |
| `flake/modules/` | Every module, grouped into areas such as `general-config/`, `hardware-config/`, `packages-config/`, `homelab-config/`, `host-config/`, `users-config/`. |
| `flake/doc/` | Standalone notes on mechanisms and ways back (for example returning to standalone Home Manager). |
| `flake/scripts/` | Scripts behind the `just` recipes. |
| `wiki/` | The documentation, organized by what a reader is doing. Start at [`wiki/00-INDEX.md`](../../wiki/00-INDEX.md). |
| `AGENTS.md` (also `CLAUDE.md`) | Working rules written for coding agents. Reads as a list of past mistakes. |
| `.agents/` | Agent skills, rules and hooks. The skills double as checklists for the tasks in this book. |
| `book/` | This book. |

## Reading order

1. Read [how the non-obvious pieces work](how-it-works.md), then
   [why it is built this way](rationale.md). The how-to chapters assume both.
2. Read the how-to chapters in the order you need them:
   [adding a package](adding-a-package.md),
   [adding a module](adding-a-module.md),
   [categories and membership](categories.md),
   [wiring a host](wiring-a-host.md),
   [wiring a user and Home Manager](users-and-home-manager.md), and
   [Darwin edge cases](darwin.md).
3. Read the chapters on working with agents to learn how the repo stays
   documented and checked:
   [agents in the repo](agents-in-the-repo.md),
   [checks, guards and hooks](agent-checks-and-guards.md), and
   [git and agent workflows](git-and-agent-workflows.md).
4. Look up unfamiliar terms in the [glossary](glossary.md).

## Two habits that apply everywhere

- Run `git add` before you evaluate. A flake inside a git repository ignores
  untracked files, so a brand-new module does not exist until it is tracked.
  Forgetting this step is the most common way to conclude that a correct
  change does nothing, and every how-to chapter repeats it.
- State how far you verified. Evaluating a configuration, building it and
  switching to it are different levels of evidence, and each level finds
  problems the previous one cannot. The repo states which level a claim
  reached; do the same in anything you write in the repo.

Source: `AGENTS.md` ("Working in this repo", "Before calling it done").
