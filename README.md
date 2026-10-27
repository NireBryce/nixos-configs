nixos-configs
==============

Personal NixOS + Home Manager configuration, built with flake-parts. Not a
template.

Most of the prose in this repo (commit messages, docs, comments) is written
by coding agents, with human review before it lands.

[wiki/00-INDEX.md](wiki/00-INDEX.md) is the topic index for the docs spread
around the repo. Start there to find something specific. The wiki is
machine-generated, human-vetted descriptions of how each component behaves
and how it got that way.

Do not install this as-is
-------------------------

Impermanence is on for `nire-durandal` and `nire-tenacity`. On every boot,
`/root` is deleted and recreated from a blank btrfs snapshot, so anything not
explicitly persisted is gone at the next reboot. That is deliberate: the
config, not whatever has piled up on disk, is the source of truth. Read the
code before running any of it on a machine you care about, and don't run
`nixos-rebuild switch` against it on a machine where losing `/root` would
hurt.

`$HOME` is not wiped; it is ordinary accumulated state. Home Manager
manages the user environment from Nix: dotfiles, program configs and user
packages are declared in this repo, and Home Manager installs or symlinks them into the
home directory. It is
integrated into the NixOS configuration, so one switch applies both. In the
meantime it also narrows the `$HOME` gap: each dotfile, config or package it
manages is one less undeclared thing in `$HOME`.

Layout
------

The flake entry point is `flake/flake.nix`. The repo root has none.
`flake.nix` declares inputs and sets up flake-parts, but doesn't list
modules. Instead, `(inputs.dirs-as-categories.lib.tree ./modules)` (an
import-tree preset) imports every `.nix` file under `flake/modules/` and
fills in `flake.modules.<class>.<name>` for each one. `<class>` is `nixos`,
`homeManager` or `darwin`.

A module's name is its filename, and its category is the directory it sits
in. Moving a file to another directory changes its category and nothing
else. One file can define both a NixOS and a Home Manager module for the
same feature (`cod-completions.nix` does this for cod's shell completions),
so a feature doesn't get split across two files that have to agree on a
name.

The config is split into many small files so each one can carry its own
documentation, and so a reader, human or agent, only has to load the file
in front of them. `flake/` is meant to be browsed by its file tree instead
of traced through code paths. The cost is that a directory listing alone
doesn't show how the pieces fit together.

`wiki/module-files.md` explains how names come from filenames and categories
from folders. `flake/doc/flake-parts-rationale.md` explains why flake-parts
was chosen and which of its features this repo actually uses.

Hosts
-----

The main hosts are `nire-durandal`, `nire-tenacity` and `nire-cube` (NixOS)
and `nire-lysithea` (darwin). [wiki/hosts.md](wiki/hosts.md) has the full
table: roster, class, role, and which hosts wipe `/root`. A check compares
it against `hosts.nix`, so it can't drift the way a second list in this
README did. What a given branch actually runs on a host can only be
answered on that host; see the State section of `AGENTS.md`.

`nire-tenacity` is a handheld, so it is the test bed. It gets picked up and
put down constantly, which surfaces breakage quickly. The other hosts
usually lag behind it.

Users
-----

`elly` is the experimental user, and everything lands there first. The
long-term plan is to move user-package material onto `nire`, and to split
things that don't need to be invoked by a human into their own accounts, so
a compromised or misbehaving program running as one of them doesn't inherit
all of `elly`'s authority. This separation isn't built yet.

Dev shells
----------

The Nix tooling for working on this repo (nixd, nil, nixfmt, statix,
deadnix, nix-tree, nix-diff, nix-du, nurl) isn't installed on the hosts.
Run `nix develop ./flake` from the repo root to get it
(`flake/modules/dev-shell.nix`). `just lint` enters that shell by itself
when statix and deadnix aren't on PATH.

`dev-shells/<name>/` holds standalone flake templates (`nix`, `python`,
`rust`) for other projects. `just dev-list` lists them. `just dev-new <name>
<path>` sets one up in a folder: it copies the flake, runs `git add` on it
if the folder is in a repo (flakes ignore untracked files), runs the
template's own scaffolding (`cargo init`, `uv init`), and writes an `.envrc`
with `use flake` for direnv. It won't overwrite an existing `flake.nix`
unless you pass `--force`.

Secrets
-------

Secrets use sops-nix. `secrets.yaml` is encrypted and committed on purpose.

Using this
----------

Take whatever is useful. `AGENTS.md` and `wiki/agent-lessons-learned.md` are
an AI agent's working notes, not documentation for people, so skip them
unless you're the agent.

License
-------

Copyright 2026 Nire Bryce. Licensed under the Apache License, Version 2.0;
see `LICENSE`. One file carries its own copyright header and keeps its own
terms: `flake/modules/users-config/elly/!dotfiles/.dir_colors` (Free
Software Foundation).
