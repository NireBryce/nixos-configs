---
name: trim-history
description: How to compress a .nix module's bottom-of-file history section down to the facts the module body doesn't already restate, and show the result side by side before landing.
---

# Compressing a module's history section

## Applies to

A `.nix` module in `flake/modules/` whose history section (the bottom-of-file
`# ── history ──` block the repo's convention puts stranded bug records
under — `just history-line <file>` finds it) has grown large next to its
module, and the ask is to compress, trim, or shrink it. Not wiki pages
(skill `trim-docs`; the wiki has its own `-history.md` pattern), and never
deleting the section — this skill makes it shorter, not gone.

## Why the section exists — read before cutting

The history is a correctness backstop, not documentation: it stops an agent
re-introducing a fixed bug while editing the file ("a bug recorded in a
comment stays in the file", AGENTS.md). The moment it matters is the moment
the file is already open. So the goal is shorter, never absent, and the
compressed section must still stand alone — readable without `git log`.

## Steps

1. `just history-line <file>` for the section's line number, then read the
   **whole** module. The body usually absorbed most of the history's facts
   when it was last rewritten — that overlap is the cut.
2. For each history entry, ask: does the body above already state this?
   Cut what it restates; keep what it doesn't.
3. Keep, always: dates and commit hashes, what was wrong and what fixed it
   (one line each), any guidance a body pointer sends readers here for
   ("see history at the bottom before re-enabling" must still resolve to
   real content), pointers to full accounts (a skill, lessons-learned §),
   and how claims were verified (`just diff`, subvolid, od -c).
4. Cut, always: mechanism explanations the body now carries, incident
   narration, and quoted wrong assessments that lessons-learned already
   holds.
5. Prove the edit was comment-only: every diff hunk at or after the history
   line, and `cmp` of `head -n $((line-1))` old vs new byte-identical.
6. Verify evaluation: `nix eval` the toplevel drvPath of every host
   importing the module. Comment text moves the drvPath; nothing built
   changes — a successful eval is the whole check.
7. **Show the user the compressed section against the old one** — both
   blocks side by side, with what was cut and why — before landing. This
   is part of the ask, not a courtesy.
8. Land via `ship`.

## See also

- `trim-docs` — the same facts-per-sentence discipline for wiki and skills;
  this file applies it to code comments.
- `just history-line` — locating the section; also the cheap-partial-read
  trick when only *browsing* a module.
- AGENTS.md, Conventions — "a bug recorded in a comment stays in the file".
- `WARN-impermanence.nix` (PR #261) — the worked example: 7.2KB → 3.2KB,
  body byte-identical.
