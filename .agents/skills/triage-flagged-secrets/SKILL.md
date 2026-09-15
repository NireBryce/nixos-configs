---
name: triage-flagged-secrets
description: How to tell whether a secret the guard hooks flagged is a fresh leak or an already-confirmed-dead one from old git history.
---

# Triaging a flagged secret

## Applies to

`secrets-guard-posttooluse.sh` (or `-pretooluse.sh`) fires and names a
plaintext secret shape in a Bash tool's output — a Tailscale auth key, an
age secret key, a private key block, a bare `tailscale_key`/`atuin_key`
value. Run this **before** treating it as a fresh incident and before
following `secrets-hygiene`'s "say so immediately, recommend rotation"
step, since that step is for the case where triage below says it's new.

## Why this exists

2026-09-15: a `git remote prune origin` / `git show 449d158` sequence
re-flagged a Tailscale auth key that turned out to be ~2 years dead —
committed in `449d158f` (`nire-galatea/tskey`), deleted from the tree one
commit later in `8b78516d`, but still reachable from history, so any
command that walks that commit or blob re-triggers the hook. Re-treating
that as a live incident every time it resurfaces wastes a rotation-panic
cycle on a key that's been inert since Jan 2024. This is the first entry
in `.agents/known-dead-secrets.md`; there will be more.

## Steps

1. **Check `.agents/known-dead-secrets.md` first.** Match by *provenance*
   — the commit SHA or path the triggering command touched (`git show
   <sha>`, `git log -p -- <path>`, `git cat-file blob <sha>`, a worktree
   checked out at an old ref) — not by re-reading the flagged value. If
   the command's target matches a row, this is a recognized dead key: say
   so, name which registry row it is, and stop — no rotation, no incident
   report, same as any other already-handled thread.
2. **No match: treat it as new.** Follow `secrets-hygiene`'s leak
   procedure as written — stop, don't requote the value, tell the user
   immediately, name which secret type leaked, recommend rotation.
3. **Once the user (or you, via an admin console / `just read-sops-names`
   plus context) confirms the key is actually dead** — rotated, revoked,
   or provably never valid — add a row to
   `.agents/known-dead-secrets.md`: the type, the commit + path it came
   from, the commit that removed it (if any), the date confirmed, and any
   context worth keeping (e.g. "host no longer in the roster"). **Never
   put the secret value itself in the registry** — identify rows by
   commit/path so the registry can't become a second leak of the thing it
   exists to stop re-panicking about.
4. **A registry match is not blanket permission to ignore future hits in
   the same file/commit family.** Match the specific provenance, not "a
   tskey showed up and we've seen one of those before" — a *different*
   commit or path producing the same secret *shape* is still an unknown
   until it's actually checked.

## See also

- `secrets-hygiene` skill — the leak procedure this triage step sits in
  front of, and the hooks' own limits (Bash-tool-only, shape-based
  matching, and the known ZCode-harness gap where the hooks don't fire at
  all).
- `.agents/known-dead-secrets.md` — the registry itself.
- `.agents/hooks/secrets-guard-posttooluse.sh` — what actually triggers
  this: the exact patterns it matches are what step 1's "match by
  provenance, not by value" is working around, since the hook's own output
  never repeats enough of the value to compare against.
