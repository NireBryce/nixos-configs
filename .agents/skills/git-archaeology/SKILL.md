---
name: git-archaeology
description: How to find the commit that added, changed, or removed something in git history when the file has since been renamed or moved.
---

# Finding a change in git history despite renames

## Applies to

You need the commit behind a date or claim you're recording — hashes for
skill `trim-history`'s keep-list and skill `fact-hygiene`'s records, a
provenance match for skill `triage-flagged-secrets`, or "when was this
comment/option removed?" — and `git log` scoped to the file's current path
came back empty. Also before concluding "no commit ever touched this":
emptiness usually indicts the pathspec, not the history.

## The issue

This repo renames areas wholesale (`modules/system` -> `modules/config-system`
in `e03027a0`, 2026-09-14; `modules/config-system` -> `modules/general-config`
2026-09-27; homelab categories consolidated 2026-08-27), so a file's current
path often postdates the change — sometimes by a day. `git log -- <path>`
(and pickaxe `-S`/`-G` given a pathspec) matches only commits where *that
exact path* changed; `old/area/file.nix` doesn't match `new/area/file.nix`.
Empty means "nothing changed this path under this name", which reads like
"never happened".

Hit 2026-09-15 verifying `fact-hygiene`'s cross-reference record: a
date-scoped log on the current paths of `forgejo.nix`, `golink.nix`,
`bash.nix` found nothing (all moved); the pickaxe over wildcard pathspecs
found the sweep commit first try.

## Steps

1. **Needle that existed verbatim where you expect the change** — a removed
   line's own words: `-S 'tenacity, lego'` beats bare `-S 'lego'`.
2. **Search across renames, not paths:**
   ```sh
   git log --all --format='%h %cs %s' -S 'tenacity, lego' -- '*forgejo.nix'
   ```
   Bare wildcard pathspecs: `*` crosses directory separators, so
   `'*forgejo.nix'` matches every path the file has lived at (`:(glob)` pins
   `*` to one segment — don't reach for it first). A distinctive needle can
   drop the pathspec entirely.
3. **Read `%cs`; don't pre-scope with `--since`/`--until`** — filtering
   results by date is safe, scoping the search on a wrong pathspec is the
   empty result. Cite `%cs` (committer date): PRs merge by rebase, so author
   date is when written, committer date when landed.
4. **Verify the hit — a pickaxe hit means the needle's count changed, not
   that this is *the* commit.** `b73672c6` (2026-08-28 comment-prose pass)
   moved `lego` lines without removing them; the removal was `216a5ae7`.
   `git show <hash> -- '*<name>'` and read the removed lines.
5. **Record hash + date together** (as the known-dead-secrets registry does,
   `449d158f`/2024-01-29), not date-plus-confidence: the hash keeps the claim
   checkable after the next rename.

## See also

- `fact-hygiene` — where these hashes get recorded.
- `trim-history` — "keep, always: dates and commit hashes".
- `triage-flagged-secrets` — same archaeology in reverse (commit/path provenance).
