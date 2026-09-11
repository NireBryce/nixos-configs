---
name: wiki-sync
description: Check whether a change you just made leaves a wiki/ article stale, and fix it in the same change.
---

# Keeping the local wiki in sync

## Applies to

Run at the end of any change that could make something `wiki/` states no
longer true. The rule (wiki/README.md, styleguide.md): *whichever session's
change makes a page stale corrects it in the same change, not as a
follow-up.* Skip it when the change touches nothing the wiki describes —
most small single-module internal edits; grep first rather than reflexively
opening every page.

## When to run this

At the end of a change that could make a wiki fact wrong, for example:

- moving or renaming a file that a wiki page links to
- changing a fact a `wiki/*.md` page states as current: a category's member
  count, an import list, a command, a path, a stateVersion, a count of
  hosts (host switch/boot status is deliberately *not* a wiki fact — it
  rots; it's a live check per `AGENTS.md`'s State section)
- fixing a bug a wiki page describes as open (`open-threads.md`), or
  finding a new one worth recording there
- reorganizing categories, splitting a module, or anything that changes
  which directory something lives under

Two narrower cases have their own instructions — read those first:

- **Module added/removed/renamed, or a category's membership changed** —
  `new-flake-module`'s "Keep the wiki in sync": update that category's
  `wiki/categories/<name>.md`, its `-for-agents.md` sibling if it has one,
  and `wiki/categories/README.md`'s table.
- **Host added, or its category imports changed** — `new-host-config`'s
  wiring step: `wiki/hosts.md`'s table plus the "Imported by" line on every
  affected `wiki/categories/*.md`.

## Procedure

1. **Name what changed, in wiki terms.** Turn the diff into a short list of
   facts, not files — "host X now imports category Y", "path A moved to
   B", "host C booted for the first time", "bug D (open-threads.md) is
   fixed". This is the thing to search for, not the commit description.
2. **Find candidate pages** by grepping the wiki for the old name, path, or
   fact, and by checking the pages most likely to hold a table or count
   that intersects it:
   ```sh
   grep -rln "<old-name-or-path-or-fact>" wiki/
   ```
   `wiki/categories/README.md` (the category table), `wiki/hosts.md` (the
   host table), and `wiki/architecture.md` are the usual hits for anything
   structural; `wiki/open-threads.md` for anything that was tracked as
   pending.
3. **Read each candidate against the new state, not memory** — re-derive
   the fact (`just modules`, `hostname`, the file itself) rather than
   trusting what the page says or what you assume changed.
4. **Edit stale pages in the same change**, following `wiki/styleguide.md`:
   - Dates absolute (`2026-08-23`), never relative.
   - Relative links recomputed for the file depth; verify each resolves.
   - kebab-case naming; `README.md` reserved for a directory's own index.
   - A fix ballooning into prose that argues a fact instead of linking to
     it means the fact belongs in the linked file's own header.
   - **Bump the page's `_Last modified: YYYY-MM-DD_` line** (right after
     the title) to today, on every page you actually edited in this step —
     not on a page you only read and found still correct. `python3
     wiki/scripts/check_wiki.py dates` (part of `just wiki-lint`) only
     catches the line being missing or malformed, never a stale date left
     behind; that half is this step.
5. **Edit the `-for-agents` sibling of every page you touched, in the same
   change.** Long wiki pages come in pairs — `<page>.md` is the explanation,
   `<page>-for-agents.md` is the same ground condensed to facts
   (`wiki/styleguide.md`'s "Two audiences per page"). A fact that changed on
   one side has almost always changed on the other, and the sibling is the
   copy an agent actually reads, so leaving it stale is the worse half to
   leave stale.

   `check_wiki.py siblings` (part of `just wiki-lint`) catches the common
   miss mechanically: it fails when a sibling's `_Last modified:_` predates
   its source's, which is exactly what bumping step 4's date on the human
   page alone produces. **Don't satisfy it by bumping the sibling's date** —
   that turns a caught omission into a silent one. Make the edit, then bump.

   When the source edit genuinely has nothing to sync — a reorder, a typo,
   a rewording of a fact the sibling states its own way — say so on the
   sibling instead, under its `_Last modified:_` line:

   ```
   _Sibling reviewed: 2026-09-11 -- header reorder, no facts moved_
   ```

   A reviewed date at or after the source's clears the finding without
   touching the sibling's own modification date. The reason is mandatory and
   a future date is itself a finding, because the whole value of this over a
   silent date bump is that the claim is auditable in the diff.

   Two asymmetries worth knowing rather than re-deriving:

   - **Narrative changes are one-sided.** Adding the account of how
     something was verified belongs on the human page only; the sibling
     carries the conclusion, not the story. Bumping the human page's date
     for that still trips the check — which is the `_Sibling reviewed:_`
     case above, once you've confirmed the sibling genuinely needs no edit.
     (Until 2026-09-11 this said to bump the sibling's date instead, which
     contradicted the paragraph above telling you never to do that; there
     was no third option to point at yet.)
   - **A category page's `## Imported by` may live on either page, or
     both.** `check_imports` checks whichever exist, so update every copy
     that's there; grep rather than assuming which page has it.

6. **If nothing in `wiki/` mentions what changed, say so and stop.** Don't
   manufacture an edit — most changes are exactly this case; the check
   itself is the value.

## See also

- `wiki/styleguide.md` — the house rules this skill's edits have to follow,
  including "Two audiences per page" (what belongs in a `-for-agents`
  sibling and what deliberately doesn't).
- `wiki/styleguide-for-agents.md` — those rules condensed, if you only need
  the checklist.
- `wiki/README.md` — why the wiki is a link layer, and "keeping this from
  rotting".
- `new-flake-module` skill — the specific module/category-membership case.
- `new-host-config` skill — the specific host-addition case.
