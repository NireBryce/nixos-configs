# 19. The machine's own tools can lie about the machine

_Last modified: 2026-09-29_

§19 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §19's full account.

Confirming the disk matched `hardware-tenacity.nix` was a stop condition. The
obvious commands returned nonsense: `findmnt` said `/` was a tmpfs, `lsblk`
showed `enc` mounted at `/etc/xdg` and left every UUID column empty.

The shell runs in a mount namespace, and both tools report **that** namespace —
accurately, and about the wrong world. Read literally they say the disk does not
match the config, which would have meant regenerating a correct file.

Two sources are not rewritten, and both are unprivileged:

- `/proc/1/mountinfo` — PID 1's mount table
- `/dev/disk/by-uuid/` — udev's symlinks

Through those, every value matched. The same trap caught me again later via
`/etc`, which is also a namespace tmpfs here; store paths are the way out.

That output also carried the round's best evidence: `/` was **subvolid 607**
while neighbours sat at 257–265. Nothing but hundreds of recreations explains
that, which is the `/root` rollback demonstrably *running* — a stronger fact
than `root-blank` merely existing.
