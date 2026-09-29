---
name: wiki-history-sweep
description: How to move a wiki page's resolved-incident narrative into a <name>-history.md companion, and how to find the pages that need it.
---

# Sweeping resolved narrative into a `-history.md` companion

## Applies to

A `wiki/` page holding narrative about things now **fully resolved** (a
fixed first-switch failure, superseded plan, retired design, done checklist
item) where the outcome matters but the blow-by-blow no longer informs
current use. Either a deliberate sweep (`just wiki-history-candidates`) or
you're editing such a page and the section is in the way.

Not this skill:

| ask | do |
|---|---|
| `.nix` module's bottom-of-file history too long | `trim-history` |
| wiki page just wordy | `trim-docs` (tightens in place, moves nothing) |
| facts went stale | `wiki-sync` |
| section *about* a live setting, however old | leave it (test below) |

## Why this exists

The pattern was created in one pass (`68b99813`, 2026-09-02, six category
pages) and extracted into once since (`5cdd8b2b`, 2026-09-06,
`homelab/backup-runbook.md` rewritten as a command reference). Nothing
routes to it: no check asks, and `wiki/styleguide.md`'s "Directory
hierarchy" documents it with no procedure. Issue #288.

## The test (conservative)

From `styleguide.md`:

> Does understanding the **current** setting/behavior require this
> paragraph, or only understanding how it came to be that way?

**Only the second kind moves.** The house style explains live mechanisms
*through the story of their discovery*, which reads like history and isn't.
`68b99813` kept shortlinks' `AF_NETLINK` requirement, monitoring's
`grafana-secret-key-setup.service`, reverse-proxy's `handle`-vs-`handle_path`
split, virtualization's default-network gating — correctly.

False positives (confirmed 2026-09-11; the script still scores them; don't move):

- `categories/landing.md` "Two things that could have gone quietly wrong, and didn't" — confirmed-live facts; states the fix if either changes (`alt-status-codes: [302]`).
- `categories/shell-config/blesh.md` `read: not a valid identifier` — diagnosis is history-shaped; upstream bug still open.
- `categories/system.md` "Containers vs. virtualization — no longer filed here" — trap is live; where someone remembering the old location looks.

**A section's justification can expire** — worth sweeping for.
`reverse-proxy.md`'s `handle`-vs-`handle_path` section was kept 2026-09-02
as explaining a live setting; path-prefix routes were retired 2026-09-07
(each app got its own vhost), so no shared prefix remains. Same words, no
longer load-bearing. The script can't see this (it scores words); only
reading current config does.

## Steps

1. **Find candidates**:
   ```sh
   just wiki-history-candidates            # everything scoring > 0
   just wiki-history-candidates --min 6    # stronger hits only
   just wiki-history-candidates --page wiki/categories/reverse-proxy.md
   ```
   Ranked, reporting-only. **Most hits are wrong** — a reading list. Marker meanings: docstring of `wiki/scripts/history_candidates.py`.
2. **Apply the test by reading each.** Name the current setting the section justifies; if you can, it stays.
3. **Destination: one companion per category, not per page** (`5cdd8b2b` moved backup-runbook's background into `categories/backup-history.md`, not `backup-runbook-history.md`). Confirm it exists or its absence is intended.
4. **A page spanning several categories has no single destination** (script says so). `homelab/pending-setup.md`: four of six items done, belonging to git-forge, backup, monitoring, shortlinks. Distributing destroys the checklist; `pending-setup-history.md` breaks the rule. **Don't settle silently** — it sets precedent. Ask; #288 records it open.
5. **Leave a 1-2 sentence summary plus link**, never a bare pointer (`68b99813`'s shape).
6. **Both pages get today's `_Last modified:_`**; follow in the `-for-agents` sibling in the same change or `siblings` fails (`wiki-sync` step 5). A sweep usually changes the sibling: it carries the conclusion a summary-plus-link replaces.
7. `just wiki-lint`, then re-run `just wiki-history-candidates` on the swept page to confirm the section stopped scoring.

## Traps

- **`gen-contents` after removing a heading:** `python3 wiki/scripts/check_wiki.py gen-contents <page>`, not hand-editing.
- **Never run `gen-contents` across all pages.** `-for-agents.md` siblings, `lessons-learned.md` and its articles are exempt from Contents blocks and the insert path adds one anyway (hit 2026-09-11, ~20 pages). Pass only pages you changed.
- **A `-history.md` needs no `-for-agents` sibling but DOES keep `## Contents`.** `SIBLING_EXEMPT` in `check_wiki.py` covers `-history.md`; styleguide's Contents exception covers only `lessons-learned*` and `-for-agents.md`. An earlier version of this skill had it backwards and `reverse-proxy-history.md` lost its block (2026-09-12); `check_contents` now reports **MISSING CONTENTS** for a non-exempt page with headings but no block.

## See also

- `wiki/styleguide.md` "Directory hierarchy"; `wiki/scripts/history_candidates.py`; commit `68b99813` (best worked example); `wiki-sync`.
