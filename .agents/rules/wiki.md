---
paths:
  - "wiki/**"
---

# Editing wiki pages

Start at `wiki/00-INDEX-for-agents.md`, which routes by task. Procedure for a
change that may have made a page stale: skill `wiki-sync`. New page: skill
`new-wiki-page`.

## Long pages: a pair or a Quick facts section

A page over 1,000 words has one of two shapes:

- **A pair.** `<page>.md` is explanation for a human reading cold.
  `<page>-for-agents.md` covers the same ground at maximum density: paths,
  option names, commands, host lists, every trap as one line, no narrative.
  Read the `-for-agents.md` half.
- **One page opening with `## Quick facts`.** Used for compact or procedural
  pages (runbooks, how-tos), where a sibling only restated the page and doubled
  every edit. Read that section first.

## Keeping a pair in step

The pair duplicates content, against the wiki's "index over restatement" rule
(`wiki/00-INDEX.md` records that one fact in two places has caused repeated
bugs). It is allowed because a check guards it.

`factcheck siblings` (part of `just wiki-lint`) fails when:

- a sibling's `_Last modified:_` predates its source's, or
- a page over 1,000 words has neither a sibling nor a first-section
  `## Quick facts`.

So edit the sibling in the same change as its source. Don't bump the
sibling's date to satisfy the check: that hides the omission. If the edit has
nothing to sync (a reorder, a typo), add a dated `_Sibling reviewed:_` line
with the reason to the sibling.

Full rule and the cut list: "Two audiences per page" in
`wiki/meta/styleguide.md`.

## Other pages

- `wiki/00-INDEX.md` is the topic index; `00-INDEX-for-agents.md` is its
  condensed form. A change that makes a wiki page stale corrects it in the
  same change; `just wiki-lint` checks the mechanical claims.
- `wiki/agent-lessons-learned.md` lists every past mistake as one line,
  grouped by the moment it applies, each naming the skill or section that
  carries its rule and what enforces it. Full accounts are
  `wiki/agent-lessons-learned/<N>-*.md`. § numbers are stable, cited from many
  files, and never renumbered. It has no `-for-agents` sibling because it is
  already written for agents. A new lesson goes in its Home page as well as
  the index: a rule only that page states reaches nobody.
