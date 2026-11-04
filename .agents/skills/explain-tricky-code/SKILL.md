---
name: explain-tricky-code
description: Writes comments for a module or function whose design isn't obvious, covering what it does, why it's shaped that way, and what breaks if it changes.
when_to_use: Asked to explain code like a talk, make comments clearer for newcomers, or redo a comment rewrite that is still confusing.
---

# Explaining tricky code so a user or contributor can follow it

Technique: write the comments like a conference talk to a mixed-skill
audience. Start from the problem, build up, add diagrams, and explain what the
code alone does not show. (Named `talk-style-explainer` until 2026-09-28.)

## Applies to

A `.nix` module or `_lib/` function whose mechanism is the hard part: a
competent reader cannot follow it from the code alone, and the open questions
are why it is shaped this way and what breaks if it changes. Use it when asked
directly ("explain this like a talk", "make these comments clearer for someone
new"), or offer it when a comment rewrite keeps coming back "still
confusing".

Worked example: the category collector, rewritten 2026-09-28 after three
denser rounds that read as clear only to someone who already knew the answer.
The file was retired 2026-10-16 (wiki/config-structure/module-files.md); read
it with `git show 5808bfe2:flake/modules/_lib/category-collector.nix`.

Not this skill:

| ask | what to do |
|---|---|
| ordinary module (package, service toggle) | `wiki/config-structure/module-style-guide.md` — dense one-line comments |
| bottom-of-file history block | skill `trim-history`; stays compressed, never talk-style |
| a wiki page | `wiki/meta/styleguide.md` (human half + agent half) |
| tightening existing prose | skill `trim-docs` |

This is the opposite trade from the repo's house style (maximum density): a
talk header is several times longer. Use it only where the mechanism needs it,
and say so when offering it, because the user decides.

## The shape

Each part is a ruled section (`just ruled-heading "<title>"`, 78 wide), in the
order below. Skip parts the subject does not need; do not reorder them.

Title each section after what it describes ("where restore-root sits in the
boot"), not after the part below it and not with a judgment ("the clever
part", "the surprising bits"). Evaluative labels bias how the next reader,
including an LLM agent, weighs the code beneath.

1. **Self-introduction, own line, full path.** "This file,
   `modules/_lib/category-collector.nix`, is the logic every
   `dirsAsCategory.nix` runs." (the worked example's opening)
2. **The problem: what first, why second.** State what the code does, then the
   obvious alternative and its concrete failure modes ("rename a module and
   every list naming it is wrong").
3. **Background the mechanism needs, and only that.** Give the context from
   outside the file (flake-parts per-class `flake.modules`, import-tree path
   filtering) with one real tree example (`zsh.nix` declaring a `nixos` and a
   `homeManager` half). Do not write a tool tutorial.
4. **The rule once, then a diagram.** State one repeatable sentence ("a
   category imports every `.nix` module under its folder, however deep"), then
   a tree of real paths annotated with what happens to each, then the
   consequences as a short list.
5. **The core mechanism**, introduced from the reader's likely first guess
   ("it could walk in and list everything by hand. But …"), with a small flow
   diagram.
6. **Reasons the code cannot show, at the line they concern.** Examples: a
   systemd behaviour, a second module declaring the same option, a machine that
   did something the config never asked for. Explain what depends on what; do
   not gather them into a "don't change" list. Use a separate section only when
   several lines share one cause that the header explains. If an explanation
   mainly defends dead code, delete the code and put a line in `history`.
7. **Traps.** What fails silently, and what (if anything) catches it.
8. **How to change it safely.** The doc to read first, and how to verify
   (fingerprint diff, attribute-set diff).

Per-function comments use the same voice and stay short: say what the piece
does in terms of the sections above, plus any "why not the obvious thing" for
that line.

## Voice

- Define every term at first use, in words ("a folder whose subfolders hold
  modules is a *category*").
- Use real examples from this tree (`fzf.nix` in `find/`, not `foo.nix` in
  `bar/`); a reader can check a real path.
- Start from what the reader would expect ("You'd think it could just hand
  over the names. It can't, and here is why").
- Use plain words where they are exact ("folder"), and keep the greppable
  term too (`importsFor`, `imports`).
- Keep history out of the body ("We used to…" goes in bottom `history`).
- For security code (guards, hooks, permission rules), explain the rule and
  what it enforces, not the inputs that got past an earlier version or what
  they reached. That analysis lives in `elly/infra-notes` (AGENTS.md).

## Diagrams

Use one wherever the explanation would otherwise start "imagine a folder
containing…". Write them as inline `#` comments, 78 columns:

- **Trees**: Unicode box drawing as `tree` prints (`├──`, `│`, `└──`), each
  node annotated in a right-hand column.
- **Flows/decisions**: a small table of input, branch, result:

  ```
  #     find/          plain folder    -> walk in          -> fzf, fd
  #     text-tools/    a category      -> add its name     -> ripgrep, tokei, ...
  ```

- **Code shapes**: attribute paths one per line
  (`flake.modules.nixos.<name>   system config`).

Keep each diagram small enough to check by hand, because every node is a
claim.

## Verify every claim before landing

Talk headers make many authoritative-sounding claims. Three drafts of the
worked example shipped false ones:

- "Hosts never import individual modules": `kde-desktop` and `jovian` are
  imported by name. Grep every "never", "always" and "every".
- "Each category comes out as *up to* three modules": the code always defines
  all three. Read the code, not your model of it.
- "`just modules` catches a file named differently from its module": it keys
  by filename and checks no such thing. Read the tool's source before writing
  "tool catches X".

Also:

- Run the real code against the diagram (collector: stub `config` mapping
  every name to itself; compare the lists to the tree annotations).
- Run `ls` or grep on each example path and declaration.
- Count anything you quote ("~40 folders"), and prefer "~" or no number
  (skill `fact-hygiene`).

Then run `just agent preflight-brief`. Comment-only `.nix` edits still need
the full run, because a `${...}` in a `''` string comment interpolates.

## See also

- `git show 5808bfe2:flake/modules/_lib/category-collector.nix` — worked example.
- `wiki/config-structure/module-style-guide.md` — the dense default this departs from.
- Skill `fact-hygiene`; `just ruled-heading`.
