---
name: git-archaeology
description: Finds the commit that added, changed or removed something when the file has since been renamed or moved.
when_to_use: Asked when something was removed, git log on a file's current path comes back empty, or about to conclude no commit ever touched it.
---

# Finding a change in git history despite renames

## Applies to

Use this skill when you need the commit behind a date or claim you are
recording, and `git log` scoped to the file's current path returns nothing.
Examples: hashes for skill `trim-history`'s keep-list and skill
`fact-hygiene`'s records, a provenance match for skill
`triage-flagged-secrets`, or "when was this comment/option removed?". Also use
it before concluding "no commit ever touched this": an empty result usually
means the pathspec is wrong, not that the history is empty.

## The issue

This repo renames areas wholesale (`modules/system` -> `modules/config-system`
in `e03027a0`, 2026-09-14; `modules/config-system` -> `modules/general-config`
2026-09-27; homelab categories consolidated 2026-08-27), so a file's current
path often postdates the change, sometimes by a day. `git log -- <path>` (and
pickaxe `-S`/`-G` given a pathspec) matches only commits where that exact path
changed; `old/area/file.nix` does not match `new/area/file.nix`. An empty
result means "nothing changed this path under this name", which is easy to
misread as "never happened".

2026-09-15, verifying `fact-hygiene`'s cross-reference record: a date-scoped
log on the current paths of `forgejo.nix`, `golink.nix` and `bash.nix` found
nothing (all had moved). The pickaxe over wildcard pathspecs found the sweep
commit on the first try.

## Steps

1. **Pick a needle that existed verbatim where you expect the change**: a
   removed line's own words. `-S 'tenacity, lego'` is better than bare
   `-S 'lego'`.
2. **Search across renames, not paths:**
   ```sh
   git log --all --format='%h %cs %s' -S 'tenacity, lego' -- '*forgejo.nix'
   ```
   In a bare wildcard pathspec, `*` crosses directory separators, so
   `'*forgejo.nix'` matches every path the file has lived at. (`:(glob)` pins
   `*` to one segment; do not use it first.) A distinctive needle can drop the
   pathspec entirely.
3. **Read `%cs`; do not pre-scope with `--since`/`--until`.** Filtering
   results by date is safe; scoping the search by a wrong pathspec is what
   produces the empty result. Cite `%cs` (committer date): PRs merge by
   rebase, so author date is when the change was written and committer date is
   when it landed.
4. **Verify the hit.** A pickaxe hit means the needle's count changed in that
   commit, not that it is the commit you want. `b73672c6` (2026-08-28
   comment-prose pass) moved `lego` lines without removing them; the removal
   was `216a5ae7`. Run `git show <hash> -- '*<name>'` and read the removed
   lines.
5. **Record hash and date together** (as the known-dead-secrets registry does,
   `449d158f`/2024-01-29), not a date plus a confidence note. The hash keeps
   the claim checkable after the next rename.

## See also

- `fact-hygiene`: where these hashes get recorded.
- `trim-history`: "keep, always: dates and commit hashes".
- `triage-flagged-secrets`: the same archaeology in reverse (commit/path
  provenance).
