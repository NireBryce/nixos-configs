---
name: wiki-sync
description: Check whether a change you just made leaves a wiki/ article stale, and fix it in the same change.
---

# Keeping the local wiki in sync

## Applies to

End of any change that could make something `wiki/` states no longer true.
Rule (`wiki/00-INDEX.md`, `styleguide.md`): *whichever session's change makes
a page stale corrects it in the same change, not as a follow-up.* Skip when
the change touches nothing the wiki describes (most small single-module
internal edits); grep first rather than opening every page.

## Triggers

- moving/renaming a file a wiki page links to
- changing a fact a page states as current: category member count, import list, command, path, stateVersion, host count (host switch/boot status is deliberately *not* a wiki fact — live check per `AGENTS.md` State)
- fixing a bug `open-threads.md` describes as open, or finding a new one worth recording there
- reorganizing categories, splitting a module, anything changing which directory something lives under
- adding a `just agent` script (skill `agent-scripts`): one line naming it on the `-for-agents` page for its topic, where an agent doing that task will look; none fits → skip

Narrower cases with their own instructions (read first):

- **Module added/removed/renamed, or category membership changed** — `new-flake-module` "Keep the wiki in sync": the category's `wiki/categories/<name>.md`, its `-for-agents.md` sibling, and `wiki/categories/00-INDEX.md`'s table.
- **Host added, or its category imports changed** — `new-host-config` wiring step: `wiki/hosts.md` table plus the "Imported by" line on every affected `wiki/categories/*.md`.

## Procedure

1. **Name what changed as facts, not files** ("host X now imports category Y", "path A moved to B", "bug D (open-threads.md) fixed"). Search for that, not the commit description.
2. **Find candidate pages:**
   ```sh
   grep -rln "<old-name-or-path-or-fact>" wiki/
   ```
   Usual hits for structural changes: `wiki/categories/00-INDEX.md`, `wiki/hosts.md`, `wiki/architecture.md`; `wiki/open-threads.md` for anything tracked as pending.
3. **Read each against the new state, not memory** — re-derive (`just modules`, `hostname`, the file itself).
4. **Edit stale pages in the same change**, per `wiki/styleguide.md`:
   - Dates absolute (`2026-08-23`).
   - Relative links recomputed for file depth; verify each resolves.
   - kebab-case names; `00-INDEX.md` reserved for a directory's own index.
   - A fix ballooning into prose that argues a fact means the fact belongs in the linked file's own header.
   - **Bump `_Last modified: YYYY-MM-DD_`** (right after the title) to today on every page you edited, not on pages only read. `check_wiki.py dates` (in `just wiki-lint`) catches only a missing/malformed line, never a stale date left behind.
5. **Edit the `-for-agents` sibling of every page you touched, same change.** Long pages are pairs (`wiki/styleguide.md` "Two audiences per page"); the sibling is the copy an agent reads, so stale there is the worse half.

   `check_wiki.py siblings` (in `just wiki-lint`) fails when a sibling's `_Last modified:_` predates its source's. **Don't satisfy it by bumping the sibling's date** (turns a caught omission silent). Edit, then bump.

   If the source edit has nothing to sync (reorder, typo, rewording of a fact the sibling states its own way), say so on the sibling under its `_Last modified:_` line:

   ```
   _Sibling reviewed: 2026-09-11 -- header reorder, no facts moved_
   ```

   A reviewed date at or after the source's clears the finding. Reason mandatory; a future date is itself a finding (the claim must be auditable in the diff).

   Asymmetries:
   - **Narrative is one-sided.** Verification accounts go on the human page only; the sibling carries the conclusion. The date bump still trips the check → `_Sibling reviewed:_` once you've confirmed the sibling needs no edit. (Before 2026-09-11 this said to bump the sibling's date, contradicting the rule above.)
   - **`## Imported by` may live on either page or both.** `check_imports` checks whichever exist; grep, update every copy.
6. **If nothing in `wiki/` mentions what changed, say so and stop.** Don't manufacture an edit.

## See also

- `wiki/styleguide.md` (house rules; "Two audiences per page"), `wiki/styleguide-for-agents.md` (checklist), `wiki/00-INDEX.md` ("keeping this from rotting").
- Skills `new-flake-module`, `new-host-config`, `new-wiki-page` (creating a page; this skill starts from an existing one).
