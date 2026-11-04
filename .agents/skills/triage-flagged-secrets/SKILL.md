---
name: triage-flagged-secrets
description: Decides whether a secret flagged by the guard hooks is a fresh leak or one already confirmed dead in old git history.
when_to_use: The secrets guard hook flags a Tailscale auth key, age key or private key block in tool output, before calling it a fresh leak.
---

# Triaging a flagged secret

## Applies to

Use when `secrets-guard-posttooluse.sh` (or `-pretooluse.sh`) fires on a plaintext secret shape in a Bash tool's output: Tailscale auth key, age secret key, private key block, or a bare `tailscale_key`/`atuin_key` value. Triage first. Only if triage says the secret is new, go on to `secrets-hygiene`'s "say so immediately, recommend rotation" step.

## Why

2026-09-14: `git remote prune origin` and `git show 449d158` re-flagged a Tailscale auth key that had been dead for about 2 years. It was committed in `449d158f` (`nire-galatea/tskey`) and deleted in `8b78516d`, but it is still reachable in history, so anything that walks that commit or blob re-triggers the hook. It has been inert since Jan 2024, and treating it as live wastes a rotation cycle. It is the first entry in `.agents/known-dead-secrets.md`.

## Steps

1. **Check `.agents/known-dead-secrets.md`.** Match by provenance: the commit SHA or path the command touched (`git show <sha>`, `git log -p -- <path>`, `git cat-file blob <sha>`, a worktree at an old ref). Do not re-read the value to compare. On a match, say it is a recognized dead key, name the row, and stop; no rotation, no incident report.
2. **No match: treat it as new.** Follow `secrets-hygiene`'s leak procedure: stop, do not requote the value, tell the user immediately, name the secret type, recommend rotation.
3. **Record it once confirmed dead.** Confirmation comes from the user, the admin console, or `just read-sops-names` plus context (rotated, revoked, or never valid). Add a row to `.agents/known-dead-secrets.md` with: type, commit + path, removing commit (if any), date confirmed, and context (for example "host no longer in the roster"). Never put the value in the registry; identify the secret by commit and path.
4. **Do not widen a match.** A match covers that file and commit only. A different commit or path with the same secret shape is unknown until checked.

## See also

- `secrets-hygiene`: the leak procedure, and the hooks' limits (Bash-tool only, shape-based matching, a ZCode-harness gap where they do not fire).
- `.agents/known-dead-secrets.md`: the registry.
- `.agents/hooks/secrets-guard-posttooluse.sh`: its output never repeats enough of the value to compare, which is why matching is by provenance.
