# 52. A step that deletes by name takes the name from verified facts

_Last modified: 2026-10-31_

## Index entry

§52 in [agent-lessons-learned.md](../agent-lessons-learned.md)

## The lesson

Landing a PR ends in `git branch -D <head>` and `git push origin --delete
<head>`, where `<head>` is the PR's head branch name. Three copies of that
flow (this repo's `ship.py land`, polymorph's `ship_land.py`, and the ship
skills of four other repos) checked only that the PR's *base* was right. A PR
whose head is named `main` or `experimental`, or whose head is in a fork,
passed every check and then aimed the delete at the real branch. A review
found it on polymorph's script, and a read of the others found the same
shape. `worktree.py prune` had a variant: it force-deleted the branch of any
clean worktree, and its "PR merged" lookup matched on head *name*, so a
protected branch's name that appeared on any merged PR counted as landed.

None of it had gone wrong. The checks all passed and the tests covered the
happy path, which is why it was still there.

## The rule

A step that deletes, force-pushes or overwrites something named by data
(a branch, a path, a ref) takes the target from facts read out of the thing
being acted on (the PR's `headRefName`, `headRefOid`, `isCrossRepository`),
never from a name typed from memory, and refuses before the first outward step
when the target is a protected name, equals the base, or comes from somewhere
else. Delete with the safe form (`-d`); use `-D` only when the ref is exactly
the commit that was verified. A missing field counts as the unsafe answer.
Test the refusals with a head named like each protected branch, and see them
fail on the old code.

## Related

§15 (commit hygiene), §22 (before believing a zero, show the query can
return non-zero). Enforced in `.agents/scripts/ship.py` (`gate_problems`),
`.agents/scripts/worktree.py` (`PROTECTED`) and their tests.
