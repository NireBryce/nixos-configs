---
name: explain-tricky-code
description: How to write comments that teach a reader a module or lib function whose design isn't obvious, covering what it does, why it's shaped so, and what breaks on change.
---

# Explaining tricky code so a user or contributor can follow it

Technique: write the comments like a conference talk to a mixed-skill
audience — start from the problem, build up, diagram, explain what the code
alone doesn't show. (Was `talk-style-explainer` until 2026-09-28.)

## Applies to

A `.nix` module or `_lib/` function whose *mechanism* is the hard part —
a competent reader can't follow it from code alone; the questions are "why
is it shaped like this" and "what breaks if I touch it". Asked directly
("explain this like a talk", "make these comments clearer for someone
new"), or offered when a comment rewrite keeps coming back "still
confusing".

Worked example: `flake/modules/_lib/category-collector.nix`, rewritten
2026-09-28 after three denser rounds that read as clear only to someone who
already knew the answer.

Not this skill:

| ask | what to do |
|---|---|
| ordinary module (package, service toggle) | `wiki/module-style-guide.md` — dense one-line comments |
| bottom-of-file history block | skill `trim-history`; stays compressed, never talk-style |
| a wiki page | `wiki/styleguide.md` (human half + agent half) |
| tightening existing prose | skill `trim-docs` |

**Opposite trade from the repo's house style** (max density); a talk header
is several times longer. Use only where the mechanism earns it, and say so
when offering — the user picks.

## The shape

Each part is a ruled section (`just ruled-heading "<title>"`, 78 wide), in
this order. Skip parts the subject doesn't need; don't reorder.

**Title sections after what they describe** ("where restore-root sits in
the boot"), not after the part below, and not with a judgment ("the clever
part", "the surprising bits") — evaluative labels bias how the next reader,
LLM agents included, weighs the code beneath.

1. **Self-introduction, own line, full path.** "This file,
   `modules/_lib/category-collector.nix`, is the logic every
   `dirsAsCategory.nix` runs."
2. **The problem: what first, why second.** One plain statement of what it
   does, then the obvious alternative and its concrete failure modes
   ("rename a module and every list naming it is wrong").
3. **Background the mechanism leans on — only that.** Outside-the-file
   context (flake-parts per-class `flake.modules`, import-tree path
   filtering), with one real tree example (`zsh.nix` declaring a `nixos` and
   a `homeManager` half). Not a tool tutorial.
4. **The rule once, then a diagram.** One repeatable sentence ("a category
   imports every `.nix` module under its folder, however deep"), a tree of
   *real* paths annotated with what happens to each, then consequences as a
   short list.
5. **The core mechanism**, introduced from the reader's likely first guess
   ("it could walk in and list everything by hand. But …"), with a small
   flow diagram.
6. **Reasons the code can't show, at the line they concern.** A systemd
   behaviour, a second module declaring the same option, a machine that did
   something the config never asked for — explained as what depends on what,
   not gathered into a "don't change" list. Separate section only when
   several share one cause explained in the header. If an explanation mainly
   defends dead code, delete the code and put a line in `history`.
7. **Traps.** What fails silently, and what (if anything) catches it.
8. **How to change it safely.** Doc to read first; how to verify
   (fingerprint diff, attribute-set diff).

Per-function comments: same voice, short — what this piece does in terms of
the sections above, plus any "why not the obvious thing" for that line.

## Voice

- Define every term at first use, in words ("a folder with a
  `dirsAsCategory.nix` is a *category*").
- Real examples from this tree, never placeholders (`fzf.nix` in `find/`,
  not `foo.nix` in `bar/`) — a real path can be checked.
- Start from what the reader would expect ("You'd think it could just hand
  over the names — it can't, and here's why").
- Plain words where exact ("folder"); keep the greppable term too
  (`forClass`, `imports`).
- No history in the body ("We used to…" goes in bottom `history`).

## Diagrams

Wherever the explanation would otherwise be "imagine a folder containing…".
Inline `#` comments, 78 columns:

- **Trees**: Unicode box drawing as `tree` prints (`├──`, `│`, `└──`), each
  node annotated in a right-hand column.
- **Flows/decisions**: a small table — input, branch, result:

  ```
  #     find/          plain folder    -> walk in          -> fzf, fd
  #     text-tools/    a category      -> add its name     -> ripgrep, bat, ...
  ```

- **Code shapes**: attribute paths one per line
  (`flake.modules.nixos.<name>   system config`).

Keep each small enough to check by hand — every node is a claim.

## Verify every claim before landing

Talk headers make many authoritative-sounding claims; on the worked example
three drafts shipped false ones:

- "Hosts never import individual modules" — `kde-desktop` and `jovian` are
  imported by name. **Any "never"/"always"/"every" gets a grep.**
- "Each category comes out as *up to* three modules" — the code always
  defines all three. **Read the code, not your model of it.**
- "`just modules` catches a file named differently from its module" — it
  keys by filename, checks no such thing. **A "tool catches X" claim needs
  the tool's source read.**

Also:

- Run the real code against the diagram (collector: stub `config` mapping
  every name to itself; compare lists to the tree annotations).
- `ls`/grep each example path and declaration.
- Counts ("~40 folders"): count, and prefer "~" or no number (skill
  `fact-hygiene`).

Then `just preflight` — comment-only edits still face wiki-lint and module
checks.

## See also

- `flake/modules/_lib/category-collector.nix` — worked example.
- `wiki/module-style-guide.md` — the dense default this departs from.
- Skill `fact-hygiene`; `just ruled-heading`.
