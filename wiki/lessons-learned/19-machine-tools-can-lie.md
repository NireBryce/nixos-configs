# 19. The machine's own tools can lie about the machine

_Last modified: 2026-10-05_

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

## The agent's own sandbox is a namespace too

2026-10-05, nire-tenacity, writing the lesson-reminder hook's tests. A
fixture used `/nonexistent/lesson-state` as a state directory that could not
exist. It did: the agent's Bash tool runs in a sandbox whose `/` is a
private tmpfs (`/newroot` in `/proc/self/mountinfo`, mounted at session
start, writable by the user, with entries like `init` and `nix-support` the
host doesn't have). The test created the directory, a later run read it
back, and the agent reported a stray directory "on this machine" and asked
the user to delete it. The user's own `ls /` showed no such thing.

Same rule, one level further out: before saying something exists, or was
created, on the host, check which namespace the shell is in.
`/proc/self/mountinfo` showing `/` as a tmpfs, or `/proc/1/ns/mnt` being
unreadable, means it is not the host's view. A test needing a path that
cannot be created uses one under a regular file, which can never become a
directory in any environment.
