# Introduction

This book is a guided tour of one repository: a personal configuration for
NixOS, nix-darwin and [Home Manager](glossary.md#home-manager), built as a
single flake with [flake-parts](https://flake.parts). Home Manager manages a
user's packages and dotfiles with the NixOS module system. flake-parts is a
library for writing a flake as a set of modules (see the
[glossary](glossary.md#flake-parts)). The book explains what the pieces are,
why they have their current shape, and how to make the common extensions: a
package, a module, a category, a host, a user. It assumes basic Nix and no
prior knowledge of this tree.

The book does not duplicate the documentation. The repo's wiki is the source
for facts, and the book links into it wherever a wiki page already covers a
topic. When the book and the wiki or the code disagree, the wiki and the code
win. Links of the form `../../wiki/...` point at files in the repository.
They work when you read the book's Markdown on GitHub or in a checkout. On a
rendered mdBook site they leave the book and will not resolve.

## Do not install this wholesale

This repo is not a template. Some NixOS hosts enable
[impermanence](glossary.md#impermanence): on every boot the `/root` btrfs
subvolume is deleted and recreated from a blank snapshot, and anything not
explicitly persisted is gone at the next reboot. Read
[how the non-obvious pieces work](how-it-works.md) and
[wiring a host](wiring-a-host.md) before running any of it on a machine you
care about. Do not assume which hosts wipe `/root`, in either direction.
Check `flake/modules/host-config/hosts.nix` and
[`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md).

## What it builds

- NixOS hosts, declared in `flake/modules/host-config/hosts.nix` as
  `flake.nixosConfigurations`.
- nix-darwin hosts, declared in the same file as
  `flake.darwinConfigurations`.
- Home Manager for one user, integrated into each system configuration
  instead of exposed as its own `homeConfigurations` output. One switch
  applies both. See [users and Home Manager](users-and-home-manager.md).
- A small self-hosted stack on one host. The stack is out of scope for this
  book; start at
  [`wiki/homelab/00-INDEX.md`](../../wiki/homelab/00-INDEX.md).

Source: `flake/flake.nix`, `flake/modules/host-config/hosts.nix`,
`README.md`, `wiki/overview.md`.

## The idea in one paragraph

Almost every `.nix` file under `flake/modules/` is a module, and its name is
its filename. (The exceptions are plain flake-parts files such as `hosts.nix`,
`checks.nix`, `invariants.nix`, `dev-shell.nix` and `lib.nix`, `defaults.nix`
files, and anything under a `_` path; see [how it works](how-it-works.md).)
The folder a module sits in decides which [category](glossary.md#category)
it belongs to; a category is a named group of modules that a host can take
in one line. A host lists categories by name and receives every module in
them. No central module list needs to be kept in sync, and no feature has
its own `enable` option: membership is the directory tree. A single file can
declare the NixOS side and the Home Manager side of one feature next to each
other, one [module class](glossary.md#module-class) per key. The details, and
the places where this design surprises people, are in
[how it works](how-it-works.md).

## Repository map

| Path | What is there |
|---|---|
| `flake/flake.nix` | Inputs and flake-parts setup. Deliberately holds no module list. |
| `flake/modules/` | Every module, grouped into areas such as `general-config/`, `hardware-config/`, `packages-config/`, `homelab-config/`, `host-config/`, `users-config/`. |
| `flake/doc/` | Standalone notes on mechanisms and ways back (for example returning to standalone Home Manager). |
| `flake/scripts/` | Scripts behind the `just` recipes. |
| `wiki/` | The documentation, organised by what a reader is doing. Start at [`wiki/00-INDEX.md`](../../wiki/00-INDEX.md). |
| `AGENTS.md` (also `CLAUDE.md`) | Working rules written for coding agents. Worth reading as a list of past mistakes. |
| `.agents/` | Agent skills, rules and hooks. The skills double as checklists for the tasks in this book. |
| `book/` | This book. |

Coding agents write most prose in the repo (commit messages, docs,
comments), with human review. That is why `AGENTS.md` and the skills are
phrased as hard-won rules. Treat them as reliable but not infallible.

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
3. Look up unfamiliar terms in the [glossary](glossary.md).

## Two habits that apply everywhere

- **Run `git add` before you evaluate.** A flake inside a git repository
  ignores untracked files, so a brand-new module silently does not exist
  until it is tracked. Every how-to chapter repeats this rule, because
  forgetting it is the most common way to conclude that a correct change
  does nothing.
- State how far you verified. Evaluating a configuration, building it, and
  switching to it are three different levels of evidence, and each level
  finds problems the previous one cannot. The repo's habit is to state which
  level a claim reached. Apply the same habit to anything you write down in
  the repo.

Source: `AGENTS.md` ("Working in this repo", "Before calling it done").
