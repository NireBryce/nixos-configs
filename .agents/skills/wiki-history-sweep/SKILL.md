---
name: wiki-history-sweep
description: How to move a wiki page's resolved-incident narrative into a <name>-history.md companion, and how to find the pages that need it.
---

# Sweeping resolved narrative into a `-history.md` companion

## Applies to

A `wiki/` page that has accumulated narrative about things now **fully
resolved** — a first-switch failure since fixed, a superseded plan, a
retired design, a checklist item marked done — where the *outcome* still
matters but the blow-by-blow no longer informs how to use or extend
anything current. Either because you are sweeping deliberately
(`just wiki-history-candidates`), or because you are already editing such a
page and the section is in your way.

Not this skill:

| ask | what to do |
|---|---|
| a `.nix` module's bottom-of-file history block is too long | skill `trim-history` — different tier, different rules |
| a wiki page is just wordy | skill `trim-docs` — tightens in place, moves nothing |
| a page's facts went stale | skill `wiki-sync` |
| a section is *about* a live setting, however old | leave it — see the test below |

## Why this exists — read before sweeping anything

The `<name>-history.md` pattern was created in **one pass** (`68b99813`,
2026-09-02, six category pages at once) and extracted into **exactly once
since** (`5cdd8b2b`, 2026-09-06, when `homelab/backup-runbook.md` was
rewritten as a command reference). Every other commit touching one is
incidental — the `+2 lines` on five of the six is the wiki-wide
`_Last modified:_` commit, not content.

So it is a destination nothing routes to. Pages accumulate; no check asks;
the pattern is documented in `wiki/styleguide.md`'s "Directory hierarchy"
with no procedure attached. That is what this skill and
`just wiki-history-candidates` are for. Issue #288.

## The test, and why it is conservative

From `styleguide.md`, and it is the whole judgement:

> Does understanding the **current** setting/behavior require this
> paragraph, or only understanding how it came to be that way?

**Only the second kind moves.** This repo's house style is "checked, not
assumed", which means it constantly explains a live mechanism *through the
story of how it was discovered*. That reads exactly like history and is
not. `68b99813` kept every instance it found — shortlinks' `AF_NETLINK`
requirement, monitoring's `grafana-secret-key-setup.service`,
reverse-proxy's `handle`-vs-`handle_path` split, virtualization's
default-network gating — and was right to.

Three worked false positives, confirmed by hand 2026-09-11, all of which
the candidate script still scores and none of which should move:

- `categories/landing.md`'s "Two things that could have gone quietly wrong,
  and didn't" — both are confirmed-live facts, and the section states the
  fix if either changes (`alt-status-codes: [302]`).
- `categories/shell-config/blesh.md`'s `read: not a valid identifier` bug —
  the diagnosis narrative is history-shaped; the upstream bug is still open.
- `categories/system.md`'s "Containers vs. virtualization — no longer filed
  here" — the page says outright the trap is live and this is exactly where
  someone remembering the old location will look.

**A section's own justification can expire**, which is the case worth
sweeping for. `reverse-proxy.md`'s `handle`-vs-`handle_path` section was
deliberately kept in 2026-09-02 because it explained a live setting; the
path-prefix routes were retired 2026-09-07, each app got its own vhost, and
there is now no shared prefix for the two directives to disagree about. Same
words, no longer load-bearing.

## Steps

1. **Find candidates**:

   ```sh
   just wiki-history-candidates            # everything scoring > 0
   just wiki-history-candidates --min 6    # stronger hits only
   just wiki-history-candidates --page wiki/categories/reverse-proxy.md
   ```

   Ranked, reporting-only, never fails. **Expect most hits to be wrong** —
   it is a reading list, not a work queue. Read the script's own docstring
   (`wiki/scripts/history_candidates.py`) for what each marker means.

2. **Apply the test above to each candidate, by reading it.** The score is
   a prompt to look, never a verdict. Say out loud which current setting
   the section justifies; if you can name one, it stays.

3. **Confirm the destination exists, or that its absence is intended.** One
   companion **per category, not per page** — that is the rule `5cdd8b2b`
   set when `homelab/backup-runbook.md`'s background moved into
   `categories/backup-history.md` rather than a new
   `backup-runbook-history.md`.

4. **A page that spans several categories has no single destination**, and
   the script says so rather than guessing. `homelab/pending-setup.md` is
   the live example: four of its six items are done, and they belong to
   git-forge, backup, monitoring and shortlinks respectively. Distributing
   them follows the rule and destroys the checklist; a
   `pending-setup-history.md` keeps it together and breaks the rule.
   **Don't settle this silently as a side effect of a sweep** — it sets
   precedent for every future cross-category page. Ask. Issue #288 records
   it as open.

5. **Move the narrative, and leave a summary plus a link behind** — one to
   two sentences, never a bare pointer with nothing. Someone skimming the
   main page should lose the full story, not the context. This is the
   explicit shape `68b99813` used on all six pages.

6. **Both pages get today's `_Last modified:_`**, and if the source page has
   a `-for-agents` sibling, follow there in the same change or the
   `siblings` check fails the run (skill `wiki-sync`, step 5). A sweep
   usually *does* change the sibling — it carries the conclusion, which is
   what a summary-plus-link replaces.

7. **`just wiki-lint`**, and re-run `just wiki-history-candidates` on the
   page you swept to confirm the section stopped scoring.

## Traps

- **`gen-contents` after removing a heading.** Cutting a section leaves the
  page's `## Contents` list stale; `python3 wiki/scripts/check_wiki.py
  gen-contents <page>` is the fix, not hand-editing the list. `wiki-lint`
  catches it either way.
- **Don't run `gen-contents` across every wiki page to "check" it.**
  `-for-agents.md` siblings, `lessons-learned.md` and its articles are
  **exempt** from carrying a Contents block, and the insert path will
  happily add one to each. Hit 2026-09-11, ~20 pages, reverted by hand.
  Pass only the pages you actually changed.
- **A `-history.md` page needs no `-for-agents` sibling** and no
  `## Contents` — it is already the moved-out-of-the-way tier
  (`SIBLING_EXEMPT` in `check_wiki.py`).
- **The script can't see a justification that expired.** It scores words,
  and the `reverse-proxy.md` case above had identical words before and
  after it became history. Only a human reading the current config knows.

## See also

- `wiki/styleguide.md`, "Directory hierarchy" — where the `-history.md`
  pattern and the don't-reach-for-this-by-default test are written down.
- `wiki/scripts/history_candidates.py` — the survey, and its own account of
  what it cannot tell apart.
- Commit `68b99813` — the original six-page split, and the most careful
  worked example of this judgement that exists here.
- Skill `wiki-sync` — keeping the `-for-agents` sibling in step, step 6
  above.
