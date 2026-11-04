---
name: boyscouting-all
description: Sweeps the whole repo for small, local cleanups and lands them as one scoped change.
when_to_use: Asked to "boyscout the repo" or "clean up the small stuff everywhere" as a standalone task, not a fix noticed mid-task.
---

# Boyscouting, repo-wide

## Applies to

Use this when asked to "boyscout the repo" or "clean up the small stuff everywhere": a standalone pass over files you were not editing for another task. Do not use it for:

- a fix noticed mid-task: `boyscouting`, in that task's commit
- reviewing a diff
- docs conciseness: `trim-docs`
- stale facts: `wiki-sync`
- anything with a real failure scenario: `propose-issue`

## Relationship to `boyscouting`

The bar for what is eligible is the same. Read `boyscouting`'s "What qualifies" and "What doesn't" first. Only the scope differs: here the sweep is the task, so opening files is expected. Every change must still be behavior-neutral, create no new failure scenario, and avoid opinion-only renames. Real bugs go to `propose-issue`.

The diff will not be small, so each hunk must be independently justifiable and quick to review. Leave out anything that needed its own task.

## Steps

1. **Use a worktree** (`use-a-worktree`).
2. **Pin down scope.** Ask whether it is everything, one area (`flake/modules/general-config/`, `wiki/`, one host), or one class of fix (dead imports, stale comments, unused variables). One question is cheaper than guessing diff size.
3. **Search.** Grep for the shapes `boyscouting` lists: unused bindings, TODO/FIXME older than the surrounding code, duplicated small blocks, comments referencing moved code. Run `statix` and `deadnix` first (`just preflight` runs them); they catch many Nix cases.
4. **Check each candidate against the bar.** Send a real bug to `propose-issue`, not this branch.
5. **Make one commit per logical cleanup**, so a reviewer can revert one without the others. Group only identical mechanical fixes (for example, deadnix's suggested removals).
6. **Run `just agent preflight-brief`** before shipping (`just wiki-lint` if the diff is docs-only; skill `ship`, step 0).
7. **Run `ship`**: one branch, one PR. Describe the scope and the kinds of fix, not just "cleanup".

## Calibrate

If step 5 gives more than a handful of commits, the sweep found real work. Split it into proposals (`propose-issue` per finding, or one issue listing several) instead of a mega-branch. A full audit is not a boyscout pass.

## See also

`boyscouting`, `propose-issue`, `use-a-worktree`, `ship`.
