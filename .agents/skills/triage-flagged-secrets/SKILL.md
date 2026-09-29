---
name: triage-flagged-secrets
description: How to tell whether a secret the guard hooks flagged is a fresh leak or an already-confirmed-dead one from old git history.
---

# Triaging a flagged secret

## Applies to

`secrets-guard-posttooluse.sh` (or `-pretooluse.sh`) fires on a plaintext
secret shape in a Bash tool's output: Tailscale auth key, age secret key,
private key block, bare `tailscale_key`/`atuin_key` value. Run this
**before** treating it as fresh and before `secrets-hygiene`'s "say so
immediately, recommend rotation" step (which applies only if triage says
new).

## Why

2026-09-14: `git remote prune origin` / `git show 449d158` re-flagged a
Tailscale auth key ~2 years dead: committed in `449d158f`
(`nire-galatea/tskey`), deleted in `8b78516d`, still reachable in history,
so anything walking that commit/blob re-triggers the hook. Inert since Jan
2024; treating it as live wastes a rotation cycle. First entry in
`.agents/known-dead-secrets.md`.

## Steps

1. **Check `.agents/known-dead-secrets.md`.** Match by *provenance* (the
   commit SHA or path the command touched: `git show <sha>`, `git log -p --
   <path>`, `git cat-file blob <sha>`, a worktree at an old ref), not by
   re-reading the value. Match: say it's a recognized dead key, name the
   row, stop — no rotation, no incident report.
2. **No match: treat as new.** Follow `secrets-hygiene`'s leak procedure:
   stop, don't requote the value, tell the user immediately, name the
   secret type, recommend rotation.
3. **Once confirmed dead** (user, admin console, or `just read-sops-names`
   plus context: rotated, revoked, or never valid), add a row to
   `.agents/known-dead-secrets.md`: type, commit + path, removing commit (if
   any), date confirmed, context (e.g. "host no longer in the roster").
   **Never put the value in the registry**; identify by commit/path.
4. **A match is not blanket permission** for the same file/commit family.
   A *different* commit or path with the same secret *shape* is unknown
   until checked.

## See also

- `secrets-hygiene` — the leak procedure, and the hooks' limits (Bash-tool
  only, shape-based matching, ZCode-harness gap where they don't fire).
- `.agents/known-dead-secrets.md` — the registry.
- `.agents/hooks/secrets-guard-posttooluse.sh` — its output never repeats
  enough of the value to compare, hence provenance matching.
