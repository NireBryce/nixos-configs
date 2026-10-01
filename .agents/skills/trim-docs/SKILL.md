---
name: trim-docs
description: How to tighten wiki pages, skills, and AGENTS.md prose for conciseness without breaking wiki-lint checks or losing load-bearing facts.
when_to_use: Asked to "lint", "tighten", "trim", or "make more concise" the wiki, a skill, or AGENTS.md.
---

# Trimming docs for conciseness

## Applies to

Asked to "lint", "tighten", "trim", or "make more concise" the wiki,
`.agents/skills/*/SKILL.md`, or `AGENTS.md`. Not: fixing a stale fact
(`wiki-sync`), writing a new page (`new-wiki-page`), or module code comments
(`wiki/module-style-guide.md`).

## Baseline first

`just wiki-lint` before editing; note the REVIEW findings. After: hard
findings zero, REVIEW findings not grown.

## What lint pins in place

Checked mechanically (`wiki/scripts/check_wiki.py`); preserve:

- **"Imported by" sections and the categories/00-INDEX.md Index table's
  Imported by column** (the table's other columns are generated -- never trim
  inside a `<!-- generated:... -->` region):
  every importing host named, or the exact blanket phrase ("all 3 NixOS
  hosts", "all four hosts"). Naming a host to say it *doesn't* import is
  fine (REVIEW, not failure).
- **The `.sops.yaml ... enrolls ... —` sentence** in
  impermanence-and-secrets.md and `.agents/rules/secrets.md`: keep the
  em-dash terminator and all four hosts.
- **`## Contents` blocks** must match the page's headings. After any heading
  rename/add/remove: `python3 wiki/scripts/check_wiki.py gen-contents <page>`.
- **The `_Last modified: YYYY-MM-DD_` line** right after the title. Don't
  delete it; bump it to today on every page whose text you change
  (wiki-sync's rule), and leave it alone on pages you only re-read.
- **`<page>-for-agents.md` siblings.** A sibling dated earlier than its
  source is a hard finding: check the sibling in the same pass. The
  back-link between the two (`check_wiki.py siblings` requires both
  directions) is checked, not trimmable cross-reference spray.
- **Anchors are GitHub slugs of headings.** Renaming a heading breaks every
  inbound `page.md#anchor` link silently: grep `page.md#` across wiki/ and
  AGENTS.md first, or don't rename.
- **lessons-learned § numbers are referenced repo-wide.** Never renumber,
  merge, or drop a §.

## Cut

- The same incident narrated on several pages: keep the fullest account in
  one place (a module header or one page), link from the rest.
- How something came to be, told as a story: one dated line.
- Meta-commentary: "same reasoning as X", "this page stays the index, that
  the log" said twice, restating a rule the linked file already states.
- Bulk cross-references: one pointer per fact, not three.

## Keep

Mechanisms, exact option/flag/unit names, commands, dates, host names,
per-app asymmetries, verification methods and what was actually verified,
and every checkable claim shape above. When unsure whether a sentence is
load-bearing, it is.

## Trimming a pair

A page with a `-for-agents.md` sibling is trimmed from opposite directions;
don't conflate them:

- **The human page** keeps its prose. Cut narration, repeated incidents and
  cross-reference spray, not the explanation. It may be long; length is not
  what a sibling exists to fix.
- **The sibling** is trimmed toward density: only what a reader needs to
  act, no story. Its 50% word budget is a **REVIEW** finding, never a
  failure (`wiki/styleguide.md` "Two audiences per page": a fact beats the
  number); don't cut a command or option name to meet it.

**Never move a fact from the human page to the sibling to shorten the human
page.** That retargets the page at the wrong reader and leaves a hole in the
explanation.

## Calibrate

- The metric is facts per sentence, not word count. Don't gut
  lessons-learned's numbered lessons or a skill made of real incidents for
  marginal savings; trim their narration and intros.
- Wiki pages stay human-readable prose; skills may be terser; a
  `-for-agents.md` sibling is terser still, the one place in `wiki/` where
  prose readability is deliberately not the goal.

## Method

`wc -w` the candidates; work biggest-first, tiered: full rewrite for the
worst offenders, targeted edits where already tight. Read the whole file
before editing (much prose is load-bearing as listed above). Fix factual
drift noticed in passing in the same change and call it out in the commit
message (wiki-sync's rule). After a big trim, `just wiki-restatement` shows
where the same prose now lives in two layers, the next session's stale-claim
risk.
