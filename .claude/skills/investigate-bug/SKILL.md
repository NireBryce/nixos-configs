---
name: investigate-bug
description: How to check whether a reported bug or symptom is already a known, tracked thread before investigating it yourself.
---

# Checking before investigating

## Applies to

Someone reports an error, a crash, or unexpected/"weird" behavior in this
repo or on one of its hosts, and you're about to start reproducing or
diagnosing it. Run this **before** that — not after you've already found
something and are deciding whether to write it up (that's the
`propose-issue` skill, the filing side of this same problem; this is the
checking side). Doesn't apply when the user already points you at the
specific cause or file — there's nothing to check for in that case.

## Why this exists

A ble.sh/carapace completion bug was reported 2026-08-24 ("weird completion
errors ... over ssh"). It got fully re-derived from a live pty session —
tracing `read` calls through ble.sh's internals, hours of it — before
anyone checked whether it was already known. It was: diagnosed and written
up in `wiki/categories/shell-config/blesh.md` on **2026-08-22**, two days
earlier, one link from `wiki/README.md`'s own top-level index. The
sentence naming it was right there ("an open upstream bug found while
diagnosing a spurious `read` error on Tab-completion") — never checked.
Full account: `claude cave/lessons-learned.md` #39,
[issue #72](https://github.com/NireBryce/nixos-configs/issues/72).

That session had also just spent its whole diagnosis proving a piece of
prose in `CLAUDE.md`/`wiki/README.md` ("check before re-deriving") isn't
enough on its own to make the check actually happen — which is why this is
a skill (a triggered, required step) instead of one more line added to
those files.

## Steps

1. **Before reproducing anything**, run `just threads "<keywords>"` with a
   couple of guesses from the report's own wording (symptom text, error
   message, command name). It checks this repo's GitHub issues
   (`gh issue list --search`) and greps `wiki/`,
   `claude cave/lessons-learned.md`, and `bugs pending submission/` in one
   shot — see `flake/scripts/threads.sh` for exactly what it covers.
2. **A hit means read it fully** — the issue and/or the linked wiki
   deep-dive — before doing anything else. Pick up from where it left off
   (an untested fix, an open question, a "not yet confirmed" status) rather
   than re-deriving from zero. If it's stale or wrong, fix *that* rather
   than starting a parallel investigation.
3. **No hit**: proceed as normal — reproduce for real rather than reasoning
   from source (`CLAUDE.md`'s "evaluating proves nothing, force a real
   run"). Once something is actually diagnosed, don't leave it only in your
   reply: follow `propose-issue`'s flow to file or track it, and
   `wiki-sync` for anything a wiki page should now say.
4. **State fixed vs. verified precisely**, the same discipline the rest of
   this repo holds itself to (`CLAUDE.md`: "treat an undated 'verified' as
   *evaluates*"). A fix that hasn't been through a real `just switch` and a
   live re-check is *in the tree*, not *fixed* — say which one, in the
   issue and the wiki page both, not just in the conversation.

## See also

- `propose-issue` skill — the filing side of this same problem, for a bug
  you noticed rather than one that was reported to you.
- `wiki-sync` skill — keeping the linked wiki page current once you've
  acted, so the next check in step 1 finds the real state.
- `flake/scripts/threads.sh` / `just threads` — the actual command step 1
  runs.
