---
name: git-archaeology
description: How to find the commit that added, changed, or removed something in git history when the file has since been renamed or moved.
---

# Finding a change in git history despite renames

## Applies to

You need the commit behind a date or claim you're recording — the hashes
skill `trim-history`'s keep-list and skill `fact-hygiene`'s records cite,
a provenance match for skill `triage-flagged-secrets`, or "when was this
comment/option removed?" — and a `git log` scoped to the file's current
path came back empty. Also before concluding "no commit ever touched
this": emptiness usually indicts the pathspec, not the history.

## The issue

This repo renames areas wholesale (`modules/system` became
`modules/config-system` in `e03027a0`, 2026-09-14; the homelab
categories consolidated 2026-08-27), so a file's current path often
postdates the change you're looking for — sometimes by a single day.
`git log -- <path>` lists only commits where *that exact path* changed:
a commit that changed `old/area/file.nix` does not match
`new/area/file.nix`, and the same holds for a pickaxe (`-S`/`-G`) given
a pathspec. An empty result means "nothing changed this path *under
this name*", which reads exactly like "this never happened".

Hit 2026-09-15, verifying the dates in skill `fact-hygiene`'s
cross-reference record: a date-scoped log on the current paths of
`forgejo.nix`, `golink.nix` and `bash.nix` found *nothing* — all three
had moved since — while the same pickaxe over wildcard pathspecs found
the sweep commit on the first try.

## Steps

1. **Pick a needle that existed verbatim where you expect the change** —
   a removed line's own words beat the file name: `-S 'tenacity, lego'`
   found what a bare `-S 'lego'` would have buried in noise.
2. **Search across renames, not paths:**
   ```sh
   git log --all --format='%h %cs %s' -S 'tenacity, lego' -- '*forgejo.nix'
   ```
   Bare pathspec wildcards are the useful flavor here: `*` crosses
   directory separators, so `'*forgejo.nix'` matches the file at every
   path it has lived at. (`:(glob)` magic is the opposite — it pins `*`
   within one segment; don't reach for it first.) If the needle is
   distinctive enough, drop the pathspec entirely.
3. **Read `%cs` in the output; don't pre-scope the search with
   `--since`/`--until`.** Date-filtering the results is safe;
   date-scoping the search on top of a wrong pathspec is exactly the
   empty result this skill exists for. `%cs` (committer date) is the
   right date to cite: this repo merges PRs by rebase, so author date
   is when it was written and committer date is when it landed.
4. **Verify the hit before citing it — a pickaxe hit means the needle's
   count changed, not that this commit is *the* one.** `b73672c6` (the
   2026-08-28 comment-prose pass) moved `lego` lines without removing
   them; the actual removal was `216a5ae7`. `git show <hash> --
   '*<name>'` and read the removed lines.
5. **Record hash + date together**, the shape this repo's records use
   (the known-dead-secrets registry's `449d158f`/2024-01-29): hash-plus-
   date rather than date-plus-confidence. The hash is what keeps the
   claim checkable after the next rename.

## See also

- skill `fact-hygiene` — the records these hashes end up in, and the
  verification discipline they serve.
- skill `trim-history` — "keep, always: dates and commit hashes"; this
  is how the hashes get found.
- skill `triage-flagged-secrets` — matches flagged secrets by commit and
  path provenance: the same archaeology run in reverse.
