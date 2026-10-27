---
name: boyscouting
description: Fixes small, local problems in files you're already editing, in the same commit as the main task.
when_to_use: Noticing a stale comment, dead import, unused variable or similar small flaw in a file you're changing for another reason.
---

# Boyscouting

## Applies to

Editing a file for a real task and noticing something small and local: a stale comment, dead import, misnamed variable, duplicated three-liner, missing `.gitignore` entry next to code you're changing. Not for:

- a defect worth tracking: `propose-issue`
- a stale factual claim in `wiki/` or `AGENTS.md`: `wiki-sync`
- a deliberate broad tidy-up: `trim-docs`, or state it and make it the task

## The rule

Fix only what the diff touches or sits next to. Anything else you noticed is not in scope. Put the fix in the same commit as the main task and say in the commit message that it's incidental.

## What qualifies

- Small, obviously correct, reviewable in seconds next to the real change: a typo, an unused variable, a comment describing code three edits ago, inconsistent formatting in a block you already rewrote.
- In a file (or adjacent lines) you're editing anyway. Having to open a file you otherwise wouldn't makes it a separate task.
- Doesn't change behavior, an interface, or anything another module depends on. If you can't tell it's behavior-neutral, it needs the main change's verification and isn't a quick tidy ("bugs here serialize", `AGENTS.md`).

## What doesn't

- **A real bug**, even a tiny one, once it has a failure scenario: `propose-issue`, unless the user is present and says to fix it now.
- **A stale wiki or `AGENTS.md` claim** your change causes: `wiki-sync`, in the same change, following its steps.
- **A rename or restructure** because you'd have written it differently: that's opinion. Skip it or mention it.
- **A file you weren't going to touch**: separate task. `propose-issue` if it's a bug, otherwise mention it in your reply.
- **A module-style-guide violation** found while only reading the file: mention it, don't fix it.

## Why the boundary

One reviewer, homelab scale (`AGENTS.md`: "Homelab, not production"). A diff that outgrows its purpose is harder to review: a "fix the sops path" PR that also reformats an unrelated module buries the real change. Small and labeled fits `ship`'s single-purpose-branch rule.

## Steps

1. Spot something small in a file you're already changing.
2. If it needs a file you weren't opening, or changes behavior, stop. Use `propose-issue`, `wiki-sync`, or a mention.
3. Make the fix, minimal and local.
4. Report it ("also removed an unused import in the same file") and add a short trailing clause to the commit message, not the summary line.
5. If it's bigger than a drive-by (more than a few lines, or a second file), propose it separately.

## See also

`propose-issue` (noticed, not fixed), `wiki-sync` (docs your change staled), `trim-docs` (deliberate conciseness pass).
