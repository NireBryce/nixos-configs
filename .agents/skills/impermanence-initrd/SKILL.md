---
name: impermanence-initrd
description: Edits impermanence and initrd config and reads real disk and mount state on a host that wipes /root on boot.
when_to_use: Touching boot.initrd options or impermanence config, or before trusting lsblk, findmnt or /etc output on a host that wipes /root on boot.
---

# Editing impermanence or initrd, and reading real disk state

## Applies to

Use this before touching `flake/modules/general-config/impermanence/` or any `boot.initrd.*` option (systemd stage 1 since 2026-08-10; see History), and before trusting `lsblk`, `findmnt` or mounted-`/etc` output on a host that wipes `/root` on boot.

Read `WARN-impermanence.nix` before changing anything near this. Which hosts wipe `/root` is in the `CLAUDE.md` Safety section.

## The shell's view is a mount namespace

`lsblk`, `findmnt` and `/etc` describe the shell's own mount namespace, not the host's. On tenacity they showed `/` as tmpfs, `/dev/mapper/enc` at `/etc/xdg`, empty UUID columns, and an `/etc` missing files the system has. Read literally, that says the disk does not match the hardware module (a stop-and-ask condition). The disk matched.

Use these sources instead; none is rewritten by the namespace and none needs privileges:

- `/proc/1/mountinfo`: PID 1's (the host's) mount table
- `/dev/disk/by-uuid/`: udev symlinks; LUKS and filesystem UUIDs resolve
- `/run/current-system/…` and any `/nix/store` path: what `/etc` should hold

`btrfs subvolume list` needs privileges, so ask the user to run it. It shows whether `root-blank` exists without mounting:

```sh
sudo btrfs subvolume list -a /
```

Compare subvolids too. A `/root` far above its neighbours shows the rollback running, which is stronger evidence than `root-blank` existing (tenacity: 607 vs. 257-265 on first boot). A second method is the boot journal's delete-then-snapshot sequence (durandal's first boot into this config). Both are in `wiki/meta/history.md`'s "Confirmed-on-hardware facts".

## History

**The scripted stage 1 `@name@` templating trap no longer applies.** The config migrated to systemd stage 1 on 2026-08-10 (nixpkgs deprecated scripted initrd that week; removal is scheduled for 26.11). For old `boot.initrd.postResumeCommands`-shaped code: hook strings were pasted into `stage-1-init.sh` by a fixed sequence of `substituteInPlace --replace-fail` passes. Naming a later placeholder (for example `@preLVMCommands@`) inside an earlier one's string, even in a comment, pasted a whole other script in and executed most of it. This paragraph is the only full account; `WARN-impermanence.nix`'s history comments list what else the old mechanism did. `wiki/agent-lessons-learned.md` §28 covers the hibernation-resume side of the same migration, not this trap.
