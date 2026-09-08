---
name: impermanence-initrd
description: How to edit impermanence/initrd config in this repo, and read real disk/mount state on a host that wipes /root on boot.
---

# Editing impermanence or initrd, and reading real disk state

## Applies to

`flake/modules/nire/impermanence/`, any `boot.initrd.*` option (systemd
stage 1 here since 2026-08-10 — see History), and reading disk/mount state
on one of the hosts that wipes `/root` on boot. Use before touching
anything under `nire/impermanence/`, any `boot.initrd` option, or before
trusting `lsblk`/`findmnt`/mounted-`/etc` output on these hosts.

**Read `WARN-impermanence.nix` before
changing anything near this.** This mechanism wipes `/root` on boot on most
hosts in this repo — see `CLAUDE.md` Safety section for which ones, current
as of the date on that file. The following has actually happened here.

## The shell's view of the machine is a mount namespace

`lsblk`, `findmnt` and `/etc` all describe **that** namespace — faithfully,
and about the wrong world. On tenacity they reported `/` as a tmpfs,
`/dev/mapper/enc` mounted at `/etc/xdg`, empty UUID columns, and an `/etc`
that is missing files the system definitely has. Read literally, the first
of those says *the disk does not match the hardware module*, which is a
stop-and-ask condition. It matched perfectly — the shell was just looking at
the wrong namespace.

Sources that are not rewritten, all unprivileged:

- `/proc/1/mountinfo` — PID 1's mount table, the host's
- `/dev/disk/by-uuid/` — udev's symlinks, so LUKS and filesystem UUIDs resolve
- `/run/current-system/…` and any `/nix/store` path — for what `/etc` should hold

`btrfs subvolume list` needs privileges and is worth asking Elly to run; it
answers whether `root-blank` exists without mounting anything:

```sh
sudo btrfs subvolume list -a /
```

Read the subvolids as well as the names — a `/root` far above its
neighbours is the rollback *demonstrably running*, a stronger fact than
`root-blank` merely existing. (Confirmed this way on tenacity: 607 vs.
257–265 on first boot. Confirmed a second way — reading the boot journal for
the delete-then-snapshot sequence rather than the mount — on durandal's
first boot into this config; see `wiki/history.md`'s "Confirmed-on-hardware
facts" for both.)

## History

**Scripted stage 1's `@name@` templating trap no longer applies — this repo
migrated to systemd stage 1 on 2026-08-10** (nixpkgs deprecated scripted
initrd the same week, removal scheduled for 26.11). Kept here in case
`git log`/old docs surface `boot.initrd.postResumeCommands`-shaped code:
its hook strings were pasted into `stage-1-init.sh` by a fixed sequence of
`substituteInPlace --replace-fail` passes, so naming a *later* placeholder
(e.g. `@preLVMCommands@`) inside an *earlier* one's string — even in a
comment — pasted a whole other script in and executed most of it. Full
account of the migration and what it changed: `wiki/lessons-learned.md`
§28, `WARN-impermanence.nix`'s own history comments.
