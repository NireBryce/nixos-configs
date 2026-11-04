---
name: investigate-bug
description: Checks whether a reported bug or symptom is already a tracked thread before you investigate it.
when_to_use: Someone reports an error, crash or odd behavior in this repo or on a host, before reproducing or diagnosing it.
---

# Checking before investigating

## Applies to

Use when someone reports an error, crash, or odd behavior in this repo or on a
host and you are about to reproduce or diagnose it. Run this first. It does
not cover:

- deciding whether to write up something you already found (`propose-issue`,
  the filing side);
- a report where the user already points at the specific cause or file.

## Why

2026-08-24: a ble.sh/carapace completion bug was re-derived from a live pty
session (hours of work) although it was already written up on 2026-08-22 in
`wiki/config-structure/categories/shell-config/blesh.md`, one link from
`wiki/00-INDEX.md`. See §39 and
[issue #72](https://github.com/NireBryce/nixos-configs/issues/72). A prose
instruction to check first did not make the check happen, so this is a
triggered skill.

## Steps

1. **Search before reproducing.** Run `just threads "<keywords>"` with a few
   guesses from the report's wording (symptom, error text, command). It
   searches GitHub issues (`gh issue list --search`) and greps `wiki/`
   (including `agent-lessons-learned/`) and `_loose-ends/bugs-pending-submission/`;
   see `flake/scripts/threads.sh`. A design question ("why is it shaped like
   this?") may be answered in an earlier session's transcript; `just agent`
   has scripts that read them (§17).
2. **On a hit, read it fully** (the issue and any linked wiki deep-dive) and
   resume where it left off (untested fix, open question, "not yet
   confirmed"). If it is stale or wrong, fix that record instead of starting a
   parallel investigation.
3. **With no hit, reproduce for real**, not from source (`AGENTS.md`, "Bugs
   here serialize"). After diagnosing, record it: file or track it with
   `propose-issue` and update wiki pages with `wiki-sync`.
4. **State "fixed" and "verified" precisely** (`AGENTS.md`, "Before calling it
   done": treat an undated "verified" as *evaluates*). Without a real `just
   switch` and a live re-check, a fix is *in the tree*, not *fixed*. Say which
   in both the issue and the wiki page.

See also: `propose-issue`, `wiki-sync`, `just threads` /
`flake/scripts/threads.sh`.
