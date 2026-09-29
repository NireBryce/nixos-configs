---
name: investigate-bug
description: How to check whether a reported bug or symptom is already a known, tracked thread before investigating it yourself.
---

# Checking before investigating

## Applies to

Someone reports an error, crash, or "weird" behavior in this repo or on a
host and you're about to reproduce/diagnose it. Run **before** that. Not for
deciding whether to write up something you already found (`propose-issue`,
the filing side). Not when the user already points at the specific cause or
file.

## Why

2026-08-24: a ble.sh/carapace completion bug was re-derived from a live pty
session (hours) though already written up 2026-08-22 in
`wiki/categories/shell-config/blesh.md`, one link from `wiki/00-INDEX.md`.
§39, [issue #72](https://github.com/NireBryce/nixos-configs/issues/72).
Prose saying "check first" didn't make the check happen; hence a triggered
skill.

## Steps

1. **Before reproducing**, `just threads "<keywords>"` with a couple of
   guesses from the report's wording (symptom, error text, command). It
   searches GitHub issues (`gh issue list --search`) and greps `wiki/`
   (incl. `lessons-learned/`) and `_loose-ends/bugs-pending-submission/`;
   see `flake/scripts/threads.sh`.
   A design question ("why is it shaped like this?") may be settled in
   an earlier session's transcript; `just agent` has scripts that read
   them (§17).
2. **Hit: read it fully** (issue and/or linked wiki deep-dive) and resume
   from where it left off (untested fix, open question, "not yet
   confirmed"). If stale or wrong, fix *that*; no parallel investigation.
3. **No hit**: reproduce for real, not from source (`AGENTS.md` "Bugs here
   serialize"). Once diagnosed, don't leave it only in your reply: file or
   track via `propose-issue`, update wiki pages via `wiki-sync`.
4. **State fixed vs. verified precisely** (`AGENTS.md` "Before calling it done": treat an undated
   "verified" as *evaluates*). Without a real `just switch` and live
   re-check a fix is *in the tree*, not *fixed*; say which, in the issue and
   wiki page both.

See also: `propose-issue`, `wiki-sync`, `just threads` /
`flake/scripts/threads.sh`.
