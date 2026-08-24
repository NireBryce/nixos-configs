---
name: wiki-sync
description: Check whether a change you just made leaves a wiki/ article stale, and fix it in the same change.
---

# Keeping the local wiki in sync

## Applies to

Run this at the end of any change to this repo that could make something
`wiki/` states no longer true — not only module/category/host additions
(those two already have their own specific step, see below). Skip it when
the change touches nothing the wiki describes, which is most small
single-module internal edits; check by grepping first rather than
reflexively opening every page.

## Why this exists

`wiki/README.md` and `wiki/styleguide.md` already state the rule:
"whichever session's change makes a page stale corrects it in the same
change, not as a follow-up" — the same discipline `CLAUDE.md` holds itself
to for its own State/Safety sections. That rule is easy to know and easy to
forget in practice, because by the time a change is done and verified,
the wiki is the last thing still in mind. This skill is the deliberate
checklist for closing that loop instead of trusting it'll happen by habit.

## When to run this

At the end of a change that could make a wiki fact wrong, for example:

- moving or renaming a file that a wiki page links to
- changing a fact a `wiki/*.md` page states as current: a host's
  built/booted/switched status, a category's member count, an import list,
  a command, a path, a stateVersion, a count of hosts
- fixing a bug a wiki page describes as open (`open-threads.md`), or
  finding a new one worth recording there
- reorganizing categories, splitting a module, or anything that changes
  which directory something lives under

Two narrower cases already have their own specific instructions — read
those first if one applies, then use this skill for anything they don't
cover:

- **Adding, removing, or renaming a module, or changing a category's
  membership** — the `new-flake-module` skill's "Keep the wiki in sync"
  section: update that category's `wiki/categories/<name>.md` and the
  table in `wiki/categories/README.md`.
- **Adding a host, or changing which categories a host imports** — the
  `new-host-config` skill's wiring step: update `wiki/hosts.md`'s host
  table and the "Imported by" line on every affected
  `wiki/categories/*.md` article.

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
3. **Read each candidate against the new state, not against memory** —
   re-derive the fact (`just modules`, `hostname`, the file itself) the
   way `CLAUDE.md`'s "bugs here serialize" and "did it work before" both
   insist on, rather than trusting what the page already says or what you
   assume changed.
4. **Edit stale pages in the same change**, following `wiki/styleguide.md`:
   - Dates absolute (`2026-08-23`), never relative ("today", "last week").
   - Relative links recomputed for the actual file depth; verify each
     resolves after editing.
   - kebab-case naming; `README.md` reserved for a directory's own index.
   - If a fix balloons into new prose that argues a fact rather than
     linking to it, that's a sign the fact belongs in the linked file's
     own header instead — `wiki/README.md`'s whole reason for being a link
     layer rather than a rewrite.
5. **If nothing in `wiki/` actually mentions what changed, say so and
   stop.** Don't manufacture an edit to a page the change doesn't touch —
   most changes are exactly this case, and the check itself is the value,
   not an edit for its own sake.

## See also

- `wiki/styleguide.md` — the house rules this skill's edits have to follow.
- `wiki/README.md` — why the wiki is a link layer, and "keeping this from
  rotting".
- `new-flake-module` skill — the specific module/category-membership case.
- `new-host-config` skill — the specific host-addition case.
