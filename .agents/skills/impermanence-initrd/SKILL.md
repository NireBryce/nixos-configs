---
name: impermanence-initrd
description: How to edit impermanence/initrd config in this repo, and read real disk/mount state on a host that wipes /root on boot.
when_to_use: Touching boot.initrd options or impermanence config, or before trusting lsblk, findmnt, or /etc output on a host that wipes /root.
---

# Editing impermanence or initrd, and reading real disk state

## Applies to

`flake/modules/general-config/impermanence/`, any `boot.initrd.*` option
(systemd stage 1 since 2026-08-10 — see History), and reading disk/mount
state on a host that wipes `/root` on boot. Use before touching those, or
before trusting `lsblk`/`findmnt`/mounted-`/etc` output on these hosts.

**Read `WARN-impermanence.nix` before changing anything near this.** Which
hosts wipe `/root`: `CLAUDE.md` Safety section.

## The shell's view is a mount namespace

`lsblk`, `findmnt` and `/etc` describe **that** namespace — faithfully, about
the wrong world. On tenacity they showed `/` as tmpfs, `/dev/mapper/enc` at
`/etc/xdg`, empty UUID columns, and an `/etc` missing files the system has.
Read literally that says *the disk does not match the hardware module* (a
stop-and-ask condition); it matched perfectly.

Unrewritten sources, all unprivileged:

- `/proc/1/mountinfo` — PID 1's (the host's) mount table
- `/dev/disk/by-uuid/` — udev symlinks; LUKS and filesystem UUIDs resolve
- `/run/current-system/…`, any `/nix/store` path — what `/etc` should hold

`btrfs subvolume list` needs privileges; ask the user to run it. It shows
whether `root-blank` exists without mounting:

```sh
sudo btrfs subvolume list -a /
```

Read subvolids too: a `/root` far above its neighbours is the rollback
*demonstrably running*, stronger than `root-blank` merely existing
(tenacity: 607 vs. 257–265 on first boot). Second method: boot journal for
the delete-then-snapshot sequence (durandal's first boot into this config).
Both: `wiki/history.md`'s "Confirmed-on-hardware facts".

## History

**Scripted stage 1's `@name@` templating trap no longer applies** — migrated
to systemd stage 1 2026-08-10 (nixpkgs deprecated scripted initrd that week;
removal scheduled 26.11). For old `boot.initrd.postResumeCommands`-shaped
code: hook strings were pasted into `stage-1-init.sh` by a fixed sequence of
`substituteInPlace --replace-fail` passes, so naming a *later* placeholder
(e.g. `@preLVMCommands@`) inside an *earlier* one's string — even in a
comment — pasted a whole other script in and executed most of it. Full
account: `wiki/lessons-learned.md` §28, `WARN-impermanence.nix` history
comments.
