# Plan: bring `nire-tenacity` back

Written 2026-08-09 on `flake-parts-consolidation`, which is durandal-only. The
den restructure dropped tenacity rather than migrating it; its sops enrollment
survived, so the key is still valid.

rename this file to `<timestamp>-TENACITY-PLAN-(COMPLETED).md` when finished

---

## Resolved 2026-08-09 — steps 1-7 done

All seven steps landed. Both hosts evaluate, `nix flake check --all-systems`
passes, `just modules` is clean.

Two things the plan got wrong, both found by reading the config the machine
actually ran rather than the sibling branch's stub:

  **stateVersion is 25.05**, not the 23.11 the stub implied — that looks copied
  from durandal. The backup branch has durandal 23.11 and tenacity 25.05 on
  adjacent lines.

  **Tenacity had Home Manager**, and the same config as durandal:
  `homeConfigurations."nire-tenacity-hm-elly"` importing the identical
  `user-elly` tree. The sibling's handoff says it had none, which is true of
  that branch but not of the machine. So its dotfiles are probably already
  HM-owned and it is no riskier to switch than durandal.

And the impermanence question resolved differently than expected. The blocker
was never the host-specific unit name: `boot.initrd.systemd.services` is not
rendered at all under scripted stage 1, which is what both hosts run, so the
whole service was inert. Restoring `postResumeCommands` — what `origin/main` and
`origin/flake-parts` both use, and what these machines have been running — fixed
it for both hosts at once. Tenacity now imports `boot` and wipes `/root` on boot,
as it did before the restructure. See `linux-flake/impermanence-stage1.md`.

Also corrected: `jovian.nix` is a *generic handheld* module — machines with
built-in controllers that occasionally launch a SteamOS session — not tenacity's.
A second handheld would import it too. The plan and both host configs described
it as host-specific.

**Prerequisite before switching tenacity**, which cannot be checked from here:
the rollback runs `btrfs subvolume snapshot /mnt/root-blank /mnt/root`, so a
`root-blank` subvolume must exist on that machine's btrfs top level. It should,
from when it last ran impermanence.


---

## Where the blueprint came from

**Not `origin/main`.** It has no tenacity configuration — `modules/hosts/`
contains durandal alone and `hosts.nix` declares one `nixosConfiguration`. The
only traces there are two commented `.justfile` lines and the sops enrollment,
exactly as here.

Tenacity host files exist on three refs:

| ref | date | files |
|---|---|---|
| `origin/backup-before-flake-parts-happened` | 2026-01-30 | 3 — the last *complete* config |
| `origin/claude` | 2025-12-20 | 3 — same layout, older |
| `origin/flake-parts` | 2026-08-07 | 2 — flake-parts-shaped, but a stub |

The January backup is the functional blueprint; the sibling is the shape.

```sh
git show "origin/backup-before-flake-parts-happened:linux-flake/configs/hosts/nire-tenacity/hw-conf/hardware-configuration.nix"
git show "origin/backup-before-flake-parts-happened:linux-flake/configs/system-config/wm/gaming-handheld/jovian.nix"
git show "origin/flake-parts:linux-flake/modules/hosts/tenacity/tenacity-configuration.nix"
```

**The hardware config is being reused as-is.** Elly confirms nothing about the
machine has changed since January, so the UUIDs stand and it does not need
regenerating. Recorded because it cannot be checked from the dev machine: if a
mount fails on first boot, this assumption is the first thing to revisit.

## What tenacity needs, and what already exists

| need | on this branch | action |
|---|---|---|
| hostname, `stateVersion = "23.11"`, hostPlatform | pattern in `durandal-configuration.nix` | write new |
| hardware config — LUKS `enc`, btrfs `root`/`home`/`nix`/`persist`/`log`, `kvm-amd`, nvme + thunderbolt | absent | copy from backup, wrap |
| bootloader — systemd-boot, `limine.enable = mkForce false` | absent | new module |
| Jovian/SteamOS, decky-loader, handheld-daemon, plasma6 | `nire/desktop-env/jovian/jovian.nix` | wire up |
| peripherals — logitech-g600, zsa-moonlander | `nire/peripherals/` category | reuse |
| user, shells, packages | `elly` + package categories | reuse |

Two things already went right without anyone planning them:

- **`jovian.nix` is further along than the old layout.** It already merges what
  were two files there (`jovian.nix` + `handheld-daemon.nix`), and its two
  evaluation errors — `adjustor`, removed from nixpkgs, and
  `inputs.jovian.decky-loader`, which that flake does not expose — were fixed
  during the port in `1d8fbcc`. It has never been evaluated by a host, though,
  so expect it to surface more.
- **The peripherals tenacity used are already categorised**, unchanged.

The one thing `jovian.nix` lacks is `boot.loader`, which the sibling branch kept
separate as `boot-handheld.nix`. It force-disables limine — nothing on this
branch references limine at all, so that `mkForce false` may now be dead weight;
check before copying it.

## Decisions to make first

### 1. Impermanence — the safety-critical one

Tenacity's disk layout has `persist` and `log` subvolumes marked
`neededForBoot`, which only makes sense with impermanence. But on this branch
impermanence *is* the `boot` category, so importing `boot` at all gives tenacity
a `/root` wipe — and `WARN-impermanence.nix:67` is hardcoded to durandal:

