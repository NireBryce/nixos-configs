---
name: trim-docs
description: Tightens wiki pages, skills and AGENTS.md prose without breaking wiki-lint or losing facts that matter.
when_to_use: Asked to lint, tighten, trim or make more concise the wiki, a skill or AGENTS.md.
---

# Trimming docs for conciseness

## Applies to

Use when asked to "lint", "tighten", "trim", or "make more concise" the wiki, `.agents/skills/*/SKILL.md`, or `AGENTS.md`. Do not use it to fix a stale fact (`wiki-sync`), write a new page (`new-wiki-page`), or edit module code comments (`wiki/config-structure/module-style-guide.md`).

## Baseline first

Run `just wiki-lint` before editing and note the REVIEW findings. After editing, hard findings must be zero and REVIEW findings must not have grown.

## What lint pins in place

`factcheck` checks these mechanically through `just wiki-lint`. Preserve them:

- **"Imported by" sections and the Imported by column of the categories/00-INDEX.md Index table.** Name every importing host, or use the exact blanket phrase ("all 3 NixOS hosts", "all four hosts"). Naming a host to say it does *not* import is fine (REVIEW, not failure). The table's other columns are generated; never trim inside a `<!-- generated:... -->` region.
- **The `.sops.yaml ... enrolls ... —` sentence** in impermanence-and-secrets.md and `.agents/rules/secrets.md`. Keep the em-dash terminator and the full host list.
- **`## Contents` blocks** must match the page's headings. After any heading rename, add or removal, run `factcheck fix-contents <page>`.
- **The `_Last modified: YYYY-MM-DD_` line** right after the title. Do not delete it. Bump it to today on every page whose text you change (wiki-sync's rule), and leave it alone on pages you only re-read.
- **`<page>-for-agents.md` siblings.** A sibling dated earlier than its source is a hard finding, so check the sibling in the same pass. The back-link between the two (`factcheck siblings` requires both directions) is checked; do not trim it.
- **Anchors are GitHub slugs of headings.** Renaming a heading silently breaks every inbound `page.md#anchor` link. Grep `page.md#` across wiki/ and AGENTS.md first, or do not rename.
- **agent-lessons-learned § numbers are referenced repo-wide.** Never renumber, merge, or drop a §.

## Cut

- An incident narrated on several pages: keep the fullest account in one place (a module header or one page) and link from the rest.
- How something came to be, told as a story: replace it with one dated line.
- Meta-commentary: "same reasoning as X", "this page stays the index, that the log" said twice, or restating a rule the linked file already states.
- Bulk cross-references: keep one pointer per fact, not three.

## Rewrite for a plain tone

The readers are agents and contributors who have not seen the history and need to act on the text. While trimming, fix these in the passage you touch:

- Lead with the instruction or fact, then give the reason in one sentence. Use imperatives for instructions and declaratives for facts.
- Replace emphasis and filler (*deliberately, critically, importantly, notably, actually, genuinely, simply*, "it's worth noting", "the key insight", "turns out") with what breaks if the point is ignored, or delete it.
- Say literally what you mean: no metaphors ("bitten", "footgun", "paper over"), rhetorical questions, "not X, but Y" framing where a direct statement works, or triplets chosen for rhythm.
- Define a term at first use and use one name per thing.
- Drop narration of the author's process ("I found", "we discovered"). State the result; for an incident, write one dated line of facts.
- Show a command with its expected output instead of describing it.

Fix only passages you are already editing. A repo-wide tone sweep buries the real change in the diff.

## Keep

Keep mechanisms, exact option, flag and unit names, commands, dates, host names, per-app asymmetries, verification methods and what was verified, and every checkable claim shape above. When unsure whether a sentence is load-bearing, treat it as load-bearing.

## Trimming a pair

Trim a page with a `-for-agents.md` sibling from opposite directions:

- **The human page** keeps its prose. Cut narration, repeated incidents and cross-reference spray, not the explanation. It may be long; length is not what a sibling exists to fix.
- **The sibling** is trimmed toward density: only what a reader needs to act, no story. Its 50% word budget is a **REVIEW** finding, never a failure (`wiki/meta/styleguide.md` "Two audiences per page": a fact beats the number). Do not cut a command or option name to meet it.

**Never move a fact from the human page to the sibling to shorten the human page.** That retargets the page at the wrong reader and leaves a hole in the explanation.

## Calibrate

- The metric is facts per sentence, not word count. Do not gut agent-lessons-learned's numbered lessons, or a skill made of real incidents, for marginal savings; trim their narration and intros.
- Wiki pages stay human-readable prose. Skills may be terser. A `-for-agents.md` sibling is terser still; it is the one place in `wiki/` where prose readability is not the goal.

## Method

1. Run `wc -w` on the candidates and work biggest-first, in tiers: full rewrite for the worst offenders, targeted edits where the text is already tight.
2. Read the whole file before editing; much prose is load-bearing as listed above.
3. Fix factual drift you notice in passing in the same change and call it out in the commit message (wiki-sync's rule).
4. After a big trim, run `just wiki-restatement`. It shows where the same prose now lives in two layers, which is the next session's stale-claim risk.
