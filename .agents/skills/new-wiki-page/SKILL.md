---
name: new-wiki-page
description: How to create a new wiki page with the date line, Contents block, sibling decision, and index registration wiki-lint requires.
---

# Creating a new wiki page

## Applies to

Creating any new page under `wiki/` — a category page for a new homelab
service, a `homelab/` runbook, a top-level topic page. Not: fixing facts
on an existing page (`wiki-sync`), tightening prose (`trim-docs`), moving
resolved narrative out (`wiki-history-sweep`), or writing a skill
(`new-skill` — the analogous act for `.agents/skills/`).

## Steps

1. **Name and place it first.** kebab-case; `00-INDEX.md` is reserved for
   a directory's own index, never a content page. A page nothing links to
   is dead weight — plan the inbound links (the topic index
   `wiki/00-INDEX.md`, the parent directory's index, or the pages that
   today hold the prose this page extracts) as part of the same change.
2. **Skeleton**: `# Title`, then `_Last modified: YYYY-MM-DD_` right after
   it (absolute date, today), then intro prose, then `## Contents` —
   generate the block with
   `python3 wiki/scripts/check_wiki.py gen-contents <page>`, never by
   hand. Pass only the page you created: the insert path happily adds
   Contents blocks to exempt pages too.
3. **Make the sibling decision deliberately.** Under ~1,000 words and
   human-facing: no `-for-agents.md` yet — expect one once it passes
   1,000 words or accumulates agent-actionable density
   (`wiki/styleguide.md`'s "Two audiences per page"). Created now or
   later, the pair needs back-links in both directions and the sibling
   gets its own `_Last modified:` line. The exemption lists differ and
   conflating them is the classic mistake: a `-for-agents.md` sibling
   never carries a Contents block, while a `-history.md` companion always
   does but never gets a sibling.
4. **A category page has two extra obligations**: a row in
   `wiki/categories/00-INDEX.md`'s Index table, and a `## Imported by`
   section naming every importing host — `check_imports` reads whichever
   copy exists (human page, sibling, or both), so grep before assuming
   where it lives.
5. **Register it before landing**: index rows, inbound links from the
   pages it extracts from (leave a pointer, don't leave a duplicate), and
   — if the page documents a credential — a `maintenance-schedule` row in
   the same change.
6. **`just wiki-lint` before landing.** It checks the mechanical claims
   the page now makes (imports, counts, links, anchors, recipes, dates)
   and the pair rules from step 3.

## Traps

- **Dates absolute**, never relative — `wiki-sync`'s edit rules apply to
  a new page too.
- **`gen-contents` across exempt pages** adds blocks that shouldn't exist
  (`lessons-learned*` and `-for-agents.md` siblings are Contents-exempt;
  hit 2026-09-11, ~20 pages, reverted by hand — see `wiki-history-sweep`'s
  traps section for the full shape).
- **A category page usually earns its sibling by its second real
  incident**, not at creation (`new-homelab-service` step 9). Creating an
  empty sibling "for later" puts the `siblings` staleness check on watch
  over a file with nothing in it.

## See also

- `wiki/styleguide.md` — the shape rules (Content shape, Directory
  hierarchy, "Two audiences per page");
  `wiki/styleguide-for-agents.md` is the condensed checklist.
- `wiki-sync` — the staleness half, for every change after this one.
- `trim-docs` — when the page has grown past what its facts need.
- `new-homelab-service` step 9 — the recurring creator of category pages.
