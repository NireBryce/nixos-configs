# Introduction

This book is a guided tour of one repository: a personal NixOS, nix-darwin and
Home Manager configuration built as a single [flake-parts](https://flake.parts)
flake. It tells you what the pieces are, why they are shaped the way they are,
and the steps for the common extensions: a package, a module, a category, a
host, a user. It is written for someone who knows basic Nix and has never seen
this tree.

It is a tour, not a second copy of the documentation. The repo's wiki is the
source for facts, and this book links into it wherever a page already says
something well. When the two disagree, the wiki and the code win. Links of the form
`../../wiki/...` point at files in the repository, so they work when you
read the book's Markdown on GitHub or in a checkout; on a rendered mdBook
site they leave the book and will not resolve.

## Do not install this wholesale

This is not a template. Two of the NixOS hosts enable impermanence: on every
boot the `/root` btrfs subvolume is deleted and recreated from a blank
snapshot, and anything not explicitly persisted is gone at the next reboot.
Read [how the non-obvious pieces work](how-it-works.md) and
[wiring a host](wiring-a-host.md) before running any of it on a machine you
care about. Which hosts wipe `/root` is a fact to check in
`flake/modules/host-config/hosts.nix` and
[`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md), not to assume either way.

## What it builds

- **NixOS hosts**, declared in `flake/modules/host-config/hosts.nix` as
  `flake.nixosConfigurations`.
- **One nix-darwin host**, declared in the same file as
  `flake.darwinConfigurations`.
- **Home Manager for one user**, integrated into each system configuration
  rather than exposed as its own `homeConfigurations` output. One switch
  applies both. See [users and Home Manager](users-and-home-manager.md).
- **A small self-hosted stack** on one host. That is out of scope for this
  book; start at
  [`wiki/homelab/00-INDEX.md`](../../wiki/homelab/00-INDEX.md).

Source: `flake/flake.nix`, `flake/modules/host-config/hosts.nix`,
`README.md`, `wiki/overview.md`.

## The idea in one paragraph

Almost every `.nix` file under `flake/modules/` is a module, and its name is
its filename. (The exceptions are plain flake-parts files such as `hosts.nix`,
`checks.nix`, `invariants.nix`, `dev-shell.nix` and `lib.nix`, `defaults.nix`
files, and anything under a `_` path; see [how it works](how-it-works.md).) The folder it sits in decides which *category* it belongs to. A host
lists categories by name and receives every module in them. There is no central
module list to keep in sync and no `enable` option per feature: membership is
the directory tree. A single file can declare the NixOS side and the Home
Manager side of one feature next to each other. The details, and the places
where this surprises people, are in
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

Most prose in the repo (commit messages, docs, comments) is written by coding
agents with human review, which is why `AGENTS.md` and the skills are phrased
as hard-won rules. Treat them as reliable but not infallible.

## Reading order

1. [How the non-obvious pieces work](how-it-works.md), then
   [why it is built this way](rationale.md). Read these first; the how-to
   chapters assume them.
2. The how-to chapters, in the order you need them:
   [adding a package](adding-a-package.md),
   [adding a module](adding-a-module.md),
   [categories and membership](categories.md),
   [wiring a host](wiring-a-host.md),
   [wiring a user and Home Manager](users-and-home-manager.md), and
   [Darwin edge cases](darwin.md).

## Two habits that apply everywhere

- **`git add` before you evaluate.** Flakes inside a git repository ignore
  untracked files, so a brand-new module silently does not exist until it is
  tracked. Every how-to chapter repeats this because it is the most common way
  to conclude that a correct change does nothing.
- **Say how far you verified.** Evaluating a configuration, building it, and
  switching to it are three different levels of evidence, and each finds
  problems the previous one cannot. The repo's habit is to state which level a
  claim reached. The same goes for anything you write down here.

Source: `AGENTS.md` ("Working in this repo", "Before calling it done").
