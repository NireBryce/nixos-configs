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
- changing a fact a `wiki/*.md` page states as current: a host's
  built/booted/switched status, a category's member count, an import list,
  a command, a path, a stateVersion, a count of hosts
- fixing a bug a wiki page describes as open (`open-threads.md`), or
  finding a new one worth recording there
- reorganizing categories, splitting a module, or anything that changes
  which directory something lives under

Two narrower cases have their own instructions — read those first:

- **Module added/removed/renamed, or a category's membership changed** —
  `new-flake-module`'s "Keep the wiki in sync": update that category's
  `wiki/categories/<name>.md` and `wiki/categories/README.md`'s table.
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
5. **If nothing in `wiki/` mentions what changed, say so and stop.** Don't
   manufacture an edit — most changes are exactly this case; the check
   itself is the value.

## See also

- `wiki/styleguide.md` — the house rules this skill's edits have to follow.
- `wiki/README.md` — why the wiki is a link layer, and "keeping this from
  rotting".
- `new-flake-module` skill — the specific module/category-membership case.
- `new-host-config` skill — the specific host-addition case.
