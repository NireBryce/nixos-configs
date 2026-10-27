---
name: boyscouting-all
description: Sweeps the whole repo for small, local cleanups and lands them as one scoped change.
when_to_use: Asked to "boyscout the repo" or "clean up the small stuff everywhere" as a standalone task, not a fix noticed mid-task.
---

# Boyscouting, repo-wide

## Applies to

Asked to "boyscout the repo" or "clean up the small stuff everywhere": a standalone pass over files you weren't editing for another task. Not for:

- a fix noticed mid-task: `boyscouting`, in that task's commit
- reviewing a diff
- docs conciseness: `trim-docs`
- stale facts: `wiki-sync`
- anything with a real failure scenario: `propose-issue`

## Relationship to `boyscouting`

Same bar for what's eligible. Read its "What qualifies" and "What doesn't" first. Only the scope differs: this skill is the task, so opening files is expected. Changes must still be behavior-neutral, create no new failure scenario, and skip opinion-only renames. Real bugs go to `propose-issue`.

The diff won't be small, so the test is that every hunk is independently justifiable and trivially reviewable. Don't include anything that needed its own task.

## Steps

1. **Use a worktree** (`use-a-worktree`).
2. **Pin down scope.** Ask whether it's everything, one area (`flake/modules/general-config/`, `wiki/`, one host), or one class of fix (dead imports, stale comments, unused variables). One question beats guessing diff size.
3. **Search.** Grep for the shapes `boyscouting` lists: unused bindings, TODO/FIXME older than the surrounding code, duplicated small blocks, comments referencing moved code. Search, don't skim. Run `statix` and `deadnix` first (`just preflight` runs them); they catch many Nix cases.
4. **Check each candidate against the bar.** A real bug goes to `propose-issue`, not this branch.
5. **One commit per logical cleanup**, so a reviewer can revert one without the others. Group only identical mechanical fixes (e.g. deadnix's suggested removals).
6. **Run `just preflight`** before shipping.
7. **`ship`**: one branch, one PR. Describe the scope and the kinds of fix, not just "cleanup".

## Calibrate

If step 5 gives more than a handful of commits, the sweep found real work. Split it into proposals (`propose-issue` per finding, or one issue listing several) instead of a mega-branch. A full audit isn't a boyscout pass.

## See also

`boyscouting`, `propose-issue`, `use-a-worktree`, `ship`.
