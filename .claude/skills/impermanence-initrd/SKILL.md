---
name: impermanence-initrd
description: How to edit impermanence/initrd config in this repo, and read real disk/mount state on a host that wipes /root on boot.
---

# Editing impermanence or initrd, and reading real disk state

## Applies to

`flake/modules/nire/impermanence/`, any `boot.initrd.*` option, stage-1
hooks, and reading disk/mount state on one of the hosts that wipes `/root` on
boot. Use before touching anything under `nire/impermanence/`, any
`boot.initrd` option, or before trusting `lsblk`/`findmnt`/mounted-`/etc`
output on these hosts.

**Read `WARN-impermanence.nix` and
`wiki/impermanence-stage1-migration.md` before
changing anything near this.** This mechanism wipes `/root` on boot on most
hosts in this repo — see `CLAUDE.md` Safety section for which ones, current
as of the date on that file. Both of the following have actually happened
here.

## `@name@` inside an initrd hook string is a live template placeholder

Applies to **scripted** stage 1, which this repo still uses as of the
`lessons-learned-impermanence-stage1-migration.md` writeup (kept because the
mechanism is one `boot.initrd.systemd.enable = false` away).

`boot.initrd.postResumeCommands` and its siblings are pasted into
`stage-1-init.sh` by a fixed sequence of 19 `substituteInPlace
--replace-fail` passes. `@postResumeCommands@` is the **10th**, so every
placeholder substituted after it — `@preDeviceCommands@`, `@preFailCommands@`,
`@preLVMCommands@`, `@resumeDevice@`, `@shell@`, `@udevRules@` — is still
live in the text you just inserted.

Naming `@preLVMCommands@` in a **comment** inside `postResumeCommands`
therefore pastes the whole LUKS unlock script into that comment. Only its
first line stays commented; the rest executes, in initrd, part-way through
the `/root` rollback.

**Text in these strings is not inert, and a comment is not a safe place to
name things.** Refer to a hook in prose, never by its token. (Same family as
the general Nix trap: `${...}` inside a `''` string is interpolation, even
inside what you intend as a comment — escape as `''${...}` or reword.)

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
first boot into this config; see `CLAUDE.md` State section for both.)
