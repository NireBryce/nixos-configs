# Wiki style guide, for agents

_Last modified: 2026-10-05_

Condensed from [styleguide.md](styleguide.md). Rules only here. The *repo's* style guide is
[conventions.md](conventions.md); module formatting is
[module-style-guide.md](module-style-guide.md).

## Where a page goes

| Tier | Holds |
|---|---|
| `wiki/*.md` | cross-cutting topics belonging to no one category |
| `wiki/categories/<name>.md` | one page per real category — a directory under `flake/modules/` with its own `dirsAsCategory.nix`. Indexed in [categories/00-INDEX.md](categories/00-INDEX.md)'s table. |
| `wiki/categories/<name>/` | escape hatch, used once (`shell-config`). Triggered by one *member* accumulating an investigation, not by length. `00-INDEX.md` becomes the category article; each deep-dive is named after its subject. **No third tier under it.** |
| `wiki/categories/<name>-history.md` | resolved incidents whose *outcome* matters but whose blow-by-blow shouldn't load every read. **Not the default** — the test is whether understanding the *current* behavior needs the paragraph. One companion per **category**, not per page. Procedure: skill `wiki-history-sweep`; candidates: `just wiki-history-candidates`. |
| `wiki/homelab/` | usage tier: operating a service, for a reader who wants to *do something with it*. |
| `wiki/experiments/` | open questions: one page per problem **instrumented but not yet diagnosed** — symptom, established, ruled out, under test. Must mark settled vs under-test claims (`fact-hygiene`). On resolution the outcome moves to `lessons-learned.md` or the category page and the page goes. |
| `<page>-for-agents.md` | the condensed sibling; see below. |

No per-category page for `packages-config/*` subcategories or `host-config/*`
bundles.

A category page's order: **what's in it → category-specific mechanism notes
→ imported by → see also.**

## Required on every page

1. `# Title`
2. `_Last modified: YYYY-MM-DD_` — **bump it in the same change you edit
   content in.** A purely mechanical touch doesn't need it. This line is
   load-bearing for the `siblings` check.
3. intro prose (what this page is), then the condensed-version blockquote
4. `## Contents` — one bullet per `##` heading, **after** the intro, not
   before it.

**Don't hand-derive anchors.** Run `python3 wiki/scripts/check_wiki.py
gen-contents <page>` after adding, renaming, or removing any heading; it's
idempotent. A hand-derived anchor already got it wrong once.

Exempt from `## Contents`: `lessons-learned.md`, `lessons-learned/`
articles, and `-for-agents.md` siblings. **Not the same list as the sibling
exemption** — `-history.md` needs no sibling but does carry a Contents
block. A non-exempt page with headings and no block is a MISSING CONTENTS
finding.

## Two audiences per page

A page over **1,000 words** gets a `<page>-for-agents.md` sibling **or**
opens with `## Quick facts` (first section after Contents).

- **Sibling** when the human page is long narrative and the dense version is
  a fraction of it. The original stays explanation for a human reading cold;
  the sibling is the same ground at maximum information density.
- **Quick facts** when the page is already compact/procedural (runbook,
  how-to, reference). Fold an existing pair when the sibling is over ~45% of
  its source's words or the halves mostly change in the same commits. Dense
  facts at the top, body unchanged, sibling deleted, links repointed to
  `#quick-facts`, old sibling's name in the lead-in. Folded 2026-10-01:
  `name-resolution.md`, `maintenance.md`, `homelab/creating-golinks.md`,
  `homelab/reaching-services.md`, `homelab/backup-runbook.md`.

**In**: paths, option and flag names, exact commands, config-block shapes,
host lists, each trap as one declarative line. Tables wherever one fits.
**Out**: how it came to be, what was tried first, who confirmed it and when,
the reasoning behind a choice, meta-commentary, see-also sprawl.

Exempt from needing one: `lessons-learned*`, `*-history.md`. Under 1,000
words it's allowed but usually a loss.

Checked by `check_wiki.py siblings`, which is what makes this the wiki's one
deliberate duplication rather than a future stale claim:

- **the sibling's `_Last modified:_` must not predate its source's** — edit
  both in the same change or the run fails and names the pair. This is the
  point; the rest is bookkeeping.
