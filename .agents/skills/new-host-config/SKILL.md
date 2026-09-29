---
name: new-host-config
description: How to add a new host to this repo.
---

# Adding a new host

## Applies to

Adding a machine: a `host-config/<name>-configuration.nix` entry point, a
`host-config/<name>/` directory of host modules, and a line in `hosts.nix`.
The entry point sits directly under `host-config/`, outside every category
tree on purpose (`new-flake-module` has why); the directory is collected by
its own `dirsAsCategory.nix` copy. Read the closest worked example first:
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
  `amdgpu`). **Never add an `intel` sibling under `general-config/hardware/`**
  — `dirsAsCategory` recurses, so it would apply to AMD hosts too. Intel
  hosts skip `hardware` and pull the exact `nixos-hardware` module (e.g.
  `lenovo-thinkpad-x270`) from `<name>/hardware/hardware-<name>.nix`
  (`nire-testbed`, removed 2026-08-22, did; no live Intel host).
- **NixOS or darwin?** `mkHost`/`mkDarwinHost` in `hosts.nix`; darwin has no
  `elly-user`, no impermanence, lands in `flake.darwinConfigurations`.
  `nire-lysithea` is the only example.

## Real hardware, or not installed yet?

Easy to get backwards. Whether the machine has booted this config is a live
question (`just baseline` on the host); not recorded in the repo.

**Real, scanned hardware**: capture `nixos-generate-config`'s
`fileSystems`/`boot.initrd.*` into `<name>/hardware/hardware-<name>.nix`,
wrapped as a flake-parts module (raw output dies with a misleading
`infinite recursion`; `new-flake-module` has the shape). Generated output
may lack two things `invariants.nix` fails `just check` over:
`options = [ "fmask=0077" "dmask=0077" ]` on vfat `/boot`, and on an
impermanence host `neededForBoot = true` on `/persist`.

**No hardware yet**: use the disko generator
`general-config/impermanence/_disko/impermanence-luks-btrfs.nix` (curried
over `device`, `includeSecureboot`, `swapSize`; call-site example in
`flake/doc/disko-impermanence-layout.md`) rather than inventing a
`hardware-configuration.nix`. No module calls it currently; the doc example
is the reference.

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

Names in one class **merge**. Every file under `<name>/` gets a host suffix
(`hardware-cube.nix`, `boot-cube.nix`). Durandal's unsuffixed
`hardware-configuration.nix` predates the rule; don't repeat it.

## `system.stateVersion`: copy the reasoning, not the value

Pins defaults to the release the host's data was first created under; never
bumped. A host with no data starts on the **current** release:

```sh
nix eval --raw .#nixosConfigurations.nire-tenacity.config.system.nixos.release
```

Not durandal's `23.11` or tenacity's `25.05`. Comment the fresh-host case,
not just the string.

## Don't copy hardware-keyed fixes blind

Silicon-specific fixes (PCI IDs, board revision) belong to the machine
diagnosed: `durandal/fixes/b550-suspend-fix.nix` is B550M-specific. Carry
generic pieces only; record the decision in the host header
(`cube-configuration.nix` records a deliberate omission).

## Wiring

1. `host-config/<name>-configuration.nix` — imports + `networking.hostName`.
2. `host-config/<name>/` with a verbatim `dirsAsCategory.nix` and the
   `configuration/`, `hardware/`, `fixes/` subdirs needed.
3. `hosts.nix`: `mkHost` in `flake.nixosConfigurations` (or `mkDarwinHost`
   in `darwinConfigurations`) pointing at
   `config.flake.modules.nixos.<name>Configuration`.
4. Secrets are not auto-enrolled: when the host needs `secrets.yaml`, add its
   SSH host key (via `ssh-to-age`) to `.sops.yaml` and `sops updatekeys
   secrets.yaml`. Not preemptively.
5. `AGENTS.md` Architecture/State sections need a line (always have).
6. `wiki/hosts.md` table, plus the `Imported by` line of every
   `wiki/categories/*.md` for categories the host now imports.

## Verifying

`git add` first (flakes ignore untracked files):

```sh
git add -A flake/modules/host-config/<name> flake/modules/host-config/<name>-configuration.nix flake/modules/host-config/hosts.nix
just modules      # category-membership check; catches name collisions
cd flake && nix eval --raw .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath
```

Force the real toplevel; cheap attributes resolve while something else is
broken. If `just check` fails, confirm with `git stash` that it isn't
pre-existing before blaming the new host.

This doesn't prove the host boots: write "evaluates", not "verified" — the
first real boot found four defects a green eval and build missed.
