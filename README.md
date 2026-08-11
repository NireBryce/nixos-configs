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

`flake.nix` imports every `.nix` file under `linux-flake/modules/` via
`import-tree`, rather than wiring paths together by hand. Each file declares
one `flake.modules.<class>.<name>` module. Which category it belongs to is
decided by the directory it sits in, not by an explicit list, so moving a
file between directories moves it between categories and nothing else has
to change.

This keeps the config easy to reshape and hard to browse from a directory
listing alone. `linux-flake/dirsAsCategory.md` explains the mechanism.

Hosts
-----

- `nire-durandal` — workstation
- `nire-tenacity` — handheld, Jovian/SteamOS

Both wipe `/root` on boot. `nire-tenacity` is currently the one this branch
actually runs on; `nire-durandal` has not been built or switched yet.

Secrets
-------

sops-nix. `secrets.yaml` is encrypted and committed on purpose, not a
mistake to fix.

Using this
----------

Steal what's useful. Don't run `nixos-rebuild switch` against this as-is on
a machine you are not prepared to lose `/root` on.

`CLAUDE.md` and `linux-flake/lessons.md` are an AI agent's working notes,
not documentation for a human reader — skip them unless you're the agent.
