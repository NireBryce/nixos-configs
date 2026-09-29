# Where a module goes

_Last modified: 2026-09-29_

Every module under `flake/modules/` sits in one of three places, and which
one decides who gets it: **shared** modules sit in the general tree and
hosts pick them up by category; **host-specific** modules sit under that
host's directory in `host-config/`; **user-specific** modules sit under
that user's directory in `users-config/`. Location *is* membership here
(a category imports every `.nix` file under its folder —
[architecture.md](architecture.md)), so choosing the directory is
choosing who the module reaches.

## Contents

- [The three places](#the-three-places)
- [Deciding](#deciding)
- [Naming: suffix anything host- or user-specific](#naming-suffix-anything-host--or-user-specific)
- [Not a module: entry points](#not-a-module-entry-points)
- [Worked example: cube's VM wiring](#worked-example-cubes-vm-wiring)
- [See also](#see-also)

## The three places

```
flake/modules/
├── general-config/        shared system behavior, one category per subject
│   ├── boot/                (boot, impermanence, homelab, shell-config, ...)
│   └── ...
├── packages-config/       shared packages, one category per kind
│   ├── shell-apps/          (editors, terminals, development, ...)
│   └── ...
├── host-config/           one directory per host
│   ├── cube/                category `cube`   -- only cube imports it
│   │   ├── configuration/
│   │   ├── hardware/
│   │   └── cube-vm/
│   ├── cube-configuration.nix                 -- cube's entry point
│   └── ...
└── users-config/          one directory per user
    ├── elly/                category `elly`   -- the account's own config
    │   ├── elly-git/
    │   ├── hm-config/
    │   └── user-settings/
    └── elly-home-manager.nix                  -- the HM entry point
```

**Shared — `general-config/` and `packages-config/`.** Anything more than
one host could want, even if only one takes it today. Each subdirectory is
a category (`boot`, `homelab`, `shell-apps`, …) and a host opts in by
listing the category in its entry point, so a shared module can still be
optional: a category nobody lists is a category nobody gets (`homelab`,
and `virtualization` inside it, are cube-only that way). `general-config/` is behavior —
services, boot, shell setup; `packages-config/` is packages.

**Host-specific — `host-config/<host>/`.** Anything that only makes sense
on one machine: its `hardware-configuration`, its bootloader, its
`stateVersion`, workarounds for its own firmware, services only it runs.
`host-config/<host>/` is a category named after the host, and only that
host's entry point imports it — so a module here is that host's by
construction, with nothing to remember. The subfolders in use
(`configuration/`, `hardware/`, `fixes/`, cube's `cube-vm/`) are grouping only.

**User-specific — `users-config/<user>/`.** Anything about one person's
account rather than a machine: the user account and its groups
(`elly-user.nix`), their git config (`elly-git.nix`), Home Manager
settings (`hm-config.nix`). `users-config/<user>/` is a category named
after the user, carrying both halves: each fleet host's entry point lists
`elly`
for the NixOS side (the account), and `users-config/elly-home-manager.nix`
lists it for the Home Manager side.

## Deciding

```
Is it about one person's account (identity, dotfiles, HM settings)?
  yes -> users-config/<user>/<group>/
  no  -> Is it about one machine (its hardware, its fixes, what only it runs)?
           yes -> host-config/<host>/<group>/
           no  -> general-config/<subject>/...  or  packages-config/<kind>/...
```

When in doubt between shared and host-specific, ask what happens if a
second host imports the category it would land in. If the answer is "that
host now runs something it shouldn't" — a VM, a firewall rule, a
machine-specific fix — it's host-specific. That question is the one
[lessons-learned §38](lessons-learned.md) records as having caught a
too-general fix before it shipped.

## Naming: suffix anything host- or user-specific

A module's name is its filename, and names share **one namespace per
class** across the whole tree. Two hosts each with a `boot.nix` would both
declare `flake.modules.nixos.boot` and silently **merge** — with each other
and with the shared `boot` category. So:

- host-specific files end in `-<host>`: `boot-cube.nix`,
  `hardware-tenacity.nix`, `nixpkgs-stateVersion-durandal.nix`.
- user-specific files start with the user where the name would otherwise
  be generic: `elly-git.nix`, `elly-user.nix`.

A file that's inherently unique (`b550-suspend-fix.nix`) doesn't need one.
`just modules` reports a collision if you miss one; `just add-module`
refuses or warns about a taken name up front.

## Not a module: entry points

Files sitting directly in `host-config/` or `users-config/` — not in a
host's or user's directory — are **entry points**: `hosts.nix`, each
`<host>-configuration.nix`, `elly-home-manager.nix`. They list which
categories a host or the Home Manager config imports. Neither directory is
a category itself, so nothing collects a file placed there: a module
dropped at `host-config/foo.nix` reaches no host, and because it sits
outside every category tree, `just modules`' orphan check skips it too.
Put modules one level down, in the host's or user's directory.

## Worked example: cube's VM wiring

`virtualization-cube.nix` defines the `forge-runner` libvirt VM that only
cube runs. It used to sit in the shared `virtualization` category, kept out
of that category's own import list by a collector rule. When that rule was
removed (2026-09-28), the file moved to `host-config/cube/cube-vm/` (then
named `vms/`) — where
"cube only" is a property of the location instead of a quirk someone has
to know. That move is the pattern: anything whose placement needs an
explanation for why other hosts don't get it probably belongs under a host.

## See also

- [architecture.md](architecture.md) — how categories are collected.
- [hosts.md](hosts.md) — the roster, and which host wipes `/root`.
- [module-style-guide.md](module-style-guide.md) — how to write the file
  once you know where it goes.
- Skill `new-flake-module` and `just add-module` — scaffolding a module in
  the right place.