- **escape hatch for a no-op source edit** (reorder, typo): a
  `_Sibling reviewed: YYYY-MM-DD -- <reason>_` line on the sibling, dated at
  or after the source's. Reason mandatory; future date is a finding. Never
  bump the sibling's `_Last modified:_` to clear a stale finding.
- every sibling has a source; every page over the line has a sibling or a
  first-section `## Quick facts`
- each links to the other
- sibling within **50%** of the source's `wc -w` — **REVIEW only, never a
  failure.** Cut narration, not facts; if what's left is load-bearing, over
  is the right answer.
- a category page's `## Imported by` may live on **either** page, or both

## Index over restatement

Link to the real source — a module header, `CLAUDE.md`, a skill — rather
than copying it in. Four exceptions, each on stated terms:

- `lessons-learned.md` and `module-style-guide.md` — nothing to link to.
- `lessons-learned.md` is an index: one `- **§N**` line per lesson (title linking `lessons-learned/<N>-<slug>.md`, the rule, `Home:`, `Enforced:`), under the group where it applies; the article holds the account. The rule also goes in its Home, and a lesson tied to a path or command gets a topic in `.agents/lessons-map.toml` (the lesson-reminder hook's source). `check_wiki.py lessons` enforces the shape and the map.
- `flake-parts-port-notes.md` — the branch it indexed is gone.
- `wiki/homelab/` — the source is often the live service, so synthesized
  content is allowed **if the page says what was verified against the live
  service and what was only transcribed**. `creating-golinks.md`'s closing section is
  the pattern.
- deep-dive pages (`blesh.md`, `carapace.md`) — a cross-tool finding with no
  single code comment to live in.

If an ordinary page starts accumulating *why* rather than *where*, the fact
belongs in the linked file's own header.

## Naming and linking

- kebab-case, matching the subject exactly.
- `00-INDEX.md` is reserved for a directory's index — never a single-topic
  page.
- Each such directory also holds a `README.md` symlink to its
  `00-INDEX.md`, for GitHub's benefit. Edit the target, not the symlink;
  don't link to `README.md`. `check_wiki.py`'s `wiki_md()` skips symlinks,
  and every wiki-walking check goes through it.
- **Name a usage page for the reader's task, not the module.** A plural noun
  reads as a list of the things: `golinks.md` → `creating-golinks.md`,
  matching `reaching-services.md`. A bare noun is fine when
  the page is about the whole service (`forgejo.md`).
- **Dates absolute**, never "today" or "last week".
- Relative paths, recomputed for actual depth. Moving a page means walking
  every link in it.
- Link both directions: index down, page back up.
- A path containing a space needs `<...>` around the link target.
- See-also points sideways to siblings and outward to the general form of a
  trap — usually a skill. The wiki page stays the instance; the skill stays
  the reusable lesson.

## Rotting

Whichever change makes a page stale corrects it in the same change (skill
`wiki-sync`); only `just wiki-lint` checks links.

**Generated tables** (since 2026-10-01): `<!-- generated:<name> ... -->` …
`<!-- /generated -->` regions, rewritten by `just wiki-gen`
(`wiki/scripts/wiki_gen.py`). Today: [hosts.md](hosts.md)'s host table,
both Index tables on [categories/00-INDEX.md](categories/00-INDEX.md),
[module-style-guide-for-agents.md](module-style-guide-for-agents.md#counts)'s
counts.

- Never edit inside a region: change the source the marker names, then
  `just wiki-gen`. A hand edit is reverted on the next run.
- `wiki-lint`'s `generated` check (= `just wiki-gen --check`) fails on a
  stale, missing, unknown or unterminated region, or an empty hand cell.
- Hand-written columns (named in the marker: hosts' Role, categories'
  Imported by) are kept per row. A new row's hand cell starts empty and
  fails lint until written.
- Regeneration is mechanical: no `_Last modified:_` bump, no sibling edit.
  A sibling needing the table carries the same region, not a copy.
- New generated table: a `Region` in `wiki_gen.py` + a case in
  `test_wiki_gen.py`. Prose counts/lists stay prose, under the old checks.

## See also

[styleguide.md](styleguide.md) · [00-INDEX.md](00-INDEX.md)
