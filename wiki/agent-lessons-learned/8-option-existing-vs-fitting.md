# 8. A built-in option existing is not the same as it fitting

_Last modified: 2026-09-29_

## Index entry

§8 in [agent-lessons-learned.md](../agent-lessons-learned.md)

## The lesson

`documentation.man.generateCaches` exists and does not work here: `man-db.nix`
only maps `/run/current-system/sw/share/man`, so it would pay a full rebuild and
still not index `/etc/profiles/per-user/<user>/share/man`, where the packages
worth searching live.

**Read what an option generates, not what it is called.**
