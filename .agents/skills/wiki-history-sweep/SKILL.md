---
name: wiki-history-sweep
description: Moves a wiki page's resolved-incident narrative into a history companion page, and finds the pages that need it.
when_to_use: A wiki page carries narrative about fully resolved problems, or running the history candidates sweep.
---

# Sweeping resolved narrative into a `-history.md` companion

## Applies to

Use when a `wiki/` page holds narrative about things that are now **fully resolved** (a fixed first-switch failure, a superseded plan, a retired design, a done checklist item), where the outcome matters but the blow-by-blow no longer informs current use. Use it for a deliberate sweep (`just wiki-history-candidates`) or when you are editing such a page and the section is in the way.

Other skills cover neighboring asks:

| ask | do |
|---|---|
| `.nix` module's bottom-of-file history too long | `trim-history` |
| wiki page just wordy | `trim-docs` (tightens in place, moves nothing) |
| facts went stale | `wiki-sync` |
| section *about* a live setting, however old | leave it (test below) |

## Why this exists

The pattern was created in one pass (`68b99813`, 2026-09-02, six category pages) and reused once since (`5cdd8b2b`, 2026-09-06, `homelab/backup-runbook.md` rewritten as a command reference). Nothing routes to it: no check asks for it, and `wiki/meta/styleguide.md`'s "Directory hierarchy" documents it with no procedure. Issue #288.

## The test (conservative)

From `styleguide.md`:

> Does understanding the **current** setting/behavior require this
> paragraph, or only understanding how it came to be that way?

**Only the second kind moves.** The house style explains live mechanisms through the story of their discovery, so a live section can read like history. `68b99813` correctly kept shortlinks' `AF_NETLINK` requirement, monitoring's `grafana-secret-key-setup.service`, reverse-proxy's `handle`-vs-`handle_path` split, and virtualization's default-network gating.

False positives (confirmed 2026-09-11; the script still scores them; do not move):

- `categories/landing.md` "Two things that could have gone quietly wrong, and didn't": confirmed-live facts, and it states the fix if either changes (`alt-status-codes: [302]`).
- `categories/shell-config/blesh.md` `read: not a valid identifier`: the diagnosis is history-shaped, but the upstream bug is still open.
- `categories/system.md` "Containers vs. virtualization — no longer filed here": the trap is live, and it is where someone remembering the old location looks.

**A section's justification can expire.** Check for this during a sweep. `reverse-proxy.md`'s `handle`-vs-`handle_path` section was kept on 2026-09-02 because it explained a live setting. Path-prefix routes were retired on 2026-09-07 (each app got its own vhost), so no shared prefix remains and the same words are no longer load-bearing. The script cannot see this because it scores words; only reading the current config does.

## Steps

1. **Find candidates:**
   ```sh
   just wiki-history-candidates            # everything scoring > 0
   just wiki-history-candidates --min 6    # stronger hits only
   just wiki-history-candidates --page wiki/config-structure/categories/reverse-proxy.md
   ```
   The output is ranked and report-only. Most hits are wrong, so treat it as a reading list. Marker meanings are in the docstring of `wiki/meta/scripts/history_candidates.py`.
2. **Apply the test by reading each hit.** Name the current setting the section justifies. If you can, it stays.
3. **Pick the destination: one companion per category, not per page.** `5cdd8b2b` moved backup-runbook's background into `categories/backup-history.md`, not `backup-runbook-history.md`. Confirm the companion exists, or that its absence is intended.
4. **A page spanning several categories has no single destination** (the script says so). The worked example was the old `homelab/pending-setup.md` checklist (items for git-forge, backup, monitoring, shortlinks), settled on 2026-10-01 by moving open items to issues. For any new case, ask instead of settling it yourself, because the choice sets precedent. #288 records the question.
5. **Leave a 1-2 sentence summary plus a link** in the original page, never a bare pointer (the shape `68b99813` used).
6. **Give both pages today's `_Last modified:_` date.** Update the `-for-agents` sibling in the same change or `siblings` fails (`wiki-sync` step 5). A sweep usually changes the sibling, since it carries the conclusion that the summary-plus-link replaces.
7. **Run `just wiki-lint`**, then re-run `just wiki-history-candidates` on the swept page to confirm the section stopped scoring.

## Traps

- **After removing a heading, run `factcheck fix-contents <page>`.** Do not hand-edit the Contents block.
- **Never run `gen-contents` across all pages.** `-for-agents.md` siblings, `agent-lessons-learned.md` and its articles are exempt from Contents blocks, and the insert path adds one anyway (this hit about 20 pages on 2026-09-11). Pass only pages you changed.
- **A `-history.md` needs no `-for-agents` sibling but does keep `## Contents`.** factcheck.toml's `[siblings] exempt` covers `-history.md`; styleguide's Contents exception covers only `agent-lessons-learned*` and `-for-agents.md`. An earlier version of this skill had it backwards and `reverse-proxy-history.md` lost its block (2026-09-12). `check_contents` now reports **MISSING CONTENTS** for a non-exempt page with headings but no block.

## See also

- `wiki/meta/styleguide.md` "Directory hierarchy"; `wiki/meta/scripts/history_candidates.py`; commit `68b99813` (best worked example); `wiki-sync`.
