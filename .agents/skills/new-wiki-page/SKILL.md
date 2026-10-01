---
name: new-wiki-page
description: How to create a new wiki page with the date line, Contents block, sibling decision, and index registration wiki-lint requires.
---

# Creating a new wiki page

## Applies to

Creating any new page under `wiki/` (category page for a new homelab
service, `homelab/` runbook, top-level topic page). Not: fixing facts on an
existing page (`wiki-sync`), tightening prose (`trim-docs`), moving resolved
narrative out (`wiki-history-sweep`), writing a skill (`new-skill`).

## Steps

1. **Name and place it.** kebab-case; `00-INDEX.md` is reserved for a directory's own index. Plan inbound links in the same change (`wiki/00-INDEX.md`, the parent directory's index, or the pages holding the prose this page extracts): an unlinked page is dead weight.
2. **Skeleton**: `# Title`, `_Last modified: YYYY-MM-DD_` right after (absolute, today), intro prose, then `## Contents` via `python3 wiki/scripts/check_wiki.py gen-contents <page>`, never by hand. Pass only the page you created (the insert path also adds blocks to exempt pages).
3. **Sibling decision, deliberately.** Under ~1,000 words and human-facing: no `-for-agents.md` yet. Past 1,000 words: a sibling if the page is long narrative, otherwise a `## Quick facts` first section (runbooks, how-tos, reference pages) -- `wiki/styleguide.md` "Two audiences per page". Whenever created, the pair needs back-links both directions and the sibling its own `_Last modified:`. Exemptions differ (classic mistake): a `-for-agents.md` sibling never carries Contents; a `-history.md` companion always does but never gets a sibling.
4. **Category page extras**: `just wiki-gen` (adds the page's row to `wiki/categories/00-INDEX.md`'s generated Index table; write its Imported by cell), and `## Imported by` naming every importing host (`check_imports` reads whichever copy exists — human page, sibling, or both; grep first).
5. **Register before landing**: index rows; inbound links from the pages it extracts from (leave a pointer, not a duplicate); if it documents a credential, a `maintenance-schedule` row in the same change.
6. **`just wiki-lint`** (checks imports, counts, links, anchors, recipes, dates, pair rules).

## Traps

- Dates absolute (`wiki-sync`'s edit rules apply).
- `gen-contents` across exempt pages (`lessons-learned*`, `-for-agents.md`) adds blocks that shouldn't exist (2026-09-11, ~20 pages; see `wiki-history-sweep` traps).
- A category page usually earns its sibling by its second real incident, not at creation (`new-homelab-service` step 9). An empty "for later" sibling puts the `siblings` check on watch over nothing.

## See also

`wiki/styleguide.md` (Content shape, Directory hierarchy, Two audiences per page) and `wiki/styleguide-for-agents.md`; `wiki-sync`; `trim-docs`; `new-homelab-service` step 9.
