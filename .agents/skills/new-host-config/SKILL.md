---
name: new-host-config
description: Adds a new host to the repo.
when_to_use: Adding a machine, or a host entry point, host module directory or hosts.nix line.
---

# Adding a new host

**Needs:** bash-guards

## Applies to

Use this when adding a machine: a `host-config/<name>-configuration.nix` entry point, a `host-config/<name>/` directory of host modules, and a line in `hosts.nix`. The entry point sits directly under `host-config/`, outside every category tree (`new-flake-module` explains why). The directory is a category because its subfolders hold modules.

Read the closest worked example first: durandal, tenacity, cube, or lysithea (darwin). `forge-runner` is a VM guest on cube, not a fleet host (no `nire-` prefix; see its `hosts.nix` comment). `nire-lego` and `nire-installer` were removed 2026-08-27; see git history.

## Shape decisions (roster: `hosts.nix`, never assume a count)

- **Workstation or handheld?** A workstation uses `kde-desktop`; a handheld (tenacity) uses `jovian`. Both are in `desktop-env`. Import the module, not the category.
- **Impermanence?** The default is yes (durandal and tenacity wipe `/root`). `nire-cube` opts out (plain root, not LUKS+impermanence). Read `WARN-impermanence.nix` and skill `impermanence-initrd` either way. If opting out, say so in the host header as `cube-configuration.nix` does, including the `invariants.nix` interaction.
- **CPU/GPU?** AMD hosts import the shared `hardware` category (`amdcpu`, `amdgpu`). Do not add an `intel` sibling under `hardware-config/hardware/`: a category includes everything beneath it, so it would apply to AMD hosts too. Intel hosts skip `hardware` and pull the exact `nixos-hardware` module (for example `lenovo-thinkpad-x270`) from `<name>/hardware/hardware-<name>.nix`. `nire-testbed` did this before its removal on 2026-08-22; no live Intel host exists.
- **NixOS or darwin?** Use `mkHost` or `mkDarwinHost` in `hosts.nix`. Darwin has no impermanence and lands in `flake.darwinConfigurations`. `nire-lysithea` is the only example.

## Real hardware, or not installed yet?

Whether the machine has booted this config is a live question (`just baseline` on the host). The repo does not record it.

**Real, scanned hardware**: capture `nixos-generate-config`'s `fileSystems`/`boot.initrd.*` into `<name>/hardware/hardware-<name>.nix`, wrapped as a module file. Raw output is refused for asking for `modulesPath`; `new-flake-module` has the shape. Generated output may lack two things that `invariants.nix` fails `just check` over: `options = [ "fmask=0077" "dmask=0077" ]` on vfat `/boot`, and on an impermanence host `neededForBoot = true` on `/persist`.

**No hardware yet**: use the disko generator `general-config/impermanence/_disko/impermanence-luks-btrfs.nix` instead of inventing a `hardware-configuration.nix`. It is curried over `device`, `includeSecureboot` and `swapSize`; a call-site example is in `flake/doc/disko-impermanence-layout.md`. Grep for callers; the doc example is the reference.

- **Make the placeholder device path obviously fake** (`/dev/disk/by-id/REPLACE-ME-before-running-disko`). A plausible path like `/dev/nvme0n1` exists on tenacity, and disko run on the wrong machine wipes real data. A fake path fails loudly.
- **Set `includeSecureboot` and `swapSize` per host** (durandal's additions), explicitly, with a one-line reason.

Either way, an `impermanence` host's rollback needs a `root-blank` subvolume at the btrfs top level, which exists only once disko runs on the real disk. The host can be fully wired and still unable to boot; say so in the header.

## Naming: suffix anything host-specific

A name is one namespace across the whole tree (every class, modules and categories alike). A repeated name is an evaluation error naming both paths, one line per clash, with the kind of clash (dirs-as-categories v0.3.1: `module and module share the name <name>`, `module and category share ...`, `category and category share ...`, or `<name>.nix and <name>/default.nix share ...`). Give every file under `<name>/` a host suffix (`hardware-cube.nix`, `boot-cube.nix`). Every live host follows this, down to `nixpkgs-hostPlatform-<name>.nix` and `nixpkgs-stateVersion-<name>.nix` in `<name>/configuration/`.

## `system.stateVersion`: copy the reasoning, not the value

`stateVersion` pins defaults to the release the host's data was first created under, and is never bumped. A host with no data starts on the current release:

```sh
nix eval --raw .#nixosConfigurations.nire-tenacity.config.system.nixos.release
```

Do not copy another host's value (each lives in its `nixpkgs-stateVersion-<name>.nix`). Comment the fresh-host case, not just the string.

## Don't copy hardware-keyed fixes blind

Silicon-specific fixes (PCI IDs, board revision) belong to the machine they were diagnosed on: `durandal/fixes/b550-suspend-fix.nix` is B550M-specific. Carry over only generic pieces, and record the decision in the host header (`cube-configuration.nix` records a deliberate omission).

## Wiring

1. `host-config/<name>-configuration.nix`: set `includes.nixos = [ "<name>" … ];` and `nixos.networking.hostName` (copy `durandal-configuration.nix`).
2. `host-config/<name>/`: add the `configuration/`, `hardware/` and `fixes/` subdirs needed. Holding them is what makes `<name>` a category.
3. `hosts.nix`: add `mkHost` in `flake.nixosConfigurations` (or `mkDarwinHost` in `darwinConfigurations`) pointing at `config.flake.modules.nixos.<name>-configuration`.
4. Secrets are not auto-enrolled. When the host needs `secrets.yaml`, add its SSH host key (via `ssh-to-age`) to `.sops.yaml` and run `sops updatekeys secrets.yaml`. Do this when needed, not preemptively.
5. `AGENTS.md` keeps no host roster (it points at `hosts.nix` and `wiki/fleet/hosts.md`). Edit it only if its Safety section's list of hosts that wipe `/root` changes.
6. Run `just wiki-gen`. It adds the host's row to `wiki/fleet/hosts.md`; write that row's Role cell, the one hand-written column. Also update the `Imported by` line of every `wiki/config-structure/categories/*.md` for categories the host now imports.

## Verifying

Run `git add` first (flakes ignore untracked files):

```sh
git add -A flake/modules/host-config/<name> flake/modules/host-config/<name>-configuration.nix flake/modules/host-config/hosts.nix
just modules      # category-membership check; catches name collisions
cd flake && nix eval --raw .#nixosConfigurations.nire-<name>.config.system.build.toplevel.drvPath
```

Force the real toplevel; cheap attributes can resolve while something else is broken. If `just check` fails, confirm with `git stash` that the failure is not pre-existing before blaming the new host.

This does not prove the host boots. Write "evaluates", not "verified": the first real boot found four defects that a green eval and build missed.
