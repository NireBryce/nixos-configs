# 8. A built-in option existing is not the same as it fitting

_Last modified: 2026-09-29_

§8 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §8's full account.

`documentation.man.generateCaches` exists and does not work here: `man-db.nix`
only maps `/run/current-system/sw/share/man`, so it would pay a full rebuild and
still not index `/etc/profiles/per-user/<user>/share/man`, where the packages
worth searching live.

**Read what an option generates, not what it is called.**
