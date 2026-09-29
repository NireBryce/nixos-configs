---
name: trim-history
description: How to compress a .nix module's bottom-of-file history section down to the facts the module body doesn't already restate, and show the result side by side before landing.
---

# Compressing a module's history section

## Applies to

A `.nix` module in `flake/modules/` whose bottom-of-file `# ── history ──`
block (stranded bug records; `just history-line <file>` finds it) is large
next to the module, and the ask is to compress/trim/shrink it. Not wiki
pages (`trim-docs`; the wiki has its own `-history.md` pattern), and never
deleting the section.

## Why it exists

The history is a correctness backstop: it stops an agent re-introducing a
fixed bug ("a bug recorded in a comment stays in the file", AGENTS.md), and
matters exactly when the file is open. Shorter, never absent; the result
must stand alone without `git log`.

## Steps

1. `just history-line <file>`, then read the **whole** module. The body usually absorbed most of the history's facts; that overlap is the cut.
2. Per entry: does the body above already state it? Cut what it restates.
3. Keep always: dates and commit hashes; what was wrong and what fixed it (one line each); guidance a body pointer sends readers here for ("see history at the bottom before re-enabling" must still resolve); pointers to full accounts (skill, lessons-learned §); how claims were verified (`just diff`, subvolid, od -c).
4. Cut always: mechanism the body now carries, incident narration, quoted wrong assessments lessons-learned already holds.
5. Prove comment-only: every diff hunk at or after the history line, and `cmp` of `head -n $((line-1))` old vs new byte-identical.
6. `nix eval` the toplevel drvPath of every host importing the module. Comment text moves the drvPath; nothing built changes, so a successful eval is the whole check.
7. **Show the user old vs compressed section side by side, with what was cut and why, before landing** (part of the ask).
8. Land via `ship`.

## See also

`trim-docs` (same discipline for wiki/skills); `just history-line` (also the cheap partial read when browsing); `WARN-impermanence.nix` (PR #261: 7.2KB to 3.2KB, body byte-identical).
