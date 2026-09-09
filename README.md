nixos-configs
==============

Personal NixOS + Home Manager configuration, built with flake-parts. Not a
generalist template.

Do not install this blindly
----------------------------

This config enables impermanence: `/root` is deleted and recreated from a
blank snapshot on every boot. Anything not explicitly persisted is gone at
the next reboot. Read the code before running any of it on a machine you
care about.

Layout
------

The flake entry point is `flake/flake.nix` -- the repo root has none. It
imports every `.nix` file under `flake/modules/` via
`import-tree`, rather than wiring paths together by hand. Each file declares
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

Secrets
-------

sops-nix. `secrets.yaml` is encrypted and committed on purpose, not a
mistake to fix.

Using this
----------

Steal what's useful. Don't run `nixos-rebuild switch` against this as-is on
a machine you are not prepared to lose `/root` on.

`CLAUDE.md` and `wiki/lessons-learned.md` are an AI agent's working notes,
not documentation for a human reader — skip them unless you're the agent.

`wiki/README.md` is a topic index over the docs scattered around this repo
(architecture, hosts, impermanence, conventions, open threads) — a better
starting point than grepping if you're looking for a specific thing.
