---
name: boyscouting
description: Fixes small, local problems in files you're already editing, in the same commit as the main task.
when_to_use: Noticing a stale comment, dead import, unused variable or similar small flaw in a file you're changing for another reason.
---

# Boyscouting

## Applies to

Use this when you are editing a file for a real task and notice something small and local: a stale comment, dead import, misnamed variable, duplicated three-liner, or missing `.gitignore` entry next to the code you are changing. Do not use it for:

- a defect worth tracking: `propose-issue`
- a stale factual claim in `wiki/` or `AGENTS.md`: `wiki-sync`
- a deliberate broad tidy-up: `trim-docs`, or state it and make it the task

## The rule

Fix only what the diff touches or sits next to. Put the fix in the same commit as the main task and say in the commit message that it is incidental. Leave everything else you noticed alone.

## What qualifies

- The fix is small, obviously correct, and reviewable in seconds next to the real change: a typo, an unused variable, a comment describing code three edits ago, inconsistent formatting in a block you already rewrote.
- The fix is in a file (or adjacent lines) you are editing anyway. If you have to open a file you otherwise would not, it is a separate task.
- The fix does not change behavior, an interface, or anything another module depends on. If you cannot tell that it is behavior-neutral, it needs the main change's verification and is not a quick tidy ("bugs here serialize", `AGENTS.md`).

## What doesn't

- **A real bug**, even a tiny one, once it has a failure scenario: use `propose-issue`, unless the user is present and says to fix it now.
- **A stale wiki or `AGENTS.md` claim** that your change causes: use `wiki-sync` in the same change.
- **A rename or restructure** because you would have written it differently: skip it or mention it.
- **A file you were not going to touch**: separate task. Use `propose-issue` if it is a bug, otherwise mention it in your reply.
- **A module-style-guide violation** found while only reading the file: mention it, do not fix it.

## Why the boundary

This repo has one reviewer and runs at homelab scale (`AGENTS.md`: "Homelab, not production"). A diff that outgrows its purpose is harder to review: a "fix the sops path" PR that also reformats an unrelated module buries the real change. A small, labeled fix fits `ship`'s single-purpose-branch rule.

## Steps

1. Spot something small in a file you are already changing.
2. If it needs a file you were not opening, or changes behavior, stop. Use `propose-issue`, `wiki-sync`, or a mention.
3. Make the fix, minimal and local.
4. Report it ("also removed an unused import in the same file") and add a short trailing clause to the commit message, not the summary line.
5. If it is bigger than a drive-by (more than a few lines, or a second file), propose it separately.

## See also

`propose-issue` (noticed, not fixed), `wiki-sync` (docs your change staled), `trim-docs` (deliberate conciseness pass).
