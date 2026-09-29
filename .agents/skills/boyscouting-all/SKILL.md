---
name: boyscouting-all
description: How to deliberately sweep the whole repo for the same small, local cleanups boyscouting fixes incidentally, and land them as one scoped change.
---

# Boyscouting, repo-wide

## Applies to

Asked to "boyscout the repo", "clean up the small stuff everywhere": a
deliberate standalone pass over files you weren't editing for another task.
Not: a fix noticed mid-task (`boyscouting`, in that task's commit); review of
a diff; docs conciseness (`trim-docs`); stale facts (`wiki-sync`); anything
with a real failure scenario (`propose-issue`).

## Relationship to `boyscouting`

Same eligibility bar: read its "What qualifies" / "What doesn't" first.
Only scope changes (this skill *is* the task, so opening files is
deliberate). Behavior-neutral, no new failure scenario, no opinion-only
renames, real bugs to `propose-issue` — all still apply.

The discipline: not "keep the diff small" (it won't be) but **every hunk
independently justifiable and trivially reviewable**; smuggle in nothing
that needed its own task.

## Steps

1. **Use a worktree** (`use-a-worktree`).
2. **Scope first.** Ask whether it's everything, one area (`flake/modules/general-config/`, `wiki/`, one host), or one class (dead imports, stale comments, unused variables). One clarifying question beats guessing diff size.
3. **Search, don't skim.** Grep `boyscouting`'s qualifying shapes: unused bindings, TODO/FIXME older than surrounding code, duplicated small blocks, stale comments referencing moved code. `statix`/`deadnix` (run by `just preflight`) catch many Nix cases; use them first.
4. **Apply the bar per candidate.** A real bug found here still goes to `propose-issue`, not this branch.
5. **One commit per logical cleanup**, so a reviewer can revert one without another. Group only identical mechanical fixes (e.g. deadnix's suggested removals).
6. **`just preflight`** before shipping.
7. **`ship`**: one branch, one PR, describing scope and the categories of fix, not just "cleanup".

## Calibrate

If step 5 would yield more than a handful of commits, the sweep found real
work: split into a proposal (`propose-issue` per finding or one listing
several), not a mega-branch. Not a full audit under a friendlier name.

## See also

`boyscouting`, `propose-issue`, `use-a-worktree`, `ship`.
