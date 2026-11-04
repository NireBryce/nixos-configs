---
name: wiki-sync
description: Checks whether your change left a wiki article stale, and fixes it in the same change.
when_to_use: At the end of any change that could make something the wiki states no longer true.
---

# Keeping the local wiki in sync

## Applies to

Use this skill at the end of any change that could make something `wiki/`
states no longer true. The rule (`wiki/00-INDEX.md`, `styleguide.md`): the
session whose change makes a page stale corrects it in the same change, not in
a follow-up. Skip it when the change touches nothing the wiki describes (most
small single-module internal edits). Grep first instead of opening every page.

## Triggers

- Moving or renaming a file a wiki page links to.
- Changing a fact a page states as current: category member count, import
  list, command, path, stateVersion, host count. (Host switch/boot status is
  not a wiki fact; check it live per `AGENTS.md` State.)
- Fixing a bug `open-threads.md` describes as open, or finding a new one worth
  recording there.
- Reorganizing categories, splitting a module, or anything that changes which
  directory something lives under.
- Adding a `just agent` script (skill `agent-scripts`): add one line naming it
  on the `-for-agents` page for its topic, where an agent doing that task will
  look. If no page fits, skip.

Narrower cases have their own instructions; read them first:

- **Files or directories moved**: `git mv` them, then run
  `just agent move-refs` (use `--dry-run` first). It rewrites markdown links
  and bare path mentions repo-wide, and prints `REVIEW` lines for code that
  builds a moved path from pieces or counts directories up (`parents[2]`),
  which no link check sees. Read every `REVIEW` line, then run
  `just wiki-lint`.
- **Module added, removed or renamed, or category membership changed**:
  `new-flake-module` "Keep the wiki in sync". Update the category's
  `wiki/config-structure/categories/<name>.md`, its `-for-agents.md` sibling,
  and run `just wiki-gen` for the tables in
  `wiki/config-structure/categories/00-INDEX.md`.
- **Host added, or its category imports changed**: `new-host-config` wiring
  step. Run `just wiki-gen` for `wiki/fleet/hosts.md`'s table (then write the
  new row's Role), and update the "Imported by" line on every affected
  `wiki/config-structure/categories/*.md`.

**Do not hand-edit generated tables.** A table between
`<!-- generated:<name> ... -->` and `<!-- /generated -->` is rewritten from
source by `just wiki-gen`. Change the source the marker names, then run it.
Only the columns the marker calls hand-written are yours to edit.
`wiki-lint`'s `generated` check names a stale region, and the fix is always
`just wiki-gen`. Do not bump the date for a regeneration
(`wiki/meta/styleguide.md`, "Generated tables").

## Procedure

1. **Name what changed as facts, not files** ("host X now imports category Y",
   "path A moved to B", "bug D (open-threads.md) fixed"). Search for the fact,
   not the commit description.
2. **Find candidate pages:**
   ```sh
   grep -rln "<old-name-or-path-or-fact>" wiki/
   ```
   Usual hits for structural changes: `wiki/config-structure/categories/00-INDEX.md`,
   `wiki/fleet/hosts.md`, `wiki/config-structure/architecture.md`, and
   `wiki/meta/open-threads.md` for anything tracked as pending.
3. **Read each page against the new state, not memory.** Re-derive the state
   (`just modules`, `hostname`, the file itself).
4. **Edit stale pages in the same change**, per `wiki/meta/styleguide.md`:
   - Write dates as absolute dates (`2026-08-23`).
   - Recompute relative links for the file's depth and verify each resolves.
   - Use kebab-case names; `00-INDEX.md` is reserved for a directory's own
     index.
   - If a fix grows into prose that argues a fact, put the fact in the linked
     file's own header instead.
   - **Bump `_Last modified: YYYY-MM-DD_`** (right after the title) to today on
     every page you edited, not on pages you only read. `factcheck dates` (in
     `just wiki-lint`) catches only a missing or malformed line, never a stale
     date left behind.
5. **Edit the `-for-agents` sibling of every page you touched, in the same
   change.** Long narrative pages are pairs (`wiki/meta/styleguide.md` "Two
   audiences per page"). The sibling is the copy an agent reads, so staleness
   there does more harm. A page with no sibling that opens with
   `## Quick facts` is the folded shape: update that section in place if your
   edit changes a fact it states. If a pair's sibling restates the page
   near-verbatim, or the two churn in lockstep, it is a fold candidate
   (styleguide's tests). Do that in a separate change.

   `factcheck siblings` (in `just wiki-lint`) fails when a sibling's
   `_Last modified:_` predates its source's. **Do not satisfy it by bumping
   the sibling's date**, which turns a caught omission into a silent one. Edit
   the sibling, then bump.

   If the source edit has nothing to sync (a reorder, a typo, rewording of a
   fact the sibling states its own way), say so on the sibling under its
   `_Last modified:_` line:

   ```
   _Sibling reviewed: 2026-09-11 -- header reorder, no facts moved_
   ```

   A reviewed date at or after the source's clears the finding. The reason is
   mandatory, and a future date is itself a finding (the claim must be
   auditable in the diff).

   Two asymmetries:
   - **Narrative is one-sided.** Verification accounts go on the human page
     only; the sibling carries the conclusion. The date bump still trips the
     check, so add `_Sibling reviewed:_` once you have confirmed the sibling
     needs no edit. (Before 2026-09-11 this said to bump the sibling's date,
     contradicting the rule above.)
   - **`## Imported by` may live on either page or both.** `check_imports`
     checks whichever exist. Grep, and update every copy.
6. **If nothing in `wiki/` mentions what changed, say so and stop.** Do not
   manufacture an edit.

## See also

- `wiki/meta/styleguide.md` (house rules; "Two audiences per page"),
  `wiki/meta/styleguide-for-agents.md` (checklist), `wiki/00-INDEX.md`
  ("keeping this from rotting").
- Skills `new-flake-module`, `new-host-config`, `new-wiki-page` (creating a
  page; this skill starts from an existing one).
