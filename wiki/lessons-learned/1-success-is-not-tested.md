# 1. A tool that reports success has not thereby been tested

_Last modified: 2026-09-29_

§1 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §1's full account.

Four tools were written during this port. All four were wrong on first run, and
**all four reported success while being wrong** — none errored, none warned.

| tool | first-run defect |
|---|---|
| `unwrap.py` | silently skipped `sops.nix`, whose declaration ends in `=` with the body on the next line |
| `modules.py orphans` | called eight nested categories dead; `collectModules` recurses, so `rust` in `langs` is also collected by `development` |
| `modules.py collisions` | **could not see the collision it was written for** — keyed its dict by filename stem and *assigned*, so duplicates overwrote each other |
| `host-fingerprint.nix` | "no attribute differs" for changes that moved the drvPath; it sampled names, not content |

**A summary line is not evidence.** `151 ok, 0 skipped` was true and useless —
the file it mishandled was counted OK.

**Test a checker against a case it should catch**, in the same commit. The
collision check was verified by renaming `boot-durandal.nix` back to `boot.nix`
and confirming the report.

Twice the defect was in the *reporting* rather than the logic, which is worse:
the tool destroys the evidence, then reports its absence. Prefer shapes that
cannot — `modules.py` maps name → *list* of paths, so a duplicate cannot be lost.
