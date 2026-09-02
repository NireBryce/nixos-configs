---
name: prune-permissions
description: How to remove dead entries from .claude/settings.local.json's permission allowlist in this repo.
---

# Pruning `.claude/settings.local.json`

## Applies to

Use when asked to clean up, prune, or audit this repo's permission
allowlist, or as a periodic housekeeping pass alongside other stale-state
cleanup (memory files, stale `wiki/` drafts). Not for *adding* entries to
reduce prompts — that's the built-in `fewer-permission-prompts` skill, which
only appends and doesn't touch what's already there.

`.claude/settings.local.json` is **untracked for real as of 2026-09-02**
(`git rm --cached` — the `.gitignore` entry from 2026-08-25 alone never
untracked an already-tracked file; §42 has that incident). Pruning is now a
pure local edit: no commit, no `ship`. The file still holds real state
worth curating; it just benefits this machine's own copy only.

## Why this exists

The file only ever grows: every tool call needing a new permission pattern
gets one appended automatically (including, in the 2026-08-25 session that
wrote this skill, patterns for commands used to *audit this same file*).
Nothing prunes it back; left alone it accumulates stale never-fires-again
cruft. First pass: 31 entries down to 21.

## Heuristic: dead vs. standing

**Prune** — dies when the session that created it ends, because what it
names cannot recur:

- A `Bash(...)` entry with **no trailing `*`** embedding a one-off literal
  payload (full regex, exact multi-command pipeline, exact argument list).
  Matching is by prefix; no wildcard means only that exact command string
  ever matches again.
- Any path under `/nix/store/<hash>-...` — content-addressed; a new eval
  gets a new hash and the old permission never matches again.
- A specific file under `/tmp/` (`/tmp/diag-log.txt`, not `/tmp/**`) —
  ephemeral by construction.

**Keep** — standing, reusable patterns:

- `WebFetch(domain:...)` — a domain doesn't expire.
- `Bash(<recipe> *)` prefix-wildcards (`just check *`, `git commit *`,
  `gh pr *`) — general, matches future invocations of that shape.
- Broad `Read`/`Edit` globs (`//tmp/**`, `//nix/store/**`, a skill
  directory's `/**`) — scoped but not one-off.

When an entry fits neither bucket cleanly, say what it is and ask.

## Steps

1. Read `.claude/settings.local.json`.
2. Classify every entry in `permissions.allow` against the heuristic.
3. List the prune candidates before removing anything — reviewable, not
   silent.
4. Rewrite with the dead entries removed; keep survivors in original order,
   no reshuffling.
5. Validate it's still well-formed JSON before calling it done.
