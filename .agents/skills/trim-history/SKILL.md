---
name: trim-history
description: Compresses a .nix module's bottom-of-file history section to the facts the module body doesn't already state, and shows the result side by side before landing.
when_to_use: Asked to compress, trim or shrink the history section at the bottom of a .nix module.
---

# Compressing a module's history section

**Needs:** bash-guards

## Applies to

Use this skill when a `.nix` module in `flake/modules/` has a large
bottom-of-file `# ── history ──` block (stranded bug records;
`just history-line <file>` finds it) and you are asked to compress, trim or
shrink it. Do not use it on wiki pages (`trim-docs`; the wiki has its own
`-history.md` pattern), and never delete the section.

## Why it exists

The history stops an agent from re-introducing a fixed bug ("a bug recorded in
a comment stays in the file", AGENTS.md), and it matters when the file is
open. Make it shorter but never absent. The result must stand alone without
`git log`.

## Steps

1. Run `just history-line <file>`, then read the **whole** module. The body
   usually already states most of the history's facts; that overlap is what to
   cut.
2. For each entry, check whether the body above already states it. Cut what it
   restates.
3. Always keep:
   - dates and commit hashes;
   - what was wrong and what fixed it (one line each);
   - guidance a body pointer sends readers here for ("see history at the
     bottom before re-enabling" must still resolve);
   - pointers to full accounts (a skill, an agent-lessons-learned §);
   - how claims were verified (`just diff`, subvolid, od -c).
4. Always cut mechanism the body now carries, incident narration, and quoted
   wrong assessments that agent-lessons-learned already holds.
5. Prove the change is comment-only: every diff hunk is at or after the
   history line, and `cmp` of `head -n $((line-1))` on old and new is
   byte-identical.
6. Run `nix eval` on the toplevel drvPath of every host importing the module.
   Comment text moves the drvPath but nothing built changes, so a successful
   eval is the whole check.
7. **Show the user the old and compressed sections side by side, with what was
   cut and why, before landing.** This is part of the ask.
8. Land via `ship`.

## See also

`trim-docs` (same discipline for wiki/skills); `just history-line` (also a
cheap partial read when browsing); `WARN-impermanence.nix` (PR #261: 7.2KB to
3.2KB, body byte-identical).
