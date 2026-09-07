---
name: boyscouting-all
description: How to deliberately sweep the whole repo for the same small, local cleanups boyscouting fixes incidentally, and land them as one scoped change.
---

# Boyscouting, repo-wide

## Applies to

Asked to "boyscout the repo", "clean up the small stuff everywhere", or
similar — a deliberate, standalone pass looking for `boyscouting`-shaped
opportunities across files you weren't already editing for another task.
Not: a fix noticed while doing something else (that's `boyscouting`
itself, landed in that task's commit); a correctness/simplification review
of a diff (`code-review`, `simplify`); a docs-conciseness pass
(`trim-docs`); a stale factual claim (`wiki-sync`); anything with a real
failure scenario (`propose-issue`).

## Relationship to `boyscouting`

Same eligibility bar — read that skill's "What qualifies" and "What
doesn't" first, they're not repeated here. The only thing that changes is
scope: `boyscouting` limits itself to files a real task already opened;
this skill *is* the task, so it's the file-opening step that's now
deliberate instead of forbidden. Everything else — behavior-neutral, no
new failure scenario, no opinion-only renames, real bugs go to
`propose-issue` instead — still applies exactly as written there.

## Why this needs its own skill, not just "run boyscouting on everything"

A repo-wide sweep is outward-facing in a way a single incidental fix isn't:
it touches many unrelated files in one pass, which is exactly the
single-purpose-branch problem `ship` and `boyscouting` both guard against,
just inverted. The discipline here isn't "keep the diff small" (it won't
be), it's **keep every individual hunk independently justifiable and
trivially reviewable**, and don't let the sweep smuggle in anything that
needed its own task.

## Steps

1. **Use a worktree** (`use-a-worktree`) — this touches many files across
   the tree, exactly the shared-checkout risk that skill exists for.
2. **Scope the sweep before starting.** "Whole repo" is rarely what's
   wanted — confirm with Elly whether it's everything, one area
   (`flake/modules/nire/`, `wiki/`, one host), or one class of finding
   (dead imports, stale comments, unused variables). A vague ask is worth
   one clarifying question rather than guessing at the diff size.
3. **Search, don't skim.** Grep for the concrete shapes that
   `boyscouting`'s "what qualifies" names — unused bindings, TODO/FIXME
   comments older than the code around them, duplicated small blocks,
   obviously-stale comments referencing code that moved. `statix`/`deadnix`
   (already run by `just preflight`) catch a chunk of the Nix-side cases
   mechanically — lean on them before hand-searching for the same thing.
4. **Apply `boyscouting`'s qualifying bar to each candidate individually.**
   Finding it in a sweep doesn't relax the bar — a real bug found this way
   still goes to `propose-issue`, not into this branch, even though you're
   already looking at the file.
5. **One commit per logical cleanup, not one giant commit.** A reviewer
   should be able to revert "remove dead import in foo.nix" without
   reverting "fix stale comment in bar.nix". Group only truly identical
   mechanical fixes (e.g. "run deadnix's suggested removals") into one
   commit.
6. **Run `just preflight`** before shipping — a sweep this wide is exactly
   where a typo becomes an eval failure.
7. **Ship normally** (`ship`) — one branch, one PR, describing the sweep's
   scope and listing what categories of fix it contains, not just "cleanup".

## Calibrate

If the candidate list is long enough that step 5 would produce more than a
handful of commits, that's a signal the sweep found real work, not tidying
— split it into a proposal (`propose-issue` per finding, or one issue
listing several) rather than one mega-branch. This skill is for the case
where each fix really is boyscouting-small; it isn't a shortcut for
running a full audit under a friendlier name.

## See also

- `boyscouting` — the eligibility bar this skill reuses verbatim.
- `code-review` / `simplify` — for correctness or simplification work that
  needs actual judgment, not this skill's mechanical bar.
- `propose-issue` — where anything with a failure scenario goes instead.
- `use-a-worktree`, `ship` — mechanics for running and landing the sweep.
