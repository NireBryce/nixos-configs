nixos-configs
==============

Personal NixOS + Home Manager configuration, built with flake-parts. Not a
generalist template.

[wiki/00-INDEX.md](wiki/00-INDEX.md) is the topic index over the docs
scattered around this repo -- start there if you're looking for a
specific thing. The wiki itself is machine-generated, human-vetted
descriptions of component behavior and how it evolved.

Most of the prose in this repo -- commit messages, docs, comments -- is
written by coding agents, with human review before it lands.

Do not install this blindly
----------------------------

This config enables impermanence: `/root` is deleted and recreated from a
blank snapshot on every boot. The philosophy behind it is that state
should never accumulate by accident -- anything worth keeping has to be
named explicitly (persisted), so the config itself stays the source of
truth instead of drifting away from whatever's actually on disk.
Anything not explicitly persisted is gone at the next reboot. Read the
code before running any of it on a machine you care about.

That philosophy doesn't apply to home directory state yet -- `$HOME` is
still ordinary accumulated state, not wiped and rebuilt. Home Manager is
the interim tool for closing that gap: each thing it takes over (a
dotfile, a config, a package) is one less piece of `$HOME` that's just
sitting there undeclared.

Layout
------

The flake entry point is `flake/flake.nix` -- the repo root has none.
`flake.nix` itself is a manifest: it declares inputs and wires up
flake-parts, but doesn't enumerate modules by hand. `(inputs.import-tree
./modules)` recursively imports every `.nix` file under `flake/modules/`
instead. Each file declares
one `flake.modules.<class>.<name>` module — `<class>` is `nixos`,
`homeManager`, or `darwin`, so a single file can declare a NixOS module and
a Home Manager module for the same feature side by side (`nixd.nix`
installs the nixd LSP for both) instead of splitting one feature across two
files that agree only by sharing a filename. Which category a module
belongs to is decided by the directory it sits in, not by an explicit list,
so moving a file between directories moves it between categories and
nothing else has to change.

This keeps the config easy to reshape and hard to browse from a directory
listing alone. `flake/doc/dirsAsCategory.md` explains that mechanism;
`flake/doc/flake-parts-rationale.md` explains why flake-parts specifically,
and what else of it this repo actually uses.

Hosts
-----

Four hosts: `nire-durandal`, `nire-tenacity`, `nire-cube` (NixOS) and
`nire-lysithea` (darwin). [wiki/hosts.md](wiki/hosts.md) is the table --
roster, class, role, and which wipe `/root` -- and is checked against
`hosts.nix` mechanically, so it can't drift the way a second list here
did. Which one this branch actually runs on is a live question for the
host itself; see `AGENTS.md`'s State section.

`nire-(t)enacity` is a handheld, so it's usually the (t)estbed for
rapid prototyping -- it gets picked up and put down constantly, which
surfaces breakage fast. The other hosts usually lag behind it, not
ahead.

Users
-----

`(e)lly` is the (e)xperimental user -- everything lands there first. The
long-term idea is to offload what's really user-package material onto
`nire`, and beyond that, split off things that don't
need to be invoked directly by a human into their own dedicated user
accounts, so a compromised or misbehaving program running as one of
those users doesn't inherit the whole of `elly`'s authority (a
confused-deputy mitigation via user separation, not yet built out).

Secrets
-------

sops-nix. `secrets.yaml` is encrypted and committed on purpose, not a
mistake to fix.

Using this
----------

Steal what's useful. Don't run `nixos-rebuild switch` against this as-is on
a machine you are not prepared to lose `/root` on.

`AGENTS.md` and `wiki/lessons-learned.md` are an AI agent's working notes,
not documentation for a human reader — skip them unless you're the agent.
