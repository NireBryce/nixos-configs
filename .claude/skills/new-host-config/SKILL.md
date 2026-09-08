---
name: new-host-config
description: How to add a new host (nixosConfigurations or darwinConfigurations entry) to this repo.
---

# Adding a new host

## Applies to

Adding a machine to this repo: a `nireHost/<name>-configuration.nix` entry
point, a `nireHost/<name>/` directory of host-specific modules, and a line in
`hosts.nix`. The entry point sits directly under `nireHost/`, outside every
category tree on purpose (`new-flake-module` skill has why); the directory is
collected by its own `dirsAsCategory.nix` copy. Worked examples: durandal,
tenacity, cube, lysithea (darwin) — read the closest one first. (`nire-lego`
and `nire-installer`, removed 2026-08-27: git history if either is a closer
match.)

## Shape decisions — check `hosts.nix` for the roster, never assume a count

- **Workstation or handheld?** Workstation takes `kde-desktop`; handheld
  (tenacity) takes `jovian`. Both live in `desktop-env` — import the specific
  module, not the category.
- **Impermanence?** Default yes (durandal, tenacity wipe `/root` on boot),
  but `nire-cube` deliberately opts out — its real install is a plain root,
  not LUKS+impermanence. Read `WARN-impermanence.nix` and the
  `impermanence-initrd` skill either way; if opting out, say so in the host
  file's header like `cube-configuration.nix` does, including the
  `invariants.nix` interaction.
- **CPU/GPU?** AMD hosts import the shared `hardware` category (`amdcpu`,
  `amdgpu`). **Never add an `intel` sibling under `nire/hardware/`** —
  `dirsAsCategory` recurses into subdirectories, so it would apply to the AMD
  hosts too. An Intel host skips `hardware` and pulls a `nixos-hardware`
  module for the exact machine (e.g. `lenovo-thinkpad-x270`) from its own
  `<name>/hardware/hardware-<name>.nix` (`nire-testbed`, removed 2026-08-22,
  did this; no live Intel host exists to point at).
- **NixOS or darwin?** `mkHost`/`mkDarwinHost` in `hosts.nix`; darwin has no
  `elly-user`, no impermanence, and lands in `flake.darwinConfigurations`.
  `nire-lysithea` is the only example.

## Real hardware, or not installed yet?

The fork that matters most, easy to get backwards. Whether the machine has
actually booted this config is a live question — ask, or check on the host
(`just baseline`); switch state is not recorded in the repo.

**Real, scanned hardware**: capture `nixos-generate-config`'s
`fileSystems`/`boot.initrd.*` into `<name>/hardware/hardware-<name>.nix`,
wrapped as a flake-parts module — the raw generated file under `modules/`
as-is makes flake-parts resolve `modulesPath` itself and dies with a
misleading `infinite recursion` (`new-flake-module` has the wrapping shape).

**No hardware yet**: use the disko generator
`nire/impermanence/_disko/impermanence-luks-btrfs.nix` (curried over
`device`, `includeSecureboot`, `swapSize`; explained with a call-site example
in `flake/doc/disko-impermanence-layout.md`) instead of inventing a
`hardware-configuration.nix`. Nothing in the tree currently calls it; the
doc's inline example is the reference. Two rules:

- **Placeholder device path must be unmistakably fake**
  (`/dev/disk/by-id/REPLACE-ME-before-running-disko`), never plausible like
  `/dev/nvme0n1` — that path exists on real machines here (tenacity), and
  disko running against the wrong box would silently wipe real data. A fake
  path just fails loudly.
- **`includeSecureboot`/`swapSize` are per-host judgement calls** (durandal's
  additions, not universal). Set them explicitly with a one-line reason;
  don't silently inherit or drop.

Either way, if the host imports `impermanence`: the rollback
(`WARN-impermanence.nix`) needs a `root-blank` subvolume at the btrfs top
level, which only exists once disko runs against the real disk. The host can
be fully wired up here and still unable to boot — say so in the header.

## Naming: suffix anything host-specific

Module names are filenames and names in one class **merge**. Every file under
`<name>/` gets a host suffix — `hardware-cube.nix`, `boot-cube.nix` — so a
second host's file can't merge into the first's. (Durandal's unsuffixed
`hardware-configuration.nix` predates this rule and survives only because no
other host is named `configuration`. Don't repeat the gap.)

## `system.stateVersion`: copy the reasoning, not the value

`stateVersion` pins defaults to the release a host's data was first created
under and is never bumped — it is not "what we run now". A host with no data
starts on the **current** nixpkgs release pin:

```sh
nix eval --raw .#nixosConfigurations.nire-tenacity.config.system.nixos.release
```

Not durandal's `23.11` or tenacity's `25.05`. Write the comment explaining
the fresh-host case, not just the bare string.

## Don't copy hardware-keyed fixes blind

A fix tied to specific silicon (PCI IDs, board revision) belongs to the
machine it was diagnosed on — `durandal/fixes/b550-suspend-fix.nix` is
B550M-specific; copying it elsewhere is superstition even on AMD. Carry over
generic pieces; leave hardware-keyed fixes unless confirmed. Record the
decision either way in the host header (`cube-configuration.nix` is the
worked example of recording a deliberate omission).

## Wiring

1. `nireHost/<name>-configuration.nix` — imports + `networking.hostName`.
2. `nireHost/<name>/` with a verbatim copy of `dirsAsCategory.nix` and the
   `configuration/`, `hardware/`, `fixes/` subdirs the host needs.
3. `hosts.nix`: `mkHost` line in `flake.nixosConfigurations` (or
   `mkDarwinHost` in `darwinConfigurations`), pointing at
   `config.flake.modules.nixos.<name>Configuration`.
4. Secrets are not auto-enrolled: when the host actually needs
   `secrets.yaml`, add its SSH host key (via `ssh-to-age`) to `.sops.yaml`
   and run `sops updatekeys secrets.yaml`. Not preemptively.
5. `AGENTS.md`'s Architecture/State sections need a line — they have, every
   time so far.
6. `wiki/hosts.md`'s table, plus the `Imported by` line of every
   `wiki/categories/*.md` for categories this host now imports (or stops
   importing).

## Verifying

**`git add` before evaluating** — flakes ignore untracked files; a new module
tree silently doesn't exist until staged.

```sh
git add -A flake/modules/nireHost/<name> flake/modules/nireHost/<name>-configuration.nix flake/modules/nireHost/hosts.nix
just modules      # category-membership check; catches name collisions
cd flake && nix eval --raw .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath
```

Force the real toplevel — cheap attributes resolve fine while something else
is broken. (`just check` currently fails on a pre-existing `flake-parts`
formatter heuristic on `main`; confirm with `git stash` before blaming the
new host.)

None of this proves the host boots. Write "evaluates", not "verified" — the
first real boot in this repo's history found four defects a green eval and
build both missed.
