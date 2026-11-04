---
name: new-wiki-page
description: Creates a wiki page with the date line, Contents block, sibling decision and index entry that wiki-lint requires.
when_to_use: Creating any new page under wiki, such as a category page, a homelab runbook or a topic page.
---

# Creating a new wiki page

## Applies to

Use this skill when creating any new page under `wiki/` (a category page for a
new homelab service, a `homelab/` runbook, a top-level topic page). Do not use
it for fixing facts on an existing page (`wiki-sync`), tightening prose
(`trim-docs`), moving resolved narrative out (`wiki-history-sweep`), or
writing a skill (`new-skill`).

## Steps

1. **Name and place it.** Use kebab-case; `00-INDEX.md` is reserved for a
   directory's own index. Plan inbound links in the same change
   (`wiki/00-INDEX.md`, the parent directory's index, or the pages holding
   the prose this page extracts). An unlinked page is never found.
2. **Skeleton**: `# Title`, then `_Last modified: YYYY-MM-DD_` right after
   (absolute date, today), intro prose, then `## Contents` via
   `factcheck fix-contents <page>`, never by hand. Pass only the page you
   created (the insert path also adds blocks to exempt pages).
3. **Sibling decision.** Under about 1,000 words and human-facing: no
   `-for-agents.md` yet. Past 1,000 words: add a sibling if the page is long
   narrative, otherwise make `## Quick facts` the first section (runbooks,
   how-tos, reference pages); see `wiki/meta/styleguide.md` "Two audiences per
   page". Whenever a pair is created, each page links to the other and the
   sibling has its own `_Last modified:`. The Contents exemptions differ: a
   `-for-agents.md` sibling never carries Contents; a `-history.md` companion
   always does but never gets a sibling.
4. **Category page extras**: run `just wiki-gen` (it adds the page's row to
   the generated Index table in `wiki/config-structure/categories/00-INDEX.md`;
   write that row's Imported by cell). Add `## Imported by` naming every
   importing host. `check_imports` reads whichever copy exists (human page,
   sibling, or both), so grep first.
5. **Register before landing**: add index rows; add inbound links from the
   pages it extracts from (leave a pointer, not a duplicate); if the page
   documents a credential, add a `maintenance-schedule` row in the same
   change.
6. **Run `just wiki-lint`.** It checks imports, counts, links, anchors,
   recipes, dates and pair rules.

## Traps

- Dates are absolute (`wiki-sync`'s edit rules apply).
- `gen-contents` across exempt pages (`agent-lessons-learned*`,
  `-for-agents.md`) adds blocks that should not exist (2026-09-11, about 20
  pages; see `wiki-history-sweep` traps).
- A category page usually earns its sibling by its second real incident, not
  at creation (`new-homelab-service` step 9). An empty "for later" sibling
  makes the `siblings` check watch a page with no content.

## See also

`wiki/meta/styleguide.md` (Content shape, Directory hierarchy, Two audiences
per page) and `wiki/meta/styleguide-for-agents.md`; `wiki-sync`; `trim-docs`;
`new-homelab-service` step 9.
