# Wiki style guide, for agents

_Last modified: 2026-09-11_

Condensed from [styleguide.md](styleguide.md), which keeps the reasoning and
the precedents. Rules only here. The *repo's* style guide is
[conventions.md](conventions.md); module formatting is
[module-style-guide.md](module-style-guide.md).

## Where a page goes

| Tier | Holds |
|---|---|
| `wiki/*.md` | cross-cutting topics belonging to no one category |
| `wiki/categories/<name>.md` | one page per real category — a directory under `flake/modules/` with its own `dirsAsCategory.nix`. Indexed in [categories/README.md](categories/README.md)'s table. |
| `wiki/categories/<name>/` | escape hatch, used once (`shell-config`). Triggered by one *member* accumulating an investigation, not by length. `README.md` becomes the category article; each deep-dive is named after its subject. **No third tier under it.** |
| `wiki/categories/<name>-history.md` | resolved incidents whose *outcome* matters but whose blow-by-blow shouldn't load every read. **Not the default** — the test is whether understanding the *current* behavior needs the paragraph. |
| `wiki/homelab/` | usage tier: operating a service, for a reader who wants to *do something with it*. |
| `<page>-for-agents.md` | the condensed sibling; see below. |

No per-category page for `nirePackages/*` subcategories or `nireHost/*`
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
   before it (moved 2026-09-11; it sat under the title until then).

**Don't hand-derive anchors.** Run `python3 wiki/scripts/check_wiki.py
gen-contents <page>` after adding, renaming, or removing any heading; it's
idempotent. A hand-derived anchor already got it wrong once.

Exempt from `## Contents`: `lessons-learned.md`, `lessons-learned/`
articles, and `-for-agents.md` siblings.

## Two audiences per page

A page over **1,000 words** gets a `<page>-for-agents.md` sibling. The
original stays explanation for a human reading cold; the sibling is the same
ground at maximum information density, for something that loaded it to get
one thing done.

**In**: paths, option and flag names, exact commands, config-block shapes,
host lists, each trap as one declarative line. Tables wherever one fits.
**Out**: how it came to be, what was tried first, who confirmed it and when,
the reasoning behind a choice, meta-commentary, see-also sprawl.

Exempt from needing one: `lessons-learned*`, `*-history.md`. Under 1,000
words it's allowed but usually a loss — `homelab/README.md` was tried and
dropped.

Checked by `check_wiki.py siblings`, which is what makes this the wiki's one
deliberate duplication rather than a future stale claim:

- **the sibling's `_Last modified:_` must not predate its source's** — edit
  both in the same change or the run fails and names the pair. This is the
  point; the rest is bookkeeping.
- **escape hatch for a no-op source edit** (reorder, typo): a
  `_Sibling reviewed: YYYY-MM-DD -- <reason>_` line on the sibling, dated at
  or after the source's. Reason mandatory; future date is a finding. Never
  bump the sibling's `_Last modified:_` to clear a stale finding.
- every sibling has a source; every page over the line has a sibling
- each links to the other
- sibling within **50%** of the source's `wc -w` — **REVIEW only, never a
  failure.** Cut narration, not facts; if what's left is load-bearing, over
  is the right answer.
- a category page's `## Imported by` may live on **either** page, or both

## Index over restatement

Link to the real source — a module header, `CLAUDE.md`, a skill — rather
than copying it in. Four exceptions, each on stated terms:

- `lessons-learned.md` and `module-style-guide.md` — nothing to link to.
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
- `README.md` is reserved for a directory's index — never a single-topic
  page.
- **Name a usage page for the reader's task, not the module.** A plural noun
  reads as a list of the things: `golinks.md` → `creating-golinks.md`
  (2026-09-11), matching `reaching-services.md`. A bare noun is fine when
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

No CI ties links to what they point at beyond `just wiki-lint`. The rule:
whichever change makes a page stale corrects it in the same change. Skill
`wiki-sync`.

## See also

[styleguide.md](styleguide.md) · [README.md](README.md) ·
[categories/README.md](categories/README.md)