```nix
after = [ "dev-mapper-enc.device" "systemd-cryptsetup@nire-durandal.service" ];
#TODO: fix me to be general this is just to make it work for now
```

That TODO is now load-bearing. Both machines name their LUKS device `enc`, so
`dev-mapper-enc.device` is fine; the `systemd-cryptsetup@nire-durandal.service`
line is what has to become per-host. The sibling branch avoided the question by
importing impermanence from durandal only, never from a role.

**Nothing should import `nire/boot/` for tenacity until this is resolved.** The
choices are to generalise the unit reference, or to decide tenacity runs without
impermanence and leave `persist`/`log` as ordinary subvolumes.

### 2. Mount options are already duplicated on durandal

Found while planning this, not caused by it. `fileSystems.<n>.options` is
`listOf str`, and both the hwconfig and `WARN-impermanence.nix` declare
`compress=zstd`/`noatime`, so they concatenate. Today, on durandal:

```
/          ["x-initrd.mount","subvol=root","compress=zstd","noatime","compress=zstd","noatime"]
/home      ["subvol=home","compress=zstd","compress=zstd"]
/nix       ["x-initrd.mount","subvol=nix","compress=zstd","noatime","compress=zstd","noatime"]
/persist   ["x-initrd.mount","subvol=persist","compress=zstd","noatime","compress=zstd","noatime"]
/var/log   ["x-initrd.mount","subvol=log","compress=zstd","noatime","compress=zstd","noatime"]
```

Benign — mount accepts repeated options — but it is the same one-owning-module
rule that `.blerc` and `home.sessionPath` both broke, and it decides how
tenacity's hwconfig should be written. The sibling's tenacity hwconfig declares
only `subvol=`, letting impermanence supply the rest, which is the right shape.

Worth fixing on durandal in the same change, and verifying with `just diff`
that the resulting option *set* is unchanged.

### 3. `desktop-env` is never imported as a category

Durandal imports `kde` directly to avoid pulling in jovian; tenacity would
import `jovian` directly for the mirror reason. So the category exists and no
host uses it. Either split it (`desktop-env/kde/`, `desktop-env/handheld/`) or
accept that direct module imports are the idiom for mutually-exclusive
alternatives, and say so in `dirsAsCategory.md`.

### 4. Package parity

The sibling recorded an explicit decision that tenacity gets the full desktop
GUI set — vscode, gimp, libre-office, zoom, github-desktop — on purpose, with
the structure left able to split later. Confirm that still holds; if it does,
tenacity's config imports the same package categories durandal does and there is
nothing to do.

## Steps

Each assumes the previous. Nothing here can be built or switched from the dev
machine; every check below is evaluation.

1. **Settle decision 1.** Either generalise the cryptsetup unit reference in
   `WARN-impermanence.nix`, or record that tenacity goes without impermanence.
   Everything about `nire/boot/` depends on it.

2. **Fix the duplicated mount options** (decision 2), on durandal, on its own,
   before tenacity exists — so `just diff` attributes the change to the right
   cause. Confirm the option *set* is unchanged, only the duplicates gone.

3. **Add the hardware config.** Copy from the January backup and wrap it as a
   flake-parts module *in the same commit* — a raw `nixos-generate-config` file
   under `modules/` makes flake-parts resolve `modulesPath` through its own
   `_module.args` and evaluation dies with `infinite recursion`, naming
   `modulesPath` rather than the file. This broke the sibling branch twice.
   Strip `compress=zstd`/`noatime` per decision 2 if impermanence is providing
   them. Place under `modules/nireHost/tenacity/hardware/`, so the `tenacity`
   category collects it.

4. **Add `boot-handheld.nix`** under `modules/nireHost/tenacity/hardware/`,
   mirroring `boot-durandal.nix`. Drop the limine `mkForce false` unless
   something actually enables limine.

5. **Write `modules/nireHost/tenacity-configuration.nix`**, beside
   `durandal-configuration.nix` and *not* inside a category directory —
   dirsAsCategory collects from subdirectories only, and a host definition
   should not be a member of anything. Import the `tenacity` category, the
   shared categories, `jovian` directly, and `elly`.

6. **Add the host to `hosts.nix`** — one `mkHost "x86_64-linux"` line.

7. **Remove the `ORPHAN-OK` marker from `jovian.nix`.** It stops being an
   orphan, and leaving the marker would suppress a real finding later.

8. **Verify.** `just check` builds both hosts' toplevels and both home
   activations. `just modules` must stay clean — watch for a filename colliding
   with a category name, which merges silently. `just diff HEAD` must report
   durandal unchanged; if it does not, something meant for tenacity leaked into
   a shared category.

## What cannot be verified from here

Both hosts are `x86_64-linux`; this machine is aarch64-darwin. Nothing in this
branch has been built or switched, tenacity least of all — it has not
evaluated since March and its jovian module has never been evaluated by any
host at all. Expect the first `just build` on the machine to find things that
evaluation cannot.

Home Manager applies doubly here: tenacity has never
had Home Manager, so every dotfile it manages is a potential collision on first
activation, where durandal's are at least already HM-owned.
