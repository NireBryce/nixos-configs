---
name: trim-docs
description: How to tighten wiki pages, skills, and AGENTS.md prose for conciseness without breaking wiki-lint checks or losing load-bearing facts.
---

# Trimming docs for conciseness

## Applies to

Asked to "lint", "tighten", "trim", or "make more concise" the wiki,
`.claude/skills/*/SKILL.md`, or `AGENTS.md`. Not: fixing a fact that went
stale (`wiki-sync`), writing a new page (`wiki/styleguide.md` has the shape
rules), or module code comments (`wiki/module-style-guide.md`).

## Baseline first

`just wiki-lint` before editing, and note the REVIEW findings — you must be
able to show you added none. Re-run after; hard findings must stay at zero
and REVIEW findings must not grow.

## What lint pins in place

These claim shapes are checked mechanically (`wiki/scripts/check_wiki.py`);
edits must preserve them:

- **"Imported by" sections and the categories/README.md Index table**: every
  importing host named, or the exact blanket phrase ("all 3 NixOS hosts",
  "all four hosts"). A host named to say it *doesn't* import is fine
  (REVIEW, not failure).
- **The `.sops.yaml ... enrolls ... —` sentence** in
  impermanence-and-secrets.md and AGENTS.md: keep the em-dash terminator and
  all four hosts.
- **`## Contents` blocks** must match the page's headings. After renaming,
  adding, or removing any heading, run `python3
  wiki/scripts/check_wiki.py gen-contents <page>`.
- **Anchors are GitHub slugs of headings.** Renaming a heading silently
  breaks every inbound `page.md#anchor` link — grep `page.md#` across wiki/
  and AGENTS.md before renaming, or don't rename.
- **lessons-learned § numbers are referenced repo-wide** (AGENTS.md, skills,
  category pages, by number). Never renumber, merge, or drop a §.

## Cut

- The same incident narrated on several pages: keep the fullest account in
  one place — a module header or one page — and link from the rest.
- How something came to be, told as a story: one dated line instead.
- Meta-commentary: "this is the same reasoning as X", "this page stays the
  index, that page the log" said twice, restating a rule the linked file
  already states.
- Cross-references in bulk: one pointer per fact, not three.

## Keep

Mechanisms, exact option/flag/unit names, commands, dates, host names,
per-app asymmetries, verification methods and what was actually verified,
and every checkable claim shape above. When unsure whether a sentence is
load-bearing, it is.

## Calibrate

- The metric is facts per sentence, not word count. Dense is not verbose:
  don't gut lessons-learned's numbered lessons or a skill made of real
  incidents for marginal savings — trim their narration and intros instead.
- Wiki pages stay human-readable prose; skills may be terser.

## Method

`wc -w` the candidates and work biggest-first, tiered: full rewrite for the
worst offenders, targeted edits where the file is already tight. Read the
whole file before editing — much of this repo's prose is load-bearing in
the ways listed above. Factual drift noticed in passing gets fixed in the
same change and called out in the commit message (wiki-sync's rule applies
to trims too).
