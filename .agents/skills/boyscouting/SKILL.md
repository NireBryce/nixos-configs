---
name: boyscouting
description: How to leave code you're already touching a little better than you found it, without letting the cleanup outgrow the task that brought you there.
---

# Boyscouting

## Applies to

Editing a file for a real task and noticing something small and local to fix in passing — stale comment, dead import, misnamed variable, duplicated three-liner, missing `.gitignore` entry next to code you're changing. Not: a defect worth tracking (`propose-issue`), a stale factual claim in `wiki/`/`AGENTS.md` (`wiki-sync`), or a deliberate broad tidy-up (`trim-docs`, or state it and make it the actual task).

## The rule

Campsite rule, but only the ground you're standing on: scope is "touched by this diff or immediately adjacent," not "anything imperfect I noticed." The fix rides in the same commit as the motivating task, labeled incidental in the commit message, not folded in silently.

## What qualifies

- Small, obviously correct, reviewable in seconds beside the real change (typo, unused variable, comment describing code three edits ago, formatting inconsistency in a block you already rewrote).
- Confined to a file (or adjacent lines) you're editing anyway. Needing to open a file you otherwise wouldn't makes it a separate task.
- Doesn't change behavior, an interface, or anything another module depends on. If not sure it's behavior-neutral, it needs the main change's verification, so it isn't a quick tidy ("bugs here serialize", `AGENTS.md`).

## What doesn't

- **A real bug**, even tiny, once it has a failure scenario: `propose-issue`, unless the user is present and says fix it now.
- **A stale wiki/AGENTS.md claim** your change causes: `wiki-sync`, in the same change, following its steps.
- **Renaming/restructuring** because you'd have written it differently: opinion; skip or mention.
- **Any file you weren't already going to touch**: scope creep; separate task, `propose-issue` if a bug, else a mention in your reply.
- **A module-style-guide violation found while only reading** the file: mention, don't fix.

## Why the boundary

Homelab-scale, one reviewer (`AGENTS.md`: "Homelab, not production"). A diff that grew past its purpose is harder to review: a "fix the sops path" PR that also reformats an unrelated module hides the change in noise. Small and labeled is what stays consistent with `ship`'s single-purpose-branch discipline.

## Steps

1. Notice something small in a file you're already changing.
2. Needs a file you weren't opening, or changes behavior? Stop: use `propose-issue`, `wiki-sync`, or a plain mention.
3. Make the fix, minimal and local.
4. Say so when reporting ("also fixed an unused import in the same file") and in the commit message as a short trailing clause, not in the main summary line.
5. Real but bigger than a drive-by (more than a few lines, or a second file): propose it separately.

## See also

`propose-issue` (noticed, not fixed), `wiki-sync` (docs staled by your change), `trim-docs` (deliberate scoped conciseness pass).
