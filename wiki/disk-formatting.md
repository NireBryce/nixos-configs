# New host disk formatting (LUKS + btrfs + impermanence)

_Last modified: 2026-10-20_

Runbook for the disk step of adding a new host: the order of operations and
the safety warnings for running `disko` on a real disk. Skill
`new-host-config` covers the whole host-adding decision tree, and
[flake/doc/disko-impermanence-layout.md](<../flake/doc/disko-impermanence-layout.md>)
covers the generator's mechanism. Read this page once before formatting; it
doesn't replace either.

**This is the destructive step.** `disko` partitions a real disk. Read
[`../CLAUDE.md`](../CLAUDE.md)'s Safety section before running any of this
against real hardware, and see the placeholder-device rule below before
touching a device path at all.

> **Condensed version:**
> [disk-formatting-for-agents.md](disk-formatting-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [What this is for](#what-this-is-for)
- [Decide before touching a disk](#decide-before-touching-a-disk)
- [Wiring the layout in](#wiring-the-layout-in)
- [Actually formatting the disk](#actually-formatting-the-disk)
- [What depends on this having actually run](#what-depends-on-this-having-actually-run)
- [Confirming the rollback actually works](#confirming-the-rollback-actually-works)
- [Traps](#traps)
- [See also](#see-also)

## What this is for

A **new** host that will wipe `/root` on every boot, like durandal and
tenacity and unlike `nire-cube`. Impermanence is a per-host decision, not a
default: [categories/impermanence.md](categories/impermanence.md) lists which
hosts import it, and the `new-host-config` skill's "Impermanence or not?"
section covers deciding for a new host. A host that opts out, like `nire-cube`
and the handhelds, can ignore this page; say so in the host's own header the
way `cube-configuration.nix` does.

`general-config/impermanence/_disko/impermanence-luks-btrfs.nix` reproduces
durandal and tenacity's hand-run layout as a reusable generator: one
LUKS-encrypted partition, btrfs inside it, subvolumes for
`root`/`home`/`nix`/`persist`/`log`, and an unmounted `root-blank` subvolume.
**Nothing in this repo currently calls it.** Every live host has a
hand-written `hardware-*.nix` from a real install, or (cube) never adopted
this layout. The disko doc's inline example is the only reference until a
new host uses it.

## Decide before touching a disk

Per the disko doc and the `new-host-config` skill, in order:

1. **The real device path**, found on the target machine (`lsblk`,
   `ls /dev/disk/by-id/`) — not guessed from another host's layout.
2. **`includeSecureboot`** (default off) — durandal's own addition
   (`/var/lib/sbctl`), not universal. Decide for this host explicitly.
3. **`swapSize`** (default `null`, no swap) — set, it makes a swapfile
   inside LUKS. Durandal and tenacity both instead have a raw swap partition
   outside LUKS, which is why their `swapDevices` use `randomEncryption`.
   Decide for this host explicitly, don't silently inherit either default.
4. **LUKS unlock method** — the generator sets none of `keyFile` /
   `passwordFile` / `enrollFido2`, so disko's own default applies:
   interactive passphrase, at partition time and at every later boot. That's
   what durandal and tenacity do. Automating it (key file on
   removable media, TPM/FIDO2 enrollment) is a real per-host decision the
   template deliberately doesn't make for you.

## Wiring the layout in

Call the generator curried with this host's own parameters, in its
`imports` list — the disko doc's own example:

```nix
imports = [
    (import ../../general-config/impermanence/_disko/impermanence-luks-btrfs.nix {
        device = "/dev/disk/by-id/REPLACE-ME-before-running-disko";
    })
];
```

Two things easy to get backwards here:

- **The placeholder device path must be unmistakably fake.** Never a
  plausible-looking one like `/dev/nvme0n1` — that path exists on a real
  machine here already (tenacity), and disko running against the wrong box
  silently wipes real data. A nonexistent path just fails loudly. Replace it
  only once you're certain which disk on which machine you're pointed at.
- **This generator produces the disk layout only.** The `impermanence`
  category import — which brings in `WARN-impermanence.nix` (the rollback
  unit), the hibernation guards, and `environment.persistence` — is a
  separate step in the host's own config. Both have to happen.

## Actually formatting the disk

This repo has no live install/bootstrap runbook (the live-USB installer
`nire-installer` was removed 2026-08-27; see [history.md](history.md)). What
follows is disko's standard interface, not run end to end in this repo. The
generator itself is evaluation-verified only (see the doc's "What was actually
verified" section), never against real hardware.

1. Boot install media on the target machine.
2. `git clone` this repo (or otherwise get the flake onto the install media)
   with the new host's config, including the wired-in generator above,
   already committed — `git add` first, since flakes in a git repo ignore
   untracked files.
3. Run disko against the real device — the command quoted from disko's
   docs, **not run end to end on any host in this repo**. From the repo's
   `flake/` directory (the flake lives there, not at the repo root):

   ```sh
   sudo nix --experimental-features "nix-command flakes" run \
     github:nix-community/disko/latest -- --mode destroy,format,mount \
     --flake .#<new-host-name>
   ```

   `--flake` resolves the host's `diskoConfigurations.<name>` output, or
   else the disko module of its `nixosConfigurations.<name>` entry — the
   fallback is this repo's shape, since the generator is wired into the
   host config itself.
4. Once partitioned and mounted, install normally (`nixos-install` or
   equivalent) against the flake.

## What depends on this having actually run

**A host can be fully wired up here and still be unable to boot**:
`WARN-impermanence.nix`'s rollback depends on the `root-blank` subvolume
existing at the btrfs top level, and that subvolume only exists once disko
has actually run against the real disk. Eval and build prove nothing about
it. Say so in the new host's header if wired in before the disk step, the
way `nire-lego`'s did (git history).

First boot also needs the KDE half of the hibernation guard —
`root-rollback/restore-root/kde-sleepmode.nix` sets `SleepMode=1` in `powerdevil.rc`,
matching `WARN-impermanence.nix`'s `nohibernate` kernel parameter, or
suspend breaks outright. It's `homeManager`-class and reaches every desktop
host through `elly-home-manager` automatically.

## Confirming the rollback actually works

The machine coming up proves nothing: a failed rollback that wipes nothing
looks like a working system until the disk fills. The method used on
tenacity is to compare the `/root` subvolid across a reboot.

```sh
findmnt -no SOURCE /        # or: awk '$5=="/"{print $NF}' /proc/1/mountinfo
journalctl -b 0 -u restore-root
```

The subvolid must change on every boot. On tenacity it moved 607 → 622 → 627
across successive boots, against neighbouring subvolumes at 257–265 (a
`/root` subvolid far above its siblings shows the rollback running, not just
present). Run this check on the new host before calling the rollback
confirmed; AGENTS.md's State section explains why the result isn't recorded in
the repo.

## Traps

- **The shell's view of the machine can be scoped wrong.** `lsblk`,
  `findmnt` and `/etc` are scoped to the shell's mount namespace and can
  describe a different disk layout. Use `/proc/1/mountinfo`,
  `/dev/disk/by-uuid/`, and `/run/current-system` instead (skill
  `impermanence-initrd`).
- **Check that hibernation is disabled; don't assume it's absent.**
  `systemd-gpt-auto-generator` can activate a swap partition and wire up
  `/sys/power/resume` with no `resume=` on the kernel command line and no
  `swapDevices` entry, so the config proves nothing about the running
  machine. `WARN-impermanence.nix`'s history section has the account of how
  this went wrong here once.
- **A `just check`/toplevel build proves the config evaluates, not that the
  disk is formatted or the rollback runs.** Both are runtime facts; see the
  two sections above.

## See also

- [flake/doc/disko-impermanence-layout.md](<../flake/doc/disko-impermanence-layout.md>)
  — the generator itself: what it produces, what it deliberately leaves out,
  and exactly how it was verified (and how it wasn't).
- `WARN-impermanence.nix`
  (`flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`) —
  the rollback module this disk layout exists to support; read before
  changing anything near it, every time.
- Skill `new-host-config` (`.agents/skills/new-host-config/SKILL.md`) — the
  full host-adding decision tree this page is one piece of.
- Skill `impermanence-initrd`
  (`.agents/skills/impermanence-initrd/SKILL.md`) — the initrd-specific sharp
  edges referenced above.
- [categories/impermanence.md](categories/impermanence.md) — what's in the
  category, which hosts import it today.
- [impermanence-and-secrets.md](impermanence-and-secrets.md) — the
  cross-cutting topic page (impermanence and secrets together).
- [hosts.md](hosts.md) — current roster and per-host boot/switch status.
