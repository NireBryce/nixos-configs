---
name: new-host-config
description: Adds a new host to the repo.
when_to_use: Adding a machine, or a host entry point, host module directory or hosts.nix line.
---

# Adding a new host

## Applies to

Adding a machine: a `host-config/<name>-configuration.nix` entry point, a
`host-config/<name>/` directory of host modules, and a line in `hosts.nix`.
The entry point sits directly under `host-config/`, outside every category
tree on purpose (`new-flake-module` has why); the directory is a category
because its subfolders hold modules. Read the closest worked example first:
durandal, tenacity, cube, lysithea (darwin). `forge-runner` is a VM guest on
cube, not a fleet host (no `nire-` prefix; see its `hosts.nix` comment).
(`nire-lego`, `nire-installer` removed 2026-08-27: git history.)

## Shape decisions (roster: `hosts.nix`, never assume a count)

- **Workstation or handheld?** Workstation: `kde-desktop`; handheld
  (tenacity): `jovian`. Both in `desktop-env` — import the module, not the
  category.
- **Impermanence?** Default yes (durandal, tenacity wipe `/root`); `nire-cube`
  opts out (plain root, not LUKS+impermanence). Read `WARN-impermanence.nix`
  and skill `impermanence-initrd` either way; if opting out, say so in the
  host header like `cube-configuration.nix`, including the `invariants.nix`
  interaction.
- **CPU/GPU?** AMD hosts import the shared `hardware` category (`amdcpu`,
  `amdgpu`). **Never add an `intel` sibling under `hardware-config/hardware/`**
  — a category includes everything beneath it, so it would apply to AMD
  hosts too. Intel
  hosts skip `hardware` and pull the exact `nixos-hardware` module (e.g.
  `lenovo-thinkpad-x270`) from `<name>/hardware/hardware-<name>.nix`
  (`nire-testbed`, removed 2026-08-22, did; no live Intel host).
- **NixOS or darwin?** `mkHost`/`mkDarwinHost` in `hosts.nix`; darwin has no
  impermanence, lands in `flake.darwinConfigurations`.
  `nire-lysithea` is the only example.

## Real hardware, or not installed yet?

Easy to get backwards. Whether the machine has booted this config is a live
question (`just baseline` on the host); not recorded in the repo.

**Real, scanned hardware**: capture `nixos-generate-config`'s
`fileSystems`/`boot.initrd.*` into `<name>/hardware/hardware-<name>.nix`,
wrapped as a module file (raw output is refused for asking for
`modulesPath`; `new-flake-module` has the shape). Generated output
may lack two things `invariants.nix` fails `just check` over:
`options = [ "fmask=0077" "dmask=0077" ]` on vfat `/boot`, and on an
impermanence host `neededForBoot = true` on `/persist`.

**No hardware yet**: use the disko generator
`general-config/impermanence/_disko/impermanence-luks-btrfs.nix` (curried
over `device`, `includeSecureboot`, `swapSize`; call-site example in
`flake/doc/disko-impermanence-layout.md`) rather than inventing a
`hardware-configuration.nix`. Grep for callers; the doc example is the
reference.

- **Placeholder device path must be unmistakably fake**
  (`/dev/disk/by-id/REPLACE-ME-before-running-disko`), never plausible like
  `/dev/nvme0n1` (exists on tenacity; disko on the wrong box wipes real
  data). A fake path fails loudly.
- **`includeSecureboot`/`swapSize` are per-host judgement calls** (durandal's
  additions). Set explicitly with a one-line reason.

Either way, an `impermanence` host's rollback needs a `root-blank` subvolume
at the btrfs top level, which exists only once disko runs on the real disk.
The host can be fully wired and still unable to boot — say so in the header.

## Naming: suffix anything host-specific

A name is one namespace across the whole tree (every class, modules and
categories alike), and a repeated name is an evaluation error naming both
paths, one line per clash, saying which kind it is (dirs-as-categories v0.3.1:
`module and module share the name <name>`, `module and category share ...`,
`category and category share ...`, or `<name>.nix and <name>/default.nix
share ...`). Every file under `<name>/` gets a host suffix
(`hardware-cube.nix`, `boot-cube.nix`). Every live host follows it, down to
`nixpkgs-hostPlatform-<name>.nix` and `nixpkgs-stateVersion-<name>.nix` in
`<name>/configuration/`.

## `system.stateVersion`: copy the reasoning, not the value

Pins defaults to the release the host's data was first created under; never
bumped. A host with no data starts on the **current** release:

```sh
nix eval --raw .#nixosConfigurations.nire-tenacity.config.system.nixos.release
```

Not another host's value (each lives in its
`nixpkgs-stateVersion-<name>.nix`). Comment the fresh-host case,
not just the string.

## Don't copy hardware-keyed fixes blind

Silicon-specific fixes (PCI IDs, board revision) belong to the machine
diagnosed: `durandal/fixes/b550-suspend-fix.nix` is B550M-specific. Carry
generic pieces only; record the decision in the host header
(`cube-configuration.nix` records a deliberate omission).

## Wiring

1. `host-config/<name>-configuration.nix` — `includes.nixos = [ "<name>" … ];`
   and `nixos.networking.hostName` (copy `durandal-configuration.nix`).
2. `host-config/<name>/` with the `configuration/`, `hardware/`, `fixes/`
   subdirs needed; holding them is what makes `<name>` a category.
3. `hosts.nix`: `mkHost` in `flake.nixosConfigurations` (or `mkDarwinHost`
   in `darwinConfigurations`) pointing at
   `config.flake.modules.nixos.<name>-configuration`.
4. Secrets are not auto-enrolled: when the host needs `secrets.yaml`, add its
   SSH host key (via `ssh-to-age`) to `.sops.yaml` and `sops updatekeys
   secrets.yaml`. Not preemptively.
5. `AGENTS.md` keeps no host roster (it points at `hosts.nix` and
   `wiki/fleet/hosts.md`); edit it only if its Safety section's list of hosts that
   wipe `/root` changes.
6. `just wiki-gen` (adds the host's row to `wiki/fleet/hosts.md`; write its Role
   cell, the one hand-written column), plus the `Imported by` line of every
   `wiki/config-structure/categories/*.md` for categories the host now imports.

## Verifying

`git add` first (flakes ignore untracked files):

```sh
git add -A flake/modules/host-config/<name> flake/modules/host-config/<name>-configuration.nix flake/modules/host-config/hosts.nix
just modules      # category-membership check; catches name collisions
cd flake && nix eval --raw .#nixosConfigurations.nire-<name>.config.system.build.toplevel.drvPath
```

Force the real toplevel; cheap attributes resolve while something else is
broken. If `just check` fails, confirm with `git stash` that it isn't
pre-existing before blaming the new host.

This doesn't prove the host boots: write "evaluates", not "verified" — the
first real boot found four defects a green eval and build missed.
